extends SceneTree
## Un ferito grave si porta come gli altri: Ulisse lo sorregge, nessuna squadra con la barella compare dal nulla.
## Esecuzione: godot --headless --path . -s res://tests/test_stretcher.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.duration = 300.0
	rules.first_wave_delay = 999.0
	rules.severe_wounded = 2
	director.rules = rules
	root.add_child(main)
	await create_timer(0.6).timeout
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	var w: WoundedSoldier = director.wounded[director.wounded.size() - 1]
	_check(w.severe, "l'ultimo ferito è grave")
	var before := get_nodes_in_group(&"achei").size()
	var near := w.cell + Vector2i(1, 1)
	if not grid.is_walkable(near):
		near = w.cell + Vector2i(-1, -1)
	ulisse.place_at(near)
	await create_timer(0.6).timeout
	_check(w.state == WoundedSoldier.State.FOLLOWING, "il ferito grave si rialza e segue Ulisse")
	_check(root.find_children("Stretcher*", "", true, false).is_empty(), "nessuna barella")
	_check(get_nodes_in_group(&"achei").size() == before, "nessun compagno compare dal nulla")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
