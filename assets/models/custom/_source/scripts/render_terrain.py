"""Anteprime del terreno con erba istanziata (EEVEE, luce di tramonto in controluce).

Uso: blender -b --factory-startup -P render_terrain.py -- <shot> <out.png> [--mobile]
shot: overview | hero | close | cards
Lanciare UNA render alla volta (render paralleli bloccano il PC).
"""
import bpy, sys, os, math, random
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
shot, out = argv[0], argv[1]
mobile = "--mobile" in argv
HERE = os.path.dirname(os.path.abspath(__file__))
TER = os.path.abspath(os.path.join(HERE, "..", "..", "terreno"))

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"
sc.render.resolution_x, sc.render.resolution_y = (1280, 720)
ee = sc.eevee
for k, v in (("taa_render_samples", 48), ("use_shadows", True), ("use_raytracing", True),
             ("shadow_ray_count", 2), ("shadow_step_count", 8)):
    try:
        setattr(ee, k, v)
    except Exception:
        pass
try:
    ee.ray_tracing_options.resolution_scale = "2"
    ee.fast_gi_method = "GLOBAL_ILLUMINATION"
    ee.use_fast_gi = True
except Exception:
    pass

# cielo di tramonto: gradiente pesca-arancio, ambiente caldo
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
nt = w.node_tree
bg = nt.nodes["Background"]
sky = nt.nodes.new("ShaderNodeTexSky")
try:
    sky.sky_type = "MULTIPLE_SCATTERING"
except Exception:
    try:
        sky.sky_type = "NISHITA"
    except Exception:
        pass
try:
    sky.sun_elevation = math.radians(9); sky.sun_rotation = math.radians(90); sky.altitude = 200
    sky.air_density = 2.2; sky.dust_density = 4.0
except Exception:
    pass
# gradiente semplice: arancio all'orizzonte, pesca e rosa in alto
tc = nt.nodes.new("ShaderNodeTexCoord"); sx = nt.nodes.new("ShaderNodeSeparateXYZ")
ramp = nt.nodes.new("ShaderNodeValToRGB")
nt.links.new(tc.outputs["Generated"], sx.inputs[0]); nt.links.new(sx.outputs[2], ramp.inputs[0])
cr = ramp.color_ramp
cr.elements[0].position = 0.0; cr.elements[0].color = (1.0, 0.55, 0.28, 1)
cr.elements[1].position = 0.45; cr.elements[1].color = (0.75, 0.52, 0.55, 1)
nt.links.new(ramp.outputs[0], bg.inputs[0])
bg.inputs[1].default_value = 0.7

def sun(rot_deg, energy, col, angle=4):
    d = bpy.data.lights.new("sun", "SUN"); d.energy = energy; d.color = col; d.angle = math.radians(angle)
    o = bpy.data.objects.new("sun", d); o.rotation_euler = [math.radians(a) for a in rot_deg]
    sc.collection.objects.link(o)
    return o

# sole basso a nord-ovest (dietro la scena rispetto alla camera da sud-est): controluce dorato
sun((72, 0, 200), 4.2, (1.0, 0.70, 0.45), 3)
sun((40, 0, 20), 0.5, (0.75, 0.80, 1.0), 20)  # riempimento freddo dal cielo opposto

def imp(fn):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(TER, fn))
    return [o for o in bpy.data.objects if o not in before]

terr = imp("terreno_pianura_mobile.gltf" if mobile else "terreno_pianura.gltf")
grass = imp("erba_ciuffi.gltf")
gcol = bpy.data.collections.new("erba"); sc.collection.children.link(gcol)
protos = {}
for o in grass:
    for c in o.users_collection:
        c.objects.unlink(o)
    gcol.objects.link(o)
    o.location = (0, 0, 0)
    protos[o.name.split(".")[0]] = o
gcol.hide_render = True
lay = bpy.context.view_layer.layer_collection.children["erba"]; lay.exclude = False

# acqua semplice per il mare incassato
bpy.ops.mesh.primitive_cube_add(size=1, location=(-23.8, -1.5, -0.32))
sea = bpy.context.active_object; sea.scale = (4.4, 41, 0.4)
mw = bpy.data.materials.new("acqua"); mw.use_nodes = True
b = mw.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.03, 0.16, 0.20, 1); b.inputs["Roughness"].default_value = 0.08
b.inputs["Alpha"].default_value = 0.85
sea.data.materials.append(mw)

