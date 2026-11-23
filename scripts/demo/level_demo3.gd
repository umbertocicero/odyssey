extends Node
## Demo 3: un bot gioca il livello 1 come un giocatore vero, nel minor tempo possibile.
##
## Nessun cheat: il livello è quello di scenes/main/main.tscn con le sue regole
## (data/level1/rules.tres), nessuna modifica a vita, danni, tempo, velocità o
## posizioni. Il bot vede lo stato del mondo come lo vedrebbe un giocatore e agisce
## solo con gli stessi input (muovi, attacca): soccorso dei feriti, barella con quattro
## soldati liberi (altrimenti trascinamento da 2 o da 1), barche, ondate, fuoco dalle mura
## sono tutti gestiti dai sistemi del gioco. L'unica cosa fissata è il seme casuale.
##
## Il livello finisce quando ogni ferito è in salvo sulle navi o perso.
## Argomenti (dopo "--"): --auto-quit, --plan=..., --seed=N, --timescale=N (solo prove),
## --shots=DIR --shot-times=a,b,c, --clean (niente aiuto tasti).
##
## Piano = visite in ordine: numero = ferito (1..N) da raggiungere, C = porta in salvo
## in accampamento chi ti segue, W = come C ma entrando dal lato della riva.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const DEFAULT_SEED := 1207
const DEFAULT_PLAN := "5,6,2,4,C,3,1,W"

var main: Node
var director: LevelDirector
var grid: DioramaGrid
var ulisse: GridUnit
var viewport: SubViewport

var plan_text := DEFAULT_PLAN
var rng_seed := DEFAULT_SEED

var _gen := 0
var _arg_auto_quit := false
var _arg_clean := false
var _arg_shots := ""
var _arg_shot_times: Array[float] = []
var _arg_timescale := 1.0
var _next_shot := 0
var _arg_trace := false
var _trace_next := 0.0
var _finished := false
var _paused := false

var _attack_cd := 0.0
var _attack_release := false
var _status := ""
var _kills_at_start := 0
var _min_hp := 100
var _hits_taken := 0
var _last_hp := 100

var _ui: CanvasLayer
var _clock_label: Label
var _info_label: Label
var _status_label: Label
var _help: Label
var _end_panel: PanelContainer
var _end_label: Label
var _title_label: Label

var _path: Array[Vector2i] = []
var _path_goal_key := ""
var _path_age := 0.0
var _stuck := 0.0
var _last_pos := Vector2.ZERO
var _side_until := 0.0
var _side_sign := 1.0
var _hazard: Dictionary = {}
var _hazard_age := 0.0


func _ready() -> void:
	_parse_args()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if _arg_timescale != 1.0:
		Engine.time_scale = _arg_timescale
	if _arg_shots != "":
		DirAccess.make_dir_recursive_absolute(_arg_shots)
	_boot()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto-quit":
			_arg_auto_quit = true
		elif arg == "--trace":
			_arg_trace = true
		elif arg == "--clean":
			_arg_clean = true
		elif arg.begins_with("--plan="):
			plan_text = arg.substr(7)
		elif arg.begins_with("--seed="):
			rng_seed = int(arg.substr(7))
		elif arg.begins_with("--shots="):
			_arg_shots = arg.substr(8)
		elif arg.begins_with("--shot-times="):
			for s in arg.substr(13).split(",", false):
				_arg_shot_times.append(float(s))
		elif arg.begins_with("--timescale="):
			_arg_timescale = clampf(float(arg.substr(12)), 0.1, 16.0)


# ─────────────────────────── avvio ───────────────────────────

func _boot() -> void:
	_gen += 1
	var gen := _gen
	_finished = false
	_end_panel.visible = false
	_path.clear()
	_path_goal_key = ""
	_attack_cd = 0.0
	_next_shot = 0
	if main:
		main.free()
		main = null
	seed(rng_seed)
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	director = main.get_node("Director") as LevelDirector
	director.next_level_path = ""   # niente passaggio al livello 2 dalla demo
	add_child(main)
	for i in 6:
		await get_tree().process_frame
	if gen != _gen:
		return
	grid = get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	ulisse = get_tree().get_first_node_in_group(&"player") as GridUnit
	viewport = main.get_node("GameView/GameViewport") as SubViewport
	var hint := main.get_node_or_null(^"UI/Hint") as Control
	if hint:
		hint.visible = false
	_seed_shooters()
	seed(rng_seed)
	director.level_finished.connect(_on_level_finished)
	_last_hp = ulisse.health
	_min_hp = ulisse.health
	ulisse.health_changed.connect(_on_hp)
	for w in director.wounded:
		w.state_changed.connect(func(st: int) -> void:
			print("[demo3] %5.1fs %s -> %s (hp %d, ulisse hp %d)" % [director.elapsed, w.name, WoundedSoldier.State.keys()[st], w.health, ulisse.health]))
	print("[demo3] start: seed=%d plan=%s wounded=%d allies=%d" % [rng_seed, plan_text, director.wounded.size(), _ally_count()])
	_play(gen)


