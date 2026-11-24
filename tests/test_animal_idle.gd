extends SceneTree
## Gli animali si muovono ma restano vicino al punto di partenza, e non cambiano la griglia.
## godot --headless --path . -s res://tests/test_animal_idle.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	var animals: Array[GridProp] = []
	for n in main.find_children("*", "GridProp", true, false):
		if (n as GridProp).animal != "":
			animals.append(n)
	var fails := 0
	if animals.size() < 10:
		print("FAIL: animali trovati ", animals.size()); fails += 1
	var start := {}
	var maxd := {}
	for a in animals:
		start[a] = a.global_position
		maxd[a] = 0.0
	# Simula ~90 s a 20 fps di tempo di gioco.
	for i in 1800:
		await process_frame
		for a in animals:
			var v := a.visual_node()
			if v == null:
				continue
			maxd[a] = maxf(maxd[a], Vector2(v.position.x, v.position.z).length())
	var moved := 0
	for a in animals:
		var v := a.visual_node()
		if v == null:
			continue  # qualità bassa: modello non mostrato
		if a.global_position != start[a]:
			print("FAIL: il nodo si e' spostato ", a.name); fails += 1
		var lim := a.animal_wander + 0.6
		if maxd[a] > lim:
			print("FAIL: ", a.name, " troppo lontano ", maxd[a]); fails += 1
		if v.transform.is_equal_approx(Transform3D.IDENTITY):
			print("FAIL: ", a.name, " non animato"); fails += 1
		if maxd[a] > 0.05:
			moved += 1
	print("animali ", animals.size(), " con passi ", moved)
	print("OK" if fails == 0 else "FAILED %d" % fails)
	quit(1 if fails else 0)
