"""Imposta i parametri di import Godot delle texture dei modelli (campo/, polyhaven/, sketchfab/) e rifa' l'import.

Perche': senza queste impostazioni Godot importa le texture senza compressione (compress/mode=0) e senza mipmap:
VRAM molto piu' alta e moire' sui tessuti. Regole (lette dai .gltf, che dicono a cosa serve ogni file):
  - tutte: compress/mode=2 (VRAM compressed) e mipmaps/generate=true;
  - normal map: compress/normal_map=1 (abilita);
  - texture a carte con alpha (foglie, fiamme, crini): VRAM compressed + mipmap + process/fix_alpha_border=true.
Se un .import non esiste ancora, lancia prima 'godot --headless --import' per farlo generare; alla fine reimporta.
Imposta process/size_limit=512 per le texture dei props secondari (SECONDARY_MODELS) e delle famiglie generiche (SMALL_TEXTURES).
Include anche terreno_costa/ e le textures_2k delle rocce (polyhaven): quando servono vanno compresse come le altre.

Uso: python3 tune_imports.py [campo|polyhaven|sketchfab ...]      (default: campo)
Opzioni: --no-godot   solo modifica i .import, senza lanciare Godot.
"""
import glob, json, os, re, shutil, subprocess, sys
from PIL import Image

CUSTOM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PROJECT = os.path.abspath(os.path.join(CUSTOM, "..", "..", ".."))
# Props secondari: le loro texture (se usate SOLO da loro) e queste famiglie di texture generiche stanno a 512 px (process/size_limit=512)
SECONDARY_MODELS = ("campo/giare_panche/panca_", "campo/giare_panche/pithos_medio", "campo/luci/torcia_", "campo/luci/braciere_",
                    "polyhaven/oggetti/wooden_ladder_02", "polyhaven/oggetti/wooden_stool_02", "polyhaven/oggetti/wooden_bucket_02",
                    "polyhaven/oggetti/wooden_crate_01", "polyhaven/oggetti/wooden_barrels_01", "polyhaven/attrezzi/", "polyhaven/attrezzi_fuori_epoca/", "campo/personaggi/masse/")
SMALL_TEXTURES = ("rope_", "bark_", "hoof_", "ash_", "charcoal_", "bronze_", "iron_", "cloak_")
args = [a for a in sys.argv[1:] if not a.startswith("--")]
roots = args or ["campo"]
use_godot = "--no-godot" not in sys.argv


def classify():
    """Percorso assoluto della texture -> 'normal' | 'alpha' | 'color' | 'data'."""
    kinds = {}
    for r in roots:
        for g in glob.glob(os.path.join(CUSTOM, r, "**", "*.gltf"), recursive=True):
            d = json.load(open(g)); base = os.path.dirname(g)
            def path_of(tex):
                return os.path.normpath(os.path.join(base, d["images"][d["textures"][tex["index"]]["source"]]["uri"]))
            for m in d.get("materials", []):
                pbr = m.get("pbrMetallicRoughness", {})
                if "normalTexture" in m:
                    kinds[path_of(m["normalTexture"])] = "normal"
                if "baseColorTexture" in pbr:
                    p = path_of(pbr["baseColorTexture"])
                    try:
                        im = Image.open(p)
                        has_a = im.mode in ("RGBA", "LA") and im.getchannel("A").getextrema()[0] < 255
                    except Exception:
                        has_a = False
                    kinds.setdefault(p, "alpha" if has_a else "color")
                for key in ("metallicRoughnessTexture",):
                    if key in pbr:
                        kinds.setdefault(path_of(pbr[key]), "data")
                for key in ("occlusionTexture", "emissiveTexture"):
                    if key in m:
                        kinds.setdefault(path_of(m[key]), "data" if key == "occlusionTexture" else "color")
    # texture non referenziate da .gltf: materiali del terreno e versioni 2K delle rocce (qualita' alta)
    for r in roots:
        for f in glob.glob(os.path.join(CUSTOM, r, "terreno_costa", "*", "*.*")) + glob.glob(os.path.join(CUSTOM, r, "*", "*", "textures_2k", "*.*")):
            if f.endswith((".jpg", ".png")):
                n = os.path.basename(f).lower()
                kinds.setdefault(f, "normal" if ("_nor" in n or "normal" in n) else ("color" if ("_diff" in n or "basecolor" in n) else "data"))
    return kinds


def run_godot():
    exe = shutil.which("godot")
    if not (use_godot and exe):
        return False
    subprocess.run([exe, "--headless", "--path", PROJECT, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1500)
    return True


def set_key(text, key, value):
    pat = re.compile(r"^%s=.*$" % re.escape(key), re.M)
    if pat.search(text):
        return pat.sub("%s=%s" % (key, value), text)
    return text.replace("[params]\n", "[params]\n\n%s=%s\n" % (key, value), 1)


# .import orfani (la texture sorgente non esiste piu', es. PNG sostituiti da JPEG condivisi): vanno tolti, risultano valid=false
orphans = 0
for r in roots:
    for imp in glob.glob(os.path.join(CUSTOM, r, "**", "*.import"), recursive=True):
        if not os.path.exists(imp[:-7]):
            os.remove(imp); orphans += 1
if orphans:
    print("rimossi %d .import orfani" % orphans)
kinds = classify()
# quali modelli usano ciascuna texture (per decidere il limite a 512)
users = {}
for r in roots:
    for g in glob.glob(os.path.join(CUSTOM, r, "**", "*.gltf"), recursive=True):
        d = json.load(open(g)); base = os.path.dirname(g)
        for im in d.get("images", []):
            users.setdefault(os.path.normpath(os.path.join(base, im["uri"])), set()).add(os.path.relpath(g, CUSTOM).replace(os.sep, "/"))


def wants_512(p):
    if os.path.basename(p).startswith(SMALL_TEXTURES):
        return True
    u = users.get(p)
    return bool(u) and all(any(m in x for m in SECONDARY_MODELS) for x in u)
missing = [p for p in kinds if not os.path.exists(p + ".import")]
if missing:
    print("%d texture senza .import: lancio un import di Godot per generarli" % len(missing))
    run_godot()
changed = 0
for p, kind in sorted(kinds.items()):
    imp = p + ".import"
    if not os.path.exists(imp):
        continue
    t = open(imp).read()
    o = t
    t = set_key(t, "compress/mode", "2")
    t = set_key(t, "mipmaps/generate", "true")
    if kind == "normal":
        t = set_key(t, "compress/normal_map", "1")
    if kind == "alpha":
        t = set_key(t, "process/fix_alpha_border", "true")
    t = set_key(t, "process/size_limit", "512" if wants_512(p) else "0")
    if t != o:
        open(imp, "w").write(t)
        changed += 1
print("file .import aggiornati:", changed, "su", len(kinds), "texture")
if changed and run_godot():
    print("reimport di Godot eseguito")
