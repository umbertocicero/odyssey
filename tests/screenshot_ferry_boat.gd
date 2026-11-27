extends SceneTree
## Sequenza della barca: soldato a bordo, salita del ferito, voga, ritorno. Serve una finestra.
## Avvio: godot --path . -s res://tests/screenshot_ferry_boat.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	rules.duration = 300.0
	rules.ferry_sail_time = 3.0
	director.rules = rules
	root.add_child(main)
	for i in 60:
		await process_frame
	var hud := main.get_node_or_null("UI/LevelHud") as CanvasItem
	if hud:
		hud.visible = false
	var ferry := director.ferry
	var boat: FerrySystem.Boat = ferry.boats[0]
	var w: WoundedSoldier = director.wounded[0]
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var cam := viewport.get_camera_3d()
	cam.set(&"_follow", null)
	cam.set(&"distance", 4.2)
	cam.set(&"pitch_degrees", -32.0)
	cam.set(&"yaw_degrees", 60.0)
	var dir := ProjectSettings.globalize_path("res://screenshots/")
	var snap := func(n: String) -> void:
		for i in 12:
			cam.set(&"target", boat.node.global_position + Vector3(0, 0.6, 0))
			await process_frame
		root.get_texture().get_image().save_png(dir + "barca_%s.png" % n)
	await snap.call("1_attesa")
	# Il ferito arriva sulla riva, in piedi.
	w.place_at(ferry.shore_cell())
	var j := FerrySystem.Job.new()
	j.wounded = w
	j.phase = FerrySystem.Phase.WAIT_BOAT
	w.state = WoundedSoldier.State.SAVED
	ferry.jobs.append(j)
	for i in 30:
		await process_frame
	await snap.call("2_salita")
	for i in 55:
		await process_frame
	await snap.call("3_adagiato")
	for i in 60:
		await process_frame
	await snap.call("4_voga")
	var t := 0.0
	while t < 12.0 and not (boat.busy == false):
		await create_timer(0.2).timeout
		t += 0.2
		if t > 7.0 and t < 7.3:
			await snap.call("5_ritorno")
	await snap.call("6_di_nuovo_in_attesa")
	quit()
