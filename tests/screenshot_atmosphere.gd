extends SceneTree
## Screenshot dell'atmosfera a ore diverse e sotto la pioggia (serve una finestra).
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_atmosphere.gd -- --out=atmosfera_2

func _initialize() -> void:
	_run.call_deferred()


func _shot(dir: String, shot_name: String) -> void:
	for i in 50:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, shot_name]))
	print("salvata ", shot_name)


func _run() -> void:
	var out := "atmosfera_2"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var tag: String = ["low", "medium", "high"][Quality.current()]
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var clock := get_first_node_in_group(&"level_clock") as LevelClock
	clock.running = false
	clock.rain_chance = 0.0
	var ulisse := get_first_node_in_group(&"player") as Node3D
	ulisse.set_physics_process(false)
	for hour in [17.5, 19.5, 20.5, 22.5]:
		clock.time_of_day = hour
		await _shot(dir, "ora_%s_%s" % [str(hour).replace(".", "_"), tag])
	# Pioggia di giorno e poi dopo la pioggia (pozze che si asciugano).
	clock.time_of_day = 18.0
	clock.start_rain(200.0)
	for i in 600:
		clock.advance(0.05)
	await _shot(dir, "pioggia_%s" % tag)
	clock._raining = false
	for i in 120:
		clock.advance(0.05)
	await _shot(dir, "pozze_dopo_%s" % tag)
	quit()
