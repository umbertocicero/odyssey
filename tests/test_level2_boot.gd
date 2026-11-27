extends SceneTree
## Carica il livello 2 e lo fa girare qualche secondo: nessun errore, mondo e regia presenti.
## Avvio: godot --headless --path . -s res://tests/test_level2_boot.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main/main_level2.tscn").instantiate()
	root.add_child(main)
	for i in 120:
		await process_frame
	var world := get_first_node_in_group(&"level2_world")
	var player := get_first_node_in_group(&"player")
	print("world=", world != null, " player=", player != null, " trees=", world.tree_nodes.size() if world else -1)
	quit(0 if world and player else 1)
