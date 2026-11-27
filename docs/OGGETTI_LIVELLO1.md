# Oggetti del livello 1: cosa è nella scena e cosa è generato

Perché alcuni oggetti si vedevano nel gioco ma non nell'editor su `scenes/levels/level1/level1.tscn`:
un nodo `PropsPolyhaven` (script `scripts/props/polyhaven_props.gd`) leggeva
`data/props/level1_polyhaven.json` e **creava all'avvio** casse, botti, forziere, alberi, rocce,
tronco caduto, secchio, sgabello, topo e molo. Quei nodi non avevano un `owner`, quindi non venivano
salvati nella scena e nell'editor non esistevano. Altri oggetti sono costruiti a runtime per motivi
validi (vedi sotto).

## Oggetti ora nella scena (si spostano nell'editor)

I 22 oggetti solidi dell'ex JSON sono nodi `GridProp` veri, con il loro transform:

| Gruppo (`Scenario/…`) | Contenuto |
|---|---|
| `Vegetazione` | AbeteOvest1-3, AlberoEst1-2 (gruppo `tree`, tronco sottile, chioma che sfuma) |
| `Rocce` | RoccioneRilievo1-3, MassoPianura1-3 |
| `CampoProps` | TroncoCaduto, BotteCampo1-2, CassaCampo1-2, ForzierePorta, SecchioCampo, SgabelloCampo, RattoCampo |
| `Molo` | MoloMare1-2 |

- Posizione, rotazione, `fit_size`, impronta (`footprint`), `trunk_radius`, `vault_mode` e `climb_mode`
  sono quelli che prima calcolava `PolyhavenProps`. L'altezza Y è già quella del terreno (meno `sink`).
- Gli alberi pesanti (`fir_tree_01_c`, `island_tree_01/02`) e il forziere usano `lazy_model_path`
  (modello pieno solo ad alta qualità) e `low_quality_model` (versione leggera sotto): le texture di
  ciò che non si vede non finiscono in VRAM, come prima.
- Si possono spostare, ruotare, duplicare, cancellare. **Cancellare un nodo lo elimina davvero**:
  il file JSON non viene più letto per gli oggetti solidi (la chiave `items` è vuota, il registro
  originale è in `items_in_scene`).
- Anche se un nome del JSON fosse ancora presente (livello 2, o JSON vecchio), `PolyhavenProps`
  salta gli oggetti che trova già nella scena con lo stesso nome (niente duplicati).
- Gli oggetti a terra con nome o modello `crate`, `barrel`, `bucket`, `chest` ricevono da
  `LevelAtmosphere` la solita piccola inclinazione e infossatura casuale (pochi centimetri, meno di
  0,1°), come tutte le altre casse e botti del campo.

## Oggetti già in scena prima di questo lavoro

Tende, falò, torce, recinti, casse, botti, giare, carri, navi, scudi, lance, alberi del campo,
mura, torri, porta di Troia, difese sulle mura, ecc. erano già nodi della scena (`Scenario/Accampamento`,
`Pianura`, `DavantiAlleMura`, `PostazioneTroiana`, `Navi`, `MuraDiTroia`, `Decorazioni`, `Unita`).

## Resta generato a runtime (volutamente)

Per ognuno si dice dove si regolano i parametri.

| Cosa | Script | Parametri e seed |
|---|---|---|
| Fiori gialli, ciuffi alti, felci, pervinche, cespugli (MultiMesh) | `polyhaven_props.gd` | **Inspector del nodo `PropsPolyhaven` → `Scatter Defs`** (5 risorse `PolyhavenScatterDef`: `ids`, `rect`, `count`, altezza min/max, `random_seed`, `cast_shadows`, `use_mask`, `min_grass`). Se `Scatter Defs` è vuoto valgono gli `scatters` del JSON. |
| Alberi e cespugli delle `Decorazioni` | `prop_scatter.gd` | Esportati sul nodo (`area_size`, `count`, `random_seed`, `exclude_rects`, `fit_size`) |
| Erba mossa e cespugli d'erba | `grass_field.gd` (nodi `ErbaMossa`, `Cespugli`) | Esportati (`count`, `random_seed`, `area_size`, colori, vento) |
| Erba a ciuffi fotorealistica | `grass_cards.gd` (`ErbaFotorealistica`) | Esportati (`random_seed`, densità, altezze) |
| Lastre di pietra di strade e piazzali | `stone_scatter.gd` | Esportati sui nodi `Lastrico…` e `Piazzale…` |
| Radici e blocchi ai lati del diorama | `block_sides.gd` (`LatiBlocco`) | Esportati |
| Rilievo, pareti, erba del rilievo | `terrain_relief.gd` (`Rilievo`) | Mappa del rilievo nello script/risorsa |
| Strada di terra | `dirt_road.gd` (`StradaTerra`) | Esportati |
| Pezzi della porta e delle portine | `troy_gate.gd` | Esportati sui nodi `PortaTroia`, `PortinaTorre1-5` |
| Frecce conficcate, fumo, polvere, meteo, notte | `battle_atmosphere.gd`, `smoke_columns.gd`, `weather_fx.gd`, `night_cycle.gd` | Esportati sui rispettivi nodi |
| Unione di oggetti uguali in un solo MultiMesh | `prop_batcher.gd` (`UnioneOggetti`) | Automatico (draw call) |
| Soldati troiani delle ondate, feriti, barca del traghetto, passerella | `level_director.gd`, `ferry_system.gd`, `unit_factory.gd` | Dinamici (celle libere, ondate): punti e numeri in `LevelRules` (`spawn_points`, `wounded_points`, …). Non sono oggetti fissi e non sono toccati. |
| Fiamme delle torce, luci di mura e soldati, ombre di contatto | `level_atmosphere.gd` | Si ricavano dai nodi in scena |

## Strumenti di verifica

- `tests/tools/dump_level_objects.gd`: elenca mesh, MultiMesh, caselle bloccate e, uno per uno, i 22
  oggetti (posizione, riquadro, impronta, collisioni). Due esecuzioni si confrontano con `diff`.
  `godot --headless --path . -s res://tests/tools/dump_level_objects.gd -- out.txt`
- `tests/tools/list_runtime_nodes.gd`: elenca i nodi creati a runtime (senza owner).
- `tests/tools/bake_polyhaven_items.gd`: ricalcola i valori da salvare nei nodi a partire da
  `items_in_scene` (serve solo se si aggiungono altri oggetti al JSON).
