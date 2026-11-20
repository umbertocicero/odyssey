"""Importa modelli .glb scaricati (es. Sketchfab, NON Poly Haven) e li prepara per il gioco.

Unisce le parti, decima fino al budget, ridimensiona le texture, porta la base a z = 0 con il centro in x/y = 0,
(opzionale) rialza il modello sull'asse lungo e lo scala a un'altezza data; esporta .gltf separato
in sketchfab/<categoria>/<nome>/ come gli altri modelli. Poi lanciare compress_textures.py sketchfab
(PNG opachi -> JPEG, niente profilo ICC).

Uso (una sola istanza alla volta!):
  blender -b --factory-startup -P import_glb.py -- <chiave> <file.glb>
"""
import bpy, sys, os, json, math
from mathutils import Vector, Matrix

CUSTOM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_ROOT = os.path.join(CUSTOM, "sketchfab")

# chiave = nome del file (senza .glb) -> impostazioni
CONFIG = {
    "4a8c1e43d3bf42ea96a5517fb173b1ca": dict(cat="architettura", name="edificio_greco_bouleuterion", cap=24000, tex=1024),
    "50fd926fa8494ace9ad39553dc335d86": dict(cat="architettura", name="colonna_corinzia_frammento", cap=10000, tex=2048,
                                              upright=True, height=3.5),
    "832d4c43a07a481e9b700212d99dbd86": dict(cat="rovine", name="rovina_arco_muschio", cap=10000, tex=2048),
}


def tris_of(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def fix_gltf(path):
    g = json.load(open(path))
    for m in g.get("materials", []):
        m.pop("alphaMode", None); m["doubleSided"] = False
    json.dump(g, open(path, "w"), indent=1)


def main(key, src):
    cfg = CONFIG[key]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:   # tutte le parti nel loro posto (coordinate mondo)
        o.parent = None
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:   # nodi vuoti e matrici: applicare mondo
        pass
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # rimuovo gli empty
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    me = ob.data
    src_tris = tris_of(me)
    # materiali e texture: ridimensiona, colore opaco in JPEG
    size = cfg["tex"]
    for im in list(bpy.data.images):
        if im.size[0] == 0:
            continue
        nonc = im.colorspace_settings.name != "sRGB"
        lim = max(1024, size // 2) if nonc else size
        if max(im.size) > lim:
            im.scale(lim, lim)
        if not nonc:
            im.file_format = "JPEG"
    # decimazione
    if src_tris > cfg["cap"]:
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.ratio = max(0.02, cfg["cap"] / src_tris)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    me = ob.data
    vs = [v.co.copy() for v in me.vertices]
    # modello da rialzare sull'asse lungo, con la parte piu' larga (capitello) in alto
    if cfg.get("upright"):
        mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        ext = mx - mn
        axis = max(range(3), key=lambda i: ext[i])
        if axis == 1:
            R = Matrix.Rotation(math.radians(90), 4, "X")     # +Y -> +Z
        elif axis == 0:
            R = Matrix.Rotation(math.radians(-90), 4, "Y")    # +X -> +Z
        else:
            R = Matrix.Identity(4)
        for v in me.vertices:
            v.co = R @ v.co
        vs = [v.co.copy() for v in me.vertices]
        zs = sorted(v.z for v in vs)
        lo, hi = zs[int(len(zs) * 0.15)], zs[int(len(zs) * 0.85)]
        def spread(sel):
            cx = sum(v.x for v in sel) / len(sel); cy = sum(v.y for v in sel) / len(sel)
            return sum(math.hypot(v.x - cx, v.y - cy) for v in sel) / len(sel)
        bottom, top = [v for v in vs if v.z <= lo], [v for v in vs if v.z >= hi]
        if top and bottom and spread(bottom) > spread(top):   # il capitello (largo) deve stare in alto
            for v in me.vertices:
                v.co = Matrix.Rotation(math.radians(180), 4, "X") @ v.co
            vs = [v.co.copy() for v in me.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    s = cfg["height"] / (mx.z - mn.z) if cfg.get("height") else 1.0
    off = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for v in me.vertices:
        v.co = (v.co - off) * s
    me.update()
    for p in me.polygons:
        p.use_smooth = True
    dims = (mx - mn) * s
    d = os.path.join(OUT_ROOT, cfg["cat"], cfg["name"])
    os.makedirs(d, exist_ok=True)
    out = os.path.join(d, cfg["name"] + ".gltf")
    ob.name = cfg["name"]
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLTF_SEPARATE", use_selection=True, export_yup=True, export_apply=False,
        export_materials="EXPORT", export_image_format="AUTO", export_texture_dir="textures",
        export_texcoords=True, export_normals=True, export_animations=False, export_skins=False,
        export_cameras=False, export_lights=False)
    fix_gltf(out)
    rec = dict(asset=key, variant=cfg["name"], tris_src=src_tris, tris=tris_of(ob.data), dim=[round(x, 2) for x in dims],
               tex=size, scale=round(s, 4), file=os.path.relpath(out, CUSTOM))
    print("JOB", json.dumps(rec, ensure_ascii=False))
    with open(os.path.join(OUT_ROOT, "_report.jsonl"), "a") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    os.makedirs(OUT_ROOT, exist_ok=True)
    main(a[0], a[1])
