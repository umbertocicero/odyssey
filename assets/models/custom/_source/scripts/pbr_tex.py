"""Texture PBR procedurali (solo Pillow, niente numpy) per i modelli del campo.

Ogni generatore scrive in _source/textures/pbr/ :  <nome>_c.jpg (colore), <nome>_r.png (roughness, grigio),
<nome>_n.png (normal OpenGL), e per foglie/fiamme <nome>_c.png con alpha (+ <nome>_e.png emissiva).
Le texture sono ripetibili (tileable) tranne quelle a scheda (foglie, fiamma).
Palette: terrosa e smorzata (Età del bronzo, STYLE.md sez. 5): sabbia, ocra, oliva, legno consumato, bronzo opaco.
"""
import math, os, random
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "textures", "pbr"))
SIZE = 1024


# ------------------------------------------------------------------ rumore
def noise(size, cx, cy, seed):
    """Rumore a valori, ripetibile, con cx x cy celle (celle diverse = venature allungate)."""
    rnd = random.Random(seed)
    base = Image.new("L", (cx, cy))
    base.putdata([rnd.randrange(256) for _ in range(cx * cy)])
    big = Image.new("L", (cx * 3, cy * 3))
    for i in range(3):
        for j in range(3):
            big.paste(base, (i * cx, j * cy))
    big = big.resize((size * 3, size * 3), Image.BICUBIC)
    return big.crop((size, size, size * 2, size * 2))


def fbm(size, seed, cells=4, octaves=5, stretch=(1, 1), gain=0.5):
    res = noise(size, cells * stretch[0], cells * stretch[1], seed)
    w = 1.0
    for k in range(1, octaves):
        c = cells * (2 ** k)
        w *= gain
        res = Image.blend(res, noise(size, c * stretch[0], c * stretch[1], seed + 17 * k), min(0.5, w))
    return ImageOps.autocontrast(res, cutoff=1)


def ridged(g):
    """Linee scure dove il rumore attraversa il valore medio (crepe, venature)."""
    return g.point(lambda v: int(255 - abs(v - 128) * 2.2) if abs(v - 128) < 116 else 0)


def mulrgb(base_rgb, gray, lo=0.55, hi=1.05):
    """Moltiplica un colore per un modulatore grigio mappato in [lo, hi]."""
    m = gray.point(lambda v: int(255 * (lo + (hi - lo) * v / 255)))
    return ImageChops.multiply(Image.new("RGB", gray.size, base_rgb), m.convert("RGB"))


def colorize(gray, dark, mid, light):
    return ImageOps.colorize(gray, dark, light, mid=mid)


def normal_from_height(h, strength=2.0):
    """Normal map OpenGL (Y su) dalla mappa di altezza (L)."""
    gx = h.filter(ImageFilter.Kernel((3, 3), [-1, 0, 1, -2, 0, 2, -1, 0, 1], 1, 128))
    gy = h.filter(ImageFilter.Kernel((3, 3), [-1, -2, -1, 0, 0, 0, 1, 2, 1], 1, 128))
    r = gx.point(lambda v: max(0, min(255, int(128 - (v - 128) * strength))))
    g = gy.point(lambda v: max(0, min(255, int(128 + (v - 128) * strength))))
    b = Image.new("L", h.size, 255)
    return Image.merge("RGB", (r, g, b))


def save_set(name, color, rough, normal):
    os.makedirs(OUT, exist_ok=True)
    color.convert("RGB").save(f"{OUT}/{name}_c.jpg", "JPEG", quality=92, subsampling=0, optimize=True)
    rough.convert("L").save(f"{OUT}/{name}_r.png", optimize=True)
    normal.convert("RGB").save(f"{OUT}/{name}_n.png", optimize=True)


def rough_map(size, seed, lo, hi):
    g = fbm(size, seed, cells=6, octaves=3)
    return g.point(lambda v: int(255 * (lo + (hi - lo) * v / 255)))


