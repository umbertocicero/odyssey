extends SceneTree
## Se un ferito muore (a terra, mentre cammina o in barella), gli altri vanno comunque
## raccolti e portati in salvo: niente blocchi nella coda.
## Esecuzione: godot --headless --path . -s res://tests/test_wounded_death.gd

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
	rules.severe_wounded = 0
	director.rules = rules
	root.add_child(main)
	await create_timer(0.6).timeout
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var camp := rules.camp_rect.position + Vector2i(2, 2)

	# 1) Muore il primo mentre Ulisse lo sorregge: Ulisse torna normale, il secondo si rialza.
	var a: WoundedSoldier = director.wounded[0]
	var b: WoundedSoldier = director.wounded[1]
	_near(ulisse, a)
	await create_timer(0.5).timeout
	_check(a.state == WoundedSoldier.State.FOLLOWING, "il primo ferito si rialza")
	a.take_damage(1000)
	await create_timer(0.3).timeout
	_check(a.state == WoundedSoldier.State.LOST, "il primo ferito muore e resta a terra")
	_check(is_equal_approx(ulisse.speed_multiplier, 1.0), "Ulisse torna a velocità normale dopo la morte")
	_near(ulisse, b)
	await create_timer(0.5).timeout
	_check(b.state == WoundedSoldier.State.FOLLOWING, "il secondo ferito si rialza dopo la morte del primo")
	ulisse.place_at(camp)
	b.place_at(camp + Vector2i(1, 0))
	await _wait_state(b, [WoundedSoldier.State.SAVED, WoundedSoldier.State.CARRIED, WoundedSoldier.State.EVACUATED], 5.0)
	_check(b.state in [WoundedSoldier.State.SAVED, WoundedSoldier.State.CARRIED, WoundedSoldier.State.EVACUATED], "il secondo arriva al campo")

	# 2) Un ferito a terra muore prima di essere raggiunto: il terzo si rialza lo stesso.
	var c: WoundedSoldier = director.wounded[2]
	var d: WoundedSoldier = director.wounded[3]
	c.take_damage(1000)
	await create_timer(0.2).timeout
	_near(ulisse, d)
	await create_timer(0.5).timeout
	_check(d.state == WoundedSoldier.State.FOLLOWING, "un ferito si rialza anche se un altro a terra è morto")

	# 3) Muore un ferito portato da un soldato alla barca: il soldato si libera e la coda va avanti.
	var e: WoundedSoldier = director.wounded[4]
	ulisse.place_at(camp)
	_near(ulisse, e)
	await create_timer(0.4).timeout
	ulisse.place_at(camp)
	e.place_at(camp + Vector2i(0, 1) if grid.is_walkable(camp + Vector2i(0, 1)) else camp + Vector2i(-1, 0))
	await _wait_state(e, [WoundedSoldier.State.CARRIED], 10.0)
	if e.state == WoundedSoldier.State.CARRIED:
		e.take_damage(1000)
		await create_timer(0.8).timeout
	var busy := 0
	for n in get_nodes_in_group(&"achei"):
		if n is AllySoldier and (n as AllySoldier).busy:
			busy += 1
	var t := 0.0
	while t < 60.0 and director.evacuated_count() < 2:
		await create_timer(0.5).timeout
		t += 0.5
	_check(director.evacuated_count() >= 2, "la coda di evacuazione prosegue dopo una morte (%d imbarcati)" % director.evacuated_count())
	await create_timer(0.5).timeout
	busy = 0
	for n in get_nodes_in_group(&"achei"):
		if n is AllySoldier and (n as AllySoldier).busy:
			busy += 1
	_check(busy == 0, "nessun soldato resta bloccato nel soccorso (%d occupati)" % busy)
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)


func _near(ulisse: GridUnit, w: WoundedSoldier) -> void:
	for dd in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(1, -1)]:
		if ulisse.place_at(w.cell + dd):
			return


func _wait_state(w: WoundedSoldier, states: Array, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not (w.state in states):
		await create_timer(0.2).timeout
		t += 0.2
