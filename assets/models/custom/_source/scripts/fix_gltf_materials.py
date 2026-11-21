"""Dichiara esplicitamente metallicFactor su OGNI materiale dei .gltf (polyhaven/, sketchfab/ e campo/).

Perche': l'esporter glTF di Blender omette metallicFactor quando vale 1 (il predefinito della specifica) e la
texture metallicRoughness ha R = occlusione (bianca), G = roughness, B = metallo. Dove B non e' una vera mappa
di metallo (bianco o nero quasi uniforme: artefatto) il materiale risulta metallico o bianco in Godot.

Regola: canale B con deviazione standard < 40 -> metallicFactor 0 (nessuna mappa di metallo reale);
        altrimenti -> 1.0 (mappa di metallo vera: teste di martelli, fascette, ecc.);
        nessuna texture metallicRoughness -> 0.
Uso: python3 fix_gltf_materials.py        (dopo OGNI importazione, insieme a compress_textures.py)
"""
import json, glob, os, sys
from PIL import Image, ImageStat

CUSTOM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
n0 = n1 = nchanged = 0
for g in sorted(glob.glob(os.path.join(CUSTOM, "polyhaven", "*", "*", "*.gltf")) + glob.glob(os.path.join(CUSTOM, "sketchfab", "*", "*", "*.gltf")) + glob.glob(os.path.join(CUSTOM, "campo", "**", "*.gltf"), recursive=True)):
    d = json.load(open(g)); ch = False
    for m in d.get("materials", []):
        p = m.setdefault("pbrMetallicRoughness", {})
        mr = p.get("metallicRoughnessTexture")
        if mr:
            f = os.path.join(os.path.dirname(g), d["images"][d["textures"][mr["index"]]["source"]]["uri"])
            sd = ImageStat.Stat(Image.open(f).convert("RGB").resize((128, 128)).getchannel("B")).stddev[0]
            want = 1.0 if sd >= 40 else 0.0
        else:
            want = 0.0
        if p.get("metallicFactor") != want:
            p["metallicFactor"] = want; ch = True; nchanged += 1
        n1 += want == 1.0; n0 += want == 0.0
    if ch:
        json.dump(d, open(g, "w"), indent=1)
print("metallicFactor 0:", n0, "| 1.0:", n1, "| materiali modificati:", nchanged)
