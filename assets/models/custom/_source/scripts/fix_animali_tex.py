"""Dopo build_animali.py: riscrive i JPEG di animali/*/textures senza profilo ICC (Godot non carica quelli scritti da Blender) e li verifica.
Uso: python3 fix_animali_tex.py"""
import glob, os
from PIL import Image
D = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "animali"))
for f in sorted(glob.glob(D + "/*/textures/*.jpg")):
    im = Image.open(f)
    px = im.size
    q = 94 if os.path.basename(f).startswith("n") else 90
    im.convert("RGB").save(f, "JPEG", quality=q, optimize=True, icc_profile=None)
    print(os.path.relpath(f, D), px, os.path.getsize(f) // 1024, "KB")
