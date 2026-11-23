extends SceneTree
## Gli animali (cavalli, pecore, montone, maiali) sono ostacoli solidi: le loro caselle sono bloccate
## (anche mentre fanno i passetti), i personaggi non li attraversano, il pathfinding li aggira e
## non chiudono il corridoio campo-costa né i punti dei feriti/imbarco.
## godot --headless --path . -s res://tests/test_animal_block.gd

const X_SHORE := -20.0
const X_CAMP_EAST := -6.0
const Z_MIN := 10.0
const Z_MAX := 13.0

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load("res://scenes/levels/level1/level1.tscn").instantiate()
	root.add_child(level)
	for i in 10:
		await process_frame
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var animals: Array[GridProp] = []
	for n in level.find_children("*", "GridProp", true, false):
		if (n as GridProp).animal != "":
			animals.append(n)
	_check(animals.size() >= 15, "animali trovati: %d" % animals.size())

	# 1. Ogni animale ha un corpo sulla griglia; i cavalli occupano più caselle.
	var union := {}  # casella -> true, su tutta la simulazione
	for a in animals:
		var cells := grid.get_body_cells(a)
		var outside := not grid.is_inside(grid.world_to_cell(a.global_position))
		if outside:
			continue  # fuori dal campo di gioco (oltre il bordo sud): nessuna unità ci arriva
		_check(not cells.is_empty(), "%s ha caselle bloccate" % a.name)
		if a.animal == "horse":
			_check(cells.size() >= 2, "%s (cavallo) occupa più caselle: %d" % [a.name, cells.size()])
		for c in cells:
			_check(grid.is_blocked(c) and not grid.is_walkable(c), "%s: casella %s bloccata" % [a.name, c])
			union[c] = true
		var circles: PackedVector3Array = a.get_node("AnimalIdle")._circles(Vector2.ZERO, 0.0)
		var crowded := false
		for b in animals:
			if b != a and b.global_position.distance_to(a.global_position) < 1.6:
				crowded = true  # due corpi vicini: il personaggio spinto fuori da uno può finire nell'altro
		for circle in circles.slice(0, 0 if crowded else 1):
			_check(grid.resolve_circle(Vector2(circle.x, circle.y), 0.28, grid.world_to_cell(Vector3(circle.x, 0, circle.y)))["pos"].distance_to(Vector2(circle.x, circle.y)) >= circle.z + 0.28 - 0.01,
				"%s: un personaggio non entra nel corpo" % a.name)

	# 2. Simula 120 s: mai su ostacoli fissi, mai uno dentro l'altro, caselle sempre bloccate.
	for f in 2400:
		await process_frame
		if f % 4 != 0:
			continue
		for a in animals:
			var idle: Node = a.get_node("AnimalIdle")
			var cells := grid.get_body_cells(a)
			for c in cells:
				union[c] = true
				if grid.is_static_blocked(c) and not grid._thin_cells.has(c):
					_fail("%s sta su una casella fissa bloccata %s" % [a.name, c])
			for b in animals:
				if b == a or b.name > a.name:
					continue
				for ca: Vector3 in grid._bodies[a]["circles"]:
					for cb: Vector3 in grid._bodies[b]["circles"]:
						if Vector2(ca.x, ca.y).distance_to(Vector2(cb.x, cb.y)) < (ca.z + cb.z) * 0.9:
							_fail("%s e %s si compenetrano" % [a.name, b.name])
	var moved := 0
	for a in animals:
		if grid.get_body_cells(a) != _initial(a):
			moved += 1
	print("animali che hanno cambiato casella: ", moved)

	# 3. Corridoio campo-costa, punti feriti, riva e partenza del campo restano liberi.
	var rules := LevelRules.new()
	var keep := {}
	for x in range(int(X_SHORE), int(X_CAMP_EAST)):
		for z in range(int(Z_MIN), int(Z_MAX)):
			keep[grid.world_to_cell(Vector3(x + 0.5, 0.0, z + 0.5))] = "corridoio"
	for wp in rules.wounded_points:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				keep[grid.world_to_cell(Vector3(wp.x, 0, wp.y)) + Vector2i(dx, dy)] = "ferito %s" % wp
	var sp := rules.shore_point
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			keep[grid.world_to_cell(Vector3(sp.x, 0, sp.y)) + Vector2i(dx, dy)] = "imbarco"
	var camp_mid := Vector2i(rules.camp_rect.position + rules.camp_rect.size / 2)
	keep[camp_mid] = "centro campo"
	for c: Vector2i in keep:
		_check(not union.has(c), "casella %s (%s) mai occupata da animali" % [c, keep[c]])

	# 4. Il pathfinding aggira: dal centro del campo ogni casella libera statica è ancora raggiungibile.
	var start := grid.world_to_cell((get_first_node_in_group(&"player") as Node3D).global_position)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + d
			if grid.is_inside(nx) and not grid.is_blocked(nx) and not seen.has(nx) and grid.step_allowed(cur, nx):
				seen[nx] = true
				queue.append(nx)
	# Si guarda il campo di gioco (z < 18 m): la striscia di bordo sud del campo (due file di caselle
	# dietro ai cavalli legati, senza feriti né imbarchi) può restare chiusa dal cavallo.
	var lost := 0
	for y in 37:
		for x in grid.size.x:
			var c := Vector2i(x, y)
			if not grid.is_static_blocked(c) and not grid._body_cells.has(c) and not seen.has(c) and not grid.find_unreachable_cells(start).has(c):
				lost += 1
	_check(lost == 0, "gli animali non chiudono zone raggiungibili (%d)" % lost)
	if lost > 0:
		for y in 37:
			for x in grid.size.x:
				var c := Vector2i(x, y)
				if not grid.is_static_blocked(c) and not grid._body_cells.has(c) and not seen.has(c) and not grid.find_unreachable_cells(start).has(c):
					print("   chiusa: ", c, " ", grid.cell_to_world(c))
	_check(grid.validate_connectivity(start), "connettività statica invariata")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)


var _init_cells := {}

func _initial(a: GridProp) -> Array[Vector2i]:
	# Prima chiamata registra lo stato di partenza equivalente: usa il corpo a riposo.
	var idle: Node = a.get_node("AnimalIdle")
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var probe := Node.new()
	grid.set_body(probe, idle._circles(Vector2.ZERO, 0.0))
	var cells := grid.get_body_cells(probe)
	grid.remove_body(probe)
	return cells


func _fail(what: String) -> void:
	_failures += 1
	print("FALLITO ", what)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fail(what)
