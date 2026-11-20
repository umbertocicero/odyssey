class_name GridUnit
extends CharacterBody3D
## Unità che si muove a passi sulla DioramaGrid (Ulisse, soldati achei, troiani).
## Il movimento è un tween da una cella all'altra; la cella occupata è
## registrata nella griglia, così le unità non si sovrappongono.

signal step_started(from_cell: Vector2i, to_cell: Vector2i)
signal step_finished(cell: Vector2i)

enum Team { ACHEI, TROIANI }

@export var team: Team = Team.ACHEI
## Durata di un passo, in secondi.
@export var step_duration := 0.18
## Nodo che contiene il modello: viene ruotato verso la direzione del passo.
@export var model_path: NodePath = ^"Model"

var grid: DioramaGrid
var cell := Vector2i.ZERO
var facing := Vector2i(0, 1)
var is_moving := false

@onready var _model: Node3D = get_node_or_null(model_path)


func _ready() -> void:
	add_to_group(&"units")
	add_to_group(&"achei" if team == Team.ACHEI else &"troiani")
	grid = get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	if grid == null:
		push_warning("%s: nessuna DioramaGrid nella scena." % name)
		return
	cell = grid.world_to_cell(global_position)
	global_position = grid.cell_to_world(cell)
	grid.occupy(cell, self)


## Prova a fare un passo nella direzione indicata (un asse della griglia).
## Restituisce true se il passo è partito.
func try_step(direction: Vector2i) -> bool:
	if is_moving or grid == null or direction == Vector2i.ZERO:
		return false
	face(direction)
	var target := cell + direction
	if not grid.is_walkable(target):
		return false

	var from := cell
	grid.release(cell, self)
	grid.occupy(target, self)
	cell = target
	is_moving = true
	step_started.emit(from, target)

	var tween := create_tween()
	tween.tween_property(self, "global_position", grid.cell_to_world(target), step_duration)
	tween.finished.connect(_on_step_finished)
	return true


func face(direction: Vector2i) -> void:
	facing = direction
	if _model:
		# Il modello guarda verso -Z (convenzione Godot).
		_model.rotation.y = atan2(-direction.x, -direction.y)


func _on_step_finished() -> void:
	is_moving = false
	step_finished.emit(cell)


func _exit_tree() -> void:
	if grid:
		grid.release(cell, self)
