extends Node
## Demo automatica del livello 1 (~2 minuti): camera cinematica, Ulisse che si
## muove da solo e testi a schermo in inglese. La voce fuori campo la mette chi
## presenta la demo.
##
## Non modifica il livello: istanzia scenes/main/main.tscn (con regole proprie),
## ci aggiunge una Camera3D separata e guida Ulisse con gli stessi input del
## giocatore (movimento, balzo, spada), quindi usa davvero level_director,
## ulisse.gd, ferry_system.gd e level_hud.gd. La camera di gioco (FixedCamera)
## resta intatta: con il tasto G la demo cede il controllo al giocatore.
##
## Capitoli (secondi dall'inizio):
##   0  0:00 panoramica alta sul diorama
##   1  0:20 camera bassa sul sentiero verso le mura (arcieri, balista, catapulta)
##   2  0:45 Ulisse corre nell'erba, scavalca una cassa, passa sotto un ulivo, combatte
##   3  1:10 soccorre un ferito (55% di velocità da solo, 70% con un compagno)
##   4  1:30 barella con quattro soldati e barca a remi verso la nave
##   5  1:50 segnale di ritirata e schermata finale
##
## Argomenti (dopo "--"): vedi scenes/demo/README.md.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const CHAPTER_START: Array[float] = [0.0, 20.0, 45.0, 70.0, 90.0, 110.0]
const CHAPTER_NAMES: Array[String] = ["Overview", "Path to the walls", "Odysseus runs", "Rescue", "Stretcher and boat", "Retreat"]
## Il livello finisce da solo a questo istante (dopo il "Retreat!" a 110 s).
const END_TIME := 114.0
const OPENING_TEXT := "Hold the line until the retreat signal!"

const DEFAULT_SHOT_TIMES: Array[float] = [4.0, 14.0, 24.0, 34.0, 42.0, 50.0, 58.0, 66.0, 74.0, 82.0, 92.0, 100.0, 107.0, 112.0, 117.0]

# Dove giace il ferito grave: poco fuori dall'accampamento, così la barella arriva in tempo.
const SEVERE_SPOT := Vector2(-10.5, 6.0)
# Centro dell'accampamento (x, z in metri).
# Ferito da soccorrere: sul corridoio libero che Ulisse percorre dopo la cassa.
const WOUNDED_SPOT := Vector2(-0.5, 3.0)
const CAMP_CENTER := Vector2(-11.0, 11.0)

var main: Node
var director: LevelDirector
var grid: DioramaGrid
var ulisse: GridUnit
var viewport: SubViewport
var cam: Camera3D
var game_cam: Camera3D

var clock := 0.0
var chapter := 0
var manual := false     # il giocatore ha preso il controllo (tasto G)

var _gen := 0           # cambia a ogni (ri)avvio: ferma le coroutine vecchie
var _booting := false
var _cam_keys: Array = []
var _cam_follow := {}   # {focus: Callable, yaw, pitch, dist, fov, lift}
var _cam_focus := Vector3.ZERO
var _cam_from := Transform3D.IDENTITY
var _cam_from_fov := 40.0
var _blend := 1.0
var _blend_time := 2.0
var _captions: Array = []     # [t, testo, durata]
var _caption_i := 0
var _heal_cd := 0.0
var _fire_cd := 0.0
var _fire_enabled := false
var _attack_down := false
var _live_caption := Callable()
var _live_cd := 0.0
var _debug_cd := 0.0

var _saved_time_scale := 1.0
var _paused := false

var _ui: CanvasLayer
var _caption: Label
var _caption_tween: Tween
var _big: Label
var _big_tween: Tween
var _chapter_label: Label
var _help: Label
var _help_visible := true

# Argomenti da riga di comando.
var _arg_chapter := 0
var _arg_clean := false
var _arg_auto_quit := false
var _arg_shots := ""
var _arg_shot_times: Array[float] = []
var _arg_timescale := 1.0
var _next_shot := 0


