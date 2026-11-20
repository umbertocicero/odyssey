extends SceneTree
## Test headless del terreno e dell'erba fotorealistici: la mesh del terreno c'è e
## sostituisce quello procedurale, l'erba rispetta la maschera (mare, strade,
## costruzioni), i budget per qualità, il vecchio prato resta ricostruibile con
## TerrainStyle.set_photo(false) e la griglia/il rilievo non cambiano.
## Avvio: godot --headless --path . -s res://tests/test_photo_terrain.gd

const LEVEL_PATH := "res://scenes/levels/level1/level1.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for lvl in [Quality.Level.LOW, Quality.Level.MEDIUM, Quality.Level.HIGH]:
		Quality.set_level(lvl)
		TerrainStyle.set_photo(true)
		var level: Node = load(LEVEL_PATH).instantiate()
		root.add_child(level)
		await process_frame
		await process_frame
		_check_photo(level, lvl)
		root.remove_child(level)
		level.free()
		await process_frame

	# Vecchio terreno procedurale: ricostruibile con il flag.
	Quality.set_level(Quality.Level.HIGH)
	TerrainStyle.set_photo(false)
	var old: Node = load(LEVEL_PATH).instantiate()
	root.add_child(old)
	await process_frame
	await process_frame
	var field := old.get_node("ErbaMossa") as GrassField
	_check(field.multimesh_instance != null and field.multimesh_instance.multimesh.instance_count > 1000, "flag off: il vecchio prato procedurale esiste")
	_check((old.get_node("Terreno/Prato") as Node3D).visible, "flag off: il terreno procedurale è visibile")
	_check(old.get_node("Terreno/TerrenoFotorealistico").get_child_count() == 0, "flag off: nessuna mesh fotorealistica")
	_check((old.get_node("ErbaFotorealistica") as Node3D).get_child_count() == 0, "flag off: nessuna erba a cards")
	root.remove_child(old)
	old.free()
	print("RISULTATO: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)


func _check_photo(level: Node, lvl: int) -> void:
	var tag := "qualità %d" % lvl
	var terrain := level.get_node("Terreno/TerrenoFotorealistico") as PhotoTerrain
	_check(terrain.surface != null, "%s: la mesh del terreno c'è" % tag)
	_check(not (level.get_node("Terreno/Prato") as Node3D).visible, "%s: il prato procedurale è nascosto" % tag)
	_check(not (level.get_node("Terreno/Rilievo") as Node3D).visible, "%s: il rilievo visivo procedurale è nascosto" % tag)
	_check(level.get_node("Terreno/Mare").visible, "%s: il mare resta" % tag)
	var field := level.get_node("ErbaMossa") as GrassField
	_check(field.multimesh_instance == null, "%s: il vecchio prato non viene costruito" % tag)
	# Quote: la mesh combacia con TerrainRelief entro pochi cm.
	var relief := get_first_node_in_group(&"terrain_relief") as TerrainRelief
	var worst := 0.0
	for p in [Vector2(0, 0), Vector2(-8, 4), Vector2(10, -10), Vector2(18, 6), Vector2(-14, 10)]:
		var level_h := relief.height_at_world(p.x, p.y)
		var mesh_h := terrain.height_at(p.x, p.y)
		worst = maxf(worst, absf(mesh_h - level_h))
	_check(worst < 0.25, "%s: la quota della mesh segue il rilievo (scarto max %.2f m)" % [tag, worst])
	# Erba: budget, maschera.
	var grass := level.get_node("ErbaFotorealistica") as GrassCards
	var budget := Quality.grass_budget()
	_check(grass.tuft_count > budget * 0.9 and grass.tuft_count <= budget, "%s: %d ciuffi su budget %d" % [tag, grass.tuft_count, budget])
	_check(grass.block_count > 3, "%s: erba divisa in %d blocchi" % [tag, grass.block_count])
	var mask := GrassMask.from_tree(self, 0.6)
	var bad := 0
	var total := 0
	for mmi in grass.get_children():
		if not mmi is MultiMeshInstance3D:
			continue
		var mm := (mmi as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin + grass.global_position
			total += 1
			if not mask.allows(Vector2(o.x, o.z)):
				bad += 1
	_check(total == grass.tuft_count and bad == 0, "%s: tutti i ciuffi su terreno permesso (fuori maschera: %d)" % [tag, bad])
	var sea_bad := 0
	for mmi in grass.get_children():
		if not mmi is MultiMeshInstance3D:
			continue
		var mm := (mmi as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin
			if o.x < -21.6 and o.z > -19.0:
				sea_bad += 1
	_check(sea_bad == 0, "%s: niente erba nel mare e sulla riva (%d)" % [tag, sea_bad])
	_check(get_first_node_in_group(&"diorama_grid") != null, "%s: la griglia c'è" % tag)


func _check(ok: bool, what: String) -> void:
	print(("OK    " if ok else "FALLITO ") + what)
	if not ok:
		_failures += 1
