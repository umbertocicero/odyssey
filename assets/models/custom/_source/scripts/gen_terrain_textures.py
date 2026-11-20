"""Texture PBR tileable del terreno (stile scansione fotogrammetrica) e atlas delle grass cards.

Tutto procedurale in numpy, periodico (tileable senza cuciture): rumore frattale filtrato in
frequenza, Voronoi con distanze avvolte, tratti di fili d'erba rasterizzati.

Uso: blender -b --factory-startup -P gen_terrain_textures.py [-- nome ...]
Uscite in assets/models/custom/terreno/textures/ (vedi README della cartella terreno).
"""
import bpy, sys, os, math
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "terreno", "textures")
LAYERS = os.path.join(ROOT, "_source", "textures", "terreno_layers")
os.makedirs(LAYERS, exist_ok=True)
N = 1024


# ---------------------------------------------------------------- utilita'
def save(path, arr):
    """arr HxWxC in 0..1, riga 0 = basso dell'immagine (convenzione Blender)."""
    arr = np.clip(arr, 0, 1).astype(np.float32)
    if arr.ndim == 2:
        arr = np.repeat(arr[:, :, None], 3, axis=2)
    h, w, c = arr.shape
    if c == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1), np.float32)], axis=2)
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=(c == 4))
    img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def norm01(a):
    a = a - a.min()
    return a / max(a.max(), 1e-8)


def fbm(seed, beta=2.0, fmin=1, fmax=None, n=N, shape=None):
    """Rumore frattale periodico: rumore bianco filtrato con spettro 1/f^beta tra fmin e fmax cicli per tile."""
    h, w = shape or (n, n)
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((h, w))
    F = np.fft.fft2(white)
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    amp = f ** (-beta / 2)
    amp[f < fmin] = 0
    if fmax:
        amp *= np.exp(-((f / fmax) ** 4))
    amp[0, 0] = 0
    return norm01(np.real(np.fft.ifft2(F * amp)))


def ridged(seed, **k):
    return 1 - np.abs(fbm(seed, **k) * 2 - 1)


