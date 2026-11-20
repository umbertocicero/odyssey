"""Ricomprime le texture PNG senza alpha dei .gltf di polyhaven/ in JPEG (q=90, senza sottocampionamento
del colore, adatto alle normal map) e aggiorna i riferimenti. Le texture con alpha reale restano PNG.

Poi toglie il profilo ICC incorporato da OGNI jpg e png sotto la cartella (compresi i materiali di
terreno_costa/): il loader di Godot 4.7 rifiuta le JPEG con profilo ICC (import valid=false). Per le JPEG usa
`jpegtran -copy none`, senza ricodificare (stessi pixel, stessa qualita'); per i PNG ricodifica lossless con Pillow.
Dopo un'importazione nuova di modelli lanciare SEMPRE questo script. Se Godot ha gia' segnato valid=false un file,
cancellare il suo .import prima di rifare l'import (altrimenti non lo riprova).

Uso: python3 compress_textures.py [cartella]      (default: polyhaven/)
"""
import json, os, sys, glob
from PIL import Image, ImageFile
ImageFile.MAXBLOCK = 2 ** 27   # 'optimize' su immagini grandi richiede un buffer ampio

CUSTOM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(CUSTOM, "polyhaven")
saved = 0
for tdir in sorted(set(os.path.dirname(f) for f in glob.glob(os.path.join(root, "*", "*", "textures", "*.png")))):
    mapping = {}
    for png in sorted(glob.glob(os.path.join(tdir, "*.png"))):
        im = Image.open(png)
        if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
            if im.mode != "P" and im.getchannel("A").getextrema()[0] < 255:
                continue                      # alpha reale: resta PNG
        if im.mode in ("I;16", "I"):
            im = im.point(lambda v: v / 257.0).convert("L")
        jpg = png[:-4] + ".jpg"
        im.convert("L" if im.mode == "L" else "RGB").save(jpg, "JPEG", quality=90, subsampling=0, optimize=True)
        saved += os.path.getsize(png) - os.path.getsize(jpg)
        mapping[os.path.basename(png)] = os.path.basename(jpg)
        os.remove(png)
        if os.path.exists(png + ".import"):
            os.remove(png + ".import")        # sara' rigenerato da Godot per il nuovo file
    if not mapping:
        continue
    for g in glob.glob(os.path.join(os.path.dirname(tdir), "*.gltf")):
        d = json.load(open(g)); ch = False
        for img in d.get("images", []):
            b = os.path.basename(img.get("uri", ""))
            if b in mapping:
                img["uri"] = "textures/" + mapping[b]; img["mimeType"] = "image/jpeg"; ch = True
        if ch:
            json.dump(d, open(g, "w"), indent=1)
# allinea ogni .gltf ai file realmente presenti (anche dopo un'esecuzione interrotta)
for g in glob.glob(os.path.join(root, "*", "*", "*.gltf")):
    d = json.load(open(g)); ch = False
    for img in d.get("images", []):
        u = img.get("uri", "")
        if u.endswith(".png") and not os.path.exists(os.path.join(os.path.dirname(g), u)) \
                and os.path.exists(os.path.join(os.path.dirname(g), u[:-4] + ".jpg")):
            img["uri"] = u[:-4] + ".jpg"; img["mimeType"] = "image/jpeg"; ch = True
    if ch:
        json.dump(d, open(g, "w"), indent=1)
# --- WebP -> JPEG/PNG: le sorgenti Sketchfab hanno EXT_texture_webp; non dipendiamo dal suo supporto in Godot ---
for g in glob.glob(os.path.join(root, "**", "*.gltf"), recursive=True):
    d = json.load(open(g)); gd = os.path.dirname(g); ch = False
    for img in d.get("images", []):
        u = img.get("uri", "")
        if u.endswith(".webp") and os.path.exists(os.path.join(gd, u)):
            im = Image.open(os.path.join(gd, u)); im.load()
            has_a = im.mode in ("RGBA", "LA") and im.getchannel("A").getextrema()[0] < 255
            new = u[:-5] + (".png" if has_a else ".jpg")
            if has_a:
                im.save(os.path.join(gd, new), "PNG", optimize=True)
            else:
                im.convert("RGB").save(os.path.join(gd, new), "JPEG", quality=90, subsampling=0, optimize=True)
            os.remove(os.path.join(gd, u))
            if os.path.exists(os.path.join(gd, u + ".import")):
                os.remove(os.path.join(gd, u + ".import"))
            img["uri"] = new; img["mimeType"] = "image/png" if has_a else "image/jpeg"; ch = True
    if ch:
        for t in d.get("textures", []):
            ext = t.get("extensions", {}).pop("EXT_texture_webp", None)
            if ext is not None:
                t["source"] = ext["source"]
            if not t.get("extensions"):
                t.pop("extensions", None)
        for k in ("extensionsUsed", "extensionsRequired"):
            if k in d:
                d[k] = [e for e in d[k] if e != "EXT_texture_webp"]
                if not d[k]:
                    del d[k]
        json.dump(d, open(g, "w"), indent=1)
# --- niente profili ICC ---
import subprocess, shutil
stripped = 0
for f in glob.glob(os.path.join(root, "**", "*.jpg"), recursive=True):
    im = Image.open(f)
    if im.info.get("icc_profile"):
        tmp = f + ".tmp"
        if shutil.which("jpegtran"):
            subprocess.run(["jpegtran", "-copy", "none", "-optimize", "-outfile", tmp, f], check=True)
        else:                       # senza jpegtran: ricodifica (q95, nessun profilo)
            im.convert("RGB").save(tmp, "JPEG", quality=95, subsampling=0, icc_profile=None)
        os.replace(tmp, f); stripped += 1
for f in glob.glob(os.path.join(root, "**", "*.png"), recursive=True):
    im = Image.open(f)
    if im.info.get("icc_profile"):
        im.load(); im.save(f, "PNG", optimize=True, icc_profile=None); stripped += 1
print("profili ICC rimossi da", stripped, "file")
print("risparmiati %.0f MB" % (saved / 1048576))
