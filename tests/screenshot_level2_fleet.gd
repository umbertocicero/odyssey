extends SceneTree
## Cascata del mare sul bordo e partenza della flotta del livello 2 (serve una finestra).
func _initialize() -> void:
	_run.call_deferred()
func _shot(n: String, frames := 30) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/level2_%s.png" % n))
	print("salvata ", n)
func _run() -> void:
	var main: Node = load("res://scenes/main/main_level2.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var world: Level2World = get_first_node_in_group(&"level2_world")
	var d: Level2Director = main.get_node("Director")
	var cam: FixedCamera = world.camera
	cam._follow = null
	cam.follow_bounds = Rect2()
	cam.target = Vector3(-22, 0, 4)
	cam.distance = 26.0
	await _shot("bordo_mare")
	cam.yaw_degrees = -100.0
	cam.pitch_degrees = -14.0
	cam.target = Vector3(-26, -3, 0)
	cam.distance = 24.0
	await _shot("cascata_ovest")
	cam.yaw_degrees = 30.0
	cam.pitch_degrees = -38.0
	cam.target = Vector3(-14, 0, -4)
	cam.distance = 46.0
	d._sail_ship(world.ships[0], -18.5, -22.0, 0.0)
	d._sail_ship(world.ships[1], -18.5, -10.0, 0.0)
	d._sail_ship(world.ships[2], -23.0, -10.0, 0.0)
	d._sail_ship(world.ships[3], -23.0, -22.0, 0.0)
	await _shot("flotta_1", 200)
	cam.yaw_degrees = 0.1
	cam.pitch_degrees = -80.0
	cam.target = Vector3(-20, 0, -14)
	cam.distance = 40.0
	await _shot("flotta_2", 700)
	quit()
