extends SceneTree
## Barella da vicino mentre i quattro portatori la trasportano.
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_stretcher.gd -- --out=barella

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "barella"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	rules.severe_wounded = 1
	director.rules = rules
	root.add_child(main)
	for i in 50:
		await process_frame
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var w: WoundedSoldier = director.wounded[director.wounded.size() - 1]
	var free: Array[AllySoldier] = []
	for n in get_nodes_in_group(&"achei"):
		if n is AllySoldier:
			free.append(n)
	while free.size() < 4:
		var extra := UnitFactory.make(AllySoldier, UnitFactory.MODEL_ACHEO, GridUnit.Team.ACHEI, 60, "Extra%d" % free.size()) as AllySoldier
		main.add_child(extra)
		free.append(extra)
	for d in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if ulisse.place_at(w.cell + d):
			break
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var hud := main.get_node_or_null("UI/LevelHud") as Control
	if hud:
		hud.visible = false
	cam.fov = 30.0
	var st: Node3D = null
	var shots := 0
	for i in 600:
		await process_frame
		if st == null:
			st = main.find_child("Stretcher", true, false) as Node3D
			continue
		if i % 60 == 0:
			var angles := [Vector3(3.2, 2.0, 0.0), Vector3(0.0, 1.6, 4.0), Vector3(-3.0, 2.2, 2.0)]
			var o: Vector3 = angles[shots % 3]
			cam.global_position = st.global_position + o
			cam.look_at(st.global_position + Vector3(0, 0.7, 0), Vector3.UP)
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/barella_%d.png" % [dir, shots]))
			shots += 1
			if shots >= 3:
				break
	quit()
