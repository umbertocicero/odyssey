# Modelli da Sketchfab

Tre modelli arrivati da `~/Scaricati/new3` come file `.glb` con nome a hash (`4a8c1e43…glb`, `50fd926f…glb`, `832d4c43…glb`), tipici dei download di Sketchfab.

## Licenze e autori

Arrivano da `~/Scaricati/new3` e `~/Scaricati/new4` (non Poly Haven). **I crediti CC-BY vanno nel gioco**: testi pronti in [`CREDITI.md`](CREDITI.md).

| Modello | Autore | Licenza | Pagina d'origine |
|---|---|---|---|
| `tende/tenda_sketchfab_gajk` | Gajk.Mv | **CC-BY-4.0** | [Sketchfab](https://sketchfab.com/3d-models/tent-fa46028e8d3849399ba5271df07ed99c) |
| `navi/pentecontera_greca` | Thales | **CC-BY-4.0** | [Sketchfab](https://sketchfab.com/3d-models/greek-penteconter-50-oared-monoreme-stormworks-41777109ea814be48fb0e2b2a22af0b6) |
| `rovine/rilievo_tempio_pietra` | ScanForgeFAB | **CC-BY-4.0** | [Sketchfab](https://sketchfab.com/3d-models/ancient-stone-temple-relief-photogrammetry-free-18e4293c232246e78bf3e88d9a3501c6) |
| `architettura/edificio_greco_bouleuterion` | ? | **da verificare** | ? |
| `architettura/colonna_corinzia_frammento` | ? | **da verificare** | ? |
| `rovine/rovina_arco_muschio` | ? | **da verificare** | ? |
| `rovine/testa_statua_barbuta` | ? | **da verificare** | ? |
| `animali/cavallo_lowpoly_marrone` | ? | **da verificare** | ? |
| `fuori_epoca/nave_asiatica_torri` | ? | **da verificare** | ? |

I modelli con `?` sono GLB Sketchfab senza `license.txt` e con i metadati tolti da glTF-Transform: né autore né licenza (CC0, CC-BY, o NC che vieta l'uso commerciale). Finché Umberto non conferma le pagine d'origine, **solo prototipi interni, da non pubblicare**.

### Non utilizzabili o non convertiti

**Ritocco di colore della tenda (20/11/2026):** `_source/scripts/grade_gajk_tent.py` rimappa la luminosità delle texture originali sulla palette sabbia/ocra/legno scuro (pieghe e dettagli restano); `tenda_gajk_decorata.py` aggiunge rami e pelli. Opera derivata: il credito CC-BY resta (`CREDITI.md`).

**new5 (20/11/2026):** `tent.zip` convertito (vedi sopra). Gli altri tre sono tre copie della stessa tenda in formati non apribili qui: `19428_open3dmodel.zip` contiene un file **3ds Max `.max`** (formato proprietario, Blender non lo legge) e tre texture TGA, nessuna licenza; `200333_open3dmodel.com.rar` e `cadnav-1FG21I427.rar` sono **RAR5 non estraibili** (come sopra), con un `tent.FBX` e un `.max`. Nessuno ha file di licenza (siti open3dmodel e cadnav): licenza da verificare.


| File (in `Scaricati/new3`, `new4`) | Motivo |
|---|---|
| `Unconfirmed 241285.crdownload` (new3) | download interrotto (825 KB, un `.blend` troncato): va riscaricato |
| `Greek+Doric+Column.rar` (new4) | **non estraibile qui** (correzione: prima l'avevo scritto "incompleto", ed era sbagliato): è un RAR5 (metodo m5) e il 7z installato risponde «Unsupported Method», i file escono a 0 byte. Contiene `.obj`, `.fbx`, `.3ds`, `.max` e texture TIFF della colonna dorica. Servono `unrar` oppure un riarchiviamento in `.zip`/`.7z` |
| `ICQIQYIC26VJNC5KK64ZPHAZP_gltf.zip` | contiene anche un `.exe`: **non aperto né eseguito**; il glTF è stato convertito, il file eseguibile ignorato |
| `Trireme V2.zip` e `Trireme V2.3dm` (1,2 GB OBJ, 311 MB Rhino) | OBJ da 1,2 GB: caricarlo in Blender con la RAM disponibile rischia di bloccare il PC (già successo); il `.3dm` è un formato Rhino che Blender non legge. Da ridurre altrove o con un OBJ più leggero |
| `Low polygon mesh.zip` (4,8 GB di OBJ) | stesso motivo |
| `umanosehorseback-sea-cave.zip` | 1,3 milioni di triangoli e texture 8K da 117 × 140 m: serve un bake, non una decimazione |
| `peak_cliff_mountain_rock.zip` (Metazeon, CC-BY-4.0) | 991.000 triangoli, texture 8K, 212 × 212 × 264 m: stesso motivo |
| `ocean_wave*.zip` (Andrea Marziano, CC-BY-4.0) | superficie da 80.000 triangoli e 205 m: non utile così; per l'acqua serve uno shader |
| `herculaneum_boat_-_roman_boat.zip` (Opus Poly, CC-BY-4.0) | gerarchia FBX con unità mescolate (scafo 8 m, parti a 100×): l'insieme risulta alto 317 m. Da sistemare a mano in Blender |
| `ancient-temple.zip` | un `temple01.blend` modulare con texture trim sheet: non analizzato (nessun file di licenza) |
| `ship_OBJ.zip` + `ship_textures.zip` | nave in OBJ da 39.000 triangoli e 4,6 m, con 3 materiali PBR a parte: non convertita |
| `94a8ba5997b646dcb6647a600e0ed4cd_gltf.zip` | glTF **1.0**, formato obsoleto che Blender 5.3 non legge |
| `81d324598a…` (gltf e glb) | scudo Dura-Europos Homeric (romano, 682.000 triangoli, bandiera «NoAI» sulla pagina Sketchfab): non convertito |
| `4a8c1e43…glb` (new4) | identico a quello di new3 (edificio greco già convertito) |

## Contenuto

| File | Cosa | Dimensioni L×P×A (m) | Triangoli | Budget | Livello |
|---|---|---|---|---|---|
| [`architettura/edificio_greco_bouleuterion/`](architettura/edificio_greco_bouleuterion/edificio_greco_bouleuterion.gltf) | Edificio greco (bouleuterion) a due ali con tetti a tegole e portico; 10 materiali PBR | 19,8 × 6,6 × 10,9 | 60.000 | **primo piano, solo PC**, uno per scena | 2 (piazza davanti al tempio, acropoli di Troia); 1 solo come punto di riferimento |
| [`architettura/colonna_corinzia_frammento/`](architettura/colonna_corinzia_frammento/colonna_corinzia_frammento.gltf) | Colonna con base quadrata, fusto e capitello corinzio (scansione) | 1,9 × 2,4 × 3,5 | 61.900 | **primo piano, solo PC**; 1–2 esemplari, sono tanti per una colonna | 1 e 2: rovine e piazza |
| [`rovine/rovina_arco_muschio/`](rovine/rovina_arco_muschio/rovina_arco_muschio.gltf) | Rovina di pietra con arco, gradini e muschio (PBR 4K ridotto a 2K) | 12,0 × 9,6 × 6,1 | 10.000 | standard | 1: rovine ai margini, mura distrutte; 2: difese distrutte («già in rovina», `level2.MD`) |

Anteprime: `../_previews/sketchfab.png` e `../_previews/sketchfab_new4.png`. Origine al centro della base, y = 0, metri; texture JPEG senza profilo ICC.

| [`navi/pentecontera_greca/`](navi/pentecontera_greca/pentecontera_greca.gltf) | Pentecontera greca a 50 remi (dal gioco *Stormworks*), con remi; **senza texture**, solo colori dei materiali | 10,7 × 38,0 × 10,9 | 27.400 | primo piano | 2: navi a riva e in partenza (a scala 38 m è enorme: ridurre a ~1/3 per il diorama) |
| [`rovine/rilievo_tempio_pietra/`](rovine/rilievo_tempio_pietra/rilievo_tempio_pietra.gltf) | Pannello di pietra con rilievo scolpito (scansione, PBR 4K ridotto a 2K) | 1,0 × 0,06 × 0,5 | 20.000 | standard | 1 e 2: parete decorata, rovine |
| [`rovine/testa_statua_barbuta/`](rovine/testa_statua_barbuta/testa_statua_barbuta.gltf) | Testa barbuta di statua in bronzo (scansione); era a scala arbitraria, portata a 0,5 m | 0,46 × 0,47 × 0,5 | 25.000 | primo piano | 1 e 2: decorazione di rovine o piazza |
| [`animali/cavallo_lowpoly_marrone/`](animali/cavallo_lowpoly_marrone/cavallo_lowpoly_marrone.gltf) | Cavallo marrone low poly, texture 4K ridotta a 2K; scala portata a 1,8 m | 0,6 × 2,0 × 1,8 | 9.000 | standard | 1 e 2: cavalli da sfondo (carri, cavalleria). **Non** è il cavallo di legno del livello 2 |
| [`fuori_epoca/nave_asiatica_torri/`](fuori_epoca/nave_asiatica_torri/nave_asiatica_torri.gltf) | Grande nave con torri e remi di tipo asiatico | 2,5 × 0,8 × 1,4 | 15.900 | standard | **non usare** (fuori epoca e fuori stile) |

| [`tende/tenda_sketchfab_gajk/`](tende/tenda_sketchfab_gajk/tenda_sketchfab_gajk.gltf) | Tenda a falde con pieghe vere e intelaiatura di pali con corde legate (originale in centimetri, riportata a metri); **colori ritoccati** sulla palette del gioco: tela di lino ocra consumata e affumicata, pali di corteccia scura (l'originale era quasi grigia); PBR 2K ridotto a 1K | 4,2 × 2,8 × 2,3 | 9.201 | primo piano | 1 e 2: accampamento, tende degli ufficiali; tela pulita |
| [`tende/tenda_gajk_pelli_rami/`](tende/tenda_gajk_pelli_rami/tenda_gajk_pelli_rami.gltf) | la stessa tenda con **9 rami frondosi e 2 pelli** appoggiati sulle falde (posizionati con raggi sulla superficie vera, secondo `STYLE.md` sez. 5) | 4,6 × 3,0 × 2,4 | 9.541 | primo piano | 1 e 2: tende degli ufficiali e del cantiere, in coppia con `campo/tende` |

## Fuori epoca

Il bouleuterion e il capitello corinzio sono dell'età **classica** (V secolo a.C. in poi), non dell'età del bronzo di Troia: sono coerenti con i modelli greci già presenti (`troia/architettura`: tempio, colonne doriche) ma restano più tardi di Omero. La colonna corinzia in particolare è l'ordine più recente: meglio come rovina in primo piano che come architettura "viva" della città. La rovina a muschio è neutra.

## Note tecniche

- **Edificio**: la decimazione a 24.000 triangoli deformava le texture a piastrelle (tegole sui muri), quindi il budget è 60.000. Usa `KHR_texture_transform`.
- **Colonna**: scansione con topologia sporca. La decimazione di Blender si pianta intorno ai 62.000 triangoli (provati anche saldatura larga, rimagliatura voxel e bake: inservibili). L'originale ne aveva 150.000 e una texture 4K, ridotta a 2K. È esportata **a doppia faccia** perché dopo la decimazione alcune facce hanno l'avvolgimento invertito e restano buchi minuscoli visibili; compare qualche forellino, accettabile a distanza.
- **Colonna, scala**: l'originale era di scala arbitraria (18,8 m di lunghezza): è stata riportata a 3,5 m di altezza.
- **Texture**: i `.glb` avevano texture WebP; sono state ricodificate in JPEG per non dipendere dall'estensione `EXT_texture_webp`. Sono stati rimossi anche i profili ICC (Godot 4.7 li rifiuta).

## Rigenerare

```bash
# copiare i .glb in cartelle separate fuori dal progetto, poi, uno alla volta:
blender -b --factory-startup -P _source/scripts/import_glb.py -- <nome file senza .glb> <percorso>.glb
python3 _source/scripts/compress_textures.py sketchfab      # WebP -> JPEG, senza ICC
```

La configurazione (categoria, nome, budget, texture, riorientamento) è in `CONFIG` dentro `import_glb.py`.
