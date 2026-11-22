"""Prepara nave achea e torcia (creati dall'autore con mesh.ai, art_source/models/*.blend) per Godot.

Uso (un solo Blender alla volta; il .blend sorgente dev'essere quello aperto):
  blender -b art_source/models/nave_achea.blend --factory-startup -P build_nave_torcia.py -- nave
  blender -b art_source/models/torcia.blend     --factory-startup -P build_nave_torcia.py -- torcia
Per ciascuno esporta la versione normale e la _lod (decimazione Collapse + texture ridotte, JPEG):
  navi/nave_achea/nave_achea[_lod].gltf        lunga 12 m, prua verso -Z Godot (+Y Blender), origine al centro, z=0 al punto piu' basso (remi)
  campo/luci/torcia_achea/torcia_achea[_lod].gltf  lunga 0,62 m, origine nel punto di presa, testa verso +Y Godot, fiamma a carte (emissiva)
Texture: Image_0 base color, Image_1 ORM (G=roughness, B=metallo), Image_2 normale (mesh.ai).
"""
import bpy, sys, os, math, json
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
CUSTOM = os.path.abspath(os.path.join(HERE, "..", ".."))
TARGET = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "nave"
# (cartella, lunghezza m, [(suffisso, triangoli, px texture)])
CFG = {
    "nave": ("navi/nave_achea", "nave_achea", 12.0, [("", 32000, 1024), ("_lod", 7000, 512)]),
    "torcia": ("campo/luci/torcia_achea", "torcia_achea", 0.62, [("", 5000, 1024), ("_lod", 1500, 512)]),
}


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def prepare(ob, length):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if TARGET == "nave":
        ob.rotation_mode = "XYZ"
        ob.rotation_euler = (0, 0, -math.pi / 2)          # prua da -X a +Y
        bpy.ops.object.transform_apply(rotation=True)
    bb = [Vector(c) for c in ob.bound_box]
    dims = ob.dimensions
    k = length / max(dims)
    ob.scale = (k, k, k)
    bpy.ops.object.transform_apply(scale=True)
    bb = [Vector(c) for c in ob.bound_box]
    cx = (min(v.x for v in bb) + max(v.x for v in bb)) / 2
    cy = (min(v.y for v in bb) + max(v.y for v in bb)) / 2
    if TARGET == "nave":
        ob.location = (-cx, -cy, -min(v.z for v in bb))
    else:
        # origine nel punto di presa: 36% dal basso del bastone (avvolgimento in cuoio)
        zmin, zmax = min(v.z for v in bb), max(v.z for v in bb)
        ob.location = (-cx, -cy, -(zmin + (zmax - zmin) * 0.36))
    bpy.ops.object.transform_apply(location=True)
    return k


def flame(ob_zmax, k):
    """Tre carte incrociate di fiamma sopra la gabbia (texture condivisa campo/_tex/flame_*)."""
    bpy.ops.object.select_all(action="DESELECT")
    verts, faces, uvs = [], [], []
    w, h = 0.20, 0.30
    z0 = ob_zmax - 0.17
    for i, a in enumerate((0, 60, 120)):
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        base = len(verts)
        for (u, v) in ((0, 0), (1, 0), (1, 1), (0, 1)):
            x = (u - 0.5) * w
            verts.append((x * c, x * s, z0 + v * h))
        faces.append((base, base + 1, base + 2, base + 3))
    me = bpy.data.meshes.new("flame_m")
    me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name="UVMap")
    for f in me.polygons:
        for j, li in enumerate(f.loop_indices):
            uv.data[li].uv = ((0, 0), (1, 0), (1, 1), (0, 1))[j]
    mat = bpy.data.materials.new("M_flame")
    mat.use_nodes = True
    ob = bpy.data.objects.new("flame", me)
    me.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def apply_flame_patch(gltf_path):
    j = json.load(open(gltf_path))
    for m in j.get("materials", []):
        if m["name"] == "M_flame":
            imgs = j.setdefault("images", []); texs = j.setdefault("textures", []); smp = j.setdefault("samplers", [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}])
            def add(uri, mime):
                imgs.append({"uri": uri, "mimeType": mime, "name": os.path.splitext(os.path.basename(uri))[0]})
                texs.append({"source": len(imgs) - 1, "sampler": len(smp) - 1}); return len(texs) - 1
            c = add("../../_tex/flame_c.png", "image/png"); e = add("../../_tex/flame_e.jpg", "image/jpeg")
            m["pbrMetallicRoughness"] = {"baseColorTexture": {"index": c}, "metallicFactor": 0.0, "roughnessFactor": 1.0}
            m["emissiveFactor"] = [1, 1, 1]; m["emissiveTexture"] = {"index": e}
            m["extensions"] = {"KHR_materials_emissive_strength": {"emissiveStrength": 2}}
            m["alphaMode"] = "MASK"; m["alphaCutoff"] = 0.3; m["doubleSided"] = True
            j.setdefault("extensionsUsed", [])
            if "KHR_materials_emissive_strength" not in j["extensionsUsed"]:
                j["extensionsUsed"].append("KHR_materials_emissive_strength")
    json.dump(j, open(gltf_path, "w"), indent=1)


