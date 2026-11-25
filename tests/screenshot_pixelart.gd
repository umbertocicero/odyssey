extends SceneTree
## Screenshot del livello 1 con/senza pixel art (modi 0, 1, 2) + FPS (serve una finestra).
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_pixelart.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var dir := ProjectSettings.globalize_path("res://tests/screenshots/pixelart")
	DirAccess.make_dir_recursive_absolute(dir)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var ui := main.get_node_or_null(^"UI") as CanvasLayer
	if ui:
		ui.visible = false   # niente HUD né schermata di fine livello: si confronta solo il 3D
	var clock := get_first_node_in_group(&"level_clock") as LevelClock
	clock.running = false
	clock.rain_chance = 0.0
	(get_first_node_in_group(&"player") as Node3D).set_physics_process(false)
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	# nome, ora, posizione camera, bersaglio, fov
	var shots := [
		["accampamento", 17.5, Vector3(-3.0, 4.2, 11.6), Vector3(-21.0, 0.3, 11.6), 48.0],
		["pianura", 17.5, Vector3(0.0, 6.0, 5.0), Vector3(0.0, 0.0, -8.0), 50.0],
		["mura", 17.5, Vector3(7.0, 3.0, -8.0), Vector3(7.0, 3.0, -21.0), 45.0],
		["tramonto", 19.5, Vector3(-3.0, 4.2, 11.6), Vector3(-21.0, 0.3, 11.6), 48.0],
		["notte", 22.5, Vector3(-3.0, 4.2, 11.6), Vector3(-21.0, 0.3, 11.6), 48.0],
	]
	for s in shots:
		clock.time_of_day = s[1]
		# colonne: originale, opzione 1 attuale, varianti 1-3 del modo 1
		for col in 3:
			main.pixelart_mode = [0, 1, 3][col]
			main.pixelart_variant = 1
			var mode := col
			for i in 40:
				cam.fov = s[4]
				cam.global_position = s[2]
				cam.look_at(s[3], Vector3.UP)
				await process_frame
			if s[0] == "accampamento":
				var t0 := Time.get_ticks_msec()
				for i in 200:
					cam.global_position = s[2]
					cam.look_at(s[3], Vector3.UP)
					await process_frame
				print("FPS colonna %d: %.1f" % [mode, 200000.0 / (Time.get_ticks_msec() - t0)])
			root.get_texture().get_image().save_png("%s/%s_var%d.png" % [dir, s[0], mode])
	quit()
