class_name WoundedSoldier
extends GridUnit
## Compagno ferito da portare in salvo. Giace a terra, bendato e sanguinante,
## finché Ulisse non gli si avvicina; poi si rialza e cammina zoppicando al suo fianco, con il
## braccio attorno al suo collo, sorretto da lui (Ulisse gli cinge la vita). Se un compagno
## incontrato per strada si affianca, il ferito sta al centro e le sue braccia vanno attorno
## alle spalle di entrambi. Nessuno compare dal nulla e la barella non si usa. Dall'accampamento
## alla riva lo porta un soldato alleato (già presente), sempre al suo fianco. In salvo all'accampamento
## (SAVED), poi imbarcato (EVACUATED) su una barca che lo porta alla nave grande.
## Perso (LOST) se muore prima.

signal state_changed(new_state: int)
## Un compagno si è affiancato a Ulisse per aiutarlo a sorreggere il ferito.
signal helper_joined(by: AllySoldier)

enum State { LYING, FOLLOWING, SAVED, LOST, CARRIED, EVACUATED, STRETCHER }

## Distanza (m) entro cui Ulisse "sveglia" il ferito: vale anche in diagonale,
## sotto una chioma o accanto a un oggetto (non conta la casella, ma lo spazio).
@export var wake_distance := 1.9
## Velocità massima (m/s) quando viene trascinato.
@export var drag_speed := 4.2
## Distanza (m) a cui sta dietro a chi lo sorregge.
@export var drag_offset := 0.72
## Inclinazione in avanti dell'intero modello quando è sorretto (il resto lo fa l'animazione zoppa).
@export var lean_angle := 0.06
## Un compagno entro questa distanza (m) dal ferito va ad affiancarsi a Ulisse.
@export var helper_range := 6.0
## Il compagno si affianca (ferito al centro) quando è a questa distanza (m) dal ferito.
@export var handover_distance := 1.5

## Ferito grave (solo informativo: si porta come gli altri, niente barella).
var severe := false
var state: State = State.LYING
var camp_rect := Rect2i()
var leader: GridUnit
var _model_node: CharacterModel
var _dragging := false
var _helper_check := 0.0
var helper: AllySoldier
var _helper_prev_leader: GridUnit
var _helper_prev_follow := 2
## Il compagno è già affiancato (cammina dall'altra parte del ferito).
var _helper_joined := false
var _cur_stance: StringName = &"limp"


func _ready() -> void:
	step_duration = 0.4
	super._ready()
	_model_node = get_node_or_null(^"Model") as CharacterModel
	if _model_node:
		_model_node.set_stance(&"limp")
	# Un frame dopo, quando il modello è pronto, lo sdraia a terra e lo benda.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if state == State.LYING and _model_node:
		_model_node.play_lying(true)


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
		_update_stance()
		return
	if state == State.LYING:
		_wake_check()
		return
	_drag(delta)
	_update_stance()
	if state == State.FOLLOWING:
		_helper_check -= delta
		if _helper_check <= 0.0:
			_helper_check = 0.3
			_refresh_helper()
	if state == State.FOLLOWING and camp_rect.has_point(cell):
		# In salvo: resta in piedi, accasciato, finché un soldato non lo prende in consegna
		# (niente "butta giù e rialza": a terra va solo sulla barca).
		release_support()
		_drop_helper()
		_set_state(State.SAVED)


## Ulisse (se in vita) a distanza ravvicinata sveglia il ferito.
func _wake_check() -> void:
	if leader == null or not is_instance_valid(leader):
		leader = get_tree().get_first_node_in_group(&"player") as GridUnit
	if leader == null or leader.health <= 0:
		return
	var d := Vector2(leader.global_position.x - global_position.x, leader.global_position.z - global_position.z)
	if d.length() <= wake_distance and not _leader_busy():
		start_support(leader, State.FOLLOWING)


## Ulisse sorregge già un altro ferito: questo aspetta (si porta un ferito alla volta).
func _leader_busy() -> bool:
	for n in get_tree().get_nodes_in_group(&"achei"):
		var o := n as WoundedSoldier
		if o != null and o != self and o.leader == leader and (o.state == State.FOLLOWING or o.state == State.CARRIED):
			return true
	return false


