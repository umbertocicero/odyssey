# Catalogo modelli da integrare in futuro

Inventario dei modelli forniti da Umberto in `~/Scaricati/MODELLI` (26/11/2026).
**Nessun file è stato copiato negli assets** e nulla è integrato nel gioco: questo è solo un catalogo per decidere dopo.
I file originali non sono stati modificati. Misure fatte aprendo i `.blend` in Blender in background (uno alla volta).

## Riepilogo

Sono 5 file `.blend`, salvati con Blender 4.4, circa 556 MB in tutto. Sono tutti **personaggi mitologici dell'Odissea, statici, in alta risoluzione**, della stessa serie (stessa struttura, stessa altezza di ~1,9 m).

| File | Personaggio | Dimensione file | Triangoli | Vertici | Ingombro (m, X×Y×Z) |
|---|---|---|---|---|---|
| `Calipso.blend` | Calipso, ninfa | 84 MB | 880.452 | 440.098 | 0,67 × 0,72 × 1,90 |
| `Circe.blend` | Circe, maga | 97 MB | 1.026.574 | 513.176 | 0,72 × 0,87 × 1,90 |
| `Cyclops.blend` | Polifemo, ciclope | 90 MB | 959.597 | 479.277 | 0,78 × 0,46 × 1,90 |
| `Siren.blend` | Sirena (versione 1) | 158 MB | 1.730.429 | 865.111 | 0,77 × 0,92 × 1,90 |
| `Siren_2.blend` | Sirena (versione 2) | 154 MB | 1.675.227 | 837.566 | 0,76 × 0,93 × 1,89 |

Struttura identica in tutti i file:

- 1 solo oggetto mesh (`Mesh_0`), senza modificatori, senza gerarchia, senza collezioni.
- 1 solo materiale (`Material_0`), Principled BSDF con 3 texture **2048×2048 impacchettate nel .blend**: `Image_0` colore (sRGB), `Image_1` metallic/roughness (canale blu = metallic, verde = roughness, formato glTF), `Image_2` normal map.
- 1 solo set UV. Nessuno scheletro, nessuna animazione, nessun vertex group, nessuno shape key.
- Unità in metri, scala 1.

## Aggiornamento: GLB ritopologizzati ~30k (26/11/2026, 19:58)

Umberto ha riesportato da Meshy i 5 modelli con Remesh. I `.glb` precedenti da ~1M triangoli sono stati sostituiti (stessi nomi file). Misurati leggendo l'intestazione glTF, senza aprire Blender.

| File | Dimensione | Triangoli | Vertici | Altezza | Ingombro X × Z | Texture |
|---|---|---|---|---|---|---|
| `calipso.glb` | 13,8 MB | 30.774 | 41.804 | 1,90 m | 0,67 × 0,72 | 3 PNG 2048 |
| `circe.glb` | 13,0 MB | 30.510 | 40.387 | 1,90 m | 0,68 × 0,66 | 3 PNG 2048 |
| `Cyclops.glb` | 13,2 MB | 30.530 | 39.480 | 1,90 m | 0,78 × 0,46 | 3 PNG 2048 |
| `Siren.glb` | 15,8 MB | 31.008 | 46.721 | 1,90 m | 0,77 × 0,92 | 3 PNG 2048 |
| `Siren2.glb` | 15,8 MB | 31.016 | 46.697 | 1,90 m | 0,76 × 0,93 | 3 PNG 2048 |

Le 3 texture sono colore, metallic/roughness e normal. Una sola mesh e un solo materiale (doppia faccia attiva) per file. Nessuno scheletro, nessuna animazione, nessun LOD.

**Nomi delle sirene:** ora coincidono con i `.blend` (`Siren.glb` = `Siren.blend`, ingombro Z 0,92; `Siren2.glb` = `Siren_2.blend`, ingombro Z 0,93). Le due sono molto simili tra loro, da guardare a occhio per scegliere.

**Pronti per Godot? Quasi, come modelli statici.**
- Sì: ~30k triangoli (circa il doppio del budget alto dei nostri personaggi, ma gestibile per 1-3 personaggi in scena), texture 2048, formato GLB importabile direttamente.
- **Origine al centro, non ai piedi:** la mesh va da -0,95 a +0,95 in altezza (centro del corpo). Per la convenzione del progetto (origine ai piedi) va traslata di +0,95 m, oppure si mette il nodo a Y = -0,95 in scena.
- **Nessun LOD:** per più comparse o mobile ne serve uno a ~8-10k triangoli (`_lod`).
- **Nessun rig:** sono ferme. Per camminare o parlare serve scheletro compatibile con `HumanoidAnims` (rig automatico di Meshy o rig nostro); restano pose fisse (scena/statua/cutscene) altrimenti.
- Cyclops è alto 1,9 m come gli altri: per Polifemo va riscalato (3-4 m o più).
- Texture PNG 2048 ×3 per modello = circa 11-14 MB di texture compressa ciascuna: in Godot vanno compresse (VRAM) e armonizzate con la palette di `STYLE.md`.
- Licenza ancora da chiarire (vedi sotto).

