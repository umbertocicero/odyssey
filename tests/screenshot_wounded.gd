extends SceneTree
## Screenshot ravvicinati dei feriti con le bende (serve una finestra). Avvio:
## ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_wounded.gd -- --out=feriti_bende

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "feriti_bende"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var director := main.get_node("Director") as LevelDirector
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var i := 0
	for w in director.wounded:
		if i >= 3:
			break
		cam.fov = 30.0
		cam.global_position = w.global_position + Vector3(0.0, 4.2, 3.4)
		cam.look_at(w.global_position + Vector3(0, 0.2, 0), Vector3.UP)
		for f in 40:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/ferito_%d.png" % [dir, i]))
		print("salvata ferito ", i, " ", w.name, " ", w.global_position)
		i += 1
	var names := []
	for w in director.wounded:
		names.append("%s (%.1f, %.1f)" % [w.name, w.global_position.x, w.global_position.z])
	print("FERITI ", names)
	quit()