def main():
    folder, name, length, variants = CFG[TARGET]
    src = bpy.data.objects["Mesh_0"]
    for o in list(bpy.data.objects):
        if o != src: bpy.data.objects.remove(o)
    n0 = tris(src)
    k = prepare(src, length)
    zmax = max((src.matrix_world @ Vector(c)).z for c in src.bound_box)
    out_dir = os.path.join(CUSTOM, folder)
    os.makedirs(out_dir, exist_ok=True)
    mat0 = src.data.materials[0]
    node_orig = {nd.name: nd.image for nd in mat0.node_tree.nodes if nd.type == "TEX_IMAGE"}
    node_orig = {k: (v, v.name) for k, v in node_orig.items()}
    # versione piena (hi) conservata: le varianti si decimano ciascuna dalla copia originale della mesh
    base_mesh = src.data.copy()
    for suffix, target, px in variants:
        m = src.modifiers.new("dec", "DECIMATE")
        m.decimate_type = "COLLAPSE"; m.ratio = min(1.0, target / tris(src)); m.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = src
        bpy.ops.object.modifier_apply(modifier=m.name)
        for p in src.data.polygons: p.use_smooth = True
        # texture: copie ridimensionate, nomi per variante, JPEG
        mat = src.data.materials[0]
        for nd in mat.node_tree.nodes:
            if nd.type == "TEX_IMAGE":
                orig, oname = node_orig[nd.name]
                im = orig.copy()
                role = {"Image_0": "c", "Image_1": "r", "Image_2": "n"}[oname]
                im.name = f"{name}{suffix}_{role}"
                im.filepath_raw = os.path.join(out_dir, im.name + ".jpg")
                im.file_format = "JPEG"
                im.alpha_mode = "NONE"
                nd.image = im
        # gltf: il colore/ORM/normale vanno in canali separati nello shader mesh.ai; l'export li rilegge dai nodi
        objs = [src]
        if TARGET == "torcia":
            objs.append(flame(zmax, k))
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs: o.select_set(True)
        bpy.context.view_layer.objects.active = src
        path = os.path.join(out_dir, name + suffix + ".gltf")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", use_selection=True, export_yup=True,
                                  export_apply=False, export_texcoords=True, export_normals=True, export_materials="EXPORT",
                                  export_image_format="JPEG", export_jpeg_quality=85, export_texture_dir="", export_animations=False)
        import subprocess
        for role in "cnr":
            subprocess.run(["/usr/bin/python3", "-c", "import sys;from PIL import Image;f,px=sys.argv[1],int(sys.argv[2]);im=Image.open(f);"
                            "im.convert('RGB').resize((px,px),Image.LANCZOS).save(f,quality=85,optimize=True,icc_profile=None) if im.size[0]>px else None",
                            os.path.join(out_dir, f"{name}{suffix}_{role}.jpg"), str(px)], check=True)
        if TARGET == "torcia":
            apply_flame_patch(path)
            bpy.data.objects.remove(objs[1])
        print("RESULT", name + suffix, n0, "->", tris(src), path)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(CUSTOM, "_source", "blend", ("navi" if TARGET == "nave" else "campo"), name + ".blend"), compress=True)


main()
