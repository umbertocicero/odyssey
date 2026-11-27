class_name LevelDirector
extends Node
## Regia del livello 1: sopravvivere fino al segnale di ritirata mentre
## ondate di troiani sempre più forti avanzano e si salvano i compagni feriti.
## Il livello finisce con una ritirata (sconfitta narrativa) che porta al livello 2.

signal wave_started(number: int, trojan_count: int)
signal wounded_changed(saved: int, lost: int, total: int)
signal wounded_evacuated(count: int, total: int)
signal time_changed(seconds_left: float)
signal level_finished(summary: Dictionary)
## Un tentativo è finito (Ulisse è caduto): `attempt` è il numero del nuovo tentativo.
signal attempt_changed(attempt: int, max_attempts: int)
## Tre tentativi esauriti: si ricomincia da capo (stato iniziale, punteggio azzerato).
signal full_restart

enum Phase { IDLE, RUNNING, ENDED }

@export var rules: LevelRules
## Scena del livello 2 a cui si passa dopo la schermata finale.
@export_file("*.tscn") var next_level_path := "res://scenes/main/main_level2.tscn"
## Avvia da solo il livello all'ingresso nella scena.
@export var auto_start := true

var phase: Phase = Phase.IDLE
var elapsed := 0.0
var wave := 0
var kills := 0
var summary := {}
var wounded: Array[WoundedSoldier] = []
var hud: LevelHud
## Tentativo corrente (1..max_attempts); il terzo fallimento riporta tutto allo stato iniziale.
var attempt := 1
@export_range(1, 9) var max_attempts := 3
## Se vero, il riavvio completo ricarica la scena (spento nei test).
@export var reload_on_full_restart := true
var ferry: FerrySystem

var _grid: DioramaGrid
var _player: GridUnit
var _units_root: Node
var _next_wave_at := 0.0
var _saved := 0
var _lost := 0
var _unreachable := {}


func _ready() -> void:
	if rules == null:
		rules = LevelRules.new()
	await get_tree().process_frame
	await get_tree().process_frame
	_grid = get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	_player = get_tree().get_first_node_in_group(&"player") as GridUnit
	if _grid == null or _player == null:
		push_warning("LevelDirector: griglia o Ulisse mancanti.")
		return
	_units_root = _player.get_parent()
	var ui := get_parent().get_node_or_null(^"UI")
	if ui:
		hud = LevelHud.new()
		hud.name = "LevelHud"
		ui.add_child(hud)
		hud.continue_pressed.connect(_on_continue)
	if auto_start:
		start()


func start() -> void:
	if phase != Phase.IDLE:
		return
	phase = Phase.RUNNING
	elapsed = 0.0
	wave = 0
	kills = 0
	_saved = 0
	_lost = 0
	_next_wave_at = rules.first_wave_delay
	_spawn_wounded()
	_setup_ferry()
	if _player and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	_apply_defence_scaling(1)
	for node in get_tree().get_nodes_in_group(&"troiani"):
		var u := node as GridUnit
		if u and not u.died.is_connected(_on_trojan_died):
			u.died.connect(_on_trojan_died)
	if hud:
		hud.show_banner("Find the wounded and bring them to the ships!", 3.5)
	wounded_changed.emit(_saved, _lost, wounded.size())
	time_changed.emit(rules.duration)


func _process(delta: float) -> void:
	if phase != Phase.RUNNING:
		return
	elapsed += delta
	var left := maxf(rules.duration - elapsed, 0.0)
	time_changed.emit(left)
	if hud:
		hud.set_time(left, wave)
		hud.set_attempt(attempt, max_attempts)
	if elapsed >= _next_wave_at:
		_start_wave()
		_next_wave_at += rules.wave_interval
	_resolve_check -= delta
	if _resolve_check <= 0.0:
		_resolve_check = 0.5
		if all_wounded_resolved():
			finish()
			return
	if left <= 0.0:
		finish()


## Ulisse è caduto: tentativo successivo; dopo l'ultimo si ricomincia tutto da capo.
func _on_player_died() -> void:
	if phase != Phase.RUNNING:
		return
	if attempt >= max_attempts:
		full_restart.emit()
		if hud:
			hud.show_banner("All attempts used - starting over...", 3.0)
		if reload_on_full_restart:
			phase = Phase.ENDED
			await get_tree().create_timer(3.0).timeout
			get_tree().reload_current_scene()
		else:
			attempt = 1
		return
	attempt += 1
	attempt_changed.emit(attempt, max_attempts)
	if hud:
		hud.show_banner("Attempt %d of %d" % [attempt, max_attempts], 2.5)


var _resolve_check := 1.0


