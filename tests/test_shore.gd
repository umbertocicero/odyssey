extends SceneTree
## Test headless della riva naturale del livello 1 (SeaShore / ShoreProfile).
## - la linea d'acqua è irregolare (non una retta) ma resta dentro i limiti, e a est del corridoio di imbarco
## - le caselle del corridoio campo-costa (x da -21 a -20, z 10..13) sono all'asciutto e a quota calpestabile
## - la sabbia combacia con il terreno a est e a nord; la mesh e i detriti ci sono per ogni qualità
## - niente scogli né tronchi nel corridoio; le quote delle caselle sulla riva seguono la sabbia
## - con il terreno procedurale non si crea nulla e il mare resta il box originale
## Avvio: godot --headless --path . -s res://tests/test_shore.gd

const LEVEL_PATH := "res://scenes/levels/level1/level1.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Profilo: irregolare e dentro i limiti.
	var xs: Array[float] = []
	for z in range(-19, 23):
		xs.append(ShoreProfile.waterline(float(z)))
	var lo: float = xs.min()
	var hi: float = xs.max()
	_check(hi - lo > 0.9, "la linea d'acqua è sinuosa (escursione %.2f m)" % (hi - lo))
	_check(lo > -23.5 and hi < -20.6, "la linea d'acqua sta tra -23.5 e -20.6 (%.2f .. %.2f)" % [lo, hi])
	for z in range(10, 14):
		_check(ShoreProfile.waterline(float(z)) < -21.4, "corridoio di imbarco all'asciutto a z=%d (riva a %.2f)" % [z, ShoreProfile.waterline(float(z))])
	_check(ShoreProfile.floor_height(-19.5, 0.0) >= ShoreProfile.WATER_Y, "a terra la quota non scende sotto il pelo dell'acqua")
	_check(ShoreProfile.floor_height(-25.5, 0.0) < ShoreProfile.WATER_Y - 0.3, "al largo il fondale è profondo")
	_check(ShoreProfile.floor_height(-23.0, -19.0) >= ShoreProfile.WATER_Y, "la testa nord del bacino risale sopra il pelo dell'acqua")

	for lvl in [Quality.Level.LOW, Quality.Level.MEDIUM, Quality.Level.HIGH]:
		Quality.set_level(lvl)
		TerrainStyle.set_photo(true)
		var level: Node = load(LEVEL_PATH).instantiate()
		root.add_child(level)
		await process_frame
		await process_frame
		await process_frame
		_check_level(level, lvl)
		root.remove_child(level)
		level.free()
		await process_frame

	Quality.set_level(Quality.Level.HIGH)
	TerrainStyle.set_photo(false)
	var old: Node = load(LEVEL_PATH).instantiate()
	root.add_child(old)
	await process_frame
	await process_frame
	_check(old.get_node_or_null("Terreno/Mare/Riva") == null, "terreno procedurale: nessuna riva generata")
	root.remove_child(old)
	old.free()
	TerrainStyle.set_photo(true)
	print("FALLITI: %d" % _failures if _failures > 0 else "TUTTO OK")
	quit(1 if _failures > 0 else 0)


func _check_level(level: Node, lvl: int) -> void:
	var tag := "qualità %d" % lvl
	var shore := level.get_node_or_null("Terreno/Mare/Riva") as SeaShore
	_check(shore != null, "%s: la riva c'è" % tag)
	if shore == null:
		return
	_check(shore.sand != null and shore.sand.mesh != null, "%s: mesh della sabbia" % tag)
	# Cascata: il mare cade oltre il bordo ovest lungo il fianco del blocco.
	var fall := level.get_node_or_null("Terreno/Mare/Cascata") as SeaFall
	_check(fall != null, "%s: la cascata c'è" % tag)
	if fall != null:
		_check(absf(fall.edge_x - (-32.0)) < 0.01, "%s: la cascata parte dal bordo ovest del mare, ora a -32 (%.2f)" % [tag, fall.edge_x])
		_check(int(fall.stats["fall_triangles"]) > 100 and int(fall.stats["fall_triangles"]) < 5000, "%s: triangoli della cascata %d" % [tag, fall.stats["fall_triangles"]])
		_check(fall.get_node_or_null("Lastra") != null and fall.get_node_or_null("Nebbia") != null, "%s: lastra e nebbia" % tag)
	_check(int(shore.stats["sand_triangles"]) > 1000 and int(shore.stats["sand_triangles"]) < 120000, "%s: triangoli della sabbia %d" % [tag, shore.stats["sand_triangles"]])
	_check(int(shore.stats["debris_instances"]) > 100, "%s: detriti %d in %d MultiMesh" % [tag, shore.stats["debris_instances"], shore.stats["multimeshes"]])
	_check(int(shore.stats["multimeshes"]) <= 8, "%s: al massimo 8 MultiMesh di detriti (%d)" % [tag, shore.stats["multimeshes"]])
	# Combacia col terreno a est e a nord (nessun gradino).
	var terrain := get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	for p: Vector2 in [Vector2(-19.0, 0.0), Vector2(-19.0, 15.0), Vector2(-23.0, -21.0), Vector2(-21.0, -21.0)]:
		var diff := absf(shore.surface_y(p.x, p.y) - terrain.height_at(p.x, p.y))
		_check(diff < 0.02, "%s: la sabbia combacia col terreno in %s (scarto %.3f m)" % [tag, p, diff])
	# Corridoio: la sabbia sta sopra l'acqua alle caselle di imbarco.
	for z in [10.5, 11.5, 12.5]:
		var y := shore.surface_y(-20.5, z)
		_check(y > ShoreProfile.WATER_Y + 0.02 and y < 0.3, "%s: sabbia asciutta e calpestabile a (-20.5, %.1f): y=%.3f" % [tag, z, y])
	# Niente scogli né tronchi nel corridoio.
	for node_name in ["Scogli", "TronchiSpiaggiati"]:
		var mmi := shore.get_node_or_null(node_name) as MultiMeshInstance3D
		if mmi == null:
			continue
		var inside := 0
		for i in mmi.multimesh.instance_count:
			var z := mmi.multimesh.get_instance_transform(i).origin.z
			if z > SeaShore.KEEP_CLEAR_Z.x and z < SeaShore.KEEP_CLEAR_Z.y:
				inside += 1
		_check(inside == 0, "%s: %s fuori dal corridoio (%d dentro)" % [tag, node_name, inside])
	# Le quote delle caselle sulla riva seguono la sabbia, entro 12 cm dal livello della casella.
	var relief := get_first_node_in_group(&"terrain_relief") as TerrainRelief
	var h := relief.height_at_world(-20.5, 11.5)
	_check(absf(h - shore.surface_y(-20.5, 11.5)) < 0.13, "%s: la quota della casella di imbarco segue la sabbia (%.3f)" % [tag, h])
	# Il mare ora arriva sotto la spiaggia.
	var sea := level.get_node("Terreno/Mare") as MeshInstance3D
	_check((sea.mesh as BoxMesh).size.x > 5.5, "%s: il box del mare si estende sotto la spiaggia (%.1f m)" % [tag, (sea.mesh as BoxMesh).size.x])


func _check(ok: bool, what: String) -> void:
	if ok:
		print("OK    ", what)
	else:
		print("FALLITO  ", what)
		_failures += 1
