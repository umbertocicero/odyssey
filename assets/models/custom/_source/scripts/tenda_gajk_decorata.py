"""Variante decorata della tenda di Gajk.Mv (CC-BY-4.0): pellicce e rami frondosi sul tetto (STYLE.md sez. 5).

Importa la tenda gia' ritoccata (sketchfab/tende/tenda_sketchfab_gajk), cerca con raggi verticali i punti sulle falde,
vi appoggia carte di rami (foglie con alpha) e pelli, unisce tutto ed esporta sketchfab/tende/tenda_gajk_pelli_rami.
Uso: blender -b --factory-startup -P tenda_gajk_decorata.py
"""
import bpy, sys, os, math, json, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M

CUSTOM = okit2.CUSTOM
SRC = os.path.join(CUSTOM, "sketchfab", "tende", "tenda_sketchfab_gajk", "tenda_sketchfab_gajk.gltf")
NAME = "tenda_gajk_pelli_rami"

okit2.reset()
bpy.ops.import_scene.gltf(filepath=SRC)
tent = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(tent, dg)
vs = [tent.matrix_world @ v.co for v in tent.data.vertices]
xs, ys, zs = [v.x for v in vs], [v.y for v in vs], [v.z for v in vs]
x0, x1, y0, y1, ztop = min(xs), max(xs), min(ys), max(ys), max(zs)
rnd = random.Random(7)
g = G(7)
placed = []
tries = 0
want_br, want_hide = 9, 3
while (len([p for p in placed if p[0] == "b"]) < want_br or len([p for p in placed if p[0] == "h"]) < want_hide) and tries < 4000:
    tries += 1
    kind = "b" if len([p for p in placed if p[0] == "b"]) < want_br else "h"
    x, y = rnd.uniform(x0 * 0.8, x1 * 0.8), rnd.uniform(y0 * 0.8, y1 * 0.8)
    hit = bvh.ray_cast(Vector((x, y, ztop + 1.0)), Vector((0, 0, -1)))
    if hit[0] is None:
        continue
    loc, n = hit[0], hit[1]
    if n.z < 0.35 or loc.z < 0.7:
        continue
    if any((loc - p[1]).length < (0.75 if kind == "b" else 0.9) for p in placed):
        continue
    placed.append((kind, loc.copy(), n.normalized()))
for kind, loc, n in placed:
    t = Vector((0, 0, -1)) - n * n.dot(Vector((0, 0, -1)))          # verso il basso lungo la falda
    t = t.normalized()
    b = t.cross(n).normalized()
    yaw = math.radians(rnd.uniform(-35, 35))
    t2 = (t * math.cos(yaw) + b * math.sin(yaw)).normalized()
    b2 = t2.cross(n).normalized()
    if kind == "b":
        Lb = rnd.uniform(0.95, 1.3)
        base = loc + n * 0.035
        g.rod(base, base + t2 * Lb, 0.011, 0.007, 5, "bark")
        for tilt in (0.0, 0.3):
            up = (t2 * math.cos(tilt) + n * math.sin(tilt)).normalized()
            rot = Matrix((b2, up.cross(b2), up)).transposed().to_4x4()
            g.quad(Lb * 0.78, Lb * 0.98, Matrix.Translation(base + n * (0.02 if tilt else 0.0)) @ rot, "leaves")
    else:
        rot = Matrix((b2, t2, n)).transposed().to_4x4()
        g.blob((0.5, 0.36, 0.05), Matrix.Translation(loc + n * 0.04) @ rot, "hide", 10, 5, 0.12)
deco = g.build("decor")
bpy.ops.object.select_all(action="DESELECT")
tent.select_set(True); deco.select_set(True)
bpy.context.view_layer.objects.active = tent
bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.name = NAME
out_dir = os.path.join(CUSTOM, "sketchfab", "tende", NAME)
os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, NAME + ".gltf")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLTF_SEPARATE", use_selection=True, export_yup=True, export_apply=False,
                          export_materials="EXPORT", export_image_format="AUTO", export_texture_dir="textures",
                          export_texcoords=True, export_normals=True, export_animations=False, export_skins=False)
gj = json.load(open(out))
for m in gj.get("materials", []):
    key = m["name"].replace("M_", "", 1)
    if key in okit2.ALPHA_MATS:
        m["alphaMode"] = "MASK"; m["alphaCutoff"] = okit2.ALPHA_MATS[key]; m["doubleSided"] = True
    else:
        m.pop("alphaMode", None); m["doubleSided"] = key in ("Tent", "hide")
json.dump(gj, open(out, "w"), indent=1)
tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
mn = Vector((min(v.co.x for v in ob.data.vertices), min(v.co.y for v in ob.data.vertices), min(v.co.z for v in ob.data.vertices)))
mx = Vector((max(v.co.x for v in ob.data.vertices), max(v.co.y for v in ob.data.vertices), max(v.co.z for v in ob.data.vertices)))
rec = dict(variant=NAME, tris=tris, dim=[round(x, 2) for x in (mx - mn)], branches=len([p for p in placed if p[0] == "b"]),
           hides=len([p for p in placed if p[0] == "h"]), file=os.path.relpath(out, CUSTOM),
           author="Gajk.Mv (tenda) + elementi originali del progetto", license="CC-BY-4.0 (tenda), originali (rami e pelli)")
print("JOB", json.dumps(rec, ensure_ascii=False))
with open(os.path.join(CUSTOM, "sketchfab", "_report.jsonl"), "a") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
