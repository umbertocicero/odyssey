extends SceneTree
## Screenshot dell'accampamento (serve una finestra, non headless).
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_camp.gd -- --out=camp_after
## Salva in tests/screenshots/<out>/: camera di gioco e camera bassa obliqua dall'interno del campo verso il mare.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "camp_after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var ulisse = get_first_node_in_group(&"player")
	ulisse.place_at(Vector2i(6, 31))
	for i in 90:
		await process_frame
	_save(dir + "/camp_gioco.png")
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var views := {
		"camp_obliqua_mare": [Vector3(-3.5, 1.7, 13.0), Vector3(-20.0, 1.6, 9.5), 55.0],
		"camp_costa": [Vector3(-3.0, 4.2, 11.6), Vector3(-21.0, 0.3, 11.6), 48.0],
		"camp_comandanti": [Vector3(-12.6, 1.7, 3.6), Vector3(-13.0, 1.2, 7.4), 44.0],
		"camp_obliqua_nord": [Vector3(-10.0, 1.8, 18.5), Vector3(-14.0, 1.2, 8.0), 50.0],
	}
	for v: String in views:
		cam.fov = views[v][2]
		cam.global_transform = Transform3D(Basis(), views[v][0]).looking_at(views[v][1], Vector3.UP)
		cam.global_position = views[v][0]
		cam.look_at(views[v][1], Vector3.UP)
		for i in 60:
			await process_frame
		_save(dir + "/%s.png" % v)
	quit()


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("salvata ", path)