func _ready() -> void:
	_parse_args()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if _arg_timescale != 1.0:
		Engine.time_scale = _arg_timescale
	if _arg_shots != "":
		DirAccess.make_dir_recursive_absolute(_arg_shots)
		if _arg_shot_times.is_empty():
			_arg_shot_times = DEFAULT_SHOT_TIMES.duplicate()
	_boot(_arg_chapter)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chapter="):
			_arg_chapter = clampi(int(arg.substr(10)) - 1, 0, CHAPTER_START.size() - 1)
		elif arg == "--clean":
			_arg_clean = true
		elif arg == "--auto-quit":
			_arg_auto_quit = true
		elif arg.begins_with("--shots="):
			_arg_shots = arg.substr(8)
		elif arg.begins_with("--shot-times="):
			for s in arg.substr(13).split(",", false):
				_arg_shot_times.append(float(s))
		elif arg.begins_with("--timescale="):
			_arg_timescale = clampf(float(arg.substr(12)), 0.1, 8.0)


# ─────────────────────────── avvio / salti ───────────────────────────

## (Ri)crea il livello e parte dall'inizio del capitolo `ch` (0 = primo).
func _boot(ch: int) -> void:
	_gen += 1
	var gen := _gen
	_booting = true
	manual = false
	_stop_input()
	_fire_enabled = false
	_live_caption = Callable()
	if main:
		main.free()
		main = null
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	director = main.get_node("Director") as LevelDirector
	director.rules = _make_rules()
	director.next_level_path = ""
	add_child(main)
	# Il director aspetta due frame prima di partire (griglia, Ulisse, feriti).
	for i in 5:
		await get_tree().process_frame
	if gen != _gen:
		return
	grid = get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	ulisse = get_tree().get_first_node_in_group(&"player") as GridUnit
	viewport = main.get_node("GameView/GameViewport") as SubViewport
	game_cam = viewport.get_camera_3d()
	var hint := main.get_node_or_null(^"UI/Hint") as Control
	if hint:
		hint.visible = false
	cam = Camera3D.new()
	cam.name = "DemoCamera"
	cam.fov = 40.0
	cam.far = 400.0
	viewport.add_child(cam)
	cam.make_current()
	_cam_follow = {}
	_cam_keys = []
	_cam_focus = Vector3(0, 0, -4)
	_blend = 1.0
	_hook_end_button()
	for w in director.wounded:
		w.max_health = 600
		w.health = 600
	# Conta come sconfitti anche i troiani già in campo all'inizio.
	for n in get_tree().get_nodes_in_group(&"troiani"):
		(n as GridUnit).died.connect(director._on_trojan_died)
	ulisse.attack_damage = 45   # i fendenti di Ulisse abbattono un troiano in due colpi
	if director.ferry:
		director.ferry.stretcher_speed = 2.8   # la barella è più veloce, per stare nei tempi
	if director.hud:
		director.hud.set_wounded(0, 0, director.wounded.size(), 0)
	clock = CHAPTER_START[ch]
	_prepare_world(ch)
	director.elapsed = clock
	chapter = ch - 1       # _update_chapter() entra nel capitolo ch
	_caption_i = 0
	_next_shot = 0
	while _next_shot < _arg_shot_times.size() and _arg_shot_times[_next_shot] < clock:
		_next_shot += 1
	_booting = false
	_update_chapter(true)


func _make_rules() -> LevelRules:
	var r := LevelRules.new()
	r.duration = END_TIME
	r.first_wave_delay = 99999.0   # le ondate le lancia la demo dal capitolo 2
	r.wave_interval = 22.0
	r.ferry_sail_time = 4.0
	r.good_threshold = 0.3   # con 2 feriti su 6 la ritirata risulta "ordinata"
	return r


## Porta il mondo nello stato che ha all'inizio del capitolo `ch`.
func _prepare_world(ch: int) -> void:
	# Fino al capitolo 2 i troiani aspettano fermi sotto le mura.
	_set_trojans_halted(ch < 2)
	var w0 := _first_wounded()
	if w0 and ch < 4:
		_place_near(w0, WOUNDED_SPOT)
	var severe := _severe()
	if severe:
		_place_near(severe, SEVERE_SPOT)
	if ch >= 2:
		director._next_wave_at = clock + 10.0
	if ch == 3:
		ulisse.place_at(grid.world_to_cell(Vector3(-0.5, 0, 7.5)))
		_gather_allies_near(ulisse)
	elif ch >= 4:
		var w := _first_wounded()
		if w:
			_place_near(w, Vector2(-9.5, 10.5))
			w.lie_down()
			w.mark_saved()
		ulisse.place_at(grid.world_to_cell(Vector3(-11.5, 0, 8.5)))
		_gather_allies_near(ulisse)