## Aggiornamento 27/11/2026: cavallo di Troia, personaggi animati, oggetti

Cinque file nuovi in `~/Scaricati/MODELLI`, tutti GLB di Meshy. Misure lette dall'intestazione glTF (nessun Blender). Assi glTF: Y è l'altezza.

| File | Peso | Triangoli | Dimensioni L × H × P (m) | Origine | Texture | Rig | Animazioni |
|---|---|---|---|---|---|---|---|
| `Meshy_AI_Trojan_Horse_Design_Sheet_20261127_texture.glb` | 13,3 MB | 29.270 | 0,82 × 1,66 × 1,67 | centro (Y da -0,84 a +0,82) | 3 × 2048 (colore, metal/rough, normal) | no | no |
| `Epeus.glb` | 13,8 MB | 30.540 | 0,77 × 1,64 × 0,50 | ai piedi | 3 × 2048 | sì, 69 ossa Mixamo | 7 |
| `carpentiere.glb` | 13,0 MB | 31.082 | 0,82 × 1,65 × 0,35 | ai piedi | 3 × 2048 | sì, 66 ossa Mixamo | 6 |
| `Meshy_AI_Oak_Plank_20261127_texture.glb` | 6,1 MB | 14.696 | 1,90 × 0,03 × 0,61 | centro | 3 × 2048 | no | no |
| `Meshy_AI_Ancient_Root_Crown_20261126_generate.glb` | 37,8 MB | 1.574.652 | 1,90 × 0,66 × 1,44 | centro | **nessuna** (solo geometria, senza UV) | no | no |

### Cavallo di Troia
Pezzo unico: 1 mesh, 1 materiale, nessuna gerarchia, 29k triangoli. È grande come una persona (1,66 m di altezza), mentre nel gioco serve molto più grande (indicativamente 6-9 m): va riscalato di 4-5 volte e va spostata l'origine a livello del suolo.
Per il livello 2 (costruzione o comparsa a pezzi), tre strade:
1. **Rivelazione con shader (consigliata):** un solo mesh, un piano di taglio in coordinate locali che sale dal basso (`discard` oltre una quota, oppure dissolvenza con rumore). Costo quasi zero, nessun lavoro sulla mesh, funziona anche con il piano che sale a scatti per fasi (zoccolo/ruote, zampe, corpo, collo, testa).
2. **Taglio in Blender in 4-6 parti** (ruote/base, zampe, torso, collo, testa, coda): si usa `bisect` sui piani, si chiudono i bordi e si tiene la stessa UV, quindi la stessa texture. Servono ~1-2 ore di pulizia e le parti restano vuote dentro, ma si può far arrivare ogni pezzo con animazione (carpentieri che montano).
3. **Rigenerare per parti in Meshy:** costoso e con stile non coerente tra le parti, sconsigliato.
Per evitare buchi visibili nel taglio meglio fare le parti in modo che si sovrappongano di qualche cm e nascondere le giunture con assi e funi. Il nome del file indica un "design sheet": controllare a occhio che il modello sia un cavallo ligneo completo e non un foglio di riferimento.

### Personaggi animati
- **Epeus** (Epeo, costruttore del cavallo): animazioni `Walking`, `Running`, `Run_03`, `Attack`, `Double_Combo_Attack`, `Triple_Combo_Attack`, `Basic_Jump`. È di fatto un combattente: utile come personaggio non giocante o nemico.
- **Carpentiere**: `Walking`, `Running`, `Sega`, `Heavy_Hammer_Swing`, `Idle_11`, `Idle_12`. Adatto alla scena della costruzione del cavallo (segare, martellare).
- Scheletro con nomi `mixamorig:*` (identico per entrambi, ~66-69 ossa con dita), un solo mesh skinnato di ~30k triangoli. Va verificato se si adatta con il retarget a `HumanoidAnims`; la convenzione delle ossa del progetto è diversa (vedi memoria sulle animazioni).
- Alti 1,64-1,65 m, origine ai piedi (già corretta per Godot, diversamente dai personaggi mitologici).

### Oggetti
- **Oak Plank:** asse di quercia di 1,9 m, ma 14,7k triangoli sono troppi per una tavola piatta (spessore 3 cm): per l'uso in gioco meglio un box con le sue texture (3 × 2048) o decimata a poche centinaia di triangoli. Serve come materiale da cantiere del cavallo.
- **Ancient Root Crown:** 1,57 milioni di triangoli, nessuna texture e nessuna UV: è una mesh "generate" non rifinita. **Non utilizzabile così**; servirebbero retopologia e texture. Uso non chiaro: va chiesto a Umberto.

