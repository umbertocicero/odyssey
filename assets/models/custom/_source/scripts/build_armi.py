"""Armi come oggetti separati da attaccare a hand.R del rig a 17 ossa: xiphos (spada corta), lancia, arco con corda.

Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_armi.py -- [xiphos lancia arco]
Esporta armi/<nome>/<nome>.gltf (versione normale) e <nome>_lod.gltf (leggera), texture condivise in armi/<nome>/textures/.
Convenzioni: metri alla scala dei personaggi (0,8 x reale), ORIGINE = centro della presa, asse lungo = +Z Blender (= +Y Godot,
punta/estremita' verso l'alto), piano della lama / dell'arco in X-Z; arco: la corda sta verso +Y Blender (= -Z Godot, il lato del tiratore).
Modelli originali (modellati per il progetto).
"""
import bpy, sys, os, math, json
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, seg_m, CUSTOM

V = Vector
METAL = {"bronze_blade": 0.92}


def leaf_blade(g, z0, z1, wmax, wpos, w0, th0, th1, n, mat, mtx=None, wtip=0.0):
    """Lama a foglia con nervatura centrale: n stazioni lungo z, sezione a esagono schiacciato (8 vertici)."""
    rings = []
    for i in range(n + 1):
        t = i / n
        if t < wpos:
            w = w0 + (wmax - w0) * math.sin(math.pi / 2 * t / wpos)
        else:
            w = wmax * math.cos(math.pi / 2 * (t - wpos) / (1 - wpos)) ** 0.85
        w = max(w, wtip)
        th = th0 + (th1 - th0) * t
        z = z0 + (z1 - z0) * t
        rings.append([(-w, 0, z), (-w * 0.38, th * 0.8, z), (0, th, z), (w * 0.38, th * 0.8, z), (w, 0, z),
                      (w * 0.38, -th * 0.8, z), (0, -th, z), (-w * 0.38, -th * 0.8, z)])
    verts = [p for r in rings for p in r]
    faces = []
    k = 8
    for i in range(n):
        for j in range(k):
            a, b = i * k + j, i * k + (j + 1) % k
            faces.append([a, b, b + k, a + k])
    tip = len(verts)
    verts.append((0, 0, z1 + 0.0004))
    for j in range(k):
        faces.append([n * k + j, n * k + (j + 1) % k, tip])
    g._add(verts, faces, mat, mtx, None, False, 0.5, True)


def xiphos(lod=False):
    g = G(201)
    ns, seg = (8, 8) if lod else (22, 16)
    # impugnatura (cuoio avvolto) centrata sull'origine, 0,095 m
    prof = [(0.0085, -0.0475), (0.0105, -0.043), (0.0118, -0.02), (0.0125, 0.0), (0.0118, 0.02), (0.0105, 0.043), (0.0085, 0.0475)]
    g.lathe(prof, seg=seg, mat="leather", tile=0.08)
    if not lod:
        for z in (-0.03, -0.01, 0.01, 0.03):                                    # giri di cordino
            g.ring(0.0124, 0.0011, M((0, 0, z)), "cord", seg=14, tube=4, tile=0.05)
    # pomolo a disco di bronzo e parafilo
    g.cyl(0.015, 0.013, 0.012, seg, M((0, 0, -0.0595)), "bronze_blade", tile=0.05, smooth=True)
    g.blob((0.012, 0.012, 0.01), M((0, 0, -0.0615)), "bronze_blade", seg=seg, rings=4, rough=0.0)
    g.box((0.07, 0.014, 0.012), M((0, 0, 0.0535)), "bronze_blade", tile=0.05)
    g.blob((0.035, 0.007, 0.006), M((0, 0, 0.0535)), "bronze_blade", seg=seg, rings=4, rough=0.0)
    leaf_blade(g, 0.058, 0.43, 0.0215, 0.42, 0.012, 0.0062, 0.0022, ns, "bronze_blade", wtip=0.0)
    return g


def lancia(lod=False):
    g = G(202)
    seg = 8 if lod else 14
    top, bot = 1.07, -0.56
    g.rod((0, 0, bot), (0, 0, top), 0.0115, 0.0098, seg, "wood_ash", tile=0.1)           # asta di frassino, conicita' leggera
    g.cyl(0.0132, 0.0132, 0.17, seg, M((0, 0, -0.085)), "leather", tile=0.08)             # presa avvolta in cuoio
    if not lod:
        for z in (-0.075, -0.04, 0.0, 0.04, 0.075):
            g.ring(0.0132, 0.0011, M((0, 0, z)), "cord", seg=14, tube=4, tile=0.05)
    # puntale (sauroter) di bronzo con spuntone a sezione quadra
    g.cyl(0.0125, 0.0125, 0.05, seg, M((0, 0, bot)), "bronze_blade", tile=0.05)
    g.cyl(0.0125, 0.0022, 0.17, 4, M((0, 0, bot - 0.17)), "bronze_blade", tile=0.05, caps=False, smooth=False)
    g.rod((0, 0, bot - 0.17), (0, 0, bot - 0.17), 0.0, 0.0, 4, "bronze_blade") if False else None
    # cuspide: cannone (cono) + lama a foglia
    g.cyl(0.0108, 0.0125, 0.012, seg, M((0, 0, top - 0.02)), "bronze_blade", tile=0.05)    # collarino
    g.cyl(0.0125, 0.0078, 0.085, seg, M((0, 0, top - 0.008)), "bronze_blade", tile=0.05)   # cannone
    leaf_blade(g, top + 0.075, top + 0.305, 0.0225, 0.36, 0.0095, 0.0068, 0.0024, 10 if lod else 24, "bronze_blade")
    return g


