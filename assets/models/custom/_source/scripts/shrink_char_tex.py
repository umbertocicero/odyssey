"""Riduce a 1024 (512 per le cartelle *_lod) le texture di personaggi_nuovi/*/ (JPEG q90) e toglie il profilo ICC
(Godot non carica i JPEG con ICC: 'Error loading image', albedo nullo e personaggio bianco).
Uso: python3 shrink_char_tex.py   (dopo build_char_mixamo.py)"""
import glob, os
from PIL import Image
D = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "personaggi_nuovi"))
for f in sorted(glob.glob(D + "/*/*.jpg")):
    im = Image.open(f)
    px = 512 if os.path.dirname(f).endswith("_lod") else 1024
    if im.size[0] > px or "icc_profile" in im.info:
        im.convert("RGB").resize((px, px), Image.LANCZOS) if im.size[0] > px else im.convert("RGB")
        out = im.convert("RGB").resize((px, px), Image.LANCZOS) if im.size[0] > px else im.convert("RGB")
        out.save(f, quality=90, optimize=True, icc_profile=None)
    print(f, Image.open(f).size, os.path.getsize(f) // 1024, "KB", "ICC" if "icc_profile" in Image.open(f).info else "")
