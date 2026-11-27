class_name Level2Director
extends Node
## Regia del livello 2, "Il dono del mare": Ulisse e gli Achei costruiscono il cavallo di Troia.
##  1. Legname: si abbatte un abete (E), si sfronda, si porta il tronco al ruscello e lo si lascia galleggiare
##     fino alla spiaggia, lo si riporta a riva, lo si squadra sul banco e si porta la trave al cantiere.
##  2. Costruzione a pezzi: ogni fase consuma travi e il cavallo "cresce" (piano di taglio nello shader).
##     A meta' (il ventre) arriva di notte un'incursione di troiani con le torce, circa un minuto, senza fuoco.
##  3. Finale: gli Achei entrano nel cavallo (Ulisse per ultimo), la flotta parte, i troiani trovano il cavallo
##     sulla spiaggia e lo trascinano lungo il sentiero fino alle mura lontane.
## Se Ulisse cade, riparte dal campo e il lavoro fatto resta. Tutti i testi visibili sono in inglese.

signal level_finished

enum Phase { BUILD, FINALE, ENDED }

const BEAMS_PER_STAGE := [1, 2, 2, 2, 1]
const STAGE_NAMES := ["Foundation", "Legs and frame", "Belly and ribs", "Neck and head", "Finishing and hatch"]
const STAGE_TARGET := [0.18, 0.42, 0.7, 0.93, 1.0]
const STAGE_TIME := 11.0
const REACH := 2.4
const RAID_STAGE := 2
const RAID_MAX := 75.0

var world: Level2World
var hud: Level2Hud
var phase := Phase.BUILD
var player: GridUnit

## Un abete: {node, spot, state, trunk, d, yaw}. Stati: STANDING, FALLEN, TRIMMED, FLOATING, LANDED, SQUARED.
var trees: Array[Dictionary] = []
enum T { STANDING, FALLEN, TRIMMED, FLOATING, LANDED, SQUARED, USED }

var carry := ""            # "", "trunk", "beam"
var carry_index := -1
var carry_node: Node3D
var pile_beams := 0
var beams_delivered := 0
var stage := 0
var stage_active := false
var stage_t := 0.0
var _task := {}
var _task_start := Vector3.ZERO
var _task_hp := 0
var _land_d := 0.0
var _landed_count := 0
var raid_active := false
var raid_done := false
var raid_t := 0.0
var raiders: Array[GridUnit] = []
var patrols: Array[Dictionary] = []
var _patrol_clock := 0.0
var _epeus_t := 0.0
var _stage_from := 0.0
var _horse_ready := false
var _hatch := Vector2.ZERO
var _inside := 0
var _log_mesh_material: Material
var _prompt_cache := ""
var _ally_clock := []
var _called: Node3D = null
var helper: Node3D = null          # compagno che porta il tronco con Ulisse
var _fwd := Vector3(0, 0, -1)
var _last_pp := Vector3.ZERO
var _helpers_at_site := 0
var _wood_material: StandardMaterial3D
var _work_sfx_t := 0.0
var _work_sfx_i := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	world = get_tree().get_first_node_in_group(&"level2_world") as Level2World
	if world == null:
		push_warning("Level2Director: nessun Level2World.")
		return
	player = world.player
	var ui := get_parent().get_node_or_null(^"UI")
	hud = Level2Hud.new()
	hud.name = "Level2Hud"
	if ui:
		ui.add_child(hud)
	else:
		add_child(hud)
	hud.replay_pressed.connect(func() -> void: get_tree().reload_current_scene())
	player.health_changed.connect(func(c: int, m: int) -> void: hud.set_health(c, m))
	hud.set_health(player.health, player.max_health)
	player.set(&"spawn_cell", world.cell_of(Level2World.START))
	player.died.connect(_on_player_died)
	_hatch = Level2World.SITE + Vector2(0.0, 3.6)
	_land_d = world.stream_project(Level2World.LANDING).x
	for i in world.tree_nodes.size():
		trees.append({"node": world.tree_nodes[i], "spot": Level2World.TREE_SPOTS[i], "state": T.STANDING, "trunk": null, "d": 0.0, "yaw": 0.0})
	_make_wood_material()
	_set_carpenters_working(false)
	_spawn_patrols()
	_refresh_objectives()
	hud.show_banner("Fell the firs, float the logs down the stream and bring beams to Epeus!", 5.0)
	hud.show_subtitle("Epeus", "The sea will seem to bring us this gift, Odysseus. Bring me beams, and I will raise the horse.", 5.5)


# ------------------------------------------------------------------ ciclo

func _process(delta: float) -> void:
	if world == null or player == null or phase == Phase.ENDED:
		return
	_update_epeus(delta)
	_update_tree_fade(delta)
	if phase == Phase.BUILD:
		_update_floating(delta)
		_update_carry(delta)
		_update_called()
		_update_task(delta)
		_update_prompt()
		_update_stage(delta)
		_update_work_sfx(delta)
		_update_allies(delta)
		_update_raid(delta)
		_update_patrols(delta)
		if _task.is_empty() and Input.is_action_just_pressed(&"interact"):
			_interact()
	elif phase == Phase.FINALE and _horse_ready:
		_update_prompt()
		if Input.is_action_just_pressed(&"interact"):
			_interact()


func _snd(sound: String, pos: Vector3, volume_db := 0.0) -> void:
	GameAudio.sfx(self, sound, pos, volume_db)


## Colpi di martello e sega dal cantiere finche' i carpentieri lavorano.
func _update_work_sfx(delta: float) -> void:
	if not stage_active or raid_active:
		return
	_work_sfx_t -= delta
	if _work_sfx_t > 0.0:
		return
	_work_sfx_t = 3.6
	_work_sfx_i += 1
	_snd("saw" if _work_sfx_i % 3 == 0 else "hammer", world.world_of(Level2World.SITE), -4.0)


