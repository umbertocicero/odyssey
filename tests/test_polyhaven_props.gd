extends SceneTree
## Test headless dei props Poly Haven:
##  - ogni modello del catalogo si carica ed è una mesh valida;
##  - i dati del livello 1 si costruiscono senza modelli mancanti;
##  - i props solidi non occupano caselle già occupate dal livello e
##    non spezzano la connettività (nessuna zona chiusa nuova);
##  - rispettano i budget di triangoli per qualità.
## Avvio: godot --headless --path . -s res://tests/test_polyhaven_props.gd

const LEVEL1 := "res://scenes/levels/level1/level1.tscn"
const DATA1 := "res://data/props/level1_polyhaven.json"
const DATA2 := "res://data/props/level2_polyhaven.json"
## Budget dei triangoli dei soli props Poly Haven (solidi + sparsi), per qualità.
const BUDGET := {0: 170000, 1: 360000, 2: 650000}

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_failures += 1


## Il livello può già istanziare i props: per misurare togliamo quella istanza.
func _strip_props(level: Node) -> void:
	var existing := level.get_node_or_null("PropsPolyhaven")
	if existing:
		level.remove_child(existing)
		existing.free()


func _run() -> void:
	# 1) Catalogo
	var missing: Array[String] = []
	for id: String in PolyhavenCatalog.ENTRIES:
		var scene := PolyhavenCatalog.get_scene(id)
		if scene == null or ModelFit.extract_meshes(scene, "").is_empty():
			missing.append(id)
	_check(missing.is_empty(), "catalogo: %d modelli caricati, mancanti/vuoti: %s" % [PolyhavenCatalog.ENTRIES.size(), missing])

	# 2) Livello 1 senza props: caselle bloccate di base
	var base_level: Node = load(LEVEL1).instantiate()
	_strip_props(base_level)
	root.add_child(base_level)
	await process_frame
	await process_frame
	var base_grid: DioramaGrid = get_first_node_in_group(&"diorama_grid")
	var base_blocked := {}
	for y in base_grid.size.y:
		for x in base_grid.size.x:
			if base_grid.is_blocked(Vector2i(x, y)):
				base_blocked[Vector2i(x, y)] = true
	var start: Vector2i = base_grid.world_to_cell((get_first_node_in_group(&"player") as Node3D).global_position)
	var base_unreachable := base_grid.find_unreachable_cells(start).size()
	base_level.queue_free()
	await process_frame
	await process_frame

	# 3) Livello 1 con props, per ogni qualità
	for q in [2, 1, 0]:
		var level: Node = load(LEVEL1).instantiate()
		_strip_props(level)
		var props := PolyhavenProps.new()
		props.data_path = DATA1
		props.quality_override = q
		level.add_child(props)
		level.move_child(props, level.get_node("Griglia").get_index())
		root.add_child(level)
		await process_frame
		await process_frame
		await process_frame
		var grid: DioramaGrid = get_first_node_in_group(&"diorama_grid")
		var st: Dictionary = props.stats
		_check((st["skipped"] as Array).is_empty() or q < 2, "q=%d: nessun modello saltato %s" % [q, st["skipped"]])
		var tris: int = int(st["solid_tris"]) + int(st["scatter_tris"])
		_check(tris <= BUDGET[q], "q=%d: triangoli props %d <= budget %d" % [q, tris, BUDGET[q]])
		if q == 2:
			var overlap := 0
			for node in get_nodes_in_group(&"grid_obstacle"):
				if node is GridProp and node.get_parent() == props:
					for c: Vector2i in (node as GridProp).get_blocked_cells(grid):
						if base_blocked.has(c):
							overlap += 1
							print("   sovrapposizione ", node.name, " cella ", c)
			_check(overlap == 0, "q=2: nessun prop sopra caselle già bloccate (%d)" % overlap)
			var unreachable := grid.find_unreachable_cells(start).size()
			_check(unreachable <= base_unreachable, "q=2: zone irraggiungibili %d (base %d)" % [unreachable, base_unreachable])
			_check(grid.validate_connectivity(start) or base_unreachable > 0, "q=2: connettività dalla partenza")
		print("   q=%d stats=%s" % [q, st])
		level.queue_free()
		await process_frame
		await process_frame

	# 4) Dati del livello 2: solo che ogni id esista nel catalogo
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA2))
	var bad: Array[String] = []
	for item: Dictionary in data["items"]:
		if not PolyhavenCatalog.has_entry(item["id"]):
			bad.append(item["id"])
	for sc: Dictionary in data["scatters"]:
		for id: String in sc["ids"]:
			if not PolyhavenCatalog.has_entry(id):
				bad.append(id)
	_check(bad.is_empty(), "livello 2: id sconosciuti nel catalogo %s" % [bad])

	print("RISULTATO: %s (%d errori)" % ["OK" if _failures == 0 else "FALLITO", _failures])
	quit(1 if _failures else 0)