## Le difese sulle mura usano un proprio generatore casuale: lo fissiamo per ripetere la partita.
func _seed_shooters() -> void:
	var i := 0
	for n in get_tree().get_nodes_in_group(&"wall_shooters"):
		var s := n as WallShooter
		var r := s.get("_rng") as RandomNumberGenerator
		if r:
			r.seed = rng_seed + 1000 + i
			if s.profile:
				s.set("_cooldown", r.randf_range(0.5, s.profile.reload_time))
		i += 1


func _ally_count() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(&"achei"):
		if node is AllySoldier:
			n += 1
	return n


func _on_hp(cur: int, _mx: int) -> void:
	if cur < _last_hp:
		_hits_taken += 1
	_last_hp = cur
	_min_hp = mini(_min_hp, cur)


# ─────────────────────────── regia del bot ───────────────────────────

func _tick() -> void:
	await get_tree().physics_frame


func _alive() -> bool:
	return not _finished and director != null and director.phase != LevelDirector.Phase.ENDED


func _play(gen: int) -> void:
	while gen == _gen and director.phase != LevelDirector.Phase.RUNNING:
		await _tick()
	for token in plan_text.split(",", false):
		if gen != _gen or not _alive():
			return
		token = token.strip_edges().to_upper()
		if token.is_valid_int():
			var idx := int(token) - 1
			if idx >= 0 and idx < director.wounded.size():
				await _visit(gen, director.wounded[idx])
		elif token == "C" or token == "W":
			await _deliver(gen, token == "W")
	# Piano finito: se restano feriti sulla mappa, li recupera nell'ordine di vicinanza.
	while gen == _gen and _alive():
		var w := _nearest_unresolved_lying()
		if w == null:
			break
		await _visit(gen, w)
		await _deliver(gen, true)
	_set_status("Waiting for the boats")
	while gen == _gen and _alive():
		await _guard_tick(gen)


func _nearest_unresolved_lying() -> WoundedSoldier:
	var best: WoundedSoldier = null
	var bd := INF
	for w in director.wounded:
		if w.state != WoundedSoldier.State.LYING:
			continue
		var d := _p2(ulisse).distance_to(_p2(w))
		if d < bd:
			bd = d
			best = w
	return best


## Raggiunge un ferito a terra e lo sveglia (a piedi: da lì lo seguirà o arriverà la barella).
func _visit(gen: int, w: WoundedSoldier) -> void:
	if w.state != WoundedSoldier.State.LYING:
		return
	_set_status("Heading for %s%s" % [w.name.replace("Wounded", "wounded #"), " (severe)" if w.severe else ""])
	var goals := _goals_around(w.cell)
	await _goto(gen, goals, "w%d" % w.get_instance_id(), func() -> bool:
		return w.state != WoundedSoldier.State.LYING or _p2(ulisse).distance_to(_p2(w)) <= 1.55, w)
	if w.state == WoundedSoldier.State.STRETCHER:
		_set_status("Stretcher team called for %s" % w.name.replace("Wounded", "wounded #"))
		# Resta finché ci sono troiani addosso al ferito: la barella parte solo se è al sicuro.
		var t0 := director.elapsed
		while gen == _gen and _alive() and director.elapsed - t0 < 8.0 and w.state != WoundedSoldier.State.LOST and _enemy_near(w, 5.0):
			await _guard_tick(gen)
	await _tick()


