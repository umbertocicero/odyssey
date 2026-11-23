extends GridUnit
## Ulisse, controllato dal giocatore. Si muove in modo libero e continuo
## (stick analogico o tasti, anche in diagonale) come un cerchio che scivola
## lungo gli ostacoli: passa sotto le chiome degli alberi, costeggia pali e
## lampioni senza incastrarsi e scavalca con un balzo gli ostacoli bassi.
##
## I comandi sono relativi alla camera: "su" è verso l'alto dello schermo.
## Su mobile uno swipe lo fa camminare in quella direzione per un attimo.
## La griglia resta la mappa logica: la sua casella si aggiorna da sola.
## try_step() (passo a casella) resta disponibile per test e cutscene.
## Ha più vita dei soldati (max_health nella scena).

signal action_requested(action: StringName)

## Lunghezza minima di uno swipe, in pixel.
@export var swipe_min_distance := 40.0

## Casella in cui Ulisse riappare se viene sconfitto (prototipo).
var spawn_cell := Vector2i.ZERO
## Vero mentre gioca l'animazione di morte: i comandi sono bloccati.
var is_defeated := false
## Danno e ritmo dell'attacco con la spada (sulla casella davanti a Ulisse).
@export var attack_damage := 30
@export var attack_cooldown := 0.5
## Movimento libero: velocità (m/s), raggio del corpo e portata della spada.
@export var move_speed := 4.4
@export var body_radius := 0.3
@export var attack_range := 1.7
@export var turn_speed := 14.0

## Moltiplicatore di velocità: scende mentre Ulisse sorregge un ferito.
var speed_multiplier := 1.0
## Velocità mentre sorregge un ferito: con un compagno che aiuta / da solo.
@export var carry_speed_helped := 0.70
@export var carry_speed_alone := 0.55

var _attack_cd := 0.0
var _touch_start := Vector2.ZERO
var _queued_swipe := Vector2.ZERO
var _swipe_dir := Vector2.ZERO
var _swipe_time := 0.0
var _face_yaw := 0.0


func _ready() -> void:
	add_to_group(&"player")
	# Ulisse passa attraverso i suoi soldati scambiandosi di posto.
	can_swap_with_allies = true
	super._ready()
	if _model:
		_face_yaw = _model.rotation.y
	spawn_cell = cell
	if grid:
		grid.validate_connectivity(cell)


## Chiamato dal ferito quando comincia o smette di essere sorretto da Ulisse.
func set_carrying(on: bool, helped := false) -> void:
	if not on:
		speed_multiplier = 1.0
	else:
		speed_multiplier = carry_speed_helped if helped else carry_speed_alone
	var model := get_node_or_null(^"Model") as CharacterModel
	if model:
		model.set_stance(&"carry_r" if on else &"normal")


## Ulisse non sparisce: nel prototipo riappare all'accampamento con la vita piena.
func _on_died() -> void:
	is_defeated = true
	if _tween:
		_tween.kill()
	is_moving = false
	# Il modello recita la morte (CharacterModel la avvia dal segnale died).
	var model := get_node_or_null(^"Model") as CharacterModel
	var wait := 0.1
	if model:
		wait = model.anim_length(model.anim_death) + 0.5
	await get_tree().create_timer(wait).timeout
	if not is_inside_tree():
		return
	var target := _nearest_free_cell(spawn_cell)
	place_at(target)
	heal_full()
	is_defeated = false
	if model:
		model.revive()
	print("Ulisse è stato sconfitto: riparte dall'accampamento.")


func _nearest_free_cell(from: Vector2i) -> Vector2i:
	if grid == null or grid.is_walkable(from) or from == cell:
		return from
	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c := from + Vector2i(dx, dy)
				if grid.is_walkable(c):
					return c
	return cell


func _physics_process(delta: float) -> void:
	if is_defeated:
		return
	_attack_cd -= delta
	for action: StringName in [&"attack", &"parry", &"dodge", &"interact", &"special"]:
		if Input.is_action_just_pressed(action):
			# Combattimento e interazioni non sono ancora implementati.
			action_requested.emit(action)
			if action == &"attack":
				_melee_attack()

	if _tween and _tween.is_running():
		return # balzo o passo a casella in corso
	_free_move(delta)


