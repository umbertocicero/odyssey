# Integrazione dei modelli Poly Haven

Registro dell'integrazione dei modelli di `assets/models/custom/polyhaven/` (CC0, vedi README e CATALOGO.md di quella cartella) nei livelli. Testi di gioco sempre in inglese; questo documento è di lavoro.

## Come funziona

| Pezzo | File |
|---|---|
| Catalogo (id, percorso, ruolo, triangoli, qualità minima) | `scripts/props/polyhaven_catalog.gd` |
| Costruttore dei props (solidi come `GridProp`, sparsi come MultiMesh) | `scripts/props/polyhaven_props.gd` |
| Placement livello 1 / livello 2 (dati) | `data/props/level1_polyhaven.json`, `data/props/level2_polyhaven.json` |
| Scene da istanziare | `scenes/levels/level1/props_polyhaven.tscn`, `scenes/levels/level2/props_polyhaven.tscn` |
| Test headless | `tests/test_polyhaven_props.gd` |
| Screenshot e prestazioni | `tests/tools/shot_polyhaven.gd`, `tests/tools/perf_polyhaven.gd`, `tests/tools/dump_level_map.gd` |

- **Alberi**: `GridProp` nel gruppo `tree`: il fusto blocca solo un cerchio sottile, la chioma si attraversa e diventa semitrasparente al passaggio di Ulisse.
- **Rocce**: `GridProp` affondato nel terreno (`sink`), scavalcabili se alte meno di 1,1 m; i massi grandi a ridosso dei gradini del rilievo.
- **Piante, fiori, ciuffi**: MultiMesh per variante, senza ombre, solo dove la maschera dell'erba (`GrassMask`) lo permette e fuori dalle caselle bloccate.
- **Fogliame**: gli albedo originali sono molto scuri (~RGB 24/22/8). `foliage_gain` (5,5 / 12 / 6, in lineare) schiarisce i materiali alpha-cutout di alberi e arbusti senza toccare i file.
- **Qualità**: ogni modello ha una `min_quality` (0 web, 1 mobile, 2 PC); un oggetto pesante può avere un `fallback` leggero; i conteggi degli sparsi si moltiplicano per `Quality.density()` (0,35 / 0,7 / 1).
- **Istanziazione**: il nodo va messo **prima di `Griglia`** nel livello (così la griglia registra gli ostacoli). Non è ancora stato aggiunto a `level1.tscn`: serve una sola riga, da concordare.

## Livello 1: pianura di Troia (22 oggetti solidi + 5 gruppi sparsi)

| Gruppo | Modelli | Dove / uso | Triangoli |
|---|---|---|---|
| Abeti | `fir_tree_01_c` (fallback `fir_sapling_medium_a`), `fir_sapling_medium_b/c` | Rilievo ovest, 3 esemplari alti 4–6,5 m | 24k + 8,8k + 8,4k |
| Alberelli | `island_tree_01/02` (fallback abete) | Margine est, 2 esemplari da primo piano; solo qualità alta | 42,6k + 35,5k |
| Rocce | `namaqualand_boulder_02/03`, `boulder_01` | Incastonate ai gradini del rilievo ovest (3) e sparse in pianura (3), sink 0,1–0,35 m | 3,5–4k l'una |
| Tronco | `dead_tree_trunk_02` | Pianura, vicino al muretto, lungo 3,2 m | 4,5k |
| Campo | `wooden_barrel_01/02`, `wooden_crate_01`, `wooden_bucket_02`, `wooden_stool_02`, `street_rat` | Accampamento, vicino alle tende | 3–4k l'uno |
| Forziere | `treasure_chest` (fallback cassa) | Piazzale della porta, punto di interazione | 9k |
| Molo | `pier_section_01/02` | Sul mare a ovest (2 sezioni, da verificare in scena) | 7k l'una |
| Fiori | celidonia, tarassaco | 180 istanze, 0,22–0,34 m | 150–320 |
| Ciuffi | `grass_medium_01/02` | 320 istanze | 120–1.200 |
| Felci, pervinche | `fern_02`, `periwinkle_plant` | 36 + 45 istanze | 600–2.400 |
| Cespugli | `othonna_cerarioides`, `searsia_lucida` | 14 istanze; non a qualità bassa | 5k–14k |

Non usati nel livello 1: mura e porta del forte (stile europeo, 8,5 m), `namaqualand_cliff_02` (riservata al livello 2 e alla cresta), tutto ciò che è in `*_fuori_epoca/`.

Totali a qualità alta: 22 solidi ≈ 193k triangoli, 595 sparsi ≈ 395k.

## Livello 2: il dono del mare (solo preparato)

Dati e scena pronti, **non istanziati** (il livello 2 non ha ancora il suo diorama). Contiene: cantiere sulla piattaforma `coast_land_rocks_04` con casse, botti, secchio, due scale, ascia, sega, martello, pialla, vanga e piccone; 6 tronchi spiaggiati; 4 abeti sullo sperone nord-ovest; scogliera `namaqualand_cliff_02` e scogli `coast_rocks_05` a ovest; molo; sparsi per dune, sottobosco, prato e fiori. I 2 materiali costieri (`terreno_costa/`) non sono usati: servono agli strati del terreno, che non è in questo ambito. Posizioni indicative, da rifinire sul terreno vero.

## Prestazioni (GTX 860M, 1280x720, vsync off, livello 1 con i props istanziati)

| Qualità | Frame medio | Primitive | Draw call | VRAM |
|---|---|---|---|---|
| Alta | 15,3 ms (65 FPS) | 585k | 605 | 199 MB |
| Media | 9,3 ms (108 FPS) | 404k | 446 | 168 MB |
| Bassa | 9,1 ms (110 FPS) | 347k | 333 | 150 MB |

Prima dei props (misura del primo giro): ~385k primitive e 117 MB di VRAM a qualità alta. Le misure sono rumorose perché l'altro agente modifica il livello in parallelo: contano gli ordini di grandezza. Budget nei test (`tests/test_polyhaven_props.gd`): 650k / 360k / 170k triangoli di soli props per alta / media / bassa.

## Stato

- `props_polyhaven.tscn` è istanziato in `level1.tscn` prima di `Griglia`. Test verdi: `test_polyhaven_props`, `test_relief`, `test_gameplay`, `test_grid_movement`, `test_vault`, `test_wall_combat`.
- JPEG con profilo ICC rigenerati dall'agente Blender: import a 0 errori. Per le texture future lanciare `compress_textures.py` dopo ogni importazione.
- Livello 2: dati e scena pronti, non istanziati.

## Note

1. **Livello 2** da istanziare quando avrà il diorama; posizioni da rifinire.
2. Il trapano a manovella e la pialla hanno forma moderna: usarli con parsimonia.
