extends SceneTree
## Gioca il livello 2 da cima a fondo con comandi simulati (tronchi, ruscello, banco, cantiere, incursione, finale).
## Avvio: godot --path . -s res://tests/test_level2_flow.gd   (serve la finestra per il cavallo; va anche in --headless)

var d: Level2Director
var world: Level2World
var player: GridUnit


func _initialize() -> void:
	_run.call_deferred()


func _wait_until(cond: Callable, timeout_s: float, what: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale < timeout_s:
		if cond.call():
			return true
		await process_frame
	print("TIMEOUT: ", what)
	return false


func _act(expect_kind: String) -> void:
	var t0 := Time.get_ticks_msec()
	while expect_kind in ["lift", "haul"] and d._action().get("kind", "") != expect_kind and (Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale < 25.0:
		await process_frame
	var a := d._action()
	print("  azione: ", a, " (attesa ", expect_kind, ")")
	d._interact()


func _run() -> void:
	var main: Node = load("res://scenes/main/main_level2.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	world = get_first_node_in_group(&"level2_world")
	player = get_first_node_in_group(&"player")
	d = main.get_node("Director")
	Engine.time_scale = 5.0
	var ok := true
	for i in 10:
		if d.beams_delivered >= 8:
			break
		if d.raid_active:
			await _wait_until(func() -> bool: return not d.raid_active, 90.0, "raid end")
		player.heal_full()
		var spot: Vector2 = Level2World.TREE_SPOTS[i]
		player.global_position = Vector3(spot.x + 1.2, 0, spot.y + 0.6)
		await process_frame
		await _act("fell")
		ok = await _wait_until(func() -> bool: return d.trees[i]["state"] == Level2Director.T.FALLEN, 8.0, "fell %d" % i) and ok
		await _act("trim")
		ok = await _wait_until(func() -> bool: return d.trees[i]["state"] == Level2Director.T.TRIMMED, 8.0, "trim %d" % i) and ok
		world.allies[0].global_position = player.global_position + Vector3(1.0, 0, 0.5)
		await process_frame
		await _act("lift")
		var near_stream := world.stream_point(world.stream_len * 0.4)
		player.global_position = Vector3(near_stream.x, 0, near_stream.y + 1.5)
		await process_frame
		await _act("float")
		ok = await _wait_until(func() -> bool: return d.trees[i]["state"] == Level2Director.T.LANDED, 40.0, "landed %d" % i) and ok
		var lp: Vector2 = d._p2(d.trees[i]["trunk"])
		player.global_position = Vector3(lp.x, 0, lp.y + 1.0)
		await process_frame
		world.allies[0].global_position = player.global_position + Vector3(1.0, 0, 0.5)
		await process_frame
		await _act("haul")
		player.global_position = Vector3(Level2World.BENCH.x, 0, Level2World.BENCH.y + 1.2)
		await process_frame
		await _act("square")
		ok = await _wait_until(func() -> bool: return d.carry == "beam", 8.0, "square %d" % i) and ok
		player.global_position = Vector3(Level2World.PILE.x, 0, Level2World.PILE.y + 1.5)
		await process_frame
		await _act("deliver")
		print("albero ", i, " consegnato; travi=", d.beams_delivered, " fase=", d.stage, " raid=", d.raid_active)
	ok = await _wait_until(func() -> bool: return d.phase == Level2Director.Phase.FINALE, 120.0, "horse finished") and ok
	print("cavallo finito, fase=", d.phase, " dentro=", d._inside)
	ok = await _wait_until(func() -> bool: return d._inside >= world.allies.size() + 4, 60.0, "crew inside") and ok
	player.global_position = Vector3(Level2World.SITE.x, 0, Level2World.SITE.y + 3.0)
	await process_frame
	_act("enter")
	ok = await _wait_until(func() -> bool: return d.phase == Level2Director.Phase.ENDED and d.hud._end.visible, 200.0, "end panel") and ok
	print("TEST ", "OK" if ok else "FALLITO")
	quit(0 if ok else 1)
