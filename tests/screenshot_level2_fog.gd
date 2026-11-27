extends SceneTree
## Nebbia di confine del livello 2 (bordo nord, lato Troia): vista normale e vista con il corridoio aperto (finale).
func _initialize() -> void:
	_run.call_deferred()
func _shot(n: String, frames := 40) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/level2_%s.png" % n))
	print("salvata ", n)
func _run() -> void:
	var main: Node = load("res://scenes/main/main_level2.tscn").instantiate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			var holder := main.get_node("GameView/GameViewport")
			var old := holder.get_node("Level2")
			holder.remove_child(old)
			old.free()
			var lvl: Node = (load(a.substr(8)) as PackedScene).instantiate()
			lvl.name = "Level2"
			holder.add_child(lvl)
	root.add_child(main)
	for i in 40:
		await process_frame
	var w: Level2World = get_first_node_in_group(&"level2_world")
	var cam: FixedCamera = w.camera
	if OS.get_environment("NO_VELO") == "1":
		for i in 3:
			w.get_node("NebbiaConfine/Velo%d" % (i + 1)).visible = false
	cam._follow = null
	cam.follow_bounds = Rect2()
	cam.target = Vector3(14, 0, -22)
	cam.distance = 22.0
	cam.yaw_degrees = 0.1
	cam.pitch_degrees = -60.0
	await _shot("nebbia_nord")
	cam.target = Vector3(0, 0, -20)
	cam.distance = 60.0
	cam.pitch_degrees = -75.0
	await _shot("nebbia_alto")
	cam.target = Vector3(0, 0, -16)
	cam.distance = 40.0
	cam.yaw_degrees = -35.0
	cam.pitch_degrees = -22.0
	await _shot("nebbia_laterale")
	cam.target = Vector3(0, 0, 0)
	cam.distance = 31.0
	cam.yaw_degrees = 30.0
	cam.pitch_degrees = -38.0
	cam.distance = 31.0
	cam.target = Vector3(10, 0, -10)
	await _shot("nebbia_gioco")
	w.open_boundary_fog(0.5)
	cam.target = Vector3(18, 0, -46)
	cam.distance = 62.0
	cam.pitch_degrees = -26.0
	await _shot("nebbia_aperta", 90)
	quit()
