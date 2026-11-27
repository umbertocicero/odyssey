extends SceneTree
## Fuoco a terra delle frecce infuocate: screenshot ravvicinati (giorno/notte). Serve una finestra.
## DISPLAY=:0 godot --path . -s res://tests/screenshot_burning_cell.gd
func _initialize() -> void:
	_run.call_deferred()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await _wait(3.0)
	var clock := get_first_node_in_group(&"level_clock") as LevelClock
	clock.running = false
	clock.rain_chance = 0.0
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var player := get_first_node_in_group(&"player") as GridUnit
	var c := player.cell + Vector2i(0, -3)
	BurningCell.ignite(grid, c, 30.0, 4)
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var camera := viewport.get_camera_3d()
	camera.set(&"_follow", null)
	camera.set(&"target", grid.cell_to_world(c) + Vector3(0, 0.4, 0))
	camera.set(&"distance", 3.5)
	for t in [[17.0, "giorno"], [22.0, "notte"]]:
		clock.time_of_day = t[0]
		await _wait(3.0)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/fuoco_%s.png" % t[1]))
	quit()