## Porta all'accampamento chi ti segue, finché tutti sono in salvo (o persi).
func _deliver(gen: int, west: bool) -> void:
	if _followers().is_empty():
		return
	_set_status("Carrying the wounded to camp")
	var cr := director.rules.camp_rect
	var goals := {}
	for y in range(cr.position.y + 1, cr.end.y - 1):
		for x in range(cr.position.x + 1, cr.end.x - 1):
			var c := Vector2i(x, y)
			if grid.is_blocked(c):
				continue
			if west and x > cr.position.x + 2:
				continue
			goals[c] = true
	if goals.is_empty():
		goals[cr.position + cr.size / 2] = true
	var t0 := director.elapsed
	await _goto(gen, goals, "camp%s" % str(west), func() -> bool:
		return _followers().is_empty() or director.elapsed - t0 > 120.0, null)
	while gen == _gen and _alive() and not _followers().is_empty():
		await _guard_tick(gen)


func _followers() -> Array[WoundedSoldier]:
	var out: Array[WoundedSoldier] = []
	for w in director.wounded:
		if w.state == WoundedSoldier.State.FOLLOWING:
			out.append(w)
	return out


func _enemy_near(w: Node3D, r: float) -> bool:
	for n in get_tree().get_nodes_in_group(&"troiani"):
		var t := n as GridUnit
		if t and t.health > 0 and _p2(t).distance_to(_p2(w)) <= r:
			return true
	return false


func _goals_around(c: Vector2i) -> Dictionary:
	var goals := {}
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cc := c + Vector2i(dx, dy)
			if grid.is_inside(cc) and not grid.is_blocked(cc):
				goals[cc] = true
	return goals


# ─────────────────────────── movimento ───────────────────────────

## Cammina verso un insieme di caselle, combattendo chi minaccia Ulisse o chi protegge.
func _goto(gen: int, goals: Dictionary, key: String, stop: Callable, protect_extra: Node) -> void:
	_path.clear()
	_path_goal_key = ""
	_path_age = 99.0
	while gen == _gen and _alive():
		await _tick()
		if gen != _gen or not _alive():
			break
		var dt := get_physics_process_delta_time()
		_release_attack()
		_attack_cd -= dt
		if stop.call():
			break
		var th := _threat(protect_extra)
		if th != null:
			_fight_step(th)
			continue
		_move_step(goals, key, dt)
	_stop_input()


## Un tick di guardia (attesa): protegge feriti, portatori e Ulisse.
func _guard_tick(gen: int) -> void:
	await _tick()
	if gen != _gen:
		return
	_release_attack()
	_attack_cd -= get_physics_process_delta_time()
	var th := _threat(null)
	if th != null:
		_fight_step(th)
	else:
		_stop_input()
		_dodge_hazard_only()


func _p2(n: Node3D) -> Vector2:
	return Vector2(n.global_position.x, n.global_position.z)


## Il troiano più vicino che sta per colpire Ulisse o qualcuno da proteggere.
func _threat(extra: Node) -> GridUnit:
	var protect: Array[Node3D] = [ulisse]
	for w in director.wounded:
		if w.state in [WoundedSoldier.State.FOLLOWING, WoundedSoldier.State.SAVED, WoundedSoldier.State.CARRIED, WoundedSoldier.State.STRETCHER]:
			protect.append(w)
	if extra != null:
		protect.append(extra as Node3D)
	var up := _p2(ulisse)
	var best: GridUnit = null
	var bd := INF
	for n in get_tree().get_nodes_in_group(&"troiani"):
		var t := n as GridUnit
		if t == null or t.health <= 0:
			continue
		var tp := _p2(t)
		var d := tp.distance_to(up)
		var near := d <= 2.4
		if not near:
			for p in protect:
				if p != ulisse and tp.distance_to(_p2(p)) <= 2.1 and d <= 7.0:
					near = true
					break
		if near and d < bd:
			bd = d
			best = t
	return best


func _fight_step(t: GridUnit) -> void:
	var to := _p2(t) - _p2(ulisse)
	if to.length() > 1.15:
		_steer(to, 1.0)
	else:
		_steer(to, 0.0)
		_face(to)
	if to.length() <= 1.55 and _attack_cd <= 0.0:
		_attack_cd = ulisse.attack_cooldown + 0.02
		_press_attack()


func _face(dir: Vector2) -> void:
	# Un piccolo input verso il nemico basta a girare Ulisse senza spostarlo.
	_steer(dir, 0.25)


func _press_attack() -> void:
	Input.action_press(&"attack")
	_attack_release = true


func _release_attack() -> void:
	if _attack_release:
		Input.action_release(&"attack")
		_attack_release = false


