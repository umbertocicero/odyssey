extends SceneTree
## Verifica il gioco del livello 1: ondate, feriti, salvataggio, punteggio, fine livello.
## Esecuzione: godot --headless --path . -s res://tests/test_gameplay.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.duration = 14.0
	rules.first_wave_delay = 1.0
	rules.wave_interval = 5.0
	director.rules = rules
	director.auto_start = true
	root.add_child(main)
	await create_timer(0.5).timeout
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var ulisse := get_first_node_in_group(&"player") as GridUnit

	_check(director.phase == LevelDirector.Phase.RUNNING, "il livello parte da solo")
	_check(director.wounded.size() == rules.wounded_count, "ci sono %d feriti sparsi (trovati %d)" % [rules.wounded_count, director.wounded.size()])
	_check(director.hud != null, "esiste l'interfaccia del livello")
	for w in director.wounded:
		if w.state != WoundedSoldier.State.LYING:
			_check(false, "all'inizio tutti i feriti giacciono a terra")
			break
	var w0: WoundedSoldier = director.wounded[0]
	_check(w0._model_node.dead and w0._model_node.current_animation() != &"idle", "il modello del ferito è sdraiato (non in idle)")

	# Difese e ondate.
	for node in get_nodes_in_group(&"wall_shooters"):
		(node as WallShooter).auto_fire = false   # niente frecce durante il test
	await create_timer(1.5).timeout
	_check(director.wave == 1, "la prima ondata parte (ondata %d)" % director.wave)
	var t1 := director.alive_trojans()
	_check(t1 >= rules.trojans_in_wave(1), "i troiani dell'ondata 1 sono comparsi (%d vivi)" % t1)
	director._start_wave()
	_check(rules.trojans_in_wave(3) > rules.trojans_in_wave(1) and rules.health_in_wave(3) > rules.health_in_wave(1), "le ondate successive sono più forti")
	var shooters := get_nodes_in_group(&"wall_shooters")
	_check((shooters[0] as WallShooter).reload_scale > 1.0, "le difese sulle mura tirano più spesso (x%.2f)" % (shooters[0] as WallShooter).reload_scale)

	# Ulisse colpisce un troiano accanto.
	var trojan: TrojanSoldier
	for n in get_nodes_in_group(&"troiani"):
		if n is TrojanSoldier:
			trojan = n
			break
	_check(trojan != null, "c'è almeno un TrojanSoldier")
	var hp := trojan.health
	var free_cell := Vector2i(-1, -1)
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if grid.is_walkable(trojan.cell + d):
			free_cell = trojan.cell + d
			break
	trojan._halted = true
	ulisse.place_at(free_cell)
	ulisse.face(trojan.cell - ulisse.cell)
	# Il colpo arriva all'impatto della lama (0,22 s) e il troiano può schivare: si riprova qualche volta.
	for attempt in 6:
		ulisse._attack_cd = 0.0
		ulisse._melee_attack()
		await create_timer(0.9).timeout
		if trojan.health < hp:
			break
	_check(trojan.health < hp, "Ulisse colpisce il troiano davanti (vita %d -> %d)" % [hp, trojan.health])
	var kills_before := director.kills
	trojan.take_damage(1000)
	_check(director.kills == kills_before + 1, "un troiano ucciso viene contato")
	for n in get_nodes_in_group(&"troiani"):
		if n is TrojanSoldier:
			(n as TrojanSoldier).halt()
	director._next_wave_at = INF   # nessuna altra ondata: i conteggi restano deterministici

	# Salvataggio di un ferito.
	var w: WoundedSoldier = director.wounded[0]
	var spot := Vector2i(-1, -1)
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if grid.is_walkable(w.cell + d):
			spot = w.cell + d
			break
	ulisse.place_at(spot)
	await create_timer(2.6).timeout
	_check(w.state == WoundedSoldier.State.FOLLOWING, "avvicinandosi, il ferito si rialza e segue Ulisse")
	var camp := director.rules.camp_rect
	var camp_cell := camp.position + Vector2i(2, 2)
	ulisse.place_at(camp_cell)
	w.place_at(camp_cell + Vector2i(1, 0) if grid.is_walkable(camp_cell + Vector2i(1, 0)) else camp_cell + Vector2i(0, 1))
	await create_timer(0.4).timeout
	_check(w.state in [WoundedSoldier.State.SAVED, WoundedSoldier.State.CARRIED, WoundedSoldier.State.EVACUATED], "arrivato all'accampamento, il ferito è in salvo (poi lo portano alle barche)")
	_check(director.saved_count() == 1, "il contatore dei salvati sale a 1")

	# Enemies cannot kill a wounded man who is still lying.
	var w2: WoundedSoldier = director.wounded[1]
	w2.take_damage(1000)
	await process_frame
	_check(w2.state != WoundedSoldier.State.LOST and w2.health > 0 and director.lost_count() == 0, "a lying wounded man cannot be killed")

	# Fine del livello.
	var done := [false]
	director.level_finished.connect(func(_s): done[0] = true)
	await create_timer(rules.duration + 1.0).timeout
	_check(done[0] and director.phase == LevelDirector.Phase.ENDED, "al segnale di ritirata il livello finisce")
	var s := director.summary
	_check(int(s["saved"]) == 1 and int(s["lost"]) == 0, "il riepilogo conta salvati e persi (%d salvati, %d persi)" % [int(s["saved"]), int(s["lost"])])
	_check(int(s["score"]) == rules.score_for(1, director.kills, director.wounded.size()), "punteggio = %d" % int(s["score"]))
	_check(not bool(s["orderly"]), "1 salvato su %d: ritirata disperata" % director.wounded.size())
	_check(director.hud.end_panel_visible(), "compare la schermata finale")
	_check(ResourceLoader.exists(director.next_level_path), "esiste la scena del livello 2")

	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
