# Sostituzione dei props poligonali nel livello 1

Dopo (`tests/screenshots/props_after/`) e prima (`tests/screenshots/props_before/`), stesse inquadrature (`tests/screenshot_level1.gd`).

## Oggetto attuale -> sostituto
| Era (low-poly) | Nodi | Ora |
|---|---|---|
| Ulivo `olive_tree_poly` | Ulivo1-3, UlivoNordEst, UlivoOvest | Poly Haven `island_tree_01/02` (36-43k tris, solo a qualità alta; a bassa/media `fir_sapling_medium_b/c` via `GridProp.low_quality_model`); UlivoOvest `fir_sapling_medium_a` |
| Cipresso `cypress_tree_poly` | Cipresso1-3, CipressoOvest1-2 | `fir_sapling_medium_c` (8,4k tris) |
| Alberi sparsi Quaternius (`trees_`, `tree_`) e cipressi sparsi | AlberiEst1/2, AlberiSud, CipressiEst, CipressiCitta | `fir_sapling_medium_a/b/c` in MultiMesh (6+4+6+3+8 esemplari, x densità qualità) |
| Massi e rocce Quaternius | Masso*, Roccia* | `namaqualand_boulder_03/02`, `boulder_01` |
| Scudi Quaternius | Scudo*, ScudoAcc*, ScudoOvest | `scudo_oplita_bronzo/nero/nero_usurato` (6,1k tris; a bassa/media `stendardi/scudo_acheo`, 244 tris) |
| Tende Quaternius/Kenney | Tenda*, TendaPiccola* | `tenda_padiglione`, `tenda_padiglione_piccola` |
| Stendardi e bandiere Quaternius | Stendardo*, BandieraPorta* | `stendardo_acheo`, `stendardo_troiano` |
| Carro coperto (Konta) | CarroCoperto | `carro_coperto` |
| Botti, casse Quaternius | Botte*, Cassa* | Poly Haven `wooden_barrels_01_barrel01/02`, `wooden_crate_01`, `treasure_chest` (a bassa: cassa) |
| Cespugli Quaternius | Cespuglio* | `othonna_cerarioides_c` (5k; a bassa/media `fern_02_d`), `flower_heliophila_medium` (a bassa `periwinkle_plant_01`); sparsi: `othonna_b`, `heliophila_small`, `celandine_01_a`, `dandelion_01_a` |
| Rastrelliere/lance dritte | Lance1-3, LancePosto1-2 | `rastrelliera_lance` |
| Navi Quaternius e drakkar | Nave1-2, Drakkar1-2 | `trireme`, `pentecontera_greca` (a bassa/media trireme) |

## Mancano modelli dettagliati (non inventati, restano quelli vecchi)
Carri e carretti (CarroRotto1-2, CarroRottoOvest, Carretto, CarrettoPosto), lance singole (Lancia1-4, LanciaAcc*, LanciaATerra*), torce (11), sacchi (4), recinti e palizzate (27), mura, torri e porta (Mura1-5, TorreDiGuardia, TorreDiVedetta, PortaScea, Citta), rovine e colonne Quaternius (RudereMuro*, ColonnaSpezzata*, Mattoni*, Scalini, BaseColonna), archi (Arco, ArcoRomano), anfore/vasi/brocca (già non poligonali, non sostituiti), falò.
Disponibili ma non usati: `rovina_arco_muschio` (arco con muschio, 10k) e `colonna_corinzia_frammento` (62k tris, troppo pesante), `edificio_greco_bouleuterion`, `rilievo_tempio_pietra`, `testa_statua_barbuta`, `cavallo_lowpoly_marrone`, pezzi del forte (8,5 m di altezza, fuori scala), molo modulare. Cambiarli altera passaggi e collisioni: decisione di level design.

## Tecnica
- `GridProp.low_quality_model`: modello più leggero a qualità bassa e media.
- `FoliageTint` (`foliage_gain`): schiarisce il fogliame scuro e azzera il metallico spurio (vedi sotto).
- Collisioni: solo i tronchi (`trunk_radius` 0,25-0,3) per gli alberi; chioma attraversabile con fade.
- Stesso `PropBatcher`: i ripetuti (botti, casse, scudi, rocce, cespugli) diventano MultiMesh.

## Licenze
Poly Haven CC0. Sketchfab senza licenza verificata (`sketchfab/README.md`): prototipo, da verificare prima del rilascio. Qui non si usano modelli Sketchfab.

## Texture e VRAM (stato)
- Tutte le texture 3D usate dal livello 1 sono VRAM-compressed (S3TC/BPTC desktop, ETC2/ASTC mobile e web, abilitati in `project.godot`) con mipmap; maschere e splat del terreno restano lossless di proposito.
- Per qualità: non si riducono le texture a runtime; i modelli pesanti hanno una variante leggera (`GridProp.low_quality_model`, mesh mobile del terreno con texture 1K, erba con budget).
- Da fare quando serve: ~24 `.import` di modelli del livello 2 (coste, attrezzi, sketchfab) sono ancora lossless senza mipmap (`compress/mode=0`): impostare `compress/mode=2` e `mipmaps/generate=true`.
- Export: non esiste `export_presets.cfg`. Quando c'è, aggiungere a `exclude_filter` di web e mobile: `*/textures_2k/*, assets/models/custom/_source/*`.
