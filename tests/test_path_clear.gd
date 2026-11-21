extends SceneTree
## Test headless: il percorso tra l'accampamento e la costa (zona di imbarco dei feriti) è libero.
## Un corridoio largo 3 caselle (z da 10 a 13) dalla riva (x -20) al bordo est del campo (x -6) non
## deve avere caselle bloccate né scavalcabili, né tronchi/pali sottili; con una ricerca sulla griglia
## si verifica che la casella della riva sia raggiungibile dal centro del campo restando nel corridoio.
## Avvio: godot --headless --path . -s res://tests/test_path_clear.gd

const LEVEL_PATH := "res://scenes/levels/level1/level1.tscn"
const X_SHORE := -20.0
const X_CAMP_EAST := -6.0
const Z_MIN := 10.0
const Z_MAX := 13.0

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load(LEVEL_PATH).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	await process_frame
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	_check(grid != null, "griglia presente")
	var blocked: Array[Vector2i] = []
	var cells := {}
	for x in range(int(X_SHORE), int(X_CAMP_EAST)):
		for z in range(int(Z_MIN), int(Z_MAX)):
			var c := grid.world_to_cell(Vector3(x + 0.5, 0.0, z + 0.5))
			cells[c] = true
			if grid.is_blocked(c):
				blocked.append(c)
	_check(blocked.is_empty(), "corridoio camp-costa senza caselle bloccate o scavalcabili (%d) %s" % [blocked.size(), blocked])
	var thin_hits := 0
	for s: Dictionary in grid._thin:
		var c: Vector2 = s["center"]
		var r: float = s["radius"]
		if c.x > X_SHORE - r and c.x < X_CAMP_EAST + r and c.y > Z_MIN - r and c.y < Z_MAX + r:
			thin_hits += 1
			print("   tronco/palo nel corridoio: ", c)
	_check(thin_hits == 0, "nessun tronco o palo sottile nel corridoio (%d)" % thin_hits)
	# Ricerca sulla griglia dal centro del campo alla riva, solo dentro il corridoio.
	var rules := LevelRules.new()
	var start_cell := Vector2i(rules.camp_rect.position + rules.camp_rect.size / 2)
	var goal := grid.world_to_cell(Vector3(X_SHORE + 0.5, 0.0, 11.5))
	var in_corridor := func(c: Vector2i) -> bool:
		return cells.has(c)
	var seen := {start_cell: true}
	var queue: Array[Vector2i] = [start_cell]
	var reached := false
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			reached = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + d
			if seen.has(nx) or not (in_corridor.call(nx) or nx == start_cell) or grid.is_blocked(nx):
				continue
			seen[nx] = true
			queue.append(nx)
	_check(reached, "la riva %s è raggiungibile dal centro del campo %s dentro il corridoio" % [goal, start_cell])
	var player := get_first_node_in_group(&"player") as Node3D
	var player_cell := grid.world_to_cell(player.global_position)
	_check(grid.validate_connectivity(player_cell), "connettività della griglia dalla partenza di Ulisse (%d irraggiungibili)" % grid.find_unreachable_cells(player_cell).size())
	print("RISULTATO: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print(("OK    " if ok else "FALLITO ") + what)
	if not ok:
		_failures += 1