# ------------------------------------------------------------------ materiali
def canvas(size=SIZE, seed=1, tint=(186, 168, 132)):
    """Tela grezza di lino consumata, con macchie di fumo e sporco."""
    tile = Image.new("L", (16, 16), 0)
    d = ImageDraw.Draw(tile)
    for i in range(0, 16, 4):
        d.rectangle([i, 0, i + 2, 15], fill=170)       # ordito
    for j in range(0, 16, 4):
        d.rectangle([0, j + 2, 15, j + 3], fill=230)    # trama
    weave = Image.new("L", (size, size))
    for x in range(0, size, 16):
        for y in range(0, size, 16):
            weave.paste(tile, (x, y))
    weave = ImageChops.add(weave, noise(size, 256, 256, seed + 5).point(lambda v: v // 6))
    dirt = fbm(size, seed, cells=3, octaves=5)
    stains = fbm(size, seed + 40, cells=5, octaves=4).point(lambda v: 255 if v > 140 else int(110 + v * 1.0))
    mod = ImageChops.multiply(dirt, stains)
    col = mulrgb(tint, ImageChops.blend(mod, weave, 0.4), 0.62, 1.06)
    height = ImageChops.add(weave, dirt.point(lambda v: v // 3))
    save_set("canvas", col, rough_map(size, seed + 2, 0.82, 0.95), normal_from_height(height, 2.2))


def hide(size=SIZE, seed=2):
    """Pelle di animale: chiazze marrone, fulvo e crema con bordi scuri, pelo fine."""
    g = fbm(size, seed, cells=3, octaves=6)
    col = colorize(g, (62, 42, 28), (118, 84, 54), (176, 142, 100))
    patch = fbm(size, seed + 9, cells=2, octaves=3).point(lambda v: 255 if v > 175 else 0).filter(ImageFilter.GaussianBlur(9))
    pale = Image.new("RGB", (size, size), (196, 172, 134))
    col = Image.composite(pale, col, patch.point(lambda v: v // 2))
    fur = noise(size, 400, 400, seed + 3)
    col = ImageChops.multiply(col, fur.point(lambda v: 205 + v // 6).convert("RGB"))
    save_set("hide", col, rough_map(size, seed + 4, 0.8, 0.95), normal_from_height(ImageChops.blend(fur, g, 0.35), 1.6))


def bark(size=SIZE, seed=3):
    """Corteccia/tronco scortecciato, venature verticali e crepe."""
    g = fbm(size, seed, cells=4, octaves=5, stretch=(4, 1))
    r = ridged(fbm(size, seed + 8, cells=3, octaves=4, stretch=(5, 1)))
    col = colorize(g, (44, 34, 26), (92, 74, 55), (146, 122, 92))
    col = ImageChops.multiply(col, r.point(lambda v: 150 + v * 105 // 255).convert("RGB"))
    height = ImageChops.add(g, r, scale=1.5)
    save_set("bark", col, rough_map(size, seed + 1, 0.8, 0.95), normal_from_height(height, 3.2))


def planks(size=SIZE, seed=4):
    """Assi di legno consumato, giunture orizzontali ogni 256 px."""
    g = fbm(size, seed, cells=2, octaves=5, stretch=(1, 14))
    seams = Image.new("L", (size, size), 255)
    d = ImageDraw.Draw(seams)
    tint = Image.new("L", (size, size), 255)
    dt = ImageDraw.Draw(tint)
    rnd = random.Random(seed)
    for k in range(0, size, 256):
        d.rectangle([0, k, size, k + 4], fill=40)
        dt.rectangle([0, k, size, k + 255], fill=rnd.randrange(185, 255))
    col = colorize(g, (80, 60, 42), (124, 96, 68), (172, 140, 104))
    col = ImageChops.multiply(col, tint.convert("RGB"))
    col = ImageChops.multiply(col, seams.point(lambda v: 90 + v * 165 // 255).convert("RGB"))
    height = ImageChops.multiply(g, seams.point(lambda v: 120 + v // 2))
    save_set("planks", col, rough_map(size, seed + 1, 0.7, 0.9), normal_from_height(height, 2.4))


def stone(size=SIZE, seed=5):
    """Pietra calcarea ocra/grigia scheggiata."""
    g = fbm(size, seed, cells=3, octaves=6)
    r = ridged(fbm(size, seed + 4, cells=4, octaves=4))
    col = colorize(g, (96, 88, 76), (152, 142, 124), (200, 190, 168))
    col = ImageChops.multiply(col, r.point(lambda v: 170 + v * 85 // 255).convert("RGB"))
    save_set("stone", col, rough_map(size, seed + 1, 0.82, 0.97), normal_from_height(ImageChops.add(g, r, scale=2), 2.6))


def bronze(size=512, seed=6):
    """Bronzo opaco con patina verde e graffi."""
    g = fbm(size, seed, cells=4, octaves=5)
    col = colorize(g, (88, 62, 34), (132, 96, 50), (170, 128, 70))
    patina = fbm(size, seed + 3, cells=3, octaves=4).point(lambda v: 255 if v > 190 else 0).filter(ImageFilter.GaussianBlur(5))
    col = Image.composite(Image.new("RGB", (size, size), (70, 100, 78)), col, patina.point(lambda v: v * 6 // 10))
    sc = Image.new("L", (size, size), 128)
    d = ImageDraw.Draw(sc)
    rnd = random.Random(seed)
    for _ in range(240):
        x, y = rnd.randrange(size), rnd.randrange(size)
        a = rnd.random() * math.pi
        d.line([x, y, x + math.cos(a) * 40, y + math.sin(a) * 40], fill=rnd.choice((90, 175)), width=1)
    save_set("bronze", col, rough_map(size, seed + 1, 0.38, 0.62), normal_from_height(ImageChops.blend(g, sc, 0.4), 1.4))


def clay(size=SIZE, seed=7):
    """Argilla cotta con bande dipinte scure e linea ondulata (pithoi), u = giro, v = altezza."""
    g = fbm(size, seed, cells=3, octaves=5)
    col = colorize(g, (150, 88, 56), (180, 108, 68), (206, 136, 92))
    d = ImageDraw.Draw(col)
    dark = (62, 38, 26)
    for y0, h in ((70, 26), (170, 10), (180, 10), (520, 22), (860, 14), (876, 14)):
        d.rectangle([0, y0, size, y0 + h], fill=dark)
    pts = [(x, 330 + 28 * math.sin(x / size * 2 * math.pi * 6)) for x in range(0, size + 1, 8)]
    d.line(pts, fill=dark, width=14)
    for x in range(8, size, 64):                     # fila di punti
        d.ellipse([x, 650, x + 18, 668], fill=dark)
    col = ImageChops.multiply(col, fbm(size, seed + 5, cells=8, octaves=4).point(lambda v: 190 + v // 4).convert("RGB"))
    save_set("clay", col, rough_map(size, seed + 1, 0.7, 0.9), normal_from_height(g, 1.3))


def rope(size=256, seed=8):
    d_img = Image.new("L", (size, size), 120)
    d = ImageDraw.Draw(d_img)
    for k in range(-size, size * 2, 22):
        d.line([k, 0, k + size // 2, size], fill=230, width=9)
    col = colorize(d_img, (88, 66, 40), (130, 102, 66), (170, 140, 96))
    save_set("rope", col, rough_map(size, seed, 0.9, 0.98), normal_from_height(d_img, 2.5))


def charcoal(size=512, seed=9):
    """Tizzoni carbonizzati con braci arancio (colore + emissiva)."""
    g = fbm(size, seed, cells=5, octaves=5)
    r = ridged(fbm(size, seed + 2, cells=6, octaves=3))
    col = colorize(g, (16, 14, 13), (36, 30, 27), (70, 58, 50))
    em = Image.new("RGB", (size, size), (0, 0, 0))
    d = ImageDraw.Draw(em)
    rnd = random.Random(seed)
    glow = r.point(lambda v: 255 if v > 238 else 0).filter(ImageFilter.GaussianBlur(2)).point(lambda v: v * 6 // 10)
    em = Image.merge("RGB", (glow, glow.point(lambda v: v * 4 // 10), glow.point(lambda v: v // 14)))
    col = ImageChops.add(col, em, scale=3)
    save_set("charcoal", col, rough_map(size, seed + 1, 0.85, 1.0), normal_from_height(ImageChops.add(g, r, scale=2), 2.5))
    em.save(f"{OUT}/charcoal_e.png", optimize=True)


def _leaf_poly(cx, cy, length, width, ang, steps=10):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        w = math.sin(math.pi * t) ** 0.8 * width / 2
        pts.append((t * length, w))
    pts += [(t * length, -w) for (t, w) in [(p[0] / length, p[1]) for p in reversed(pts)]]
    ca, sa = math.cos(ang), math.sin(ang)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]


def leaves(size=512, seed=10):
    """Scheda di ramo frondoso (RGBA): stelo con foglie di quercia/olivo in verdi oliva smorzati."""
    S = size * 2
    img = Image.new("RGBA", (S, S), (80, 92, 48, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    greens = [(78, 92, 48), (92, 104, 56), (64, 80, 42), (104, 112, 62), (86, 78, 44)]
    stem = (74, 56, 38)
    d.line([S * 0.5, S, S * 0.52, S * 0.05], fill=stem + (255,), width=14)
    for k in range(26):
        t = 0.08 + 0.9 * k / 26
        y = S * (1 - t)
        side = -1 if k % 2 else 1
        ang = -math.pi / 2 + side * rnd.uniform(0.55, 1.15)
        length = S * rnd.uniform(0.17, 0.26) * (1.1 - 0.5 * t)
        x0 = S * (0.5 + 0.02 * t)
        d.line([x0, y, x0 + math.cos(ang) * length * 0.12, y + math.sin(ang) * length * 0.12], fill=stem + (255,), width=6)
        poly = _leaf_poly(x0, y, length, length * 0.42, ang)
        c = rnd.choice(greens)
        d.polygon(poly, fill=c + (255,))
        d.line([poly[0], poly[len(poly) // 2]], fill=tuple(min(255, v + 40) for v in c) + (255,), width=2)
    # foglia terminale
    d.polygon(_leaf_poly(S * 0.52, S * 0.09, S * 0.12, S * 0.05, -math.pi / 2), fill=greens[1] + (255,))
    img = img.resize((size, size), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    img.save(f"{OUT}/leaves_c.png", optimize=True)
    Image.new("L", (size, size), 190).save(f"{OUT}/leaves_r.png")
    Image.new("RGB", (size, size), (128, 128, 255)).save(f"{OUT}/leaves_n.png")


def flame(size=512, seed=11):
    """Tre lingue di fiamma (RGBA, emissiva): rosso-arancio ai bordi, giallo al centro."""
    S = size * 2
    layers = [((255, 90, 20), 1.0, 0), ((255, 150, 40), 0.78, 1), ((255, 215, 90), 0.52, 2), ((255, 248, 200), 0.28, 3)]
    img = Image.new("RGBA", (S, S), (255, 110, 25, 0))
    rnd = random.Random(seed)
    tongues = [(S * 0.5, 0.94, 0.30), (S * 0.27, 0.62, 0.22), (S * 0.74, 0.7, 0.24)]
    for col, k, _ in layers:
        layer = Image.new("RGBA", (S, S), col + (0,))
        d = ImageDraw.Draw(layer)
        for cx, h, w in tongues:
            top = S * (1 - h * k) if k == 1.0 else S * (1 - h * (0.45 + 0.55 * k))
            base_w = S * w * (0.35 + 0.65 * k)
            right, left = [], []
            for i in range(0, 21):
                t = i / 20
                y = S * 0.98 - t * (S * 0.98 - top)
                wid = base_w * math.sin(math.pi * (0.12 + 0.88 * t) ** 0.9) * (1 - t) ** 0.35
                sway = math.sin(t * 4 + cx) * S * 0.02
                right.append((cx + sway + wid, y))
                left.append((cx + sway - wid, y))
            pts = right + list(reversed(left))
            d.polygon(pts, fill=col + (255,))
        layer = layer.filter(ImageFilter.GaussianBlur(16 + 12 * k))
        img = Image.alpha_composite(img, layer)
    img = img.resize((size, size), Image.LANCZOS)
    img.save(f"{OUT}/flame_c.png", optimize=True)
    Image.new("L", (size, size), 255).save(f"{OUT}/flame_r.png")
    Image.new("RGB", (size, size), (128, 128, 255)).save(f"{OUT}/flame_n.png")
    img.convert("RGB").save(f"{OUT}/flame_e.png", optimize=True)

def limestone(size=SIZE, seed=12):
    """Calcare ocra: toni sabbia, pori scuri e crepe leggere."""
    g = fbm(size, seed, cells=2, octaves=7, gain=0.62)
    r = ridged(fbm(size, seed + 5, cells=5, octaves=3))
    col = colorize(g, (158, 140, 112), (194, 174, 138), (222, 206, 174))
    pores = noise(size, 220, 220, seed + 3).point(lambda v: 150 if v > 232 else 255)
    col = ImageChops.multiply(col, pores.convert("RGB"))
    col = ImageChops.multiply(col, r.point(lambda v: 205 + v * 50 // 255).convert("RGB"))
    save_set("limestone", col, rough_map(size, seed + 1, 0.86, 0.97), normal_from_height(ImageChops.add(g, r, scale=2), 2.0))


def iron(size=512, seed=13):
    """Ferro scuro battuto con ruggine a chiazze."""
    g = fbm(size, seed, cells=4, octaves=5)
    col = colorize(g, (36, 33, 32), (58, 52, 50), (84, 76, 72))
    rust = fbm(size, seed + 4, cells=3, octaves=4).point(lambda v: 255 if v > 175 else 0).filter(ImageFilter.GaussianBlur(6))
    col = Image.composite(Image.new("RGB", (size, size), (112, 66, 40)), col, rust.point(lambda v: v * 6 // 10))
    save_set("iron", col, rough_map(size, seed + 1, 0.5, 0.8), normal_from_height(g, 1.6))


def tile(size=SIZE, seed=14):
    """Tegole di terracotta curve, a file sovrapposte (u = larghezza, v = discesa)."""
    rnd = random.Random(seed)
    W, Hrow = 128, 170
    px = []
    cols_n = size // W
    rows_n = size // Hrow + 2
    shade = {(c, r): rnd.uniform(0.82, 1.08) for c in range(cols_n + 1) for r in range(rows_n + 1)}
    hdat, cdat = [], []
    for y in range(size):
        r_i, fy = divmod(y, Hrow)
        for x in range(size):
            c_i, fx = divmod(x, W)
            rib = 0.5 + 0.5 * math.cos((fx / W - 0.5) * math.pi * 2 * 0.5 * 2)   # sezione curva
            lap = 0.62 + 0.38 * (fy / Hrow)                                       # bordo sporgente in fondo
            h = rib * lap
            if fx < 3 or fx > W - 4:
                h *= 0.5
            hdat.append(int(255 * min(1, h)))
            cdat.append(h * shade[(c_i, r_i)])
    height = Image.new("L", (size, size)); height.putdata(hdat)
    cm = Image.new("L", (size, size)); cm.putdata([int(255 * min(1, c)) for c in cdat])
    g = fbm(size, seed, cells=4, octaves=5)
    col = colorize(cm, (96, 46, 30), (168, 92, 60), (206, 130, 88))
    col = ImageChops.multiply(col, mulrgb((255, 255, 255), g, 0.7, 1.05))
    moss = fbm(size, seed + 6, cells=4, octaves=4).point(lambda v: 255 if v > 200 else 0).filter(ImageFilter.GaussianBlur(7))
    col = Image.composite(Image.new("RGB", (size, size), (84, 96, 56)), col, moss.point(lambda v: v * 4 // 10))
    save_set("tile", col, rough_map(size, seed + 1, 0.72, 0.9), normal_from_height(height, 3.0))

def coat(name, base, dark, light, size=SIZE, seed=15, sheen=(0.5, 0.66)):
    """Mantello di cavallo: pelo corto, chiazze larghe appena visibili, lucentezza."""
    g = fbm(size, seed, cells=3, octaves=5)
    fur = noise(size, 320, 320, seed + 2)
    col = colorize(g, dark, base, light)
    col = ImageChops.multiply(col, fur.point(lambda v: 215 + v // 7).convert("RGB"))
    save_set(name, col, rough_map(size, seed + 1, *sheen), normal_from_height(fur, 0.6))


def hoof(size=256, seed=16):
    g = fbm(size, seed, cells=4, octaves=4, stretch=(3, 1))
    col = colorize(g, (34, 28, 26), (58, 48, 42), (88, 74, 64))
    save_set("hoof", col, rough_map(size, seed + 1, 0.4, 0.6), normal_from_height(g, 1.5))


def mane(name, color, size=512, seed=17):
    """Scheda di crini (RGBA): ciocche sottili, lievemente ondulate, che si assottigliano in basso."""
    S = size * 2
    img = Image.new("RGBA", (S, S), color + (0,))
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    for _ in range(620):
        x = rnd.uniform(0.02, 0.98) * S
        amp, ph, fr = rnd.uniform(6, 26), rnd.uniform(0, 6.28), rnd.uniform(2, 5)
        k = rnd.uniform(0.7, 1.25)      # un solo fattore per tutti i canali: niente striature colorate
        c = tuple(max(0, min(255, int(v * k))) for v in color) + (255,)
        top = rnd.uniform(0, 0.12) * S
        bot = rnd.uniform(0.7, 1.0) * S
        pts = [(x + amp * math.sin(ph + fr * t), top + (bot - top) * t) for t in [i / 30 for i in range(31)]]
        w = rnd.randint(8, 15)
        d.line(pts, fill=c, width=w)
    img = img.filter(ImageFilter.GaussianBlur(1.2)).resize((size, size), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    img.save(f"{OUT}/{name}_c.png", optimize=True)
    Image.new("L", (size, size), 150).save(f"{OUT}/{name}_r.png")
    Image.new("RGB", (size, size), (128, 128, 255)).save(f"{OUT}/{name}_n.png")


def horse_set():
    coat("horse_bay", (112, 68, 42), (78, 46, 30), (140, 92, 60))
    coat("horse_dark", (44, 34, 30), (28, 22, 20), (62, 48, 42), seed=18)
    coat("horse_grey", (176, 172, 164), (132, 128, 122), (212, 208, 200), seed=19)
    hoof()
    mane("mane_dark", (30, 22, 18))
    mane("mane_light", (186, 180, 168), seed=21)

def hoplon(name, kind, size=SIZE, seed=30):
    """Faccia di scudo hoplon, mappatura piana dall'alto: bronzo consumato con campo dipinto e simbolo.
    kind = 'tridente' (campo rosso scuro, tridente dorato) o 'chevron' (bronzo con chevron neri a file)."""
    g = fbm(size, seed, cells=4, octaves=6)
    img = colorize(g, (92, 66, 36), (140, 102, 56), (178, 136, 78))
    d = ImageDraw.Draw(img)
    c = size // 2
    R = size // 2
    rim = int(R * 0.88)
    if kind == "tridente":
        d.ellipse([c - rim, c - rim, c + rim, c + rim], fill=(104, 40, 32))
        gold = (192, 152, 82)
        d.rectangle([c - 22, c - int(R * 0.55), c + 22, c + int(R * 0.62)], fill=gold)                 # asta
        for ox, h in ((-int(R * 0.26), 0.46), (int(R * 0.26), 0.46), (0, 0.66)):                          # tre denti
            top = c - int(R * h)
            d.rectangle([c + ox - 14, top, c + ox + 14, c - int(R * 0.18)], fill=gold)
            d.polygon([(c + ox - 34, top + 40), (c + ox, top - 56), (c + ox + 34, top + 40)], fill=gold)  # punta
            d.polygon([(c + ox - 30, top + 30), (c + ox - 52, top + 70), (c + ox - 14, top + 66)], fill=gold)   # barbe
            d.polygon([(c + ox + 30, top + 30), (c + ox + 52, top + 70), (c + ox + 14, top + 66)], fill=gold)
        d.arc([c - int(R * 0.3), c - int(R * 0.4), c + int(R * 0.3), c + int(R * 0.1)], 0, 180, fill=gold, width=26)   # traversa
        d.rectangle([c - 70, c + int(R * 0.6), c + 70, c + int(R * 0.64)], fill=gold)
    else:
        d.ellipse([c - rim, c - rim, c + rim, c + rim], fill=(150, 112, 62))
        black = (34, 28, 26)
        for k in range(5):                                                                              # chevron concentrici verso l'alto
            y = c - int(R * 0.52) + k * int(R * 0.27)
            hw = int(R * (0.62 - 0.05 * abs(k - 2)))
            pts = [(c - hw, y + 70), (c, y - 20), (c + hw, y + 70), (c + hw, y + 112), (c, y + 22), (c - hw, y + 112)]
            d.polygon(pts, fill=black)
        d.ellipse([c - 70, c - 70, c + 70, c + 70], fill=(172, 130, 72))
        d.ellipse([c - 70, c - 70, c + 70, c + 70], outline=black, width=14)
    d.ellipse([c - rim - 10, c - rim - 10, c + rim + 10, c + rim + 10], outline=(70, 50, 28), width=12)   # filo del bordo
    rnd = random.Random(seed)
    for _ in range(900):                                                                               # scrostature: bronzo che affiora
        x, y = rnd.randrange(size), rnd.randrange(size)
        r = rnd.choice((2, 3, 5, 8))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(136, 100, 56))
    wear = fbm(size, seed + 4, cells=6, octaves=5)
    img = ImageChops.multiply(img, wear.point(lambda v: 170 + v * 85 // 255).convert("RGB"))
    save_set(name, img, rough_map(size, seed + 1, 0.42, 0.7), normal_from_height(ImageChops.blend(g, wear, 0.4), 1.5))


def hoplon_set():
    hoplon("hoplon_tridente", "tridente")
    hoplon("hoplon_chevron", "chevron", seed=31)

def hull_dark(size=SIZE, seed=40):
    """Fasciame scuro catramato: assi orizzontali con giunture e venature, macchie di salsedine."""
    g = fbm(size, seed, cells=2, octaves=5, stretch=(1, 16))
    tint = Image.new("L", (size, size), 255)
    seams = Image.new("L", (size, size), 255)
    d, dt = ImageDraw.Draw(seams), ImageDraw.Draw(tint)
    rnd = random.Random(seed)
    for k in range(0, size, 128):
        d.rectangle([0, k, size, k + 3], fill=20)
        dt.rectangle([0, k, size, k + 127], fill=rnd.randrange(190, 255))
    col = colorize(g, (30, 24, 20), (58, 46, 38), (96, 78, 62))
    col = ImageChops.multiply(col, tint.convert("RGB"))
    col = ImageChops.multiply(col, seams.point(lambda v: 60 + v * 195 // 255).convert("RGB"))
    salt = fbm(size, seed + 3, cells=3, octaves=4).point(lambda v: 255 if v > 205 else 0).filter(ImageFilter.GaussianBlur(10))
    col = Image.composite(Image.new("RGB", (size, size), (140, 134, 120)), col, salt.point(lambda v: v * 3 // 10))
    save_set("hull_dark", col, rough_map(size, seed + 1, 0.55, 0.85), normal_from_height(ImageChops.multiply(g, seams.point(lambda v: 110 + v // 2)), 2.2))


def hull_band(size=SIZE, seed=41):
    """Fascia dipinta di ocra rossa consumata, con il legno scuro che affiora."""
    g = fbm(size, seed, cells=3, octaves=6, stretch=(1, 8))
    col = colorize(g, (78, 38, 28), (122, 68, 44), (160, 106, 68))
    wear = fbm(size, seed + 5, cells=5, octaves=5).point(lambda v: 255 if v > 190 else 0).filter(ImageFilter.GaussianBlur(3))
    col = Image.composite(Image.new("RGB", (size, size), (44, 34, 28)), col, wear.point(lambda v: v * 7 // 10))
    save_set("hull_band", col, rough_map(size, seed + 1, 0.6, 0.9), normal_from_height(g, 1.8))


def sail(size=SIZE, seed=42):
    """Vela quadra di lino grezzo: teli cuciti (giunture orizzontali ogni 128 px), toppe e macchie di salsedine."""
    g = fbm(size, seed, cells=3, octaves=5)
    weave = noise(size, 300, 300, seed + 2).point(lambda v: 205 + v // 5)
    tint = Image.new("L", (size, size), 255)
    seams = Image.new("L", (size, size), 255)
    d, dt = ImageDraw.Draw(seams), ImageDraw.Draw(tint)
    rnd = random.Random(seed)
    for k in range(0, size, 128):
        dt.rectangle([0, k, size, k + 127], fill=rnd.randrange(215, 255))
        d.rectangle([0, k, size, k + 2], fill=70)
        d.rectangle([0, k + 6, size, k + 7], fill=150)       # doppia cucitura
    col = colorize(g, (176, 156, 120), (212, 194, 156), (232, 218, 184))
    col = ImageChops.multiply(col, tint.convert("RGB"))
    col = ImageChops.multiply(col, seams.point(lambda v: 150 + v * 105 // 255).convert("RGB"))
    col = ImageChops.multiply(col, weave.convert("RGB"))
    dc = ImageDraw.Draw(col)
    for _ in range(5):                                          # toppe piu' scure
        x, y = rnd.randrange(60, size - 200), rnd.randrange(60, size - 200)
        w, h = rnd.randrange(80, 170), rnd.randrange(80, 150)
        dc.rectangle([x, y, x + w, y + h], fill=(150 + rnd.randrange(-14, 14), 128, 96), outline=(110, 92, 66))
    save_set("sail", col, rough_map(size, seed + 1, 0.82, 0.95), normal_from_height(ImageChops.blend(weave, seams, 0.4), 1.8))


def eye(size=512, seed=43):
    """Occhio apotropaico dipinto sulla prua (RGBA): sclera crema, iride scura, contorno nero spesso, sopracciglio."""
    S = size * 2
    img = Image.new("RGBA", (S, S), (40, 30, 24, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S // 2, S // 2
    w, h = int(S * 0.46), int(S * 0.22)
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((cx - w + 2 * w * t, cy - h * math.sin(math.pi * t) ** 0.9))
    low = [(cx - w + 2 * w * (1 - i / 40), cy + h * 0.8 * math.sin(math.pi * (1 - i / 40)) ** 0.9) for i in range(41)]
    shape = pts + low
    d.polygon(shape, fill=(226, 214, 184, 255), outline=(20, 16, 14, 255))
    d.line(shape + [shape[0]], fill=(20, 16, 14, 255), width=26)
    r = int(h * 0.9)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(46, 62, 74, 255), outline=(20, 16, 14, 255), width=14)
    r2 = int(r * 0.48)
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(14, 12, 12, 255))
    d.line([(cx - w - 40, cy - h - 60), (cx - w * 0.2, cy - h - 150), (cx + w * 0.7, cy - h - 80)], fill=(20, 16, 14, 255), width=34)
    img = img.resize((size, size), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    img.save(f"{OUT}/eye_c.png", optimize=True)
    Image.new("L", (size, size), 170).save(f"{OUT}/eye_r.png")
    Image.new("RGB", (size, size), (128, 128, 255)).save(f"{OUT}/eye_n.png")


def navi_set():
    hull_dark(); hull_band(); sail(); eye()

def earth(size=SIZE, seed=50):
    """Terra secca ocra con zolle, sassolini e fili d'erba paglierini (colle dell'acropoli, terreno)."""
    g = fbm(size, seed, cells=3, octaves=6)
    col = colorize(g, (108, 84, 56), (156, 126, 86), (196, 168, 122))
    rnd = random.Random(seed)
    d = ImageDraw.Draw(col)
    for _ in range(1400):                                      # sassolini chiari e scuri
        x, y = rnd.randrange(size), rnd.randrange(size)
        r = rnd.choice((2, 3, 4, 6))
        c = rnd.choice(((196, 180, 152), (134, 114, 88), (168, 150, 120), (92, 76, 58)))
        d.ellipse([x - r, y - r // 2 - 1, x + r, y + r // 2 + 1], fill=c)
    for _ in range(1500):                                      # fili d'erba secca
        x, y = rnd.randrange(size), rnd.randrange(size)
        a = rnd.uniform(-1.2, 1.2) - math.pi / 2
        L = rnd.randrange(10, 26)
        d.line([x, y, x + math.cos(a) * L, y + math.sin(a) * L], fill=rnd.choice(((176, 158, 104), (150, 140, 90), (120, 112, 70))), width=1)
    col = ImageChops.multiply(col, fbm(size, seed + 4, cells=6, octaves=4).point(lambda v: 200 + v // 5).convert("RGB"))
    h = ImageChops.blend(g, noise(size, 180, 180, seed + 2), 0.35)
    save_set("earth", col, rough_map(size, seed + 1, 0.9, 1.0), normal_from_height(h, 2.0))


def ash(size=512, seed=51):
    """Carbone spento e cenere, senza emissiva (bracieri spenti)."""
    g = fbm(size, seed, cells=5, octaves=5)
    col = colorize(g, (26, 24, 23), (58, 54, 51), (118, 112, 104))
    pale = fbm(size, seed + 3, cells=4, octaves=4).point(lambda v: 255 if v > 190 else 0).filter(ImageFilter.GaussianBlur(5))
    col = Image.composite(Image.new("RGB", (size, size), (150, 146, 138)), col, pale.point(lambda v: v * 4 // 10))
    save_set("ash", col, rough_map(size, seed + 1, 0.88, 1.0), normal_from_height(g, 2.2))


def terra_set():
    earth(); ash()

def leather(size=512, seed=60):
    """Cuoio scuro consumato, con pieghe e usura."""
    g = fbm(size, seed, cells=3, octaves=5)
    r = ridged(fbm(size, seed + 3, cells=7, octaves=3))
    col = colorize(g, (44, 28, 18), (84, 56, 36), (126, 88, 58))
    col = ImageChops.multiply(col, r.point(lambda v: 200 + v * 55 // 255).convert("RGB"))
    save_set("leather", col, rough_map(size, seed + 1, 0.5, 0.78), normal_from_height(ImageChops.add(g, r, scale=2), 1.6))

def skin(size=512, seed=61):
    g = fbm(size, seed, cells=3, octaves=5)
    col = colorize(g, (134, 92, 66), (172, 124, 90), (204, 156, 118))
    save_set("skin", col, rough_map(size, seed + 1, 0.55, 0.75), normal_from_height(noise(size, 220, 220, seed + 2), 0.7))


def wool(size=512, seed=62):
    """Lana tessuta di tunica: rosso/ocra smorzato con trama visibile."""
    tile = Image.new("L", (12, 12), 0)
    d = ImageDraw.Draw(tile)
    for i in range(0, 12, 3):
        d.rectangle([i, 0, i + 1, 11], fill=170)
    for j in range(0, 12, 3):
        d.rectangle([0, j + 1, 11, j + 2], fill=235)
    weave = Image.new("L", (size, size))
    for x in range(0, size, 12):
        for y in range(0, size, 12):
            weave.paste(tile, (x, y))
    g = fbm(size, seed, cells=3, octaves=5)
    col = colorize(g, (92, 52, 38), (130, 80, 56), (168, 116, 82))
    col = ImageChops.multiply(col, weave.point(lambda v: 170 + v // 3).convert("RGB"))
    save_set("wool", col, rough_map(size, seed + 1, 0.85, 0.98), normal_from_height(ImageChops.blend(weave, g, 0.3), 1.6))

def cloak(name, dark, mid, light, size=512, seed=70):
    """Lana tinta e consumata per mantelli e scudi dipinti (a 512 px: per masse lontane)."""
    tile = Image.new("L", (8, 8), 0)
    d = ImageDraw.Draw(tile)
    for i in range(0, 8, 2):
        d.rectangle([i, 0, i, 7], fill=180)
    weave = Image.new("L", (size, size))
    for x in range(0, size, 8):
        for y in range(0, size, 8):
            weave.paste(tile, (x, y))
    g = fbm(size, seed, cells=3, octaves=5)
    col = colorize(g, dark, mid, light)
    col = ImageChops.multiply(col, weave.point(lambda v: 190 + v // 4).convert("RGB"))
    save_set(name, col, rough_map(size, seed + 1, 0.85, 0.98), normal_from_height(ImageChops.blend(weave, g, 0.3), 1.3))


def cloaks():
    cloak("cloak_red", (74, 30, 26), (118, 52, 42), (156, 84, 66), seed=71)
    cloak("cloak_blue", (34, 46, 66), (56, 76, 104), (88, 112, 142), seed=72)
    cloak("cloak_brown", (66, 48, 32), (104, 78, 52), (144, 112, 80), seed=73)


def wood_ash(size=512, seed=90):
    """Frassino per l'asta della lancia: fibre lunghe, anelli chiari, lucidata dall'uso (v = lungo l'asta)."""
    g = fbm(size, seed, cells=3, octaves=5, stretch=(6, 1))
    r = ridged(fbm(size, seed + 8, cells=2, octaves=4, stretch=(9, 1)))
    col = colorize(g, (118, 86, 54), (166, 128, 86), (206, 170, 120))
    col = ImageChops.multiply(col, r.point(lambda v: 190 + v * 65 // 255).convert("RGB"))
    save_set("wood_ash", col, rough_map(size, seed + 1, 0.45, 0.7), normal_from_height(ImageChops.add(g, r, scale=2), 1.8))


def wood_bow(size=512, seed=91):
    """Legno scuro laccato con tendine per l'arco: venature fini e riflesso setoso."""
    g = fbm(size, seed, cells=3, octaves=5, stretch=(8, 1))
    r = ridged(fbm(size, seed + 8, cells=2, octaves=4, stretch=(10, 1)))
    col = colorize(g, (52, 32, 20), (90, 58, 36), (132, 92, 58))
    col = ImageChops.multiply(col, r.point(lambda v: 200 + v * 55 // 255).convert("RGB"))
    save_set("wood_bow", col, rough_map(size, seed + 1, 0.32, 0.55), normal_from_height(ImageChops.add(g, r, scale=2), 1.4))


def bronze_blade(size=512, seed=92):
    """Bronzo di lama: lucido, con affilatura, graffi e un velo di patina verde ai bordi."""
    g = fbm(size, seed, cells=3, octaves=5, stretch=(1, 4))
    col = colorize(g, (96, 74, 42), (146, 114, 64), (188, 154, 98))
    sc = Image.new("L", (size, size), 128)
    d = ImageDraw.Draw(sc)
    rnd = random.Random(seed)
    for _ in range(320):
        x, y = rnd.randrange(size), rnd.randrange(size)
        a = math.pi / 2 + rnd.uniform(-0.25, 0.25)
        d.line([x, y, x + math.cos(a) * rnd.randrange(30, 140), y + math.sin(a) * rnd.randrange(30, 140)], fill=rnd.choice((70, 190)), width=1)
    patina = fbm(size, seed + 3, cells=4, octaves=4).point(lambda v: 255 if v > 205 else 0).filter(ImageFilter.GaussianBlur(7))
    col = Image.composite(Image.new("RGB", (size, size), (74, 104, 80)), col, patina.point(lambda v: v * 5 // 10))
    save_set("bronze_blade", col, rough_map(size, seed + 1, 0.22, 0.48), normal_from_height(ImageChops.blend(g, sc, 0.5), 1.2))


def cord(size=256, seed=93):
    """Corda di lino ritorto per la corda dell'arco (u = giro, v = lungo la corda)."""
    d_img = Image.new("L", (size, size), 120)
    d = ImageDraw.Draw(d_img)
    for k in range(-size, size * 2, 32):
        d.line([k, 0, k + size // 4, size], fill=230, width=12)
    col = colorize(d_img, (150, 128, 96), (190, 168, 128), (222, 204, 164))
    save_set("cord", col, rough_map(size, seed, 0.85, 0.97), normal_from_height(d_img, 2.2))


def armi_set():
    wood_ash(); wood_bow(); bronze_blade(); cord()


ALL = [canvas, hide, bark, planks, stone, bronze, clay, rope, charcoal, leaves, flame, limestone, iron, tile, horse_set, hoplon_set, navi_set, terra_set, leather, skin, wool, cloaks, armi_set]

if __name__ == "__main__":
    import sys
    names = sys.argv[1:]
    for f in ALL:
        if not names or f.__name__ in names:
            f()
            print("ok", f.__name__)
