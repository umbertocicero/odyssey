extends SceneTree
## Test headless del movimento a griglia.
## Avvio: godot --headless --path . -s res://tests/test_grid_movement.gd
## Esce con codice 0 se tutti i controlli passano, 1 altrimenti.

const LEVEL_PATH := "res://scenes/levels/level1/level1.tscn"
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load(LEVEL_PATH).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame

	var grid = get_first_node_in_group(&"diorama_grid")
	var ulisse = get_first_node_in_group(&"player")
	_check(grid != null and ulisse != null, "griglia e Ulisse presenti")
	if grid == null or ulisse == null:
		quit(1)
		return
	# Le difese sulle mura hanno un loro test: qui non devono disturbare.
	for shooter in get_nodes_in_group(&"wall_shooters"):
		shooter.auto_fire = false

	# 1. Nessuna casella chiusa dagli ostacoli.
	var unreachable: Array = grid.find_unreachable_cells(ulisse.cell)
	_check(unreachable.is_empty(), "nessuna casella irraggiungibile (trovate: %s)" % [unreachable])

	# 2. Ulisse circondato da alleati: deve potersi muovere scambiandosi di posto.
	var allies: Array = get_nodes_in_group(&"achei").filter(func(u): return u != ulisse)
	for ally in allies:
		ally.leader = null # niente inseguimento durante questo controllo
	await create_timer(0.5).timeout # lascia finire i passi in corso
	var center := _find_open_cell(grid)
	_check(center != Vector2i(-1, -1), "trovata una casella con 4 vicini liberi")
	ulisse.place_at(center)
	var around: Array[Vector2i] = []
	for d in DIRECTIONS:
		around.append(center + d)
	for i in mini(allies.size(), around.size()):
		_free_cell(grid, around[i], ulisse)
		allies[i].place_at(around[i])
	var first_ally = allies[0]
	var ok: bool = ulisse.try_step(around[0] - center)
	await create_timer(0.6).timeout
	_check(ok and ulisse.cell == around[0] and first_ally.cell == center,
		"scambio di posto con un alleato (Ulisse %s, alleato %s)" % [ulisse.cell, first_ally.cell])

	# 3. Passeggiata casuale con gli alleati che seguono: Ulisse ha sempre
	#    almeno una mossa possibile verso caselle non occupate da nemici.
	for ally in allies:
		ally.leader = ulisse
	Engine.time_scale = 6.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var stuck_checks := 0
	for step in 150:
		var possible := DIRECTIONS.filter(func(d): return ulisse.can_enter(ulisse.cell + d))
		if possible.is_empty():
			# Un alleato a metà passo non si può scambiare: riprova poco dopo.
			await create_timer(0.25).timeout
			possible = DIRECTIONS.filter(func(d): return ulisse.can_enter(ulisse.cell + d))
			if possible.is_empty() and not _surrounded_by_enemies_or_walls(grid, ulisse):
				stuck_checks += 1
		if not possible.is_empty():
			ulisse.try_step(possible[rng.randi() % possible.size()])
		await create_timer(0.25).timeout
	Engine.time_scale = 1.0
	_check(stuck_checks == 0, "Ulisse mai bloccato dagli alleati in 150 passi (blocchi: %d)" % stuck_checks)

	print("RISULTATO: %s" % ("OK" if _failures == 0 else "%d controlli falliti" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		_failures += 1


func _find_open_cell(grid) -> Vector2i:
	for y in range(1, grid.size.y - 1):
		for x in range(1, grid.size.x - 1):
			var c := Vector2i(x, y)
			if grid.is_blocked(c):
				continue
			if DIRECTIONS.all(func(d): return not grid.is_blocked(c + d)):
				return c
	return Vector2i(-1, -1)


## Libera una casella spostando altrove l'eventuale occupante (non Ulisse).
func _free_cell(grid, c: Vector2i, keep) -> void:
	var occupant = grid.get_occupant(c)
	if occupant == null or occupant == keep:
		return
	for y in grid.size.y:
		for x in grid.size.x:
			if occupant.place_at(Vector2i(x, y)):
				return


func _surrounded_by_enemies_or_walls(grid, unit) -> bool:
	for d in DIRECTIONS:
		var c: Vector2i = unit.cell + d
		if not grid.is_inside(c) or grid.is_blocked(c):
			continue
		var occupant = grid.get_occupant(c)
		if occupant == null or occupant.team == unit.team:
			return false
	return true
