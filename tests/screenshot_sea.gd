extends SceneTree
## Screenshot del mare (serve una finestra, non headless).
## Avvio: godot --path . -s res://tests/screenshot_sea.gd -- prima   (o: dopo)
## Salva tests/screenshots/mare_<tag>_{riva,largo}.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tag := "dopo"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var camera := viewport.get_camera_3d()
	camera.set(&"_follow", null)
	var views := {
		"riva": [Vector3(-22.5, 0, 6), 14.0],
		"largo": [Vector3(-23, 0, -4), 30.0],
	}
	for v: String in views:
		camera.set(&"target", views[v][0])
		camera.set(&"distance", views[v][1])
		for i in 90:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tests/screenshots/mare_%s_%s.png" % [tag, v]))
	quit(0)
