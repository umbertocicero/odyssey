extends SceneTree
## Primo piano di un ferito su terra spoglia (bende e sangue). Serve una finestra.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	director.rules = rules
	root.add_child(main)
	for i in 60:
		await process_frame
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var w: WoundedSoldier = director.wounded[0]
	w.visible = true
	var spot := grid.world_to_cell(Vector3(-8.0, 0.0, 4.0))
	for r in 6:
		var done := false
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if w.place_at(spot + Vector2i(dx, dy)):
					done = true
					break
			if done:
				break
		if done:
			break
	for n in root.find_children("*", "", true, false):
		if n is GrassField or n is GrassCards:
			n.visible = false
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var cam := viewport.get_camera_3d()
	cam.set(&"_follow", null)
	cam.set(&"target", w.global_position + Vector3(0, 0.6, 0))
	cam.set(&"distance", 3.4)
	cam.set(&"pitch_degrees", -35.0)
	cam.set(&"yaw_degrees", 205.0)
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	ulisse.place_at(grid.world_to_cell(Vector3(-12.0, 0.0, 9.0)))
	var names := ["a_terra_primo_piano", "in_piedi_primo_piano"]
	for k in 2:
		for i in 50:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/wounded_%s.png" % names[k]))
		w._model_node.revive()
		w._model.rotation.x = 0.38
	quit()
