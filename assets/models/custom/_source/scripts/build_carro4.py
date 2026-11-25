"""Carro a 4 ruote (Wooden_Cart_3.blend, carro centrale) -> campo/carri/carro_4_ruote/carro_4_ruote.gltf.

Uso (un solo Blender alla volta):
  blender -b Wooden_Cart_3.blend --factory-startup -P build_carro4.py -- <cartella jpg gia' ridimensionati> <cartella output>
I jpg (carro4_<nome>.jpg) si ricavano dalle texture originali del blend (tif/png, 1K-4K) con Pillow.
Convenzioni: metri, fronte (timoni) verso +Y Blender (= -Z Godot), origine al centro in pianta, z=0 alla ruota piu' bassa.
Dei 3 carri del blend tiene quello a 4 ruote (centro, |y|<1.1).
"""
import bpy, sys, os, math
from mathutils import Vector
jpgdir, out_dir = sys.argv[sys.argv.index("--") + 1:][:2]
TEX = {"A bit dark wood": "wood_dark", "Black metal": "metal_black", "Metal_Chain": "metal_black", "Bronze": "bronze",
       "wooden_cart01": "wood_floor", "wooden_cart02": "wood_slats", "wooden_cart04": "wood_trim"}
ROUGH = {"wood_dark": 0.85, "metal_black": 0.6, "bronze": 0.5, "wood_floor": 0.9, "wood_slats": 0.9, "wood_trim": 0.85}

keep = []
for o in list(bpy.data.objects):
    if o.type != "MESH" or o.name == "Plane":
        bpy.data.objects.remove(o); continue
    c = o.matrix_world @ (sum((Vector(v) for v in o.bound_box), Vector()) / 8)
    if abs(c.y) < 1.1: keep.append(o)
    else: bpy.data.objects.remove(o)
print("KEPT", len(keep))
# Mapping node di wooden_cart01: porta scala/offset nelle UV (il gltf non lo trasporta in modo affidabile)
mp = bpy.data.materials["wooden_cart01"].node_tree.nodes.get("Mapping")
if mp:
    print("MAPPING", tuple(mp.inputs["Location"].default_value), tuple(mp.inputs["Rotation"].default_value), tuple(mp.inputs["Scale"].default_value))
bpy.ops.object.select_all(action="DESELECT")
for o in keep: o.select_set(True)
bpy.context.view_layer.objects.active = keep[0]
bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.name = "carro_4_ruote"; ob.data.name = "carro_4_ruote"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if mp:
    loc = mp.inputs["Location"].default_value; sc = mp.inputs["Scale"].default_value
    idx = [i for i, s in enumerate(ob.material_slots) if s.material.name == "wooden_cart01"][0]
    uv = ob.data.uv_layers.active.data
    for p in ob.data.polygons:
        if p.material_index == idx:
            for li in p.loop_indices:
                u = uv[li].uv; uv[li].uv = (u.x * sc[0] + loc[0], u.y * sc[1] + loc[1])
# fronte +X -> +Y
ob.rotation_euler = (0, 0, math.radians(90)); bpy.ops.object.transform_apply(rotation=True)
bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
lo = [min(v[i] for v in bb) for i in range(3)]; hi = [max(v[i] for v in bb) for i in range(3)]
ob.location = (-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]); bpy.ops.object.transform_apply(location=True)
print("DIMS", [round(d, 3) for d in ob.dimensions], "TRIS", sum(len(p.vertices) - 2 for p in ob.data.polygons))
# materiali: solo base color JPEG + roughness fissa
for slot in ob.material_slots:
    m = slot.material; name = TEX[m.name]
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    img = bpy.data.images.load(os.path.join(jpgdir, f"carro4_{name}.jpg")); img.colorspace_settings.name = "sRGB"
    for l in list(nt.links):
        if l.to_node == bsdf and l.to_socket.name in ("Roughness", "Normal"): nt.links.remove(l)
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE"); tex.image = img
    for l in list(nt.links):
        if l.to_socket.name == "Vector" and l.to_node == tex: nt.links.remove(l)
    bsdf.inputs["Roughness"].default_value = ROUGH[name]; bsdf.inputs["Metallic"].default_value = 0.0
    m.name = "carro4_" + name
# materiali duplicati (Black metal e Metal_Chain) -> uno solo
first = {}
for i, slot in enumerate(ob.material_slots):
    key = slot.material.name.split(".")[0]
    if key in first:
        for p in ob.data.polygons:
            if p.material_index == i: p.material_index = first[key]
    else: first[key] = i
bpy.context.view_layer.objects.active = ob
bpy.ops.object.material_slot_remove_unused()
bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
os.makedirs(out_dir, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "carro_4_ruote.gltf"), export_format="GLTF_SEPARATE", use_selection=True,
    export_yup=True, export_apply=False, export_texcoords=True, export_normals=True, export_materials="EXPORT",
    export_image_format="JPEG", export_jpeg_quality=88, export_texture_dir="textures", export_animations=False)
print("EXPORTED")
