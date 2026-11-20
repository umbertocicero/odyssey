class_name UnitFactory
extends RefCounted
## Costruisce da codice le unità che compaiono durante il livello (troiani
## delle ondate, feriti) con il modello Blender e le animazioni.

const MODEL_TROIANO := "res://assets/models/custom/personaggi/ufficiale_troiano.glb"
const MODEL_ACHEO := "res://assets/models/custom/personaggi/oplita_acheo.glb"


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
	model.model_scene = load(model_path) as PackedScene
	unit.add_child(model)
	return unit