## Mette l'unità nella casella libera più vicina al punto (x, z in metri).
func _place_near(u: GridUnit, p: Vector2) -> bool:
	var c := grid.world_to_cell(Vector3(p.x, 0, p.y))
	for r in range(0, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and grid.is_walkable(c + Vector2i(dx, dy)) \
						and grid.get_occupant(c + Vector2i(dx, dy)) == null:
					return u.place_at(c + Vector2i(dx, dy))
	return false


func _gather_allies_near(u: GridUnit) -> void:
	for n in get_tree().get_nodes_in_group(&"achei"):
		var a := n as AllySoldier
		if a == null:
			continue
		for d in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 2), Vector2i(0, -2)]:
			if a.place_at(u.cell + d):
				break


func _set_trojans_halted(on: bool) -> void:
	for n in get_tree().get_nodes_in_group(&"troiani"):
		var t := n as TrojanSoldier
		if t:
			t._halted = on


func _first_wounded() -> WoundedSoldier:
	for w in director.wounded:
		if is_instance_valid(w) and not w.severe:
			return w
	return null


func _severe() -> WoundedSoldier:
	for w in director.wounded:
		if is_instance_valid(w) and w.severe:
			return w
	return null


## Il pulsante della schermata finale rilancia la demo.
func _hook_end_button() -> void:
	if director.hud == null:
		return
	for b in director.hud.find_children("*", "Button", true, false):
		(b as Button).text = "Replay the demo"
		(b as Button).pressed.connect(func() -> void: _boot.call_deferred(0))


# ─────────────────────────── ciclo principale ───────────────────────────

func _process(delta: float) -> void:
	if _booting or director == null:
		return
	clock += delta
	if director.phase == LevelDirector.Phase.RUNNING:
		director.elapsed = clock
	_update_chapter(false)
	_update_captions()
	if cam:
		_update_camera(delta)
	_update_helpers(delta)
	_update_shots()
	_debug_cd -= delta
	if _debug_cd <= 0.0 and OS.get_cmdline_user_args().has("--debug"):
		_debug_cd = 2.0
		var w := _first_wounded()
		print("[demo] t=%.0f ch=%d ulisse=(%.1f,%.1f) speed=%.2f wounded0=%s" % [clock, chapter + 1, _ulisse_pos().x, _ulisse_pos().z,
			ulisse.speed_multiplier if ulisse else 0.0,
			("%d@(%.1f,%.1f)" % [w.state, w.global_position.x, w.global_position.z]) if w else "-"])
	if _arg_auto_quit and clock >= END_TIME + 6.0:
		_quit()


func _update_chapter(force: bool) -> void:
	var idx := 0
	for i in CHAPTER_START.size():
		if clock >= CHAPTER_START[i]:
			idx = i
	if idx == chapter and not force:
		return
	chapter = idx
	_enter_chapter(idx)


func _clock_text() -> String:
	return "%d:%02d" % [int(clock) / 60, int(clock) % 60]


