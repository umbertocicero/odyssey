extends SceneTree
## Screenshot degli alberi del livello 1 (serve una finestra, non headless).
## Avvio: godot --path . -s res://tests/screenshot_trees.gd -- --quality=high
## Le immagini finiscono in tests/screenshots/trees/ (a: insieme, b: da vicino,
## c: Ulisse sotto la chioma, che diventa semitrasparente).

var _main: Node
var _ulisse: GridUnit
var _grid: DioramaGrid
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(_main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots/trees"))
	for i in 30:
		await process_frame
	_ulisse = get_first_node_in_group(&"player")
	_grid = get_first_node_in_group(&"diorama_grid")
	_camera = (_main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	_camera.set(&"follow_bounds", Rect2(-30, -30, 60, 60))
	# a) abeti e alberelli a ovest: Abete 6,5 m, abeti medi, ulivo, cipresso.
	await _shot("a_insieme", Vector2(-14.5, -5.0), 24.0)
	# b) da vicino: l'abete grande e un abete più piccolo.
	await _shot("b_vicino", Vector2(-16.5, -7.5), 11.0)
	# c) Ulisse sotto la chioma di un abete medio, poi sotto l'ulivo.
	await _shot("c_sotto_chioma_abete", Vector2(-15.5, -4.2), 8.0)
	await _shot("c_sotto_chioma_ulivo", Vector2(-13.0, -0.2), 8.0)
	await _shot("c_sotto_chioma_ulivo_largo", Vector2(-13.0, -0.2), 15.0)
	quit()


func _shot(shot_name: String, world: Vector2, distance: float) -> void:
	var cell := _grid.world_to_cell(Vector3(world.x, 0, world.y))
	var placed := false
	for r in 4:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if not placed and _ulisse.place_at(cell + Vector2i(dx, dy)):
					placed = true
	_camera.set(&"distance", distance)
	for i in 120:
		await process_frame
	var path := "res://tests/screenshots/trees/trees_%s.png" % shot_name
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("salvata ", path, " Ulisse in ", _ulisse.global_position)
