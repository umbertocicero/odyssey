extends SceneTree
## Ferito grave: Ulisse si avvicina, quattro soldati portano la barella al campo e poi alla barca.
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
	rules.ferry_sail_time = 1.0
	rules.severe_wounded = 2
	director.rules = rules
	root.add_child(main)
	await create_timer(0.6).timeout
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var w: WoundedSoldier = director.wounded[director.wounded.size() - 1]
	_check(w.severe, "gli ultimi feriti sono gravi")
	var light: WoundedSoldier = director.wounded[0]
	_check(not light.severe, "il primo ferito è leggero")
	for d in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(1, -1)]:
		if ulisse.place_at(w.cell + d):
			break
	await create_timer(0.4).timeout
	_check(w.state == WoundedSoldier.State.STRETCHER, "il ferito grave non si rialza: arriva la barella")
	var crew := 0
	for n in get_nodes_in_group(&"achei"):
		if str(n.name).begins_with("StretcherBearer"):
			crew += 1
	_check(crew == 4, "quattro soldati portano la barella (%d)" % crew)
	var t := 0.0
	while t < 150.0 and w.state != WoundedSoldier.State.SAVED and w.state != WoundedSoldier.State.EVACUATED:
		await create_timer(0.5).timeout
		t += 0.5
	_check(w.state == WoundedSoldier.State.SAVED or w.state == WoundedSoldier.State.EVACUATED, "la barella arriva all'accampamento (%.0f s)" % t)
	_check(director.saved_count() == 1, "conta come salvato")
	while t < 300.0 and director.evacuated_count() < 1:
		await create_timer(0.5).timeout
		t += 0.5
	_check(director.evacuated_count() == 1, "la barella è portata alla nave (%.0f s)" % t)
	_check(w.state == WoundedSoldier.State.EVACUATED, "stato imbarcato")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