func _enter_chapter(idx: int) -> void:
	if manual:
		return
	_from_current_camera()
	_captions = []
	_cam_keys = []
	_cam_follow = {}
	_live_caption = Callable()
	_fire_enabled = false
	var t0 := CHAPTER_START[idx]
	var gen := _gen
	match idx:
		0:
			_cam_keys = [
				_key(t0, Vector3(0, 0, -3), 32, -50, 56, 28),
				_key(t0 + 8, Vector3(-2, 0, -2), 18, -45, 50, 28),
				_key(t0 + 14, Vector3(-6, 0, 1), 4, -38, 44, 28),
				_key(t0 + 20.5, Vector3(-8, 0, 3), -6, -32, 38, 30),
			]
			_blend = 1.0
			director.hud.show_banner(OPENING_TEXT, 11.0)
		1:
			_cam_keys = [
				_key(t0, Vector3(-9, 1.2, 8), 24, -11, 10, 42),
				_key(t0 + 7, Vector3(-5, 1.8, -2), 12, -9, 11, 42),
				_key(t0 + 14, Vector3(-3, 3.0, -12), -4, -8, 13, 40),
				_key(t0 + 20, Vector3(-9, 4.2, -19), 8, -5, 15, 38),
				_key(t0 + 25.5, Vector3(3, 4.5, -19), -16, -6, 15, 38),
			]
			_captions = [[t0 + 0.5, "The path to the walls of Troy: towers, archers, ballistae and a catapult.", 9.0]]
			_fire_enabled = true
		2:
			_set_trojans_halted(false)
			director._next_wave_at = clock + 9.0
			_follow(func() -> Vector3: return _ulisse_pos(), 30, -36, 9.0, 42, 1.0)
			_captions = [
				[t0 + 0.5, "Odysseus races through the tall grass, vaults a crate and slips under an olive tree.", 10.0],
				[t0 + 14.0, "Side by side with his comrades, he fights the Trojans.", 9.0],
			]
			_run_chapter_run(gen)
		3:
			_follow(func() -> Vector3: return _ulisse_pos(), 24, -40, 9.0, 40, 1.0)
			_captions = [[t0 + 0.5, "A wounded comrade! Odysseus lifts him up and helps him back to camp.", 6.0]]
			_run_chapter_rescue(gen)
		4:
			_follow(func() -> Vector3: return _ulisse_pos(), 24, -40, 9.0, 40, 1.0)
			_captions = [
				[t0 + 0.5, "Badly wounded men are carried on a stretcher by four soldiers.", 9.0],
				[t0 + 10.0, "A rowing boat takes the wounded to the ships.", 9.0],
			]
			_run_chapter_stretcher(gen)
		5:
			_cam_keys = [
				_key(t0 - 0.01, _cam_focus, 30, -35, 28, 38),
				_key(t0 + 6, Vector3(-14, 0, 8), 40, -28, 36, 30),
				_key(t0 + 14, Vector3(-18, 0, 6), 55, -24, 44, 28),
			]
			_stop_input()
			_run_chapter_retreat(gen)
	_caption_i = 0
	while _caption_i < _captions.size() and _captions[_caption_i][0] < clock - 0.2:
		_caption_i += 1


# ─────────────────────────── capitoli: Ulisse ───────────────────────────

## Capitolo 2: corsa nell'erba, balzo sulla cassa, sotto l'ulivo, combattimento.
func _run_chapter_run(gen: int) -> void:
	var end_t := CHAPTER_START[3]
	var route: Array[Vector2] = [
		Vector2(-9.0, 14.5), Vector2(-5.5, 16.8), Vector2(-3.0, 18.7),   # sotto la chioma dell'ulivo
		Vector2(-0.5, 16.0), Vector2(-0.5, 14.0),
	]
	for p in route:
		await _walk_to(gen, p, 0.7, 10.0, false)
		if gen != _gen:
			return
	# Verso nord contro la cassa: Ulisse la scavalca con il balzo.
	await _walk_to(gen, Vector2(-0.5, 9.2), 0.6, 8.0, false)
	if gen != _gen:
		return
	# Lo scontro avviene davanti alla camera: quattro troiani escono davanti a Ulisse.
	for i in 4:
		director.wave = maxi(director.wave, 1)
		director._spawn_trojan(Vector2(-0.5 + (i - 1.5) * 2.0, 3.0 - (i % 2) * 1.5))
	await _fight_until(gen, end_t)


## Capitolo 3: raggiunge il ferito e lo porta all'accampamento.
func _run_chapter_rescue(gen: int) -> void:
	var w := _first_wounded()
	if w == null:
		return
	await _walk_to(gen, Vector2(w.global_position.x, w.global_position.z), 1.3, 14.0, true,
		func() -> bool: return w.state != WoundedSoldier.State.LYING)
	if gen != _gen:
		return
	# Da solo: 55% della velocità. I compagni restano impegnati per un po'.
	_set_allies_busy(true)
	_live_caption = func() -> String:
		var pct := roundi(ulisse.speed_multiplier * 100.0)
		return "Supporting a wounded comrade: %d%% speed%s" % [pct, " (alone)" if pct <= 56 else " (a comrade is helping)"]
	await _walk_to(gen, Vector2(-0.6, 7.0), 1.0, 8.0, false)
	await _walk_to(gen, Vector2(-2.5, 9.6), 1.0, 8.0, false)
	if gen != _gen:
		return
	_set_allies_busy(false)
	await _walk_to(gen, CAMP_CENTER, 1.2, 12.0, false,
		func() -> bool: return w.state == WoundedSoldier.State.SAVED)
	if gen != _gen:
		return
	_stop_input()
	_live_caption = Callable()
	await _fight_until(gen, CHAPTER_START[4] - 5.0, Vector2(-8.0, 8.0))


