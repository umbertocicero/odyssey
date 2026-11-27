extends SceneTree
## Schermate del livello 2 (serve una finestra). Avvio: godot --path . -s res://tests/screenshot_level2.gd
## Le immagini finiscono in tests/screenshots/ (ignorata da git).

func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 40:
		await process_frame
	var image := root.get_texture().get_image()
	var path := "res://tests/screenshots/level2_%s.png" % name
	image.save_png(ProjectSettings.globalize_path(path))
	print("salvata ", path)


func _run() -> void:
	var main: Node = load("res://scenes/main/main_level2.tscn").instantiate()
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	for i in 60:
		await process_frame
	var world: Level2World = get_first_node_in_group(&"level2_world")
	var player: GridUnit = get_first_node_in_group(&"player")
	await _shot("start")
	var cam: FixedCamera = world.camera
	for spec in [["cantiere", Vector2(-8, 11)], ["foresta", Vector2(4, -6)], ["cascata", Vector2(12, -15)]]:
		player.global_position = Vector3(spec[1].x, 0, spec[1].y)
		cam.target = player.global_position
		await _shot(spec[0])
	player.global_position = Vector3(-12, 0, 7)
	cam.target = Vector3(-14.5, 0, 7)
	cam.distance = 16.0
	await _shot("foce")
	cam.distance = 60.0
	cam.target = Vector3(0, 0, 0)
	await _shot("ampia")
	cam.distance = 31.0
	world.set_horse_progress(1.0)
	player.global_position = Vector3(-8, 0, 11)
	cam.target = world.horse.global_position
	await _shot("cavallo")
	cam.distance = 12.0
	await _shot("cavallo_vicino")
	quit()
