extends SceneTree
## Screenshot dei rematori sulla barca (serve una finestra, non headless).
## Avvio: godot --path . -s res://tests/screenshot_rowing.gd -- tag
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var tag := "dopo"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	Quality.set_level(Quality.Level.HIGH)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var ferry := get_first_node_in_group(&"ferry_system") as FerrySystem
	var boat: FerrySystem.Boat = ferry.boats[0]
	ferry._board_crew(boat)
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var camera := viewport.get_camera_3d()
	camera.set(&"_follow", null)
	camera.set(&"target", boat.node.global_position + Vector3(0, 0.8, 0))
	camera.set(&"distance", 5.0)
	for k in 4:
		for i in 14:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/rowing_%s_%d.png" % [tag, k]))
	quit(0)
