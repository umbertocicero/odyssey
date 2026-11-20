"""Terreno della pianura di Troia (livello 1): superficie 52x52 m con rilievo, lati del blocco in sezione,
splat map, maschere e texture cotte. Richiede le texture di gen_terrain_textures.py.

Uso: blender -b --factory-startup -P build_terrain.py
Coordinate: X Blender = X Godot, Y Blender = -Z Godot. Il blocco va da X -26..26 e Z Godot -30..22,
come TerrainRelief (origin (-26, -30), 52x52 quadrati da 1 m, 1 livello = 0,8 m). Quota 0 = pianura.
"""
import bpy, bmesh, os, sys, math, base64, re
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import okit
from gen_terrain_textures import fbm, blur as pblur, normal_map, smooth, LAYERS, OUT, ARRAY_ORDER

PROJECT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
CUSTOM = os.path.join(PROJECT, "assets", "models", "custom")
X0, X1, Y0, Y1 = -26.0, 26.0, -22.0, 30.0
SIZE = 52.0
LEVEL_H = 0.8
UND_AMP = 0.10  # ondulazione dolce delle superfici piane, +/- metri (colline basse come nel riferimento)
BOTTOM = -8.0
# metri coperti da un tile di ciascuno strato (usati anche nello shader Godot)
TILE_M = {"prato_muschio": 2.0, "terra": 2.5, "terra_secca": 3.0, "sentiero": 2.5, "sabbia_ghiaia": 3.0, "roccia": 4.0}


# ---------------------------------------------------------------- dati del livello
def load_levels():
    t = open(os.path.join(PROJECT, "scenes", "levels", "level1", "level1.tscn")).read()
    m = re.search(r'levels = PackedByteArray\("([^"]+)"\)', t)
    return np.frombuffer(base64.b64decode(m.group(1)), np.uint8).reshape(52, 52).astype(np.float32)


def gblur(a, sigma):
    """Sfocatura gaussiana non periodica (bordi replicati), sigma in campioni."""
    r = int(sigma * 3) + 1
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2); k /= k.sum()
    p = np.pad(a, r, mode="edge")
    p = np.apply_along_axis(lambda v: np.convolve(v, k, "valid"), 0, p)
    p = np.apply_along_axis(lambda v: np.convolve(v, k, "valid"), 1, p)
    return p


def grid(res):
    n = int(round(SIZE / res)) + 1
    xs = np.linspace(X0, X1, n)
    ys = np.linspace(Y0, Y1, n)
    X, Y = np.meshgrid(xs, ys)  # [j, i]: riga = Y (nord), colonna = X
    return X, Y


def godot(X, Y):
    return X, -Y  # (gx, gz)


def rect_sdf(gx, gz, x0, x1, z0, z1):
    cx, cz, hx, hz = (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0) / 2, (z1 - z0) / 2
    qx, qz = np.abs(gx - cx) - hx, np.abs(gz - cz) - hz
    return np.hypot(np.maximum(qx, 0), np.maximum(qz, 0)) + np.minimum(np.maximum(qx, qz), 0)


def noise(seed, n, beta=2.0, fmin=1, fmax=None):
    return fbm(seed, beta, fmin, fmax, shape=(n, n))


# ---------------------------------------------------------------- campo di altezza
RES = 0.125