### Altri oggetti (scansione delle 09:34)

Tutti GLB di Meshy, una mesh, nessun rig né animazioni, 3 texture 2048 (colore, metal/rough, normal), origine al centro. Quasi tutti sono scalati a ~1,9 m sul lato lungo, quindi la scala reale va decisa in scena.

| File | Peso | Triangoli | L × H × P (m) | Note |
|---|---|---|---|---|
| `Meshy_AI_Rustic_Timber_Bench_...` | 9,7 MB | 8.682 | 1,90 × 0,73 × 0,91 | panca di legno; peso accettabile come prop, usabile così |
| `Meshy_AI_Ancient_Shipwreck_Relic_...` | 12,5 MB | 30.264 | 1,89 × 0,60 × 0,66 | relitto/frammento di nave; 30k tris sono tanti per un prop, meglio decimare a ~8-10k |
| `Meshy_AI_Aged_Timber_Beam_...` | 14,1 MB | **237.984** | 1,91 × 0,34 × 0,31 | trave di legno: troppo pesante, un cubo allungato con la texture basta; decimare a poche centinaia |
| `Meshy_AI_Stacked_Timber_Beams_...` | 6,4 MB | 1.776 | 1,90 × 0,15 × 0,31 | travi impilate; leggero, **usabile così** come prop del cantiere |
| `Meshy_AI_Aged_Timber_Beam_..._remesh_tri.glb` | 9,5 MB | 2.424 | 1,91 × 0,34 × 0,31 | **versione leggera della trave da 238k, usabile così** (09:39); sostituisce l'originale pesante |

Usi possibili: panca e trave per il cantiere del cavallo (livello 2), relitto per spiagge e scene di naufragio.

## Aggiornamento 27/11/2026 (pomeriggio): `MODELLI_ANIMATI` e Polifemo