func _move_step(goals: Dictionary, key: String, dt: float) -> void:
	_path_age += dt
	_hazard_age += dt
	if _hazard_age > 0.1:
		_hazard_age = 0.0
		_refresh_hazards()
	var carrying := not _followers().is_empty()
	if _path.is_empty() or _path_goal_key != key or _path_age > 0.5:
		_path_goal_key = key
		_path_age = 0.0
		_path = _find_path(ulisse.cell, goals, not carrying)
	var up := _p2(ulisse)
	# Fuori da una casella pericolosa: prima di tutto un passo di lato.
	if _hazard.has(ulisse.cell):
		var safe := _nearest_safe(ulisse.cell)
		if safe != ulisse.cell:
			_steer(Vector2(grid.cell_to_world(safe).x, grid.cell_to_world(safe).z) - up, 1.0)
			return
	if _path.is_empty():
		_stop_input()
		return
	# Scarta le caselle già superate.
	while _path.size() > 1 and _p2c(_path[0]).distance_to(up) < 0.5:
		_path.pop_front()
	var target := _lookahead(up)
	var dir := target - up
	# Incastrato: un passo di lato.
	var now := Time.get_ticks_msec() / 1000.0
	_stuck += dt
	if _stuck >= 0.7:
		if up.distance_to(_last_pos) < 0.45:
			_side_until = now + 0.45
			_side_sign = -_side_sign
			_path_age = 99.0
		_stuck = 0.0
		_last_pos = up
	if now < _side_until:
		dir = dir.rotated(_side_sign * PI * 0.5)
	_steer(dir, 1.0)


func _p2c(c: Vector2i) -> Vector2:
	var w := grid.cell_to_world(c)
	return Vector2(w.x, w.z)


## Il punto più lontano del percorso raggiungibile in linea retta (senza scavalcare).
func _lookahead(up: Vector2) -> Vector2:
	if _path.is_empty():
		return up
	var limit := mini(_path.size() - 1, 9)
	var best := 0
	for i in range(0, limit + 1):
		if i > 0 and (_path[i] - _path[i - 1]).length_squared() > 1:
			break   # balzo sopra un ostacolo: si arriva dritti alla casella di partenza
		if i == 0 or _clear_line(up, _p2c(_path[i])):
			best = i
		else:
			break
	return _p2c(_path[best])


