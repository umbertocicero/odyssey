# Personaggi nuovi (da art_source/characters)

Sorgenti: `art_source/characters/*.blend` (mesh unica 1,8-2,4 M tri, A-pose, 3 texture 2K). Creati dall'autore con mesh.ai (vedi `sketchfab/CREDITI.md`).
Script: `_source/scripts/build_char_hires.py` (decimazione, scheletro, skinning, animazioni, export) e `shrink_char_tex.py` (texture a 1024).
Rigenerare (un Blender alla volta): `blender -b --factory-startup art_source/characters/Ulisse.blend -P build_char_hires.py -- ulisse slash 25000`.

| Cartella | Sorgente | Chi e' | Attacco |
|---|---|---|---|
| `ulisse/ulisse.gltf` | Ulisse.blend | Ulisse: elmo con cresta chiara, barba, corazza di bronzo, mantello scuro | slash (spada) |
| `elpenore/elpenore.gltf` | Elpenore.blend | Elpenore: benda sull'occhio, tunica grigia consunta, cinghie incrociate | slash |
| `euriloco/euriloco.gltf` | Euriloco.blend | Euriloco: elmo con cresta nera, tunica rossa scura, corazza | slash |
| `troiano_1/troiano_1.gltf` | troiano1.blend | soldato troiano, corazza dorata e blu | thrust (lancia) |
| `troiano_2/troiano_2.gltf` | troiano2.blend | soldato troiano, variante | thrust |
| `troiano_arciere/troiano_arciere.gltf` | traoiano3_con_arco.blend | troiano con faretra e frecce | shoot (arco: non c'e' l'arco nel modello) |

| `troiano_fanteria/troiano_fanteria.gltf` | troiano_fanteria.blend | fanteria troiana (Trojan Infantry): elmo con cresta blu, corazza di cuoio e bronzo, mantello blu. Sostituisce troiano_1/2 nel livello 1 | thrust |
| `troiano_capitano/troiano_capitano.gltf` | troaino_capitano.blend | capitano troiano (Lochagos): barba, corazza decorata con pteruges, cresta; mini-boss vicino alla porta | slash |
| `euribate/euribate.gltf` | Euribate.blend | Euribate | slash |
| `filotete/filotete.gltf`, `filotete_no_elmo/filotete_no_elmo.gltf` | Filotete.blend, Filotete_no_elmo.blend | Filotete (con elmo / senza elmo, fascia e bende) | slash |
| `polite/polite.gltf` | polite.blend | Polite (fascia sulla fronte) | slash |
| `perimede/perimede.gltf` | Perimede.blend | Perimede | slash |
| `menelao/menelao.gltf` | Menelao.blend | Menelao | slash |
| `agamennone/agamennone.gltf` | Agamennone.blend | Agamennone | slash |

**Versioni leggere**: ogni cartella ha la gemella `<nome>_lod/<nome>_lod.gltf` (~6.500 tri, texture 512, stesso rig e stesse animazioni). 15 personaggi x 2 versioni.

- ~25.000 tri ciascuno, 1 materiale PBR (base, ORM con G=roughness B=metallo, normale) a 1024 px, JPEG senza ICC, import Godot VRAM compressed + mipmap.
- Altezza ~1,52 m (i sorgenti sono 1,9 m, scalati 0,8 come le figurine di `personaggi/`), piedi a z=0, origine tra i piedi, fronte verso -Z in Godot.
- Scheletro (17 ossa, stessi nomi di `personaggi/`): root, hips, spine, neck, head, upperarm/forearm/hand .L/.R, thigh/shin/foot .L/.R. Niente osso mantello.
- Animazioni: `idle_loop`, `walk_loop`, `attack`, `hit`, `death` (gli stessi nomi dei vecchi personaggi; le `_loop` in loop). Pose semplici e rigide (armatura, nessuna arma in mano: scudo, lancia, spada e arco non sono nei modelli).
- Limiti: la posa a riposo e' una A-pose (braccia scostate); skinning automatico, per pezzi non collegati (parti dell'armatura) fusione morbida tra le ossa piu' vicine, quindi nelle pose estreme (attacco, morte) si vedono piccole deformazioni.
- Texture: 1K (~0,8 MB JPEG) per le versioni normali, 512 per le `_lod`; import Godot con `tune_imports.py personaggi_nuovi` (VRAM compressed + mipmap, normal map).
