"""Animali scaricati (Sketchfab, CC-BY-4.0) -> modelli per il gioco: pulizia, decimazione, orientamento, scala, due LOD.

Uso (un solo Blender alla volta):
    blender -b --factory-startup -P build_animali.py -- [nome ...]      (senza nomi: tutti)
Sorgenti: art_source/animals/<zip estratto>/scene.gltf (non nel repo grande: 1-2 milioni di triangoli).
Uscita: assets/models/custom/animali/<nome>/<nome>.gltf (+ textures/ 1024) e <nome>_lod/<nome>_lod.gltf (+ textures/ 512).
Convenzioni come gli altri modelli: metri reali, origine in mezzo ai piedi (z = 0 = suolo, x/y centrati sull'impronta),
FRONTE = +Y Blender (= -Z Godot), asse lungo del corpo = Y. Un solo materiale PBR (colore, normal, metallic/roughness in JPEG).
"""
import bpy, bmesh, sys, os, math, json, shutil, tempfile
import numpy as np
from mathutils import Vector, Matrix

ROOT = "/home/umberto/dev/git/Odyssey"
SRC = ROOT + "/art_source/animals"
OUT = ROOT + "/assets/models/custom/animali"

# nome: (cartella sorgente, quantita' fissata ("h" altezza | "l" lunghezza) in m, tri normale, tri lod, giro in gradi dopo l'allineamento PCA)
ANIMALS = {
    "cavallo_castagno": ("chestnut_majesty_horse_3d_model_free", "h", 1.62, 30000, 9000, 180),
    "cavallo_da_tiro": ("realistic_heavy_draft_horse_-_feathered_legs", "h", 1.72, 26000, 8000, 180),
    "cavallo_bardato": ("armored_horse", "h", 1.62, 30000, 9000, 180),
    "maiale_rosa": ("curious_pink_pig_animal_3d_model_free", "l", 1.30, 9000, 3500, 180),
    "maiale_macchiato": ("realistic_domestic_pig_-_mottled_barrel_body", "l", 1.35, 16000, 5000, -90),
    "pecora": ("realistic_woolly_sheep_-_thick_curled_fleece", "h", 0.80, 20000, 6000, 180),
    "montone_corna": ("low_poly_realistic_woolly_ram_3d_model_free", "h", 0.95, 14000, 5000, 180),
    "montone_lana": ("woolly__ram_animal_3d_model_free", "h", 0.95, 20000, 6000, 180),
    "cervo": ("male_deer_animal_3d_model_free", "h", 1.50, 22000, 7000, 0),
    "ghepardo": ("realistic_cheetah_-_spotted_big_cat", "l", 1.25, 22000, 7000, 180),
}
NO_PCA = ("maiale_macchiato",)   # corpo troppo tondo: la PCA sceglie l'asse sbagliato, si parte dall'orientamento originale
FLIP = {}   # nome -> gradi extra (180 se il muso finisce verso -Y); si compila guardando le anteprime
if os.path.exists(os.path.dirname(os.path.abspath(__file__)) + "/animali_flip.json"):
    FLIP = json.load(open(os.path.dirname(os.path.abspath(__file__)) + "/animali_flip.json"))


def log(*a):
    print("ANIMALI:", *a, flush=True)


def load_model(folder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f"{SRC}/{folder}/scene.gltf")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in meshes:
        o.parent = None if o.parent is None else o.parent
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
    # applica i trasformi del mondo e unisce tutto
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
        o.select_set(True)
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:
        o.modifiers.clear()
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = "animal"
    return ob


def clean(ob):
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002)
    bmesh.ops.dissolve_degenerate(bm, dist=0.000005, edges=bm.edges)
    bm.verts.ensure_lookup_table()
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.validate()
    # un solo materiale / UV: tolgo slot doppi, niente colori vertice
    while len(ob.material_slots) > 1:
        ob.active_material_index = len(ob.material_slots) - 1
        bpy.ops.object.material_slot_remove()
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    log("dopo pulizia:", len(me.polygons), "facce (tri circa", sum(len(p.vertices) - 2 for p in me.polygons), ")")


