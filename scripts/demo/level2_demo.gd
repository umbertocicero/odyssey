extends Node
## Demo automatica del livello 2 (~5 minuti): un bot gioca "Il dono del mare" con gli stessi input del giocatore
## (movimento, interazione E, spada): abbatte e sfronda due abeti, li fa galleggiare lungo il ruscello fino alla spiaggia,
## li squadra sul banco e consegna le travi; poi il tempo "salta" e il cavallo cresce fase per fase con i soldati che
## aiutano Epeo; di notte respinge l'incursione dei troiani con le torce; infine entra nel cavallo per ultimo e si
## vedono la flotta che parte e i troiani che trascinano il cavallo fino alle mura. Testi a schermo in inglese.
## Usa il vero Level2World / Level2Director: nessuna copia della logica.
##
## Argomenti (dopo "--"): --clean (niente indicatore capitolo), --auto-quit, --shots=DIR, --shot-times=5,30,60,
## --timescale=N, --chapter=N (1-5). Vedi scenes/demo/README.md.

const MAIN_SCENE := "res://scenes/main/main_level2.tscn"
const CHAPTERS: Array[String] = ["The bay", "Timber and stream", "The horse rises", "Night raid", "Inside the horse"]
const DEFAULT_SHOTS: Array[float] = [4.0, 20.0, 40.0, 60.0, 80.0, 100.0, 130.0, 160.0, 190.0, 220.0, 250.0, 280.0, 310.0]

var main: Node
var world: Level2World
var director: Level2Director
var player: GridUnit
var cam: FixedCamera

var clock := 0.0
var chapter := -1
var _gen := 0
var _arg_clean := false
var _arg_auto_quit := false
var _arg_shots := ""
var _arg_shot_times: Array[float] = []
var _arg_chapter := 0
var _next_shot := 0
var _caption: Label
var _chapter_label: Label
var _caption_tween: Tween
var _attack_down := false
var _done := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--clean":
			_arg_clean = true
		elif arg == "--auto-quit":
			_arg_auto_quit = true
		elif arg.begins_with("--shots="):
			_arg_shots = arg.substr(8)
		elif arg.begins_with("--shot-times="):
			for s in arg.substr(13).split(",", false):
				_arg_shot_times.append(float(s))
		elif arg.begins_with("--timescale="):
			Engine.time_scale = clampf(float(arg.substr(12)), 0.1, 8.0)
		elif arg.begins_with("--chapter="):
			_arg_chapter = clampi(int(arg.substr(10)) - 1, 0, CHAPTERS.size() - 1)
	Duel.enabled = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if _arg_shots != "":
		DirAccess.make_dir_recursive_absolute(_arg_shots)
		if _arg_shot_times.is_empty():
			_arg_shot_times = DEFAULT_SHOTS.duplicate()
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	world = get_tree().get_first_node_in_group(&"level2_world") as Level2World
	player = world.player
	cam = world.camera
	director = main.get_node("Director") as Level2Director
	await get_tree().create_timer(0.5).timeout
	_play(_gen)


func _process(delta: float) -> void:
	clock += delta
	_auto_fight(delta)
	if _arg_shots != "" and _next_shot < _arg_shot_times.size() and clock >= _arg_shot_times[_next_shot]:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/demo2_%03d.png" % [_arg_shots, int(_arg_shot_times[_next_shot])])
		_next_shot += 1
	if not _arg_clean and _chapter_label and chapter >= 0:
		_chapter_label.text = "%d/%d  %s   %d:%02d" % [chapter + 1, CHAPTERS.size(), CHAPTERS[chapter], int(clock) / 60, int(clock) % 60]


## Il bot si difende da solo dalle pattuglie e riprende fiato (come il bot della demo del livello 1).
func _auto_fight(delta: float) -> void:
	if player == null or not is_instance_valid(player) or director == null or _done:
		return
	if player.health < 40 and player.health > 0:
		player.heal_full()
	var foe := _nearest_trojan(2.0)
	if foe != null and director._task.is_empty():
		_attack_pulse()


func _nearest_trojan(max_dist: float) -> GridUnit:
	var best: GridUnit = null
	var bd := max_dist
	for n in get_tree().get_nodes_in_group(&"troiani"):
		var u := n as GridUnit
		if u and u.health > 0:
			var d := player.global_position.distance_to(u.global_position)
			if d < bd:
				bd = d
				best = u
	return best


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		get_tree().quit()


