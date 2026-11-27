extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var main: Node = load("res://scenes/main/main_level2.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	var w: Level2World = get_first_node_in_group(&"level2_world")
	var h := w.get_node_or_null("MassiConfine")
	print("massi=", h.get_child_count() if h else -1)
	if h:
		for c in h.get_children():
			print(c.name, " ", c.position, " vis=", c.visible, " kids=", c.get_child_count())
	quit()