func _p2(n: Node3D) -> Vector2:
	return Vector2(n.global_position.x, n.global_position.z)


func _pp() -> Vector2:
	return _p2(player)


func _make_wood_material() -> void:
	var src := load(Level2World.L2 + "trave.glb") as PackedScene
	var inst := src.instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).get_active_material(0)
		if mat:
			_wood_material = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			break
	inst.free()
	if _wood_material:
		_wood_material.uv1_scale = Vector3(3.5, 1.0, 1.0)
		_wood_material.albedo_color = Color(0.72, 0.62, 0.52)


# ------------------------------------------------------------------ interazioni

func _nearest_tree(states: Array) -> int:
	var best := -1
	var best_d := REACH + 0.6
	var pp := _pp()
	for i in trees.size():
		if not states.has(trees[i]["state"]):
			continue
		var pos: Vector2 = trees[i]["spot"]
		if trees[i]["state"] in [T.FLOATING, T.LANDED]:
			pos = _p2(trees[i]["trunk"])
		var d := pp.distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## Che cosa si puo' fare adesso: {text, kind, index, duration}. Vuoto se niente.
func _action() -> Dictionary:
	var pp := _pp()
	if phase == Phase.FINALE:
		if _horse_ready and pp.distance_to(_hatch) < 3.2 and _inside >= world.allies.size():
			return {"text": "E - Climb into the horse (last)", "kind": "enter"}
		if _horse_ready and pp.distance_to(_hatch) < 3.2:
			return {"text": "Wait: your men are still climbing in...", "kind": ""}
		return {}
	if not _task.is_empty():
		return {}
	if carry == "":
		var i := _nearest_tree([T.STANDING])
		if i >= 0:
			return {"text": "E - Fell the fir", "kind": "fell", "index": i, "duration": 3.4}
		i = _nearest_tree([T.FALLEN])
		if i >= 0:
			return {"text": "E - Strip the branches", "kind": "trim", "index": i, "duration": 2.6}
		i = _nearest_tree([T.TRIMMED])
		if i >= 0:
			return _help_action(i, "lift", "Lift the log")
		i = _nearest_tree([T.LANDED])
		if i >= 0:
			return _help_action(i, "haul", "Haul the log ashore")
		i = _nearest_tree([T.FLOATING])
		if i >= 0:
			return {"text": "The log is drifting down the stream...", "kind": ""}
	elif carry == "trunk":
		var proj := world.stream_project(pp)
		var floated: bool = trees[carry_index]["state"] == T.LANDED or trees[carry_index].get("floated", false)
		if not floated and proj.y < 3.2 and proj.x < _land_d - 4.0:
			return {"text": "E - Float the log down the stream", "kind": "float"}
		if floated and pp.distance_to(Level2World.BENCH) < 3.0:
			return {"text": "E - Square the log into a beam", "kind": "square", "duration": 3.0}
		if not floated:
			return {"text": "Carry the log to the stream (E to float it)", "kind": ""}
		return {"text": "Take the log to the work bench", "kind": ""}
	elif carry == "beam":
		if pp.distance_to(Level2World.PILE) < 3.6 or pp.distance_to(Level2World.SITE) < 5.5:
			return {"text": "E - Deliver the beam to Epeus", "kind": "deliver"}
		return {"text": "Take the beam to the building site", "kind": ""}
	return {}


## Un tronco grande non lo porta un uomo solo: serve un compagno (soldato, o carpentiere se nessun soldato e' libero).
func _helper_candidates() -> Array[Node3D]:
	var list: Array[Node3D] = []
	for a in world.allies:
		var u := a as AllySoldier
		if u and is_instance_valid(u) and u.health > 0 and not u.busy:
			list.append(u)
	if list.is_empty():
		for c in world.carpenters:
			list.append(c)
	return list


func _help_action(i: int, kind: String, label: String) -> Dictionary:
	var tr := trees[i]
	var pos: Vector2 = _p2(tr["trunk"]) if tr["trunk"] else tr["spot"]
	var best: Node3D = null
	var bd := INF
	for c in _helper_candidates():
		var d := _p2(c).distance_to(pos)
		if d < bd:
			bd = d
			best = c
	if best == null:
		return {"text": "No one is free to help lift the log...", "kind": ""}
	_call_helper(best, pos)
	if bd > 3.2:
		return {"text": "A comrade is coming to help you lift the log...", "kind": ""}
	return {"text": "E - %s together with a comrade" % label, "kind": kind, "index": i, "helper": best}


## Il compagno raggiunge il tronco camminando (soldati e carpentieri); resta "occupato" finche' non si usa o Ulisse si allontana.
func _call_helper(h: Node3D, pos: Vector2) -> void:
	if h.has_meta(&"calling") or h == _called:
		return
	if _called != null and is_instance_valid(_called) and _called != helper:
		_release_node(_called)
	_called = h
	h.set_meta(&"calling", true)
	var u := h as AllySoldier
	if u:
		u.busy = true
		if u._tween:
			u._tween.kill()
		world.grid.release(u.cell, u)
		u.is_moving = true
	else:
		world.person_play(h, "Walking")
	var target := Vector3(pos.x + 1.4, 0.0, pos.y + 0.8)
	var d := Vector2(target.x - h.global_position.x, target.z - h.global_position.z)
	if u:
		var model := u.get_node_or_null(^"Model") as Node3D
		if model:
			model.rotation.y = atan2(-d.x, -d.y)
	else:
		h.rotation.y = atan2(d.x, d.y)
	var tw := create_tween()
	tw.tween_property(h, "global_position", target, maxf(d.length() / 3.0, 0.3))
	tw.finished.connect(func() -> void:
		if not is_instance_valid(h):
			return
		h.remove_meta(&"calling")
		if u:
			u.is_moving = false
		else:
			world.person_play(h, "Idle_11"))