def heightfield():
    lv = load_levels()
    X, Y = grid(RES)
    gx, gz = godot(X, Y)
    n = X.shape[0]
    ix = np.clip(np.floor(gx + 26 - 1e-4).astype(int), 0, 51)
    iz = np.clip(np.floor(gz + 30 - 1e-4).astype(int), 0, 51)
    step = lv[iz, ix] * LEVEL_H
    sea = (gx < -21.6) & (gz > -19) & (gz < 22)
    beach = (gx >= -21.6) & (gx < -19.8) & (gz > -19) & (gz < 22)
    # mare incassato e spiaggia in pendenza
    beach_t = np.clip((gx + 21.6) / 1.8, 0, 1)
    step = np.where(sea, -0.6, step)
    step = np.where(beach, -0.45 + 0.45 * smooth(0, 1, beach_t), step)
    H = gblur(step, 1.3)
    gy_, gx_ = np.gradient(H, RES)
    slope = np.hypot(gx_, gy_)
    cliff = smooth(0.25, 1.4, slope)
    n1, n2, n3 = noise(201, n, 1.3, 24), noise(202, n, 1.3, 24), noise(203, n, 2.0, 2)
    n4 = noise(205, n, 1.0, 60)
    micro = noise(204, n, 1.2, 20)
    und = (noise(206, n, 2.6, 2, 7) - 0.5) * 0.55 + (noise(207, n, 2.0, 3, 10) - 0.5) * 0.25
    shore = smooth(-18.8, -20.5, gx) * ((gz > -19.5) & (gz < 22.5))
    land = (1 - cliff) * smooth(-20.0, -16.5, gx) * (1 - sea)
    H = H + und * UND_AMP * land / 0.25 + cliff * ((n1 - 0.5) * 0.5 + (n4 - 0.5) * 0.12 + 0.07 * np.sin(H * 15 + n3 * 8)) \
          + (1 - cliff) * ((micro - 0.5) * 0.035 + (n3 - 0.5) * 0.02) \
          + shore * (n3 - 0.5) * 0.08
    # spostamento orizzontale sulle pareti: profilo frastagliato
    dx = cliff * ((n2 - 0.5) * 0.45 + (n4 - 0.5) * 0.15)
    dy = cliff * ((n1 - 0.5) * 0.45 + (n4 - 0.5) * 0.15)
    return X, Y, H, dx, dy, cliff, sea


# ---------------------------------------------------------------- maschere 2D (1024 px su 52 m)
MAPN = 1024


def sample(a, X, Y):
    """Campiona bilineare un array [riga=Y, col=X] che copre il blocco."""
    n = a.shape[0]
    fx = np.clip((X - X0) / SIZE * (n - 1), 0, n - 1.001)
    fy = np.clip((Y - Y0) / SIZE * (n - 1), 0, n - 1.001)
    i, j = fx.astype(int), fy.astype(int)
    tx, ty = fx - i, fy - j
    if a.ndim == 3:
        tx, ty = tx[..., None], ty[..., None]
    return (a[j, i] * (1 - tx) * (1 - ty) + a[j, i + 1] * tx * (1 - ty)
            + a[j + 1, i] * (1 - tx) * ty + a[j + 1, i + 1] * tx * ty)


