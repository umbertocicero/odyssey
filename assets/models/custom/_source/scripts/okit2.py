"""Costruttore di mesh con materiali PBR per ogni parte (modelli del campo, Età del bronzo).

Differenza da okit.py: niente palette condivisa; ogni faccia ha un materiale (texture PBR di pbr_tex.py) e UV in
metri (1 texture = 1 m), cilindriche per pali e tronchi, a scatola per il resto.
Convenzioni come okit.py: metri, Z in alto, origine alla base, fronte +Y (= -Z in Godot dopo l'export).
"""
import bpy, math, os, random, json
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
CUSTOM = os.path.abspath(os.path.join(HERE, "..", ".."))
TEXD = os.path.join(CUSTOM, "_source", "textures", "pbr")
ALPHA_MATS = {"leaves": 0.5, "flame": 0.3, "mane_dark": 0.45, "mane_light": 0.45, "eye": 0.5}      # materiali a maschera (alphaMode MASK, cutoff)
EMISSIVE = {"flame": "flame_e.png", "charcoal": "charcoal_e.png"}


def M(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    r = Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(loc) @ r @ Matrix.Diagonal((*scale, 1))


def seg_m(a, b, sx=1.0, sy=1.0):
    """Matrice che porta l'asse Z unitario (0..1) sul segmento a->b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return Matrix.Translation(a) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((sx, sy, d.length, 1))


class G:
    def __init__(self, seed=0):
        self.v, self.f, self.fm, self.fuv, self.fs = [], [], [], [], []
        self.rnd = random.Random(seed)

    # ---- inserimento generico (le UV a scatola si calcolano dopo la trasformazione, cosi' sono in metri)
    def _add(self, verts, faces, mat, mtx=None, uvs=None, smooth=True, tile=1.0, long_u=True):
        base = len(self.v)
        pts = [(mtx @ Vector(p)) if mtx is not None else Vector(p) for p in verts]
        self.v += [tuple(p) for p in pts]
        for fi, fc in enumerate(faces):
            self.f.append([base + i for i in fc])
            self.fm.append(mat)
            self.fs.append(smooth)
            if uvs is not None:
                self.fuv.append(uvs[fi])
            else:
                self.fuv.append(self._box_uv([pts[i] for i in fc], tile, long_u))

    @staticmethod
    def _box_uv(pf, tile, long_u):
        n = Vector((0, 0, 0))
        for i in range(len(pf)):
            a, b = pf[i], pf[(i + 1) % len(pf)]
            n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
        ax = max(range(3), key=lambda i: abs(n[i]))
        a1, a2 = [i for i in range(3) if i != ax]
        if long_u:     # u lungo l'asse piu' esteso della faccia (venature delle assi)
            ext = [max(p[i] for p in pf) - min(p[i] for p in pf) for i in (a1, a2)]
            if ext[1] > ext[0]:
                a1, a2 = a2, a1
        return [(p[a1] / tile, p[a2] / tile) for p in pf]

    # ---- primitive
    def cyl(self, r1, r2, h, seg=8, mtx=None, mat="bark", tile=1.0, caps=True, z0=0.0, smooth=True):
        ring0 = [(r1 * math.cos(2 * math.pi * i / seg), r1 * math.sin(2 * math.pi * i / seg), z0) for i in range(seg)]
        ring1 = [(r2 * math.cos(2 * math.pi * i / seg), r2 * math.sin(2 * math.pi * i / seg), z0 + h) for i in range(seg)]
        verts = ring0 + ring1
        faces, uvs = [], []
        circ = 2 * math.pi * (r1 + r2) / 2
        for i in range(seg):
            j = (i + 1) % seg
            faces.append([i, j, seg + j, seg + i])
            u0, u1 = i / seg * circ / tile, (i + 1) / seg * circ / tile
            uvs.append([(u0, z0 / tile), (u1, z0 / tile), (u1, (z0 + h) / tile), (u0, (z0 + h) / tile)])
        self._add(verts, faces, mat, mtx, uvs, smooth, tile)
        if caps:
            for z, r, flip in ((z0, r1, True), (z0 + h, r2, False)):
                if r < 1e-4:
                    continue
                vs = [(r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z) for i in range(seg)]
                fc = [list(range(seg))[::-1] if flip else list(range(seg))]
                self._add(vs, fc, mat, mtx, [[(p[0] / tile, p[1] / tile) for p in vs[::-1] if flip] or [(p[0] / tile, p[1] / tile) for p in vs]], False, tile)

    def rod(self, a, b, r1, r2=None, seg=6, mat="bark", tile=1.0, caps=True):
        self.cyl(r1, r1 if r2 is None else r2, 1.0, seg, seg_m(a, b), mat, tile, caps)

    def stake(self, a, b, r, tip=0.3, seg=7, mat="bark"):
        """Palo con punta affilata: fusto da a verso b e cono di 'tip' metri in cima."""
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        cut = b - d * tip
        self.rod(a, cut, r, r * 0.95, seg, mat, caps=False)
        self.rod(cut, b, r * 0.95, 0.012, seg, mat, caps=False)

    def blob(self, radii=(0.2, 0.2, 0.2), mtx=None, mat="stone", seg=10, rings=7, rough=0.22, tile=1.0, seed=None):
        rnd = random.Random(seed if seed is not None else self.rnd.random())
        rows = []
        verts = [(0, 0, -radii[2])]
        for r in range(1, rings):
            phi = math.pi * r / rings
            for i in range(seg):
                th = 2 * math.pi * i / seg
                k = 1 + rnd.uniform(-rough, rough)
                verts.append((radii[0] * k * math.sin(phi) * math.cos(th), radii[1] * k * math.sin(phi) * math.sin(th), -radii[2] * math.cos(phi) * k))
        verts.append((0, 0, radii[2]))
        faces = []
        for i in range(seg):
            faces.append([0, 1 + (i + 1) % seg, 1 + i])
        for r in range(rings - 2):
            for i in range(seg):
                a, b = 1 + r * seg + i, 1 + r * seg + (i + 1) % seg
                faces.append([a, b, b + seg, a + seg])
        top = len(verts) - 1
        for i in range(seg):
            faces.append([top, 1 + (rings - 2) * seg + i, 1 + (rings - 2) * seg + (i + 1) % seg])
        self._add(verts, faces, mat, mtx, None, True, tile, False)

    def box(self, size, mtx=None, mat="planks", tile=1.0, long_u=True):
        sx, sy, sz = [s / 2 for s in size]
        verts = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz), (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
        faces = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [3, 0, 4, 7]]
        self._add(verts, faces, mat, mtx, None, False, tile, long_u)

    def ring(self, R, r, mtx=None, mat="bronze", seg=14, tube=6, tile=1.0, arc=2 * math.pi):
        verts, faces = [], []
        n = seg if arc >= 2 * math.pi - 1e-6 else seg + 1
        for i in range(n):
            th = arc * i / seg
            for j in range(tube):
                ph = 2 * math.pi * j / tube
                verts.append(((R + r * math.cos(ph)) * math.cos(th), (R + r * math.cos(ph)) * math.sin(th), r * math.sin(ph)))
        for i in range(seg if arc >= 2 * math.pi - 1e-6 else seg):
            i2 = (i + 1) % n
            for j in range(tube):
                j2 = (j + 1) % tube
                faces.append([i * tube + j, i2 * tube + j, i2 * tube + j2, i * tube + j2])
        self._add(verts, faces, mat, mtx, None, True, tile, False)

    def lathe(self, profile, seg=18, mtx=None, mat="clay", uv_norm=True, tile=1.0):
        """Solido di rotazione da un profilo [(r, z), ...]; con uv_norm u = giro (0..1), v = altezza (0..1)."""
        zs = [p[1] for p in profile]
        z0, z1 = min(zs), max(zs)
        verts, faces, uvs = [], [], []
        for (r, z) in profile:
            for i in range(seg):
                th = 2 * math.pi * i / seg
                verts.append((r * math.cos(th), r * math.sin(th), z))
        for k in range(len(profile) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                a, b, c, d = k * seg + i, k * seg + j, (k + 1) * seg + j, (k + 1) * seg + i
                faces.append([a, b, c, d])
                v0, v1 = (profile[k][1] - z0) / (z1 - z0), (profile[k + 1][1] - z0) / (z1 - z0)
                uvs.append([(i / seg, 1 - v0), ((i + 1) / seg, 1 - v0), ((i + 1) / seg, 1 - v1), (i / seg, 1 - v1)])
        self._add(verts, faces, mat, mtx, uvs, True, tile)

    def quad(self, w, h, mtx=None, mat="leaves"):
        """Scheda verticale larga w e alta h (z da 0 a h), con la texture per intero."""
        verts = [(-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, h), (-w / 2, 0, h)]
        self._add(verts, [[0, 1, 2, 3]], mat, mtx, [[(0, 0), (1, 0), (1, 1), (0, 1)]], True)

    def slab(self, P, nu, nv, thick, matfn, tile=1.0, mtx=None):
        """Lastra con spessore da una superficie parametrica P(u, v) in [0,1]^2. matfn(i, j) -> nome materiale."""
        eps = 1e-3
        pu = [Vector(P(0, 0.5)), Vector(P(1, 0.5))]
        pv = [Vector(P(0.5, 0)), Vector(P(0.5, 1))]
        lu, lv = (pu[1] - pu[0]).length, (pv[1] - pv[0]).length
        verts, idx = [], {}
        for j in range(nv + 1):
            for i in range(nu + 1):
                u, v = i / nu, j / nv
                p = Vector(P(u, v))
                n = (Vector(P(min(u + eps, 1), v)) - Vector(P(max(u - eps, 0), v))).cross(
                    Vector(P(u, min(v + eps, 1))) - Vector(P(u, max(v - eps, 0))))
                n = n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
                idx[(i, j, 0)] = len(verts); verts.append(tuple(p + n * thick / 2))
                idx[(i, j, 1)] = len(verts); verts.append(tuple(p - n * thick / 2))
        faces, uvs, mats = [], [], []
        for j in range(nv):
            for i in range(nu):
                m = matfn(i, j)
                uv = [(i / nu * lu / tile, j / nv * lv / tile), ((i + 1) / nu * lu / tile, j / nv * lv / tile),
                      ((i + 1) / nu * lu / tile, (j + 1) / nv * lv / tile), (i / nu * lu / tile, (j + 1) / nv * lv / tile)]
                faces.append([idx[(i, j, 0)], idx[(i + 1, j, 0)], idx[(i + 1, j + 1, 0)], idx[(i, j + 1, 0)]]); uvs.append(uv); mats.append(m)
                faces.append([idx[(i, j, 1)], idx[(i, j + 1, 1)], idx[(i + 1, j + 1, 1)], idx[(i + 1, j, 1)]]); uvs.append(uv); mats.append(m)
        for i in range(nu):                # bordi v = 0 e v = 1
            for j, flip in ((0, True), (nv, False)):
                f = [idx[(i, j, 0)], idx[(i + 1, j, 0)], idx[(i + 1, j, 1)], idx[(i, j, 1)]]
                faces.append(f[::-1] if flip else f); uvs.append([(0, 0), (0.05, 0), (0.05, 0.05), (0, 0.05)]); mats.append(matfn(i, max(0, j - 1)))
        for j in range(nv):                # bordi u = 0 e u = 1
            for i, flip in ((0, False), (nu, True)):
                f = [idx[(i, j, 0)], idx[(i, j + 1, 0)], idx[(i, j + 1, 1)], idx[(i, j, 1)]]
                faces.append(f[::-1] if flip else f); uvs.append([(0, 0), (0.05, 0), (0.05, 0.05), (0, 0.05)]); mats.append(matfn(max(0, i - 1), j))
        base = len(self.v)
        self.v += [tuple(mtx @ Vector(p)) if mtx is not None else p for p in verts]
        for fc, uv, m in zip(faces, uvs, mats):
            self.f.append([base + k for k in fc]); self.fm.append(m); self.fuv.append(uv); self.fs.append(True)


    def loft(self, stations, seg=16, mat="horse_bay", dens=3, tile=1.0, close=True):
        """Forma lungo un percorso: stations = [((x,y,z), rx, rz), ...]; anelli ellittici perpendicolari al percorso,
        con interpolazione Catmull-Rom (dens volte piu' anelli), smussata e chiusa alle estremita'."""
        n = len(stations)
        def cr(p0, p1, p2, p3, t):
            return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
        pts = []
        for i in range(n - 1):
            a, b = stations[i], stations[i + 1]
            p0 = stations[max(i - 1, 0)]; p3 = stations[min(i + 2, n - 1)]
            for k in range(dens):
                t = k / dens
                c = cr(Vector(p0[0]), Vector(a[0]), Vector(b[0]), Vector(p3[0]), t)
                rx = cr(p0[1], a[1], b[1], p3[1], t); rz = cr(p0[2], a[2], b[2], p3[2], t)
                pts.append((c, max(rx, 0.004), max(rz, 0.004)))
        pts.append((Vector(stations[-1][0]), max(stations[-1][1], 0.004), max(stations[-1][2], 0.004)))
        rings, s_cum, acc = [], [], 0.0
        for i, (c, rx, rz) in enumerate(pts):
            nxt, prv = pts[min(i + 1, len(pts) - 1)][0], pts[max(i - 1, 0)][0]
            T = (nxt - prv)
            T = T.normalized() if T.length > 1e-9 else Vector((0, 1, 0))
            ref = Vector((1, 0, 0))
            R = (ref - T * ref.dot(T))
            R = R.normalized() if R.length > 1e-6 else Vector((0, 1, 0))
            U = R.cross(T)
            ring = [tuple(c + R * rx * math.cos(2 * math.pi * j / seg) + U * rz * math.sin(2 * math.pi * j / seg)) for j in range(seg)]
            rings.append(ring)
            if i:
                acc += (c - pts[i - 1][0]).length
            s_cum.append(acc)
        verts = [v for r in rings for v in r]
        faces, uvs = [], []
        per = sum(2 * math.pi * math.sqrt((p[1] ** 2 + p[2] ** 2) / 2) for p in pts) / len(pts)
        for i in range(len(rings) - 1):
            for j in range(seg):
                j2 = (j + 1) % seg
                f = [i * seg + j, i * seg + j2, (i + 1) * seg + j2, (i + 1) * seg + j]
                faces.append(f)
                uvs.append([(j / seg * per / tile, s_cum[i] / tile), ((j + 1) / seg * per / tile, s_cum[i] / tile),
                            ((j + 1) / seg * per / tile, s_cum[i + 1] / tile), (j / seg * per / tile, s_cum[i + 1] / tile)])
        # orientamento verso l'esterno: controllo sulla prima faccia
        f0 = faces[0]
        vv = [Vector(verts[k]) for k in f0]
        nrm = (vv[1] - vv[0]).cross(vv[3] - vv[0])
        cen = sum(vv, Vector()) / 4 - pts[0][0]
        if nrm.dot(cen) < 0:
            faces = [f[::-1] for f in faces]
            uvs = [u[::-1] for u in uvs]
        self._add(verts, faces, mat, None, uvs, True, tile)
        if close:
            for end, flip in ((0, True), (len(rings) - 1, False)):
                ci = len(verts)
                c = pts[end][0]
                ring = rings[end]
                vs = list(ring)
                fan = [[k, (k + 1) % seg, seg] for k in range(seg)]
                if end != 0:        # il tappo iniziale guarda indietro (-T), quello finale avanti (+T)
                    fan = [f[::-1] for f in fan]
                self._add(vs + [tuple(c)], fan, mat, None, [[(0.5, 0.5)] * 3 for _ in fan], True, tile)

    def count_tris(self):
        return sum(len(f) - 2 for f in self.f)

    # ---- creazione oggetto Blender
    def build(self, name):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in self.v], [], self.f)
        names = sorted(set(self.fm))
        for n in names:
            me.materials.append(material(n))
        me.update()
        uv = me.uv_layers.new(name="UVMap")
        for p, fuv, m, s in zip(me.polygons, self.fuv, self.fm, self.fs):
            p.material_index = names.index(m)
            p.use_smooth = s
            for k, li in enumerate(p.loop_indices):
                uv.data[li].uv = fuv[k]
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


_MATS = {}


def material(name):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new("M_" + name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    ext = "png" if name in ALPHA_MATS else "jpg"
    cimg = bpy.data.images.load(os.path.join(TEXD, f"{name}_c.{ext}"), check_existing=True)
    tc = nt.nodes.new("ShaderNodeTexImage"); tc.image = cimg; tc.location = (-600, 300)
    nt.links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
    rimg = bpy.data.images.load(os.path.join(TEXD, f"{name}_r.png"), check_existing=True)
    rimg.colorspace_settings.name = "Non-Color"
    tr = nt.nodes.new("ShaderNodeTexImage"); tr.image = rimg; tr.location = (-600, 0)
    nt.links.new(tr.outputs["Color"], bsdf.inputs["Roughness"])
    nimg = bpy.data.images.load(os.path.join(TEXD, f"{name}_n.png"), check_existing=True)
    nimg.colorspace_settings.name = "Non-Color"
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = nimg; tn.location = (-600, -300)
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.location = (-300, -300)
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if name in ALPHA_MATS:
        nt.links.new(tc.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"; m.alpha_threshold = ALPHA_MATS[name]; m.use_backface_culling = False
    if name in EMISSIVE:
        eimg = bpy.data.images.load(os.path.join(TEXD, EMISSIVE[name]), check_existing=True)
        te = nt.nodes.new("ShaderNodeTexImage"); te.image = eimg; te.location = (-600, -600)
        nt.links.new(te.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0 if name == "charcoal" else 2.0
    _MATS[name] = m
    return m


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def export(ob, cat, name, double=()):
    """Esporta in campo/<cat>/<name>/<name>.gltf (separato, texture in textures/) e corregge alpha."""
    d = os.path.join(CUSTOM, "campo", cat, name)
    os.makedirs(d, exist_ok=True)
    out = os.path.join(d, name + ".gltf")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLTF_SEPARATE", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="EXPORT", export_image_format="AUTO",
                              export_texture_dir="textures", export_texcoords=True, export_normals=True,
                              export_animations=False, export_skins=False)
    g = json.load(open(out))
    for m in g.get("materials", []):
        key = m["name"].replace("M_", "", 1)
        if key in ALPHA_MATS:
            m["alphaMode"] = "MASK"; m["alphaCutoff"] = ALPHA_MATS[key]; m["doubleSided"] = True
        else:
            m.pop("alphaMode", None); m["doubleSided"] = key in ("canvas", "hide", "tile", "sail", "hull_band") or key in double
    json.dump(g, open(out, "w"), indent=1)
    return out


def bbox(ob):
    vs = [v.co for v in ob.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return mn, mx


def finish(g, name, cat, center_xy=True, double=()):
    """Crea l'oggetto, porta la base a z = 0 (e il centro a x/y = 0) ed esporta. Ritorna un riepilogo."""
    ob = g.build(name)
    mn, mx = bbox(ob)
    off = Vector(((mn.x + mx.x) / 2 if center_xy else 0, (mn.y + mx.y) / 2 if center_xy else 0, mn.z))
    for v in ob.data.vertices:
        v.co -= off
    ob.data.update()
    mn, mx = bbox(ob)
    out = export(ob, cat, name, double)
    rec = dict(name=name, cat=cat, tris=tri_count(ob), dim=[round(x, 2) for x in (mx - mn)], license="originale (modellato per il progetto), proprietà di Umberto",
               file=os.path.relpath(out, CUSTOM))
    with open(os.path.join(CUSTOM, "campo", "_report.jsonl"), "a") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    print("MODEL", json.dumps(rec, ensure_ascii=False))
    return rec