## Movimento continuo: direzione dall'input in coordinate di schermo, convertita
## nel mondo secondo la camera, poi collisione con scivolamento.
func _free_move(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input == Vector2.ZERO and _queued_swipe != Vector2.ZERO:
		_swipe_dir = _queued_swipe
		_swipe_time = 0.35
	_queued_swipe = Vector2.ZERO
	if input == Vector2.ZERO and _swipe_time > 0.0:
		_swipe_time -= delta
		input = _swipe_dir
	var dir := screen_to_world_direction(input)
	var walking := dir != Vector3.ZERO and grid != null
	if walking:
		var start := Vector2(global_position.x, global_position.z)
		var wish := start + Vector2(dir.x, dir.z) * move_speed * speed_multiplier * delta
		var result := grid.resolve_circle(wish, body_radius, cell)
		var end: Vector2 = result["pos"]
		var travelled := (end - start).length()
		var vault_cell = result["vault_cell"]
		if vault_cell != null and can_vault:
			var axis := _dominant_axis(dir)
			if vault_cell == cell + axis and Vector2(dir.x, dir.z).dot(Vector2(axis)) > 0.55 \
					and grid.can_vault_over(cell, axis):
				face(axis)
				if _model:
					_face_yaw = _model.rotation.y
				_vault(axis)
				return
		var climb_cell = result.get("climb_cell")
		if climb_cell != null and can_climb:
			var caxis := _dominant_axis(dir)
			if climb_cell == cell + caxis and Vector2(dir.x, dir.z).dot(Vector2(caxis)) > 0.55 \
					and grid.can_climb_over(cell, caxis):
				face(caxis)
				if _model:
					_face_yaw = _model.rotation.y
				_climb(caxis)
				return
		if travelled > 0.0005:
			var y := grid.get_height_at_world(Vector3(end.x, 0.0, end.y))
			global_position = Vector3(end.x, lerpf(global_position.y, y, minf(1.0, 14.0 * delta)), end.y)
			_sync_cell()
		_face_yaw = atan2(-dir.x, -dir.z)
		walking = travelled > delta * move_speed * speed_multiplier * 0.15
	is_moving = walking
	if _model:
		_model.rotation.y = lerp_angle(_model.rotation.y, _face_yaw, minf(1.0, turn_speed * delta))
		var axis := _dominant_axis(Vector3(-sin(_model.rotation.y), 0.0, -cos(_model.rotation.y)))
		facing = axis


## Mantiene allineata la casella logica alla posizione reale.
func _sync_cell() -> void:
	var now := grid.world_to_cell(global_position)
	if now == cell:
		return
	grid.release(cell, self)
	cell = now
	if grid.get_occupant(now) == null:
		grid.occupy(now, self)
	step_finished.emit(cell)


func _dominant_axis(dir: Vector3) -> Vector2i:
	if absf(dir.x) >= absf(dir.z):
		return Vector2i(roundi(signf(dir.x)), 0)
	return Vector2i(0, roundi(signf(dir.z)))


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_touch_start = touch.position
	else:
		var swipe := touch.position - _touch_start
		if swipe.length() >= swipe_min_distance:
			_queued_swipe = swipe.normalized()


## Direzione sullo schermo (x a destra, y in basso) -> direzione nel mondo (XZ),
## senza arrotondarla agli assi: il movimento è analogico.
func screen_to_world_direction(screen_direction: Vector2) -> Vector3:
	if screen_direction == Vector2.ZERO:
		return Vector3.ZERO
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	var camera := get_viewport().get_camera_3d()
	if camera:
		right = camera.global_basis.x
		forward = -camera.global_basis.z
	right = Vector3(right.x, 0.0, right.z).normalized()
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	var world := right * screen_direction.x - forward * screen_direction.y
	return world.limit_length(1.0)


## Converte una direzione sullo schermo (x a destra, y in basso) nell'asse
## della griglia che le somiglia di più, tenendo conto dell'orientamento della camera.
func screen_to_grid_direction(screen_direction: Vector2) -> Vector2i:
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	var camera := get_viewport().get_camera_3d()
	if camera:
		right = camera.global_basis.x
		forward = -camera.global_basis.z
	right = Vector3(right.x, 0.0, right.z).normalized()
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	var world := right * screen_direction.x - forward * screen_direction.y
	if absf(world.x) >= absf(world.z):
		return Vector2i(roundi(signf(world.x)), 0)
	return Vector2i(0, roundi(signf(world.z)))


## Colpisce il nemico più vicino davanti a Ulisse (o molto vicino, anche di lato).
func _melee_attack() -> void:
	if _attack_cd > 0.0 or grid == null:
		return
	_attack_cd = attack_cooldown
	var forward := Vector3(-sin(_face_yaw), 0.0, -cos(_face_yaw))
	var best: GridUnit = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"troiani"):
		var unit := node as GridUnit
		if unit == null or unit.health <= 0:
			continue
		var to := unit.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > attack_range:
			continue
		var front := to.normalized().dot(forward) if dist > 0.001 else 1.0
		if front < 0.0 and dist > attack_range * 0.6:
			continue # dietro le spalle e lontano
		var score := dist - front * 0.5
		if score < best_score:
			best_score = score
			best = unit
	if best:
		var to := best.global_position - global_position
		_face_yaw = atan2(-to.x, -to.z)
		melee_strike(best, attack_damage)
