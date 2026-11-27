extends SceneTree
## Elenca i nodi che il livello 1 crea a runtime (senza owner, quindi non presenti in level1.tscn),
## solo il primo livello di ogni ramo generato, con classe e script del padre.
## Avvio: godot --headless --path . -s res://tests/tools/list_runtime_nodes.gd


func _initialize() -> void:
	_run.call_deferred()


func _walk(n: Node, level: Node, out: Dictionary) -> void:
	for c in n.get_children():
		if c.owner == null and c != level and not (c.scene_file_path != "" and c.owner == null and false):
			var parent_script := ""
			if n.get_script():
				parent_script = (n.get_script() as Script).resource_path.get_file()
			var key := "%s | %s | padre=%s (%s)" % [c.get_class(), String(c.name).rstrip("0123456789@"), level.get_path_to(n), parent_script]
			out[key] = int(out.get(key, 0)) + 1
		else:
			_walk(c, level, out)


func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	var level := get_first_node_in_group(&"diorama_grid").get_parent()
	var out := {}
	_walk(level, level, out)
	var keys := out.keys()
	keys.sort()
	for k in keys:
		print("RUNTIME ", out[k], "x  ", k)
	quit()
