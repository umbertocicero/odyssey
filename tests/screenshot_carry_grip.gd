extends SceneTree
## Presa del trasporto: Ulisse cinge la vita del ferito, il ferito ha il braccio sulle spalle di Ulisse.
## Avvio: godot --path . -s res://tests/screenshot_carry_grip.gd
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
	var hud := main.get_node_or_null("UI/LevelHud") as CanvasItem
	if hud:
		hud.visible = false
	var spot := grid.world_to_cell(Vector3(-8.0, 0.0, 4.0))
	var done := false
	for r in 8:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if done or maxi(absi(dx), absi(dy)) != r:
					continue
				var c := spot + Vector2i(dx, dy)
				if grid.is_walkable(c) and grid.is_walkable(c + Vector2i(1, 0)) and grid.get_occupant(c) == null and grid.get_occupant(c + Vector2i(1, 0)) == null:
					ulisse.place_at(c)
					w.place_at(c + Vector2i(1, 0))
					done = true
	w.start_support(ulisse, WoundedSoldier.State.FOLLOWING)
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	for i in 150:
		await process_frame
	print("pos ", ulisse.global_position, w.global_position, ulisse.cell, w.cell)
	var c := (ulisse.global_position + w.global_position) * 0.5 + Vector3(0, 0.9, 0)
	cam.set(&"_follow", null)
	cam.set(&"distance", 3.0)
	var dir := ProjectSettings.globalize_path("res://screenshots/")
	# Ulisse guarda verso -Z del modello ruotato di rotation.y: davanti = yaw del modello + 180 gradi.
	var ym := rad_to_deg((ulisse.get_node("Model") as Node3D).rotation.y)
	var views := {"front": [ym + 180.0, -35.0], "side": [ym + 90.0, -20.0], "top": [ym + 180.0, -65.0]}
	for k in views:
		cam.set(&"yaw_degrees", views[k][0])
		cam.set(&"pitch_degrees", views[k][1])
		for i in 110:
			cam.set(&"target", (ulisse.global_position + w.global_position) * 0.5 + Vector3(0, 0.9, 0))
			await process_frame
		root.get_texture().get_image().save_png(dir + "carry_grip_%s.png" % k)
	quit()
