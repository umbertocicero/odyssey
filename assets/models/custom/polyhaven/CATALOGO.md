# Catalogo modelli Poly Haven

Elenco generato da `_source/scripts/gen_polyhaven_catalog.py` (dati: `_report.jsonl`). Dimensioni in metri **larghezza (X) x profondità (Z in Godot) x altezza (Y in Godot)**, origine al centro della base. Triangoli dopo la riduzione.
Budget: **massa** = fino a 1.000 triangoli, adatta al MultiMesh; **standard** = fino a 5.000; **primo piano** = oltre 5.000, pochi esemplari alla volta (su mobile e web meglio ridurre).
Tutti i modelli sono CC0 (Poly Haven): [polyhaven.com/license](https://polyhaven.com/license). Pagina originale di ogni modello: `https://polyhaven.com/a/<nome>`.

### Rocce, scogliere e tronchi

| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |
|---|---|---|---|---|---|---|
| [`rocce/boulder_01/boulder_01.gltf`](rocce/boulder_01/boulder_01.gltf) | Masso isolato: margini del campo, accanto a rovine e muretti | 1, 2 | 1.27 × 1.82 × 1 | 3.500 | 2048 | standard |
| [`rocce/coast_land_rocks_04/coast_land_rocks_04.gltf`](rocce/coast_land_rocks_04/coast_land_rocks_04.gltf) | Piattaforma rocciosa piana sul bagnasciuga: base per il cantiere e per le onde | 2 | 9.97 × 11.5 × 0.83 | 8.999 | 2048 | primo piano |
| [`rocce/coast_rocks_05/coast_rocks_05.gltf`](rocce/coast_rocks_05/coast_rocks_05.gltf) | Gruppo di scogli: scogliera, relitto spaccato tra gli scogli, battigia | 2 | 3.03 × 2.82 × 0.99 | 6.000 | 2048 | primo piano |
| [`rocce/dead_tree_trunk_02/dead_tree_trunk_02.gltf`](rocce/dead_tree_trunk_02/dead_tree_trunk_02.gltf) | Tronco morto: legni portati dal mare (8 mucchi), punto di raccolta legna | 2 (1 sulla cresta) | 4.05 × 1.06 × 1.05 | 4.500 | 2048 | standard |
| [`rocce/namaqualand_boulder_02/namaqualand_boulder_02.gltf`](rocce/namaqualand_boulder_02/namaqualand_boulder_02.gltf) | Lastra di roccia bassa e larga: bordi del diorama, riva | 1, 2 | 2.53 × 1.23 × 0.88 | 3.999 | 2048 | standard |
| [`rocce/namaqualand_boulder_03/namaqualand_boulder_03.gltf`](rocce/namaqualand_boulder_03/namaqualand_boulder_03.gltf) | Grande masso verticale: sperone, scogliera, quinta di cresta | 1, 2 | 2.4 × 3.06 × 1.47 | 3.500 | 2048 | standard |
| [`rocce/namaqualand_cliff_02/namaqualand_cliff_02.gltf`](rocce/namaqualand_cliff_02/namaqualand_cliff_02.gltf) | Parete di roccia (20 m): cresta e scogliera nord-ovest, bordo del blocco | 2 (1 solo per la cresta) | 20.22 × 6.58 × 7.19 | 8.999 | 2048 | primo piano |

### Erba, fiori e cespugli (alpha cards, MASK)

| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |
|---|---|---|---|---|---|---|
| [`vegetazione/celandine_01/celandine_01_a.gltf`](vegetazione/celandine_01/celandine_01_a.gltf) | Celidonia gialla: accenti di colore nel prato | 1, 2 | 0.28 × 0.23 × 0.19 | 232 | 1024 | massa (MultiMesh) |
| [`vegetazione/celandine_01/celandine_01_b.gltf`](vegetazione/celandine_01/celandine_01_b.gltf) | Celidonia gialla: accenti di colore nel prato | 1, 2 | 0.25 × 0.31 × 0.14 | 207 | 1024 | massa (MultiMesh) |
| [`vegetazione/celandine_01/celandine_01_c.gltf`](vegetazione/celandine_01/celandine_01_c.gltf) | Celidonia gialla: accenti di colore nel prato | 1, 2 | 0.25 × 0.19 × 0.18 | 319 | 1024 | massa (MultiMesh) |
| [`vegetazione/celandine_01/celandine_01_d.gltf`](vegetazione/celandine_01/celandine_01_d.gltf) | Celidonia gialla: accenti di colore nel prato | 1, 2 | 0.19 × 0.22 × 0.15 | 250 | 1024 | massa (MultiMesh) |
| [`vegetazione/dandelion_01/dandelion_01_a.gltf`](vegetazione/dandelion_01/dandelion_01_a.gltf) | Tarassaco: accenti gialli e bianchi nel prato | 1, 2 | 0.22 × 0.25 × 0.16 | 260 | 1024 | massa (MultiMesh) |
| [`vegetazione/dandelion_01/dandelion_01_b.gltf`](vegetazione/dandelion_01/dandelion_01_b.gltf) | Tarassaco: accenti gialli e bianchi nel prato | 1, 2 | 0.2 × 0.21 × 0.11 | 265 | 1024 | massa (MultiMesh) |
| [`vegetazione/dandelion_01/dandelion_01_c.gltf`](vegetazione/dandelion_01/dandelion_01_c.gltf) | Tarassaco: accenti gialli e bianchi nel prato | 1, 2 | 0.17 × 0.17 × 0.09 | 156 | 1024 | massa (MultiMesh) |
| [`vegetazione/fern_02/fern_02_a.gltf`](vegetazione/fern_02/fern_02_a.gltf) | Felce: sottobosco ai piedi di rovine, abeti dello sperone | 1, 2 | 0.55 × 0.61 × 0.29 | 784 | 1024 | massa (MultiMesh) |
| [`vegetazione/fern_02/fern_02_b.gltf`](vegetazione/fern_02/fern_02_b.gltf) | Felce: sottobosco ai piedi di rovine, abeti dello sperone | 1, 2 | 0.99 × 0.89 × 0.43 | 2.384 | 1024 | standard |
| [`vegetazione/fern_02/fern_02_c.gltf`](vegetazione/fern_02/fern_02_c.gltf) | Felce: sottobosco ai piedi di rovine, abeti dello sperone | 1, 2 | 0.87 × 0.77 × 0.35 | 2.248 | 1024 | standard |
| [`vegetazione/fern_02/fern_02_d.gltf`](vegetazione/fern_02/fern_02_d.gltf) | Felce: sottobosco ai piedi di rovine, abeti dello sperone | 1, 2 | 0.57 × 0.59 × 0.21 | 816 | 1024 | massa (MultiMesh) |
| [`vegetazione/flower_heliophila/flower_heliophila_medium.gltf`](vegetazione/flower_heliophila/flower_heliophila_medium.gltf) | Eliofila (fiore blu): accenti sulle dune e ai bordi | 2 (1) | 0.65 × 0.6 × 0.37 | 4.499 | 1024 | standard |
| [`vegetazione/flower_heliophila/flower_heliophila_small.gltf`](vegetazione/flower_heliophila/flower_heliophila_small.gltf) | Eliofila (fiore blu): accenti sulle dune e ai bordi | 2 (1) | 0.34 × 0.27 × 0.27 | 4.500 | 1024 | standard |
| [`vegetazione/grass_medium_01/grass_medium_01_large_b.gltf`](vegetazione/grass_medium_01/grass_medium_01_large_b.gltf) | Ciuffo grande: macchie d'erba alta, bordi di muri | 1, 2 | 0.29 × 0.29 × 0.17 | 890 | 1024 | massa (MultiMesh) |
| [`vegetazione/grass_medium_01/grass_medium_01_mid_b.gltf`](vegetazione/grass_medium_01/grass_medium_01_mid_b.gltf) | Ciuffo d'erba medio: manto del prato, MultiMesh | 1, 2 | 0.19 × 0.18 × 0.18 | 334 | 1024 | massa (MultiMesh) |
| [`vegetazione/grass_medium_01/grass_medium_01_small_b.gltf`](vegetazione/grass_medium_01/grass_medium_01_small_b.gltf) | Ciuffo d'erba medio: manto del prato, MultiMesh | 1, 2 | 0.17 × 0.19 × 0.1 | 283 | 1024 | massa (MultiMesh) |
| [`vegetazione/grass_medium_01/grass_medium_01_tall_a.gltf`](vegetazione/grass_medium_01/grass_medium_01_tall_a.gltf) | Ciuffo d'erba medio: manto del prato, MultiMesh | 1, 2 | 0.16 × 0.16 × 0.33 | 121 | 1024 | massa (MultiMesh) |
| [`vegetazione/grass_medium_01/grass_medium_01_tall_c.gltf`](vegetazione/grass_medium_01/grass_medium_01_tall_c.gltf) | Ciuffo d'erba medio: manto del prato, MultiMesh | 1, 2 | 0.15 × 0.12 × 0.23 | 162 | 1024 | massa (MultiMesh) |
| [`vegetazione/grass_medium_01/grass_medium_01_tiny_a.gltf`](vegetazione/grass_medium_01/grass_medium_01_tiny_a.gltf) | Ciuffo minuscolo: riempimento fitto, MultiMesh (poche decine di triangoli) | 1, 2 | 0.07 × 0.07 × 0.11 | 35 | 1024 | massa (MultiMesh) |
| [`vegetazione/grass_medium_02/grass_medium_02_a.gltf`](vegetazione/grass_medium_02/grass_medium_02_a.gltf) | Cespo d'erba: alternativa a grass_medium_01 per variare il prato | 1, 2 | 0.12 × 0.12 × 0.16 | 714 | 1024 | massa (MultiMesh) |
| [`vegetazione/grass_medium_02/grass_medium_02_b.gltf`](vegetazione/grass_medium_02/grass_medium_02_b.gltf) | Cespo d'erba: alternativa a grass_medium_01 per variare il prato | 1, 2 | 0.18 × 0.2 × 0.18 | 1.760 | 1024 | standard |
| [`vegetazione/grass_medium_02/grass_medium_02_c.gltf`](vegetazione/grass_medium_02/grass_medium_02_c.gltf) | Cespo d'erba: alternativa a grass_medium_01 per variare il prato | 1, 2 | 0.26 × 0.25 × 0.23 | 1.215 | 1024 | standard |
| [`vegetazione/grass_medium_02/grass_medium_02_d.gltf`](vegetazione/grass_medium_02/grass_medium_02_d.gltf) | Cespo d'erba: alternativa a grass_medium_01 per variare il prato | 1, 2 | 0.32 × 0.36 × 0.26 | 2.489 | 1024 | standard |
| [`vegetazione/grass_medium_02/grass_medium_02_e.gltf`](vegetazione/grass_medium_02/grass_medium_02_e.gltf) | Cespo d'erba: alternativa a grass_medium_01 per variare il prato | 1, 2 | 0.36 × 0.43 × 0.4 | 1.664 | 1024 | standard |
| [`vegetazione/othonna_cerarioides/othonna_cerarioides_a.gltf`](vegetazione/othonna_cerarioides/othonna_cerarioides_a.gltf) | Cespuglio a fiori gialli: macchia sulle dune e sulla cresta | 1, 2 | 1.1 × 1.03 × 1.97 | 5.000 | 1024 | standard |
| [`vegetazione/othonna_cerarioides/othonna_cerarioides_b.gltf`](vegetazione/othonna_cerarioides/othonna_cerarioides_b.gltf) | Cespuglio a fiori gialli: macchia sulle dune e sulla cresta | 1, 2 | 1.01 × 1.05 × 1.77 | 5.000 | 1024 | standard |
| [`vegetazione/othonna_cerarioides/othonna_cerarioides_c.gltf`](vegetazione/othonna_cerarioides/othonna_cerarioides_c.gltf) | Cespuglio a fiori gialli: macchia sulle dune e sulla cresta | 1, 2 | 0.72 × 0.95 × 1.44 | 4.999 | 1024 | standard |
| [`vegetazione/periwinkle_plant/periwinkle_plant_01.gltf`](vegetazione/periwinkle_plant/periwinkle_plant_01.gltf) | Pervinca viola: accenti di colore tra le pietre (STYLE.md: fiori viola) | 1 | 0.27 × 0.33 × 0.4 | 700 | 1024 | massa (MultiMesh) |
| [`vegetazione/periwinkle_plant/periwinkle_plant_02.gltf`](vegetazione/periwinkle_plant/periwinkle_plant_02.gltf) | Pervinca viola: accenti di colore tra le pietre (STYLE.md: fiori viola) | 1 | 0.24 × 0.23 × 0.41 | 606 | 1024 | massa (MultiMesh) |
| [`vegetazione/searsia_lucida/searsia_lucida_a.gltf`](vegetazione/searsia_lucida/searsia_lucida_a.gltf) | Arbusto verde scuro: macchia, siepi naturali, riparo per Sinone tra le dune | 2, 1 | 1.77 × 1.96 × 2.34 | 14.000 | 1024 | primo piano |
| [`vegetazione/searsia_lucida/searsia_lucida_b.gltf`](vegetazione/searsia_lucida/searsia_lucida_b.gltf) | Arbusto verde scuro: macchia, siepi naturali, riparo per Sinone tra le dune | 2, 1 | 1.51 × 1.46 × 1.99 | 14.000 | 1024 | primo piano |
| [`vegetazione/searsia_lucida/searsia_lucida_c.gltf`](vegetazione/searsia_lucida/searsia_lucida_c.gltf) | Arbusto verde scuro: macchia, siepi naturali, riparo per Sinone tra le dune | 2, 1 | 1.51 × 1.25 × 1.68 | 14.000 | 1024 | primo piano |
| [`vegetazione/searsia_lucida/searsia_lucida_d.gltf`](vegetazione/searsia_lucida/searsia_lucida_d.gltf) | Arbusto verde scuro: macchia, siepi naturali, riparo per Sinone tra le dune | 2, 1 | 1.11 × 0.96 × 1.42 | 14.000 | 1024 | primo piano |

### Alberi

| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |
|---|---|---|---|---|---|---|
| [`alberi/fir_sapling_medium/fir_sapling_medium_a.gltf`](alberi/fir_sapling_medium/fir_sapling_medium_a.gltf) | Abete giovane (6-9 m): abeti dello sperone nord-ovest da abbattere (raccolta legna) | 2 | 5.06 × 5.32 × 8.86 | 8.999 | 1024 | primo piano |
| [`alberi/fir_sapling_medium/fir_sapling_medium_b.gltf`](alberi/fir_sapling_medium/fir_sapling_medium_b.gltf) | Abete giovane (6-9 m): abeti dello sperone nord-ovest da abbattere (raccolta legna) | 2 | 4.95 × 5.43 × 7.93 | 8.761 | 1024 | primo piano |
| [`alberi/fir_sapling_medium/fir_sapling_medium_c.gltf`](alberi/fir_sapling_medium/fir_sapling_medium_c.gltf) | Abete giovane (6-9 m): abeti dello sperone nord-ovest da abbattere (raccolta legna) | 2 | 4.32 × 4.04 × 5.94 | 8.393 | 1024 | primo piano |
| [`alberi/fir_tree_01/fir_tree_01_c.gltf`](alberi/fir_tree_01/fir_tree_01_c.gltf) | Abete adulto (14,5 m): sperone nord-ovest, quinta alta ai margini | 2 | 6.35 × 6.01 × 14.55 | 23.999 | 1024 | primo piano |
| [`alberi/island_tree_01/island_tree_01_geometry_nodes.gltf`](alberi/island_tree_01/island_tree_01_geometry_nodes.gltf) | Alberello da primo piano (4,5 m): macchia vicino alle rovine | 1, 2 | 3.89 × 4.89 × 4.51 | 42.656 | 1024 | primo piano |
| [`alberi/island_tree_02/island_tree_02_geometry_nodes.gltf`](alberi/island_tree_02/island_tree_02_geometry_nodes.gltf) | Alberello da primo piano (3,7 m): alternativa al precedente | 1, 2 | 4.23 × 3.57 × 3.69 | 35.500 | 1024 | primo piano |

### Fauna

| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |
|---|---|---|---|---|---|---|
| [`fauna/street_rat/street_rat.gltf`](fauna/street_rat/street_rat.gltf) | Ratto: dettaglio di vita al campo, sotto le casse e vicino alle navi | 1, 2 | 0.03 × 0.15 × 0.03 | 4.000 | 1024 | standard |

### Oggetti da campo e cantiere

| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |
|---|---|---|---|---|---|---|
| [`oggetti/treasure_chest/treasure_chest.gltf`](oggetti/treasure_chest/treasure_chest.gltf) | Forziere: interazione/ricompensa (Interazione dell'immagine di Ulisse) | 1, 2 | 0.96 × 0.52 × 0.62 | 9.000 | 1024 | primo piano |
| [`oggetti/wooden_barrels_01/wooden_barrels_01_barrel01.gltf`](oggetti/wooden_barrels_01/wooden_barrels_01_barrel01.gltf) | Botte: accampamento (immagine di riferimento), cantiere, navi | 1, 2 | 0.74 × 0.74 × 0.92 | 3.500 | 1024 | standard |
| [`oggetti/wooden_barrels_01/wooden_barrels_01_barrel02.gltf`](oggetti/wooden_barrels_01/wooden_barrels_01_barrel02.gltf) | Botte: accampamento (immagine di riferimento), cantiere, navi | 1, 2 | 0.74 × 0.74 × 0.92 | 3.500 | 1024 | standard |
| [`oggetti/wooden_bucket_02/wooden_bucket_02.gltf`](oggetti/wooden_bucket_02/wooden_bucket_02.gltf) | Secchio: cantiere, tracce da bagnare (livello 2, fase 3) | 2 (1) | 0.61 × 0.62 × 0.35 | 3.000 | 1024 | standard |
| [`oggetti/wooden_crate_01/wooden_crate_01.gltf`](oggetti/wooden_crate_01/wooden_crate_01.gltf) | Cassa: accampamento e cantiere | 1, 2 | 0.82 × 0.41 × 0.32 | 3.498 | 1024 | standard |
| [`oggetti/wooden_ladder_02/wooden_ladder_02.gltf`](oggetti/wooden_ladder_02/wooden_ladder_02.gltf) | Scala a pioli: impalcatura del cavallo | 2 | 0.99 × 0.62 × 1.72 | 3.499 | 1024 | standard |
| [`oggetti/wooden_stool_02/wooden_stool_02.gltf`](oggetti/wooden_stool_02/wooden_stool_02.gltf) | Sgabello: dentro e davanti alle tende | 1, 2 | 0.27 × 0.18 × 0.18 | 3.000 | 1024 | standard |

### Attrezzi (cantiere del cavallo)

| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |
|---|---|---|---|---|---|---|
| [`attrezzi/cross_pein_hammer/cross_pein_hammer.gltf`](attrezzi/cross_pein_hammer/cross_pein_hammer.gltf) | Martello da carpentiere: cantiere | 2 | 0.1 × 0.02 × 0.3 | 2.124 | 1024 | standard |
| [`attrezzi/hand_plane_no4/hand_plane_no4.gltf`](attrezzi/hand_plane_no4/hand_plane_no4.gltf) | Pialla: cantiere (la pialla romana esisteva, la forma è moderna) | 2 | 0.33 × 0.08 × 0.2 | 3.999 | 1024 | standard |
| [`attrezzi/handsaw_wood/handsaw_wood.gltf`](attrezzi/handsaw_wood/handsaw_wood.gltf) | Sega a mano: smontare le navi e tagliare il legno | 2 | 0.04 × 0.63 × 0.17 | 2.500 | 1024 | standard |
| [`attrezzi/picke_dirty_01/picke_dirty_01.gltf`](attrezzi/picke_dirty_01/picke_dirty_01.gltf) | Piccone: scavo del fossato, rocce | 1, 2 | 0.55 × 0.07 × 1.12 | 3.500 | 1024 | standard |
| [`attrezzi/rusted_spade_01/rusted_spade_01.gltf`](attrezzi/rusted_spade_01/rusted_spade_01.gltf) | Vanga arrugginita: rastrellare le tracce, scavare | 2 | 0.17 × 0.05 × 1.1 | 3.500 | 1024 | standard |
| [`attrezzi/vintage_hand_drill/vintage_hand_drill.gltf`](attrezzi/vintage_hand_drill/vintage_hand_drill.gltf) | Trapano a manovella: cantiere (forma moderna, usare con parsimonia) | 2 | 0.12 × 0.13 × 0.49 | 4.500 | 1024 | standard |
| [`attrezzi/wooden_axe/wooden_axe.gltf`](attrezzi/wooden_axe/wooden_axe.gltf) | Ascia: carpentieri di Epeo, abbattimento degli abeti | 2 | 0.05 × 0.21 × 0.63 | 3.000 | 1024 | standard |
| [`attrezzi/wooden_hammer_01/wooden_hammer_01.gltf`](attrezzi/wooden_hammer_01/wooden_hammer_01.gltf) | Martello di legno (mazzuolo): impalcatura e cantiere | 2 | 0.11 × 0.02 × 0.28 | 3.000 | 1024 | standard |

### Architettura modulare

| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |
|---|---|---|---|---|---|---|
| [`architettura/modular_fort_01/modular_fort_01_tower_round.gltf`](architettura/modular_fort_01/modular_fort_01_tower_round.gltf) | Torre rotonda: candidata per una torre di Troia | 1, 2 | 15.84 × 15.84 × 13.5 | 4.000 | 1024 | standard |
| [`architettura/modular_fort_01/modular_fort_01_wall_stairs_straight_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_stairs_straight_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 3.54 × 14.82 × 7.53 | 1.196 | 1024 | standard |
| [`architettura/modular_fort_01/modular_fort_01_wall_thick_corner_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thick_corner_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 5.84 × 5.84 × 8.53 | 816 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_thick_corner_02.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thick_corner_02.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 7.07 × 5.72 × 8.53 | 836 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_thick_end_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thick_end_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 4.17 × 4.85 × 7.79 | 442 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_thick_end_02.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thick_end_02.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 4.17 × 4.85 × 8.53 | 642 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_thick_straight_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thick_straight_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 4.17 × 14.56 × 8.53 | 2.340 | 1024 | standard |
| [`architettura/modular_fort_01/modular_fort_01_wall_thick_straight_02.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thick_straight_02.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 4.23 × 14.56 × 8.52 | 4.000 | 1024 | standard |
| [`architettura/modular_fort_01/modular_fort_01_wall_thick_thin_transition_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thick_thin_transition_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 4.17 × 3.56 × 8.57 | 434 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_thin_corner_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thin_corner_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 4.56 × 4.56 × 8.61 | 654 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_thin_corner_02.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thin_corner_02.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 5.34 × 5.34 × 8.61 | 708 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_thin_corner_03.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thin_corner_03.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 6.46 × 4.99 × 8.61 | 494 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_thin_gate_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thin_gate_01.gltf) | Porta del forte: candidata per la porta di Troia (livello 2: percorso del cavallo) | 2, 1 | 2.67 × 7.41 × 8.62 | 1.368 | 1024 | standard |
| [`architettura/modular_fort_01/modular_fort_01_wall_thin_straight_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thin_straight_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 2.55 × 14.82 × 8.61 | 1.076 | 1024 | standard |
| [`architettura/modular_fort_01/modular_fort_01_wall_thin_straight_02.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thin_straight_02.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 2.55 × 14.82 × 8.61 | 2.376 | 1024 | standard |
| [`architettura/modular_fort_01/modular_fort_01_wall_thin_straight_03.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thin_straight_03.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 2.55 × 7.41 × 7.79 | 406 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_thin_straight_04.gltf`](architettura/modular_fort_01/modular_fort_01_wall_thin_straight_04.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 2.55 × 7.41 × 8.61 | 622 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_walkway_corner_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_walkway_corner_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 7.68 × 7.68 × 7.53 | 140 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_walkway_corner_02.gltf`](architettura/modular_fort_01/modular_fort_01_wall_walkway_corner_02.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 2.79 × 2.79 × 7.08 | 94 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_walkway_end_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_walkway_end_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 3.12 × 4.85 × 7.53 | 76 | 1024 | massa (MultiMesh) |
| [`architettura/modular_fort_01/modular_fort_01_wall_walkway_straight_01.gltf`](architettura/modular_fort_01/modular_fort_01_wall_walkway_straight_01.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 3.37 × 14.56 × 7.7 | 2.654 | 1024 | standard |
| [`architettura/modular_fort_01/modular_fort_01_wall_walkway_straight_02.gltf`](architettura/modular_fort_01/modular_fort_01_wall_walkway_straight_02.gltf) | Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2) | 1, 2 | 3.12 × 14.56 × 7.53 | 76 | 1024 | massa (MultiMesh) |
| [`architettura/modular_wooden_pier/modular_wooden_pier_planks.gltf`](architettura/modular_wooden_pier/modular_wooden_pier_planks.gltf) | Tavolato del molo (impalcato) | 1, 2 | 2.52 × 2.2 × 0.08 | 5.512 | 1024 | primo piano |
| [`architettura/modular_wooden_pier/modular_wooden_pier_poles.gltf`](architettura/modular_wooden_pier/modular_wooden_pier_poles.gltf) | Pali del molo (fondazioni) | 1, 2 | 2.21 × 3.08 × 3.85 | 2.460 | 1024 | standard |
| [`architettura/modular_wooden_pier/modular_wooden_pier_section_01.gltf`](architettura/modular_wooden_pier/modular_wooden_pier_section_01.gltf) | Sezione modulare di molo (testata, curva, tratto, scala): banchina delle navi | 1, 2 | 2.49 × 3.52 × 4.27 | 7.000 | 1024 | primo piano |
| [`architettura/modular_wooden_pier/modular_wooden_pier_section_02.gltf`](architettura/modular_wooden_pier/modular_wooden_pier_section_02.gltf) | Sezione modulare di molo (testata, curva, tratto, scala): banchina delle navi | 1, 2 | 2.51 × 3.39 × 3.84 | 7.000 | 1024 | primo piano |
| [`architettura/modular_wooden_pier/modular_wooden_pier_section_03.gltf`](architettura/modular_wooden_pier/modular_wooden_pier_section_03.gltf) | Sezione modulare di molo (testata, curva, tratto, scala): banchina delle navi | 1, 2 | 2.51 × 3.39 × 3.84 | 7.000 | 1024 | primo piano |
| [`architettura/modular_wooden_pier/modular_wooden_pier_section_04.gltf`](architettura/modular_wooden_pier/modular_wooden_pier_section_04.gltf) | Sezione modulare di molo (testata, curva, tratto, scala): banchina delle navi | 1, 2 | 2.46 × 3.16 × 4.16 | 7.000 | 1024 | primo piano |
| [`architettura/modular_wooden_pier/modular_wooden_pier_section_05.gltf`](architettura/modular_wooden_pier/modular_wooden_pier_section_05.gltf) | Sezione modulare di molo (testata, curva, tratto, scala): banchina delle navi | 1, 2 | 3.1 × 0.46 × 7 | 6.999 | 1024 | primo piano |

### Fuori epoca: attrezzi e scudo moderni/medievali (non usare per Troia)

| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |
|---|---|---|---|---|---|---|
| [`attrezzi_fuori_epoca/fish_knife/fish_knife.gltf`](attrezzi_fuori_epoca/fish_knife/fish_knife.gltf) | Coltello da pesce: FUORI EPOCA (moderno); solo per scene di mercato, meglio non usarlo | - | 0.03 × 0.02 × 0.22 | 2.736 | 1024 | standard |
| [`attrezzi_fuori_epoca/flathead_screwdriver/flathead_screwdriver.gltf`](attrezzi_fuori_epoca/flathead_screwdriver/flathead_screwdriver.gltf) | Cacciavite: FUORI EPOCA, da non usare | - | 0.03 × 0.03 × 0.26 | 2.300 | 1024 | standard |
| [`attrezzi_fuori_epoca/kite_shield/kite_shield.gltf`](attrezzi_fuori_epoca/kite_shield/kite_shield.gltf) | Scudo a goccia medievale: FUORI EPOCA, da non usare per Achei e Troiani | - | 0.54 × 0.13 × 1.39 | 6.000 | 1024 | primo piano |
| [`attrezzi_fuori_epoca/machete/machete.gltf`](attrezzi_fuori_epoca/machete/machete.gltf) | Machete: FUORI EPOCA, da non usare | - | 0.04 × 0.06 × 0.75 | 3.000 | 1024 | standard |

### Fuori epoca: nave del Seicento (non usare per Troia)

| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |
|---|---|---|---|---|---|---|
| [`navi_fuori_epoca/dutch_ship_medium/dutch_ship_medium.gltf`](navi_fuori_epoca/dutch_ship_medium/dutch_ship_medium.gltf) | Nave olandese del Seicento: FUORI EPOCA; al massimo sagoma lontanissima, sconsigliata | - | 6.81 × 24.06 × 24.65 | 21.917 | 1024 | primo piano |
