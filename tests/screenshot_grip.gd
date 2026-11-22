extends SceneTree
## Impugnatura delle armi: Ulisse da vicino a riposo e durante l'attacco, un acheo, un troiano con lancia e un arciere con arco.
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_grip.gd -- --out=impugnatura

func _initialize() -> void:
	_run.call_deferred()


func _shot(dir: String, n: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, n]))
	print("salvata ", n)


func _look(cam: Camera3D, target: Node3D, offset: Vector3, up: float) -> void:
	cam.global_position = target.global_position + offset
	cam.look_at(target.global_position + Vector3(0, up, 0), Vector3.UP)


func _run() -> void:
	var out := "impugnatura"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 50:
		await process_frame
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var hud := main.get_node_or_null("UI/LevelHud") as Control
	if hud:
		hud.visible = false
	cam.fov = 26.0
	_look(cam, ulisse, Vector3(1.4, 1.1, -1.6), 0.8)
	for i in 30:
		await process_frame
	_shot(dir, "ulisse_riposo")
	ulisse.action_requested.emit(&"attack")
	for i in 14:
		await process_frame
	_shot(dir, "ulisse_attacco")
	var troiani := get_nodes_in_group(&"troiani")
	if not troiani.is_empty():
		_look(cam, troiani[0], Vector3(1.6, 1.2, 1.6), 0.9)
		for i in 20:
			await process_frame
		_shot(dir, "troiano_lancia")
	var archer := main.find_child("Arciere1", true, false) as Node3D
	if archer:
		_look(cam, archer, Vector3(0.6, 1.4, 2.4), 0.5)
		for i in 20:
			await process_frame
		_shot(dir, "arciere_arco")
	quit()
