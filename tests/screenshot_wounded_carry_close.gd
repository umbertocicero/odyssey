extends SceneTree
## Primo piano di Ulisse che porta il ferito, da solo e poi con un compagno affiancato (serve una finestra).
## Avvio: godot --path . -s res://tests/screenshot_wounded_carry_close.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	rules.duration = 300.0
	director.rules = rules
	root.add_child(main)
	for i in 60:
		await process_frame
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var w: WoundedSoldier = director.wounded[0]
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	for n in root.find_children("*", "", true, false):
		if n is GrassField or n is GrassCards:
			n.visible = false
	var allies: Array[AllySoldier] = []
	for a in get_nodes_in_group(&"achei"):
		if a is AllySoldier:
			allies.append(a)
	for i in range(1, allies.size()):
		allies[i].busy = true
	var mate := allies[0]
	var spot := grid.world_to_cell(Vector3(-8.0, 0.0, 4.0))
	for r in 8:
		if w.cell.distance_to(spot) < 1.0:
			break
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if w.cell != spot and w.place_at(spot + Vector2i(dx, dy)):
					spot = w.cell
	for off in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if ulisse.place_at(w.cell + off):
			break
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var cam := viewport.get_camera_3d()
	cam.set(&"_follow", null)
	cam.set(&"distance", 3.6)
	cam.set(&"pitch_degrees", -15.0)
	var shots := [["solo", 200.0], ["solo_dietro", 20.0]]
	for s in shots:
		cam.set(&"yaw_degrees", s[1])
		for i in 90:
			cam.set(&"target", w.global_position + Vector3(0.0, 0.9, 0.0))
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/wounded_carry_%s.png" % s[0]))
	# Con il compagno.
	var placed := false
	for dist in [4, 3, 2]:
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var clear := true
			for k in range(1, dist + 1):
				if not grid.is_walkable(w.cell + dir * k) or w.cell + dir * k == ulisse.cell:
					clear = false
					break
			if clear and mate.place_at(w.cell + dir * dist):
				placed = true
				break
		if placed:
			break
	var t := 0.0
	while t < 10.0 and not w._helper_joined:
		await create_timer(0.1).timeout
		t += 0.1
	print("joined ", w._helper_joined, " ", t)
	for i in 60:
		await process_frame
	for s in [["compagno", 200.0], ["compagno_dietro", 20.0], ["compagno_lato", 110.0]]:
		cam.set(&"yaw_degrees", s[1])
		for i in 60:
			cam.set(&"target", w.global_position + Vector3(0.0, 0.9, 0.0))
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/wounded_carry_%s.png" % s[0]))
	quit()
