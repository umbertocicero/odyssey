# Animali (da art_source/animals)

Modelli Sketchfab **CC-BY-4.0** scaricati da Umberto (sorgenti grezzi 0,03-2 M tri in `art_source/animals/<nome zip>/`, licenze in ogni `license.txt`, crediti in `../sketchfab/CREDITI.md`).
Script: `_source/scripts/build_animali.py` (un Blender alla volta: pulizia, allineamento PCA, scala reale, decimazione, 2 LOD, export) poi `fix_animali_tex.py` (JPEG senza ICC, altrimenti Godot non li carica) e `tune_imports.py animali` (VRAM compressed + mipmap, 512 px per il bestiame secondario).

Convenzioni: metri reali, origine fra i piedi, **fronte -Z Godot**, un materiale PBR (colore, normal, metallic/roughness). Cartelle `<nome>/` (texture 1024) e `<nome>_lod/` (512, ~1/3 dei triangoli). Statici, senza rig.

| Modello | Altezza | Tri / lod | Uso nel livello 1 |
|---|---|---|---|
| cavallo_castagno | 1,62 m | 30.000 / 9.000 | cavalli del campo, della strada e del carro da battaglia (sostituisce baio e grigio) |
| cavallo_da_tiro | 1,72 m | 26.000 / 8.000 | cavallo del campo, coppia davanti al carro coperto |
| cavallo_bardato | 1,62 m | 30.000 / 9.000 | non usato (sella con staffe: anacronistica) |
| pecora, montone_lana, montone_corna | 0,8-0,95 m | 14-20.000 / 5-6.000 | gregge vicino al carro coperto (corna non usato) |
| maiale_rosa, maiale_macchiato | 0,7-0,9 m | 9-16.000 / 3,5-5.000 | maiali vicino al carro |
| cervo, ghepardo | 1,5 m / 1,25 m lungo | 22.000 / 7.000 | non usati (fuori luogo) |

Non importato: `horse.zip` (cavallo con rig e 28 animazioni, sella e criniera a carte, 30k tri): è in `art_source/animals/horse` se serviranno cavalli animati.
Screenshot: `tests/screenshot_animali.gd`.
