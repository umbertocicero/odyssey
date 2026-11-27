extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var main: Node = load("res://scenes/main/main_level2.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	var w: Level2World = get_first_node_in_group(&"level2_world")
	var g := w.grid
	var pc := g.world_to_cell(w.player.global_position)
	print("player cell ", pc, " blocked? ", g.is_blocked(pc), " walkable ", g.is_walkable(pc))
	var n := 0
	for y in 40:
		var row := ""
		for x in 40:
			row += "#" if g.is_blocked(Vector2i(x, y)) else "."
		print(row)
	quit()
