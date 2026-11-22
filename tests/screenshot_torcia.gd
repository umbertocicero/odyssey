extends SceneTree
## Screenshot notturno con la torcia in mano a Ulisse (serve una finestra). Avvio: godot --path . -s res://tests/screenshot_torcia.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var clock := get_first_node_in_group(&"level_clock") as LevelClock
	clock.running = false
	clock.rain_chance = 0.0
	clock.time_of_day = 22.0
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var camera := viewport.get_camera_3d()
	var player := get_first_node_in_group(&"player") as Node3D
	for i in 120:
		await process_frame
	camera.set(&"_follow", null)
	camera.set(&"target", player.global_position)
	camera.set(&"distance", 5.0)
	for i in 90:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/torcia_notte.png"))
	quit(0)
