"""Anteprima di un .glb con luce calda da tramonto (EEVEE).

Uso: blender -b --factory-startup -P render_preview.py -- in.glb out.png [azione:frame ...] [--az 35] [--el 28] [--size 512]
Con piu' azione:frame genera un'immagine per posa (out_<i>.png).
"""
import bpy, sys, math, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
rest = argv[2:]
opts = {"--az": 35.0, "--el": 28.0, "--size": 512}
poses = []
i = 0
while i < len(rest):
    if rest[i] in opts:
        opts[rest[i]] = type(opts[rest[i]])(rest[i + 1]); i += 2
    else:
        poses.append(rest[i]); i += 1

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = opts["--size"]
sc.render.film_transparent = True
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"
try:
    sc.eevee.taa_render_samples = 32
    sc.eevee.use_shadows = True
except Exception:
    pass

w = bpy.data.worlds.new("W"); sc.world = w
w.use_nodes = True
bg = w.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.78, 0.52, 0.38, 1); bg.inputs[1].default_value = 0.9

def sun(rot, energy, col):
    d = bpy.data.lights.new("sun", "SUN"); d.energy = energy; d.color = col; d.angle = math.radians(8)
    o = bpy.data.objects.new("sun", d); o.rotation_euler = [math.radians(a) for a in rot]
    sc.collection.objects.link(o)

sun((55, 0, 150), 3.2, (1.0, 0.80, 0.60))    # luce principale dal davanti-destra
sun((70, 0, -20), 2.5, (1.0, 0.68, 0.40))    # controluce dorato da dietro

arm = next((o for o in sc.objects if o.type == "ARMATURE"), None)
if arm:
    shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
    for o in list(sc.objects):
        if o in shapes or (o.type == "MESH" and o.parent is None and o.name.startswith("Icosphere")):
            bpy.data.objects.remove(o)

def bbox():
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9,) * 3); mx = -mn
    for o in sc.objects:
        if o.type == "MESH":
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            for v in me.vertices:
                p = o.matrix_world @ v.co
                mn = Vector(map(min, mn, p)); mx = Vector(map(max, mx, p))
            ev.to_mesh_clear()
    return mn, mx

cam_d = bpy.data.cameras.new("cam"); cam_d.lens = 70
cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam

def frame_camera(mn, mx):
    c = (mn + mx) / 2
    r = (mx - mn).length / 2
    az, el = math.radians(opts["--az"]), math.radians(opts["--el"])
    d = r / math.tan(cam_d.angle / 2) * 1.08
    dirv = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    cam.location = c + dirv * d
    cam.rotation_euler = (-dirv).to_track_quat("-Z", "Y").to_euler()

if arm and arm.animation_data is None:
    arm.animation_data_create()
outs = []
if poses and arm:
    # stessa inquadratura per tutte le pose: bbox unione
    mn_all, mx_all = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for p in poses:
        a, f = p.split(":")
        act = next(x for x in bpy.data.actions if x.name.startswith(a))
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        sc.frame_set(int(f))
        mn, mx = bbox(); mn_all = Vector(map(min, mn_all, mn)); mx_all = Vector(map(max, mx_all, mx))
    frame_camera(mn_all, mx_all)
    for k, p in enumerate(poses):
        a, f = p.split(":")
        act = next(x for x in bpy.data.actions if x.name.startswith(a))
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        sc.frame_set(int(f))
        o = out.replace(".png", f"_{k}.png"); sc.render.filepath = o
        bpy.ops.render.render(write_still=True); outs.append(o)
else:
    if arm and arm.animation_data:
        arm.animation_data.action = None
        for t in arm.animation_data.nla_tracks:
            t.mute = True
        for pb in arm.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    mn, mx = bbox(); frame_camera(mn, mx)
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True); outs.append(out)
print("RENDERED", outs)