## Stance del ferito in base a chi lo sorregge: Ulisse gli sta a sinistra, un compagno incontrato a destra.
func _update_stance() -> void:
	if _model_node == null:
		return
	var want := &"limp"
	if is_supported() and leader != null and is_instance_valid(leader):
		var left := leader.is_in_group(&"player")
		var right := not left or _helper_joined
		want = &"limp_lr" if (left and right) else (&"limp_l" if left else &"limp_r")
	if want != _cur_stance:
		_cur_stance = want
		_model_node.set_stance(want)


## Il ferito si rialza e viene sorretto da `by`.
func start_support(by: GridUnit, new_state: State) -> void:
	if leader != null and leader != by and is_instance_valid(leader) and leader.has_method(&"set_carrying"):
		leader.call(&"set_carrying", false)   # chi lo sorreggeva prima si libera
	leader = by
	if _model_node and _model_node.dead:
		_model_node.revive()
	_set_state(new_state)
	if by.has_method(&"set_carrying"):
		by.call(&"set_carrying", true)


## Chi lo sorregge lo lascia, ma il ferito resta in piedi (accasciato).
func release_support() -> void:
	if leader and is_instance_valid(leader) and leader.has_method(&"set_carrying"):
		leader.call(&"set_carrying", false)
	_set_dragging(false)


## Smette di essere sorretto e si sdraia (imbarco).
func lie_down() -> void:
	if leader and is_instance_valid(leader) and leader.has_method(&"set_carrying"):
		leader.call(&"set_carrying", false)
	_set_dragging(false)
	if _model_node:
		_model_node.play_lying()


## Segue chi lo sorregge restando dietro di lui, a passo lento, quasi trascinato.
var _stuck_time := 0.0
var _last_pos := Vector2.ZERO
var _detour_until := 0.0


## Prossima casella di un percorso sulla griglia (BFS a 4 direzioni) da `from` a `goal`; Vector2i(-1,-1) se non c'è.
func _next_cell_towards(from: Vector2i, goal: Vector2i) -> Vector2i:
	if from == goal:
		return goal
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size() and prev.size() < 2500:
		var cur: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if prev.has(n) or not grid.is_inside(n):
				continue
			if n != goal and grid.is_blocked(n):
				continue
			prev[n] = cur
			if n == goal:
				var step := n
				while prev[step] != from:
					step = prev[step]
				return step
			queue.append(n)
	return Vector2i(-1, -1)


func _drag(delta: float) -> void:
	if leader == null or not is_instance_valid(leader) or grid == null:
		return
	var yaw := 0.0
	var lm := leader.get_node_or_null(^"Model") as Node3D
	if lm:
		yaw = lm.rotation.y
	# Cammina al fianco di chi lo sorregge (Ulisse: alla sua destra; un soldato: alla sua sinistra).
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var side := 1.0 if leader.is_in_group(&"player") else -1.0
	var target := leader.global_position + right * (HumanoidAnims.CARRY_SIDE * side)
	var to := Vector2(target.x - global_position.x, target.z - global_position.z)
	# Se la linea retta lo blocca (muri, palizzate, ostacoli) cerca un percorso sulla griglia.
	var here := Vector2(global_position.x, global_position.z)
	_stuck_time = _stuck_time + delta if here.distance_to(_last_pos) < drag_speed * delta * 0.25 and to.length() > 1.2 else 0.0
	_last_pos = here
	var now := Time.get_ticks_msec() / 1000.0
	if _stuck_time > 0.6:
		_detour_until = now + 1.5
		_stuck_time = 0.0
	if now < _detour_until:
		var next := _next_cell_towards(cell, leader.get("cell") if leader.get("cell") != null else cell)
		if next != Vector2i(-1, -1):
			var w := grid.cell_to_world(next)
			to = Vector2(w.x - global_position.x, w.z - global_position.z)
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
		# Guarda dove va chi lo sorregge (stessa direzione, fianco a fianco).
		_model.rotation.y = lerp_angle(_model.rotation.y, yaw, minf(1.0, 8.0 * delta))
		_model.rotation.x = lerpf(_model.rotation.x, lean_angle, minf(1.0, 6.0 * delta))
	if _helper_joined:
		_move_helper(delta, yaw, right)