## Tutti i feriti sono stati portati sulle navi o sono morti: solo allora il livello finisce (riepilogo con salvati e persi).
## I feriti morti NON contano: il livello continua finché Ulisse non li recupera tutti o non muore.
func all_wounded_resolved() -> bool:
	if wounded.is_empty():
		return false
	for w in wounded:
		if w.state != WoundedSoldier.State.EVACUATED and w.state != WoundedSoldier.State.LOST:
			return false
	return true


func alive_trojans() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(&"troiani"):
		var u := node as TrojanSoldier
		if u and u.health > 0:
			n += 1
	return n


func saved_count() -> int:
	return _saved


func lost_count() -> int:
	return _lost


## Fa partire subito l'ondata successiva (usato anche dai test). I rinforzi escono in fila dalle portine
## laterali delle torri (i battenti si aprono), ripartiti fra le porte, e vanno alla loro postazione.
func _start_wave() -> void:
	wave += 1
	var count := rules.trojans_in_wave(wave)
	count = mini(count, maxi(rules.max_alive_trojans - alive_trojans(), 0))
	_apply_defence_scaling(wave)
	var doors := _side_doors()
	if doors.is_empty():
		count = 0
	else:
		var first := randi() % doors.size()
		var used := {}
		for i in count:
			var d := doors[(first + i) % doors.size()]
			if not used.has(d):
				used[d] = true
				d.set_open(true, DOOR_TIME)
			get_tree().create_timer(DOOR_TIME + 0.2 + (i / doors.size()) * rules.gate_exit_interval).timeout.connect(
				_spawn_trojan.bind(wave, i, d))
	wave_started.emit(wave, count)
	if hud and count > 0:
		hud.show_banner("Reinforcements march out of the tower doors!", 2.5)


const DOOR_TIME := 1.0


## Le portine laterali delle torri (se non ce ne sono, tutte le porte).
func _side_doors() -> Array[TroyGate]:
	var side: Array[TroyGate] = []
	var all: Array[TroyGate] = []
	for n in get_tree().get_nodes_in_group(&"troy_gates"):
		var g := n as TroyGate
		if g == null:
			continue
		all.append(g)
		if g.kind == TroyGate.Kind.TOWER_DOOR:
			side.append(g)
	return side if not side.is_empty() else all


## Casella libera per la postazione di un rinforzo: nel piazzale davanti alla sua porta.
func _pick_post(door_cell: Vector2i) -> Vector2i:
	var r := rules.post_radius
	for _try in 12:
		var c := door_cell + Vector2i(randi_range(-r, r), randi_range(3, r + 3))
		if _grid.is_inside(c) and _grid.is_walkable(c) and not _unreachable.has(c):
			return c
	return _free_cell_near(door_cell + Vector2i(0, 4))


func _spawn_trojan(w: int, index: int, door: TroyGate) -> bool:
	if phase != Phase.RUNNING or _grid == null or not is_instance_valid(door):
		return false
	var out := door.global_position + Vector3(0, 0, 0.5)
	var door_cell := _grid.world_to_cell(out)
	var cell := _free_cell_near(door_cell)
	if cell == Vector2i(-1, -1):
		return false
	var t := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI,
		rules.health_in_wave(w), "TrojanWave%d_%d" % [w, index]) as TrojanSoldier
	t.attack_damage = rules.damage_in_wave(w)
	t.attack_interval = rules.trojan_attack_interval
	t.step_duration = rules.step_in_wave(w)
	t.show_health_bar = true
	t.position = _grid.cell_to_world(cell)
	t.post_cell = _pick_post(door_cell)
	t.state = TrojanSoldier.State.RETURN
	_units_root.add_child(t)
	# Parte da dentro la torre, oltre i battenti, e attraversa il varco (la porta è fuori dalla griglia).
	var start := _grid.cell_to_world(cell)
	start.x = door.global_position.x
	start.z = door.global_position.z - 0.5
	t.emerge_from(start, 1.5)
	t.died.connect(_on_trojan_died)
	# La porta si richiude dopo l'ultimo che esce.
	_door_last_use[door] = Time.get_ticks_msec()
	get_tree().create_timer(4.0).timeout.connect(_close_door.bind(door, _door_last_use[door]))
	return true


var _door_last_use := {}


func _close_door(door: TroyGate, stamp: int) -> void:
	if is_instance_valid(door) and _door_last_use.get(door, 0) == stamp:
		door.set_open(false, DOOR_TIME)