## Capitolo 4: Ulisse raggiunge il ferito grave, la squadra alza la barella.
func _run_chapter_stretcher(gen: int) -> void:
	var s := _severe()
	if s == null:
		return
	await _walk_to(gen, Vector2(s.global_position.x, s.global_position.z), 1.3, 12.0, true,
		func() -> bool: return s.state != WoundedSoldier.State.LYING)
	if gen != _gen:
		return
	_stop_input()
	await _fight_until(gen, CHAPTER_START[5], Vector2(-9.0, 7.0))


func _run_chapter_retreat(gen: int) -> void:
	await get_tree().create_timer(0.3).timeout
	if gen != _gen:
		return
	_show_big("Retreat!", 4.5)
	director.hud.show_banner("Retreat!", 4.0)
	_captions = [[clock + 4.0, "The army pulls back to the ships.", 6.0]]
	_caption_i = 0


## I compagni liberi smettono di seguire Ulisse (per mostrare il 55% da solo).
func _set_allies_busy(on: bool) -> void:
	for n in get_tree().get_nodes_in_group(&"achei"):
		var a := n as AllySoldier
		if a == null:
			continue
		if on:
			if not a.busy:
				a.busy = true
				a.set_meta(&"demo_busy", true)
		elif a.has_meta(&"demo_busy"):
			a.busy = false
			a.remove_meta(&"demo_busy")


## Combatte i troiani vicini finché non arriva `until` (tempo della demo).
func _fight_until(gen: int, until: float, anchor := Vector2(-2.0, 9.0)) -> void:
	while gen == _gen and clock < until:
		var foe := _nearest_trojan(14.0, anchor, 9.0)
		if foe == null:
			_stop_input()
			await get_tree().physics_frame
			continue
		var p := Vector2(foe.global_position.x, foe.global_position.z)
		await _walk_to(gen, p, 1.15, 2.0, true, func() -> bool:
			return not is_instance_valid(foe) or foe.health <= 0 or clock >= until)
		# Fermo davanti al nemico: fendenti finché cade.
		var guard := 0
		while gen == _gen and is_instance_valid(foe) and foe.health > 0 and clock < until and guard < 30:
			guard += 1
			_stop_input()
			_attack_pulse()
			for i in 12:
				await get_tree().physics_frame
	_stop_input()


func _nearest_trojan(max_dist: float, anchor := Vector2.INF, anchor_radius := 0.0) -> GridUnit:
	var best: GridUnit = null
	var best_d := max_dist
	var up := _ulisse_pos()
	for n in get_tree().get_nodes_in_group(&"troiani"):
		var t := n as GridUnit
		if t == null or t.health <= 0:
			continue
		var d := Vector2(t.global_position.x - up.x, t.global_position.z - up.z).length()
		if anchor != Vector2.INF and Vector2(t.global_position.x, t.global_position.z).distance_to(anchor) > anchor_radius:
			continue
		if d < best_d:
			best_d = d
			best = t
	return best


## Cammina verso un punto con gli stessi input del giocatore (relativi alla camera).
## Se `fight` è vero, colpisce i nemici a portata. `stop_when` interrompe in anticipo.
func _walk_to(gen: int, goal: Vector2, radius: float, timeout: float, fight: bool, stop_when := Callable()) -> void:
	var t := 0.0
	var stuck := 0.0
	var side := 0.0
	var up := _ulisse_pos()
	var last := Vector2(up.x, up.z)
	var sign_side := 1.0
	while gen == _gen and t < timeout:
		await get_tree().physics_frame
		if gen != _gen or manual:
			return
		var dt := get_physics_process_delta_time()
		t += dt
		up = _ulisse_pos()
		var pos := Vector2(up.x, up.z)
		if pos.distance_to(goal) <= radius or (stop_when.is_valid() and stop_when.call()):
			break
		var to := goal - pos
		if side > 0.0:
			side -= dt
			to = to.rotated(sign_side * PI * 0.5)
		_steer(to)
		if fight and _nearest_trojan(1.5) != null:
			_attack_pulse()
		# Bloccato (ostacolo, compagno): un passo di lato.
		stuck += dt
		if stuck >= 0.8:
			if pos.distance_to(last) < 0.5 and side <= 0.0:
				side = 0.5
				sign_side = -sign_side
			stuck = 0.0
			last = pos
	_stop_input()


func _ulisse_pos() -> Vector3:
	if ulisse == null or not is_instance_valid(ulisse):
		return Vector3.ZERO
	return ulisse.global_position


