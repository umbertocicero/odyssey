class_name Stretcher
extends Node3D
## Barella: due stanghe con un telo teso. Il ferito grave ci sta sopra.

const POLE_LENGTH := 2.5
const WIDTH := 0.72   # distanza tra gli assi delle stanghe del modello
## Altezza delle stanghe da terra: quella del pugno dei portatori con il braccio disteso (HumanoidAnims).
const POLE_HEIGHT := 0.6
## Altezza del telo, dove giace il ferito.
const BED_HEIGHT := 0.6
## Barella creata con mesh.ai (campo/macchine/barella): stanghe lungo Z, origine sull'asse delle stanghe.
const MODEL_PATH := "res://assets/models/custom/campo/macchine/barella/barella.gltf"
const MODEL_LOD_PATH := "res://assets/models/custom/campo/macchine/barella/barella_lod.gltf"


func _ready() -> void:
	var path := MODEL_PATH if Quality.current() == Quality.Level.HIGH else MODEL_LOD_PATH
	var scene := load(path) as PackedScene
	if scene == null:
		return
	# Il modello è lungo 2,5 m lungo Z con l'origine sull'asse delle stanghe: basta alzarlo all'altezza dei pugni.
	var model := scene.instantiate() as Node3D
	model.position = Vector3(0.0, POLE_HEIGHT, 0.0)
	add_child(model)
