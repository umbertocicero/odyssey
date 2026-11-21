"""Asset grafici dell'HUD in assets/ui/hud/ (PNG con alpha): icone 64x64 (e 128x128 @2x) in cornice rotonda di bronzo, e due texture
ripetibili da 512 px: pergamena invecchiata e bronzo opaco con greca a meandro. Palette smorzata (STYLE.md sez. 5).
I ritratti sono resi da Blender (render_portrait.py) e ridotti a 128 px.

Uso: python3 hud_assets.py
"""
import math, os, random, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps, ImageEnhance
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pbr_tex as T

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", "ui", "hud"))
S = 512
C = S // 2


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def cornice():
    """Cornice rotonda di bronzo smussato con fondo scuro a vignetta; ritorna (immagine RGBA, maschera del disco interno)."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r_out, r_in = 254, 190
    dark, light = (62, 42, 24), (186, 142, 78)
    for r in range(r_out, r_in - 1, -1):
        t = (r_out - r) / (r_out - r_in)
        v = math.sin(math.pi * t) ** 0.8                        # smussatura: scuro ai bordi, chiaro al centro dell'anello
        d.ellipse([C - r, C - r, C + r, C + r], fill=lerp(dark, light, v) + (255,))
    # riflesso in alto a sinistra e ombra in basso a destra sull'anello
    ring = Image.new("L", (S, S), 0)
    ImageDraw.Draw(ring).ellipse([C - r_out, C - r_out, C + r_out, C + r_out], fill=255)
    ImageDraw.Draw(ring).ellipse([C - r_in, C - r_in, C + r_in, C + r_in], fill=0)
    grad = Image.linear_gradient("L").resize((S, S)).rotate(45, resample=Image.BICUBIC, expand=False)
    hl = ImageChops.multiply(ring, grad.point(lambda v: max(0, 255 - v * 2)))
    sh = ImageChops.multiply(ring, grad.point(lambda v: max(0, v * 2 - 255)))
    img = Image.composite(Image.new("RGBA", (S, S), (236, 196, 120, 255)), img, hl.point(lambda v: v * 4 // 10))
    img = Image.composite(Image.new("RGBA", (S, S), (30, 20, 12, 255)), img, sh.point(lambda v: v * 5 // 10))
    d = ImageDraw.Draw(img)
    d.ellipse([C - r_out, C - r_out, C + r_out, C + r_out], outline=(40, 26, 14, 255), width=5)
    d.ellipse([C - r_in, C - r_in, C + r_in, C + r_in], outline=(34, 22, 12, 255), width=5)
    for k in range(24):                                          # borchie sull'anello
        a = 2 * math.pi * k / 24
        x, y = C + 222 * math.cos(a), C + 222 * math.sin(a)
        d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(126, 92, 48, 255), outline=(48, 32, 18, 255))
    # fondo del disco interno: cuoio scuro con vignetta
    inner = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    vg = Image.radial_gradient("L").resize((S, S))
    bgc = ImageOps.colorize(vg, (112, 84, 58), (30, 22, 17))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([C - r_in + 3, C - r_in + 3, C + r_in - 3, C + r_in - 3], fill=255)
    inner.paste(bgc, (0, 0), mask)
    return Image.alpha_composite(inner, img), mask


def con_ombra(layer):
    """Aggiunge un'ombra morbida sotto l'icona disegnata."""
    a = layer.getchannel("A").filter(ImageFilter.GaussianBlur(7))
    sh = Image.new("RGBA", (S, S), (10, 6, 3, 0))
    sh.putalpha(a.point(lambda v: v * 6 // 10))
    sh = ImageChops.offset(sh, 6, 9)
    return Image.alpha_composite(sh, layer)


def lucido(layer, dx=-1, dy=-1):
    """Riflesso sottile sui bordi alti/sinistri dell'icona."""
    a = layer.getchannel("A")
    edge = ImageChops.subtract(a, ImageChops.offset(a, -dx * 5, -dy * 5))
    hl = Image.new("RGBA", (S, S), (255, 232, 180, 0))
    hl.putalpha(edge.point(lambda v: v * 5 // 10))
    return Image.alpha_composite(layer, hl)


# ---------------------------------------------------------------- icone
def spada():
    L = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    steel_l, steel_d = (214, 206, 190), (146, 140, 128)
    d.polygon([(256, 62), (286, 150), (278, 300), (234, 300), (226, 150)], fill=steel_d)         # lama: metà ombreggiata
    d.polygon([(256, 62), (226, 150), (234, 300), (256, 300)], fill=steel_l)                      # metà illuminata
    d.line([(256, 82), (256, 296)], fill=(98, 92, 82), width=5)                                   # canale centrale
    d.polygon([(190, 296), (322, 296), (330, 316), (314, 326), (198, 326), (182, 316)], fill=(176, 130, 66), outline=(70, 48, 24))   # guardia
    d.rectangle([246, 326, 266, 396], fill=(96, 62, 36), outline=(46, 30, 18))                    # impugnatura di cuoio
    for y in range(334, 394, 10):
        d.line([(246, y), (266, y + 6)], fill=(60, 40, 24), width=3)
    d.ellipse([234, 392, 278, 432], fill=(206, 164, 84), outline=(80, 56, 28), width=4)           # pomo
    d.ellipse([248, 404, 264, 420], fill=(74, 104, 78))                                           # gemma di Itaca (verde oliva)
    L = L.rotate(-45, resample=Image.BICUBIC, center=(256, 246))
    L = L.resize((int(S * 0.86), int(S * 0.86)), Image.LANCZOS)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0)); out.paste(L, ((S - L.width) // 2, (S - L.height) // 2), L)
    return out


def hoplon():
    L = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    r = 160
    d.ellipse([C - r, C - r, C + r, C + r], fill=(150, 108, 54), outline=(56, 38, 20), width=6)
    d.ellipse([C - 136, C - 136, C + 136, C + 136], fill=(112, 44, 36))
    d.ellipse([C - 136, C - 136, C + 136, C + 136], outline=(84, 58, 30), width=5)
    gold = (196, 156, 84)
    d.rectangle([C - 8, C - 70, C + 8, C + 78], fill=gold)                                         # tridente
    for ox in (-34, 34):
        d.rectangle([C + ox - 5, C - 56, C + ox + 5, C - 8], fill=gold)
        d.polygon([(C + ox - 16, C - 52), (C + ox, C - 84), (C + ox + 16, C - 52)], fill=gold)
    d.polygon([(C - 16, C - 66), (C, C - 100), (C + 16, C - 66)], fill=gold)
    d.arc([C - 40, C - 52, C + 40, C + 10], 0, 180, fill=gold, width=11)
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([C - 120, C - 120, C - 20, C - 20], fill=(255, 220, 170, 60))
    L = Image.alpha_composite(L, hl.filter(ImageFilter.GaussianBlur(24)))
    for a in (200, 40):                                                                            # ammaccature
        x, y = C + 70 * math.cos(math.radians(a)), C + 70 * math.sin(math.radians(a))
        ImageDraw.Draw(L).ellipse([x - 14, y - 10, x + 14, y + 10], fill=(60, 30, 24, 120))
    return L


def lancia():
    L = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    d.rectangle([248, 150, 264, 450], fill=(132, 92, 54), outline=(60, 40, 22))                    # asta
    d.rectangle([248, 150, 256, 450], fill=(160, 114, 70))
    d.polygon([(256, 44), (292, 120), (272, 160), (240, 160), (220, 120)], fill=(176, 130, 66), outline=(70, 48, 24))   # punta a foglia
    d.polygon([(256, 44), (220, 120), (240, 160), (256, 160)], fill=(214, 172, 100))
    d.line([(256, 60), (256, 156)], fill=(120, 86, 40), width=4)
    d.rectangle([240, 158, 272, 176], fill=(150, 108, 54), outline=(60, 42, 22))                   # manicotto
    d.polygon([(250, 450), (262, 450), (256, 486)], fill=(150, 150, 142), outline=(70, 70, 66))    # puntale
    d.line([(248, 330), (264, 322)], fill=(60, 40, 22), width=4)
    d.line([(248, 342), (264, 334)], fill=(60, 40, 22), width=4)
    L = L.rotate(-40, resample=Image.BICUBIC, center=(256, 256))
    L = L.resize((int(S * 0.86), int(S * 0.86)), Image.LANCZOS)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0)); out.paste(L, ((S - L.width) // 2, (S - L.height) // 2), L)
    return out


def pozione():
    L = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    d.ellipse([156, 200, 356, 400], fill=(176, 168, 150, 255), outline=(62, 50, 36), width=6)       # corpo di vetro
    d.rectangle([232, 130, 280, 232], fill=(176, 168, 150, 255), outline=(62, 50, 36), width=6)    # collo
    liq = Image.new("RGBA", (S, S), (0, 0, 0, 0)); dl = ImageDraw.Draw(liq)
    dl.ellipse([166, 212, 346, 390], fill=(70, 118, 100, 255))
    cut = Image.new("L", (S, S), 0); ImageDraw.Draw(cut).rectangle([0, 288, S, S], fill=255)        # il liquido arriva a due terzi
    liq.putalpha(ImageChops.multiply(liq.getchannel("A"), cut))
    L = Image.alpha_composite(L, liq)
    d = ImageDraw.Draw(L)
    d.ellipse([172, 276, 340, 300], fill=(104, 160, 138, 255))                                      # superficie
    d.rectangle([226, 104, 286, 142], fill=(130, 90, 54), outline=(56, 36, 20), width=5)           # tappo di sughero
    d.line([(232, 118), (280, 118)], fill=(96, 64, 38), width=3)
    d.ellipse([186, 226, 226, 276], fill=(255, 250, 235, 120))                                      # riflessi
    d.line([(246, 158), (246, 214)], fill=(255, 250, 235, 130), width=6)
    d.rectangle([232, 232, 280, 244], fill=(150, 108, 54), outline=(62, 44, 24))                    # legaccio di bronzo
    return L


def borsa():
    L = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    d.ellipse([136, 214, 376, 436], fill=(124, 84, 52), outline=(54, 34, 20), width=6)             # corpo
    d.polygon([(196, 244), (316, 244), (298, 176), (214, 176)], fill=(106, 72, 44), outline=(54, 34, 20))   # collo arricciato
    for x in range(204, 312, 18):
        d.line([(x, 180), (x - 6 + (x % 7), 242)], fill=(72, 48, 30), width=3)                      # pieghe
    d.line([(190, 236), (322, 238)], fill=(190, 160, 106), width=9)                                   # laccio
    d.ellipse([242, 226, 272, 252], fill=(176, 138, 84), outline=(70, 48, 28), width=3)             # nodo
    d.line([(272, 244), (306, 290)], fill=(190, 160, 106), width=5)
    d.line([(236, 248), (212, 296)], fill=(190, 160, 106), width=5)
    d.arc([156, 252, 356, 424], 20, 160, fill=(68, 44, 28), width=4)                                # cucitura
    d.ellipse([172, 252, 256, 330], fill=(255, 220, 170, 38))
    d.rectangle([240, 322, 272, 362], fill=(176, 130, 66), outline=(70, 48, 24), width=4)           # placca di bronzo
    return L


def icona(nome, fn):
    fr, _ = cornice()
    ic = lucido(con_ombra(fn()))
    img = Image.alpha_composite(fr, ic)
    img = ImageEnhance.Color(img.convert("RGB")).enhance(0.9).convert("RGBA") if False else img
    for px, suff in ((64, ""), (128, "_2x")):
        o = img.resize((px, px), Image.LANCZOS)
        o.save(os.path.join(OUT, f"icon_{nome}{suff}.png"), optimize=True)
    return img


# ---------------------------------------------------------------- texture ripetibili
def pergamena(size=512, seed=81):
    g = T.fbm(size, seed, cells=3, octaves=6)
    col = T.colorize(g, (178, 150, 106), (214, 190, 146), (238, 220, 178))
    fibre = T.noise(size, 300, 40, seed + 2).point(lambda v: 214 + v // 6)                           # fibre orizzontali
    col = ImageChops.multiply(col, fibre.convert("RGB"))
    macchie = T.fbm(size, seed + 5, cells=4, octaves=5).point(lambda v: 255 if v > 205 else int(190 + v * 65 // 205))
    col = ImageChops.multiply(col, macchie.convert("RGB"))
    aloni = T.fbm(size, seed + 9, cells=2, octaves=3).point(lambda v: 0 if v < 190 else min(150, (v - 190) * 4)).filter(ImageFilter.GaussianBlur(6))
    col = Image.composite(Image.new("RGB", (size, size), (132, 96, 58)), col, aloni.point(lambda v: v * 5 // 10))   # aloni bruni di umidità
    rnd = random.Random(seed)
    d = ImageDraw.Draw(col)
    for _ in range(260):                                                                             # puntini di ossidazione
        x, y = rnd.randrange(size), rnd.randrange(size)
        r = rnd.choice((1, 1, 2, 3))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(118, 88, 56))
    col.save(os.path.join(OUT, "tex_pergamena.png"), optimize=True)


def meandro(size=512, seed=82):
    g = T.fbm(size, seed, cells=4, octaves=6)
    base = T.colorize(g, (92, 64, 34), (138, 100, 52), (176, 134, 76))
    patina = T.fbm(size, seed + 4, cells=3, octaves=4).point(lambda v: 255 if v > 200 else 0).filter(ImageFilter.GaussianBlur(10))
    base = Image.composite(Image.new("RGB", (size, size), (72, 98, 78)), base, patina.point(lambda v: v * 3 // 10))
    cell, u = 64, 8                                                                                   # cella 64 px, unita' 8 px: motivo 8 x 6 unita'
    key = [(0, 6), (0, 0), (6, 0), (6, 4), (2, 4), (2, 2), (4, 2)]
    line = Image.new("L", (size, size), 0)
    ld = ImageDraw.Draw(line)
    for r in range(size // cell):
        for c in range(size // cell):
            ox, oy = c * cell, r * cell + 10
            pts = [(ox + x * u, oy + y * u) for x, y in key]
            base_pts = [(ox, oy + 6 * u), (ox + 8 * u, oy + 6 * u)]                                 # linea di base che unisce le celle
            ld.line(base_pts, fill=255, width=7)
            ld.line(pts, fill=255, width=7, joint="curve")
            for p in pts:
                ld.ellipse([p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3], fill=255)
    dark = ImageChops.offset(line, 3, 3)
    light = ImageChops.offset(line, -2, -2)
    out = Image.composite(Image.new("RGB", (size, size), (44, 30, 16)), base, dark.point(lambda v: v * 7 // 10))
    out = Image.composite(Image.new("RGB", (size, size), (210, 168, 100)), out, light.point(lambda v: v * 6 // 10))
    out = Image.composite(Image.new("RGB", (size, size), (132, 94, 48)), out, line.point(lambda v: v * 9 // 10))
    out = ImageChops.multiply(out, T.fbm(size, seed + 7, cells=5, octaves=4).point(lambda v: 200 + v // 5).convert("RGB"))
    out.save(os.path.join(OUT, "tex_bronzo_greca.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for nome, fn in (("spada_itaca", spada), ("hoplon", hoplon), ("lancia", lancia), ("pozione", pozione), ("borsa", borsa)):
        icona(nome, fn)
        print("icona", nome)
    pergamena(); print("pergamena")
    meandro(); print("bronzo con greca")