def voronoi(seed, cells, jitter=0.9, n=N, aspect=1):
    """Voronoi periodico su griglia jitterata. Ritorna F1, F2 (in unita' cella) e id cella (0..1)."""
    rng = np.random.default_rng(seed)
    cx, cy = cells, cells * aspect
    pts = (rng.random((cy, cx, 2)) - 0.5) * jitter + 0.5
    ids = rng.random((cy, cx))
    ys, xs = np.mgrid[0:n * aspect, 0:n].astype(np.float32)
    ux = xs / n * cx
    uy = ys / (n * aspect) * cy
    ix = np.floor(ux).astype(int)
    iy = np.floor(uy).astype(int)
    f1 = np.full(ux.shape, 9.0, np.float32)
    f2 = np.full(ux.shape, 9.0, np.float32)
    cid = np.zeros(ux.shape, np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            jx = ix + dx
            jy = iy + dy
            p = pts[jy % cy, jx % cx]
            px = jx + p[..., 0]
            py = jy + p[..., 1]
            d = np.sqrt((ux - px) ** 2 + (uy - py) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, ids[jy % cy, jx % cx], cid)
            f1 = np.where(closer, d, f1)
    return f1, f2, cid


def blur(a, r):
    """Sfocatura gaussiana periodica via FFT (r in pixel)."""
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (math.pi * r) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def normal_map(h, strength):
    """Normal map OpenGL (verde = +V), come la usano Godot e glTF. strength = rilievo in pixel per unita' di h."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def cavity_ao(h, scale=1.0):
    """Occlusione dalla profondita' rispetto all'intorno, su tre scale."""
    ao = np.ones_like(h)
    for r, k in ((2, 1.6), (8, 1.4), (24, 1.0)):
        ao -= np.clip((blur(h, r * scale) - h) * k * 4, 0, 1) * 0.33
    return np.clip(ao, 0, 1)


def lerp(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a + (np.asarray(b) - a) * t


def col(*rgb):
    return np.array(rgb, np.float32)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def pebbles(seed, cells, density, rmin=0.2, rmax=0.42, n=N):
    """Sassolini a cupola: altezza, maschera e id."""
    f1, f2, cid = voronoi(seed, cells, 0.8, n)
    r = rmin + (rmax - rmin) * np.modf(cid * 7.31)[0]
    keep = np.modf(cid * 13.7)[0] < density
    d = f1 / r
    dome = np.sqrt(np.clip(1 - d * d, 0, 1)) * keep
    return dome, (dome > 0).astype(np.float32), cid


def strokes(seed, count, n, length, width, angle_spread, base_angle=None, tip_bias=1.0):
    """Fili d'erba visti dall'alto: tratti periodici. Ritorna altezza, id filo, posizione lungo il filo."""
    rng = np.random.default_rng(seed)
    key = np.zeros((n, n), np.int64)
    pts_y, pts_x, vals = [], [], []
    steps = 24
    for b in range(count):
        x0, y0 = rng.random(2) * n
        ang = (base_angle if base_angle is not None else rng.random() * math.tau) + rng.normal() * angle_spread
        L = length * rng.uniform(0.5, 1.3)
        bend = rng.normal() * 0.6
        t = np.linspace(0, 1, steps)
        a = ang + bend * t
        xs = x0 + np.cumsum(np.cos(a)) * L / steps
        ys = y0 + np.cumsum(np.sin(a)) * L / steps
        hgt = (0.35 + 0.65 * t ** tip_bias) * rng.uniform(0.6, 1.0)
        pts_x.append(xs); pts_y.append(ys); vals.append(np.stack([hgt, t, np.full(steps, b)], 1))
    X = np.concatenate(pts_x); Y = np.concatenate(pts_y); V = np.concatenate(vals)
    q = (np.clip(V[:, 0], 0, 1) * 4000).astype(np.int64) << 32 | (V[:, 2].astype(np.int64) << 8) | (V[:, 1] * 255).astype(np.int64)
    r = int(math.ceil(width))
    for oy in range(-r, r + 1):
        for ox in range(-r, r + 1):
            if ox * ox + oy * oy > width * width:
                continue
            fall = 1 - (ox * ox + oy * oy) / (width * width + 1) * 0.5
            qq = ((q >> 32) * fall).astype(np.int64) << 32 | (q & 0xFFFFFFFF)
            np.maximum.at(key, ((Y.astype(int) + oy) % n, (X.astype(int) + ox) % n), qq)
    hgt = (key >> 32).astype(np.float32) / 4000
    bid = ((key >> 8) & 0xFFFFFF).astype(np.float32)
    tpos = (key & 0xFF).astype(np.float32) / 255
    return hgt, bid, tpos, key > 0


# ---------------------------------------------------------------- materiali
def mat_soil():
    """Terra fertile scura: zolle, sassolini, frammenti organici."""
    base = fbm(11, 2.2, 2)
    moist = fbm(12, 2.6, 1, 6)
    f1, f2, cid = voronoi(13, 34, 0.9)
    clods = np.sqrt(np.clip(1 - f1 * 1.15, 0, 1))
    peb, pm, pid = pebbles(14, 70, 0.16, 0.18, 0.4)
    fine = fbm(15, 1.0, 64)
    h = 0.40 * base + 0.25 * clods * (0.6 + 0.4 * base) + 0.30 * peb + 0.07 * fine
    h = norm01(h)
    ao = cavity_ao(h)
    c = lerp(col(0.25, 0.17, 0.11), col(0.36, 0.26, 0.17), base * 0.8 + fine * 0.2)
    c = lerp(c, col(0.17, 0.11, 0.07), moist * 0.55)
    stone = lerp(col(0.46, 0.40, 0.33), col(0.30, 0.25, 0.20), np.modf(pid * 3.7)[0])
    stone = stone * (0.85 + 0.25 * fine[..., None])
    c = lerp(c, stone, smooth(0, 0.25, peb))
    # rametti e paglia secca
    tw, _, _, tm = strokes(16, 900, N, 22, 1.2, 3.0)
    c = lerp(c, col(0.52, 0.42, 0.26) * (0.7 + 0.5 * tw[..., None]), tm * 0.75)
    h = np.maximum(h, tw * 0.55 * tm + h * (1 - tm))
    c *= (0.55 + 0.45 * ao)[..., None]
    rough = 0.93 - moist * 0.16 - smooth(0, 0.3, peb) * 0.15
    return c, h, rough, ao, 7.0


def mat_dirt_dry():
    """Terra secca crepata: placche arricciate, polvere chiara, crepe scure."""
    f1, f2, cid = voronoi(21, 11, 0.95)
    edge = f2 - f1
    crack = (1 - smooth(0.0, 0.035, edge)) * smooth(0.3, 0.6, fbm(26, 2.2, 2, 10))
    f1b, f2b, _ = voronoi(22, 30, 0.95)
    crack2 = (1 - smooth(0.0, 0.025, f2b - f1b)) * smooth(0.45, 0.7, fbm(27, 2.2, 2, 10))
    plate = smooth(0.0, 0.25, edge) * 0.25 + 0.75 + fbm(28, 1.8, 4) * 0.3
    dust = fbm(23, 2.0, 2)
    fine = fbm(24, 1.0, 80)
    peb, pm, pid = pebbles(25, 90, 0.12, 0.15, 0.35)
    h = plate * 0.7 - crack * 0.5 - crack2 * 0.15 * (dust > 0.45) + dust * 0.2 + fine * 0.06 + peb * 0.25
    h = norm01(h)
    ao = cavity_ao(h)
    c = lerp(col(0.55, 0.44, 0.30), col(0.68, 0.57, 0.41), dust)
    c = lerp(c, col(0.47, 0.36, 0.24), np.modf(cid * 5.1)[0][..., None] * 0.12)
    c = lerp(c, col(0.40, 0.31, 0.21), smooth(0.5, 0.8, fbm(29, 2.4, 2, 12)) * 0.6)
    c = lerp(c, col(0.62, 0.56, 0.48), smooth(0, 0.3, peb))
    c = lerp(c, col(0.24, 0.17, 0.11), crack * 0.85)
    c *= (0.85 + 0.25 * fine)[..., None]
    c *= (0.6 + 0.4 * ao)[..., None]
    rough = 0.96 - smooth(0, 0.3, peb) * 0.1
    return c, h, rough, ao, 6.0


def mat_path():
    """Sentiero battuto: terra compatta con ghiaino incastrato e solchi leggeri."""
    base = fbm(31, 2.4, 1)
    ruts = fbm(32, 2.0, 1, 5, shape=(N, N))
    peb, pm, pid = pebbles(33, 110, 0.25, 0.2, 0.42)
    peb2, pm2, pid2 = pebbles(34, 40, 0.15, 0.2, 0.4)
    fine = fbm(35, 1.1, 60)
    h = 0.30 * base + 0.15 * ruts + 0.28 * peb + 0.35 * peb2 + 0.06 * fine
    h = norm01(h)
    ao = cavity_ao(h)
    c = lerp(col(0.45, 0.35, 0.24), col(0.58, 0.47, 0.33), base * 0.7 + ruts * 0.3)
    st = lerp(col(0.56, 0.50, 0.42), col(0.40, 0.34, 0.27), np.modf(pid * 3.3)[0])
    st2 = lerp(col(0.66, 0.60, 0.50), col(0.48, 0.42, 0.36), np.modf(pid2 * 2.9)[0])
    c = lerp(c, st, smooth(0, 0.3, peb) * (1 - pm2))
    c = lerp(c, st2 * (0.85 + 0.3 * fine[..., None]), smooth(0, 0.3, peb2))
    c *= (0.88 + 0.22 * fine)[..., None]
    c *= (0.55 + 0.45 * ao)[..., None]
    rough = 0.88 - smooth(0, 0.3, np.maximum(peb, peb2)) * 0.22
    return c, h, rough, ao, 6.0


def mat_meadow():
    """Prato basso con muschio: fili d'erba oliva con punte secche, cuscinetti di muschio, terra che affiora."""
    soil = fbm(41, 2.0, 2)
    moss_mask = smooth(0.45, 0.65, fbm(42, 2.4, 2, 12))
    moss_bump = fbm(43, 0.8, 90)
    lush = fbm(44, 2.2, 1, 6)
    hb, bid, tpos, bm = strokes(45, 22000, N, 26, 1.6, 0.9, None, 1.2)
    hb2, bid2, tpos2, bm2 = strokes(46, 10000, N, 14, 1.2, 1.2, None, 1.0)
    moss_h = moss_mask * (0.35 + 0.25 * moss_bump)
    h = np.maximum(np.maximum(soil * 0.2, moss_h), np.maximum(hb * 0.9, hb2 * 0.7))
    h = norm01(h)
    ao = cavity_ao(h, 0.8)
    rb = np.modf(bid * 0.6180339)[0]
    green = lerp(col(0.20, 0.29, 0.08), col(0.33, 0.43, 0.13), rb)
    dry = lerp(col(0.62, 0.55, 0.30), col(0.70, 0.60, 0.36), rb)
    blade = lerp(green, dry, smooth(0.55, 1.0, tpos) * (0.35 + 0.65 * (1 - lush)))
    blade = lerp(blade, dry * 0.9, (np.modf(bid * 3.17)[0] < 0.12) * 1.0)
    rb2 = np.modf(bid2 * 0.7548)[0]
    blade2 = lerp(col(0.30, 0.34, 0.13), col(0.52, 0.48, 0.24), rb2 * 0.7 + tpos2 * 0.3)
    c = lerp(col(0.22, 0.16, 0.10), col(0.32, 0.24, 0.15), soil)
    mossc = lerp(col(0.25, 0.30, 0.10), col(0.40, 0.42, 0.15), moss_bump)
    c = lerp(c, mossc, moss_mask)
    top2 = bm2 & (hb2 * 0.7 >= hb * 0.9)
    top1 = bm & ~top2
    c = np.where(top1[..., None], blade, c)
    c = np.where(top2[..., None], blade2, c)
    c *= (0.5 + 0.5 * ao)[..., None]
    rough = 0.9 - moss_mask * 0.05
    return c, h, rough, ao, 5.0


def mat_sand():
    """Sabbia di spiaggia con increspature, ghiaia e conchiglie spezzate."""
    grain = fbm(51, 0.4, 200)
    big = fbm(52, 2.4, 1)
    warp = fbm(53, 2.6, 1, 4) * 2.0
    ys, xs = np.mgrid[0:N, 0:N] / N
    ripple = 0.5 + 0.5 * np.sin(math.tau * (9 * xs + 2 * ys) + warp * 3)
    ripple = ripple ** 1.6
    gmask = smooth(0.55, 0.7, fbm(54, 2.2, 1, 8))
    peb, pm, pid = pebbles(55, 80, 0.6, 0.2, 0.45)
    peb *= gmask
    shells, smk, sid = pebbles(56, 50, 0.08, 0.12, 0.25)
    h = 0.3 * big + 0.25 * ripple * (1 - gmask) + 0.1 * grain + 0.45 * peb + 0.15 * shells
    h = norm01(h)
    ao = cavity_ao(h)
    c = lerp(col(0.74, 0.64, 0.47), col(0.84, 0.75, 0.57), big * 0.6 + ripple * 0.4)
    c *= (0.88 + 0.24 * grain)[..., None]
    st = lerp(col(0.66, 0.62, 0.56), col(0.40, 0.36, 0.32), np.modf(pid * 4.1)[0])
    st = lerp(st, col(0.78, 0.74, 0.68), (np.modf(pid * 9.3)[0] < 0.25) * 1.0)
    c = lerp(c, st, smooth(0, 0.25, peb))
    c = lerp(c, col(0.93, 0.88, 0.80), smooth(0, 0.3, shells))
    c *= (0.65 + 0.35 * ao)[..., None]
    rough = 0.92 - smooth(0, 0.3, peb) * 0.25
    return c, h, rough, ao, 5.0


def mat_rock():
    """Calcare caldo a strati: fratture, stratificazione, licheni e muschio nelle fessure."""
    ys, xs = np.mgrid[0:N, 0:N] / N
    warp = fbm(61, 2.4, 1, 6)
    strata = 0.5 + 0.5 * np.sin(math.tau * (5 * ys + 1 * xs) + warp * 5)
    f1, f2, cid = voronoi(62, 5, 0.95)
    frac = (1 - smooth(0, 0.03, f2 - f1)) * smooth(0.35, 0.6, fbm(68, 2.0, 2, 8))
    f1b, f2b, cidb = voronoi(63, 19, 0.95)
    frac2 = (1 - smooth(0, 0.02, f2b - f1b)) * smooth(0.5, 0.7, fbm(69, 2.0, 2, 8))
    rid = ridged(64, beta=2.0, fmin=2)
    fine = fbm(65, 1.0, 70)
    facet = blur(np.modf(cid * 4.3)[0], 6)
    big = fbm(70, 2.6, 1)
    h = 0.45 * rid + 0.25 * strata + 0.1 * facet + 0.35 * big + 0.12 * fine - 0.3 * frac - 0.1 * frac2
    h = norm01(h)
    ao = cavity_ao(h)
    c = lerp(col(0.55, 0.50, 0.43), col(0.68, 0.62, 0.53), strata * 0.5 + rid * 0.5)
    c = lerp(c, col(0.45, 0.41, 0.37), facet[..., None] * 0.25 + big[..., None] * 0.25)
    c *= (0.85 + 0.3 * fine)[..., None]
    lich = smooth(0.62, 0.72, fbm(66, 1.8, 6)) * (1 - frac)
    c = lerp(c, col(0.66, 0.52, 0.28), lich * 0.6)
    moss = smooth(0.4, 0.8, blur(frac + frac2 * 0.5, 4)) * smooth(0.4, 0.6, fbm(67, 2.0, 2))
    c = lerp(c, col(0.28, 0.31, 0.13), moss * 0.8)
    c = lerp(c, col(0.22, 0.18, 0.15), frac * 0.6)
    c *= (0.5 + 0.5 * ao)[..., None]
    rough = 0.82 + fine * 0.1 - lich * 0.05
    return c, h, rough, ao, 9.0


def mat_side():
    """Lato del blocco in sezione (8 m x 8 m, tile solo in orizzontale): cotica erbosa,
    muro di blocchi di pietra, terra scura con radici e sassi. v = 1 in cima (quota 0), v = 0 a -8 m."""
    rng = np.random.default_rng(71)
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float32)
    depth = (N - 1 - ys) / N * 8.0  # metri sotto il bordo
    px = N / 8.0
    fine = fbm(72, 1.0, 60)
    earth_n = fbm(73, 2.2, 2)
    h = np.zeros((N, N), np.float32)
    c = np.zeros((N, N, 3), np.float32)
    # terra con radici sotto
    eh = 0.35 * earth_n + 0.08 * fine
    peb, pm, pid = pebbles(74, 26, 0.35, 0.2, 0.45)
    eh = eh + peb * 0.4
    ec = lerp(col(0.20, 0.14, 0.10), col(0.32, 0.23, 0.15), earth_n)
    ec = lerp(ec, col(0.40, 0.36, 0.31) * (0.8 + 0.3 * fine[..., None]), smooth(0, 0.3, peb))
    rh, rid_, rt, rm = strokes(75, 160, N, 140, 2.2, 0.35, -math.pi / 2, 1.0)
    rm = rm & (depth > 3.2)
    ec = lerp(ec, col(0.28, 0.19, 0.12) * (0.8 + 0.4 * rh[..., None]), rm * 1.0)
    eh = np.where(rm, np.maximum(eh, 0.45 + rh * 0.3), eh)
    # muro di pietra a corsi irregolari, periodico in orizzontale
    wall_top, wall_bot = 0.35, 3.4
    wh = np.zeros((N, N), np.float32)
    wc = np.zeros((N, N, 3), np.float32)
    zc = wall_top
    k = 0
    while zc < wall_bot:
        ch = rng.uniform(0.38, 0.62)
        z1 = min(zc + ch, wall_bot)
        widths = []
        while sum(widths) < 8.0:
            widths.append(rng.uniform(0.55, 1.15))
        widths = np.array(widths) * 8.0 / sum(widths)
        off = rng.uniform(0, 8)
        x0 = off
        for w in widths:
            # blocco [x0, x0+w] x [zc, z1] in metri (con avvolgimento)
            gap = rng.uniform(0.025, 0.06)
            cxm = x0 + w / 2
            hx = w / 2 - gap
            hz = (z1 - zc) / 2 - gap
            czm = (zc + z1) / 2
            dxm = (xs / px - cxm + 4) % 8 - 4
            dzm = depth - czm
            q = np.stack([np.abs(dxm) - hx + 0.06, np.abs(dzm) - hz + 0.06], 0)
            sd = np.linalg.norm(np.maximum(q, 0), axis=0) + np.minimum(np.maximum(q[0], q[1]), 0) - 0.06
            inside = sd < 0
            prof = np.clip(-sd / 0.07, 0, 1) ** 0.6
            tone = rng.uniform(0, 1)
            sc = lerp(col(0.62, 0.55, 0.44), col(0.48, 0.43, 0.37), np.full((N, N), tone))
            chip = fbm(int(rng.integers(1e6)), 1.6, 8, shape=None) if k < 0 else None
            wh = np.where(inside, np.maximum(wh, prof * (0.75 + 0.1 * tone)), wh)
            wc = np.where(inside[..., None], sc, wc)
            x0 += w
            k += 1
        zc = z1
    chip = fbm(76, 1.4, 12)
    wh = wh * (0.85 + 0.25 * chip) - smooth(0.7, 0.8, fbm(77, 1.6, 10)) * 0.25 * (wh > 0)
    wc = wc * (0.8 + 0.35 * chip[..., None])
    wall = (depth > wall_top) & (depth < wall_bot)
    mortar = wall & (wh <= 0.01)
    wc = np.where(mortar[..., None], col(0.18, 0.13, 0.09), wc)
    moss = smooth(0.5, 0.75, fbm(78, 2.0, 3)) * smooth(1.6, 0.4, depth)
    wc = lerp(wc, col(0.27, 0.31, 0.12), moss[..., None] * (wh > 0)[..., None] * 0.85)
    # cotica in cima: terra scura, radici fini, erba che ricade
    th = 0.5 + 0.2 * earth_n + 0.1 * fine
    gh, gid, gt, gm = strokes(79, 2600, N, 34, 1.4, 0.35, -math.pi / 2, 1.0)
    turf_c = lerp(col(0.18, 0.13, 0.09), col(0.28, 0.20, 0.13), earth_n)
    gcol = lerp(col(0.30, 0.34, 0.13), col(0.60, 0.53, 0.28), (gt * 0.6 + np.modf(gid * 0.618)[0] * 0.4))
    turf = depth <= wall_top
    hang = gm & (depth < wall_top + 0.35)
    h = np.where(depth >= wall_bot, eh, np.where(wall, wh * 0.9 + 0.05, th))
    c = np.where((depth >= wall_bot)[..., None], ec, np.where(wall[..., None], wc, turf_c))
    c = np.where(hang[..., None], gcol, c)
    h = np.where(hang, np.maximum(h, 0.7 + 0.3 * gh), h)
    h = norm01(h)
    ao = cavity_ao(h)
    c *= (0.5 + 0.5 * ao)[..., None]
    rough = np.where(wall, 0.85, 0.94)
    return c, h, rough, ao, 9.0


