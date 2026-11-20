"""Contact sheet: piu' modelli glTF/GLB in griglia, ognuno NORMALIZZATO ad altezza 1 (solo per l'anteprima:
le dimensioni reali sono nel README). Luce calda da tramonto come render_preview.py.

Uso: blender -b --factory-startup -P render_group.py -- out.png colonne file1.gltf file2.gltf ...
"""
import bpy, sys, math, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out, cols, files = argv[0], int(argv[1]), argv[2:]
CELL = 1.35
ROWP = 2.3   # passo tra le righe: in vista inclinata le file vicine si coprirebbero

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
placed = []
for i, f in enumerate(files):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    root = bpy.data.objects.new("root", None); sc.collection.objects.link(root)
    for o in new:
        if o.parent is None:
            o.parent = root
    bpy.context.view_layer.update()
    mn = Vector((1e9,) * 3); mx = -mn
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c); mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    h = max(mx.z - mn.z, 1e-4)
    s = 1.0 / max(h, (mx.x - mn.x) * 0.9, (mx.y - mn.y) * 0.9)
    r, c = divmod(i, cols)
    root.scale = (s, s, s)
    root.location = (c * CELL - (mn.x + mx.x) / 2 * s, -r * ROWP - (mn.y + mx.y) / 2 * s, -mn.z * s)
    placed.append(root)
rows = (len(files) + cols - 1) // cols

sc.render.engine = "BLENDER_EEVEE"
el = math.radians(28)
ortho = cols * CELL + 0.2
need = (rows - 1) * ROWP * math.sin(el) + math.cos(el) + 0.6
sc.render.resolution_x = min(2400, 300 * cols)
sc.render.resolution_x = max(sc.render.resolution_x, 700)
sc.render.resolution_y = int(sc.render.resolution_x * need / ortho)
sc.render.film_transparent = True
sc.view_settings.view_transform = "AgX"
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.78, 0.52, 0.38, 1); bg.inputs[1].default_value = 0.9
for rot, e, col in (((55, 0, 150), 3.2, (1.0, 0.80, 0.60)), ((70, 0, -20), 2.5, (1.0, 0.68, 0.40))):
    d = bpy.data.lights.new("s", "SUN"); d.energy = e; d.color = col; d.angle = math.radians(8)
    o = bpy.data.objects.new("s", d); o.rotation_euler = [math.radians(a) for a in rot]; sc.collection.objects.link(o)

cam_d = bpy.data.cameras.new("c"); cam_d.type = "ORTHO"; cam_d.ortho_scale = ortho
cam = bpy.data.objects.new("c", cam_d); sc.collection.objects.link(cam); sc.camera = cam
cx, cy = (cols - 1) * CELL / 2, -(rows - 1) * ROWP / 2
tgt = Vector((cx, cy, 0.5))
d = Vector((0, -math.cos(el), math.sin(el)))
cam.location = tgt + d * 20
cam.rotation_euler = (math.radians(90) - el, 0, 0)
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