func _release_node(h: Node3D) -> void:
	if h == null or not is_instance_valid(h):
		return
	h.remove_meta(&"calling")
	var u := h as AllySoldier
	if u:
		u.is_moving = false
		var c := world.grid.world_to_cell(u.global_position)
		u.busy = false
		u.cell = c
		world.grid.occupy(c, u)
		u.post_cell = c
	else:
		world.person_play(h, "Idle_11")
	if h == _called:
		_called = null


## Se Ulisse se ne va senza usare il compagno chiamato, questo torna libero.
func _update_called() -> void:
	if _called != null and is_instance_valid(_called) and carry == "" and _p2(_called).distance_to(_pp()) > 9.0:
		_release_node(_called)


func _update_prompt() -> void:
	var a := _action()
	var text: String = a.get("text", "")
	if text != _prompt_cache:
		_prompt_cache = text
		hud.set_prompt(text)


func _interact() -> void:
	var a := _action()
	var kind: String = a.get("kind", "")
	match kind:
		"fell", "trim", "square":
			_begin_task(a)
		"lift":
			_pick_trunk(a["index"], false, a.get("helper"))
		"haul":
			_pick_trunk(a["index"], true, a.get("helper"))
		"float":
			_float_log()
		"deliver":
			_deliver_beam()
		"enter":
			_enter_horse()


func _begin_task(a: Dictionary) -> void:
	_task = a.duplicate()
	_task["t"] = 0.0
	_task_start = player.global_position
	_task_hp = player.health
	var focus := player.global_position + Vector3(1, 0, 0)
	if a.has("index"):
		var s: Vector2 = trees[a["index"]]["spot"]
		focus = Vector3(s.x, 0, s.y)
	elif a["kind"] == "square":
		focus = world.world_of(Level2World.BENCH)
	if player.has_method(&"start_help_up"):
		player.call(&"start_help_up", focus, float(a["duration"]))
	var labels := {"fell": "Felling the fir...", "trim": "Stripping the branches...", "square": "Squaring the log..."}
	hud.set_work(labels[a["kind"]], 0.0)
	match a["kind"]:
		"fell", "trim":
			_snd("axe_chop", focus, -2.0 if a["kind"] == "fell" else -6.0)
		"square":
			_snd("saw", focus, -3.0)


func _update_task(delta: float) -> void:
	if _task.is_empty():
		return
	if player.health < _task_hp or player.global_position.distance_to(_task_start) > 1.0:
		_task = {}
		hud.set_work("", 0.0)
		return
	_task["t"] += delta
	hud.set_work(hud._work_label.text, clampf(_task["t"] / float(_task["duration"]), 0.0, 1.0))
	if _task["t"] < float(_task["duration"]):
		return
	var t := _task
	_task = {}
	hud.set_work("", 0.0)
	match t["kind"]:
		"fell":
			_fell_tree(t["index"])
		"trim":
			_trim_tree(t["index"])
		"square":
			_square_log()


func _fell_tree(i: int) -> void:
	var tr := trees[i]
	tr["state"] = T.FALLEN
	var node: Node3D = tr["node"]
	var spot: Vector2 = tr["spot"]
	var away := (spot - _pp()).normalized()
	if away == Vector2.ZERO:
		away = Vector2(1, 0)
	tr["yaw"] = atan2(-away.y, away.x)
	var axis := Vector3(away.y, 0.0, -away.x)   # asse orizzontale perpendicolare alla caduta
	var base := node.basis
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void:
		node.basis = Basis(axis, a) * base, 0.0, deg_to_rad(86.0), 1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		node.position.y = 0.25)
	_unblock(spot)
	_snd("tree_fall", Vector3(spot.x, 0.5, spot.y), 0.0)
	hud.show_banner("Timber!", 1.2)
	_refresh_objectives()


func _unblock(spot: Vector2) -> void:
	var c := world.cell_of(spot)
	world.grid.set_blocked(c, false)


func _trim_tree(i: int) -> void:
	var tr := trees[i]
	tr["state"] = T.TRIMMED
	var node: Node3D = tr["node"]
	node.visible = false
	var trunk := _make_trunk()
	var spot: Vector2 = tr["spot"]
	trunk.position = Vector3(spot.x, 0.2, spot.y)
	trunk.rotation.y = tr["yaw"]
	world.add_child(trunk)
	tr["trunk"] = trunk
	_refresh_objectives()


func _make_trunk() -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.19
	cyl.height = 3.4
	cyl.radial_segments = 14
	mesh.mesh = cyl
	mesh.rotation_degrees = Vector3(0, 0, 90)
	if _wood_material:
		var m := _wood_material.duplicate() as StandardMaterial3D
		m.albedo_color = Color(0.55, 0.42, 0.32)
		mesh.material_override = m
	root.add_child(mesh)
	return root


func _make_beam() -> Node3D:
	return world.spawn_model(Level2World.L2 + "trave.glb", Vector3.ZERO, 0.0, 0.0, world, 3.0)


func _pick_trunk(i: int, from_water: bool, with: Node3D) -> void:
	var tr := trees[i]
	carry = "trunk"
	carry_index = i
	var trunk: Node3D = tr["trunk"]
	if from_water:
		_landed_count = maxi(_landed_count - 1, 0)
	carry_node = trunk
	_attach_helper(with)
	_last_pp = player.global_position
	_set_carrying(true)
	hud.show_banner("Two men carry the log. Take it slowly.", 2.0)
	_refresh_objectives()


func _attach_helper(h: Node3D) -> void:
	helper = h
	_called = null
	h.remove_meta(&"calling")
	var u := h as AllySoldier
	if u:
		u.busy = true
		if u._tween:
			u._tween.kill()
		u.is_moving = false


func _release_helper() -> void:
	var h := helper
	helper = null
	_release_node(h)


