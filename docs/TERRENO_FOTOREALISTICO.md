# Terreno ed erba fotorealistici nel livello 1

Integrazione di `assets/models/custom/terreno/` (vedi il suo README) al posto di terreno e prato procedurali.

## Nodi in `level1.tscn`
- `Terreno/TerrenoFotorealistico` (`PhotoTerrain`): istanzia `terreno_pianura.gltf` a qualità alta, `terreno_pianura_mobile.gltf` a media e bassa. Nasconde i nodi del gruppo `procedural_terrain` (Roccia, Terra, Prato, PratoNordOvest, Fondale, StradaAccampamento, StradaPorta, Spiaggia, Rilievo, LatiBlocco). Restano nell'albero: i gruppi `grass_ground`/`grass_exclude` servono ancora alla maschera. Collisioni e griglia restano su `TerrainRelief`. `height_at(x, z)` dà la quota vera della mesh. `use_splat_shader` (spento) usa lo shader a 6 strati con Texture2DArray create a runtime.
- `ErbaFotorealistica` (`GrassCards`): ciuffi a cards (`erba_ciuffi.gltf`) con `assets/shaders/grass_cards.gdshader` (derivato dallo shader del terreno: aggiunge gli interattori di `GrassField`). Un `MultiMeshInstance3D` per variante e per blocco (8 m; 16 m a qualità bassa). Maschere: `T_terreno_maschere` (densità B, secchezza A, roccia R), `T_terreno_maschere2` (altezza R, banda di colore G) e `GrassMask` (esclusioni, caselle solide). Tinta per istanza (verde/secco + chiazze), nebbia dell'Environment.
- `ErbaMossa`, `Cespugli` (`GrassField`, `procedural_only = true`): non vengono costruiti col terreno fotorealistico.

## Flag
`TerrainStyle.photo()`: `-- --terrain=procedural` o `ODYSSEY_TERRAIN=procedural` ricostruiscono il vecchio terreno e prato; `TerrainStyle.set_photo(false)` da codice (usato dai test del vecchio prato).

## Budget (`Quality.grass_budget()`)
Basso 3000, medio 10000, alto 45000 ciuffi (`ODYSSEY_GRASS_BUDGET=N` per forzarlo). `GrassCards.density_scale` lo moltiplica. A basso solo 6 varianti (meno draw call).

## Test
`tests/test_photo_terrain.gd` (mesh, nascosti, quote, budget, maschera, flag spento). I test sul vecchio prato impostano `TerrainStyle.set_photo(false)`.

## Note
- Le colline della mesh (±10 cm) non sono nella collisione: le unità possono sprofondare o galleggiare fino a 10 cm; l'erba segue la mesh.
- I lastricati (`StoneScatter`) restano sopra il sentiero della splat map.

## Aggiornamento (budget, colore, draw call, lastre, colline)
- Budget alto 30000 ciuffi (`Quality.grass_budget()`, `ODYSSEY_GRASS_BUDGET` lo forza).
- Colore: `tint` (0.86, 1.04, 0.80) verde fresco, `dry_tint` più tenue, `dry_share` 0,45 (quota di ciuffi secchi): verdi con punte secche. Prima/dopo: `tests/screenshots/photo_v1/` e `tests/screenshots/photo/`.
- Draw call: blocchi dell'erba x4 a basso e x2 a medio; `PropBatcher` (nodo `UnioneOggetti`) unisce i GridProp con lo stesso modello in MultiMesh (alberi esclusi; collisioni invariate). Draw: basso 524→279, medio 721→371, alto 761→531.
- Lastre (`StoneScatter`): con il terreno fotorealistico seguono quota e pendenza della mesh e affondano di 5 cm.
- Colline: `TerrainRelief.surface_detail` (impostato da `PhotoTerrain`) aggiunge alla quota a gradini lo scarto della mesh (max ±12 cm): unità, piedi di Ulisse, tiri e oggetti coincidono con la mesh. `test_relief` ora accetta ±13 cm.
