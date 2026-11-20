extends SceneTree
## Verifica che gli ostacoli bassi si scavalchino e quelli alti no, e che il prato sia fitto.
## Esecuzione: godot --headless --path . -s res://tests/test_vault.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	Quality.set_level(Quality.Level.HIGH)
	TerrainStyle.set_photo(false)  # prova il vecchio prato procedurale (GrassField)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

	# Cerca un ostacolo basso con casella libera prima e dopo, e uno alto.
	var low_from := Vector2i(-1, -1)
	var low_dir := Vector2i.ZERO
	var high_from := Vector2i(-1, -1)
	var high_dir := Vector2i.ZERO
	var low_count := 0
	var high_count := 0
	for y in grid.size.y:
		for x in grid.size.x:
			var c := Vector2i(x, y)
			if not grid.is_blocked(c):
				continue
			if grid.is_vaultable(c):
				low_count += 1
			else:
				high_count += 1
			for d in dirs:
				var before := c - d
				var after := c + d
				if not grid.is_walkable(before) or not grid.is_walkable(after):
					continue
				if grid.is_vaultable(c) and low_from.x < 0 and grid.can_vault_over(before, d):
					low_from = before
					low_dir = d
				elif not grid.is_vaultable(c) and high_from.x < 0 and not grid.can_vault_over(before, d):
					high_from = before
					high_dir = d
	print("INFO  ostacoli bassi: ", low_count, ", alti: ", high_count)
	_check(low_count > 0, "ci sono ostacoli bassi scavalcabili")
	_check(high_count > 0, "restano ostacoli alti non scavalcabili")
	_check(low_from.x >= 0, "trovato un ostacolo basso con spazio per atterrare")

	# Scavalcamento di un ostacolo basso.
	ulisse.place_at(low_from)
	var start_cell := ulisse.cell
	var peak := [0.0]
	var base_y: float = ulisse.global_position.y
	ulisse.vaulted.connect(func(_a, _b): pass)
	var ok := ulisse.try_step(low_dir)
	_check(ok, "Ulisse scavalca l'ostacolo basso davanti a lui")
	for i in 20:
		await process_frame
		peak[0] = maxf(peak[0], ulisse.global_position.y - base_y)
	_check(peak[0] > 0.3, "il balzo ha un arco (altezza %.2f m)" % peak[0])
	await create_timer(ulisse.vault_duration).timeout
	_check(ulisse.cell == start_cell + low_dir * 2 and not ulisse.is_moving, "atterra due caselle più in là, oltre l'ostacolo")
	_check(grid.get_occupant(ulisse.cell) == ulisse and grid.get_occupant(start_cell) == null, "la griglia segna la nuova casella")

	# Ostacolo alto: non si passa.
	if high_from.x >= 0:
		ulisse.place_at(high_from)
		_check(not ulisse.try_step(high_dir), "un ostacolo alto (muro, tenda, albero) blocca")

	# Un'unità che non scavalca resta bloccata dall'ostacolo basso.
	ulisse.place_at(low_from)
	ulisse.can_vault = false
	_check(not ulisse.try_step(low_dir), "con can_vault spento l'ostacolo blocca")
	ulisse.can_vault = true

	# Prato fitto su tutto il piano, alto circa 20 cm.
	var level := main.get_node("GameView/GameViewport/Level1")
	var grass := level.get_node("ErbaMossa") as GrassField
	_check(grass.multimesh_instance.multimesh.instance_count >= 8000, "prato fitto: %d ciuffi" % grass.multimesh_instance.multimesh.instance_count)
	_check(absf(grass.blade_height - 0.2) < 0.05, "il prato è alto circa 20 cm (%.2f m)" % grass.blade_height)
	_check(level.get_node_or_null("Cespugli") != null, "ci sono i cespugli (non ostacoli)")
	_check(grass.area_size.x >= 40 and grass.area_size.y >= 40, "il prato copre tutto il piano")

	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