## Il tronco sta sulle spalle di Ulisse (davanti) e del compagno (dietro), lungo la direzione di marcia.
func _update_carry(delta: float) -> void:
	if carry != "trunk" or carry_node == null or not is_instance_valid(carry_node):
		return
	var pos := player.global_position
	var d := pos - _last_pp
	d.y = 0.0
	var moving := d.length() > 0.004
	if moving:
		_fwd = _fwd.lerp(d.normalized(), clampf(10.0 * delta, 0.0, 1.0)).normalized()
	_last_pp = pos
	carry_node.global_position = pos - _fwd * 1.35 + Vector3(0, 1.25, 0)
	carry_node.rotation = Vector3(0, atan2(-_fwd.z, _fwd.x), 0)
	if helper and is_instance_valid(helper):
		var hp := pos - _fwd * 2.75
		hp.y = 0.0
		helper.global_position = hp
		var u := helper as GridUnit
		if u:
			u.is_moving = moving
			var model := u.get_node_or_null(^"Model") as Node3D
			if model:
				model.rotation.y = lerp_angle(model.rotation.y, atan2(-_fwd.x, -_fwd.z), clampf(10.0 * delta, 0.0, 1.0))
		else:
			helper.rotation.y = lerp_angle(helper.rotation.y, atan2(_fwd.x, _fwd.z), clampf(10.0 * delta, 0.0, 1.0))
			if moving != helper.get_meta(&"moving", false):
				helper.set_meta(&"moving", moving)
				world.person_play(helper, "Walking" if moving else "Idle_11")


func _set_carrying(on: bool) -> void:
	player.set(&"speed_multiplier", 0.6 if on else 1.0)


func _drop_carry_node() -> void:
	if carry_node and is_instance_valid(carry_node):
		carry_node.queue_free()
	carry_node = null


func _float_log() -> void:
	var tr := trees[carry_index]
	_drop_carry_node()
	_release_helper()
	var proj := world.stream_project(_pp())
	var nt := _make_trunk()
	world.add_child(nt)
	var p := world.stream_point(proj.x)
	nt.position = Vector3(p.x, -0.1, p.y)
	tr["trunk"] = nt
	tr["d"] = proj.x
	tr["state"] = T.FLOATING
	tr["floated"] = true
	carry = ""
	carry_index = -1
	_set_carrying(false)
	_snd("log_splash", nt.position, -2.0)
	hud.show_banner("The current carries the log to the beach.", 2.2)
	_refresh_objectives()


func _update_floating(delta: float) -> void:
	for i in trees.size():
		var tr := trees[i]
		if tr["state"] != T.FLOATING:
			continue
		var stop := _land_d - 0.5 - 0.8 * _landed_count
		tr["d"] = minf(tr["d"] + 1.4 * delta, stop)
		var p := world.stream_point(tr["d"])
		var q := world.stream_point(tr["d"] + 0.4)
		var trunk: Node3D = tr["trunk"]
		trunk.position = Vector3(p.x, -0.08 + 0.025 * sin(Time.get_ticks_msec() * 0.003 + i), p.y)
		var tangent := q - p
		if tangent.length() > 0.01:
			trunk.rotation.y = atan2(-tangent.y, tangent.x)
		if tr["d"] >= stop - 0.001:
			tr["state"] = T.LANDED
			_landed_count += 1
			hud.show_banner("A log has reached the shore - haul it out!", 2.2)
			_refresh_objectives()


func _square_log() -> void:
	_drop_carry_node()
	_release_helper()
	var beam := _make_beam()
	beam.get_parent().remove_child(beam)
	player.add_child(beam)
	beam.position = Vector3(0, 1.5, 0)
	beam.rotation = Vector3.ZERO
	carry_node = beam
	carry = "beam"
	trees[carry_index]["state"] = T.SQUARED
	_refresh_objectives()


func _deliver_beam() -> void:
	_drop_carry_node()
	carry = ""
	trees[carry_index]["state"] = T.USED
	carry_index = -1
	_set_carrying(false)
	pile_beams += 1
	beams_delivered += 1
	_update_pile()
	_snd("wood_drop", world.world_of(Level2World.PILE), -2.0)
	hud.show_banner("Beam delivered.", 1.4)
	_refresh_objectives()


func _update_pile() -> void:
	var pile := world.get_node_or_null(^"Cantiere/PilaTravi") as Node3D
	if pile:
		pile.visible = pile_beams > 0


func _on_player_died() -> void:
	# Ulisse riparte dal campo: il lavoro fatto resta, ma il carico in spalla torna a terra.
	if carry == "trunk" and carry_index >= 0:
		var tr := trees[carry_index]
		var trunk := _make_trunk()
		world.add_child(trunk)
		trunk.position = Vector3(player.global_position.x, 0.2, player.global_position.z)
		tr["trunk"] = trunk
		if tr.get("floated", false):
			tr["state"] = T.TRIMMED
		else:
			tr["state"] = T.TRIMMED
	elif carry == "beam" and carry_index >= 0:
		trees[carry_index]["state"] = T.SQUARED
		pile_beams += 1
		beams_delivered += 1
		trees[carry_index]["state"] = T.USED
		_update_pile()
		hud.show_banner("Odysseus fell... his men bring the beam to the site.", 3.0)
	_drop_carry_node()
	_release_helper()
	carry = ""
	carry_index = -1
	_set_carrying(false)
	_task = {}
	hud.set_work("", 0.0)
	_refresh_objectives()


# ------------------------------------------------------------------ costruzione

func _set_carpenters_working(on: bool) -> void:
	var anims := ["Sega", "Heavy_Hammer_Swing", "Sega"]
	for i in world.carpenters.size():
		var c := world.carpenters[i]
		if on:
			world.person_play(c, anims[i])
		else:
			world.person_play(c, "Idle_11" if i % 2 == 0 else "Idle_12")


