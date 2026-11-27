extends SceneTree
## Un ferito grave portato da Ulisse nell'accampamento (anche dalla spiaggia) viene preso da un compagno e imbarcato.
## Esecuzione: godot --headless --path . -s res://tests/test_severe_camp_pickup.gd

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
	rules.ferry_sail_time = 1.0
	director.rules = rules
	root.add_child(main)
	await create_timer(0.6).timeout
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	var w: WoundedSoldier = director.wounded[director.wounded.size() - 1]
	_check(w.severe, "l'ultimo ferito è grave")
	for off in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if ulisse.place_at(w.cell + off):
			break
	await create_timer(2.8).timeout
	_check(w.state in [WoundedSoldier.State.FOLLOWING, WoundedSoldier.State.CARRIED], "Ulisse lo aiuta a rialzarsi (%d)" % w.state)
	var camp := rules.camp_rect
	var cc := camp.position + Vector2i(2, 2)
	ulisse.place_at(cc)
	w.place_at(cc + Vector2i(1, 0))
	var t := 0.0
	var taken := false
	while t < 90.0 and w.state != WoundedSoldier.State.EVACUATED:
		await create_timer(0.5).timeout
		t += 0.5
		for a in get_nodes_in_group(&"achei"):
			if a is AllySoldier and (a as AllySoldier).busy:
				taken = true
	_check(taken, "un compagno va a prenderlo nel campo")
	_check(w.state == WoundedSoldier.State.EVACUATED, "imbarcato (%.0f s)" % t)
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