## Direzione nel mondo -> input a schermo, secondo la camera attiva.
func _steer(world_dir: Vector2) -> void:
	if world_dir.length() < 0.001 or cam == null:
		_stop_input()
		return
	var r := Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var f := Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
	var w := Vector3(world_dir.x, 0.0, world_dir.y).normalized()
	var s := Vector2(w.dot(r), -w.dot(f))
	_press(&"move_right", maxf(s.x, 0.0))
	_press(&"move_left", maxf(-s.x, 0.0))
	_press(&"move_down", maxf(s.y, 0.0))
	_press(&"move_up", maxf(-s.y, 0.0))


func _press(action: StringName, strength: float) -> void:
	if strength > 0.001:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _stop_input() -> void:
	for a in [&"move_right", &"move_left", &"move_down", &"move_up"]:
		Input.action_release(a)


## Un colpo di spada: l'azione resta premuta un solo frame di fisica.
func _attack_pulse() -> void:
	if _attack_down:
		return
	_attack_down = true
	if ulisse and is_instance_valid(ulisse) and ulisse.has_method(&"_melee_attack"):
		ulisse.action_requested.emit(&"attack")   # animazione di attacco
		ulisse.call(&"_melee_attack")
	await get_tree().create_timer(0.55).timeout
	_attack_down = false


# ─────────────────────────── camera ───────────────────────────

func _key(t: float, focus: Vector3, yaw: float, pitch: float, dist: float, fov: float) -> Dictionary:
	return {"t": t, "f": focus, "yaw": yaw, "pitch": pitch, "d": dist, "fov": fov}


func _follow(focus: Callable, yaw: float, pitch: float, dist: float, fov: float, lift: float) -> void:
	_cam_follow = {"focus": focus, "yaw": yaw, "pitch": pitch, "dist": dist, "fov": fov, "lift": lift}


func _from_current_camera() -> void:
	if cam == null:
		return
	_cam_from = cam.global_transform
	_cam_from_fov = cam.fov
	_blend = 0.0


func _update_camera(delta: float) -> void:
	var xform := cam.global_transform
	var fov := cam.fov
	if not _cam_follow.is_empty():
		if chapter == 4:
			_chapter4_camera_override(delta)
		var wanted: Vector3 = (_cam_follow["focus"] as Callable).call() + Vector3.UP * float(_cam_follow["lift"])
		_cam_focus = _cam_focus.lerp(wanted, 1.0 - exp(-5.0 * delta))
		xform = _orbit(_cam_focus, float(_cam_follow["yaw"]), float(_cam_follow["pitch"]), float(_cam_follow["dist"]))
		fov = float(_cam_follow["fov"])
	elif not _cam_keys.is_empty():
		var s := _eval_keys(clock)
		_cam_focus = s["f"]
		xform = _orbit(s["f"], s["yaw"], s["pitch"], s["d"])
		fov = s["fov"]
	if _blend < 1.0:
		_blend = minf(_blend + delta / _blend_time, 1.0)
		var k := smoothstep(0.0, 1.0, _blend)
		cam.global_transform = _cam_from.interpolate_with(xform, k)
		cam.fov = lerpf(_cam_from_fov, fov, k)
	else:
		cam.global_transform = xform
		cam.fov = fov


## Nel capitolo della barella la camera segue la barella, poi la barca.
func _chapter4_camera_override(delta: float) -> void:
	var ferry := director.ferry
	if ferry == null:
		return
	var focus := _ulisse_pos()
	var yaw := 24.0
	var pitch := -30.0
	var dist := 7.5
	var boat: Node3D = null
	for b in ferry.boats:
		if b.busy:
			boat = b.node
	var stretcher: Node3D = null
	for j in ferry.jobs:
		if j.stretcher and is_instance_valid(j.stretcher):
			stretcher = j.stretcher
	if boat != null:
		focus = boat.global_position
		yaw = 55.0
		pitch = -16.0
		dist = 10.0
	elif stretcher != null:
		focus = stretcher.global_position
		yaw = -40.0
		pitch = -36.0
		dist = 10.0
	var k := 1.0 - exp(-1.5 * delta)
	_cam_follow["focus"] = func() -> Vector3: return focus
	_cam_follow["yaw"] = lerpf(float(_cam_follow["yaw"]), yaw, k)
	_cam_follow["pitch"] = lerpf(float(_cam_follow["pitch"]), pitch, k)
	_cam_follow["dist"] = lerpf(float(_cam_follow["dist"]), dist, k)