top = next(o for o in terr if o.name.startswith("Terreno_Superficie"))
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(top, dg)

# maschere: B densita' erba, A secchezza (riga 0 = sud, come le UV)
img = bpy.data.images.load(os.path.join(TER, "textures", "T_terreno_maschere.png"))
W_, H_ = img.size
mk = np.empty(W_ * H_ * 4, np.float32); img.pixels.foreach_get(mk); mk = mk.reshape(H_, W_, 4)

img2 = bpy.data.images.load(os.path.join(TER, "textures", "T_terreno_maschere2.png"))
mk2 = np.empty(W_ * H_ * 4, np.float32); img2.pixels.foreach_get(mk2); mk2 = mk2.reshape(H_, W_, 4)

def mask2_at(x, y):
    i = int(np.clip((x + 26) / 52 * W_, 0, W_ - 1)); j = int(np.clip((y + 22) / 52 * H_, 0, H_ - 1))
    return mk2[j, i]

def mask_at(x, y):
    i = int(np.clip((x + 26) / 52 * W_, 0, W_ - 1)); j = int(np.clip((y + 22) / 52 * H_, 0, H_ - 1))
    return mk[j, i]

AREAS = {
    "overview": ((-26, 26, -22, 30), 0.26, ["Prato_Denso_A", "Prato_Denso_B", "Prato_Denso_C", "Erba_PunteSecche"]),
    "hero": ((-26, 26, -22, 22), 0.10, None),
    "ground": ((-14, 26, -22, 8), 0.075, None),
    "close": ((-4, 6, -6, 4), 0.07, None),
}

def pick_variant(rnd, dry, tall=0.5):
    lush = [("Erba_Alta", 3), ("Erba_Media", 4), ("Erba_Bassa", 3), ("Prato_Denso_A", 5), ("Prato_Denso_C", 5), ("Erbacce_Foglie", 0.7),
            ("Fiori_Selvatici", 0.6)]
    dryl = [("Erba_PunteSecche", 4), ("Erba_Secca", 3), ("Graminacee_Semi", 0.7), ("Prato_Denso_B", 5), ("Erba_Media", 2)]
    lush = lush + [("Erba_Lunga", 6 * tall ** 2), ("Prato_Alto", 7 * tall ** 2)]
    dryl = dryl + [("Erba_Lunga_Secca", 6 * tall ** 2), ("Prato_Alto", 3 * tall ** 2)]
    pool = dryl if rnd.random() < dry else lush
    tot = sum(wt for _, wt in pool); r = rnd.random() * tot
    for n, wt in pool:
        r -= wt
        if r <= 0:
            return n
    return pool[-1][0]

def scatter(area, step, fixed):
    x0, x1, y0, y1 = area
    rnd = random.Random(7)
    pts, idx, rot, scl, dryv = [], [], [], [], []
    names = sorted(protos)
    y = y0
    while y < y1:
        x = x0
        while x < x1:
            px, py = x + rnd.uniform(-0.5, 0.5) * step, y + rnd.uniform(-0.5, 0.5) * step
            m = mask_at(px, py)
            if rnd.random() < m[2] ** 0.8:
                hit = bvh.ray_cast(Vector((px, py, 10)), Vector((0, 0, -1)))
                if hit[0] is not None and hit[1].z > 0.6:
                    m2 = mask2_at(px, py)
                    n = rnd.choice(fixed) if fixed else pick_variant(rnd, float(m[3]), float(m2[0]))
                    pts.append(hit[0] - Vector((0, 0, 0.02)))
                    idx.append(names.index(n))
                    rot.append(rnd.uniform(0, math.tau))
                    scl.append(rnd.uniform(0.85, 1.15) * (0.6 + 0.6 * float(m2[0])) * (0.7 + 0.5 * float(m[2])))
                    dryv.append(float(m[3]) * rnd.uniform(0.6, 1.0))
            x += step
        y += step
    return pts, idx, rot, scl, dryv, names