func _spawn_wounded() -> void:
	# I feriti non devono giacere in una zona che Ulisse non può raggiungere.
	_unreachable.clear()
	for c in _grid.find_unreachable_cells(_player.cell):
		_unreachable[c] = true
	var p := rules.wounded_points
	var n := mini(rules.wounded_count, p.size())
	for i in n:
		var cell := _free_cell_near(_grid.world_to_cell(Vector3(p[i].x, 0.0, p[i].y)))
		if cell == Vector2i(-1, -1):
			continue
		var w := UnitFactory.make(WoundedSoldier, UnitFactory.MODEL_ACHEO, GridUnit.Team.ACHEI,
			rules.wounded_health, "Wounded%d" % (i + 1)) as WoundedSoldier
		w.camp_rect = rules.camp_rect
		w.severe = i >= n - rules.severe_wounded
		w.position = _grid.cell_to_world(cell)
		_units_root.add_child(w)
		w.state_changed.connect(_on_wounded_state.bind(w))
		wounded.append(w)


func _setup_ferry() -> void:
	ferry = FerrySystem.new()
	ferry.name = "FerrySystem"
	add_child(ferry)
	ferry.setup(_grid, _units_root, get_parent(), rules)
	ferry.wounded_evacuated.connect(func(n: int) -> void:
		wounded_evacuated.emit(n, wounded.size())
		if hud:
			hud.set_wounded(_saved, _lost, wounded.size(), n)
			hud.show_banner("A wounded comrade is aboard the ships!", 1.8))


func evacuated_count() -> int:
	return ferry.evacuated if ferry else 0


func _free_cell_near(c: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cc := c + Vector2i(dx, dy)
				if _grid.is_inside(cc) and _grid.is_walkable(cc) and _grid.get_occupant(cc) == null and not _unreachable.has(cc):
					return cc
	return Vector2i(-1, -1)


func _apply_defence_scaling(n: int) -> void:
	for node in get_tree().get_nodes_in_group(&"wall_shooters"):
		var s := node as WallShooter
		if s:
			s.reload_scale = rules.reload_scale_in_wave(n)
			s.damage_scale = rules.damage_scale_in_wave(n)


func _on_trojan_died() -> void:
	kills += 1


func _on_wounded_state(new_state: int, w: WoundedSoldier) -> void:
	match new_state:
		WoundedSoldier.State.SAVED:
			_saved += 1
			if ferry:
				ferry.request_evacuation(w)
			if hud:
				hud.show_banner("A wounded comrade is safe in camp! Soldiers will carry him to the ships.", 2.4)
		WoundedSoldier.State.LOST:
			_lost += 1
			if hud:
				hud.show_banner("A wounded comrade has fallen...", 1.8)
		WoundedSoldier.State.FOLLOWING:
			if hud:
				hud.show_banner("Support him and bring him back to camp - you move slower!", 2.2)
		WoundedSoldier.State.STRETCHER:
			if ferry:
				ferry.request_stretcher(w)
			if hud:
				if ferry == null or ferry.last_bearers >= 4:
					hud.show_banner("Four soldiers lift the stretcher - escort them to camp!", 2.4)
				elif ferry.last_bearers == 2:
					hud.show_banner("Not enough men for the stretcher: two soldiers drag him to camp!", 2.4)
				else:
					hud.show_banner("Not enough men for the stretcher: a lone soldier drags him to camp!", 2.4)
			return
		_:
			return
	wounded_changed.emit(_saved, _lost, wounded.size())
	if hud:
		hud.set_wounded(_saved, _lost, wounded.size(), evacuated_count())


## Termina il livello (fine del tempo) e mostra la schermata finale.
func finish() -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	var total := wounded.size()
	var ratio := float(_saved) / total if total > 0 else 1.0
	var orderly := ratio >= rules.good_threshold
	summary = {
		"saved": _saved,
		"lost": _lost,
		"evacuated": evacuated_count(),
		"total": total,
		"kills": kills,
		"waves": wave,
		"score": rules.score_for(_saved, kills, total),
		"orderly": orderly,
		"title": "Orderly retreat" if orderly else "Desperate retreat",
		"text": "The horns sound the retreat. The army pulls back to the ships; Troy still stands. Odysseus is already thinking of another way in..." if orderly \
			else "The horns sound the retreat, too late for many. The camp mourns its wounded. Odysseus swears Troy will not win by force of arms alone...",
	}
	for node in get_tree().get_nodes_in_group(&"wall_shooters"):
		(node as WallShooter).auto_fire = false
	for node in get_tree().get_nodes_in_group(&"troiani"):
		if node.has_method(&"halt"):
			node.halt()
	if _player:
		_player.set_physics_process(false)
	if hud:
		hud.show_end(summary)
	level_finished.emit(summary)


func _on_continue() -> void:
	if next_level_path != "" and ResourceLoader.exists(next_level_path):
		get_tree().change_scene_to_file(next_level_path)
