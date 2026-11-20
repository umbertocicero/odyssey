extends SceneTree
## Screenshot ravvicinati di Ulisse e di un soldato acheo (serve una finestra, non headless).
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_achei.gd -- --out=achei2_after

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "achei2_after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var ulisse := get_first_node_in_group(&"player") as Node3D
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var allies := get_nodes_in_group(&"units").filter(func(n: Node) -> bool: return n != ulisse and n.get("team") == 0)
	var targets := {"ulisse": ulisse}
	if not allies.is_empty():
		targets["soldato_acheo"] = allies[0]
	for key: String in targets:
		var t: Node3D = targets[key]
		cam.fov = 38.0
		cam.global_position = t.global_position + Vector3(-1.1, 1.35, -2.0)
		cam.look_at(t.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		for i in 60:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, key]))
		print("salvata ", key, " ", t.name)
	quit()
