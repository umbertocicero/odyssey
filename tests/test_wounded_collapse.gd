extends SceneTree
## A wounded man who loses his supporter does not follow: he collapses to the ground (keeping his health,
## untouchable again) and can be raised again by Odysseus or picked up by a nearby free comrade.
## Run: godot --headless --path . -s res://tests/test_wounded_collapse.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.duration = 600.0
	rules.first_wave_delay = 999.0
	rules.ferry_sail_time = 1.0
	director.rules = rules
	root.add_child(main)
	await create_timer(0.8).timeout
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	for n in get_nodes_in_group(&"troiani"):
		if n.has_method(&"halt"):
			n.halt()
	var allies: Array[AllySoldier] = []
	for a in get_nodes_in_group(&"achei"):
		if a is AllySoldier:
			allies.append(a)
			(a as AllySoldier).busy = true   # nobody interferes for now
	var w: WoundedSoldier = director.wounded[0]
	var wm := w.get_node("Model") as CharacterModel
	for off in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if ulisse.place_at(w.cell + off):
			break
	await create_timer(2.8).timeout
	_check(w.state == WoundedSoldier.State.FOLLOWING, "Odysseus raises the wounded man")
	var half := w.health
	var spot := w.global_position
	# Odysseus runs off (far away).
	for dy in range(10, 0, -1):
		if ulisse.place_at(ulisse.cell + Vector2i(0, dy)) or ulisse.place_at(ulisse.cell + Vector2i(0, -dy)):
			break
	var t := 0.0
	while t < 5.0 and w.state != WoundedSoldier.State.LYING:
		await create_timer(0.1).timeout
		t += 0.1
	_check(w.state == WoundedSoldier.State.LYING, "he collapses instead of following (%.1f s)" % t)
	await create_timer(0.8).timeout
	_check(wm.dead, "he is down on the ground")
	_check(not w.is_targetable(), "lying again: untouchable")
	_check(w.health == half and w.raised_once, "he keeps his health (%d)" % w.health)
	_check(is_equal_approx(ulisse.speed_multiplier, 1.0), "Odysseus is free")
	_check(w.leader == null or w.leader == ulisse, "no supporter assigned while down")
	_check(w.global_position.distance_to(spot) < 6.0, "he stays near where he fell (%.1f m)" % w.global_position.distance_to(spot))
	# Odysseus comes back and raises him again.
	for off in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if ulisse.place_at(w.cell + off) and w._dist_xz(ulisse) <= 1.4:
			break
	await create_timer(2.8).timeout
	_check(w.state == WoundedSoldier.State.FOLLOWING and w.health == half, "Odysseus raises him again, health unchanged")
	# Collapse again, now a free comrade is close by: he picks the wounded man up and takes him away.
	for dy in range(10, 0, -1):
		if ulisse.place_at(ulisse.cell + Vector2i(0, dy)) or ulisse.place_at(ulisse.cell + Vector2i(0, -dy)):
			break
	t = 0.0
	while t < 5.0 and w.state != WoundedSoldier.State.LYING:
		await create_timer(0.1).timeout
		t += 0.1
	_check(w.state == WoundedSoldier.State.LYING, "second collapse")
	var mate := allies[0]
	mate.busy = false
	for off in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2)]:
		if mate.place_at(w.cell + off):
			break
	t = 0.0
	var states := {}
	w.state_changed.connect(func(n: int) -> void: states[n] = true)
	while t < 120.0 and w.state != WoundedSoldier.State.EVACUATED:
		await create_timer(0.5).timeout
		t += 0.5
	_check(states.has(WoundedSoldier.State.CARRIED), "a nearby comrade raises him and carries him")
	_check(w.state == WoundedSoldier.State.EVACUATED, "he is taken to the ships (%.0f s)" % t)
	print("RISULTATO: ", "OK" if _failures == 0 else "%d failed" % _failures)
	quit(0 if _failures == 0 else 1)
