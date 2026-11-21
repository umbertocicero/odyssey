"""Ritratti HUD 128x128 dalle schede personaggio in ispirazione/characters (riquadro del volto), ritagliati in tondo con anello di bronzo
e fuori dal cerchio trasparenti. Uso: python3 hud_portraits.py"""
import os, math
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
SRC = os.path.join(ROOT, "ispirazione", "characters")
OUT = os.path.join(ROOT, "assets", "ui", "hud")
# nome file HUD -> (scheda, riquadro quadrato nel volto in px della scheda 2752x1536)
P = {
    "ulisse": ("ulisse.jpeg", (40, 40, 650, 650)),
    "euriloco": ("euriloco.jpeg ", (60, 90, 640, 670)),
    "elpenore": ("Elpenore.jpeg", (60, 70, 640, 650)),
    "euribate": ("Euribate.jpeg", (60, 50, 640, 630)),
    "filotete": ("Filotete.jpeg", (60, 50, 640, 630)),
    "polite": ("polite.jpeg", (60, 70, 640, 650)),
    "perimede": ("Perimede.jpeg", (60, 50, 640, 630)),
    "menelao": ("Menelao.jpeg", (40, 190, 620, 770)),
    "agamennone": ("Agamennone.jpeg", (40, 190, 620, 770)),
    "pandaro": ("Trojan.jpeg", (60, 80, 640, 660)),
    "deifobo": ("Trojan_2.jpeg", (60, 80, 640, 660)),
    "pandaro_arciere": ("Trojan_arco.jpeg", (60, 80, 640, 660)),
}
ALIAS = {"oplita_acheo": "euriloco", "ufficiale_troiano": "deifobo", "arciere_troiano": "pandaro_arciere"}   # nomi dei file del primo gruppo
S = 512
C = S // 2


def ritratto(nome):
    f, box = P[nome]
    im = Image.open(os.path.join(SRC, f)).convert("RGB").crop(box).resize((S, S), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(0.9)
    im = ImageEnhance.Contrast(im).enhance(1.05)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = Image.new("L", (S, S), 0); ImageDraw.Draw(m).ellipse([22, 22, S - 22, S - 22], fill=255)
    out.paste(im, (0, 0), m)
    d = ImageDraw.Draw(out)
    for r, col in ((C - 14, (150, 110, 58, 255)), (C - 20, (74, 50, 26, 255)), (C - 28, (196, 156, 88, 255)), (C - 34, (60, 40, 22, 255))):
        pass
    d.ellipse([20, 20, S - 20, S - 20], outline=(66, 44, 22, 255), width=10)
    d.ellipse([30, 30, S - 30, S - 30], outline=(176, 134, 72, 255), width=8)
    d.ellipse([38, 38, S - 38, S - 38], outline=(52, 36, 20, 255), width=5)
    return out


if __name__ == "__main__":
    for n in P:
        r = ritratto(n).resize((128, 128), Image.LANCZOS)
        r.save(os.path.join(OUT, f"portrait_{n}.png"), optimize=True)
        print(n)
    for old, n in ALIAS.items():
        ritratto(n).resize((128, 128), Image.LANCZOS).save(os.path.join(OUT, f"portrait_{old}.png"), optimize=True)
