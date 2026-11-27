extends SceneTree
## Pose delle braccia in prima persona (DuelArms): guardia, parate nelle cinque direzioni e i quattro colpi
## (affondo alto e basso, fendente largo da sinistra e da destra) in quattro istanti: carica, partenza,
## impatto (0,22 s), accompagnamento. Il nemico resta fermo.
## Serve una finestra: DISPLAY=:0 godot --path . -s res://tests/screenshot_duel_poses.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	director.rules = rules
	root.add_child(main)
	for i in 90:
		await process_frame
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var foe := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 500, "Duello_T") as TrojanSoldier
	director._units_root.add_child(foe)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if grid.is_walkable(ulisse.cell + d) and grid.get_occupant(ulisse.cell + d) == null and foe.place_at(ulisse.cell + d):
			break
	await process_frame
	ulisse.call(&"_melee_attack")
	var duel := Duel.active
	if duel == null:
		print("duel did not start")
		quit()
		return
	var dir := ProjectSettings.globalize_path("res://tests/screenshots/duel_poses")
	DirAccess.make_dir_recursive_absolute(dir)
	while duel.phase != Duel.Phase.FIGHT:
		await process_frame
	duel.set(&"_atk_cd", 999.0)
	for i in 40:
		await process_frame
	duel.set(&"_atk_cd", 999.0)
	root.get_texture().get_image().save_png(dir + "/guard.png")
	var arms: DuelArms = duel.get(&"_arms")
	for a in [-1, 0, 1, 2, 3]:
		arms.play_parry(a, 99.0)
		for i in 20:
			await process_frame
		duel.set(&"_atk_cd", 999.0)
		root.get_texture().get_image().save_png("%s/parry_%d.png" % [dir, a])
	arms.set(&"_keys", [])
	arms.set(&"_hold", null)
	for i in 20:
		await process_frame
	for a in 4:
		Engine.time_scale = 0.05
		arms.play_attack(a)
		for mark in [0.1, 0.16, 0.22, 0.3]:
			while float(arms.get(&"_key_t")) < mark:
				await process_frame
			root.get_texture().get_image().save_png("%s/attack_%d_%d.png" % [dir, a, int(mark * 100)])

		Engine.time_scale = 1.0
		duel.set(&"_atk_cd", 999.0)
		for i in 30:
			await process_frame
	print("poses saved in ", dir)
	quit()
