extends SceneTree
## Test headless del rilievo (livelli di altezza): salita a scalini, pareti che
## non si superano, altezza delle unità, caselle chiuse e linea di tiro.
## Avvio: godot --headless --path . -s res://tests/test_relief.gd

const LEVEL_PATH := "res://scenes/levels/level1/level1.tscn"

var _failures := 0
var grid: DioramaGrid
var relief: TerrainRelief
var ulisse: GridUnit


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load(LEVEL_PATH).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	grid = get_first_node_in_group(&"diorama_grid")
	relief = get_first_node_in_group(&"terrain_relief")
	ulisse = get_first_node_in_group(&"player")
	_check(grid != null and relief != null and ulisse != null, "griglia, rilievo e Ulisse presenti")
	for s in get_nodes_in_group(&"wall_shooters"):
		s.auto_fire = false
	for ally in get_nodes_in_group(&"achei"):
		if ally != ulisse:
			ally.leader = null
	Engine.time_scale = 4.0

	# 1. Mappa: pianura al centro, rilievi ai bordi, altopiano a nord.
	_check(grid.get_level(Vector2i(6, 31)) == 0, "l'accampamento è in pianura (livello 0)")
	_check(grid.get_level(Vector2i(0, 0)) == 3, "l'angolo nord-ovest è il rilievo più alto (livello 3)")
	_check(relief.level_at_world(0.0, -25.0) == 2, "mura e acropoli stanno sull'altopiano nord (livello 2)")
	var peak := grid.cell_to_world(Vector2i(0, 0))
	_check(absf(peak.y - 2.4) < 0.01, "una casella di livello 3 sta a 2,4 m (%.2f)" % peak.y)

	# 2. Tutte le caselle libere restano raggiungibili salendo a scalini.
	var unreachable := grid.find_unreachable_cells(ulisse.cell)
	_check(unreachable.is_empty(), "nessuna casella irraggiungibile con i dislivelli (trovate: %s)" % [unreachable])

	# 3. Uno scalino si sale, e Ulisse prende la quota della casella.
	var low := Vector2i(12, 5)    # livello 0
	var step_up := Vector2i(10, 5) # livello 1
	_check(grid.get_level(low) == 0 and grid.get_level(step_up) == 1, "caselle di prova: livello 0 e livello 1")
	_free(low)
	_free(step_up)
	ulisse.place_at(low)
	var ok := ulisse.try_step(Vector2i.LEFT)  # verso (11,5), livello 0 o 1
	await create_timer(0.5).timeout
	ok = ulisse.try_step(Vector2i.LEFT) and ok
	await create_timer(0.5).timeout
	_check(ok and ulisse.cell == step_up, "Ulisse sale uno scalino (%s)" % [ulisse.cell])
	_check(absf(ulisse.global_position.y - 0.8) < 0.13, "dopo il passo Ulisse è a 0,8 m (±12 cm di colline della mesh) (%.2f)" % ulisse.global_position.y)

	# 4. Una parete (dislivello 2 o più) non si supera.
	var wall_cell := step_up + Vector2i.LEFT
	var wall_index := (wall_cell.y + 10) * relief.map_size.x + (wall_cell.x + 6)
	var saved := relief.levels[wall_index]
	_free(wall_cell)
	relief.levels[wall_index] = 4
	_check(not ulisse.can_enter(wall_cell), "una parete di roccia (+3 livelli) non si supera")
	_check(not ulisse.try_step(Vector2i.LEFT), "try_step contro la parete non parte")
	relief.levels[wall_index] = 2
	_check(ulisse.can_enter(wall_cell), "uno scalino di un livello si supera")
	relief.levels[wall_index] = saved

	# 5. Il rilievo copre la linea di tiro solo se sta davvero in mezzo.
	var from := grid.cell_to_world(Vector2i(12, 25)) + Vector3.UP * 0.5
	var to := grid.cell_to_world(Vector2i(12, 18)) + Vector3.UP * 0.8
	_check(grid.has_line_of_fire(from, to), "tiro libero sulla pianura")
	var mid := Vector2i(12, 21)
	var mid_index := (mid.y + 10) * relief.map_size.x + (mid.x + 6)
	var mid_saved := relief.levels[mid_index]
	relief.levels[mid_index] = 4
	_check(not grid.has_line_of_fire(from, to), "un blocco di roccia alto in mezzo ferma il tiro")
	# Un arciere a terra non vede il bersaglio dietro il blocco.
	var archer: WallShooter = load("res://scenes/enemies/troiano/arciere_mura.tscn").instantiate()
	get_first_node_in_group(&"diorama_grid").get_parent().add_child(archer)
	archer.auto_fire = false
	archer.global_position = grid.cell_to_world(Vector2i(12, 25))
	var target_cell := Vector2i(12, 20)
	_free(target_cell)
	ulisse.place_at(target_cell)
	_check(archer.is_in_range(target_cell), "il bersaglio è a portata dell'arciere a terra")
	_check(archer.pick_target() != ulisse, "dietro il rilievo l'arciere non sceglie Ulisse")
	relief.levels[mid_index] = mid_saved
	_check(archer.pick_target() == ulisse, "senza il rilievo in mezzo il bersaglio viene scelto")
	archer.queue_free()

	# 6. Le difese sulle mura (in alto) vedono la pianura.
	var wall_archer: WallShooter = get_first_node_in_group(&"wall_shooters")
	var clear := true
	for x in [3, 10, 20]:
		var c := Vector2i(x, 4)
		if wall_archer.is_in_range(c) and not grid.has_line_of_fire(wall_archer.muzzle_position(), grid.cell_to_world(c) + Vector3.UP * 0.8):
			clear = false
	_check(clear, "dall'alto delle mura la linea di tiro sulla pianura è libera")

	Engine.time_scale = 1.0
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)


## Toglie dalla casella un'eventuale altra unità (per le caselle di prova).
func _free(c: Vector2i) -> void:
	var other := grid.get_occupant(c) as GridUnit
	if other and other != ulisse:
		grid.release(c, other)
		other.queue_free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		print("FAIL  ", label)
