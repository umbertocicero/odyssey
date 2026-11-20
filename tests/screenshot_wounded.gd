extends SceneTree
## Schermate dei feriti: a terra, trascinato, sulla barca. Serve una finestra.
## Avvio: godot --path . -s res://tests/screenshot_wounded.gd

func _initialize() -> void:
	_run.call_deferred()

var camera: Node

func _look(pos: Vector3, dist: float) -> void:
	if camera:
		camera.set(&"follow_target", NodePath())
		camera.set(&"_follow", null)
		camera.set(&"target", pos)
		camera.set(&"distance", dist)

func _shot(n: String) -> void:
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/wounded_%s.png" % n))
	print("salvata ", n)

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	rules.ferry_sail_time = 8.0
	director.rules = rules
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	for i in 60:
		await process_frame
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	camera = viewport.get_camera_3d()
	if camera:
		camera.set(&"distance", 5.0)
	var w: WoundedSoldier = director.wounded[0]
	print("ferito in ", w.cell, " ", w.global_position)
	for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2)]:
		if ulisse.place_at(w.cell + d):
			break
	_look(w.global_position, 4.5)
	await _shot("a_terra")
	ulisse.place_at(w.cell + Vector2i(1, 1))
	await create_timer(0.3).timeout
	var dir := Vector2i(0, 1)
	for i in 6:
		ulisse.place_at(ulisse.cell + dir)
		await create_timer(0.35).timeout
	_look((ulisse.global_position + w.global_position) * 0.5, 4.5)
	await _shot("trascinato")
	var cc := rules.camp_rect.position + Vector2i(2, 2)
	ulisse.place_at(cc)
	w.place_at(cc + Vector2i(1, 0))
	var t := 0.0
	while t < 40.0 and w.state != WoundedSoldier.State.CARRIED:
		await create_timer(0.5).timeout
		t += 0.5
	_look(w.global_position, 4.5)
	await _shot("alleato")
	while t < 80.0 and w.state != WoundedSoldier.State.EVACUATED:
		await create_timer(0.5).timeout
		t += 0.5
	await create_timer(2.5).timeout
	for b in director.ferry.boats:
		print("barca ", b.node.global_position, " busy=", b.busy, " ", b.node.get_child(0).scale if b.node.get_child_count() > 0 else "-")
	_look(director.ferry.boats[1].node.global_position, 6.0)
	await create_timer(0.3).timeout
	await _shot("barca")
	quit()