def orient_and_scale(ob, kind, size, extra_deg, pca=True):
    me = ob.data
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    # PCA sul piano XY: asse lungo -> Y
    xy = co[:, :2] - co[:, :2].mean(axis=0)
    w, v = np.linalg.eigh(np.cov(xy.T))
    major = v[:, np.argmax(w)]
    ang = math.atan2(major[1], major[0])        # angolo dell'asse lungo rispetto a +X
    rot = (math.pi / 2 - ang) if pca else 0.0                      # lo porto su +Y
    # asse Z gia' su; quale lato e' il muso lo decide il giro extra (FLIP/ANIMALS)
    ob.rotation_mode = "XYZ"
    ob.rotation_euler = (0, 0, rot + math.radians(extra_deg))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    me.update()
    co = np.empty(n * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    mn, mx = co.min(axis=0), co.max(axis=0)
    cur = (mx[2] - mn[2]) if kind == "h" else (mx[1] - mn[1])
    s = size / cur
    # centro dell'impronta = media XY dei vertici piu' bassi 15% (zampe), cosi' l'origine sta fra i piedi
    low = co[co[:, 2] < mn[2] + 0.15 * (mx[2] - mn[2])]
    cx, cy = low[:, 0].mean(), (mn[1] + mx[1]) / 2
    co[:, 0] = (co[:, 0] - cx) * s
    co[:, 1] = (co[:, 1] - cy) * s
    co[:, 2] = (co[:, 2] - mn[2]) * s
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    log("dim finali", [round(float(x), 3) for x in (co.max(axis=0) - co.min(axis=0))], "scala", round(s, 4))
    return s


def decimate(ob, target):
    cur = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if cur <= target:
        return
    # prima triangolo tutto (il collapse lavora sui tri), poi in due passi per tenere il tempo basso
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    steps = [target] if cur / target < 6 else [int(math.sqrt(cur * target) * 1.0), target]
    for t in steps:
        cur = len(ob.data.polygons)
        m = ob.modifiers.new("dec", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = max(0.0005, min(1.0, t / cur))
        m.use_collapse_triangulate = True
        m.use_symmetry = False
        bpy.ops.object.modifier_apply(modifier=m.name)
        log("  decimato a", len(ob.data.polygons))
    bpy.ops.object.shade_smooth()
    for a in ("sharp_face", "sharp_edge"):
        if a in ob.data.attributes:
            ob.data.attributes.remove(ob.data.attributes[a])


def prep_textures(folder, px, tmp):
    """Ridimensiona le texture del sorgente (JPEG q90) -> dict ruolo -> percorso."""
    d = json.load(open(f"{SRC}/{folder}/scene.gltf"))
    m = d["materials"][0] if len(d["materials"]) == 1 else None
    if m is None:
        m = max(d["materials"], key=lambda x: len(json.dumps(x)))
    def path(tex):
        return os.path.join(SRC, folder, d["images"][d["textures"][tex["index"]]["source"]]["uri"])
    out = {}
    pbr = m.get("pbrMetallicRoughness", {})
    roles = {"c": pbr.get("baseColorTexture"), "n": m.get("normalTexture"), "r": pbr.get("metallicRoughnessTexture")}
    for k, t in roles.items():
        if not t:
            continue
        im = bpy.data.images.load(path(t))
        im.colorspace_settings.name = "sRGB" if k == "c" else "Non-Color"
        im.scale(px, px)
        p = f"{tmp}/{k}.jpg"
        im.file_format = "JPEG"
        im.filepath_raw = p
        im.save(quality=90 if k != "n" else 94)     # salvataggio diretto: niente trasformazione di vista (AgX) sul colore
        bpy.data.images.remove(im)
        out[k] = p
    return out


def make_material(name, tex, metal_default=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(bsdf.outputs["BSDF"], outn.inputs["Surface"])
    def img(p, cs):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(p)
        n.image.colorspace_settings.name = cs
        return n
    if "c" in tex:
        n = img(tex["c"], "sRGB")
        nt.links.new(n.outputs["Color"], bsdf.inputs["Base Color"])
    if "n" in tex:
        n = img(tex["n"], "Non-Color")
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if "r" in tex:
        n = img(tex["r"], "Non-Color")
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(n.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    else:
        bsdf.inputs["Roughness"].default_value = 0.7
    return mat


def export(ob, name, folder, mat):
    d = f"{OUT}/{folder}"
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=f"{d}/{name}.gltf", export_format="GLTF_SEPARATE", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=90,
                              export_texture_dir="textures", export_texcoords=True, export_normals=True, export_tangents=False,
                              export_animations=False, export_skins=False)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    log("esportato", name, tris, "tri")
    return tris


def build(name):
    folder, kind, size, tri_hi, tri_lo, extra = ANIMALS[name]
    extra = FLIP.get(name, extra)
    tmp = tempfile.mkdtemp(prefix="animal_")
    ob = load_model(folder)
    clean(ob)
    orient_and_scale(ob, kind, size, extra, name not in NO_PCA)
    # versione normale
    decimate(ob, tri_hi)
    os.makedirs(tmp + "/hi"); os.makedirs(tmp + "/lo")
    t1 = prep_textures(folder, 1024, tmp + "/hi")
    mat1 = make_material(name, t1)
    nhi = export(ob, name, name, mat1)
    # lod: parto dalla versione normale (gia' decimata) e riduco ancora
    decimate(ob, tri_lo)
    t2 = prep_textures(folder, 512, tmp + "/lo")
    mat2 = make_material(name + "_lod", t2)
    nlo = export(ob, name + "_lod", name + "_lod", mat2)
    shutil.rmtree(tmp, ignore_errors=True)
    log("RISULTATO", name, nhi, nlo)
    return nhi, nlo


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or list(ANIMALS)
    for n in names:
        log("=====", n)
        build(n)
