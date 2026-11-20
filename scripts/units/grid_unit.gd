class_name GridUnit
extends CharacterBody3D
## Unità che si muove a passi sulla DioramaGrid (Ulisse, soldati achei, troiani).
## Il movimento è un tween da una cella all'altra; la cella occupata è
## registrata nella griglia, così le unità non si sovrappongono.
##
## Se can_swap_with_allies è attivo (Ulisse), quando la casella di arrivo è
## occupata da un alleato fermo, le due unità si scambiano di posto: gli
## alleati non possono mai chiudere la strada a Ulisse.

signal step_started(from_cell: Vector2i, to_cell: Vector2i)
signal step_finished(cell: Vector2i)

enum Team { ACHEI, TROIANI }

@export var team: Team = Team.ACHEI
## Durata di un passo, in secondi.
@export var step_duration := 0.18
## Se attivo, può scambiarsi di posto con un alleato fermo che gli sbarra la strada.
@export var can_swap_with_allies := false
## Nodo che contiene il modello: viene ruotato verso la direzione del passo.
@export var model_path: NodePath = ^"Model"

var grid: DioramaGrid
var cell := Vector2i.ZERO
var facing := Vector2i(0, 1)
var is_moving := false

var _tween: Tween

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


## True se questa unità può entrare nella casella (libera, oppure occupata
## da un alleato fermo con cui scambiarsi di posto).
func can_enter(target: Vector2i) -> bool:
	if grid == null or not grid.is_inside(target) or grid.is_blocked(target):
		return false
	var other := grid.get_occupant(target)
	if other == null:
		return true
	return _can_swap_with(other)


## Prova a fare un passo nella direzione indicata (un asse della griglia).
## Restituisce true se il passo è partito.
func try_step(direction: Vector2i) -> bool:
	if is_moving or grid == null or direction == Vector2i.ZERO:
		return false
	face(direction)
	var target := cell + direction
	if not can_enter(target):
		return false

	var from := cell
	var other := grid.get_occupant(target) as GridUnit
	grid.release(from, self)
	if other:
		# Scambio di posto con l'alleato.
		grid.release(target, other)
		other.cell = from
		grid.occupy(from, other)
		other.face(-direction)
		other._move_to(from)
	grid.occupy(target, self)
	cell = target
	step_started.emit(from, target)
	_move_to(target)
	return true


## Sposta istantaneamente l'unità in una casella (spawn, cutscene, test).
func place_at(target: Vector2i) -> bool:
	if grid == null or not grid.is_walkable(target):
		return false
	if _tween:
		_tween.kill()
	is_moving = false
	grid.release(cell, self)
	cell = target
	grid.occupy(cell, self)
	global_position = grid.cell_to_world(cell)
	return true


func face(direction: Vector2i) -> void:
	facing = direction
	if _model:
		# Il modello guarda verso -Z (convenzione Godot).
		_model.rotation.y = atan2(-direction.x, -direction.y)


func _can_swap_with(other: Node) -> bool:
	var unit := other as GridUnit
	return can_swap_with_allies and unit != null and unit != self \
		and unit.team == team and not unit.is_moving


func _move_to(target: Vector2i) -> void:
	is_moving = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", grid.cell_to_world(target), step_duration)
	_tween.finished.connect(_on_step_finished)


func _on_step_finished() -> void:
	is_moving = false
	step_finished.emit(cell)


func _exit_tree() -> void:
	if grid:
		grid.release(cell, self)
