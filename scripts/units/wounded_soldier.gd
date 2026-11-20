class_name WoundedSoldier
extends GridUnit
## Compagno ferito da portare in salvo. Giace a terra, bendato e sanguinante,
## finché qualcuno non gli si avvicina; poi viene sorretto e quasi trascinato
## (piegato in avanti, passo lento) da chi lo porta: Ulisse verso l'accampamento,
## un soldato alleato dall'accampamento alla riva. In salvo all'accampamento
## (SAVED), poi imbarcato (EVACUATED) su una barca che lo porta alla nave grande.
## Perso (LOST) se muore prima.

signal state_changed(new_state: int)

enum State { LYING, FOLLOWING, SAVED, LOST, CARRIED, EVACUATED, STRETCHER }

## Distanza (m) entro cui Ulisse "sveglia" il ferito: vale anche in diagonale,
## sotto una chioma o accanto a un oggetto (non conta la casella, ma lo spazio).
@export var wake_distance := 1.9
## Velocità massima (m/s) quando viene trascinato.
@export var drag_speed := 2.6
## Distanza (m) a cui sta dietro a chi lo sorregge.
@export var drag_offset := 0.8
@export var lean_angle := 0.38
## Un compagno entro questa distanza (m) da Ulisse lo aiuta a sorreggere il ferito.
@export var helper_range := 6.0

## Ferito grave: non cammina, lo portano quattro soldati su una barella.
var severe := false
var state: State = State.LYING
var camp_rect := Rect2i()
var leader: GridUnit
var _model_node: CharacterModel
var _dragging := false
var _helper_check := 0.0
var helper: AllySoldier


func _ready() -> void:
	step_duration = 0.4
	super._ready()
	_model_node = get_node_or_null(^"Model") as CharacterModel
	if _model_node:
		_model_node.sync_walk_to_step = false
	# Un frame dopo, quando il modello è pronto, lo sdraia a terra e lo benda.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	WoundedLook.apply(self)
	if state == State.LYING and _model_node:
		_model_node.play_death()


func is_targetable() -> bool:
	return state == State.LYING or state == State.FOLLOWING or state == State.CARRIED or state == State.STRETCHER


## Cammina sorretto da qualcuno (Ulisse o un alleato).
func is_supported() -> bool:
	return state == State.FOLLOWING or state == State.CARRIED


func _physics_process(delta: float) -> void:
	if state == State.LOST or state == State.EVACUATED or state == State.STRETCHER:
		return
	if state == State.SAVED:
		_set_dragging(false)
		return
	if state == State.LYING:
		_wake_check()
		return
	_drag(delta)
	if state == State.FOLLOWING:
		_helper_check -= delta
		if _helper_check <= 0.0:
			_helper_check = 0.3
			_refresh_helper()
	if state == State.FOLLOWING and camp_rect.has_point(cell):
		lie_down()
		_set_state(State.SAVED)


## Ulisse (se in vita) a distanza ravvicinata sveglia il ferito.
func _wake_check() -> void:
	if leader == null or not is_instance_valid(leader):
		leader = get_tree().get_first_node_in_group(&"player") as GridUnit
	if leader == null or leader.health <= 0:
		return
	var d := Vector2(leader.global_position.x - global_position.x, leader.global_position.z - global_position.z)
	if d.length() <= wake_distance:
		if severe:
			_set_state(State.STRETCHER)   # lo prende la squadra della barella
		else:
			start_support(leader, State.FOLLOWING)


## Il ferito si rialza e viene sorretto da `by`.
func start_support(by: GridUnit, new_state: State) -> void:
	leader = by
	if _model_node and _model_node.dead:
		_model_node.revive()
	_set_state(new_state)
	if by.has_method(&"set_carrying"):
		by.call(&"set_carrying", true)


## Smette di essere sorretto e si sdraia (in salvo, imbarco).
func lie_down() -> void:
	if leader and is_instance_valid(leader) and leader.has_method(&"set_carrying"):
		leader.call(&"set_carrying", false)
	_set_dragging(false)
	if _model_node:
		_model_node.play_death()


