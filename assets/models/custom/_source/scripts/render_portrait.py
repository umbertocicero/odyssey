"""Ritratto di un personaggio riggato: testa e spalle, luce morbida calda, sfondo trasparente.

Uso: blender -b --factory-startup -P render_portrait.py -- in.glb out.png [az] [zc] [scala] [px]
az = angolo della camera (gradi, 0 = frontale, +Y e' il fronte dei modelli); zc = quota del centro; scala = lato dell'inquadratura (m).
"""
import bpy, sys, math
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, out = a[0], a[1]
az = float(a[2]) if len(a) > 2 else 18.0
zc = float(a[3]) if len(a) > 3 else 1.24
scale = float(a[4]) if len(a) > 4 else 0.78
px = int(a[5]) if len(a) > 5 else 512

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
arm = next((o for o in sc.objects if o.type == "ARMATURE"), None)
if arm:
    shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
    for o in list(sc.objects):
        if o in shapes or (o.type == "MESH" and o.parent is None and o.name.startswith("Icosphere")):
            bpy.data.objects.remove(o)
    act = next((x for x in bpy.data.actions if x.name.startswith("idle")), None)
    if act:
        arm.animation_data_create().action = act
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        sc.frame_set(0)

# nel ritratto non servono scudo e lancia (skinnati ad avambracci e mani): via i vertici di quei gruppi
import bmesh
for o in [o for o in sc.objects if o.type == "MESH"]:
    names = {vg.index: vg.name for vg in o.vertex_groups}
    kill = {"forearm.L", "hand.L", "forearm.R", "hand.R"}
    bm = bmesh.new(); bm.from_mesh(o.data)
    dl = bm.verts.layers.deform.active
    if dl is not None:
        dead = [v for v in bm.verts if any(names.get(i) in kill and w > 0.4 for i, w in v[dl].items())]
        bmesh.ops.delete(bm, geom=dead, context="VERTS")
        bm.to_mesh(o.data)
    bm.free()
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = px
sc.render.film_transparent = True
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.9, 0.62, 0.42, 1); bg.inputs[1].default_value = 0.85


def sun(rot, energy, col, ang=14):
    d = bpy.data.lights.new("s", "SUN"); d.energy = energy; d.color = col; d.angle = math.radians(ang)
    o = bpy.data.objects.new("s", d); o.rotation_euler = [math.radians(v) for v in rot]; sc.collection.objects.link(o)


sun((62, 0, 150), 3.4, (1.0, 0.82, 0.62), 25)     # luce principale morbida, calda, da davanti a sinistra
sun((75, 0, -35), 2.2, (1.0, 0.66, 0.42), 18)     # controluce dorato
sun((40, 0, 215), 1.0, (0.78, 0.82, 1.0), 40)     # riempimento freddo debole

cam_d = bpy.data.cameras.new("c"); cam_d.type = "ORTHO"; cam_d.ortho_scale = scale
cam = bpy.data.objects.new("c", cam_d); sc.collection.objects.link(cam); sc.camera = cam
r = math.radians(az)
tgt = Vector((0, 0.0, zc))
dirv = Vector((math.sin(r), math.cos(r), 0.06))
cam.location = tgt + dirv.normalized() * 6
cam.rotation_euler = (-dirv).to_track_quat("-Z", "Y").to_euler()
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
