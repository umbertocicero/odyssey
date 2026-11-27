extends SceneTree
## Alleati: niente sciame dietro Ulisse; ingaggiano i troiani in vista chiamando in aiuto pochi compagni vicini,
## poi tornano al posto; se Ulisse si stacca il ferito continua col compagno affiancato.
## Esecuzione: godot --headless --path . -s res://tests/test_ally_guard.gd

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
		if a is AllySoldier and (a as AllySoldier).leader == null:
			allies.append(a)
	_check(allies.size() >= 4, "ci sono alleati liberi (%d)" % allies.size())
	var posts := {}
	for a in allies:
		posts[a] = a.cell
	# 1) Ulisse si allontana: gli alleati restano ai loro posti.
	var far := ulisse.cell + Vector2i(0, 8)
	for dy in range(8, 0, -1):
		if ulisse.place_at(ulisse.cell + Vector2i(0, dy)):
			break
	await create_timer(5.0).timeout
	var moved := 0
	for a in allies:
		if a.cell != posts[a]:
			moved += 1
	_check(moved == 0, "gli alleati non seguono Ulisse (%d spostati)" % moved)
	# 2) Un troiano compare vicino al primo alleato: lo ingaggia, ne accorrono al più max_responders.
	var a0 := allies[0]
	var tcell := a0.cell + Vector2i(5, 0)
	var placed := false
	for off in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 5), Vector2i(0, -5), Vector2i(4, 2), Vector2i(-4, 2)]:
		if grid.is_walkable(a0.cell + off) and grid.get_occupant(a0.cell + off) == null:
			tcell = a0.cell + off
			placed = true
			break
	_check(placed, "casella libera per il nemico")
	var troj := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 400, "TestTrojan") as TrojanSoldier
	troj.position = grid.cell_to_world(tcell)
	allies[0].get_parent().add_child(troj)
	troj.halt()
	await create_timer(1.5).timeout
	var engaged := 0
	var away_from_post := 0
	for a in allies:
		if a.target == troj:
			engaged += 1
		if a.cell != posts[a]:
			away_from_post += 1
	_check(a0.target == troj, "l'alleato vicino ingaggia il nemico")
	_check(engaged >= 2 and engaged <= 1 + a0.max_responders, "accorrono pochi compagni (%d ingaggiati)" % engaged)
	_check(engaged < allies.size(), "non accorrono tutti (%d su %d)" % [engaged, allies.size()])
	# Il nemico muore: tutti tornano al posto.
	troj.take_damage(100000)
	await create_timer(12.0).timeout
	var back := 0
	for a in allies:
		if a.cell == posts[a] or Vector2(a.cell - posts[a]).length() <= 1.5:
			back += 1
	_check(back == allies.size(), "dopo lo scontro tornano ai loro posti (%d/%d)" % [back, allies.size()])
	# 3) Distacco di Ulisse: il ferito continua con il compagno affiancato.
	var w: WoundedSoldier = director.wounded[0]
	var mate := allies[allies.size() - 1]
	for off in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if ulisse.place_at(w.cell + off):
			break
	await create_timer(2.8).timeout
	_check(w.state == WoundedSoldier.State.FOLLOWING, "il ferito è sorretto da Ulisse")
	mate.place_at(w.cell + Vector2i(2, 0)) if grid.is_walkable(w.cell + Vector2i(2, 0)) else mate.place_at(w.cell + Vector2i(-2, 0))
	var t := 0.0
	while t < 8.0 and not w._helper_joined:
		await create_timer(0.1).timeout
		t += 0.1
	_check(w._helper_joined, "il compagno si affianca (%.1f s)" % t)
	var wm := w.get_node("Model") as CharacterModel
	var fell := false
	for dy in range(8, 0, -1):
		if ulisse.place_at(ulisse.cell + Vector2i(0, dy)) or ulisse.place_at(ulisse.cell + Vector2i(0, -dy)):
			break
	t = 0.0
	while t < 4.0 and w.state != WoundedSoldier.State.CARRIED:
		await create_timer(0.1).timeout
		t += 0.1
		fell = fell or wm.dead
	print("dbg ", w.state, " joined ", w._helper_joined, " dist ", w._dist_xz(ulisse), " jobs ", director.ferry.jobs.size(), " helper ", w.helper, " ul ", ulisse.global_position, " w ", w.global_position)
	_check(w.state == WoundedSoldier.State.CARRIED and w.leader is AllySoldier, "Ulisse si stacca: il compagno prosegue col ferito (%.1f s)" % t)
	_check(not fell, "il ferito non cade né si sdraia nel passaggio")
	_check(is_equal_approx(ulisse.speed_multiplier, 1.0), "Ulisse è libero")
	t = 0.0
	while t < 120.0 and w.state != WoundedSoldier.State.EVACUATED:
		await create_timer(0.5).timeout
		t += 0.5
	_check(w.state == WoundedSoldier.State.EVACUATED, "il compagno lo porta fino alla nave (%.0f s)" % t)
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