# ─────────────────────────── sceneggiatura ───────────────────────────

func _chapter(n: int, text: String, seconds := 5.0) -> void:
	chapter = n
	_say(text, seconds)


func _play(gen: int) -> void:
	if _arg_chapter <= 0:
		_chapter(0, "Troy is far away. In a quiet bay, the Achaeans will build the horse.", 6.0)
		cam.distance = 52.0
		await _wait(gen, 4.0)
		var tw := create_tween()
		tw.tween_property(cam, "distance", 31.0, 4.0)
		await _wait(gen, 5.0)
	# --- legname ---
	if _arg_chapter <= 1:
		_chapter(1, "Fell a fir, strip the branches, carry the log to the stream.", 5.0)
		await _tree_to_stream(gen, 0)
		_say("The current floats the logs to the beach, down to the shore.", 4.0)
		await _tree_to_stream(gen, 1)
		await _wait_cond(gen, func() -> bool: return _landed() >= 1, 40.0)
		_say("Haul the log ashore and square it on the bench.", 4.0)
		await _haul_and_deliver(gen)
		if _landed() < 1:
			await _wait_cond(gen, func() -> bool: return _landed() >= 1, 30.0)
		await _haul_and_deliver(gen)
	# --- il cavallo cresce ---
	if _arg_chapter <= 2:
		_chapter(2, "Days of work pass. The soldiers who fought at Troy help Epeus raise the horse.", 6.0)
		await _build_until_raid(gen)
	# --- incursione ---
	if _arg_chapter <= 3:
		_chapter(3, "Night: Trojan raiders with torches!", 4.0)
		await _fight_raid(gen)
		_say("The raid is beaten back. Back to work.", 3.0)
		await _build_until_finished(gen)
	# --- dentro il cavallo ---
	_chapter(4, "The horse is finished. Odysseus goes in last.", 5.0)
	await _enter_horse(gen)
	await _wait_cond(gen, func() -> bool: return director.hud._end.visible, 200.0)
	_done = true
	_say("End of the Level 2 demo.", 6.0)
	await _wait(gen, 7.0)
	if _arg_auto_quit:
		get_tree().quit()


func _landed() -> int:
	var n := 0
	for t in director.trees:
		if t["state"] == Level2Director.T.LANDED:
			n += 1
	return n


func _tree_to_stream(gen: int, i: int) -> void:
	var spot: Vector2 = Level2World.TREE_SPOTS[i]
	var tr: Dictionary = director.trees[i]
	var steps := [["fell", Level2Director.T.FALLEN], ["trim", Level2Director.T.TRIMMED]]
	for st in steps:
		var tries := 0
		while gen == _gen and tr["state"] != st[1] and tries < 6:
			tries += 1
			await _walk_to(gen, spot + Vector2(1.3, 0.8), 0.6, 25.0)
			await _act(gen, st[0])
			await _wait(gen, 0.4)
			await _wait_cond(gen, func() -> bool: return tr["state"] == st[1], 5.0)
	var bank := world.stream_point(world.stream_len * 0.5)
	var tries2 := 0
	while gen == _gen and tr["state"] != Level2Director.T.FLOATING and tries2 < 6:
		tries2 += 1
		if director.carry == "":
			await _walk_to(gen, spot + Vector2(1.3, 0.8), 0.9, 25.0)
			await _act(gen, "lift")
		await _walk_to(gen, bank + Vector2(1.6, 1.2), 0.9, 25.0)
		await _act(gen, "float")


func _haul_and_deliver(gen: int) -> void:
	for i in director.trees.size():
		if director.trees[i]["state"] != Level2Director.T.LANDED:
			continue
		var lp := director._p2(director.trees[i]["trunk"])
		await _walk_to(gen, lp + Vector2(0.4, 1.0), 1.0, 20.0)
		await _act(gen, "haul")
		await _walk_to(gen, Level2World.BENCH + Vector2(0.0, 1.2), 0.9, 20.0)
		await _act(gen, "square")
		await _wait_cond(gen, func() -> bool: return director.carry == "beam", 8.0)
		await _walk_to(gen, Level2World.PILE + Vector2(0.0, 1.6), 1.2, 20.0)
		await _act(gen, "deliver")
		return


