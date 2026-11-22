extends SceneTree
## Screenshot ravvicinati di fanteria e capitano troiano (serve una finestra, non headless).
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_troiani_nuovi.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := "res://tests/screenshots/troiani_nuovi"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var cap := main.find_child("CapitanoTroiano", true, false) as Node3D
	var fan := main.find_child("SoldatoTroiano4", true, false) as Node3D
	print("capitano: ", cap != null, " fanteria: ", fan != null)
	var targets := {"capitano": cap, "fanteria": fan}
	for t: String in targets:
		var n: Node3D = targets[t]
		if n == null:
			continue
		cam.fov = 30.0
		cam.global_position = n.global_position + Vector3(2.2, 1.5, 3.0)
		cam.look_at(n.global_position + Vector3(0, 0.85, 0), Vector3.UP)
		for i in 40:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, t]))
		print("salvata ", t)
	quit()
