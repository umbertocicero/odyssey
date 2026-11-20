class_name PolyhavenCatalog
extends RefCounted
## Catalogo dei modelli Poly Haven (CC0, collezione Namaqualand e altri) convertiti
## in assets/models/custom/polyhaven/. Una voce per modello: percorso, ruolo,
## triangoli (dal _report.jsonl dell'agente di modellazione) e qualità minima
## per cui vale la pena usarlo (0 = LOW/web, 1 = MEDIUM/mobile, 2 = HIGH/PC).
##
## I file non si modificano mai: si usano così come sono, scalati con ModelFit.
## Le posizioni stanno nei file di dati (data/props/*.json), non qui.

const ROOT := "res://assets/models/custom/polyhaven/"

enum Role { ROCK, TREE, TRUNK, CLIFF, PLANT, FLOWER, GRASS, FAUNA, PROP, TOOL, PIER, WALL, GROUND }

## id -> { path, role, tris, min_quality, alt_height (metri reali a scala 1:1) }
const ENTRIES := {
	# Rocce
	"boulder_01": {"path": "rocce/boulder_01/boulder_01.gltf", "role": Role.ROCK, "tris": 3500, "min_quality": 0},
	"namaqualand_boulder_02": {"path": "rocce/namaqualand_boulder_02/namaqualand_boulder_02.gltf", "role": Role.ROCK, "tris": 3999, "min_quality": 0},
	"namaqualand_boulder_03": {"path": "rocce/namaqualand_boulder_03/namaqualand_boulder_03.gltf", "role": Role.ROCK, "tris": 3500, "min_quality": 0},
	"namaqualand_cliff_02": {"path": "rocce/namaqualand_cliff_02/namaqualand_cliff_02.gltf", "role": Role.CLIFF, "tris": 8999, "min_quality": 1},
	"dead_tree_trunk_02": {"path": "rocce/dead_tree_trunk_02/dead_tree_trunk_02.gltf", "role": Role.TRUNK, "tris": 4500, "min_quality": 0},
	# Alberi (il fusto blocca, la chioma si attraversa e diventa semitrasparente)
	"fir_sapling_medium_a": {"path": "alberi/fir_sapling_medium/fir_sapling_medium_a.gltf", "role": Role.TREE, "tris": 8999, "min_quality": 0},
	"fir_sapling_medium_b": {"path": "alberi/fir_sapling_medium/fir_sapling_medium_b.gltf", "role": Role.TREE, "tris": 8761, "min_quality": 0},
	"fir_sapling_medium_c": {"path": "alberi/fir_sapling_medium/fir_sapling_medium_c.gltf", "role": Role.TREE, "tris": 8393, "min_quality": 0},
	"fir_tree_01_c": {"path": "alberi/fir_tree_01/fir_tree_01_c.gltf", "role": Role.TREE, "tris": 23999, "min_quality": 2},
	"island_tree_01": {"path": "alberi/island_tree_01/island_tree_01_geometry_nodes.gltf", "role": Role.TREE, "tris": 42656, "min_quality": 2},
	"island_tree_02": {"path": "alberi/island_tree_02/island_tree_02_geometry_nodes.gltf", "role": Role.TREE, "tris": 35500, "min_quality": 2},
	# Arbusti e piante grandi
	"searsia_lucida_a": {"path": "vegetazione/searsia_lucida/searsia_lucida_a.gltf", "role": Role.PLANT, "tris": 14000, "min_quality": 2},
	"searsia_lucida_d": {"path": "vegetazione/searsia_lucida/searsia_lucida_d.gltf", "role": Role.PLANT, "tris": 14000, "min_quality": 2},
	"othonna_cerarioides_a": {"path": "vegetazione/othonna_cerarioides/othonna_cerarioides_a.gltf", "role": Role.PLANT, "tris": 5000, "min_quality": 1},
	"othonna_cerarioides_b": {"path": "vegetazione/othonna_cerarioides/othonna_cerarioides_b.gltf", "role": Role.PLANT, "tris": 5000, "min_quality": 1},
	"othonna_cerarioides_c": {"path": "vegetazione/othonna_cerarioides/othonna_cerarioides_c.gltf", "role": Role.PLANT, "tris": 4999, "min_quality": 1},
	"fern_02_a": {"path": "vegetazione/fern_02/fern_02_a.gltf", "role": Role.PLANT, "tris": 784, "min_quality": 0},
	"fern_02_d": {"path": "vegetazione/fern_02/fern_02_d.gltf", "role": Role.PLANT, "tris": 816, "min_quality": 0},
	"fern_02_b": {"path": "vegetazione/fern_02/fern_02_b.gltf", "role": Role.PLANT, "tris": 2384, "min_quality": 1},
	"fern_02_c": {"path": "vegetazione/fern_02/fern_02_c.gltf", "role": Role.PLANT, "tris": 2248, "min_quality": 1},
	"periwinkle_plant_01": {"path": "vegetazione/periwinkle_plant/periwinkle_plant_01.gltf", "role": Role.PLANT, "tris": 700, "min_quality": 0},
	"periwinkle_plant_02": {"path": "vegetazione/periwinkle_plant/periwinkle_plant_02.gltf", "role": Role.PLANT, "tris": 606, "min_quality": 0},
	# Fiori
	"celandine_01_a": {"path": "vegetazione/celandine_01/celandine_01_a.gltf", "role": Role.FLOWER, "tris": 232, "min_quality": 0},
	"celandine_01_b": {"path": "vegetazione/celandine_01/celandine_01_b.gltf", "role": Role.FLOWER, "tris": 207, "min_quality": 0},
	"celandine_01_c": {"path": "vegetazione/celandine_01/celandine_01_c.gltf", "role": Role.FLOWER, "tris": 319, "min_quality": 0},
	"celandine_01_d": {"path": "vegetazione/celandine_01/celandine_01_d.gltf", "role": Role.FLOWER, "tris": 250, "min_quality": 0},
	"dandelion_01_a": {"path": "vegetazione/dandelion_01/dandelion_01_a.gltf", "role": Role.FLOWER, "tris": 260, "min_quality": 0},
	"dandelion_01_b": {"path": "vegetazione/dandelion_01/dandelion_01_b.gltf", "role": Role.FLOWER, "tris": 265, "min_quality": 0},
	"dandelion_01_c": {"path": "vegetazione/dandelion_01/dandelion_01_c.gltf", "role": Role.FLOWER, "tris": 156, "min_quality": 0},
	"flower_heliophila_small": {"path": "vegetazione/flower_heliophila/flower_heliophila_small.gltf", "role": Role.FLOWER, "tris": 4500, "min_quality": 2},
	"flower_heliophila_medium": {"path": "vegetazione/flower_heliophila/flower_heliophila_medium.gltf", "role": Role.FLOWER, "tris": 4499, "min_quality": 2},
	# Ciuffi d'erba (alpha-cutout)
	"grass_medium_01_tall_a": {"path": "vegetazione/grass_medium_01/grass_medium_01_tall_a.gltf", "role": Role.GRASS, "tris": 121, "min_quality": 0},
	"grass_medium_01_tall_c": {"path": "vegetazione/grass_medium_01/grass_medium_01_tall_c.gltf", "role": Role.GRASS, "tris": 162, "min_quality": 0},
	"grass_medium_01_small_b": {"path": "vegetazione/grass_medium_01/grass_medium_01_small_b.gltf", "role": Role.GRASS, "tris": 283, "min_quality": 0},
	"grass_medium_01_mid_b": {"path": "vegetazione/grass_medium_01/grass_medium_01_mid_b.gltf", "role": Role.GRASS, "tris": 334, "min_quality": 0},
	"grass_medium_02_a": {"path": "vegetazione/grass_medium_02/grass_medium_02_a.gltf", "role": Role.GRASS, "tris": 714, "min_quality": 0},
	"grass_medium_02_c": {"path": "vegetazione/grass_medium_02/grass_medium_02_c.gltf", "role": Role.GRASS, "tris": 1215, "min_quality": 1},
	# Oggetti da campo e cantiere (livello 1: accampamento; livello 2: cantiere)
	"treasure_chest": {"path": "oggetti/treasure_chest/treasure_chest.gltf", "role": Role.PROP, "tris": 9000, "min_quality": 2},
	"wooden_barrel_01": {"path": "oggetti/wooden_barrels_01/wooden_barrels_01_barrel01.gltf", "role": Role.PROP, "tris": 3500, "min_quality": 0},
	"wooden_barrel_02": {"path": "oggetti/wooden_barrels_01/wooden_barrels_01_barrel02.gltf", "role": Role.PROP, "tris": 3500, "min_quality": 0},
	"wooden_bucket_02": {"path": "oggetti/wooden_bucket_02/wooden_bucket_02.gltf", "role": Role.PROP, "tris": 3000, "min_quality": 0},
	"wooden_crate_01": {"path": "oggetti/wooden_crate_01/wooden_crate_01.gltf", "role": Role.PROP, "tris": 3498, "min_quality": 0},
	"wooden_ladder_02": {"path": "oggetti/wooden_ladder_02/wooden_ladder_02.gltf", "role": Role.PROP, "tris": 3499, "min_quality": 0},
	"wooden_stool_02": {"path": "oggetti/wooden_stool_02/wooden_stool_02.gltf", "role": Role.PROP, "tris": 3000, "min_quality": 0},
	# Attrezzi (cantiere del cavallo, livello 2). Il trapano ha forma moderna: con parsimonia.
	"cross_pein_hammer": {"path": "attrezzi/cross_pein_hammer/cross_pein_hammer.gltf", "role": Role.TOOL, "tris": 2124, "min_quality": 1},
	"hand_plane_no4": {"path": "attrezzi/hand_plane_no4/hand_plane_no4.gltf", "role": Role.TOOL, "tris": 3999, "min_quality": 1},
	"handsaw_wood": {"path": "attrezzi/handsaw_wood/handsaw_wood.gltf", "role": Role.TOOL, "tris": 2500, "min_quality": 1},
	"picke_dirty_01": {"path": "attrezzi/picke_dirty_01/picke_dirty_01.gltf", "role": Role.TOOL, "tris": 3500, "min_quality": 1},
	"rusted_spade_01": {"path": "attrezzi/rusted_spade_01/rusted_spade_01.gltf", "role": Role.TOOL, "tris": 3500, "min_quality": 1},
	"vintage_hand_drill": {"path": "attrezzi/vintage_hand_drill/vintage_hand_drill.gltf", "role": Role.TOOL, "tris": 4500, "min_quality": 2},
	"wooden_axe": {"path": "attrezzi/wooden_axe/wooden_axe.gltf", "role": Role.TOOL, "tris": 3000, "min_quality": 1},
	"wooden_hammer_01": {"path": "attrezzi/wooden_hammer_01/wooden_hammer_01.gltf", "role": Role.TOOL, "tris": 3000, "min_quality": 1},
	# Molo modulare (sezioni da ~2,5 m)
	"pier_section_01": {"path": "architettura/modular_wooden_pier/modular_wooden_pier_section_01.gltf", "role": Role.PIER, "tris": 7000, "min_quality": 1},
	"pier_section_02": {"path": "architettura/modular_wooden_pier/modular_wooden_pier_section_02.gltf", "role": Role.PIER, "tris": 7000, "min_quality": 1},
	"pier_section_03": {"path": "architettura/modular_wooden_pier/modular_wooden_pier_section_03.gltf", "role": Role.PIER, "tris": 7000, "min_quality": 1},
	"pier_section_05": {"path": "architettura/modular_wooden_pier/modular_wooden_pier_section_05.gltf", "role": Role.PIER, "tris": 6999, "min_quality": 1},
	# Mura e porta (livello 2: breccia). I pezzi sono alti 8,5 m: vanno scalati per il diorama.
	"fort_wall_thin_gate": {"path": "architettura/modular_fort_01/modular_fort_01_wall_thin_gate_01.gltf", "role": Role.WALL, "tris": 1368, "min_quality": 0},
	"fort_wall_thin_straight_01": {"path": "architettura/modular_fort_01/modular_fort_01_wall_thin_straight_01.gltf", "role": Role.WALL, "tris": 1076, "min_quality": 0},
	"fort_wall_thick_straight_01": {"path": "architettura/modular_fort_01/modular_fort_01_wall_thick_straight_01.gltf", "role": Role.WALL, "tris": 2340, "min_quality": 0},
	"fort_wall_thick_end_01": {"path": "architettura/modular_fort_01/modular_fort_01_wall_thick_end_01.gltf", "role": Role.WALL, "tris": 442, "min_quality": 0},
	# Scogli costieri (livello 2)
	"coast_rocks_05": {"path": "rocce/coast_rocks_05/coast_rocks_05.gltf", "role": Role.ROCK, "tris": 6000, "min_quality": 1},
	"coast_land_rocks_04": {"path": "rocce/coast_land_rocks_04/coast_land_rocks_04.gltf", "role": Role.GROUND, "tris": 8999, "min_quality": 1},
	# Fauna
	"street_rat": {"path": "fauna/street_rat/street_rat.gltf", "role": Role.FAUNA, "tris": 4000, "min_quality": 1},
}

static var _scenes: Dictionary = {}


static func has_entry(id: String) -> bool:
	return ENTRIES.has(id)


## Carica il modello (cache). null se il file non c'è ancora.
static func get_scene(id: String) -> PackedScene:
	if not ENTRIES.has(id):
		push_warning("PolyhavenCatalog: id sconosciuto '%s'" % id)
		return null
	if not _scenes.has(id):
		var path: String = ROOT + String(ENTRIES[id]["path"])
		_scenes[id] = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if _scenes[id] == null:
			push_warning("PolyhavenCatalog: modello mancante %s" % path)
	return _scenes[id]


static func tris(id: String) -> int:
	return int(ENTRIES[id]["tris"]) if ENTRIES.has(id) else 0


static func role(id: String) -> int:
	return int(ENTRIES[id]["role"]) if ENTRIES.has(id) else -1


## True se il modello è adatto al livello di qualità corrente (Quality.Level).
static func allowed(id: String, quality: int) -> bool:
	return ENTRIES.has(id) and quality >= int(ENTRIES[id]["min_quality"])


## Tutti gli id di un ruolo.
static func ids_for_role(r: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in ENTRIES:
		if int(ENTRIES[id]["role"]) == r:
			out.append(id)
	return out