## "Il tempo passa": le travi arrivano a ritmo serrato, il cavallo cresce fino al ventre; si ferma all'incursione.
func _build_until_raid(gen: int) -> void:
	_cam_horse(true)
	var guard := 0
	while gen == _gen and not director.raid_active and director.stage < Level2Director.BEAMS_PER_STAGE.size() and guard < 200:
		guard += 1
		if not director.stage_active and director.pile_beams < Level2Director.BEAMS_PER_STAGE[director.stage]:
			director.debug_give_beams(Level2Director.BEAMS_PER_STAGE[director.stage] - director.pile_beams)
		await _wait(gen, 1.0)
	_cam_horse(false)


func _fight_raid(gen: int) -> void:
	cam.distance = 24.0
	var t := 0.0
	while gen == _gen and director.raid_active and t < 90.0:
		var foe := _nearest_raider()
		if foe:
			var p := Vector2(foe.global_position.x, foe.global_position.z)
			await _walk_to(gen, p, 1.3, 2.0, true)
		else:
			await _wait(gen, 0.5)
		t += 0.5
	_stop_input()
	cam.distance = 31.0


func _build_until_finished(gen: int) -> void:
	_cam_horse(true)
	var guard := 0
	while gen == _gen and director.phase == Level2Director.Phase.BUILD and guard < 300:
		guard += 1
		if not director.stage_active and director.stage < Level2Director.BEAMS_PER_STAGE.size() and director.pile_beams < Level2Director.BEAMS_PER_STAGE[director.stage]:
			director.debug_give_beams(Level2Director.BEAMS_PER_STAGE[director.stage] - director.pile_beams)
		await _wait(gen, 1.0)
	_cam_horse(false)


func _enter_horse(gen: int) -> void:
	await _wait_cond(gen, func() -> bool: return director._horse_ready, 20.0)
	await _walk_to(gen, Level2World.SITE + Vector2(-3.5, 3.5), 1.0, 20.0)
	await _wait_cond(gen, func() -> bool: return director._inside >= world.allies.size() + 4, 60.0)
	await _walk_to(gen, Level2World.SITE + Vector2(0.0, 4.5), 1.0, 20.0)
	await _act(gen, "enter")


func _cam_horse(on: bool) -> void:
	if on:
		cam._follow = world.horse
		cam.distance = 27.0
	else:
		cam._follow = player
		cam.distance = 31.0


func _nearest_raider() -> GridUnit:
	var best: GridUnit = null
	var bd := INF
	for r in director.raiders:
		if is_instance_valid(r) and r.health > 0:
			var d := player.global_position.distance_to(r.global_position)
			if d < bd:
				bd = d
				best = r
	return best


# ─────────────────────────── bot ───────────────────────────

func _wait(gen: int, seconds: float) -> void:
	var t := 0.0
	while gen == _gen and t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _wait_cond(gen: int, cond: Callable, timeout: float) -> void:
	var t := 0.0
	while gen == _gen and t < timeout and not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()


## Preme E quando l'azione richiesta e' disponibile (riprova qualche secondo).
func _act(gen: int, kind: String) -> void:
	_stop_input()
	var t := 0.0
	while gen == _gen and t < 25.0:
		if director._action().get("kind", "") == kind:
			director._interact()
			await get_tree().create_timer(0.2).timeout
			return
		await get_tree().process_frame
		t += get_process_delta_time()
	push_warning("Level2Demo: azione %s non disponibile, Ulisse in %s, azione=%s" % [kind, player.global_position, director._action()])


