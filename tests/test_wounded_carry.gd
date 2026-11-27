extends SceneTree
## Feriti: risveglio anche in diagonale/sopra, trasporto lento, evacuazione con barca.
## Esecuzione: godot --headless --path . -s res://tests/test_wounded_carry.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.duration = 200.0
	rules.first_wave_delay = 999.0
	rules.ferry_sail_time = 1.0
	director.rules = rules
	root.add_child(main)
	await create_timer(0.6).timeout
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	var w: WoundedSoldier = director.wounded[0]
	_check(w.find_child("WoundedLook", true, false) == null, "nessuna benda generata da codice (le bende sono nella texture dei modelli)")

	# Ulisse in diagonale (Manhattan 2) deve svegliarlo; prima no.
	var diag := w.cell + Vector2i(1, 1)
	if not grid.is_walkable(diag):
		diag = w.cell + Vector2i(-1, -1)
	ulisse.place_at(diag)
	await create_timer(0.3).timeout
	_check(w.state == WoundedSoldier.State.LYING and w._helping, "Ulisse si china ad aiutarlo: il ferito resta a terra, non si alza da solo")
	await create_timer(2.4).timeout
	_check(w.state == WoundedSoldier.State.FOLLOWING, "in diagonale Ulisse lo aiuta a rialzarsi e il ferito lo segue")
	for a in get_nodes_in_group(&"achei"):
		if a is AllySoldier:
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(3, 0)]:
				if (a as AllySoldier).place_at(ulisse.cell + d):
					break
			break
	await create_timer(0.6).timeout
	var near_ally := false
	for a in get_nodes_in_group(&"achei"):
		if a is AllySoldier and (a as AllySoldier).global_position.distance_to(ulisse.global_position) < w.helper_range:
			near_ally = true
	_check(near_ally and is_equal_approx(ulisse.speed_multiplier, 0.70), "velocità col ferito: %.2f (compagno vicino: %s)" % [ulisse.speed_multiplier, near_ally])
	# Compagni lontani o morti: Ulisse prosegue da solo al 55%.
	for a in get_nodes_in_group(&"achei"):
		if a is AllySoldier:
			(a as AllySoldier).health = 0
	await create_timer(0.6).timeout
	_check(is_equal_approx(ulisse.speed_multiplier, 0.55), "senza compagni va al 55%% (%.2f)" % ulisse.speed_multiplier)
	var troj := TrojanSoldier.new()
	troj.free()
	ulisse._attack_cd = 0.0
	ulisse._melee_attack()
	_check(ulisse._attack_cd > 0.0, "Ulisse può attaccare mentre sorregge il ferito")
	for a in get_nodes_in_group(&"achei"):
		if a is AllySoldier:
			(a as AllySoldier).health = (a as AllySoldier).max_health

	# Ulisse cammina: il ferito resta dietro, a distanza ravvicinata.
	var start := ulisse.global_position
	for i in 20:
		ulisse.place_at(ulisse.cell + Vector2i(0, 1) if grid.is_walkable(ulisse.cell + Vector2i(0, 1)) else ulisse.cell)
		await create_timer(0.1).timeout
	var d := Vector2(ulisse.global_position.x - w.global_position.x, ulisse.global_position.z - w.global_position.z).length()
	_check(d < 2.5, "il ferito segue Ulisse da vicino (%.2f m)" % d)

	# In accampamento: in salvo, Ulisse non è più rallentato, un alleato lo porta alla barca.
	var camp := rules.camp_rect
	var cc := camp.position + Vector2i(2, 2)
	ulisse.place_at(cc)
	w.place_at(cc + Vector2i(1, 0))
	await create_timer(0.4).timeout
	_check(w.state in [WoundedSoldier.State.SAVED, WoundedSoldier.State.CARRIED], "arrivato all'accampamento è in salvo")
	_check(is_equal_approx(ulisse.speed_multiplier, 1.0), "Ulisse torna a velocità normale")
	var bearer_found := false
	var t := 0.0
	while t < 90.0 and director.evacuated_count() < 1:
		await create_timer(0.5).timeout
		t += 0.5
		for a in get_nodes_in_group(&"achei"):
			if a is AllySoldier and (a as AllySoldier).busy:
				bearer_found = true
	_check(bearer_found, "un soldato alleato si occupa del ferito")
	_check(director.evacuated_count() == 1, "il ferito è stato portato alla nave (%.0f s)" % t)
	_check(w.state == WoundedSoldier.State.EVACUATED, "stato imbarcato")
	for a in get_nodes_in_group(&"achei"):
		if a is AllySoldier:
			_check(not (a as AllySoldier).busy, "il soldato è di nuovo libero")
			break
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
