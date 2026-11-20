"""Ritocco di colore della tenda di Gajk.Mv (Sketchfab, CC-BY-4.0) sulla palette del gioco (STYLE.md sez. 5).

L'originale e' tela quasi grigia e pali chiari. Si rimappa la LUMINOSITA' (le pieghe e i dettagli restano) su:
tela di lino consumata e affumicata (ocra scuro) e corteccia scura per i pali, con macchie di sporco e fumo.
Uso: python3 grade_gajk_tent.py <cartella tent estratta (scene.gltf + textures/)>
"""
import os, sys
from PIL import Image, ImageChops, ImageOps
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pbr_tex as T

d = os.path.join(sys.argv[1], "textures")
for name, dark, mid, light, dirt in (("Tent", (112, 94, 66), (176, 154, 112), (222, 202, 160), True),
                                     ("Stick", (56, 42, 30), (104, 80, 56), (156, 126, 92), False),
                                     ("Ropes", (74, 58, 38), (122, 98, 64), (164, 136, 92), False)):
    f = os.path.join(d, name + "_baseColor.jpeg")
    im = Image.open(f).convert("RGB")
    g = ImageOps.autocontrast(im.convert("L"), cutoff=1)
    out = ImageOps.colorize(g, dark, light, mid=mid)
    if dirt:                                              # macchie di fumo e sporco, piu' scure verso il basso
        n = im.size[0]
        st = T.fbm(n, 77, cells=4, octaves=5).point(lambda v: 185 + v * 70 // 255)
        out = ImageChops.multiply(out, st.convert("RGB"))
    out.save(f, "JPEG", quality=92, subsampling=0)
    print("graded", name)