def masks(Hf, cliff_f):
    xs = X0 + (np.arange(MAPN) + 0.5) / MAPN * SIZE
    ys = Y0 + (np.arange(MAPN) + 0.5) / MAPN * SIZE
    X, Y = np.meshgrid(xs, ys)
    gx, gz = godot(X, Y)
    H = sample(Hf, X, Y)
    rock = smooth(0.25, 0.75, sample(cliff_f, X, Y))
    e1, e2, e3, e4 = (noise(s, MAPN, 2.2, 4) for s in (301, 302, 303, 304))
    fine = noise(305, MAPN, 1.6, 30)
    # sentieri (StradaAccampamento e StradaPorta di level1.tscn) con bordi irregolari
    d = np.minimum(rect_sdf(gx, gz, -17, 8, 10, 13), rect_sdf(gx, gz, 5, 8, -23.5, 10))
    d = d + (e1 - 0.5) * 1.0 + (fine - 0.5) * 0.25
    path = smooth(0.25, -0.25, d)
    shoulder = smooth(1.4, 0.1, d) * (1 - path) * smooth(0.35, 0.6, e2)
    # accampamento acheo: terra calpestata, cenere e terra secca attorno al falo'
    camp = smooth(1.0, 0.75, np.hypot((gx + 14) / 8.0, (gz - 12) / 9.5) + (e3 - 0.5) * 0.4)
    fire = smooth(3.2, 1.0, np.hypot(gx + 12.5, gz - 8.5) + (fine - 0.5) * 0.8)
    # campo di battaglia: chiazze di terra secca nella pianura
    plain = (H < 0.3) & (gx > -19)
    battle = smooth(0.58, 0.72, e4) * plain
    soilp = smooth(0.62, 0.75, e2) * plain
    north = smooth(-20.0, -21.5, gz) * smooth(0.6, 0.45, e3)
    # spiaggia e fondale
    sand = smooth(-19.0, -20.4, gx + (e1 - 0.5) * 0.9) * ((gz > -19.6 + (e2 - .5)) & (gz < 22.4)) * 1.0
    sand = np.maximum(sand, smooth(-19.6, -19.0, -np.abs(gz - 1.5) - 1e9) * 0)
    soil = np.clip(shoulder * 0.8 + camp * smooth(0.3, 0.6, e1) * 0.8 + soilp * 0.7 + north * 0.5, 0, 1)
    dry = np.clip(battle * 0.85 + fire + camp * smooth(0.55, 0.7, e2) * 0.6 + north * smooth(0.5, 0.6, e1) * 0.5, 0, 1)
    # niente strati di terra sulle pareti di roccia; il sentiero e la sabbia vincono
    path = path * (1 - sand)
    soil = soil * (1 - path) * (1 - sand)
    dry = dry * (1 - path) * (1 - sand) * (1 - soil * 0.5)
    tot = soil + dry + path + sand
    over = np.maximum(tot, 1)
    soil, dry, path, sand = soil / over, dry / over, path / over, sand / over
    grass = np.clip(1 - (soil + dry + path + sand), 0, 1)
    # occlusione del terreno: piede delle pareti, fessure, riva bagnata
    ao = 1 - np.clip((pblur_np(H, 6) - H) * 1.5, 0, 0.5) - np.clip((pblur_np(H, 24) - H) * 0.6, 0, 0.3)
    ao = np.clip(ao, 0.35, 1)
    wet = smooth(-19.6, -21.0, gx) * ((gz > -19.5) & (gz < 22.5))
    # erba: densita', taglia e secchezza per lo scatter in Godot
    clump = smooth(0.3, 0.7, noise(306, MAPN, 2.0, 3, 40))
    density = np.clip(grass * (1 - rock * 0.9) * (0.8 + 0.2 * clump) + soil * 0.35 * clump + dry * 0.15, 0, 1) * (1 - sand) * (1 - path * 0.95)
    macro = noise(307, MAPN, 2.2, 2, 9)
    band = noise(308, MAPN, 1.8, 2, 7)
    tall = np.clip((0.35 + 0.65 * smooth(0.2, 2.5, d)) * (0.45 + 0.85 * smooth(0.3, 0.7, macro)) / 1.3, 0, 1)
    dryness = np.clip(0.06 + 0.7 * smooth(0.45, 0.72, e4) + dry * 0.4 - clump * 0.1, 0, 1)
    return dict(X=X, Y=Y, H=H, soil=soil, dry=dry, path=path, sand=sand, grass=grass, rock=rock,
                ao=ao, wet=wet, density=density, tall=tall, dryness=dryness, band=band)


def pblur_np(a, r):
    return gblur(a, r)


# ---------------------------------------------------------------- immagini
def load_png(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)


def np_image(name, arr, path, noncolor=False):
    arr = np.clip(arr, 0, 1).astype(np.float32)
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, 2)
    h, w, c = arr.shape
    if c == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1), np.float32)], 2)
    img = bpy.data.images.new(name, w, h, alpha=(c == 4))
    img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.filepath = path
    if noncolor:
        img.colorspace_settings.name = "Non-Color"
    return img


