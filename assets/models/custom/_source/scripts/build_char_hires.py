"""Personaggi scolpiti ad alta risoluzione (art_source/characters/*.blend, mesh unica da ~2M tri, A-pose, 3 texture 2K)
-> mesh decimata (~25k tri), texture 1K, scheletro umanoide, skinning automatico, 5 animazioni -> glTF separato.

Uso: blender -b --factory-startup SORGENTE.blend -P build_char_hires.py -- nome attacco [tris] [--debug]
  attacco: thrust | slash | shoot
Fronte verso +Y in Blender (= -Z in Godot), piedi a z=0, altezza finale ~1,52 m (scala 0,8: stessa taglia delle figurine
precedenti). Animazioni: idle_loop, walk_loop, attack, hit, death (gli stessi nomi di personaggi/).
"""
import bpy, sys, os, math, bmesh
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_characters as BC

CUSTOM = os.path.abspath(os.path.join(HERE, "..", ".."))
SCALE = 0.8
# giunti (m, prima della scala): x positivo = destra del personaggio
J = dict(
    hips=(0, 0, 0.88), spine=(0, 0, 0.98), chest=(0, 0, 1.40), neck=(0, 0, 1.50), head_top=(0, 0, 1.80),
    shoulder=(0.20, 0, 1.37), elbow=(0.40, 0, 1.11), wrist=(0.47, 0, 0.93), hand_end=(0.51, 0, 0.80),
    hip=(0.10, 0, 0.88), knee=(0.11, 0, 0.47), ankle=(0.11, 0, 0.09), toe=(0.11, 0.15, 0.03),
)


def S(v):
    return Vector(v) * SCALE


def armature(name):
    d = bpy.data.armatures.new(name)
    a = bpy.data.objects.new(name, d)
    bpy.context.scene.collection.objects.link(a)
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}

    def add(n, h, t, p, conn=False):
        b = d.edit_bones.new(n); b.head, b.tail = S(h), S(t); b.roll = 0
        if p:
            b.parent = eb[p]; b.use_connect = conn
        eb[n] = b
    add("root", (0, 0, 0), (0, 0, 0.2), None)
    add("hips", J["hips"], J["spine"], "root")
    add("spine", J["spine"], J["chest"], "hips", True)
    add("neck", J["chest"], J["neck"], "spine", True)
    add("head", J["neck"], J["head_top"], "neck", True)
    for s, x in (("R", 1), ("L", -1)):
        m = lambda p: (p[0] * x, p[1], p[2])
        add(f"upperarm.{s}", m(J["shoulder"]), m(J["elbow"]), "spine")
        add(f"forearm.{s}", m(J["elbow"]), m(J["wrist"]), f"upperarm.{s}", True)
        add(f"hand.{s}", m(J["wrist"]), m(J["hand_end"]), f"forearm.{s}", True)
        add(f"thigh.{s}", m(J["hip"]), m(J["knee"]), "hips")
        add(f"shin.{s}", m(J["knee"]), m(J["ankle"]), f"thigh.{s}", True)
        add(f"foot.{s}", m(J["ankle"]), m(J["toe"]), f"shin.{s}", True)
    bpy.ops.object.mode_set(mode="OBJECT")
    d.display_type = "STICK"
    for pb in a.pose.bones:
        pb.rotation_mode = "XYZ"
    return a


def prepare(ob, target):
    ob.rotation_euler = (0, 0, math.pi)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    ob.location = (-(min(v.x for v in bb) + max(v.x for v in bb)) / 2, -(min(v.y for v in bb) + max(v.y for v in bb)) / 2,
                   -min(v.z for v in bb))
    bpy.ops.object.transform_apply(location=True)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"; m.ratio = min(1.0, target / tris); m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)
    ob.scale = (SCALE,) * 3
    bpy.ops.object.transform_apply(scale=True)
    for p in ob.data.polygons:
        p.use_smooth = True
    return tris