## Segue chi lo sorregge restando dietro di lui, a passo lento, quasi trascinato.
func _drag(delta: float) -> void:
	if leader == null or not is_instance_valid(leader) or grid == null:
		return
	var yaw := 0.0
	var lm := leader.get_node_or_null(^"Model") as Node3D
	if lm:
		yaw = lm.rotation.y
	var behind := Vector3(sin(yaw), 0.0, cos(yaw)) * drag_offset
	var target := leader.global_position + behind
	var to := Vector2(target.x - global_position.x, target.z - global_position.z)
	var moving := to.length() > 0.12
	if moving:
		var step := to.normalized() * minf(to.length(), drag_speed * delta)
		var wish := Vector2(global_position.x, global_position.z) + step
		var res := grid.resolve_circle(wish, 0.28, cell)
		var p: Vector2 = res["pos"]
		var y := grid.get_height_at_world(Vector3(p.x, 0.0, p.y))
		global_position = Vector3(p.x, lerpf(global_position.y, y, minf(1.0, 12.0 * delta)), p.y)
		_sync_cell()
	_set_dragging(moving)
	if _model:
		var face_to := Vector2(leader.global_position.x - global_position.x, leader.global_position.z - global_position.z)
		if face_to.length() > 0.05:
			_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-face_to.x, -face_to.y), minf(1.0, 8.0 * delta))
		_model.rotation.x = lerpf(_model.rotation.x, lean_angle, minf(1.0, 6.0 * delta))
	if _model_node and _model_node.player:
		_model_node.player.speed_scale = 0.55


## Cerca un compagno vivo e libero vicino a Ulisse: con il suo aiuto si va più veloci.
## Se sono lontani o morti, Ulisse prosegue da solo (più lento).
func _refresh_helper() -> void:
	if leader == null or not is_instance_valid(leader) or not leader.has_method(&"set_carrying"):
		return
	if helper != null and (not is_instance_valid(helper) or helper.health <= 0 or helper.busy \
			or helper.global_position.distance_to(leader.global_position) > helper_range * 1.3):
		helper = null
	if helper == null:
		var best := helper_range
		for n in get_tree().get_nodes_in_group(&"achei"):
			var a := n as AllySoldier
			if a == null or a.busy or a.health <= 0:
				continue
			var d := a.global_position.distance_to(leader.global_position)
			if d < best:
				best = d
				helper = a
	leader.call(&"set_carrying", true, helper != null)
	if helper != null:
		helper.follow_distance = 1


func _set_dragging(on: bool) -> void:
	_dragging = on
	is_moving = on
	if not on and _model:
		_model.rotation.x = lerpf(_model.rotation.x, lean_angle if is_supported() else 0.0, 0.2)
	if not is_supported() and _model:
		_model.rotation.x = 0.0


func _sync_cell() -> void:
	var now := grid.world_to_cell(global_position)
	if now == cell:
		return
	grid.release(cell, self)
	cell = now
	if grid.get_occupant(now) == null:
		grid.occupy(now, self)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(int(s))


## Salito sulla barca: sparisce dal campo (la barca lo porta alla nave).
## Messo a terra dalla barella: in salvo all'accampamento.
func mark_saved() -> void:
	_set_state(State.SAVED)


func mark_evacuated() -> void:
	if grid:
		grid.release(cell, self)
	_set_state(State.EVACUATED)
	visible = false
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true


func _on_died() -> void:
	if leader and is_instance_valid(leader) and leader.has_method(&"set_carrying"):
		leader.call(&"set_carrying", false)
	if grid:
		grid.release(cell, self)
	if _tween:
		_tween.kill()
	is_moving = false
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true
	if _model:
		_model.rotation.x = 0.0
	if _model_node:
		_model_node.play_death()
	remove_from_group(&"achei")
	_set_state(State.LOST)
