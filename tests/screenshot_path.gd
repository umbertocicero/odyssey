extends SceneTree
## Screenshot del sentiero verso Troia (serve una finestra, non headless).
## Avvio: ODYSSEY_QUALITY=medium godot --path . -s res://tests/screenshot_path.gd -- --out=sentiero_after
## Salva in tests/screenshots/<out>/ (nome con la qualità): camera di gioco e camera bassa lungo la strada verso Troia.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "sentiero_after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var tag: String = ["low", "medium", "high"][Quality.current()]
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var ulisse = get_first_node_in_group(&"player")
	ulisse.place_at(Vector2i(33, 22))
	for i in 90:
		await process_frame
	_save("%s/sentiero_gioco_%s.png" % [dir, tag])
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var views := {
		"strada_verso_troia": [Vector3(6.6, 1.5, 10.5), Vector3(6.5, 3.2, -22.0), 48.0],
		"strada_curva": [Vector3(-4.0, 1.6, 12.4), Vector3(8.0, 1.8, -4.0), 55.0],
		"porta_da_vicino": [Vector3(6.6, 2.0, -18.6), Vector3(7.0, 3.8, -21.6), 62.0],
	}
	for v: String in views:
		cam.fov = views[v][2]
		cam.global_position = views[v][0]
		cam.look_at(views[v][1], Vector3.UP)
		for i in 60:
			await process_frame
		_save("%s/%s_%s.png" % [dir, v, tag])
	quit()


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/" + path.trim_prefix("res://tests/screenshots/")))
	print("salvata ", path)
