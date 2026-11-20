extends SceneTree
## Test headless dell'erba che si muove: il campo esiste, gli interattori
## (personaggi, proiettili, fuoco) arrivano allo shader, seguono l'oggetto con
## ritardo e svaniscono piano quando l'oggetto sparisce.
## (La resa visiva si controlla con tests/screenshot_level1.gd, dalla finestra.)
## Avvio: godot --headless --path . -s res://tests/test_grass.gd

const LEVEL_PATH := "res://scenes/levels/level1/level1.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	TerrainStyle.set_photo(false)  # prova il vecchio prato procedurale (GrassField)
	var level: Node = load(LEVEL_PATH).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var grid: DioramaGrid = get_first_node_in_group(&"diorama_grid")
	var ulisse: GridUnit = get_first_node_in_group(&"player")
	var grass: GrassField = level.get_node_or_null("ErbaMossa")
	_check(grass != null and grass.multimesh_instance != null, "il campo d'erba esiste")
	if grass == null or grass.multimesh_instance == null:
		quit(1)
		return
	for s in get_nodes_in_group(&"wall_shooters"):
		s.auto_fire = false
	for u in get_nodes_in_group(&"units"):
		if "leader" in u:
			u.leader = null

	var instances := grass.multimesh_instance.multimesh.instance_count
	_check(instances > 2000 and instances <= grass.count, "ciuffi creati: %d" % instances)
	_check(grass.multimesh_instance.multimesh.mesh.get_surface_count() == 1, "un solo disegno per tutto il campo (un MultiMesh)")
	# Nessun ciuffo sulle strade.
	var on_road := 0
	for i in instances:
		var p := grass.multimesh_instance.multimesh.get_instance_transform(i).origin
		for rect in grass.exclude_rects:
			if rect.has_point(Vector2(p.x, p.z)):
				on_road += 1
	_check(on_road == 0, "nessun ciuffo sulle strade")

	# 1. Gli interattori arrivano allo shader, con Ulisse tra i primi.
	for i in 5:
		await process_frame
	var uniform: PackedVector4Array = grass.material.get_shader_parameter(&"interactors")
	_check(uniform.size() == GrassField.MAX_INTERACTORS, "l'array degli interattori ha %d posti" % uniform.size())
	_check(grass.active_interactor_count() > 0, "ci sono interattori attivi (%d)" % grass.active_interactor_count())
	var first := uniform[0]
	_check(first.w > 0.1 and Vector2(first.x - ulisse.global_position.x, first.z - ulisse.global_position.z).length() < 1.0,
		"il primo interattore è Ulisse, con raggio %.2f" % first.w)

	# 2. Ulisse cammina: l'interattore lo segue con un po' di ritardo (erba che si rialza piano).
	var target := ulisse.cell + Vector2i(0, -1)
	for u in get_nodes_in_group(&"units"):
		if u != ulisse and (u as GridUnit).cell == target:
			(u as GridUnit).place_at(ulisse.cell + Vector2i(3, 0))
	ulisse.try_step(Vector2i(0, -1))
	await process_frame
	await process_frame
	var smoothed: Vector3 = grass.tracked_position(ulisse)
	var real := ulisse.global_position
	_check(smoothed != null and smoothed.distance_to(real) > 0.0 and smoothed.distance_to(real) < 1.5,
		"l'interattore segue Ulisse con ritardo (distanza %.2f m)" % smoothed.distance_to(real))
	await create_timer(1.0).timeout
	smoothed = grass.tracked_position(ulisse)
	_check(smoothed.distance_to(ulisse.global_position) < 0.15, "dopo un secondo l'erba ha raggiunto Ulisse")

	# 3. Un proiettile in volo piega l'erba e poi svanisce piano.
	var archer: WallShooter = level.get_node("DifeseSulleMura/Arciere4")
	var before := grass.active_interactor_count()
	archer.fire_at(Vector2i(12, 8))
	await create_timer(0.3).timeout
	_check(grass.active_interactor_count() > before, "il proiettile in volo è un interattore")
	await create_timer(archer.profile.warning_time + 0.2).timeout
	var ghosts := grass.active_interactor_count()
	await create_timer(1.5).timeout
	_check(grass.active_interactor_count() <= ghosts, "dopo l'impatto l'influenza del proiettile svanisce piano")

	# 4. Fuoco: la casella in fiamme è un interattore.
	var fire_archer: WallShooter = level.get_node("DifeseSulleMura/ArciereFuoco1")
	fire_archer.fire_at(Vector2i(9, 4))
	await create_timer(fire_archer.profile.warning_time + 0.5).timeout
	var fire_found := false
	for node in get_nodes_in_group(&"burning_cells"):
		if grass.tracked_position(node as Node3D) != null:
			fire_found = true
	_check(fire_found, "la casella in fiamme piega l'erba")

	# 5. Teletrasporto: nessuna scia, l'interattore salta con l'unità.
	ulisse.place_at(Vector2i(30, 30))
	await process_frame
	await process_frame
	var jumped: Vector3 = grass.tracked_position(ulisse)
	_check(jumped.distance_to(ulisse.global_position) < 0.5, "dopo un salto l'interattore non attraversa il campo")

	# 6. Un'unità che sparisce lascia un'influenza che svanisce.
	var ally: GridUnit = null
	for u in get_nodes_in_group(&"achei"):
		if u != ulisse:
			ally = u
			break
	var ally_id := ally.get_instance_id()
	var n_before := grass.active_interactor_count()
	ally.take_damage(1000)
	await create_timer(0.1).timeout
	var fallen = grass._tracked.get(ally_id)
	_check(fallen == null or not fallen["seen"], "un soldato caduto non è più un interattore presente (era %d attivi)" % n_before)
	await create_timer(2.5).timeout
	_check(not grass._tracked.has(ally_id), "l'influenza del soldato caduto è del tutto svanita")

	# 7. Interazione spenta: l'array torna a zero.
	grass.interaction_enabled = false
	await process_frame
	await process_frame
	var off: PackedVector4Array = grass.material.get_shader_parameter(&"interactors")
	_check(off[0] == Vector4.ZERO, "con l'interazione spenta lo shader non riceve interattori")

	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		print("FAIL  ", label)