func _orbit(focus: Vector3, yaw_deg: float, pitch_deg: float, dist: float) -> Transform3D:
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0))
	return Transform3D(basis, focus + basis.z * dist)


## Interpolazione Catmull-Rom tra i fotogrammi chiave (fuori intervallo resta ai capi).
func _eval_keys(t: float) -> Dictionary:
	var n := _cam_keys.size()
	if t <= float(_cam_keys[0]["t"]):
		return _cam_keys[0]
	if t >= float(_cam_keys[n - 1]["t"]):
		return _cam_keys[n - 1]
	var i := 0
	while i < n - 2 and t >= float(_cam_keys[i + 1]["t"]):
		i += 1
	var a: Dictionary = _cam_keys[i]
	var b: Dictionary = _cam_keys[i + 1]
	var p0: Dictionary = _cam_keys[maxi(i - 1, 0)]
	var p3: Dictionary = _cam_keys[mini(i + 2, n - 1)]
	var u: float = (t - float(a["t"])) / (float(b["t"]) - float(a["t"]))
	return {
		"f": (a["f"] as Vector3).cubic_interpolate(b["f"], p0["f"], p3["f"], u),
		"yaw": lerpf(a["yaw"], b["yaw"], u),
		"pitch": lerpf(a["pitch"], b["pitch"], u),
		"d": lerpf(a["d"], b["d"], u),
		"fov": lerpf(a["fov"], b["fov"], u),
	}


# ─────────────────────────── aiuti durante la demo ───────────────────────────

func _update_helpers(delta: float) -> void:
	_heal_cd -= delta
	if _heal_cd <= 0.0:
		_heal_cd = 0.4
		_keep_everyone_alive()
	if _fire_enabled:
		_fire_cd -= delta
		if _fire_cd <= 0.0:
			_fire_cd = 0.7
			_fire_show()
	if _live_caption.is_valid():
		_live_cd -= delta
		if _live_cd <= 0.0:
			_live_cd = 0.15
			_set_caption(_live_caption.call(), 1.0)


## La demo non deve mostrare sconfitte: Ulisse, i compagni e i feriti non muoiono.
func _keep_everyone_alive() -> void:
	if ulisse and is_instance_valid(ulisse) and ulisse.health > 0 and ulisse.health < ulisse.max_health * 0.6:
		ulisse.heal_full()
	for n in get_tree().get_nodes_in_group(&"achei"):
		var u := n as GridUnit
		if u and u.health > 0 and u.health < u.max_health * 0.5:
			u.heal_full()


## Capitolo 1: arcieri, balista e catapulta tirano davanti alla camera.
func _fire_show() -> void:
	var best: Array = []
	for n in get_tree().get_nodes_in_group(&"wall_shooters"):
		var s := n as WallShooter
		if s and s.profile:
			best.append(s)
	if best.is_empty():
		return
	var focus := _cam_focus
	best.sort_custom(func(a: WallShooter, b: WallShooter) -> bool:
		return a.global_position.distance_to(focus) < b.global_position.distance_to(focus))
	var shooter := best[randi() % mini(5, best.size())] as WallShooter
	var target := focus + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(2.0, 7.0))
	var c := grid.world_to_cell(target)
	if grid.is_inside(c) and not grid.is_blocked(c):
		shooter.fire_at(c)


# ─────────────────────────── testi ───────────────────────────

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 50
	add_child(_ui)
	_caption = _label(30, Control.PRESET_CENTER_BOTTOM)
	_caption.offset_top = -170
	_caption.offset_bottom = -80
	_caption.offset_left = -520
	_caption.offset_right = 520
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_caption.modulate.a = 0.0
	_big = _label(110, Control.PRESET_CENTER)
	_big.offset_left = -600
	_big.offset_right = 600
	_big.offset_top = -90
	_big.offset_bottom = 90
	_big.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.5))
	_big.add_theme_constant_override(&"outline_size", 16)
	_big.modulate.a = 0.0
	_chapter_label = _label(16, Control.PRESET_BOTTOM_LEFT)
	_chapter_label.offset_left = 14
	_chapter_label.offset_top = -34
	_chapter_label.offset_right = 520
	_chapter_label.offset_bottom = -10
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_chapter_label.modulate.a = 0.75
	_help = _label(15, Control.PRESET_BOTTOM_RIGHT)
	_help.offset_left = -560
	_help.offset_top = -64
	_help.offset_right = -14
	_help.offset_bottom = -10
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help.text = "N / →  next chapter    P / ←  restart chapter    1-6  jump\nR  restart demo    Space  pause    G  play yourself    H  hide help    Esc  quit"
	_help.modulate.a = 0.7
	if _arg_clean:
		_chapter_label.visible = false
		_help.visible = false


