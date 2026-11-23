extends SceneTree
## Tavola di fotogrammi di un duello ravvicinato (scambio di colpi, parate con scintille, sangue) in
## rallentatore, poi due caduti sul rilievo. Serve una finestra.
## DISPLAY=:0 godot --path . -s res://tests/screenshot_duel.gd -- --quality=high [--scale=0.2] [--shots=40]
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scale := 0.2
	var shots := 40
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scale="):
			scale = float(arg.substr(8))
		if arg.begins_with("--shots="):
			shots = int(arg.substr(8))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	director.rules = rules
	root.add_child(main)
	for i in 60:
		await process_frame
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	for n in root.find_children("*", "", true, false):
		if n is GrassField or n is GrassCards:
			n.visible = false
	var spot := grid.world_to_cell(Vector3(-8.0, 0.0, 4.0))
	for r in 8:
		var found := false
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c := spot + Vector2i(dx, dy)
				if grid.is_walkable(c) and grid.is_walkable(c + Vector2i(1, 0)) and grid.get_occupant(c) == null and grid.get_occupant(c + Vector2i(1, 0)) == null:
					spot = c
					found = true
					break
			if found:
				break
		if found:
			break
	var ally := UnitFactory.make(AllySoldier, UnitFactory.MODEL_ACHEO, GridUnit.Team.ACHEI, 400, "Duello_A") as AllySoldier
	var foe := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 400, "Duello_T") as TrojanSoldier
	if OS.get_cmdline_user_args().has("--fullmodel"):
		(foe.get_node("Model") as CharacterModel).model_scene = load(UnitFactory.MODEL_TROIANO) as PackedScene
	var units_root: Node = director._units_root
	units_root.add_child(ally)
	units_root.add_child(foe)
	print("place: ", ally.place_at(spot), foe.place_at(spot + Vector2i(1, 0)), " ", ally.global_position, foe.global_position, " grid=", grid.global_position)
	ally.face(Vector2i(1, 0))
	foe.face(Vector2i(-1, 0))
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	ulisse.place_at(grid.world_to_cell(Vector3(-12.0, 0.0, 9.0)))
	var mid := (ally.global_position + foe.global_position) * 0.5
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var cam := viewport.get_camera_3d()
	cam.set(&"_follow", null)
	cam.set(&"target", mid + Vector3(0, 1.1, 0))
	cam.set(&"distance", 3.0)
	cam.set(&"pitch_degrees", -14.0)
	cam.set(&"yaw_degrees", 0.0)
	print("cam target ", cam.get(&"target"), " cam pos ", cam.global_position)
	for i in 30:
		await process_frame
	var dir := ProjectSettings.globalize_path("res://tests/screenshots/duel")
	DirAccess.make_dir_recursive_absolute(dir)
	Engine.time_scale = scale
	for k in shots:
		for i in 3:
			await process_frame
		viewport.get_texture().get_image().save_png("%s/f%02d.png" % [dir, k])
	Engine.time_scale = 1.0
	print("duello: vita alleato=%d troiano=%d" % [ally.health, foe.health])
	# Prova diretta degli effetti, in rallentatore.
	Engine.time_scale = 0.15
	ClashFx.sparks(ally, mid + Vector3(0, 1.2, 0), Vector3.UP)
	ClashFx.blood_hit(ally, mid + Vector3(0.3, 1.2, 0), Vector3.RIGHT, true)
	for k in 6:
		for i in 3:
			await process_frame
		viewport.get_texture().get_image().save_png("%s/fx%d.png" % [dir, k])
	Engine.time_scale = 1.0
	# Morte di entrambi: corpi a terra e sangue.
	foe.take_damage(999, Vector3.RIGHT)
	ally.take_damage(999, Vector3.LEFT)
	for i in 180:
		await process_frame
	cam.set(&"target", mid + Vector3(0, 0.3, 0))
	cam.set(&"distance", 3.6)
	cam.set(&"pitch_degrees", -35.0)
	cam.set(&"yaw_degrees", 0.0)
	print("morti: ally ", ally.global_position, " foe ", foe.global_position, " cam ", cam.global_position)
	for i in 10:
		await process_frame
	viewport.get_texture().get_image().save_png("%s/morti.png" % dir)
	quit()
