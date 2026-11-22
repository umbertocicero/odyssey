"""Prepara catapulta, balista, carro e barella (creati dall'autore con mesh.ai, art_source/models/*.blend) per Godot.

Uso (un solo Blender alla volta; il .blend sorgente dev'essere quello aperto):
  blender -b art_source/models/catapulta.blend --factory-startup -P build_macchine.py -- catapulta
  (idem balista, carro, barella)
Per ciascuno esporta la versione normale e la _lod (decimazione Collapse + texture ridotte, JPEG) in
  campo/macchine/<nome>/<nome>[_lod].gltf
Convenzioni: metri, fronte verso +Y Blender (= -Z Godot), origine al centro in pianta e z=0 al punto piu' basso
(la barella: origine all'altezza dell'asse delle stanghe, lunga lungo Y).
Texture mesh.ai: Image_0 base color, Image_1 ORM (G=roughness, B=metallo), Image_2 normale.
"""
import bpy, sys, os, math, subprocess
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
CUSTOM = os.path.abspath(os.path.join(HERE, "..", ".."))
TARGET = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "catapulta"
# nome: (lunghezza m dell'asse piu' lungo, rotazione Z in gradi per portare il fronte su +Y, [(suffisso, triangoli, px texture)])
CFG = {
    "catapulta": (2.6, 90, [("", 24000, 1024), ("_lod", 6000, 512)]),
    "balista": (1.7, 90, [("", 24000, 1024), ("_lod", 6000, 512)]),
    "carro": (3.0, -90, [("", 24000, 1024), ("_lod", 6000, 512)]),
    "barella": (2.5, 90, [("", 12000, 1024), ("_lod", 3000, 512)]),
}


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def bbox(ob):
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    return [min(v[i] for v in bb) for i in range(3)], [max(v[i] for v in bb) for i in range(3)]


def prepare(ob, length, rot):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.rotation_mode = "XYZ"
    ob.rotation_euler = (0, 0, math.radians(rot))
    bpy.ops.object.transform_apply(rotation=True)
    k = length / max(ob.dimensions)
    ob.scale = (k, k, k)
    bpy.ops.object.transform_apply(scale=True)
    lo, hi = bbox(ob)
    z0 = lo[2]
    if TARGET == "barella":
        # asse delle stanghe: z centrale dei vertici alle estremita' (solo pali)
        ys = [v.co.y for v in ob.data.vertices]
        ymax = max(ys); ymin = min(ys); span = ymax - ymin
        zs = [v.co.z for v in ob.data.vertices if abs(v.co.y - (ymax + ymin) / 2) > 0.45 * span]
        z0 = (min(zs) + max(zs)) / 2
        print("POLE_AXIS_Z_ABOVE_BOTTOM", z0 - lo[2], "TOTAL_H", hi[2] - lo[2])
    ob.location = (-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -z0)
    bpy.ops.object.transform_apply(location=True)
    print("DIMS", [round(d, 3) for d in ob.dimensions])
    return k


def main():
    length, rot, variants = CFG[TARGET]
    src = bpy.data.objects["Mesh_0"]
    for o in list(bpy.data.objects):
        if o != src: bpy.data.objects.remove(o)
    n0 = tris(src)
    prepare(src, length, rot)
    out_dir = os.path.join(CUSTOM, "campo", "macchine", TARGET)
    os.makedirs(out_dir, exist_ok=True)
    mat0 = src.data.materials[0]
    node_orig = {nd.name: (nd.image, nd.image.name) for nd in mat0.node_tree.nodes if nd.type == "TEX_IMAGE"}
    for suffix, target, px in variants:
        m = src.modifiers.new("dec", "DECIMATE")
        m.decimate_type = "COLLAPSE"; m.ratio = min(1.0, target / tris(src)); m.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = src
        bpy.ops.object.modifier_apply(modifier=m.name)
        for p in src.data.polygons: p.use_smooth = True
        mat = src.data.materials[0]
        for nd in mat.node_tree.nodes:
            if nd.type == "TEX_IMAGE":
                orig, oname = node_orig[nd.name]
                im = orig.copy()
                role = {"Image_0": "c", "Image_1": "r", "Image_2": "n"}[oname]
                im.name = f"{TARGET}{suffix}_{role}"
                im.filepath_raw = os.path.join(out_dir, im.name + ".jpg")
                im.file_format = "JPEG"
                im.alpha_mode = "NONE"
                nd.image = im
        bpy.ops.object.select_all(action="DESELECT")
        src.select_set(True)
        bpy.context.view_layer.objects.active = src
        path = os.path.join(out_dir, TARGET + suffix + ".gltf")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", use_selection=True, export_yup=True,
                                  export_apply=False, export_texcoords=True, export_normals=True, export_materials="EXPORT",
                                  export_image_format="JPEG", export_jpeg_quality=85, export_texture_dir="", export_animations=False)
        for role in "cnr":
            subprocess.run(["/usr/bin/python3", "-c", "import sys;from PIL import Image;f,px=sys.argv[1],int(sys.argv[2]);im=Image.open(f);"
                            "im.convert('RGB').resize((px,px),Image.LANCZOS).save(f,quality=85,optimize=True,icc_profile=None) if im.size[0]>px else None",
                            os.path.join(out_dir, f"{TARGET}{suffix}_{role}.jpg"), str(px)], check=True)
        print("RESULT", TARGET + suffix, n0, "->", tris(src), path)
    os.makedirs(os.path.join(CUSTOM, "_source", "blend", "campo"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(CUSTOM, "_source", "blend", "campo", TARGET + ".blend"), compress=True)


main()
