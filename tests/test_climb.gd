extends SceneTree
## Verifica l'arrampicata: un blocco alto (non scavalcabile) si scala e si scende dall'altra parte,
## l'animazione "climb_*" parte, le pareti restano invalicabili e il corridoio libero non cambia.
## Esecuzione: godot --headless --path . -s res://tests/test_climb.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	Quality.set_level(Quality.Level.HIGH)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var ulisse := get_first_node_in_group(&"player") as GridUnit

	var unreachable_before := grid.find_unreachable_cells(ulisse.cell).size()
	# Cerca tre caselle libere in fila (partenza, blocco, arrivo) e un blocco di prova.
	var found := false
	var from := Vector2i.ZERO
	var dir := Vector2i.RIGHT
	for y in range(2, grid.size.y - 2):
		for x in range(2, grid.size.x - 4):
			var c := Vector2i(x, y)
			if grid.is_walkable(c) and grid.is_walkable(c + dir) and grid.is_walkable(c + dir * 2) \
					and grid.step_allowed(c, c + dir) and grid.step_allowed(c + dir, c + dir * 2):
				from = c
				found = true
				break
		if found:
			break
	_check(found, "trovato un corridoio libero di tre caselle")
	var block := from + dir
	var landing := from + dir * 2

	# Blocco alto 1,6 m scalabile.
	grid.set_blocked(block, true)
	grid._vaultable[block] = false
	grid._climbable[block] = true
	grid._heights[block] = 1.6
	_check(grid.is_climbable(block) and not grid.is_vaultable(block), "il blocco alto è scalabile ma non scavalcabile")
	_check(grid.can_climb_over(from, dir) and not grid.can_vault_over(from, dir), "can_climb_over sì, can_vault_over no")

	ulisse.place_at(from)
	var base_y := ulisse.global_position.y
	var climbed_h := [0.0]
	ulisse.climbed.connect(func(_a, _b, h: float): climbed_h[0] = h)
	var peak := [0.0]
	_check(ulisse.try_step(dir), "Ulisse si arrampica sul blocco")
	var model := ulisse.get_node_or_null("Model") as CharacterModel
	var anim := &""
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < HumanoidAnims.CLIMB_TIME + 0.2:
		await process_frame
		peak[0] = maxf(peak[0], ulisse.global_position.y - base_y)
		if model and model.current_animation().begins_with("climb"):
			anim = model.current_animation()
	_check(is_equal_approx(climbed_h[0], 1.6), "segnale climbed con altezza 1,6 m")
	_check(peak[0] > 1.4, "sale fino in cima al blocco (%.2f m)" % peak[0])
	_check(ulisse.cell == landing and not ulisse.is_moving, "scende dall'altra parte, due caselle più in là")
	_check(absf(ulisse.global_position.y - base_y) < 0.4, "atterra a terra")
	_check(grid.get_occupant(landing) == ulisse and grid.get_occupant(from) == null, "la griglia segna la nuova casella")
	if model and model.tree:
		_check(String(anim).begins_with("climb"), "l'animazione di arrampicata è partita (%s)" % anim)

	# Senza can_climb, o con blocco più alto del limite (parete), resta bloccato.
	ulisse.place_at(from)
	ulisse.can_climb = false
	_check(not ulisse.try_step(dir), "con can_climb spento il blocco alto blocca")
	ulisse.can_climb = true
	grid._climbable[block] = false
	_check(not grid.can_climb_over(from, dir) and not ulisse.try_step(dir), "una parete non scalabile blocca")
	# Atterraggio occupato: niente arrampicata.
	grid._climbable[block] = true
	grid.set_blocked(landing, true)
	_check(not grid.can_climb_over(from, dir), "senza casella libera dall'altra parte non si scala")
	grid.set_blocked(landing, false)

	# L'arrampicata aggiunge solo passaggi: nessuna casella in più diventa irraggiungibile.
	grid.set_blocked(block, false)
	grid._climbable.erase(block)
	grid._heights.erase(block)
	grid._vaultable.erase(block)
	_check(grid.find_unreachable_cells(ulisse.cell).size() <= unreachable_before + 0, "il corridoio libero non cambia")

	# Le clip esistono per ogni altezza e hanno la durata di CLIMB_TIME.
	if model and model._lib:
		for i in HumanoidAnims.CLIP_CLIMB_HEIGHTS.size():
			var clip := HumanoidAnims.climb_clip(i)
			_check(model._lib.has_animation(clip) and absf(model._lib.get_animation(clip).length - HumanoidAnims.CLIMB_TIME) < 0.05, "clip %s presente" % clip)
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
