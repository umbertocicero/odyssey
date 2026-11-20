"""Odyssey kit: helper condivisi per generare i modelli low-poly in Blender (headless).

Convenzioni
- Unita' in metri, Z in alto, 1 casella di gioco = 1 m.
- Origine ai piedi / alla base (z = 0).
- Il fronte dei modelli e' +Y in Blender, che dopo l'export glTF (+Y up) diventa -Z in Godot:
  lo stesso verso del FacingMarker usato da grid_unit.gd.
- Un solo materiale condiviso (M_Odyssey_Palette) con una texture palette 256x256:
  ogni parte del modello usa una casella (swatch) della palette. Leggero per mobile e web.
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
CUSTOM = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(CUSTOM, "_source")
TEX_DIR = os.path.join(SRC, "textures")
PREV_DIR = os.path.join(CUSTOM, "_previews")

# ---------------------------------------------------------------- palette
# nome: (colore hex, roughness, metallic)
SWATCHES = [
    ("skin", "c98d64", 0.85, 0.0), ("skin_dark", "a46c4b", 0.85, 0.0),
    ("hair", "4a2c1a", 0.9, 0.0), ("eye", "1e140d", 0.6, 0.0),
    ("tunic", "e6dac0", 0.95, 0.0), ("tunic_dark", "bfb092", 0.95, 0.0),
    ("red", "a8261e", 0.9, 0.0), ("red_dark", "731712", 0.9, 0.0),
    ("plume", "c4291c", 0.95, 0.0), ("bronze", "b5833a", 0.42, 0.85),
    ("bronze_dark", "7d5624", 0.5, 0.8), ("gold", "d6a640", 0.35, 0.9),
    ("leather", "6b4226", 0.85, 0.0), ("leather_dark", "43291a", 0.85, 0.0),
    ("wood", "8a5a34", 0.9, 0.0), ("wood_dark", "5a3820", 0.9, 0.0),
    ("wood_light", "b08354", 0.9, 0.0), ("iron", "77726a", 0.5, 0.75),
    ("blade", "c9c4ba", 0.3, 0.9), ("canvas", "dccca6", 0.95, 0.0),
    ("canvas_dark", "b09d77", 0.95, 0.0), ("cream", "efe5cf", 0.95, 0.0),
    ("troy_blue", "33507a", 0.9, 0.0), ("troy_blue_dark", "223655", 0.9, 0.0),
    ("ochre", "c99a3c", 0.9, 0.0), ("ochre_dark", "9a7128", 0.9, 0.0),
    ("hull", "6a3f22", 0.85, 0.0), ("hull_dark", "3b2213", 0.85, 0.0),
    ("pitch", "2a1d15", 0.7, 0.0), ("white_paint", "eee6d4", 0.8, 0.0),
    ("rope", "b39a6a", 0.95, 0.0), ("black", "231b16", 0.85, 0.0),
    ("stone", "bfae92", 0.95, 0.0), ("sail_red", "b3302a", 0.95, 0.0),
    ("teal_paint", "3f7a74", 0.8, 0.0), ("feather", "e8e0cc", 0.95, 0.0),
]
GRID = 8          # 8x8 caselle
CELL = 32         # px per casella
TEX = GRID * CELL # 256
SW_INDEX = {n: i for i, (n, *_r) in enumerate(SWATCHES)}


def _hex(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def swatch_rect(name):
    i = SW_INDEX[name]
    cx, cy = i % GRID, i // GRID
    # coordinate UV (v dal basso). Inset di 3 px per evitare bleeding con il mipmapping.
    pad = 3 / TEX
    u0 = cx / GRID + pad; u1 = (cx + 1) / GRID - pad
    v1 = 1 - cy / GRID - pad; v0 = 1 - (cy + 1) / GRID + pad
    return u0, v0, u1, v1


def make_palette_images():
    """Genera le due texture (base color dipinta + ORM) e le salva in _source/textures."""
    os.makedirs(TEX_DIR, exist_ok=True)
    rnd = random.Random(7)
    base = [0.0] * (TEX * TEX * 4)
    orm = [0.0] * (TEX * TEX * 4)
    # rumore a bassa frequenza per l'effetto "dipinto a mano"
    lo = [[rnd.random() for _ in range(TEX // 4 + 2)] for _ in range(TEX // 4 + 2)]

    def noise(x, y):
        fx, fy = x / 4, y / 4
        ix, iy = int(fx), int(fy)
        tx, ty = fx - ix, fy - iy
        a = lo[iy][ix] * (1 - tx) + lo[iy][ix + 1] * tx
        b = lo[iy + 1][ix] * (1 - tx) + lo[iy + 1][ix + 1] * tx
        return a * (1 - ty) + b * ty

    for i, (name, hx, rough, metal) in enumerate(SWATCHES):
        col = _hex(hx)
        cx, cy = i % GRID, i // GRID
        for py in range(CELL):
            for px in range(CELL):
                x = cx * CELL + px
                y_img = cy * CELL + py           # dall'alto
                yb = TEX - 1 - y_img             # riga Blender (dal basso)
                n = noise(x, y_img) * 0.7 + rnd.random() * 0.3
                k = 0.88 + 0.22 * n              # variazione +-11%
                grad = 1.04 - 0.08 * (py / CELL)  # leggermente piu' chiaro in alto
                idx = (yb * TEX + x) * 4
                for c in range(3):
                    base[idx + c] = min(1.0, (col[c] ** 2.2) * k * grad) ** (1 / 2.2)
                base[idx + 3] = 1.0
                orm[idx] = 1.0
                orm[idx + 1] = min(1.0, rough * (0.95 + 0.1 * n))
                orm[idx + 2] = metal
                orm[idx + 3] = 1.0
    imgs = {}
    for key, data, cs in (("BaseColor", base, "sRGB"), ("ORM", orm, "Non-Color")):
        nm = f"T_Odyssey_Palette_{key}"
        img = bpy.data.images.get(nm) or bpy.data.images.new(nm, TEX, TEX, alpha=False)
        img.colorspace_settings.name = cs
        img.pixels.foreach_set(data)
        img.filepath_raw = os.path.join(TEX_DIR, nm + ".png")
        img.file_format = "PNG"
        img.save()
        imgs[key] = img
    return imgs


def palette_material():
    m = bpy.data.materials.get("M_Odyssey_Palette")
    if m:
        return m
    paths = {k: os.path.join(TEX_DIR, f"T_Odyssey_Palette_{k}.png") for k in ("BaseColor", "ORM")}
    if not all(os.path.exists(p) for p in paths.values()):
        make_palette_images()
    m = bpy.data.materials.new("M_Odyssey_Palette")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tb = nt.nodes.new("ShaderNodeTexImage"); tb.location = (-600, 300)
    tb.image = bpy.data.images.load(paths["BaseColor"], check_existing=True)
    tb.interpolation = "Closest"
    to = nt.nodes.new("ShaderNodeTexImage"); to.location = (-600, -50)
    to.image = bpy.data.images.load(paths["ORM"], check_existing=True)
    to.image.colorspace_settings.name = "Non-Color"
    to.interpolation = "Closest"
    sep = nt.nodes.new("ShaderNodeSeparateColor"); sep.location = (-300, -50)
    nt.links.new(tb.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(to.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    return m


# ---------------------------------------------------------------- geometria
def M(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Matrice da posizione, rotazione in gradi (XYZ) e scala."""
    r = Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    s = Matrix.Diagonal((*scale, 1))
    return Matrix.Translation(loc) @ r @ s