def instancer(pts, idx, rot, scl, dryv, names):
    me = bpy.data.meshes.new("punti_erba")
    me.from_pydata([tuple(p) for p in pts], [], [])
    a = me.attributes.new("variant", "INT", "POINT"); a.data.foreach_set("value", idx)
    r = me.attributes.new("rotz", "FLOAT", "POINT"); r.data.foreach_set("value", rot)
    s = me.attributes.new("scl", "FLOAT", "POINT"); s.data.foreach_set("value", scl)
    dv = me.attributes.new("dry", "FLOAT", "POINT"); dv.data.foreach_set("value", dryv)
    # tinta per istanza come nello shader Godot: verde fresco -> paglia secondo la secchezza
    for mat in bpy.data.materials:
        if mat.name.startswith("M_Erba_Cards") and mat.node_tree:
            t = mat.node_tree; bs = t.nodes.get("Principled BSDF")
            lk = bs.inputs["Base Color"].links
            if not lk:
                continue
            src = lk[0].from_socket
            at = t.nodes.new("ShaderNodeAttribute"); at.attribute_type = "INSTANCER"; at.attribute_name = "dry"
            mx = t.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"
            mx.inputs[6].default_value = (1, 1, 1, 1); mx.inputs[7].default_value = (1.25, 1.05, 0.62, 1)
            t.links.new(at.outputs["Fac"], mx.inputs[0])
            mu = t.nodes.new("ShaderNodeMix"); mu.data_type = "RGBA"; mu.blend_type = "MULTIPLY"; mu.inputs[0].default_value = 1
            t.links.new(src, mu.inputs[6]); t.links.new(mx.outputs[2], mu.inputs[7])
            t.links.new(mu.outputs[2], bs.inputs["Base Color"])
    ob = bpy.data.objects.new("erba_istanze", me); sc.collection.objects.link(ob)
    ng = bpy.data.node_groups.new("scatter", "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    N = ng.nodes; L = ng.links
    gi = N.new("NodeGroupInput"); go = N.new("NodeGroupOutput")
    ci = N.new("GeometryNodeCollectionInfo"); ci.inputs["Collection"].default_value = gcol
    ci.inputs["Separate Children"].default_value = True; ci.inputs["Reset Children"].default_value = True
    ci.transform_space = "ORIGINAL"
    iop = N.new("GeometryNodeInstanceOnPoints")
    def attr(name, typ):
        n = N.new("GeometryNodeInputNamedAttribute"); n.data_type = typ; n.inputs["Name"].default_value = name
        return n
    av, ar, as_ = attr("variant", "INT"), attr("rotz", "FLOAT"), attr("scl", "FLOAT")
    comb = N.new("ShaderNodeCombineXYZ")
    L.new(ar.outputs["Attribute"], comb.inputs["Z"])
    L.new(gi.outputs[0], iop.inputs["Points"])
    L.new(ci.outputs[0], iop.inputs["Instance"])
    iop.inputs["Pick Instance"].default_value = True
    L.new(av.outputs["Attribute"], iop.inputs["Instance Index"])
    L.new(comb.outputs[0], iop.inputs["Rotation"])
    L.new(as_.outputs["Attribute"], iop.inputs["Scale"])
    L.new(iop.outputs[0], go.inputs[0])
    mod = ob.modifiers.new("scatter", "NODES"); mod.node_group = ng
    return ob

cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam

def look(loc, target, lens):
    cam.location = loc; cam_d.lens = lens
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam_d.clip_end = 400

if shot in AREAS:
    area, step, fixed = AREAS[shot]
    if mobile:
        step *= 1.6
    data = scatter(area, step, fixed)
    print("istanze", len(data[0]), flush=True)
    instancer(*data)
if shot == "overview":
    look((44, -52, 46), (0, 4, 0), 30)
elif shot == "ground":
    look((14, -17.5, 1.0), (-6, 3, 1.1), 28)
elif shot == "hero":
    look((13, -16, 9.0), (-1, 0, 0.3), 32)
elif shot == "close":
    look((5.5, -4.5, 2.4), (0.5, 0.5, 0.25), 30)
elif shot == "cards":
    for o in terr:
        o.hide_render = True
    sea.hide_render = True
    gcol.hide_render = False
    for i, o in enumerate(sorted(protos.values(), key=lambda o: o.name)):
        o.location = ((i % 5) * 0.9 - 1.8, (i // 5) * -0.9, 0)
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, -0.5, 0))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("piano"); fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.30, 0.22, 0.14, 1)
    fl.data.materials.append(fm)
    look((0, -3.6, 1.1), (0, -0.5, 0.25), 42)

sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("render", out)
