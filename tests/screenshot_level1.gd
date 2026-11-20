extends SceneTree
## Salva alcune schermate del livello 1 (serve una finestra, non headless).
## Avvio: godot --path . -s res://tests/screenshot_level1.gd
## Le immagini finiscono in tests/screenshots/ (ignorata da git).

const SHOTS := {
	"accampamento": Vector2i(6, 31),
	"pianura": Vector2i(24, 20),
	"mura": Vector2i(26, 7),
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	for i in 30:
		await process_frame
	var ulisse = get_first_node_in_group(&"player")
	var camera := root.get_viewport().get_camera_3d()
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	camera = viewport.get_camera_3d()
	for shot_name: String in SHOTS:
		ulisse.place_at(SHOTS[shot_name])
		for i in 90:
			await process_frame
		var image := root.get_texture().get_image()
		var path := "res://tests/screenshots/level1_%s.png" % shot_name
		image.save_png(ProjectSettings.globalize_path(path))
		print("salvata ", path, " camera=", camera.global_position if camera else "nessuna")
	# Vista d'insieme del diorama: camera più lontana, centrata sulla base.
	if camera:
		camera.set(&"_follow", null)
		camera.set(&"target", Vector3(0, 0, -4))
		camera.set(&"distance", 85.0)
		for i in 30:
			await process_frame
		var overview := root.get_texture().get_image()
		overview.save_png(ProjectSettings.globalize_path("res://tests/screenshots/level1_panoramica.png"))
		print("salvata res://tests/screenshots/level1_panoramica.png")
	quit(0)
