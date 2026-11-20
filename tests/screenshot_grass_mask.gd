extends SceneTree
## Schermate della maschera dell'erba (serve una finestra, non headless; qualità high).
## Avvio: DISPLAY=:0 godot --path . -s res://tests/screenshot_grass_mask.gd

const SHOTS := [
	["erba_alto", Vector3(-1, 0, -4), 60.0, -75.0],
	["erba_riva", Vector3(-20.0, 0, 2.0), 8.0, -42.0],
	["erba_prato", Vector3(12.0, 0, 6.0), 8.0, -42.0],
	["erba_tenda", Vector3(-15.5, 0, 9.5), 8.0, -42.0],
]


func _initialize() -> void:
	Quality.set_level(Quality.Level.HIGH)
	TerrainStyle.set_photo(false)  # maschera del vecchio prato procedurale
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	for i in 40:
		await process_frame
	var camera: Camera3D = main.get_node("GameView/GameViewport").get_camera_3d()
	camera.set(&"_follow", null)
	for shot in SHOTS:
		camera.set(&"target", shot[1])
		camera.set(&"distance", shot[2])
		camera.set(&"pitch_degrees", shot[3])
		for i in 40:
			await process_frame
		var path := "res://tests/screenshots/%s.png" % shot[0]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("salvata ", path)
	quit(0)
