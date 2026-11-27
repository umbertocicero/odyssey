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
- **Braccia (26/11/2026)**: i giunti dello scheletro sono uguali per tutti, quindi nelle braccia scolpite le ossa passavano
  3-7 cm fuori dalla mesh e lo skinning automatico lasciava l'avambraccio quasi senza pesi: piegato sembrava di gomma, sottile
  e molle. `_source/scripts/fix_char_arms.py` corregge solo le braccia (scheletro e animazioni invariati): ricentra braccio e
  avambraccio sulle ossa (la mano resta ferma: `HandFist` ne misura la posa), li irrobustisce (+16% braccio, +14% avambraccio)
  e rifa' i pesi per segmenti rigidi con raccordi corti a spalla, gomito e polso. Si applica all'export a partire da
  `_source/blend/pn_<nome>.blend` (che non viene modificato, quindi si puo' rilanciare), tenendo le texture gia' ridotte:
  `blender -b --factory-startup _source/blend/pn_ulisse.blend -P _source/scripts/fix_char_arms.py -- ulisse` (anche per i `_lod`).
  Dopo una rigenerazione con `build_char_hires.py` va rilanciato.
- **Giunti (26/11/2026)**: gomito e polso di `build_char_hires.J` erano ~6 e ~8 cm troppo in basso lungo il braccio (gomito a
  meta' avambraccio, polso sulle dita: l'avambraccio piegato sembrava corto e tozzo). Ora sono misurati sulle mesh; tutti i
  personaggi e i `_lod` sono stati rigenerati. `HandFist.CENTER` e' stato spostato della stessa quantita'.
- Texture: 1K (~0,8 MB JPEG) per le versioni normali, 512 per le `_lod`; import Godot con `tune_imports.py personaggi_nuovi` (VRAM compressed + mipmap, normal map).

- **Versioni animate (27/11/2026)**: gli stessi 15 personaggi con rig Mixamo e animazioni baked sono in `../personaggi_animati/` (scudo di Agamennone rigido). Non ancora usati nel gioco.

- **Nuovi modelli Meshy (27/11/2026)**: tutti i 15 personaggi (e i `_lod`) sono stati rigenerati da `personaggi_animati/` (mesh Meshy ~30k tri con
  skinning Mixamo) con `_source/scripts/build_char_mixamo.py`: decimazione a ~25k / ~6,5k tri, A-pose del gioco ottenuta con lo scheletro
  Mixamo, **giunti dei 17 ossa misurati sul personaggio** (non piu' i `J` fissi), pesi Mixamo collassati sulle 17 ossa (dita -> mano,
  piede+punta -> piede, spalla 50% busto / 50% braccio, ossa extra Meshy -> fusione morbida), mani orientate come vuole `HandFist`
  (dita avanti-giu', palmo verso il corpo), stesse 5 animazioni baked e stessi nomi ossa: `HumanoidAnims`, duello, `UnitGear` ecc. non cambiano.
  Fronte verso -Y in Blender (+Z in Godot), ossa `.R` a +X, osso del piede verso +Y come nei vecchi rig. Agamennone: scudo fuso nella mesh e
  legato al 100% a `forearm.R`. Texture 1K/512 JPEG senza ICC (`shrink_char_tex.py`: Godot non carica i JPEG con ICC e il modello resta bianco).
  Rigenerare: `blender -b --factory-startup -P _source/scripts/build_char_mixamo.py -- ~/Scaricati/MODELLI_ANIMATI [nome ...]`, poi
  `python3 _source/scripts/shrink_char_tex.py`, cancellare i `.gltf.import`/`.jpg.import` e `tune_imports.py personaggi_nuovi`.
  I vecchi modelli (con le correzioni a braccia e giunti del 26/11) sono nel backup fuori dal repo `~/dev/Odyssey_backup_personaggi_nuovi`.
  `fix_char_arms.py` e `build_char_hires.py` non servono piu' per questi modelli.
- **Clip Mixamo retargettati (27/11/2026)**: `build_char_mixamo.py` trasferisce anche le animazioni Mixamo sulle 17 ossa (rotazioni globali relative alla A-pose,
  moto in avanti tolto dai cicli, quota dell'anca dal terreno) e le esporta come azioni `mx_walk_v<m/s>`, `mx_run_v<m/s>` (il numero e' la velocita' in
  metri/secondo, `p` = virgola), `mx_death_<n>` e `mx_attack_<n>` (4 al massimo; non usati in gioco). `scripts/units/mixamo_clips.gd` li carica per modello e
  `CharacterModel` (`mixamo_clips = true`) li usa al posto di walk, run e death dello stance normale; idle, attacchi, parate, stance dei feriti,
  remo e duello restano procedurali perche' dipendono da arma e scudo. Euriloco e Ulisse non hanno clip di morte Mixamo (procedurale).
  Test: `tests/screenshot_mx_gait.gd -- --model=<nome> [--mx=0]` (strisce di camminata, corsa, idle, morte).
  Braccia (27/11): a braccio alzato petto, cinghie e mantello seguivano il braccio: l'influenza dell'osso del braccio si attenua verso il centro
  (|x| < spalla) e va al busto (`collapse_weights`).
- **Ossa e mani (27/11/2026)**: i giunti sono per lato (le mesh non sono simmetriche al centimetro: con giunti medi le ossa uscivano dal braccio);
  polso = osso Hand di Mixamo, `hand_end` alle nocche, caviglie a 0,072 m (HumanoidAnims pianta le caviglie a quella quota). `HandFist.CENTER` e'
  il baricentro medio delle mani nuove rispetto al polso (HANDC in `build_char_mixamo.py`). A braccio alzato la parte alta della spalla segue il braccio al 40%.
  Demo: `scenes/demo/run_demo_characters.sh`.
