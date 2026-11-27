# Personaggi animati (Meshy + rig Mixamo)

I 15 personaggi di `personaggi_nuovi/` riconsegnati già animati (da `~/Scaricati/MODELLI_ANIMATI`, 27/11/2026). Stessa texture dei modelli
originali (verificato confrontando il base color), ma mesh unica ~30k tri, scheletro Mixamo (66 ossa; 36 per perimede/filotete, 78 per
filotete_no_elmo, 70 per agamennone: le ossa extra sono il mantello) e animazioni baked. **Non sono ancora usati nel gioco** (vedi sotto).

| Cartella | File Meshy originale | Animazioni |
|---|---|---|
| `agamennone` | Agamemnon Character Concept Art | Attack, Axe_Spin_Attack, Dead, Double_Combo_Attack, Fall_Dead_from_Abdominal_Injury, Left_Slash, Running, Simple_Kick, Sword_Judgment, Triple_Combo_Attack, Vault_and_Land, Walking |
| `perimede` | Bronze Sentinel of Perimede | Combat_Stance, Combat_Idle_Turn_Left, Dead, dying_backwards, Double/Triple_Combo_Attack, Weapon_Combo(_1,_2), Running, Walking |
| `troiano_1` | Deiphobus Trojan Warrior **(1)** | Attack, Basic_Jump, Double/Triple_Combo_Attack, Simple_Kick, Run_03, dying_backwards, Fall_Dead..., Running, Walking |
| `troiano_2` | Deiphobus Trojan Warrior | come troiano_1 + Axe_Spin_Attack, walking_2 |
| `euribate` | Eurybates Character Study | Left_Slash, Stand_Up4-7, dying_backwards, Fall_Dead..., Running, Walking |
| `euriloco` | Eurylochus Character Concept | Attack, Axe_Spin_Attack, Combat_Stance, Heavy_Hammer_Swing, Sega(_2), cariche, corse, 15 in tutto |
| `menelao` | Menelaus Character Concept Art | Attack, Axe_Spin_Attack, Basic_Jump, Combat_Stance, Dead, Double/Triple_Combo_Attack, Simple_Kick, Fall_Dead..., Running, Walking |
| `troiano_arciere` | Pandarus the Trojan Archer | Archery_Shot(_1), Double_Combo_Attack, dying_backwards, Fall_Dead..., Running, Walking |
| `elpenore` | The One Eyed Legionary | Attack, Double/Triple_Combo_Attack, dying_backwards, Fall_Dead..., Running, Walking |
| `troiano_capitano` | Trojan Captain Concept Sheet | Combat_Stance, Dead, Double/Triple_Combo_Attack, Simple_Kick, Sword_Parry_Backward, dying_backwards, Fall_Dead..., Running, Walking |
| `troiano_fanteria` | Trojan Foot Soldier Concept Art | Combat_Stance, Dead, Weapon_Combo(_1,_2), dying_backwards, Running, Walking |
| `filotete` | Wounded Hoplite Character Study (senza "(1)", 36 ossa) | Arise, Axe_Spin_Attack, Dead, Double_Combo_Attack, Stand_Up2-4, dying_backwards, Running, Walking |
| `filotete_no_elmo` | Wounded Hoplite Character Study **(1)** (78 ossa, mantello) | Arise, Combat_Stance, Dead, Injured_Walk, Punch_Combo_5, Weapon_Combo, Stand_Up2/4/5, ... |
| `polite` | Wounded Legionary Concept Art | Punch_Combo(_1), Stand_Up3-7, dying_backwards, Fall_Dead..., Running, Walking |
| `ulisse` | ulisse.glb | 17 animazioni (Attack, Block5, Left_Slash, corse, salti, arrampicata...) |

Abbinamenti: tutti certi (similarità istogramma colore base 0.92-0.97 solo con il proprio originale; gli altri < 0.90). Unico punto
da guardare: `troiano_1`/`troiano_2` e `filotete`/`filotete_no_elmo` si distinguono per i file "(1)" (similarità 0.97 vs 0.94 e 0.97 vs 0.89).

## Scudo di Agamennone
Lo scudo (con la testa di Medusa) è fuso nella mesh unica e i pesi Mixamo ne distribuivano i vertici su coscia sinistra, pollice,
mantello e avambraccio: in tutte le animazioni d'attacco si piegava (media 11 cm di deformazione in `Attack`, 8,5 in `Axe_Spin_Attack`,
7 in `Dead`). Ora i suoi 2063 vertici sono legati al 100% a `mixamorig:LeftForeArm`: scudo rigido, deformazione 0.000 in tutte le 12
animazioni (misurata con Kabsch). Nelle pose estreme può compenetrare un poco il busto. Gli altri 14 modelli non hanno scudo.

## Rigenerare
`blender -b --factory-startup -P _source/scripts/build_animati.py -- ~/Scaricati/MODELLI_ANIMATI assets/models/custom/personaggi_animati [nome ...]`
poi `python3 _source/scripts/tune_imports.py personaggi_animati` (VRAM compressed + mipmap). Texture 1K JPEG, scala 0,8, nessun LOD.

## Uso nel gioco
Questi file (rig Mixamo a 66 ossa, clip baked) non sono usati direttamente: il gioco legge le 17 ossa. Le stesse mesh, con lo skinning
Mixamo portato sul rig a 17 ossa, sono in `personaggi_nuovi/` (vedi il suo README, `_source/scripts/build_char_mixamo.py`). Qui restano
i clip Mixamo originali (Combat_Stance, Weapon_Combo, Dead...) per un eventuale uso futuro (retarget).