## Il compagno affiancato cammina dall'altra parte del ferito (che resta al centro), fianco a fianco.
func _move_helper(delta: float, yaw: float, right: Vector3) -> void:
	var h := helper
	if h == null or not is_instance_valid(h) or h.health <= 0:
		return
	var target := leader.global_position + right * (HumanoidAnims.CARRY_SIDE * 2.0)
	var to := Vector2(target.x - h.global_position.x, target.z - h.global_position.z)
	var moving := to.length() > 0.12
	if moving:
		var step := to.normalized() * minf(to.length(), drag_speed * delta)
		var wish := Vector2(h.global_position.x, h.global_position.z) + step
		var res := grid.resolve_circle(wish, 0.28, h.cell)
		var p: Vector2 = res["pos"]
		var y := grid.get_height_at_world(Vector3(p.x, 0.0, p.y))
		h.global_position = Vector3(p.x, lerpf(h.global_position.y, y, minf(1.0, 12.0 * delta)), p.y)
		var now := grid.world_to_cell(h.global_position)
		if now != h.cell:
			grid.release(h.cell, h)
			h.cell = now
			if grid.get_occupant(now) == null:
				grid.occupy(now, h)
	h.is_moving = moving
	var hm := h.get_node_or_null(^"Model") as Node3D
	if hm:
		hm.rotation.y = lerp_angle(hm.rotation.y, yaw, minf(1.0, 8.0 * delta))


## Cerca il compagno vivo e libero più vicino (entro helper_range) e lo fa venire a dare il cambio a Ulisse.
## Con un compagno in arrivo Ulisse va più veloce; appena il compagno è accanto al ferito lo prende in
## consegna (scambio di sostegno): Ulisse si libera, il ferito non cade e non si rialza.
func _refresh_helper() -> void:
	if leader == null or not is_instance_valid(leader) or not leader.has_method(&"set_carrying"):
		return
	if helper != null and (not is_instance_valid(helper) or helper.health <= 0 \
			or (_helper_joined and global_position.distance_to(helper.global_position) > 3.0) \
			or (not _helper_joined and (helper.busy or global_position.distance_to(helper.global_position) > helper_range * 1.5))):
		_drop_helper()
	if helper == null:
		var best := helper_range
		for n in get_tree().get_nodes_in_group(&"achei"):
			var a := n as AllySoldier
			if a == null or a.busy or a.health <= 0:
				continue
			var d := a.global_position.distance_to(global_position)
			if d < best:
				best = d
				helper = a
		if helper != null:
			_helper_prev_leader = helper.leader
			_helper_prev_follow = helper.follow_distance
			helper.leader = self            # va incontro al ferito
			helper.follow_distance = 1
	leader.call(&"set_carrying", true, helper != null)
	if helper != null and not _helper_joined and _dist_xz(helper) <= handover_distance:
		_join_helper()


func _dist_xz(u: Node3D) -> float:
	return Vector2(u.global_position.x - global_position.x, u.global_position.z - global_position.z).length()


func _drop_helper() -> void:
	if helper != null and is_instance_valid(helper):
		if _helper_joined:
			helper.busy = false
			helper.is_moving = false
			helper.set_carrying(false)
		if helper.leader == self:
			helper.leader = _helper_prev_leader if _helper_prev_leader != null and is_instance_valid(_helper_prev_leader) \
				else get_tree().get_first_node_in_group(&"player") as GridUnit
		helper.follow_distance = _helper_prev_follow
	helper = null
	_helper_joined = false


## Il compagno arrivato accanto si affianca a Ulisse: il ferito resta al centro, braccia attorno a entrambi.
func _join_helper() -> void:
	_helper_joined = true
	helper.busy = true
	helper.set_carrying(true)
	helper_joined.emit(helper)


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
	_drop_helper()
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