func _clear_line(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var len := d.length()
	var n := int(ceil(len / 0.3))
	var side := Vector2(-d.y, d.x).normalized() * 0.34 if len > 0.001 else Vector2.ZERO
	var prev := grid.world_to_cell(Vector3(a.x, 0.0, a.y))
	for i in range(1, n + 1):
		var p := a + d * (float(i) / n)
		for off in [Vector2.ZERO, side, -side]:
			var q: Vector2 = p + off
			var c := grid.world_to_cell(Vector3(q.x, 0.0, q.y))
			if not grid.is_inside(c) or grid.is_blocked(c) or _hazard.has(c):
				return false
		var cc := grid.world_to_cell(Vector3(p.x, 0.0, p.y))
		if cc != prev:
			if not grid.step_allowed(prev, cc):
				return false
			prev = cc
	return true


## Direzione nel mondo -> input a schermo secondo la camera di gioco, con gli stessi comandi del giocatore.
func _steer(world_dir: Vector2, strength: float) -> void:
	var cam := viewport.get_camera_3d()
	if world_dir.length() < 0.001 or cam == null or strength <= 0.0:
		_stop_input()
		return
	var r := Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var f := Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
	var w := Vector3(world_dir.x, 0.0, world_dir.y).normalized()
	var s := Vector2(w.dot(r), -w.dot(f)) * strength
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


# ─────────────────────────── pericoli dalle mura ───────────────────────────

func _refresh_hazards() -> void:
	_hazard.clear()
	for n in get_tree().get_nodes_in_group(&"target_markers"):
		var m := n as Node3D
		if m and m.is_inside_tree():
			_hazard[grid.world_to_cell(m.global_position)] = true
	for n in get_tree().get_nodes_in_group(&"burning_cells"):
		var b := n as BurningCell
		if b:
			_hazard[b.cell] = true


func _nearest_safe(c: Vector2i) -> Vector2i:
	var best := c
	var bd := INF
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var cc := c + Vector2i(dx, dy)
				if not grid.is_inside(cc) or grid.is_blocked(cc) or _hazard.has(cc) or not grid.step_allowed(c, cc):
					continue
				var d := Vector2(dx, dy).length()
				if d < bd:
					bd = d
					best = cc
		if best != c:
			return best
	return c


func _dodge_hazard_only() -> void:
	_hazard_age += get_physics_process_delta_time()
	if _hazard_age > 0.1:
		_hazard_age = 0.0
		_refresh_hazards()
	if _hazard.has(ulisse.cell):
		var safe := _nearest_safe(ulisse.cell)
		if safe != ulisse.cell:
			_steer(_p2c(safe) - _p2(ulisse), 1.0)


# ─────────────────────────── percorsi ───────────────────────────

## Percorso più breve (Dijkstra con coda a heap) verso la più vicina delle caselle `goals`.
## Con `allow_vault` conta anche gli ostacoli bassi scavalcabili da Ulisse (un ferito non li scavalca).
func _find_path(from: Vector2i, goals: Dictionary, allow_vault: bool) -> Array[Vector2i]:
	var w := grid.size.x
	var n := w * grid.size.y
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var heap_c: Array[float] = []
	var heap_i: Array[int] = []
	var start := from.y * w + from.x
	dist[start] = 0.0
	_heap_push(heap_c, heap_i, 0.0, start)
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var found := -1
	while not heap_i.is_empty():
		var top := _heap_pop(heap_c, heap_i)
		var cost: float = top[0]
		var idx: int = top[1]
		if cost > dist[idx]:
			continue
		var c := Vector2i(idx % w, idx / w)
		if goals.has(c):
			found = idx
			break
		for d in dirs:
			var nb := c + d
			var step := 1.0
			if not grid.is_inside(nb):
				continue
			if grid.is_blocked(nb):
				if allow_vault and grid.is_vaultable(nb) and grid.can_vault_over(c, d):
					nb = nb + d
					step = 3.0
				else:
					continue
			elif not grid.step_allowed(c, nb):
				continue
			if _hazard.has(nb):
				step += 6.0
			var occ := grid.get_occupant(nb) as GridUnit
			if occ != null and occ.team == GridUnit.Team.TROIANI and occ.health > 0:
				step += 2.0
			var ni := nb.y * w + nb.x
			if cost + step < dist[ni]:
				dist[ni] = cost + step
				prev[ni] = idx
				_heap_push(heap_c, heap_i, cost + step, ni)
	var out: Array[Vector2i] = []
	if found < 0:
		return out
	var cur := found
	while cur != -1:
		out.push_front(Vector2i(cur % w, cur / w))
		cur = prev[cur]
	return out


func _heap_push(hc: Array[float], hi: Array[int], cost: float, idx: int) -> void:
	hc.append(cost)
	hi.append(idx)
	var i := hc.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if hc[p] <= hc[i]:
			break
		var tc := hc[p]
		hc[p] = hc[i]
		hc[i] = tc
		var ti := hi[p]
		hi[p] = hi[i]
		hi[i] = ti
		i = p


func _heap_pop(hc: Array[float], hi: Array[int]) -> Array:
	var top := [hc[0], hi[0]]
	var lc: float = hc.pop_back()
	var li: int = hi.pop_back()
	if not hc.is_empty():
		hc[0] = lc
		hi[0] = li
		var i := 0
		var n := hc.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and hc[l] < hc[m]:
				m = l
			if r < n and hc[r] < hc[m]:
				m = r
			if m == i:
				break
			var tc := hc[m]
			hc[m] = hc[i]
			hc[i] = tc
			var ti := hi[m]
			hi[m] = hi[i]
			hi[i] = ti
			i = m
	return top


# ─────────────────────────── fine e schermata ───────────────────────────

func _on_level_finished(summary: Dictionary) -> void:
	_finished = true
	_stop_input()
	_release_attack()
	var hud = director.hud
	if hud and hud.get("_end_panel") != null:
		(hud.get("_end_panel") as Control).visible = false
	var t := director.elapsed
	var text := "Level 1 solved in %s\n\nWounded saved: %d / %d  (lost: %d)\nEvacuated to the ships: %d\nTrojans defeated: %d\nWaves faced: %d\nOdysseus: lowest health %d / %d, %d hits taken\nOutcome: %s" % [
		_fmt(t), summary["saved"], summary["total"], summary["lost"], summary["evacuated"], summary["kills"],
		summary["waves"], _min_hp, ulisse.max_health, _hits_taken, summary["title"]]
	_title_label.text = "MISSION COMPLETE"
	_end_label.text = text
	_end_panel.visible = true
	print("[demo3] RESULT time=%.1f saved=%d lost=%d evacuated=%d kills=%d waves=%d min_hp=%d hits=%d plan=%s seed=%d" % [
		t, summary["saved"], summary["lost"], summary["evacuated"], summary["kills"], summary["waves"], _min_hp, _hits_taken, plan_text, rng_seed])
	if _arg_auto_quit:
		await get_tree().create_timer(8.0).timeout
		_quit()


func _fmt(t: float) -> String:
	return "%02d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _set_status(s: String) -> void:
	_status = s


func _process(_delta: float) -> void:
	if director == null or ulisse == null or not is_instance_valid(ulisse):
		return
	_clock_label.text = _fmt(director.elapsed)
	if _arg_trace and director.elapsed >= _trace_next:
		_trace_next = director.elapsed + 2.0
		var tr := 0
		for n in get_tree().get_nodes_in_group(&"troiani"):
			tr += 1
		print("[trace] %5.1f u=(%.1f,%.1f) hp=%d troians=%d fol=%d %s cell=%s path=%s mov=%s" % [director.elapsed, ulisse.global_position.x, ulisse.global_position.z, ulisse.health, tr, _followers().size(), _status, ulisse.cell, _path.slice(0, 4), Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")])
	var saved := director.saved_count()
	_info_label.text = "Wounded: %d safe in camp, %d on the ships, %d lost / %d     Wave %d     HP %d" % [
		saved, director.evacuated_count(), director.lost_count(), director.wounded.size(), director.wave, ulisse.health]
	_status_label.text = "Bot: %s" % _status if not _finished else ""
	if _arg_shots != "" and _next_shot < _arg_shot_times.size() and director.elapsed >= _arg_shot_times[_next_shot]:
		var t := _arg_shot_times[_next_shot]
		_next_shot += 1
		_save_shot(t)


func _save_shot(t: float) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/demo3_%03d.png" % [_arg_shots, int(t)])


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 60
	add_child(_ui)
	# Il HUD del gioco occupa il centro in alto (titolo, obiettivo) e il banner a y~190:
	# i testi della demo stanno a sinistra, sotto il ritratto, e in basso sopra lo stato.
	var title := _label(14, Control.PRESET_TOP_LEFT)
	title.offset_top = 236
	title.offset_bottom = 256
	title.offset_left = 16
	title.offset_right = 340
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.text = "DEMO 3  -  speedrun, no cheats"
	title.modulate.a = 0.8
	_clock_label = _label(40, Control.PRESET_TOP_LEFT)
	_clock_label.offset_top = 254
	_clock_label.offset_bottom = 308
	_clock_label.offset_left = 16
	_clock_label.offset_right = 340
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_clock_label.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.5))
	_info_label = _label(16, Control.PRESET_CENTER_BOTTOM)
	_info_label.offset_top = -92
	_info_label.offset_bottom = -68
	_info_label.offset_left = -400
	_info_label.offset_right = 400
	_status_label = _label(20, Control.PRESET_CENTER_BOTTOM)
	_status_label.offset_top = -64
	_status_label.offset_bottom = -30
	_status_label.offset_left = -400
	_status_label.offset_right = 400
	_help = _label(14, Control.PRESET_BOTTOM_RIGHT)
	_help.offset_left = -420
	_help.offset_top = -30
	_help.offset_right = -12
	_help.offset_bottom = -8
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help.text = "R  restart    Space  pause    Esc  quit"
	_help.modulate.a = 0.7
	_help.visible = not _arg_clean
	_end_panel = PanelContainer.new()
	_end_panel.visible = false
	_end_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_end_panel)
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.offset_left = -330
	_end_panel.offset_right = 330
	_end_panel.offset_top = -170
	_end_panel.offset_bottom = 170
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.09, 0.06, 0.92)
	style.border_color = Color(0.72, 0.52, 0.25)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	_end_panel.add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	_end_panel.add_child(box)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override(&"font_size", 36)
	_title_label.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.5))
	box.add_child(_title_label)
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override(&"font_size", 20)
	box.add_child(_end_label)


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


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE:
			_quit()
		KEY_R:
			_stop_input()
			_boot()
		KEY_SPACE:
			_paused = not _paused
			get_tree().paused = _paused


func _quit() -> void:
	_stop_input()
	Engine.time_scale = 1.0
	get_tree().quit()