def textures(ob, px=1024):
    for im in bpy.data.images:
        if im.size[0] > px:
            im.scale(px, px)
    # il glTF vuole ORM in un'unica immagine: R=AO, G=roughness, B=metallo; qui B=metallo, G=roughness gia' collegati
    # ma serve che l'alpha della base sia opaca
    for im in bpy.data.images:
        im.alpha_mode = "NONE" if im.name == "Image_0" else im.alpha_mode


def skin(ob, arm):
    ob.parent = arm
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True); arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    me = ob.data
    bones = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
    # vertici senza peso (isole non collegate): osso piu' vicino
    gi = {vg.index: vg.name for vg in ob.vertex_groups}
    bad = []
    for v in me.vertices:
        if sum(g.weight for g in v.groups) < 0.01:
            bad.append(v.index)
    def dist(p, a, b):
        ab = b - a; t = max(0, min(1, (p - a).dot(ab) / ab.length_squared)); return (p - (a + ab * t)).length
    for vi in bad:
        p = me.vertices[vi].co
        ds = sorted((dist(p, *bones[n]), n) for n in bones)[:3]
        ws = [1.0 / (d + 0.03) ** 4 for d, _ in ds]; tot = sum(ws)
        for (d, bn), w in zip(ds, ws):                     # fusione morbida tra le 3 ossa piu' vicine
            (ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)).add([vi], w / tot, "REPLACE")
    # al massimo 4 influenze (limite glTF)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT") if False else None
    bpy.ops.object.vertex_group_limit_total(limit=4)
    return len(bad)


def render_debug(ob, arm, path, frames):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (.4, .4, .4, 1)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.0
    l = bpy.data.objects.new("s", bpy.data.lights.new("s", "SUN")); sc.collection.objects.link(l)
    l.rotation_euler = (.9, .2, .5); l.data.energy = 3
    arm.show_in_front = True; arm.data.display_type = "STICK"
    sc.render.resolution_x, sc.render.resolution_y = 480, 600
    for k, (act, fr, az) in enumerate(frames):
        if act:
            arm.animation_data.action = bpy.data.actions[act]; sc.frame_set(fr)
        else:
            arm.animation_data.action = None
            for pb in arm.pose.bones: pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
            sc.frame_set(1)
        a = math.radians(az)
        cam.location = (math.sin(a) * 6, -math.cos(a) * 6 , 0.78); cam.rotation_euler = (math.pi / 2, 0, a)
        sc.render.filepath = f"{path}_{k}.png"; bpy.ops.render.render(write_still=True)


def export(name, ob, arm):
    d = os.path.join(CUSTOM, "personaggi_nuovi", name)
    os.makedirs(d, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for c in arm.children_recursive: c.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=os.path.join(d, name + ".gltf"), export_format="GLTF_SEPARATE", use_selection=True,
                              export_yup=True, export_apply=False, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO", export_extras=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_def_bones=False, export_anim_single_armature=True, export_force_sampling=True,
                              export_frame_range=False)
    return d


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    name, attack = a[0], a[1]
    target = int(a[2]) if len(a) > 2 and a[2].isdigit() else 25000
    debug = "--debug" in a
    ob = bpy.data.objects["Mesh_0"]
    for o in list(bpy.data.objects):
        if o != ob: bpy.data.objects.remove(o)
    n0 = prepare(ob, target)
    textures(ob)
    ob.name = "SM_" + name
    arm = armature("RIG_" + name)
    bad = skin(ob, arm)
    acts = BC.make_actions(arm, {"attack": attack}, name)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print(f"RESULT {name}: {n0} -> {tris} tris, senza peso {bad}, azioni {[x.name for x in acts]}")
    tmp = os.environ.get("SCRATCH", "/tmp")
    if debug:
        render_debug(ob, arm, os.path.join(tmp, "dbg_" + name),
                     [(None, 1, 0), (None, 1, 90), ("walk_loop", 7, 0), ("attack", 10, 30), ("death", 20, 40)])
    else:
        d = export(name, ob, arm)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(CUSTOM, "_source", "blend", f"pn_{name}.blend"), compress=True)
        print("EXPORT", d)
