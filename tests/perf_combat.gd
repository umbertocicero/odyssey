extends SceneTree
## Prestazioni con una mischia: 8 duelli alleati/troiani vicini alla camera, poi i caduti restano a terra.
## DISPLAY=:0 godot --path . -s res://tests/perf_combat.gd -- --quality=high [--nofx]
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	ClashFx.enabled = not OS.get_cmdline_user_args().has("--nofx")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	director.rules = rules
	root.add_child(main)
	for i in 60:
		await process_frame
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var cam: Camera3D = main.get_node("GameView/GameViewport").get_camera_3d()
	var units_root: Node = director._units_root
	var centre := grid.world_to_cell(cam.get(&"target") as Vector3)
	var pairs := 0
	var duel: Array = []
	for dy in range(-6, 7, 2):
		for dx in range(-6, 7, 3):
			var c := centre + Vector2i(dx, dy)
			if pairs < 8 and grid.is_walkable(c) and grid.is_walkable(c + Vector2i(1, 0)) and grid.get_occupant(c) == null and grid.get_occupant(c + Vector2i(1, 0)) == null:
				var a := UnitFactory.make(AllySoldier, UnitFactory.MODEL_ACHEO, GridUnit.Team.ACHEI, 80, "PA%d" % pairs) as AllySoldier
				var t := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 80, "PT%d" % pairs) as TrojanSoldier
				units_root.add_child(a)
				units_root.add_child(t)
				a.place_at(c)
				t.place_at(c + Vector2i(1, 0))
				duel.append([a, t])
				pairs += 1
	print("duelli: ", pairs)
	for i in 120:
		await process_frame
	var times: Array[float] = []
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < 12_000_000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var sum := 0.0
	for t in times:
		sum += t
	var sorted := times.duplicate()
	sorted.sort()
	var dead := get_nodes_in_group(&"corpses").size()
	print("PERFCOMBAT fx=%s duelli=%d caduti=%d | frame medio=%.2f ms (%.0f FPS) p99=%.2f | VRAM=%.0f MB texmem=%.0f MB" % [
		ClashFx.enabled, pairs, dead, sum / times.size(), 1000.0 / (sum / times.size()), sorted[int(sorted.size() * 0.99)],
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0])
	quit()
