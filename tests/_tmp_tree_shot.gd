extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var out := "x"
	var nm := "Cipresso3"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--node="): nm = arg.substr(7)
	var tr: Node3D = main.find_child(nm, true, false)
	print(nm, " ", tr.global_position)
	var vp: SubViewport = main.get_node("GameView/GameViewport")
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = 40
	cam.global_position = tr.global_position + Vector3(4, 5, 8)
	cam.look_at(tr.global_position + Vector3(0, 2, 0))
	cam.current = true
	for i in 90:
		await process_frame
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/%s.png" % out))
	quit()