def arco(lod=False):
    g = G(203)
    n = 8 if lod else 20
    seg = 6 if lod else 8
    H = 0.40                                                       # semilunghezza (arco da 0,8 m)

    def y_at(t):                                                   # t in [0,1] lungo il ramo: flessione e ricurvatura finale
        y = 0.16 * t ** 1.8
        s = max(0.0, (t - 0.78) / 0.22)
        return y - 0.034 * (s * s * (3 - 2 * s))
    def prof(t):                                                   # larghezza/spessore mezzi: sottili verso la punta
        return 0.0125 * (1 - 0.55 * t) + 0.001, 0.0072 * (1 - 0.5 * t) + 0.0008
    for side in (1, -1):
        pts = [V((0, y_at(i / n), side * H * (i / n) * (1 - 0.04 * (i / n)))) for i in range(n + 1)]
        for i in range(n):
            w0, t0 = prof(i / n); w1, t1 = prof((i + 1) / n)
            a, b = pts[i], pts[i + 1]
            if side == 1:
                g.cyl(1.0, w1 / w0, 1.0, seg, seg_m(a, b, w0, t0), "wood_bow", tile=0.1)
            else:
                g.cyl(1.0, w1 / w0, 1.0, seg, seg_m(a, b, w0, t0), "wood_bow", tile=0.1)
    # impugnatura in cuoio (riser) e rinforzo
    g.cyl(1.0, 1.0, 0.13, 10 if not lod else 6, seg_m(V((0, -0.0, -0.065)), V((0, 0.0, 0.065)), 0.0165, 0.0125), "leather", tile=0.08)
    if not lod:
        for z in (-0.05, -0.025, 0.0, 0.025, 0.05):
            g.ring(1.0, 0.07, M((0, 0, z), (0, 0, 0), (0.0172, 0.0132, 1)), "cord", seg=12, tube=4, tile=0.05) if False else None
    # puntali (cappucci di bronzo con gola per la corda)
    ytip = y_at(1.0)
    tip_a = V((0, ytip, H * 0.96)); tip_b = V((0, ytip, -H * 0.96))
    for tp, sgn in ((tip_a, 1), (tip_b, -1)):
        g.cyl(0.0085, 0.004, 0.026, seg, M((0, tp.y, tp.z - 0.012 * sgn if sgn > 0 else tp.z), (0 if sgn > 0 else 180, 0, 0)) if sgn > 0 else M((0, tp.y, tp.z + 0.0), (180, 0, 0)), "bronze_blade", tile=0.05)
    # corda: da punta a punta, con parte centrale rivestita (serving) e punto d'incocco
    s_a = V((0, ytip, H * 0.96 + 0.012)); s_b = V((0, ytip, -H * 0.96 - 0.012))
    g.rod(s_b, s_a, 0.0012, 0.0012, 4, "cord", tile=0.02)
    g.cyl(0.0021, 0.0021, 0.08, 6, M((0, ytip, -0.04)), "cord", tile=0.02)
    return g


ALL = {"xiphos": xiphos, "lancia": lancia, "arco": arco}


def export(ob, name, folder):
    d = os.path.join(CUSTOM, "armi", folder)
    os.makedirs(d, exist_ok=True)
    out = os.path.join(d, name + ".gltf")
    for m in ob.data.materials:
        key = m.name.replace("M_", "", 1)
        if key in METAL:
            m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = METAL[key]
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLTF_SEPARATE", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="EXPORT", export_image_format="AUTO",
                              export_texture_dir="textures", export_texcoords=True, export_normals=True,
                              export_animations=False, export_skins=False)
    j = json.load(open(out))
    for m in j.get("materials", []):
        m.pop("alphaMode", None); m["doubleSided"] = m["name"].replace("M_", "", 1) in ("cord", "bronze_blade")
    json.dump(j, open(out, "w"), indent=1)
    return out


if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        for lod in (False, True):
            okit2.reset()
            g = ALL[n](lod)
            nm = n + ("_lod" if lod else "")
            ob = g.build(nm)
            for p in ob.data.polygons:
                pass
            ob.data.update()
            out = export(ob, nm, n)
            print("ARMA", nm, "tris", okit2.tri_count(ob), "->", out)