def bake_layers(M, N=2048):
    """Composita gli strati tileable sulla superficie (texture cotte per il .gltf, pronte senza shader)."""
    xs = X0 + (np.arange(N) + 0.5) / N * SIZE
    ys = Y0 + (np.arange(N) + 0.5) / N * SIZE
    X, Y = np.meshgrid(xs, ys)
    up = lambda a: sample(a, X, Y)
    w = {"prato_muschio": up(M["grass"]), "terra": up(M["soil"]), "terra_secca": up(M["dry"]),
         "sentiero": up(M["path"]), "sabbia_ghiaia": up(M["sand"])}
    rock = up(M["rock"])
    for k in w:
        w[k] = w[k] * (1 - rock)
    w["roccia"] = rock
    px_per_m = N / SIZE
    alb = np.zeros((N, N, 3), np.float32); nrm = np.zeros((N, N, 3), np.float32)
    rgh = np.zeros((N, N), np.float32); hts = {}
    layers = {}
    for name in ARRAY_ORDER:
        a = load_png(os.path.join(LAYERS, f"T_{name}_albedo.png"))[..., :3]
        nm = load_png(os.path.join(LAYERS, f"T_{name}_normal.png"))[..., :3]
        orm = load_png(os.path.join(LAYERS, f"T_{name}_orm.png"))
        ht = load_png(os.path.join(LAYERS, f"T_{name}_height.png"))[..., 0]
        T = a.shape[0]
        f = T / (TILE_M[name] * px_per_m)  # pixel di texture per pixel cotto
        sig = f * 0.45
        bl = lambda c: pblur(c, sig)
        a = np.stack([bl(a[..., i]) for i in range(3)], 2)
        nm = np.stack([bl(nm[..., i] - 0.5) for i in range(3)], 2)
        r = bl(orm[..., 1]); ht = bl(ht)
        u = ((X / TILE_M[name]) % 1 * T).astype(int) % T
        v = ((Y / TILE_M[name]) % 1 * T).astype(int) % T
        layers[name] = (a[v, u], nm[v, u], r[v, u], ht[v, u])
    # blend con l'altezza (lo stesso usato nello shader): gli strati alti emergono tra quelli bassi
    hw = {k: w[k] + layers[k][3] * 0.5 for k in w}
    mx = np.max(np.stack(list(hw.values())), 0)
    ww = {k: np.maximum(hw[k] - mx + 0.25, 0) * (w[k] > 0.001) for k in w}
    s = np.maximum(sum(ww.values()), 1e-5)
    for k in ww:
        t = ww[k] / s
        alb += layers[k][0] * t[..., None]; nrm += layers[k][1] * t[..., None]; rgh += layers[k][2] * t
    ao = up(M["ao"]); wet = up(M["wet"])
    alb *= (0.55 + 0.45 * ao)[..., None]
    alb *= (1 - 0.35 * wet)[..., None]
    rgh = rgh * (1 - 0.4 * wet)
    nrm /= np.maximum(np.linalg.norm(nrm, axis=2, keepdims=True), 1e-5)
    nrm = nrm * 0.5 + 0.5
    return alb, nrm, np.stack([ao, rgh, np.zeros_like(ao)], 2)


# ---------------------------------------------------------------- mesh
def grid_mesh(name, X, Y, H, dx, dy, stride):
    Xs, Ys, Hs = X[::stride, ::stride], Y[::stride, ::stride], H[::stride, ::stride]
    dxs, dys = dx[::stride, ::stride], dy[::stride, ::stride]
    n = Xs.shape[0]
    # i bordi del blocco restano dritti: niente spostamento orizzontale sul perimetro
    edge = np.zeros_like(Xs, bool); edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
    vx = np.where(edge, Xs, Xs + dxs); vy = np.where(edge, Ys, Ys + dys)
    verts = np.stack([vx, vy, Hs], -1).reshape(-1, 3)
    idx = np.arange(n * n).reshape(n, n)
    a, b, c, d = idx[:-1, :-1], idx[:-1, 1:], idx[1:, 1:], idx[1:, :-1]
    faces = np.stack([a, b, c, d], -1).reshape(-1, 4)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], faces.tolist())
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def decimate(ob, ratio):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    m = ob.modifiers.new("dec", "DECIMATE"); m.ratio = ratio; m.use_collapse_triangulate = True
    # i vertici del perimetro restano: altrimenti i lati non combaciano
    vg = ob.vertex_groups.new(name="interno")
    inner = [v.index for v in ob.data.vertices
             if abs(v.co.x) < 25.999 and Y0 + 1e-3 < v.co.y < Y1 - 1e-3]
    vg.add(inner, 1.0, "REPLACE")
    m.vertex_group = "interno"
    bpy.ops.object.modifier_apply(modifier="dec")
    ob.vertex_groups.clear()


def attributes(ob, M):
    me = ob.data
    co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
    X, Y = co[:, 0], co[:, 1]
    u = (X - X0) / SIZE; v = (Y - Y0) / SIZE
    uvl = me.uv_layers.new(name="UVMap")
    li = np.empty(len(me.loops), np.int32); me.loops.foreach_get("vertex_index", li)
    uvl.data.foreach_set("uv", np.stack([u[li], v[li]], 1).ravel())
    # niente COLOR_0: per glTF moltiplica il colore base. Le maschere stanno in T_terreno_maschere.png (stesse UV).
    for p in me.polygons:
        p.use_smooth = True


