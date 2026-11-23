extends SceneTree
## Ulisse in mezzo a un cespuglio (serve una finestra). Avvio: godot --path . -s res://tests/screenshot_bush.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var ulisse: GridUnit = get_first_node_in_group(&"player")
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var bush: GridProp = main.find_child("Cespuglio1", true, false)
	var c := grid.world_to_cell(bush.global_position)
	ulisse.place_at(c)
	var camera: Camera3D = main.get_node("GameView/GameViewport").get_camera_3d()
	camera.set(&"distance", 7.0)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/bush_after.png"))
	print("salvata pos=", ulisse.global_position)
	quit()
