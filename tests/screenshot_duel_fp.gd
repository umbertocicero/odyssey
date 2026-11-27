extends SceneTree
## Duello in prima persona: avvia un duello tra Ulisse e un troiano, lo gioca con un "bot" (para nella
## direzione giusta, attacca da dove il nemico non si copre) e salva fotogrammi della finestra.
## Serve una finestra: DISPLAY=:0 godot --path . -s res://tests/screenshot_duel_fp.gd -- [--every=0.25] [--bot=good|none]
## [--noshots] (solo FPS) [--lowhp] (Ulisse quasi morto: prova della sconfitta) [--nograss|--noblades|--nocards] (confronto prestazioni dell'erba)
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var every := 0.25
	var bot := "good"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--every="):
			every = float(arg.substr(8))
		if arg.begins_with("--bot="):
			bot = arg.substr(6)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	director.rules = rules
	root.add_child(main)
	for i in 90:
		await process_frame
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var noshots := OS.get_cmdline_user_args().has("--noshots")
	if noshots:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if OS.get_cmdline_user_args().has("--noblades"):
		for n in root.find_children("*", "", true, false):
			if n is GrassField:
				n.visible = false
	if OS.get_cmdline_user_args().has("--nocards"):
		for n in root.find_children("*", "", true, false):
			if n is GrassCards:
				n.visible = false
	if OS.get_cmdline_user_args().has("--nograss"):
		for n in root.find_children("*", "", true, false):
			if n is GrassField or n is GrassCards:
				n.visible = false
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var spot := ulisse.cell
	if OS.get_cmdline_user_args().has("--lowhp"):
		ulisse.health = 20
	var foe := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 90, "Duello_T") as TrojanSoldier
	director._units_root.add_child(foe)
	var placed := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if grid.is_walkable(spot + d) and grid.get_occupant(spot + d) == null:
			placed = foe.place_at(spot + d)
			if placed:
				break
	print("foe placed: ", placed, " ", foe.global_position, " ulisse ", ulisse.global_position)
	var dir := ProjectSettings.globalize_path("res://tests/screenshots/duel_fp")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	for i in 2:
		await process_frame
	print("fps before duel: ", Engine.get_frames_per_second(), " dc=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prim=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	# Come nel gioco: Ulisse attacca il troiano accanto e il colpo apre il duello.
	ulisse.call(&"_melee_attack")
	print("duel started by Odysseus' attack: ", Duel.active != null and Duel.active.foe == foe)
	var started := Time.get_ticks_msec()
	var next_shot := 0.0
	var shot := 0
	var real := 0.0
	var last := Time.get_ticks_usec()
	var parried_this := false
	var atk_cd := 0.0
	var last_popup_state := -1
	while Duel.active != null and real < 70.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000000.0
		last = now
		real += dt
		next_shot -= dt
		var duel := Duel.active
		if duel == null:
			break
		if duel.phase == Duel.Phase.FIGHT and bot == "good":
			for a in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack", &"parry", &"dodge"]:
				Input.action_release(a)
			atk_cd -= dt * Engine.time_scale
			if duel.foe_state == Duel.FoeState.WINDUP:
				if duel.windup_progress > 0.4 and not parried_this:
					parried_this = true
					# Una volta su due schiva, altrimenti para nella direzione giusta.
					_press_aim(duel.foe_aim)
					Input.action_press(&"parry" if shot % 2 == 0 else &"dodge")
			else:
				parried_this = false
				if atk_cd <= 0.0 and duel.player_stamina > 30.0:
					var aim := (duel.guard_aim + 1 + randi() % 3) % 4
					_press_aim(aim)
					Input.action_press(&"attack")
					atk_cd = 2.1
		if next_shot <= 0.0:
			next_shot = every
			if not noshots:
				root.get_texture().get_image().save_png("%s/f%03d.png" % [dir, shot])
			print("dc=%d obj=%d prim=%dk " % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000], "fps=%d fs=%d atk=%.2f wp=%.2f " % [Engine.get_frames_per_second(), duel.foe_state, duel._atk_cd, duel.windup_progress], "f%03d phase=%d ts=%.2f foe=%d/%d st=%.0f/%.0f pl=%d/%d" % [shot, duel.phase, Engine.time_scale, foe.health, foe.max_health, duel.foe_stamina, duel.player_stamina, ulisse.health, ulisse.max_health])
			shot += 1
	for a in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack", &"parry", &"dodge"]:
		Input.action_release(a)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(dir + "/final.png")
	print("done: duel ended=", Duel.active == null, " foe=", foe.health, " ulisse=", ulisse.health, " time_scale=", Engine.time_scale, " frames=", shot)
	quit()

func _press_aim(aim: int) -> void:
	var a: StringName = [&"move_up", &"move_left", &"move_right", &"move_down"][aim]
	Input.action_press(a)
