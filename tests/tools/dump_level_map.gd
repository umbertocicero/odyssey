extends SceneTree
## Stampa una mappa ASCII del livello: '#' casella bloccata, cifre = livello di rilievo, '.' libera.
## godot --headless --path . -s res://tests/tools/dump_level_map.gd -- res://scenes/levels/level1/level1.tscn

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://scenes/levels/level1/level1.tscn"
	var level: Node = load(path).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var grid: DioramaGrid = get_first_node_in_group(&"diorama_grid")
	print("grid size ", grid.size, " origin ", grid.global_position, " player ", get_first_node_in_group(&"player").global_position if get_first_node_in_group(&"player") else "-")
	for y in grid.size.y:
		var line := ""
		for x in grid.size.x:
			var c := Vector2i(x, y)
			if grid.is_blocked(c):
				line += "#"
			else:
				var l := grid.get_level(c)
				line += str(l) if l > 0 else "."
		print("%02d %s" % [y, line])
	quit()
