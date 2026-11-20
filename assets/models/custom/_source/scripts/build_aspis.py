"""Scudo oplitico realistico (aspis) da OpenGameArt, CC0 (autore: ninelionar).
https://opengameart.org/content/aspis-hoplite-shield

Uso: blender -b <cartella zip estratto>/aspis.blend --factory-startup -P build_aspis.py
Tiene solo il low poly "Aspis (LP)" (~6.100 triangoli, PBR), lo porta con il bordo
inferiore a z = 0 e il fronte verso +Y (= -Z in Godot), ed esporta tre varianti con
texture ridotte a 2048 px (in _source/textures/aspis/, ricavate dalle 4K originali).
"""
import bpy, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit

VARIANTS = {"bronzo": "scudo_oplita_bronzo", "nero": "scudo_oplita_nero", "nero_usurato": "scudo_oplita_nero_usurato"}
TEX = os.path.join(okit.SRC, "textures", "aspis")

ob = bpy.data.objects["Aspis (LP)"]
for o in list(bpy.data.objects):
    if o is not ob:
        bpy.data.objects.remove(o)
for c in list(bpy.data.collections):
    bpy.data.collections.remove(c)
if ob.name not in bpy.context.scene.collection.objects:
    bpy.context.scene.collection.objects.link(ob)
ob.name = "SM_scudo_oplita"
ob.data.name = "SM_scudo_oplita"

# trasformazioni applicate, origine al bordo inferiore
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
minz = min(v.co.z for v in ob.data.vertices)
cx = sum(v.co.x for v in ob.data.vertices) / len(ob.data.vertices)
for v in ob.data.vertices:
    v.co.z -= minz
    v.co.x -= cx
# fronte: la bombatura (punto piu' lontano dall'imbracciatura) deve stare verso +Y
ys = [v.co.y for v in ob.data.vertices]
if abs(max(ys)) < abs(min(ys)):
    for v in ob.data.vertices:
        v.co.y = -v.co.y; v.co.x = -v.co.x
ob.data.update()


def material(var):
    m = bpy.data.materials.new(f"M_Aspis_{var}")
    m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes["Principled BSDF"]
    def img(name, cs, y):
        n = nt.nodes.new("ShaderNodeTexImage"); n.location = (-700, y)
        n.image = bpy.data.images.load(os.path.join(TEX, var, name + ".png"))
        n.image.name = f"T_Aspis_{var}_{name}"
        n.image.colorspace_settings.name = cs
        return n
    bc = img("BaseColor", "sRGB", 400); nt.links.new(bc.outputs["Color"], bsdf.inputs["Base Color"])
    mt = img("Metallic", "Non-Color", 120); nt.links.new(mt.outputs["Color"], bsdf.inputs["Metallic"])
    rg = img("Roughness", "Non-Color", -160); nt.links.new(rg.outputs["Color"], bsdf.inputs["Roughness"])
    nm = img("Normal", "Non-Color", -440)
    nmap = nt.nodes.new("ShaderNodeNormalMap"); nmap.location = (-300, -440)
    nt.links.new(nm.outputs["Color"], nmap.inputs["Color"]); nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


for var, name in VARIANTS.items():
    ob.data.materials.clear()
    ob.data.materials.append(material(var))
    p = os.path.join(okit.CUSTOM, "scudi_realistici", name + ".glb")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=p, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_materials="EXPORT", export_image_format="JPEG",
                              export_jpeg_quality=90, export_animations=False, export_skins=False)
    d = ob.dimensions
    print(f"OK {name} tris={sum(len(f.vertices) - 2 for f in ob.data.polygons)} dim=({d.x:.3f},{d.y:.3f},{d.z:.3f}) -> {p}")

# sorgente: variante bronzo, texture esterne (gia' in _source/textures/aspis)
ob.data.materials.clear(); ob.data.materials.append(bpy.data.materials["M_Aspis_bronzo"])
for m in [m for m in bpy.data.materials if m.users == 0]:
    bpy.data.materials.remove(m)
bpy.ops.outliner.orphans_purge(do_recursive=True)
out = os.path.join(okit.SRC, "blend", "scudi_realistici", "scudo_oplita.blend")
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.file.make_paths_relative() if bpy.data.filepath else None
bpy.ops.wm.save_as_mainfile(filepath=out, compress=True, relative_remap=True)
print("SAVED", out)