def side_mesh(name, Hf, hres, vres_top, vres_bot, side_h):
    """Quattro pareti verticali dal bordo del terreno fino a -8 m, con rilievo dalla texture del lato."""
    verts, faces, uvs = [], [], []
    n_h = side_h.shape[0]
    sides = [  # (punto iniziale, direzione lungo il lato, normale verso l'esterno)
        ((X0, Y0), (1, 0), (0, -1)), ((X1, Y0), (0, 1), (1, 0)),
        ((X1, Y1), (-1, 0), (0, 1)), ((X0, Y1), (0, -1), (-1, 0)),
    ]
    s_off = 0.0
    zs_top = np.arange(0, 3.6 + 1e-6, vres_top)
    zs_bot = np.arange(3.6 + vres_bot, 30, vres_bot)
    for (sx, sy), (ux, uy), (nx, ny) in sides:
        cnt = int(round(SIZE / hres)) + 1
        base = len(verts)
        rows = None
        for k in range(cnt):
            t = k * hres
            px, py = sx + ux * t, sy + uy * t
            top = float(sample(Hf, np.array([px]), np.array([py]))[0])
            depths = np.concatenate([zs_top, zs_bot])
            depths = depths[top - depths > BOTTOM + 1e-3]
            depths = np.append(depths, top - BOTTOM)
            # numero di righe fisso per lato: si ricampiona tra cima e fondo
            if rows is None:
                rows = len(np.concatenate([zs_top, zs_bot[zs_bot < 8.0]])) + 1
            dd = np.concatenate([zs_top, zs_bot[zs_bot < 8.0]])
            dd = np.append(dd, top - BOTTOM)
            dd = np.minimum(dd, top - BOTTOM)
            taper = min(1.0, t / 0.4, (SIZE - t) / 0.4)
            for j, dpt in enumerate(dd):
                z = top - dpt
                uu = (s_off + t) / 8.0
                vv = 1 - dpt / 8.0
                hu = int((uu % 1) * n_h) % n_h
                hv = int(np.clip(vv, 0, 0.999) * n_h)
                disp = (side_h[hv, hu] - 0.45) * 0.16 * taper
                verts.append((px + nx * disp, py + ny * disp, z))
                uvs.append((uu, vv))
        for k in range(cnt - 1):
            for j in range(rows - 1):
                a = base + k * rows + j
                b = base + (k + 1) * rows + j
                faces.append((a, a + 1, b + 1, b))
        s_off += SIZE
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    li = np.empty(len(me.loops), np.int32); me.loops.foreach_get("vertex_index", li)
    uvs = np.array(uvs, np.float32)
    uvl.data.foreach_set("uv", uvs[li].ravel())
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def pbr_material(name, alb, nrm, orm):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    def tex(img, x, y):
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = img; n.location = (x, y); return n
    ta = tex(alb, -600, 300)
    nt.links.new(ta.outputs[0], bsdf.inputs["Base Color"])
    to = tex(orm, -600, 0)
    sp = nt.nodes.new("ShaderNodeSeparateColor"); sp.location = (-300, 0)
    nt.links.new(to.outputs[0], sp.inputs[0])
    nt.links.new(sp.outputs[1], bsdf.inputs["Roughness"])
    nt.links.new(sp.outputs[2], bsdf.inputs["Metallic"])
    # occlusione glTF: nodo gruppo "glTF Material Output" con canale R dell'ORM
    g = bpy.data.node_groups.get("glTF Material Output")
    if g is None:
        g = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        g.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    gn = nt.nodes.new("ShaderNodeGroup"); gn.node_tree = g; gn.location = (0, -300)
    nt.links.new(sp.outputs[0], gn.inputs[0])
    tn = tex(nrm, -600, -300)
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.location = (-300, -300)
    nt.links.new(tn.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    return m


def export(objs, rel):
    p = os.path.join(CUSTOM, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=p, export_format="GLTF_SEPARATE", export_texture_dir="textures", use_selection=True, export_yup=True,
                              export_apply=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO",
                              export_vertex_color="NONE", export_animations=False, export_skins=False)
    return p


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def main():
    okit.reset()
    tex_dir = os.path.join(CUSTOM, "terreno", "textures")
    os.makedirs(tex_dir, exist_ok=True)
    X, Y, H, dx, dy, cliff, sea = heightfield()
    print("heightfield", H.shape, float(H.min()), float(H.max()), flush=True)
    M = masks(H, cliff)
    # mappe per lo shader di terreno e per lo scatter dell'erba
    np_image("splat", np.stack([M["soil"], M["dry"], M["path"], M["sand"]], 2),
             os.path.join(tex_dir, "T_terreno_splat.png"), True)
    np_image("maschere", np.stack([M["rock"], M["ao"], M["density"], M["dryness"]], 2),
             os.path.join(tex_dir, "T_terreno_maschere.png"), True)
    np_image("maschere2", np.stack([M["tall"], M["band"], np.zeros_like(M["tall"]), np.ones_like(M["tall"])], 2),
             os.path.join(tex_dir, "T_terreno_maschere2.png"), True)
    # riferimento: quota -1..3 m in 8 bit (non usata dal gioco)
    np_image("altezza", np.clip((H + 1.0) / 4.0, 0, 1),
             os.path.join(CUSTOM, "_source", "textures", "terreno_heightmap.png"), True)
    print("masks ok", flush=True)
    alb, nrm, orm = bake_layers(M)
    i_alb = np_image("T_terreno_baked_albedo", alb, os.path.join(tex_dir, "T_terreno_baked_albedo.png"))
    i_nrm = np_image("T_terreno_baked_normal", nrm, os.path.join(tex_dir, "T_terreno_baked_normal.png"), True)
    i_orm = np_image("T_terreno_baked_orm", orm, os.path.join(tex_dir, "T_terreno_baked_orm.png"), True)
    print("bake ok", flush=True)
    mat = pbr_material("M_Terreno", i_alb, i_nrm, i_orm)
    # versione mobile: stesse texture cotte a 1K (media 2x2)
    half = lambda a: a.reshape(a.shape[0] // 2, 2, a.shape[1] // 2, 2, -1).mean((1, 3))
    td = tex_dir
    m_alb = np_image("T_terreno_baked_albedo_1k", half(alb), os.path.join(td, "T_terreno_baked_albedo_1k.png"))
    nh = half(nrm) * 2 - 1; nh /= np.maximum(np.linalg.norm(nh, axis=2, keepdims=True), 1e-5)
    m_nrm = np_image("T_terreno_baked_normal_1k", nh * 0.5 + 0.5, os.path.join(td, "T_terreno_baked_normal_1k.png"), True)
    m_orm = np_image("T_terreno_baked_orm_1k", half(orm), os.path.join(td, "T_terreno_baked_orm_1k.png"), True)
    mat_mobile = pbr_material("M_Terreno_Mobile", m_alb, m_nrm, m_orm)
    # lati
    sd = os.path.join(LAYERS, "T_lato_sezione_")
    side_h = load_png(sd + "height.png")[..., 0]
    s_alb = bpy.data.images.load(sd + "albedo.png")
    s_nrm = bpy.data.images.load(sd + "normal.png"); s_nrm.colorspace_settings.name = "Non-Color"
    s_orm = bpy.data.images.load(sd + "orm.png"); s_orm.colorspace_settings.name = "Non-Color"
    mat_side = pbr_material("M_Terreno_Lati", s_alb, s_nrm, s_orm)
    stats = {}
    out = []
    for tag, stride, ratio, hres, vt, vb in (("", 1, 0.16, 0.25, 0.2, 0.6), ("_mobile", 2, 0.22, 0.5, 0.4, 1.2)):
        top = grid_mesh("Terreno_Superficie" + tag, X, Y, H, dx, dy, stride)
        decimate(top, ratio)
        attributes(top, M)
        top.data.materials.append(mat_mobile if tag else mat)
        side = side_mesh("Terreno_Lati" + tag, H, hres, vt, vb, side_h)
        side.data.materials.append(mat_side)
        stats[tag or "_lod0"] = (tri_count(top), tri_count(side))
        out.append((tag, top, side))
        print("mesh", tag, stats, flush=True)
    for tag, top, side in out:
        for o in bpy.context.scene.objects:
            o.hide_set(False)
        export([top, side], f"terreno/terreno_pianura{tag}.gltf")
    okit.save_blend("terreno/terreno_pianura.blend")
    print("STATS", stats)


main()
