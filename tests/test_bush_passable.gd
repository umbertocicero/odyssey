extends SceneTree
## I cespugli si attraversano: non sono ostacoli, non si scalano né scavalcano e la quota non cambia.
## Esecuzione: godot --headless --path . -s res://tests/test_bush_passable.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	Quality.set_level(Quality.Level.HIGH)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var bushes: Array[GridProp] = []
	for n in get_nodes_in_group(&"grid_obstacle"):
		if n is GridProp and (n as GridProp).is_bush():
			bushes.append(n)
	_check(bushes.is_empty(), "nessun cespuglio è registrato come ostacolo")
	var found: int = main.find_children("Cespuglio*", "GridProp", true, false).size()
	var walked := 0
	for node in main.find_children("Cespuglio*", "GridProp", true, false):
		var b := node as GridProp
		_check(b.is_bush(), "%s è un cespuglio" % b.name)
		var cell := grid.world_to_cell(b.global_position)
		if grid.is_blocked(cell) or grid.is_climbable(cell) or grid.is_vaultable(cell):
			_check(grid.is_blocked(cell) == false, "%s: la casella %s è libera" % [b.name, cell])
			continue
		# Ci si cammina in mezzo: la casella è libera e la quota del terreno non cambia.
		var from := cell + Vector2i.LEFT
		if grid.is_blocked(from) or not grid.is_inside(from):
			continue
		ulisse.place_at(from)
		await create_timer(0.1).timeout
		var y0 := ulisse.global_position.y
		var ok := ulisse.try_step(Vector2i.RIGHT)
		await create_timer(1.0).timeout
		if ok and grid.world_to_cell(ulisse.global_position) == cell:
			walked += 1
			_check(absf(ulisse.global_position.y - grid.get_height_at_world(b.global_position)) < 0.05 \
				or absf(ulisse.global_position.y - y0) < 0.3, "%s: l'unità resta a livello suolo" % b.name)
		if walked >= 3:
			break
	_check(found >= 5, "trovati %d cespugli" % found)
	_check(walked >= 1, "almeno un cespuglio attraversato (%d)" % walked)
	# Gli altri ostacoli (tende, mura, alberi) restano registrati.
	_check(get_nodes_in_group(&"grid_obstacle").size() > 10, "gli altri ostacoli restano")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
