extends SceneTree
## Screenshot di catapulta, balista, carro e barella nel livello 1 (serve una finestra).
## ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_macchine.gd -- --out=macchine

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "macchine"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var st := Stretcher.new()
	main.add_child(st)
	st.global_position = Vector3(0, 0, 6)
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var views := {
		"catapulta": [Vector3(-11.5, 8.5, -16.0), Vector3(-11.5, 5.0, -26.0), 40.0],
		"catapulta2": [Vector3(-6.0, 7.5, -19.0), Vector3(-11.5, 5.0, -26.0), 35.0],
		"balista": [Vector3(-20.0, 8.0, -14.0), Vector3(-20.0, 5.2, -21.95), 35.0],
		"carro": [Vector3(6.0, 2.2, -0.5), Vector3(9.4, 0.8, -3.0), 50.0],
		"barella": [Vector3(1.8, 2.2, 8.0), Vector3(0, 0.5, 6.0), 45.0],
		"barella_lato": [Vector3(3.0, 1.0, 6.0), Vector3(0, 0.5, 6.0), 45.0],
	}
	for v: String in views:
		cam.fov = views[v][2]
		cam.global_position = views[v][0]
		cam.look_at(views[v][1], Vector3.UP)
		for i in 45:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(dir + "/%s.png" % v))
	quit()
