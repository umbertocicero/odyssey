extends SceneTree
## Wounded: untouchable while lying; once helped up they start at half health, can be targeted and can die.
## Run: godot --headless --path . -s res://tests/test_wounded_death.gd

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
	rules.severe_wounded = 0
	director.rules = rules
	root.add_child(main)
	await create_timer(0.6).timeout
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var a: WoundedSoldier = director.wounded[0]
	var maxhp := a.health

	# Lying
	a.take_damage(1000)
	_check(a.health == maxhp and a.state == WoundedSoldier.State.LYING, "lying wounded ignores damage")
	_check(not a.is_targetable(), "lying wounded is not targetable")

	# Fire / explosion style hits on the wounded's cell never hurt
	for n in get_nodes_in_group(&"wall_shooters"):
		var ws := n as WallShooter
		ws.grid = get_first_node_in_group(&"diorama_grid") as DioramaGrid
		ws._on_impact([a.cell] as Array[Vector2i])
		_check(ws.pick_target() != a, "wall shooters never pick a wounded man")
	_check(a.health == maxhp, "siege/arrow impacts on the wounded's cell do nothing")

	# Helped up by Odysseus: half health, now targetable and killable.
	for dd in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if ulisse.place_at(a.cell + dd):
			break
	await create_timer(1.0).timeout
	_check(a.state == WoundedSoldier.State.LYING and not a.is_targetable(), "while being helped up he is still untouchable")
	await create_timer(1.8).timeout
	_check(a.state == WoundedSoldier.State.FOLLOWING, "wounded gets up with Odysseus")
	_check(a.health == maxi(a.max_health / 2, 1), "he starts at half health (%d/%d)" % [a.health, a.max_health])
	_check(a.is_targetable(), "once raised he can be targeted")
	var half := a.health
	a.take_damage(5)
	_check(a.health == half - 5, "a raised wounded man takes damage")
	a.take_damage(1000)
	await create_timer(0.3).timeout
	_check(a.state == WoundedSoldier.State.LOST, "he can die after being raised")
	_check(is_equal_approx(ulisse.speed_multiplier, 1.0), "Odysseus is free again after his death")
	_check(director.lost_count() == 1, "the dead wounded man counts as lost")

	print("RISULTATO: ", "OK" if _failures == 0 else "%d failed" % _failures)
	quit(0 if _failures == 0 else 1)