Nuova cartella `~/Scaricati/MODELLI_ANIMATI` con 17 GLB di personaggi **già animati** (misure dall'intestazione glTF, senza Blender). Tutti: 1 mesh skinnata di ~30,2-30,8k triangoli, 1 materiale, 3 texture 2048, altezza a riposo 1,70-1,76 m, origine ai piedi (Y = 0, già giusta per Godot), scheletro Mixamo di 66 ossa (con dita) e animazioni incluse, 16-23 MB a file.

### Polifemo (`polifemo.glb`, 14:33)
- 30.530 triangoli, 16,9 MB, 3 texture 2048, altezza 1,70 m, larghezza 0,70 m (braccia lungo i fianchi), origine ai piedi.
- Scheletro Mixamo a 66 ossa, 9 animazioni: `Walking`, `Running`, `Slow_Orc_Walk`, `Unsteady_Walk` (camminata incerta, utile per Polifemo ubriaco), `Boxing_Guard_Right_Straight_Kick`, `Right_Hand_Sword_Slash`, `Shield_Push_Left`, `Shot_and_Slow_Fall_Backward`, `Strangled_and_Fall_Forward` (caduta in avanti).
- **Scala:** alto 1,70 m come un uomo, quindi per il livello della grotta **va scalato a 3-4 m** (scala 2,0-2,4 sul nodo; il rig e le animazioni scalano insieme). Non integrato: da fare quando si costruisce il livello.
- Attenzione: alcune animazioni (spada, scudo) non c'entrano con un ciclope che usa un tronco; per un combattimento servirà sceglierne altre o aggiungerle da Mixamo.

### Altri personaggi animati nella cartella

| File (abbreviato) | Triangoli | Ossa | Animazioni |
|---|---|---|---|
| `ulisse.glb` | 30.632 | 66 | 17 (corsa, salto, scalata, torcia, colpi di ascia, blocco) |
| `agamennone (1).glb` | 30.264 | 66 | 14 (combattimento, morte, calci) |
| `polifemo.glb` | 30.530 | 66 | 9 |
| Meshy_AI_Agamemnon_Character_Concept_Art | 30.552 | 70 | 12 |
| Meshy_AI_Menelaus_Character_Concept_Art | 30.396 | 66 | 11 |
| Meshy_AI_Eurylochus_Character_Concept | 30.528 | 66 | 15 |
| Meshy_AI_Eurybates_Character_Study | 30.497 | 66 | 9 |
| Meshy_AI_Bronze_Sentinel_of_Perimede (Perimede) | 30.366 | **36** | 11 |
| Meshy_AI_Deiphobus_Trojan_Warrior (2 versioni) | 30.557 / 30.604 | 66 | 11 / 10 |
| Meshy_AI_Pandarus_the_Trojan_Archer | 30.473 | 66 | 7 |
| Meshy_AI_Trojan_Captain_Concept_Sheet | 30.231 | 66 | 10 |
| Meshy_AI_Trojan_Foot_Soldier_Concept_Art | 30.420 | 66 | 8 |
| Meshy_AI_The_One_Eyed_Legionary | 30.460 | 66 | 7 |
| Meshy_AI_Wounded_Legionary_Concept_Art | 30.495 | 66 | 10 |
| Meshy_AI_Wounded_Hoplite_Character_Study (2 versioni) | 30.640 / 30.847 | **36** / **78** | 10 / 13 |

Osservazioni:
- Gli scheletri **non sono tutti uguali**: 66 ossa è lo standard Mixamo con dita, ma Perimede e un Wounded Hoplite hanno 36 ossa, un altro Wounded Hoplite 78 e Agamemnon 70. Il retarget su `HumanoidAnims` (che usa un rig a 17 ossa, vedi memoria `mixamo-17bone-characters`) va quindi verificato modello per modello.
- Le animazioni sono incorporate in ogni file con nomi Mixamo: stesse clip in file diversi, quindi duplicate. Per risparmiare, conviene tenerle in una sola libreria e separare le mesh.
- 17 file × ~30k triangoli: per più personaggi insieme in scena serve comunque un LOD.
- Ci sono due versioni di Deiphobus e di Wounded Hoplite: decidere quale tenere.
- I nomi mostrano chiaramente Meshy + Mixamo: licenze come sopra, da verificare.

## Come sono stati prodotti (dedotto, da verificare)

I nomi generici (`Mesh_0`, `Material_0`, `Image_0..2`), la mesh da quasi 1 milione di triangoli e la pipeline texture metallic-roughness fanno pensare a un export glTF di un generatore 3D da immagine/testo (tipo Meshy, Tripo, Hunyuan3D o simili), poi importato in Blender. **Nei file non c'è nessuna informazione su autore, fonte o licenza.** Serve chiederlo a Umberto (vedi sezione Licenze).

## Uso possibile in Odyssey

- **Cyclops (Polifemo)**: boss o scena della grotta (libro IX). Ingombro 1,9 m come gli altri: va riscalato (Polifemo deve essere gigante, ~3-4 m o più rispetto a Ulisse).
- **Circe**: scena dell'isola di Eea, personaggio non giocante per dialogo (libro X). Ha l'ingombro più largo (0,87 m in Y, probabilmente vesti o pose aperte).
- **Calipso**: isola di Ogigia (libro V), personaggio non giocante di dialogo.
- **Siren / Siren_2**: sirene (libro XII), due varianti da scegliere o usare entrambe per due sirene diverse.

## Cosa serve prima di usarli nel gioco (riferito ai `.blend` da 1M triangoli; per i GLB da ~30k vedi aggiornamento sopra)

Tutti i modelli hanno ~1 milione di triangoli, **100-1000 volte il budget** dei nostri personaggi (che sono pochi migliaia di triangoli). Non sono usabili così in Godot, soprattutto su PC debole e mobile. Passi necessari per ogni modello:

1. **Retopologia/decimazione** a circa 8-20k triangoli (LOD alto) e ~3-5k (LOD basso), seguendo le convenzioni di `assets/models/custom/README.md` (origine ai piedi, `_lod`).
2. **Bake** del dettaglio della mesh originale in normal map e texture sulla versione ridotta, con UV pulite.
3. **Rig e animazioni**: i modelli sono statici. Per camminare/parlare serve uno scheletro compatibile con `HumanoidAnims` (vedi memoria sul sistema animazioni), oppure restano pose fisse (scena/statua/cutscene), che costa molto meno.
4. **Stile**: texture da armonizzare con la palette smorzata e il tramonto dorato di Odyssey (`STYLE.md`).
5. Peso nel repo: i `.blend` originali (556 MB) non vanno nel git. Tenere fuori dal repo i sorgenti e committare solo i `.glb` ridotti.

Per l'uso come comparsa lontana o statua nel paesaggio basterebbe una decimazione forte senza rig.

## Licenze e fonti

Non verificabili dai file. Vedi [CREDITI.md](CREDITI.md): i cinque modelli sono registrati lì come **fonte e licenza da verificare**. Se provengono da un generatore AI, controllare i termini del servizio (uso commerciale, piano gratuito o a pagamento); se da un marketplace, serve la licenza di redistribuzione. Fino a quel momento non vanno distribuiti pubblicamente né committati.

## Domande aperte per Umberto

1. Da dove vengono i modelli (generatore AI, quale servizio e piano; oppure acquisto/download) e con che licenza?
2. Quali personaggi servono davvero e per quale scena? Per ciascuno: statico (statua/cutscene) o animato (rig completo)?
3. Per le sirene, tenere una sola versione o entrambe?