func _update_stage(delta: float) -> void:
	if stage >= BEAMS_PER_STAGE.size():
		return
	if not stage_active:
		if pile_beams >= BEAMS_PER_STAGE[stage] and not (raid_active):
			stage_active = true
			stage_t = 0.0
			_stage_from = STAGE_TARGET[stage - 1] if stage > 0 else 0.0
			pile_beams -= BEAMS_PER_STAGE[stage]
			_update_pile()
			_set_carpenters_working(true)
			hud.show_banner("The carpenters raise: %s" % STAGE_NAMES[stage], 3.0)
			hud.show_subtitle("Epeus", ["Lay the keel true, lads!", "The legs must bear the whole belly!", "Now the ribs of the old ships!", "The neck, then the head - toward the city!", "Last the hatch and the dedication."][stage], 4.0)
			if stage == RAID_STAGE and not raid_done:
				_schedule_raid()
			_refresh_objectives()
		return
	if raid_active:
		return   # i carpentieri si riparano finche' i raiders sono in giro
	stage_t += delta * (1.0 + 0.2 * _helpers_at_site)
	var k := clampf(stage_t / STAGE_TIME, 0.0, 1.0)
	world.set_horse_progress(lerpf(_stage_from, STAGE_TARGET[stage], k))
	if stage_t >= STAGE_TIME:
		stage_active = false
		stage += 1
		_set_carpenters_working(false)
		_refresh_objectives()
		if stage >= BEAMS_PER_STAGE.size():
			_on_horse_finished()
		else:
			hud.show_banner("%s complete." % STAGE_NAMES[stage - 1], 2.5)


## Gli alberi tra la camera e Ulisse (o il cavallo) si fanno trasparenti, cosi' non si perde di vista il lavoro.
func _update_tree_fade(delta: float) -> void:
	var cam := world.camera
	var focus := player.global_position
	var to_cam := Vector3(cam.global_position.x - focus.x, 0.0, cam.global_position.z - focus.z).normalized()
	for t in world.all_trees:
		if not is_instance_valid(t) or not t.visible:
			continue
		var rel := t.global_position - focus
		rel.y = 0.0
		var along := rel.dot(to_cam)
		var side := absf(rel.dot(Vector3(-to_cam.z, 0.0, to_cam.x)))
		var covering := along > -1.0 and along < 11.0 and side < 3.6 + along * 0.15
		var target := 0.94 if covering else 0.0
		var cur: float = t.get_meta(&"fade", 0.0)
		cur = move_toward(cur, target, delta * 3.0)
		if absf(cur - float(t.get_meta(&"fade", 0.0))) > 0.001:
			t.set_meta(&"fade", cur)
			for mi in t.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).transparency = cur


## Postazione di un soldato attorno al cavallo (anello a 3,8 m).
func _ally_station(i: int) -> Vector2:
	var n := maxi(world.allies.size(), 1)
	var ang := PI * 0.15 + float(i) / n * PI * 1.7
	return Level2World.SITE + Vector2(cos(ang) * 3.8, sin(ang) * 4.6)


## I soldati che erano a Troia aiutano Epeo: durante i lavori vanno al cavallo e, a turno, si chinano a sollevare e
## montare le travi (animazione di soccorso). Ogni soldato al lavoro accelera la fase del 20%. Nell'incursione combattono.
func _update_allies(delta: float) -> void:
	if raid_active:
		_helpers_at_site = 0
		return
	var working := stage_active or (pile_beams > 0 and stage < BEAMS_PER_STAGE.size())
	while _ally_clock.size() < world.allies.size():
		_ally_clock.append(randf() * 2.0)
	_helpers_at_site = 0
	for i in world.allies.size():
		var ally := world.allies[i] as AllySoldier
		if ally == null or ally.health <= 0 or ally.busy:
			continue
		var station := _ally_station(i)
		var st_cell := world.cell_of(station)
		if working and ally.post_cell != st_cell:
			ally.post_cell = st_cell
			ally.sight_range = 8.0
		elif not working and ally.post_cell == st_cell:
			ally.post_cell = world.cell_of(Level2World.CAMP + Vector2(randf_range(-3, 3), randf_range(1, 4)))
		var close := _p2(ally).distance_to(station) < 1.8 and not ally.is_moving
		if working and close:
			_helpers_at_site += 1
			_ally_clock[i] -= delta
			if _ally_clock[i] <= 0.0 and stage_active:
				_ally_clock[i] = randf_range(3.2, 5.0)
				ally.call(&"start_help_up", world.horse.global_position, 1.6)


func _update_epeus(delta: float) -> void:
	_epeus_t += delta * 0.18
	var c := Level2World.SITE
	var p := c + Vector2(cos(_epeus_t) * 4.6, sin(_epeus_t) * 5.4)
	var q := c + Vector2(cos(_epeus_t + 0.05) * 4.6, sin(_epeus_t + 0.05) * 5.4)
	if world.epeus and phase == Phase.BUILD:
		world.epeus.position = Vector3(p.x, 0.0, p.y)
		var d := q - p
		world.epeus.rotation.y = atan2(-d.y, d.x) - PI * 0.5 + PI
		# i modelli Mixamo guardano +Z: la direzione di marcia e' (d.x, d.y) sul piano
		world.epeus.rotation.y = atan2(d.x, d.y)


func _refresh_objectives() -> void:
	var lines := ""
	if phase == Phase.BUILD:
		var standing := 0
		for tr in trees:
			if tr["state"] == T.STANDING:
				standing += 1
		var total := 0
		for b in BEAMS_PER_STAGE:
			total += b
		lines += "Timber: %d / %d beams delivered\n" % [beams_delivered, total]
		lines += "Firs left standing: %d\n" % standing
		if stage < STAGE_NAMES.size():
			lines += "Horse: %s (needs %d beams, %d at the site)\n" % [STAGE_NAMES[stage], BEAMS_PER_STAGE[stage], pile_beams]
		lines += "Soldiers helping Epeus: %d\n" % _helpers_at_site
		lines += "Carrying: %s" % ({"": "nothing", "trunk": "a log (with a comrade)", "beam": "a beam"}[carry])
	elif phase == Phase.FINALE:
		lines = "Gather your heroes in the horse.\nOdysseus goes in last."
	hud.set_objectives(lines)