def look_m(a, b, radius_scale=(1, 1)):
    """Matrice che porta l'asse Z unitario (0..1) sul segmento a->b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return Matrix.Translation(a) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((radius_scale[0], radius_scale[1], d.length, 1))


class Builder:
    """Accumula primitive in un'unica mesh, con swatch per faccia e osso per vertice."""

    def __init__(self):
        self.verts, self.faces, self.face_sw, self.face_smooth, self.vbone = [], [], [], [], []
        self.face_uv = []

    # -- inserimento generico da bmesh temporanea
    def _add_bm(self, bm, mat, swatch, bone, smooth, uvmode="box"):
        bm.transform(mat) if mat is not None else None
        bm.normal_update()
        base = len(self.verts)
        bm.verts.index_update()
        co = [v.co.copy() for v in bm.verts]
        self.verts += co
        self.vbone += [bone] * len(co)
        mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
        mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
        ext = mx - mn
        for fi, f in enumerate(bm.faces):
            idx = [base + v.index for v in f.verts]
            self.faces.append(idx)
            sw = swatch(fi, f) if callable(swatch) else swatch
            self.face_sw.append(sw)
            self.face_smooth.append(smooth)
            # proiezione sull'asse dominante della normale, normalizzata sul bbox della primitiva
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            a1, a2 = [i for i in range(3) if i != ax]
            u0, v0, u1, v1 = swatch_rect(sw)
            uvs = []
            for v in f.verts:
                s = (v.co[a1] - mn[a1]) / ext[a1] if ext[a1] > 1e-6 else 0.5
                t = (v.co[a2] - mn[a2]) / ext[a2] if ext[a2] > 1e-6 else 0.5
                uvs.append((u0 + (u1 - u0) * s, v0 + (v1 - v0) * t))
            self.face_uv.append(uvs)
        bm.free()
        return self

    def box(self, size, mat=None, swatch="wood", bone=None, bevel=0.0, smooth=False):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=size, verts=bm.verts)
        if bevel > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5)
        return self._add_bm(bm, mat, swatch, bone, smooth)

    def cyl(self, r1, r2, h, seg=8, mat=None, swatch="wood", bone=None, smooth=True, caps=True, z0=0.0):
        """Cilindro/tronco di cono da z0 a z0+h lungo Z locale."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=h)
        bmesh.ops.translate(bm, vec=(0, 0, h / 2 + z0), verts=bm.verts)
        # facce laterali smooth, tappi flat: separo con il flag per faccia
        return self._add_bm_smoothsplit(bm, mat, swatch, bone, smooth)

    def _add_bm_smoothsplit(self, bm, mat, swatch, bone, smooth):
        start = len(self.face_smooth)
        flags = [abs(f.normal.z) < 0.9 for f in bm.faces]
        self._add_bm(bm, mat, swatch, bone, smooth)
        for i, fl in enumerate(flags):
            self.face_smooth[start + i] = smooth and fl
        return self

    def rod(self, a, b, r, seg=6, swatch="wood", bone=None, r2=None, caps=True):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=1.0)
        bmesh.ops.translate(bm, vec=(0, 0, 0.5), verts=bm.verts)
        return self._add_bm_smoothsplit(bm, look_m(a, b), swatch, bone, True)

    def sphere(self, r, mat=None, swatch="skin", bone=None, seg=8, rings=6, smooth=True, scale=(1, 1, 1)):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
        bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
        return self._add_bm(bm, mat, swatch, bone, smooth)

    def hemi(self, r, mat=None, swatch="bronze", bone=None, seg=10, rings=4, cut=0.0, smooth=True, scale=(1, 1, 1)):
        """Calotta sferica (meta' superiore, aperta sotto) usata per elmi e cupole."""
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings * 2, radius=r)
        kill = [v for v in bm.verts if v.co.z < cut * r - 1e-5]
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
        return self._add_bm(bm, mat, swatch, bone, smooth)

    def poly_extrude(self, pts2d, depth, mat=None, swatch="gold", bone=None, smooth=False):
        """Prisma da un poligono 2D (piano XZ, estruso lungo +Y di 'depth')."""
        bm = bmesh.new()
        vs = [bm.verts.new((x, 0, z)) for x, z in pts2d]
        f = bm.faces.new(vs)
        bmesh.ops.reverse_faces(bm, faces=[f]) if f.normal.y > 0 else None
        res = bmesh.ops.extrude_face_region(bm, geom=[f])
        nv = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, vec=(0, depth, 0), verts=nv)
        bmesh.ops.triangulate(bm, faces=[ff for ff in bm.faces if len(ff.verts) > 4])
        bm.normal_update()
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._add_bm(bm, mat, swatch, bone, smooth)

    def slab(self, P, nu, nv, thick, swatch="cloth", bone=None, smooth=True, mat=None):
        """Lastra solida da una superficie parametrica P(u,v) con u,v in [0,1]."""
        bm = bmesh.new()
        eps = 1e-3
        grid_o, grid_i = [], []
        for j in range(nv + 1):
            ro, ri = [], []
            for i in range(nu + 1):
                u, v = i / nu, j / nv
                p = Vector(P(u, v))
                du = Vector(P(min(u + eps, 1), v)) - Vector(P(max(u - eps, 0), v))
                dv = Vector(P(u, min(v + eps, 1))) - Vector(P(u, max(v - eps, 0)))
                n = du.cross(dv)
                n = n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
                ro.append(bm.verts.new(p + n * thick / 2))
                ri.append(bm.verts.new(p - n * thick / 2))
            grid_o.append(ro); grid_i.append(ri)
        for j in range(nv):
            for i in range(nu):
                bm.faces.new((grid_o[j][i], grid_o[j][i + 1], grid_o[j + 1][i + 1], grid_o[j + 1][i]))
                bm.faces.new((grid_i[j][i], grid_i[j + 1][i], grid_i[j + 1][i + 1], grid_i[j][i + 1]))
        for i in range(nu):  # bordi v=0 e v=1
            bm.faces.new((grid_i[0][i], grid_i[0][i + 1], grid_o[0][i + 1], grid_o[0][i]))
            bm.faces.new((grid_o[nv][i], grid_o[nv][i + 1], grid_i[nv][i + 1], grid_i[nv][i]))
        for j in range(nv):  # bordi u=0 e u=1
            bm.faces.new((grid_o[j][0], grid_o[j + 1][0], grid_i[j + 1][0], grid_i[j][0]))
            bm.faces.new((grid_i[j][nu], grid_i[j + 1][nu], grid_o[j + 1][nu], grid_o[j][nu]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        # swatch callable riceve (indice faccia, faccia); passo anche (i,j) via attributo
        if callable(swatch):
            fn = swatch
            cells = []
            for j in range(nv):
                for i in range(nu):
                    cells += [(i, j), (i, j)]
            cells += [(i, 0) for i in range(nu) for _ in (0, 1)]
            cells += [(0, j) for j in range(nv) for _ in (0, 1)]
            sw = lambda fi, f: fn(*cells[fi]) if fi < len(cells) else fn(0, 0)
        else:
            sw = swatch
        return self._add_bm(bm, mat, sw, bone, smooth)

    def merge(self, other, mat=None):
        base = len(self.verts)
        for v in other.verts:
            self.verts.append((mat @ v) if mat else v.copy())
        self.vbone += other.vbone
        self.faces += [[base + i for i in f] for f in other.faces]
        self.face_sw += other.face_sw; self.face_smooth += other.face_smooth; self.face_uv += other.face_uv
        return self

    # -- creazione oggetto
    def build(self, name, collection=None):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        me.validate(clean_customdata=False)
        uv = me.uv_layers.new(name="UVMap")
        li = 0
        for p, uvs in zip(me.polygons, self.face_uv):
            for k, loop_index in enumerate(p.loop_indices):
                uv.data[loop_index].uv = uvs[k]
        me.polygons.foreach_set("use_smooth", self.face_smooth[: len(me.polygons)])
        me.materials.append(palette_material())
        ob = bpy.data.objects.new(name, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        bones = sorted({b for b in self.vbone if b})
        if bones:
            groups = {b: ob.vertex_groups.new(name=b) for b in bones}
            for i, b in enumerate(self.vbone):
                if b:
                    groups[b].add([i], 1.0, "REPLACE")
        # unisce vertici coincidenti della stessa primitiva non necessario; ricalcolo normali
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me); bm.free()
        return ob


# ---------------------------------------------------------------- emblemi
def star_points(r_out, r_in, n=8, cx=0.0, cz=0.0):
    pts = []
    for i in range(n * 2):
        a = math.pi / 2 + i * math.pi / n
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return pts


HORSE_HEAD = [  # profilo stilizzato di testa e collo di cavallo, alto ~1
    (-0.36, -0.50), (0.04, -0.50), (0.08, -0.26), (0.16, -0.08), (0.42, -0.04), (0.56, 0.00),
    (0.58, 0.10), (0.48, 0.18), (0.24, 0.30), (0.12, 0.40), (0.09, 0.58), (0.00, 0.43),
    (-0.10, 0.44), (-0.18, 0.38), (-0.26, 0.30), (-0.30, 0.22), (-0.38, 0.14), (-0.40, 0.02),
    (-0.46, -0.06), (-0.42, -0.14), (-0.46, -0.24), (-0.42, -0.34), (-0.44, -0.42),
]
OWL = [  # gufo di Atena stilizzato (sagoma)
    (-0.30, -0.50), (0.30, -0.50), (0.36, -0.10), (0.34, 0.25), (0.42, 0.50), (0.18, 0.36),
    (0.0, 0.40), (-0.18, 0.36), (-0.42, 0.50), (-0.34, 0.25), (-0.36, -0.10),
]


def scaled(pts, s, cx=0.0, cz=0.0):
    return [(cx + x * s, cz + z * s) for x, z in pts]


# ---------------------------------------------------------------- scena/export
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"; sc.unit_settings.scale_length = 1.0
    sc.render.fps = 24


def save_blend(rel):
    p = os.path.join(SRC, "blend", rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=p, compress=True)
    return p


def export_glb(objs, rel, animations=False):
    p = os.path.join(CUSTOM, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for c in o.children_recursive:
            c.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    kw = dict(filepath=p, export_format="GLB", use_selection=True, export_yup=True,
              export_apply=True, export_texcoords=True, export_normals=True,
              export_materials="EXPORT", export_image_format="AUTO", export_extras=False)
    if animations:
        kw.update(export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                  export_def_bones=False, export_anim_single_armature=True, export_force_sampling=True,
                  export_frame_range=False)
    else:
        kw.update(export_animations=False, export_skins=False)
    bpy.ops.export_scene.gltf(**kw)
    return p


def tri_count(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    t = sum(len(p.vertices) - 2 for p in me.polygons)
    ob.evaluated_get(dg).to_mesh_clear()
    return t