## Percorso sulla griglia (BFS a 8 direzioni, evita ostacoli e acqua) come lista di punti del mondo.
func _path_to(goal: Vector2) -> Array[Vector2]:
	var grid := world.grid
	var start := grid.world_to_cell(player.global_position)
	var target := grid.world_to_cell(Vector3(goal.x, 0.0, goal.y))
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var found := start == target
	var head := 0
	var best := start
	var best_d := (start - target).length_squared()
	while head < queue.size() and not found:
		var c := queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if prev.has(n) or not grid.is_inside(n) or grid.is_blocked(n):
				continue
			if d.x != 0 and d.y != 0 and (grid.is_blocked(c + Vector2i(d.x, 0)) or grid.is_blocked(c + Vector2i(0, d.y))):
				continue
			prev[n] = c
			queue.append(n)
			var dd := (n - target).length_squared()
			if dd < best_d:
				best_d = dd
				best = n
			if n == target:
				found = true
				break
	var cells: Array[Vector2i] = []
	var cur := target if found else best
	while cur != start:
		cells.push_front(cur)
		cur = prev[cur]
	var pts: Array[Vector2] = []
	for c in cells:
		var w := grid.cell_to_world(c)
		pts.append(Vector2(w.x, w.z))
	if found:
		pts.append(goal)
	return pts


func _walk_to(gen: int, goal: Vector2, radius: float, timeout: float, fight := false) -> void:
	if not fight:
		var pts := _path_to(goal)
		var deadline := Time.get_ticks_msec() + int(timeout * 1000.0 / maxf(Engine.time_scale, 0.1))
		for i in pts.size():
			if gen != _gen or Time.get_ticks_msec() > deadline:
				break
			var last_point := i == pts.size() - 1
			await _walk_direct(gen, pts[i], radius if last_point else 0.55, timeout)
		_stop_input()
		return
	await _walk_direct(gen, goal, radius, timeout, fight)


func _walk_direct(gen: int, goal: Vector2, radius: float, timeout: float, fight := false) -> void:
	var t := 0.0
	var stuck := 0.0
	var side := 0.0
	var sign_side := 1.0
	var last := Vector2(player.global_position.x, player.global_position.z)
	while gen == _gen and t < timeout:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		var pos := Vector2(player.global_position.x, player.global_position.z)
		if pos.distance_to(goal) <= radius:
			break
		var to := goal - pos
		if side > 0.0:
			side -= dt
			to = to.rotated(sign_side * PI * 0.5)
		_steer(to)
		if fight and director.raid_active:
			var foe := _nearest_raider()
			if foe and player.global_position.distance_to(foe.global_position) < 2.0:
				_attack_pulse()
		stuck += dt
		if stuck >= 0.8:
			if pos.distance_to(last) < 0.5 and side <= 0.0:
				side = 0.6
				sign_side = -sign_side
			stuck = 0.0
			last = pos
	_stop_input()


func _steer(world_dir: Vector2) -> void:
	var c: Camera3D = world.camera
	if world_dir.length() < 0.001 or c == null:
		_stop_input()
		return
	var r := Vector3(c.global_basis.x.x, 0.0, c.global_basis.x.z).normalized()
	var f := Vector3(-c.global_basis.z.x, 0.0, -c.global_basis.z.z).normalized()
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


func _attack_pulse() -> void:
	if _attack_down:
		return
	_attack_down = true
	player.action_requested.emit(&"attack")
	player.call(&"_melee_attack")
	await get_tree().create_timer(0.55).timeout
	_attack_down = false


# ─────────────────────────── interfaccia ───────────────────────────

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 50
	add_child(ui)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override(&"font_size", 28)
	_caption.add_theme_color_override(&"font_outline_color", Color(0.1, 0.05, 0.02))
	_caption.add_theme_constant_override(&"outline_size", 8)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_caption)
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_left = -520
	_caption.offset_right = 520
	_caption.offset_top = -250
	_caption.offset_bottom = -170
	_caption.modulate.a = 0.0
	_chapter_label = Label.new()
	_chapter_label.add_theme_font_size_override(&"font_size", 16)
	_chapter_label.add_theme_constant_override(&"outline_size", 6)
	_chapter_label.add_theme_color_override(&"font_outline_color", Color(0.1, 0.05, 0.02))
	_chapter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_chapter_label)
	_chapter_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_chapter_label.offset_left = 14
	_chapter_label.offset_top = -34
	_chapter_label.offset_right = 520
	_chapter_label.offset_bottom = -10
	_chapter_label.visible = not _arg_clean


func _say(text: String, seconds: float) -> void:
	_caption.text = text
	if _caption_tween:
		_caption_tween.kill()
	_caption.modulate.a = 1.0
	_caption_tween = create_tween()
	_caption_tween.tween_interval(seconds)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.8)