MATS = {
    "terra": mat_soil,
    "terra_secca": mat_dirt_dry,
    "sentiero": mat_path,
    "prato_muschio": mat_meadow,
    "sabbia_ghiaia": mat_sand,
    "roccia": mat_rock,
    "lato_sezione": mat_side,
}
# Ordine degli strati nei Texture2DArray del terreno (indice = slice).
ARRAY_ORDER = ["prato_muschio", "terra", "terra_secca", "sentiero", "sabbia_ghiaia", "roccia"]


def build_material(name):
    c, h, rough, ao, nstr = MATS[name]()
    # sRGB: i valori di colore sopra sono gia' pensati in sRGB
    save(os.path.join(LAYERS, f"T_{name}_albedo.png"), c)
    save(os.path.join(LAYERS, f"T_{name}_normal.png"), normal_map(h, nstr))
    orm = np.stack([ao, np.clip(rough, 0, 1) * np.ones_like(ao), np.zeros_like(ao)], 2)
    save(os.path.join(LAYERS, f"T_{name}_orm.png"), orm)
    save(os.path.join(LAYERS, f"T_{name}_height.png"), h)
    return c, h, rough, ao, nstr


# ---------------------------------------------------------------- grass cards
TILE_W, TILE_H = 256, 512


def card_tile(seed, kind):
    """Un ciuffo disegnato a 2x e ridotto (alpha antialias). Ritorna rgba, normal, sss (TILE_H x TILE_W)."""
    S = 2
    W, H = TILE_W * S, TILE_H * S
    rng = np.random.default_rng(seed)
    key = np.zeros((H, W), np.int64)
    prof = np.zeros((H, W), np.float32)
    colors = {}
    P = {
        "lush":    dict(n=220, hmin=0.55, hmax=0.95, dry=0.18, w=7, spread=0.38, bend=0.5),
        "tips":    dict(n=250, hmin=0.5, hmax=0.98, dry=0.55, w=6, spread=0.42, bend=0.6),
        "medium":  dict(n=270, hmin=0.3, hmax=0.65, dry=0.3, w=6, spread=0.5, bend=0.6),
        "short":   dict(n=340, hmin=0.15, hmax=0.38, dry=0.25, w=6, spread=0.7, bend=0.5),
        "dry":     dict(n=220, hmin=0.45, hmax=0.95, dry=1.0, w=5, spread=0.45, bend=0.7),
        "weeds":   dict(n=36, hmin=0.3, hmax=0.75, dry=0.15, w=8, spread=0.55, bend=0.4),
        "flowers": dict(n=75, hmin=0.3, hmax=0.7, dry=0.25, w=5, spread=0.45, bend=0.4),
        "seeds":   dict(n=150, hmin=0.5, hmax=0.95, dry=0.8, w=5, spread=0.35, bend=0.5),
        "long":    dict(n=320, hmin=0.7, hmax=1.0, dry=0.3, w=3.4, spread=0.22, bend=1.0, lean=0.35),
        "long_dry": dict(n=300, hmin=0.65, hmax=1.0, dry=0.85, w=3.4, spread=0.22, bend=1.0, lean=0.35),
    }[kind]
    stamps = []  # (x, y, r, keyval)
    blade_id = 0

    def blade(x0, L, ang, bend, w0, widthfn, colfn, z):
        nonlocal blade_id
        blade_id += 1
        steps = int(L * H / 3) + 8
        t = np.linspace(0, 1, steps)
        a = ang + bend * t ** 1.5
        xs = x0 + np.cumsum(np.sin(a)) * L * H / steps
        ys = np.cumsum(np.cos(a)) * L * H / steps + 4
        ws = w0 * widthfn(t)
        colors[blade_id] = colfn
        for i in range(steps):
            stamps.append((xs[i], ys[i], max(ws[i], 0.6), z, blade_id, t[i]))
        return xs[-1], ys[-1]

    def g_col(dryness):
        base = np.array([0.13, 0.22, 0.05]) * rng.uniform(0.85, 1.1)
        mid = np.array([0.28, 0.42, 0.11]) * rng.uniform(0.85, 1.12)
        tip = np.array([0.66, 0.58, 0.31]) * rng.uniform(0.9, 1.08)
        d = np.clip(dryness * rng.uniform(0.4, 1.4), 0, 1)
        if rng.random() < dryness * 0.5:
            mid = lerp(mid, tip * 0.85, 0.7)
        return lambda t: lerp(lerp(base, mid, smooth(0, 0.45, t)), tip, smooth(1 - d * 0.8, 1.0, t) * min(1, d * 1.5))

    taper = lambda t: (1 - t) ** 0.9 * (0.6 + 0.4 * np.sin(np.minimum(t * 6, 1.5)))
    leaf = lambda t: np.sin(np.pi * np.clip(t, 0, 1)) ** 0.8
    for i in range(P["n"]):
        L = rng.uniform(P["hmin"], P["hmax"])
        x0 = W / 2 + np.clip(rng.normal(), -2, 2) * W * 0.10
        ang = np.clip(rng.normal(), -2, 2) * P["spread"] * 0.45 + (x0 - W / 2) / W * 1.0 + P.get("lean", 0.0)
        bend = np.clip(rng.normal(), -2, 2) * P["bend"] * 0.7
        reach = abs(math.sin(ang) + math.sin(ang + bend)) * 0.5 * L * H
        if reach > W * 0.46 - abs(x0 - W / 2):
            k_ = (W * 0.46 - abs(x0 - W / 2)) / max(reach, 1)
            ang *= max(k_, 0); bend *= max(k_, 0)
        z = rng.random()
        if kind == "weeds" and i % 2 == 0:
            # stelo con foglie larghe
            xe, ye = blade(x0, L, ang * 0.6, bend * 0.4, 2.5, lambda t: np.ones_like(t), g_col(0.1), z)
            for j in range(rng.integers(3, 7)):
                tt = rng.uniform(0.15, 0.9)
                sx = x0 + (xe - x0) * tt
                la = ang + rng.choice([-1, 1]) * rng.uniform(0.6, 1.2)
                stamps_len = L * rng.uniform(0.15, 0.3)
                blade_x = sx
                blade_off = ye * tt
                b0 = len(stamps)
                blade(blade_x, stamps_len, la, rng.normal() * 0.5, rng.uniform(9, 14), leaf, g_col(0.05), z + 0.01)
                for k in range(b0, len(stamps)):
                    s = stamps[k]
                    stamps[k] = (s[0], s[1] + blade_off, s[2], s[3], s[4], s[5])
            continue
        xe, ye = blade(x0, L, ang, bend, P["w"] * rng.uniform(0.7, 1.3), taper, g_col(P["dry"]), z)
        if kind == "flowers" and i % 3 == 0:
            pc = [np.array([0.50, 0.32, 0.62]), np.array([0.88, 0.72, 0.22]), np.array([0.92, 0.90, 0.84])][i % 9 // 3]
            for j in range(9):
                a = j / 9 * math.tau
                blade_id_local = blade_id + 1
                colors[blade_id_local] = (lambda c: (lambda t: c * (0.85 + 0.25 * t)))(pc * rng.uniform(0.85, 1.1))
                stamps.append((xe + math.cos(a) * 9, ye + math.sin(a) * 6 + 4, 6.5, z + 0.02, blade_id_local, 0.8))
                globals()["_dummy"] = 0
            blade_id += 1
            colors[blade_id + 1] = (lambda t: np.array([0.80, 0.62, 0.20]))
            blade_id += 1
            stamps.append((xe, ye + 4, 5.0, z + 0.03, blade_id, 1.0))
        if kind == "seeds" and i % 2 == 0:
            blade_id += 1
            colors[blade_id] = (lambda c: (lambda t: c))(np.array([0.74, 0.64, 0.38]) * rng.uniform(0.85, 1.1))
            for j in range(16):
                tt = j / 16
                stamps.append((xe + math.sin(ang + bend) * tt * -40 + rng.normal() * 3,
                               ye - math.cos(ang + bend) * tt * 40, 5.5 - tt * 2, z + 0.01, blade_id, 0.9))
    # rasterizzazione: z piu' alto vince
    st = np.array(stamps, np.float64)
    order = np.argsort(st[:, 3])
    st = st[order]
    idbuf = np.zeros((H, W), np.int32)
    tbuf = np.zeros((H, W), np.float32)
    pbuf = np.zeros((H, W), np.float32)
    for x, y, r, z, bid, t in st:
        ri = int(math.ceil(r))
        x0, x1 = int(x) - ri, int(x) + ri + 1
        y0, y1 = int(y) - ri, int(y) + ri + 1
        if x1 <= 0 or y1 <= 0 or x0 >= W or y0 >= H:
            continue
        xa, xb, ya, yb = max(x0, 0), min(x1, W), max(y0, 0), min(y1, H)
        gy, gx = np.mgrid[ya:yb, xa:xb]
        d2 = ((gx - x) ** 2 + (gy - y) ** 2) / (r * r)
        m = d2 <= 1
        idbuf[ya:yb, xa:xb][m] = int(bid)
        tbuf[ya:yb, xa:xb][m] = t
        pbuf[ya:yb, xa:xb][m] = np.sqrt(1 - d2[m])
    alpha = (idbuf > 0).astype(np.float32)
    rgb = np.zeros((H, W, 3), np.float32)
    for bid in np.unique(idbuf):
        if bid == 0:
            continue
        m = idbuf == bid
        cf = colors.get(int(bid), lambda t: np.array([0.3, 0.35, 0.14]))
        tt = tbuf[m]
        cc = np.stack([cf(v) for v in np.round(tt, 2)]) if False else None
        lut_t = np.linspace(0, 1, 33)
        lut = np.stack([np.asarray(cf(v), np.float32) * np.ones(3) for v in lut_t])
        idx = np.clip((tt * 32).astype(int), 0, 32)
        rgb[m] = lut[idx]
    # variazione fine e occlusione verso la base del ciuffo
    yy = np.mgrid[0:H, 0:W][0] / H
    fine = fbm(seed + 5, 1.0, 60, shape=(H, W))
    rgb *= (0.88 + 0.24 * fine)[..., None]
    rgb *= (0.45 + 0.55 * smooth(0.0, 0.45, yy))[..., None]
    # normale: profilo a cupola attraverso il filo
    nrm = normal_map(pbuf * 3.0, 4.0)
    sss = np.clip(0.35 + 0.65 * tbuf, 0, 1) * (1 - 0.4 * pbuf) * alpha
    # riduzione 2x
    def down(a):
        if a.ndim == 2:
            return a.reshape(TILE_H, S, TILE_W, S).mean((1, 3))
        return a.reshape(TILE_H, S, TILE_W, S, a.shape[2]).mean((1, 3))
    a2 = down(alpha)
    # colore premoltiplicato per evitare aloni scuri, poi dilatato sotto l'alpha
    rgb2 = down(rgb * alpha[..., None]) / np.maximum(a2[..., None], 1e-4)
    for _ in range(6):
        empty = a2 < 0.01
        if not empty.any():
            break
        acc = np.zeros_like(rgb2); cnt = np.zeros(a2.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sm = np.roll(~empty, (dy, dx), (0, 1))
            acc += np.roll(rgb2, (dy, dx), (0, 1)) * sm[..., None]; cnt += sm
        fill = empty & (cnt > 0)
        rgb2[fill] = acc[fill] / cnt[fill][..., None]
        a2 = np.where(fill, 0.005, a2)
    a2 = np.where(a2 <= 0.005, 0, a2)
    return np.concatenate([rgb2, a2[..., None]], 2), down(nrm), down(sss)


CARD_KINDS = ["lush", "tips", "medium", "short", "dry", "weeds", "flowers", "seeds", "long", "long_dry"]
ROWS = 3


def build_cards():
    atlas = np.zeros((ROWS * TILE_H, 4 * TILE_W, 4), np.float32)
    natl = np.zeros((ROWS * TILE_H, 4 * TILE_W, 3), np.float32)
    satl = np.zeros((ROWS * TILE_H, 4 * TILE_W), np.float32)
    natl[..., :] = (0.5, 0.5, 1.0)
    for i, kind in enumerate(CARD_KINDS):
        col_i, row = i % 4, ROWS - 1 - i // 4  # prima riga dell'atlas in alto nell'immagine
        rgba, nrm, sss = card_tile(100 + i * 17, kind)
        ys, xs = row * TILE_H, col_i * TILE_W
        atlas[ys:ys + TILE_H, xs:xs + TILE_W] = rgba
        natl[ys:ys + TILE_H, xs:xs + TILE_W] = nrm
        satl[ys:ys + TILE_H, xs:xs + TILE_W] = sss
        print("card", kind)
    save(os.path.join(OUT, "T_erba_cards_albedo_alpha.png"), atlas)
    save(os.path.join(OUT, "T_erba_cards_normal.png"), natl)
    # R = translucenza (SSS / spessore inverso), G = roughness, B = AO dentro il ciuffo
    yy = np.tile(np.concatenate([np.linspace(0, 1, TILE_H)] * ROWS)[:, None], (1, 4 * TILE_W))
    orm = np.stack([satl, np.full_like(satl, 0.62), 0.5 + 0.5 * smooth(0, 0.5, yy)], 2)
    save(os.path.join(OUT, "T_erba_cards_sss_rough_ao.png"), orm)


def build_arrays(cache):
    """Texture2DArray verticali per lo shader di terreno: 6 slice da 1024 nell'ordine ARRAY_ORDER
    (la slice 0 e' in cima all'immagine)."""
    alb, nor, orm = [], [], []
    for name in reversed(ARRAY_ORDER):  # riga 0 = basso dell'immagine -> ultima slice
        c, h, rough, ao, nstr = cache[name]
        alb.append(np.concatenate([c, h[..., None]], 2))  # A = altezza per il blend
        nor.append(normal_map(h, nstr))
        orm.append(np.stack([ao, np.clip(rough, 0, 1) * np.ones_like(ao), h], 2))
    save(os.path.join(OUT, "T_terreno_array_albedo_height.png"), np.concatenate(alb, 0))
    save(os.path.join(OUT, "T_terreno_array_normal.png"), np.concatenate(nor, 0))
    save(os.path.join(OUT, "T_terreno_array_orm.png"), np.concatenate(orm, 0))


def build_clouds():
    """Ombre di nuvole tileable (512, 1 canale): 1 = sole pieno, ~0,55 = ombra. Da scorrere piano sul terreno."""
    n = 512
    f = fbm(901, 2.2, 1, 6, shape=(n, n))
    f2 = fbm(902, 1.6, 2, 12, shape=(n, n))
    c = smooth(0.46, 0.62, f * 0.8 + f2 * 0.2)
    save(os.path.join(OUT, "T_nuvole_ombra.png"), 1.0 - 0.45 * c)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in argv if a in MATS] or list(MATS)
    cache = {}
    for n in names:
        cache[n] = build_material(n)
        print("ok", n, flush=True)
    if not argv or "arrays" in argv:
        if all(n in cache for n in ARRAY_ORDER):
            build_arrays(cache)
            print("ok arrays")
    if not argv or "cards" in argv:
        build_cards()
        print("ok cards")
    if not argv or "clouds" in argv:
        build_clouds()
        print("ok clouds")
