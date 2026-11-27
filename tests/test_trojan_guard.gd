extends SceneTree
## Test headless dell'IA di guardia troiana: all'avvio attivi in guardia, avvistamento, inseguimento,
## ritorno alla postazione, rinforzi dalla porta.
## Avvio: godot --headless --path . -s res://tests/test_trojan_guard.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 500.0
	rules.wave_interval = 100.0
	director.rules = rules
	root.add_child(main)
	await create_timer(0.5).timeout
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	for a in get_nodes_in_group(&"achei"):
		if a != ulisse and "leader" in a:
			a.leader = null
	var guards: Array = get_nodes_in_group(&"troiani").filter(func(u): return u is TrojanSoldier)
	_check(guards.size() >= 8, "i soldati iniziali sono TrojanSoldier attivi (%d)" % guards.size())
	var facings := {}
	for g in guards:
		facings[g.facing] = true
		_check(g.state == TrojanSoldier.State.GUARD, "%s è di guardia" % g.name)
	_check(facings.size() >= 2, "orientamenti vari (%d direzioni)" % facings.size())

	# Avvistamento: Ulisse davanti a un soldato.
	var g: TrojanSoldier = guards[0]
	g._halted = false
	var spot := g.cell + g.facing * 5
	var found := false
	for r in range(3, 7):
		spot = g.cell + g.facing * r
		if grid.is_walkable(spot) and ulisse.place_at(spot):
			found = true
			break
	_check(found, "Ulisse piazzato davanti al soldato")
	await create_timer(1.0).timeout
	_check(g.state == TrojanSoldier.State.CHASE, "il soldato vede Ulisse e passa all'inseguimento")
	var d0 := Vector2(g.cell - ulisse.cell).length()
	await create_timer(3.0).timeout
	_check(Vector2(g.cell - ulisse.cell).length() < d0 or g.health > 0, "il soldato si avvicina")

	# Fuori vista: torna alla postazione.
	var far := Vector2i(3, 38)
	for dx in 8:
		if grid.is_walkable(far + Vector2i(dx, 0)):
			far += Vector2i(dx, 0)
			break
	ulisse.place_at(far)
	for a in get_nodes_in_group(&"achei"):
		if a != ulisse and a is GridUnit and a.health > 0 and not a is WoundedSoldier:
			(a as GridUnit).place_at(far + Vector2i(0, -1)) if grid.is_walkable(far + Vector2i(0, -1)) else null
	g.place_at(g.post_cell + Vector2i(1, 0) if grid.is_walkable(g.post_cell + Vector2i(1, 0)) else g.post_cell)
	g._alert(ulisse, false)
	g._last_seen = g.cell   # l'ha visto qui, poi Ulisse è sparito
	for i in 20:
		await create_timer(1.0).timeout
		if g.state != TrojanSoldier.State.CHASE:
			break
		print("  t=%d state=%d cell=%s post=%s ulisse=%s lost=%.1f" % [i, g.state, g.cell, g.post_cell, ulisse.cell, g._lost_timer])
	_check(g.state != TrojanSoldier.State.CHASE, "perso il bersaglio, smette di inseguire (stato %d)" % g.state)

	# Rinforzi dalle portine laterali.
	var before := get_nodes_in_group(&"troiani").size()
	director._start_wave()
	await create_timer(1.3).timeout
	var fresh: Array = get_nodes_in_group(&"troiani").filter(func(u): return u.name.begins_with("TrojanWave"))
	_check(fresh.size() >= 1, "un rinforzo è uscito")
	var doors := get_nodes_in_group(&"troy_gates").filter(func(d): return d.is_open)
	_check(not doors.is_empty(), "almeno una portina si è aperta (%d)" % doors.size())
	if not fresh.is_empty():
		var u: TrojanSoldier = fresh[0]
		_check(u.global_position.z < -19.5, "il rinforzo sta ancora attraversando il varco (z=%.2f)" % u.global_position.z)
		_check(u.state == TrojanSoldier.State.RETURN, "poi cammina alla postazione")
		var near_door := false
		for d in doors:
			if absf(d.global_position.x - u.global_position.x) < 1.5:
				near_door = true
		_check(near_door, "esce proprio da una portina aperta")
	await create_timer(3.0).timeout
	_check(get_nodes_in_group(&"troiani").size() > before + 1, "i rinforzi escono in fila")
	print("FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)
