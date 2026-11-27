extends SceneTree
## Schermate degli eventi del livello 2: carpentieri al lavoro, incursione notturna, finale. Serve una finestra.

func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String, frames := 30) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/level2_%s.png" % name))
	print("salvata ", name)


func _wait_until(cond: Callable, seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds and not cond.call():
		await process_frame


func _run() -> void:
	var main: Node = load("res://scenes/main/main_level2.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var world: Level2World = get_first_node_in_group(&"level2_world")
	var player: GridUnit = get_first_node_in_group(&"player")
	var d: Level2Director = main.get_node("Director")
	player.global_position = Vector3(-9, 0, 9)
	world.camera.target = player.global_position
	d.debug_give_beams(1)
	await _shot("lavoro", 150)
	d._start_raid()
	await _wait_until(func() -> bool: return d.raid_t > 9.0, 20.0)
	player.global_position = Vector3(-5, 0, 10)
	await _shot("raid", 30)
	await _wait_until(func() -> bool: return d.raid_t > 14.0, 20.0)
	await _shot("raid2", 10)
	quit()
