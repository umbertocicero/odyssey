extends SceneTree
## Screenshot degli animali del livello 1 (serve una finestra, non headless).
## ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_animali.gd -- --out=animali
## Viste libere (camera di gioco spenta): tiro del carro, gregge e maiali, cavalli del campo, cavalli della strada.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "animali"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	cam.top_level = true
	var ulisse = get_first_node_in_group(&"player")
	ulisse.place_at(Vector2i(6, 31))
	var views := {
		"testa_cavallo": [Vector3(-5.6, 1.9, 7.6), Vector3(-8.2, 1.7, 6.2), 30.0],
		"carro_tiro": [Vector3(8.0, 2.2, -4.5), Vector3(15.0, 0.9, 1.0), 50.0],
		"gregge": [Vector3(8.0, 1.8, 9.0), Vector3(12.5, 0.5, 4.5), 50.0],
		"maiali": [Vector3(15.0, 1.8, 9.5), Vector3(19.0, 0.4, 5.5), 50.0],
		"campo_cavalli": [Vector3(-2.5, 2.0, 10.0), Vector3(-8.5, 1.0, 6.5), 50.0],
		"campo_cavalli2": [Vector3(-4.0, 2.2, 21.0), Vector3(-9.2, 1.0, 17.0), 50.0],
		"strada": [Vector3(5.0, 1.8, -9.0), Vector3(9.4, 1.0, -5.9), 50.0],
		"battaglia": [Vector3(-5.0, 2.0, -9.0), Vector3(-10.0, 1.0, -14.5), 55.0],
	}
	for v: String in views:
		cam.fov = views[v][2]
		cam.global_position = views[v][0]
		cam.look_at(views[v][1], Vector3.UP)
		for i in 45:
			await process_frame
		_save(dir + "/%s.png" % v)
	quit()


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("salvata ", path)
