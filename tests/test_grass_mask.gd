extends SceneTree
## Verifica la maschera dell'erba: niente su mare, sabbia, strade, piazzali, costruzioni;
## densità uniforme e fitta sul prato; sfumatura ai bordi.
## Esecuzione: godot --headless --path . -s res://tests/test_grass_mask.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	Quality.set_level(Quality.Level.HIGH)
	TerrainStyle.set_photo(false)  # prova il vecchio prato procedurale (GrassField)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	var level := main.get_node("GameView/GameViewport/Level1")
	var mask := GrassMask.from_tree(self)
	_check(mask.ground.size() >= 1 and mask.deny.size() >= 8, "la maschera conosce prato (%d) e superfici senza erba (%d)" % [mask.ground.size(), mask.deny.size()])
	_check(mask.weight(Vector2(-24.0, 1.5)) == 0.0, "niente erba sul mare")
	_check(mask.weight(Vector2(-20.8, 5.0)) == 0.0, "niente erba sulla spiaggia")
	_check(mask.weight(Vector2(-23.8, -24.5)) == 0.0, "niente erba nel lembo nord-ovest oltre la riva")
	_check(mask.weight(Vector2(-4.5, 11.5)) == 0.0, "niente erba sulla strada dell'accampamento")
	_check(mask.weight(Vector2(-13.0, 12.0)) == 0.0, "niente erba sul piazzale dell'accampamento")
	_check(mask.weight(Vector2(6.5, -17.5)) == 0.0, "niente erba sul piazzale della porta")
	_check(mask.weight(Vector2(12.0, 0.0)) == 1.0, "prato pieno in aperta pianura")
	var near := mask.weight(Vector2(-19.8, 0.5))
	_check(near > 0.0 and near < 1.0, "l'erba sfuma verso la sabbia (peso %.2f a 20 cm)" % near)

	var grids := get_nodes_in_group(&"diorama_grid")
	var solid: Array[Vector2i] = (grids[0] as DioramaGrid).get_solid_cells()
	_check(solid.size() > 10, "ci sono basi di costruzioni da evitare (%d caselle)" % solid.size())
	var grid := grids[0] as DioramaGrid
	var under := 0
	for c in solid:
		var w := grid.cell_to_world(c)
		if mask.weight(Vector2(w.x, w.z)) > 0.0:
			under += 1
	_check(under == 0, "niente erba sotto le costruzioni (caselle con erba: %d)" % under)

	# Distribuzione reale dei ciuffi.
	for node_name in ["ErbaMossa", "Cespugli"]:
		var grass := level.get_node(node_name) as GrassField
		var mm := grass.multimesh_instance.multimesh
		var bad := 0
		var quadrants := [0, 0, 0, 0]
		for i in grass.tuft_positions.size():
			var world := grass.global_transform * grass.tuft_positions[i]
			if mask.weight(Vector2(world.x, world.z)) <= 0.0:
				bad += 1
			var q: int = 0
			if world.x > 0.0:
				q += 1
			if world.z > 0.0:
				q += 2
			quadrants[q] += 1
		_check(bad == 0, "%s: nessun ciuffo su superfici vietate (%d su %d)" % [node_name, bad, mm.instance_count])
		if node_name == "ErbaMossa":
			_check(mm.instance_count >= 30000, "prato molto fitto: %d ciuffi" % mm.instance_count)
			print("INFO  ciuffi per quadrante: ", quadrants)

	# Quote di qualità: lo stesso criterio a ogni livello.
	for lvl in [Quality.Level.LOW, Quality.Level.MEDIUM, Quality.Level.HIGH]:
		Quality.set_level(lvl)
		var g := GrassField.new()
		g.count = 12000
		g.area_size = Vector2(46, 42)
		g.area_offset = Vector2(0, 1)
		level.add_child(g)
		await process_frame
		var mm2 := g.multimesh_instance.multimesh
		var off := 0
		for i in g.tuft_positions.size():
			var o := g.global_transform * g.tuft_positions[i]
			if mask.weight(Vector2(o.x, o.z)) <= 0.0:
				off += 1
		_check(off == 0 and mm2.instance_count == int(12000 * Quality.density()), "qualità %d: %d ciuffi, tutti sul prato" % [lvl, mm2.instance_count])
		g.queue_free()

	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
