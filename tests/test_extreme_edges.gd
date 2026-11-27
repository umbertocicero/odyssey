extends SceneTree
## Test headless: le unità arrivano agli estremi sud ed est del diorama, poggiano sul terreno
## visibile (quota dei piedi = quota della mesh) e il piede delle pareti non le fa affondare.
## Avvio: godot --headless --path . -s res://tests/test_extreme_edges.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.add_child(load("res://scenes/levels/level1/level1.tscn").instantiate())
	await process_frame
	await process_frame
	var grid: DioramaGrid = get_first_node_in_group(&"diorama_grid")
	var relief: TerrainRelief = get_first_node_in_group(&"terrain_relief")
	var photo: PhotoTerrain = get_first_node_in_group(&"photo_terrain")
	var ulisse: GridUnit = get_first_node_in_group(&"player")
	for s in get_nodes_in_group(&"wall_shooters"):
		s.auto_fire = false
	_check(grid != null and relief != null and ulisse != null, "griglia, rilievo e Ulisse presenti")

	# 1. La griglia arriva ai bordi sud ed est del terreno (x 26, z 22) senza spostare il resto.
	var se := grid.cell_to_world(grid.total_size() - Vector2i.ONE)
	_check(absf(se.x - 25.5) < 0.01 and absf(se.z - 21.5) < 0.01, "ultima casella a sud-est vicina al bordo del terreno (%.1f, %.1f)" % [se.x, se.z])
	_check(grid.cell_to_world(Vector2i(0, 0)).is_equal_approx(Vector3(-19.5, grid.cell_to_world(Vector2i(0, 0)).y, -19.5)), "l'angolo nord-ovest non si è spostato")

	# 2. Le unità raggiungono gli estremi e poggiano sulla mesh.
	var bottom := Vector2i(20, grid.total_size().y - 1)
	var right := Vector2i(grid.total_size().x - 1, 31)
	for c in [bottom, right, grid.total_size() - Vector2i.ONE]:
		_check(grid.is_inside(c) and not grid.is_blocked(c), "casella estrema %s libera" % [c])
		if not ulisse.place_at(c):
			_check(false, "Ulisse non riesce a mettersi in %s" % [c])
			continue
		var w := ulisse.global_position
		_check(absf(w.y - photo.height_at(w.x, w.z)) < 0.03, "piedi di Ulisse sulla mesh in %s (%.2f vs %.2f)" % [c, w.y, photo.height_at(w.x, w.z)])
	var unreachable := grid.find_unreachable_cells(Vector2i(8, 31))
	_check(not unreachable.has(bottom) and not unreachable.has(right), "gli estremi sono raggiungibili a piedi")

	# 3. Piede delle pareti: la quota delle unità segue la mesh, non affonda (prima: 0,12 contro 0,43 a z -19,8).
	for p in [Vector2(-4.0, -19.8), Vector2(19.9, 8.0), Vector2(-8.6, -19.7)]:
		var u := relief.height_at_world(p.x, p.y)
		var m := photo.height_at(p.x, p.y)
		_check(m - u < 0.05, "ai piedi della parete in %s l'unità non affonda (unità %.2f, mesh %.2f)" % [p, u, m])

	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(_failures)


func _check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		_failures += 1
