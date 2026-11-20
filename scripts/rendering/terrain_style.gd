class_name TerrainStyle
extends RefCounted
## Stile del terreno del livello 1: fotorealistico (mesh e texture PBR in
## assets/models/custom/terreno/ più erba a cards) oppure il vecchio terreno
## procedurale (box colorati + GrassField). Si può forzare da riga di comando
## (`-- --terrain=procedural|photo`) o con la variabile d'ambiente
## ODYSSEY_TERRAIN. Senza forzature vale il fotorealistico.

static var _photo := -1


static func photo() -> bool:
	if _photo >= 0:
		return _photo == 1
	var wanted := OS.get_environment("ODYSSEY_TERRAIN").to_lower()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--terrain="):
			wanted = arg.substr(10).to_lower()
	_photo = 0 if wanted == "procedural" else 1
	return _photo == 1


## Forza lo stile (test, menu opzioni). Va chiamato prima di creare il livello.
static func set_photo(value: bool) -> void:
	_photo = 1 if value else 0