# ------------------------------------------------------------------ pattuglie

func _spawn_patrols() -> void:
	var routes := [
		[Vector2(14, 10), Vector2(9, 16), Vector2(3, 15), Vector2(8, 8)],
		[Vector2(15, -14), Vector2(16, -4), Vector2(12, 3), Vector2(13, -9)],
	]
	for r in routes.size():
		var members: Array[TrojanSoldier] = []
		for k in 2:
			var t := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 45, "Pattuglia%d_%d" % [r, k]) as TrojanSoldier
			t.attack_damage = 7
			t.show_health_bar = true
			t.patrol_radius = 2
			t.position = world.world_of(routes[r][0] + Vector2(k * 1.2, 0))
			world.units_root.add_child(t)
			members.append(t)
		patrols.append({"members": members, "route": routes[r], "i": 0})


func _update_patrols(delta: float) -> void:
	_patrol_clock -= delta
	if _patrol_clock > 0.0:
		return
	_patrol_clock = 9.0
	for p in patrols:
		p["i"] = (p["i"] + 1) % p["route"].size()
		var target: Vector2 = p["route"][p["i"]]
		for m: TrojanSoldier in p["members"]:
			if is_instance_valid(m) and m.health > 0 and m.state == TrojanSoldier.State.GUARD:
				m.assign_post(world.cell_of(target + Vector2(randf_range(-1, 1), randf_range(-1, 1))))


# ------------------------------------------------------------------ incursione notturna

func _schedule_raid() -> void:
	raid_done = true
	await get_tree().create_timer(4.0).timeout
	if phase != Phase.BUILD:
		return
	_start_raid()


func _start_raid() -> void:
	raid_active = true
	raid_t = 0.0
	hud.show_banner("Night falls... Trojan raiders with torches are coming for the carpenters!", 4.5)
	hud.show_subtitle("Epeus", "Torches in the dark! Protect the men, Odysseus - but keep the flames away from the wood!", 4.5)
	create_tween().tween_method(world.set_night, 0.0, 1.0, 6.0)
	_snd("raiders", world.world_of(Vector2(17, 2)), 2.0)
	for c in world.carpenters:
		world.person_play(c, "Idle_12", 1.0)
	var origins := [Vector2(17, 2), Vector2(17.5, 5), Vector2(16.5, 8), Vector2(17, -1), Vector2(15.5, 11), Vector2(16.5, -4)]
	for i in origins.size():
		var t := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 40, "Incursore%d" % (i + 1)) as TrojanSoldier
		t.attack_damage = 6
		t.show_health_bar = true
		t.sight_range = 14.0
		# torcia al posto della lancia
		var model := t.get_node_or_null(^"Model")
		if model:
			for g in model.get_children():
				var gear := g as UnitGear
				if gear:
					gear.weapon_path = "res://assets/models/custom/campo/luci/torcia_achea/torcia_achea.gltf"
					gear.weapon_lod_path = "res://assets/models/custom/campo/luci/torcia_achea/torcia_achea_lod.gltf"
					gear.weapon_kind = UnitGear.WeaponKind.SWORD
		t.position = world.world_of(origins[i])
		world.units_root.add_child(t)
		t.died.connect(_on_raider_died)
		raiders.append(t)
		t.assign_post(world.cell_of(Level2World.SITE + Vector2(3.0 + (i % 3), -2.0 + i * 0.8)))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.28)
		light.light_energy = 1.0
		light.omni_range = 4.5
		light.position = Vector3(0.35, 1.5, 0.3)
		t.add_child(light)
		_flame_later(t)
		if i % 2 == 0:
			GameAudio.ambient_loop(t, "torches_loop", t.global_position + Vector3(0, 1.5, 0), -4.0, 14.0)
	for a in world.allies:
		var ally := a as AllySoldier
		if ally:
			ally.post_cell = world.cell_of(Level2World.SITE + Vector2(2.5 + randf() * 2.0, -2.0 + randf() * 4.0))
			ally.sight_range = 12.0
	for r in raiders:
		(r as TrojanSoldier).call_deferred(&"_alert", player, false)


func _flame_later(t: TrojanSoldier) -> void:
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(t):
		return
	var model := t.get_node_or_null(^"Model")
	if model == null:
		return
	for g in model.get_children():
		var gear := g as UnitGear
		if gear and gear.weapon_node:
			TorchFlame.attach(gear.weapon_node, Vector3(0, 0.38, 0), 0.5, 0.3, false)


func _on_raider_died() -> void:
	if _alive_raiders() == 0 and raid_active:
		_end_raid(true)


func _alive_raiders() -> int:
	var n := 0
	for r in raiders:
		if is_instance_valid(r) and r.health > 0:
			n += 1
	return n


func _update_raid(delta: float) -> void:
	if not raid_active:
		return
	raid_t += delta
	if raid_t >= RAID_MAX:
		_end_raid(false)


func _end_raid(won: bool) -> void:
	raid_active = false
	create_tween().tween_method(world.set_night, 1.0, 0.0, 6.0)
	if won:
		hud.show_banner("The raid is beaten back!", 3.0)
		hud.show_subtitle("Epeus", "Back to work, lads. The horse still needs us.", 4.0)
	else:
		hud.show_banner("The raiders flee into the forest.", 3.0)
		for r in raiders:
			if is_instance_valid(r) and r.health > 0:
				r.queue_free()
	if stage_active:
		_set_carpenters_working(true)
	for a in world.allies:
		var ally := a as AllySoldier
		if ally:
			ally.post_cell = Vector2i(-1, -1)
	_refresh_objectives()


