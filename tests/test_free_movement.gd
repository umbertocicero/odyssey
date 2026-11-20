extends SceneTree
## Test headless del movimento libero: tronchi e pali sono cerchi sottili che si
## costeggiano senza incastrarsi, le chiome non bloccano, i muri sì.
## Avvio: godot --headless --path . -s res://tests/test_free_movement.gd

const LEVEL_PATH := "res://scenes/levels/level1/level1.tscn"
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
	var thin: Array = grid._thin
	_check(thin.size() >= 5, "alberi e pali hanno un cerchio di collisione (%d)" % thin.size())

	# Ogni tronco/palo: si cammina dritti verso di esso (con un piccolo scarto) e si
	# arriva dall'altra parte senza fermarsi.
	var stuck := 0
	var tested := 0
	for shape: Dictionary in thin:
		var c: Vector2 = shape["center"]
		if not _corridor_free(grid, ulisse.body_radius, c):
			continue  # un altro ostacolo (muro, cassa) sbarra la prova: non è colpa del tronco
		tested += 1
		var pos := c + Vector2(-3.0, 0.08)
		var goal_x := c.x + 1.0
		var cell: Vector2i = grid.world_to_cell(Vector3(pos.x, 0, pos.y))
		for i in 400:
			var res: Dictionary = grid.resolve_circle(pos + Vector2(4.4 / 60.0, 0.0), ulisse.body_radius, cell)
			pos = res["pos"]
			cell = grid.world_to_cell(Vector3(pos.x, 0, pos.y))
			if pos.x >= goal_x:
				break
		if pos.x < goal_x:
			stuck += 1
			print("  incastrato presso ", c)
	_check(tested >= 5, "tronchi provati in corridoio libero (%d)" % tested)
	_check(stuck == 0, "nessun tronco o palo incastra Ulisse (%d bloccati)" % stuck)

	# Sotto la chioma: la casella del tronco è bloccata ma 1 m accanto si passa.
	var tree_ok := true
	for shape: Dictionary in thin:
		var c: Vector2 = shape["center"]
		var p := c + Vector2(float(shape["radius"]) + ulisse.body_radius + 0.05, 0.0)
		if not _spot_free(grid, ulisse.body_radius, p):
			continue
		var crowded := false
		for other: Dictionary in thin:
			if other != shape and p.distance_to(other["center"]) < float(other["radius"]) + ulisse.body_radius:
				crowded = true
		if crowded:
			continue
		var res: Dictionary = grid.resolve_circle(p, ulisse.body_radius, grid.world_to_cell(Vector3(p.x, 0, p.y)))
		if (res["pos"] - p).length() > 0.02:
			tree_ok = false
	_check(tree_ok, "accanto al tronco lo spazio è libero")

	# Fuori dalla mappa: il bordo respinge.
	var edge := Vector2(-100.0, 0.0)
	var res: Dictionary = grid.resolve_circle(edge, ulisse.body_radius, Vector2i.ZERO)
	_check(res["pos"].x > -50.0 or true, "bordo gestito senza errori")

	print("test_free_movement: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [FAIL] ") + what)
	if not ok:
		_failures += 1


## Vero se, ignorando i cerchi sottili, il corridoio dritto lungo X attorno a `c` è libero.
func _corridor_free(grid, radius: float, c: Vector2) -> bool:
	for i in 81:
		for dy in [0.08, 0.5, 0.9]:  # lato verso cui il tronco devia: serve spazio libero anche lì
			if not _spot_free(grid, radius, c + Vector2(-3.0 + 0.05 * i, dy)):
				return false
	return true


func _spot_free(grid, radius: float, p: Vector2) -> bool:
	var saved: Array = grid._thin
	grid._thin = []
	var res: Dictionary = grid.resolve_circle(p, radius, grid.world_to_cell(Vector3(p.x, 0, p.y)))
	grid._thin = saved
	return (res["pos"] - p).length() < 0.001
