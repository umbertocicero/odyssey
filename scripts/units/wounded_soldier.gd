class_name WoundedSoldier
extends GridUnit
## Compagno ferito da portare in salvo. Giace a terra finché Ulisse non gli si
## avvicina; poi lo segue verso l'accampamento. In salvo quando entra nell'area
## dell'accampamento; perso se muore prima.

signal state_changed(new_state: int)

enum State { LYING, FOLLOWING, SAVED, LOST }

@export var follow_distance := 1
@export var think_interval := 0.2

var state: State = State.LYING
var camp_rect := Rect2i()
var leader: GridUnit
var _think := 0.0
var _model_node: CharacterModel


func _ready() -> void:
	step_duration = 0.22
	super._ready()
	_model_node = get_node_or_null(^"Model") as CharacterModel
	# Un frame dopo, quando il modello è pronto, lo sdraia a terra.
	await get_tree().process_frame
	if state == State.LYING and _model_node:
		_model_node.play_death()


func is_targetable() -> bool:
	return state == State.LYING or state == State.FOLLOWING


func _physics_process(delta: float) -> void:
	if state == State.LOST or state == State.SAVED:
		return
	if leader == null or not is_instance_valid(leader):
		leader = get_tree().get_first_node_in_group(&"player") as GridUnit
		if leader == null:
			return
	if state == State.LYING:
		var d := leader.cell - cell
		if absi(d.x) + absi(d.y) <= 1 and leader.health > 0:
			_set_state(State.FOLLOWING)
			if _model_node:
				_model_node.revive()
		return
	# FOLLOWING
	if camp_rect.has_point(cell):
		_set_state(State.SAVED)
		return
	if is_moving:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = think_interval
	var diff := leader.cell - cell
	if absi(diff.x) + absi(diff.y) <= follow_distance:
		return
	var primary := Vector2i(signi(diff.x), 0) if absi(diff.x) >= absi(diff.y) else Vector2i(0, signi(diff.y))
	var secondary := Vector2i(0, signi(diff.y)) if primary.x != 0 else Vector2i(signi(diff.x), 0)
	if not try_step(primary) and secondary != Vector2i.ZERO:
		try_step(secondary)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(int(s))


func _on_died() -> void:
	if grid:
		grid.release(cell, self)
	if _tween:
		_tween.kill()
	is_moving = false
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true
	if _model_node:
		_model_node.play_death()
	remove_from_group(&"achei")
	_set_state(State.LOST)