# ------------------------------------------------------------------ finale

func _on_horse_finished() -> void:
	phase = Phase.FINALE
	_horse_ready = true
	_refresh_objectives()
	hud.show_banner("The horse is finished!", 3.0)
	hud.show_subtitle("Epeus", "The hatch is open. Heroes of Achaea - inside! Odysseus, you go last.", 5.0)
	var hatch_mark := OmniLight3D.new()
	hatch_mark.light_color = Color(1.0, 0.8, 0.5)
	hatch_mark.light_energy = 1.3
	hatch_mark.omni_range = 4.0
	hatch_mark.position = world.world_of(_hatch) + Vector3(0, 1.2, 0)
	world.add_child(hatch_mark)
	_send_crew_inside()


func _send_crew_inside() -> void:
	var crew: Array[Node3D] = []
	for a in world.allies:
		crew.append(a)
	crew.append(world.epeus)
	for c in world.carpenters:
		crew.append(c)
	var delay := 0.0
	for m in crew:
		_walk_into_horse(m, delay)
		delay += 1.6


func _walk_into_horse(m: Node3D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(m):
		return
	var unit := m as GridUnit
	if unit:
		unit.set_physics_process(false)
		unit.set_process(false)
		world.grid.release(unit.cell, unit)
		unit.is_moving = true
	else:
		world.person_play(m, "Walking")
	var target := world.world_of(_hatch)
	var d := Vector2(target.x - m.global_position.x, target.z - m.global_position.z)
	if unit:
		var model := unit.get_node_or_null(^"Model") as Node3D
		if model:
			model.rotation.y = atan2(-d.x, -d.y)
	else:
		m.rotation.y = atan2(d.x, d.y)
	var tw := create_tween()
	tw.tween_property(m, "global_position", target, maxf(d.length() / 2.2, 0.5))
	await tw.finished
	if is_instance_valid(m):
		m.visible = false
		_inside += 1
		hud.set_prompt("")


func _enter_horse() -> void:
	phase = Phase.ENDED   # sospende i comandi: da qui in poi e' una scena
	hud.set_prompt("")
	player.set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(player, "global_position", world.world_of(_hatch), 1.2)
	await tw.finished
	player.visible = false
	hud.show_banner("Odysseus is inside. The hatch closes.", 2.5)
	hud.show_subtitle("Odysseus", "Now the sea must keep our secret.", 3.0)
	await get_tree().create_timer(2.5).timeout
	await hud.fade_to(1.0, 1.2).finished
	await _fleet_sails()


## Le navi salpano verso nord restando sull'acqua del diorama: scivolano in mare (corsie a x -18,5 e -23), girano la prua
## a nord e navigano parallele alla costa fino a fermarsi prima del bordo, ondeggiando sulle onde.
func _fleet_sails() -> void:
	world.camera.follow_target = NodePath()
	world.camera._follow = null
	world.camera.follow_bounds = Rect2()
	world.camera.target = Vector3(-14.0, 0.0, -4.0)
	world.camera.distance = 46.0
	_snd("fleet_sails", Vector3(-17.0, 0.5, -10.0), 6.0)
	# nave -> [corsia x, z finale]; l'ordine delle navi in world.ships e' nord->sud per corsia: nessuna si incrocia
	var plan := [[-17.4, -22.0], [-17.4, -10.0], [-23.2, -10.0], [-23.2, -22.0]]
	for i in mini(world.ships.size(), plan.size()):
		_sail_ship(world.ships[i], plan[i][0], plan[i][1], float(i) * 0.6)
	await hud.fade_to(0.0, 1.5).finished
	hud.show_banner("The fleet sails north along the coast. Only the horse is left on the shore.", 6.0)
	await get_tree().create_timer(14.0).timeout
	await _trojans_find_horse()


func _sail_ship(ship: Node3D, lane_x: float, end_z: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(ship):
		return
	var base_y := ship.position.y
	var yaw0 := ship.rotation.y
	var start := ship.position
	# 1) si stacca dalla riva verso la corsia e gira la prua a nord (la prua col rostro del modello guarda -Z: yaw 0 = a nord)
	var slide := create_tween().set_parallel(true)
	slide.tween_property(ship, "position:x", lane_x, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slide.tween_property(ship, "rotation:y", 0.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await slide.finished
	if not is_instance_valid(ship):
		return
	# 2) naviga a nord a velocita' costante, con un'andatura che si fa piano all'arrivo
	var dist := absf(ship.position.z - end_z)
	var dur := maxf(dist / 2.4, 2.0)
	var go := create_tween()
	go.tween_property(ship, "position:z", end_z, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# ondeggia sul mare (beccheggio e rollio lievi), senza uscire dall'acqua
	var bob := create_tween().set_loops()
	var t0 := Time.get_ticks_msec()
	bob.tween_method(func(_v: float) -> void:
		if not is_instance_valid(ship):
			return
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		ship.position.y = base_y + sin(t * 1.3) * 0.05
		ship.rotation.x = sin(t * 1.1) * 0.015
		ship.rotation.z = sin(t * 0.9 + 1.0) * 0.02, 0.0, 1.0, 1.0)


func _trojans_find_horse() -> void:
	hud.show_banner("At dawn the Trojans leave the city...", 3.5)
	create_tween().tween_property(world.env, "fog_density", 0.0004, 3.0)
	world.camera.follow_bounds = Rect2()
	var crowd: Array[GridUnit] = []
	var start := Vector2(14.0, -20.0)
	for i in 8:
		var t := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 40, "Curioso%d" % i) as TrojanSoldier
		t.show_health_bar = false
		t.position = world.world_of(start + Vector2(i % 4 * 1.2, floorf(i / 4.0) * 1.3))
		world.units_root.add_child(t)
		t.halt()
		crowd.append(t)
	var around := []
	for i in crowd.size():
		var ang := float(i) / crowd.size() * TAU
		around.append(Level2World.SITE + Vector2(cos(ang) * 4.6, sin(ang) * 5.2))
	world.camera.target = world.horse.global_position
	for i in crowd.size():
		_march_to(crowd[i], world.world_of(around[i]), 11.0)
	world.camera.set(&"distance", 34.0)
	await get_tree().create_timer(6.0).timeout
	world.camera.follow_target = NodePath()
	world.camera._follow = null
	create_tween().tween_property(world.camera, "target", world.horse.global_position, 5.0)
	await get_tree().create_timer(5.5).timeout
	hud.show_subtitle("Trojan", "The Greeks are gone! Their camp is ashes... and they left a gift for Athena!", 4.5)
	await get_tree().create_timer(5.0).timeout
	_snd("trojan_cry", world.horse.global_position + Vector3(0, 1, 4), 2.0)
	hud.show_subtitle("Trojan", "Burn it? Throw it from the cliffs? No - drag it to the city! Troy will keep it!", 4.5)
	await get_tree().create_timer(4.5).timeout
	await _drag_horse(crowd)


func _march_to(unit: GridUnit, to: Vector3, seconds: float) -> void:
	var from := unit.global_position
	var model := unit.get_node_or_null(^"Model") as Node3D
	unit.is_moving = true
	if model:
		var d := to - from
		model.rotation.y = atan2(-d.x, -d.z)
	var tw := create_tween()
	tw.tween_property(unit, "global_position", to, seconds)
	await tw.finished
	if is_instance_valid(unit):
		unit.is_moving = false
		var h := Vector3(world.horse.global_position.x - unit.global_position.x, 0, world.horse.global_position.z - unit.global_position.z)
		if model:
			model.rotation.y = atan2(-h.x, -h.z)


## I troiani trascinano il cavallo lungo il sentiero fino alle mura lontane (la sezione del livello 1, vista da fuori).
func _drag_horse(crowd: Array[GridUnit]) -> void:
	hud.show_banner("The Trojans drag the horse toward the walls of Troy...", 4.0)
	world.open_boundary_fog(3.0)
	world.camera.follow_bounds = Rect2()
	world.camera._follow = world.horse
	var path: Array = Level2World.TRACK
	var lengths := []
	var total := 0.0
	for k in range(1, path.size()):
		total += (path[k] as Vector2).distance_to(path[k - 1])
		lengths.append(total)
	var speed := 2.6
	var dur := total / speed
	var horse := world.horse
	var base_y := horse.position.y
	for u in crowd:
		u.is_moving = true
	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(world.camera, "distance", 62.0, dur * 0.8).set_delay(dur * 0.1)
	zoom.tween_property(world.camera, "pitch_degrees", -26.0, dur * 0.8).set_delay(dur * 0.1)
	var elapsed := 0.0
	var drag_sfx := 0.0
	while elapsed < dur:
		var dt := get_process_delta_time()
		elapsed += dt
		drag_sfx -= dt
		if drag_sfx <= 0.0:
			drag_sfx = 4.5
			_snd("rope_drag", horse.global_position, 4.0)
		var d := minf(elapsed * speed, total)
		var pos := _track_point(path, lengths, d)
		var ahead := _track_point(path, lengths, minf(d + 0.8, total))
		var dir := (ahead - pos).normalized()
		horse.position = Vector3(pos.x, base_y + absf(sin(elapsed * 3.0)) * 0.06, pos.y)
		horse.rotation.y = lerp_angle(horse.rotation.y, atan2(-dir.x, -dir.y), 0.05)
		horse.rotation.z = sin(elapsed * 2.6) * 0.02
		for i in crowd.size():
			var side := 1.0 if i % 2 == 0 else -1.0
			var row := floorf(i / 2.0)
			var pd := minf(d + 3.5 + row * 1.6, total)
			var pp := _track_point(path, lengths, pd)
			var pn := _track_point(path, lengths, minf(pd + 0.5, total))
			var fwd := (pn - pp).normalized()
			var perp := Vector2(-fwd.y, fwd.x)
			var target := pp + perp * side * 1.4
			var u := crowd[i]
			u.global_position = Vector3(target.x, 0.0, target.y)
			var model := u.get_node_or_null(^"Model") as Node3D
			if model:
				model.rotation.y = lerp_angle(model.rotation.y, atan2(-fwd.x, -fwd.y), 0.2)
		await get_tree().process_frame
	for u in crowd:
		u.is_moving = false
	hud.show_banner("The gates of Troy open...", 3.0)
	await get_tree().create_timer(3.5).timeout
	await hud.fade_to(1.0, 1.5).finished
	phase = Phase.ENDED
	hud.fade_to(0.0, 0.8)
	hud.show_end("Level 2 complete", "The gift of the sea is inside the walls. Troy celebrates... and the Achaeans in the belly of the horse wait for the night.\n\nLevel 3 is still being written.")
	level_finished.emit()


static func _track_point(path: Array, lengths: Array, d: float) -> Vector2:
	var prev := 0.0
	for k in range(1, path.size()):
		var seg_end: float = lengths[k - 1]
		if d <= seg_end:
			var t := (d - prev) / maxf(seg_end - prev, 0.001)
			return (path[k - 1] as Vector2).lerp(path[k], t)
		prev = seg_end
	return path[path.size() - 1]


# ------------------------------------------------------------------ comandi per i test

## Salta ai passaggi principali (usato dai test): consegna `n` travi al cantiere.
func debug_give_beams(n: int) -> void:
	pile_beams += n
	beams_delivered += n
	_update_pile()
	_refresh_objectives()
