"""Condivide le texture identiche tra i modelli di campo/: una sola copia in campo/_tex/, i .gltf puntano li'.

Perche': ogni modello esportato porta la propria copia di bark_c.jpg, rope_r.jpg, planks_n.jpg... Godot importa ogni copia come una
risorsa diversa e la VRAM si moltiplica (363 file, solo 81 contenuti unici). Con un'unica copia condivisa la texture e' caricata una volta.
Le texture uniche restano nella cartella del modello. Idempotente: si puo' rilanciare dopo ogni nuova esportazione.
Uso: python3 share_textures.py [campo]
"""
import glob, hashlib, json, os, sys

CUSTOM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
root = os.path.join(CUSTOM, sys.argv[1] if len(sys.argv) > 1 else "campo")
shared = os.path.join(root, "_tex")


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


# 1) tutti i riferimenti dei .gltf -> file reale
refs = {}                                     # percorso reale -> lista di (gltf, indice immagine)
gltfs = [g for g in glob.glob(os.path.join(root, "**", "*.gltf"), recursive=True) if os.sep + "_tex" + os.sep not in g]
data = {g: json.load(open(g)) for g in gltfs}
for g, d in data.items():
    for i, im in enumerate(d.get("images", [])):
        p = os.path.normpath(os.path.join(os.path.dirname(g), im["uri"]))
        if os.path.exists(p):
            refs.setdefault(p, []).append((g, i))
# 2) raggruppa per contenuto: i gruppi con piu' file diversi (anche gia' condivisi) finiscono in _tex
by_hash = {}
for p in refs:
    by_hash.setdefault(md5(p), []).append(p)
os.makedirs(shared, exist_ok=True)
moved = 0
names = {}
for h, paths in by_hash.items():
    in_shared = [p for p in paths if os.path.dirname(p) == shared]
    if len(paths) < 2 and not in_shared:
        continue                                               # texture unica: resta dov'e'
    name = os.path.basename(paths[0])
    if in_shared:
        target = in_shared[0]
    else:
        target = os.path.join(shared, name)
        if os.path.exists(target) and md5(target) != h:        # stesso nome, contenuto diverso
            base, ext = os.path.splitext(name)
            target = os.path.join(shared, f"{base}_{h[:6]}{ext}")
        if not os.path.exists(target):
            os.replace(paths[0], target)
    for p in paths:
        if p != target:
            if os.path.exists(p):
                os.remove(p)
            if os.path.exists(p + ".import"):
                os.remove(p + ".import")
            moved += 1
    names[h] = target
# 3) riscrivi gli uri dei .gltf
changed = 0
for h, target in names.items():
    for p in by_hash[h]:
        for (g, i) in refs[p]:
            new = os.path.relpath(target, os.path.dirname(g)).replace(os.sep, "/")
            if data[g]["images"][i]["uri"] != new:
                data[g]["images"][i]["uri"] = new
                changed += 1
for g, d in data.items():
    json.dump(d, open(g, "w"), indent=1)
print("copie duplicate rimosse:", moved, "| riferimenti aggiornati:", changed, "| texture condivise:", len(glob.glob(os.path.join(shared, "*"))))
