extends SceneTree
## Il ferito che cammina viene portato a piedi, fianco a fianco: da solo con Ulisse (braccio attorno al
## suo collo), poi con un compagno incontrato per strada che si affianca (ferito al centro, braccia attorno
## a entrambi). Nessun soldato compare dal nulla e la barella non c'è. All'accampamento il compagno si libera.
## Esecuzione: godot --headless --path . -s res://tests/test_wounded_handover.gd

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
	var w: WoundedSoldier = director.wounded[0]
	var wm := w.get_node("Model") as CharacterModel
	var allies: Array[AllySoldier] = []
	for a in get_nodes_in_group(&"achei"):
		if a is AllySoldier:
			allies.append(a)
	var mate := allies[0]
	for i in range(1, allies.size()):
		allies[i].busy = true   # fuori gioco finché serve
	var before := get_nodes_in_group(&"achei").size()
	var diag := w.cell + Vector2i(1, 1)
	if not grid.is_walkable(diag):
		diag = w.cell + Vector2i(-1, -1)
	ulisse.place_at(diag)
	await create_timer(0.5).timeout
	_check(w.state == WoundedSoldier.State.FOLLOWING, "il ferito si alza e segue Ulisse")
	_check(wm.stance == &"limp_l", "da solo con Ulisse: braccio attorno al suo collo (%s)" % wm.stance)
	var um := ulisse.get_node("Model") as CharacterModel
	_check(um.stance == &"carry_r", "Ulisse lo sorregge per la vita (%s)" % um.stance)
	# Un compagno si trova a pochi metri: viene ad affiancarsi.
	# (in linea retta libera dal ferito, perché i soldati si muovono a passi golosi sugli assi)
	var placed := false
	for dist in [4, 3, 2]:
	 for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var clear := true
		for k in range(1, dist + 1):
			var c: Vector2i = w.cell + dir * k
			if not grid.is_walkable(c) or c == ulisse.cell:
				clear = false
				break
		if clear and mate.place_at(w.cell + dir * dist):
			placed = true
			break
	 if placed:
		break
	_check(placed, "compagno posizionato in linea libera")
	var joined := false
	var fell := false
	var t := 0.0
	while t < 12.0 and not joined:
		await create_timer(0.1).timeout
		t += 0.1
		fell = fell or wm.dead
		joined = w._helper_joined
	_check(joined, "il compagno si affianca (%.1f s)" % t)
	_check(not fell, "il ferito non si sdraia")
	_check(w.state == WoundedSoldier.State.FOLLOWING and w.leader == ulisse, "Ulisse resta a sorreggerlo")
	_check(mate.busy, "il compagno è impegnato col ferito")
	await create_timer(1.5).timeout
	_check(wm.stance == &"limp_lr", "ferito al centro, braccia attorno a entrambi (%s)" % wm.stance)
	var mm := mate.get_node("Model") as CharacterModel
	_check(mm.stance == &"carry_l", "il compagno lo sorregge per la vita (%s)" % mm.stance)
	var dw := Vector2(w.global_position.x - ulisse.global_position.x, w.global_position.z - ulisse.global_position.z).length()
	var dm := Vector2(mate.global_position.x - w.global_position.x, mate.global_position.z - w.global_position.z).length()
	_check(dw < 0.9 and dm < 0.9, "i tre camminano fianco a fianco (%.2f e %.2f m)" % [dw, dm])
	_check(get_nodes_in_group(&"achei").size() == before, "nessun soldato è comparso dal nulla")
	_check(get_nodes_in_group(&"stretcher").is_empty() and root.find_children("Stretcher*", "", true, false).is_empty(), "nessuna barella")
	# Ulisse lo porta all'accampamento (a piedi, in teletrasporto della posizione): il compagno si libera.
	var camp := director.rules.camp_rect
	ulisse.place_at(camp.position + camp.size / 2)
	t = 0.0
	while t < 40.0 and w.state == WoundedSoldier.State.FOLLOWING:
		await create_timer(0.1).timeout
		t += 0.1
	_check(w.state == WoundedSoldier.State.SAVED or w.state == WoundedSoldier.State.CARRIED or w.state == WoundedSoldier.State.EVACUATED, "arrivato all'accampamento (%.1f s)" % t)
	_check(is_equal_approx(ulisse.speed_multiplier, 1.0), "Ulisse torna a velocità normale")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
