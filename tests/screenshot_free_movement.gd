extends SceneTree
## Schermate del movimento libero (serve una finestra, non headless).
## Avvio: godot --path . -s res://tests/screenshot_free_movement.gd

var ulisse
var grid


func _initialize() -> void:
	_run.call_deferred()


func _hold(action: StringName, frames: int, shot := "") -> void:
	Input.action_press(action)
	for i in frames:
		await physics_frame
	if shot != "":
		await process_frame
		await process_frame
		_save(shot)
	Input.action_release(action)


func _save(shot_name: String) -> void:
	var path := ProjectSettings.globalize_path("res://tests/screenshots/free_%s.png" % shot_name)
	root.get_texture().get_image().save_png(path)
	print("salvata ", path, "  pos=", ulisse.global_position)


func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	ulisse = get_first_node_in_group(&"player")
	grid = get_first_node_in_group(&"diorama_grid")
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var camera: Camera3D = viewport.get_camera_3d()
	camera.set(&"distance", 12.0)
	# Un albero e un palo, dal livello.
	var tree_prop = null
	var pole_prop = null
	for n in get_nodes_in_group(&"grid_obstacle"):
		if not n.has_method(&"thin_shape") or n.thin_shape().is_empty():
			continue
		var c: Vector2 = n.thin_shape()["center"]
		if n.is_tree() and tree_prop == null and absf(c.x) < 16 and absf(c.y) < 16:
			tree_prop = n
		elif not n.is_tree() and pole_prop == null and absf(c.x) < 16 and absf(c.y) < 16:
			pole_prop = n
	print("albero: ", tree_prop.name if tree_prop else "-", " palo: ", pole_prop.name if pole_prop else "-")
	for prop in [["albero", tree_prop], ["palo", pole_prop]]:
		var p = prop[1]
		if p == null:
			continue
		var c: Vector2 = p.thin_shape()["center"]
		# Parte 2,5 m a sinistra (sullo schermo) del tronco, leggermente sfalsato, e cammina a destra.
		var right: Vector3 = ulisse.screen_to_world_direction(Vector2.RIGHT)
		var start := Vector3(c.x, 0, c.y) - right * 2.5 + Vector3(0.0, 0, 0.0)
		ulisse.global_position = Vector3(start.x, grid.get_height_at_world(start), start.z)
		ulisse._sync_cell()
		for i in 20:
			await physics_frame
		var x0: Vector3 = ulisse.global_position
		await _hold(&"move_right", 40, "%s_prima" % prop[0])
		await _hold(&"move_right", 45, "%s_sotto" % prop[0])
		await _hold(&"move_right", 70, "%s_dopo" % prop[0])
		var d: float = (ulisse.global_position - Vector3(c.x, ulisse.global_position.y, c.y)).dot(right)
		print(prop[0], ": oltre il tronco di ", d, " m (>0 = superato)")
	# Chioma: lontano è opaca, sotto diventa semitrasparente.
	if tree_prop:
		var tc: Vector2 = tree_prop.thin_shape()["center"]
		var right2: Vector3 = ulisse.screen_to_world_direction(Vector2.RIGHT)
		for spec in [["chioma_lontano", 6.0], ["chioma_sotto", 0.9]]:
			var pp: Vector3 = Vector3(tc.x, 0, tc.y) - right2 * float(spec[1])
			ulisse.global_position = Vector3(pp.x, grid.get_height_at_world(pp), pp.z)
			ulisse._sync_cell()
			for i in 50:
				await physics_frame
			await process_frame
			await process_frame
			var tr := -1.0
			for ch in tree_prop._visual.get_children():
				if ch is MeshInstance3D:
					tr = ch.transparency
			print(spec[0], ": trasparenza chioma = ", tr)
			_save(spec[0])
	# Diagonale.
	var before: Vector3 = ulisse.global_position
	Input.action_press(&"move_right"); Input.action_press(&"move_down")
	for i in 30:
		await physics_frame
	Input.action_release(&"move_right"); Input.action_release(&"move_down")
	print("diagonale: spostamento ", ulisse.global_position - before)
	quit()