func _label(font_size: int, preset: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_outline_color", Color(0.1, 0.05, 0.02))
	l.add_theme_constant_override(&"outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(l)
	l.set_anchors_preset(preset)
	return l


func _update_captions() -> void:
	while _caption_i < _captions.size() and clock >= _captions[_caption_i][0]:
		var c: Array = _captions[_caption_i]
		_set_caption(c[1], c[2])
		_caption_i += 1
	if not _arg_clean:
		_chapter_label.text = "%d/%d  %s   %s" % [chapter + 1, CHAPTER_START.size(), CHAPTER_NAMES[maxi(chapter, 0)], _clock_text()]


func _set_caption(text: String, seconds: float) -> void:
	_caption.text = text
	if _caption_tween:
		_caption_tween.kill()
	_caption.modulate.a = 1.0
	_caption_tween = create_tween()
	_caption_tween.tween_interval(seconds)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.8)


func _show_big(text: String, seconds: float) -> void:
	_big.text = text
	if _big_tween:
		_big_tween.kill()
	_big.modulate.a = 0.0
	_big_tween = create_tween()
	_big_tween.tween_property(_big, "modulate:a", 1.0, 0.4)
	_big_tween.tween_interval(seconds)
	_big_tween.tween_property(_big, "modulate:a", 0.0, 1.0)


# ─────────────────────────── tasti / screenshot ───────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE:
			_quit()
		KEY_SPACE:
			_toggle_pause()
		KEY_H:
			_help_visible = not _help_visible
			_help.visible = _help_visible and not _arg_clean
		KEY_R:
			_goto(0)
		KEY_G:
			_take_control()
		KEY_N:
			_goto(chapter + 1)
		KEY_P:
			_goto(chapter if clock - CHAPTER_START[chapter] > 3.0 else chapter - 1)
		KEY_RIGHT:
			if not manual:
				_goto(chapter + 1)
		KEY_LEFT:
			if not manual:
				_goto(chapter if clock - CHAPTER_START[chapter] > 3.0 else chapter - 1)
		_:
			if k.keycode >= KEY_1 and k.keycode <= KEY_6:
				_goto(k.keycode - KEY_1)


func _goto(ch: int) -> void:
	if _booting:
		return
	if _paused:
		_toggle_pause()
	_boot(clampi(ch, 0, CHAPTER_START.size() - 1))


func _toggle_pause() -> void:
	_paused = not _paused
	if _paused:
		_saved_time_scale = Engine.time_scale
		Engine.time_scale = 0.0
	else:
		Engine.time_scale = _saved_time_scale


## Il giocatore prende il controllo: camera di gioco, niente più regia.
func _take_control() -> void:
	if manual or game_cam == null or cam == null:
		return
	manual = true
	_gen += 1
	_stop_input()
	_set_allies_busy(false)
	_fire_enabled = false
	_live_caption = Callable()
	game_cam.make_current()
	_set_caption("Your turn! WASD / arrows to move, click to attack. R restarts the demo.", 6.0)
	cam.queue_free()
	cam = null


func _update_shots() -> void:
	if _arg_shots == "" or _next_shot >= _arg_shot_times.size():
		return
	if clock < _arg_shot_times[_next_shot]:
		return
	var t := _arg_shot_times[_next_shot]
	_next_shot += 1
	_save_shot(t)


func _save_shot(t: float) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/demo_%03d.png" % [_arg_shots, int(t)]
	img.save_png(path)
	print("[demo] screenshot ", path, " clock=", snappedf(clock, 0.1), " chapter=", chapter + 1,
		" saved=", director.saved_count(), " evacuated=", director.evacuated_count())


func _quit() -> void:
	_stop_input()
	Engine.time_scale = 1.0
	if director and director.phase == LevelDirector.Phase.ENDED:
		print("[demo] finished: ", director.summary)
	get_tree().quit()
