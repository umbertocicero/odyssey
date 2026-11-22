class_name UnitFactory
extends RefCounted
## Costruisce da codice le unità che compaiono durante il livello (troiani
## delle ondate, feriti) con il modello Blender e le animazioni.

const MODEL_TROIANO := "res://assets/models/custom/personaggi_nuovi/troiano_fanteria/troiano_fanteria.gltf"
const MODEL_ACHEO := "res://assets/models/custom/personaggi_nuovi/elpenore/elpenore.gltf"
## Varianti alternate a ogni unità creata (stesse animazioni e scheletro).
const TROJAN_VARIANTS := [MODEL_TROIANO]
const ACHAEAN_VARIANTS := [
	"res://assets/models/custom/personaggi_nuovi/filotete/filotete.gltf",
	"res://assets/models/custom/personaggi_nuovi/filotete_no_elmo/filotete_no_elmo.gltf",
	"res://assets/models/custom/personaggi_nuovi/perimede/perimede.gltf",
	"res://assets/models/custom/personaggi_nuovi/polite/polite.gltf",
	"res://assets/models/custom/personaggi_nuovi/euribate/euribate.gltf",
	MODEL_ACHEO,
	"res://assets/models/custom/personaggi_nuovi/euriloco/euriloco.gltf"]
const ACHAEAN_NAMES := ["PHILOCTETES", "PHILOCTETES", "PERIMEDES", "POLITES", "EURYBATES", "ELPENOR", "EURYLOCHUS"]

static var _trojan_count := 0
static var _achaean_count := 0


## Crea un'unità del tipo `script` (deve estendere GridUnit), non ancora nell'albero.
static func make(script: Script, model_path: String, team: GridUnit.Team, health: int, unit_name: String) -> GridUnit:
	var unit := script.new() as GridUnit
	unit.name = unit_name
	unit.team = team
	unit.max_health = health
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	shape.shape = capsule
	shape.position = Vector3(0, 0.7, 0)
	unit.add_child(shape)
	var model := CharacterModel.new()
	model.name = "Model"
	var chosen := model_path
	if model_path == MODEL_TROIANO:
		chosen = TROJAN_VARIANTS[_trojan_count % TROJAN_VARIANTS.size()]
		_trojan_count += 1
	elif model_path == MODEL_ACHEO:
		chosen = ACHAEAN_VARIANTS[_achaean_count % ACHAEAN_VARIANTS.size()]
		model.variant_name = ACHAEAN_NAMES[_achaean_count % ACHAEAN_NAMES.size()]
		_achaean_count += 1
	model.model_scene = load(chosen) as PackedScene
	# Gli achei (pochi, sempre vicini alla camera fissa) usano sempre il modello pieno: il _lod decimato
	# mostra calotta dei capelli frastagliata, collo staccato e texture a blocchi da vicino.
	if int(Quality.current()) < 2 and model_path != MODEL_ACHEO and not unit is WoundedSoldier:
		var lod_path := chosen.replace("personaggi_nuovi/", "personaggi_nuovi/").replace(chosen.get_file().get_basename() + ".gltf", chosen.get_file().get_basename() + "_lod.gltf").replace("/" + chosen.get_file().get_basename() + "/", "/" + chosen.get_file().get_basename() + "_lod/")
		if ResourceLoader.exists(lod_path):
			model.model_scene = load(lod_path) as PackedScene
	unit.add_child(model)
	# Armi in mano: lancia ai troiani, xiphos agli achei in piedi (i feriti giacciono, senza arma).
	var gear := UnitGear.new()
	gear.shield_aligned = false
	gear.min_quality = 1
	if team == GridUnit.Team.TROIANI:
		gear.weapon_path = "res://assets/models/custom/armi/lancia/lancia.gltf"
		gear.weapon_lod_path = "res://assets/models/custom/armi/lancia/lancia_lod.gltf"
		gear.weapon_kind = UnitGear.WeaponKind.SPEAR
	elif not unit is WoundedSoldier:
		gear.weapon_path = "res://assets/models/custom/armi/xiphos/xiphos.gltf"
		gear.weapon_lod_path = "res://assets/models/custom/armi/xiphos/xiphos_lod.gltf"
		gear.weapon_adjust_degrees = Vector3(62, 35, 0)
	if gear.weapon_path != "":
		model.add_child(gear)
	return unit
