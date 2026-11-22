extends SceneTree
## Erba fotorealistica (GrassCards): densità uniforme sul prato, piazzali spenti
## coperti, calpestio dei personaggi nella mappa e LOD per distanza.
## Esecuzione: godot --headless --path . -s res://tests/test_grass_cards.gd

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	Quality.set_level(Quality.Level.HIGH)
	TerrainStyle.set_photo(true)
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var grass := get_first_node_in_group(&"grass_cards") as GrassCards
	_check(grass != null and grass.tuft_count > 0, "c'è l'erba a cards (%d ciuffi)" % (grass.tuft_count if grass else 0))
	if grass == null:
		quit(1)
		return

	# Uniformità: celle di 2x2 m interamente su prato pieno (lontano da bordi,
	# sentieri, rocce e caselle solide) devono avere quasi lo stesso numero di ciuffi.
	var mask := GrassMask.from_tree(self, grass.mask_fade, true, grass.solid_inset)
	var m1 := (load(GrassCards.TEX_DIR + "T_terreno_maschere.png") as Texture2D).get_image()
	if m1.is_compressed():
		m1.decompress()
	var counts := {}
	for p: Vector2 in grass.tuft_positions:
		var c := Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))
		counts[c] = counts.get(c, 0) + 1
	var values: Array[float] = []
	for cx in range(-13, 13):
		for cz in range(-15, 11):
			var full := true
			for sx in 5:
				for sz in 5:
					var q := Vector2(cx * 2.0 + sx * 0.5, cz * 2.0 + sz * 0.5)
					if mask.weight(q) < 1.0 or grass._density(q.x, q.y, mask, m1) < 0.999:
						full = false
						break
				if not full:
					break
			if full:
				values.append(float(counts.get(Vector2i(cx, cz), 0)))
	var mean := 0.0
	for v in values:
		mean += v
	mean /= maxf(values.size(), 1)
	var variance := 0.0
	var lowest := INF
	for v in values:
		variance += (v - mean) * (v - mean)
		lowest = minf(lowest, v)
	var cv := sqrt(variance / maxf(values.size(), 1)) / maxf(mean, 0.001)
	_check(values.size() > 60, "celle di prato pieno da confrontare: %d" % values.size())
	_check(cv < 0.12, "densità uniforme: scarto relativo %.3f (media %.1f ciuffi ogni 4 m²)" % [cv, mean])
	_check(lowest > mean * 0.6, "nessuna radura nel prato pieno (cella più rada %d su media %.1f)" % [int(lowest), mean])

	# Piazzale della porta: spento nella scena (visible = false), sul terreno
	# fotorealistico è prato, quindi deve esserci erba.
	var on_square := 0
	for p: Vector2 in grass.tuft_positions:
		if Rect2(1.0, -19.0, 11.0, 3.0).has_point(p):
			on_square += 1
	_check(on_square > 100, "il piazzale spento della porta è coperto d'erba (%d ciuffi)" % on_square)

	# Calpestio: Ulisse spinge l'erba nella mappa; al centro schiaccia.
	var ulisse := get_first_node_in_group(&"player") as Node3D
	for i in 30:
		await process_frame
	var t := grass.trample_at(ulisse.global_position)
	var side := grass.trample_at(ulisse.global_position + Vector3(0.35, 0, 0))
	_check(t.z > 0.5, "sotto Ulisse l'erba è schiacciata (%.2f)" % t.z)
	_check(side.x > 0.15, "accanto a Ulisse l'erba è spinta via (%.2f)" % side.x)
	_check(grass.trample_at(Vector3(20, 0, -25)).length() < 0.05, "lontano dai personaggi niente calpestio")

	# LOD: con la camera lontana si disegna solo una parte dei ciuffi.
	var camera := (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	var shown_near := _shown(grass)
	camera.set(&"_follow", null)
	camera.set(&"target", Vector3(-1, 0, -4))
	camera.set(&"distance", 58.0)
	camera.set(&"pitch_degrees", -70.0)
	for i in 30:
		await process_frame
	var shown_far := _shown(grass)
	_check(shown_far < grass.tuft_count * 0.75, "da lontano si disegnano meno ciuffi (%d su %d; vicino %d)" % [shown_far, grass.tuft_count, shown_near])
	_check(shown_far > grass.tuft_count * grass.lod_keep * 0.8, "ma mai meno della quota minima (%d)" % shown_far)

	print("RISULTATO: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)


func _shown(grass: GrassCards) -> int:
	var n := 0
	for child in grass.get_children():
		var mm := (child as MultiMeshInstance3D).multimesh
		n += mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
	return n
