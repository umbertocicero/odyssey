class_name IdleFigure
extends Node3D
## Comparsa ferma (capi e ufficiali del campo): istanzia un personaggio riggato e ne gioca l'animazione
## di riposo. Non è una unità di gioco: niente collisioni né griglia. Da `min_quality` in su; a qualità
## bassa e media usa la versione leggera (`lod_path`), se c'è. Il modello si carica solo quando serve.

@export_file("*.gltf", "*.glb") var model_path := ""
@export_file("*.gltf", "*.glb") var lod_path := ""
@export_range(0, 2) var min_quality := 1
@export var idle_animation := &"idle"
## Nome mostrato (HUD, debug), in inglese.
@export var display_name := ""

var instance: Node3D


func _ready() -> void:
	if int(Quality.current()) < min_quality or model_path == "":
		return
	var path := model_path
	if lod_path != "" and Quality.current() != Quality.Level.HIGH:
		path = lod_path
	var scene := load(path) as PackedScene
	if scene == null:
		return
	instance = scene.instantiate() as Node3D
	add_child(instance)
	for p in instance.find_children("*", "AnimationPlayer", true, false):
		var player := p as AnimationPlayer
		if player.has_animation(idle_animation):
			player.play(idle_animation)
		break
