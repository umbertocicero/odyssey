extends SceneTree
## Mappa di densità dei ciuffi di GrassCards (PNG, 1 px = 0.25 m) e maschera GrassMask.
## godot --headless --path . -s res://tests/tools/grass_density_map.gd -- --out=/percorso/mappa.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://grass_density.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var cards := get_first_node_in_group(&"grass_cards")
	var origin: Vector2 = cards.get(&"origin")
	var size: Vector2 = cards.get(&"map_size")
	var res := 4
	var w := int(size.x * res)
	var h := int(size.y * res)
	var counts := PackedInt32Array()
	counts.resize(w * h)
	for p: Vector2 in cards.get(&"tuft_positions"):
		var ix := clampi(int((p.x - origin.x) * res), 0, w - 1)
		var iz := clampi(int((p.y - origin.y) * res), 0, h - 1)
		counts[iz * w + ix] += 1
	var mask := GrassMask.from_tree(self, 0.5, true, 0.3)
	var img := Image.create(w * 2, h, false, Image.FORMAT_RGB8)
	for z in h:
		for x in w:
			# densità in ciuffi/m², mediata su 3x3 celle
			var c := 0
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					c += counts[clampi(z + dz, 0, h - 1) * w + clampi(x + dx, 0, w - 1)]
			var d := c / 25.0 * res * res
			var v := clampf(d / 25.0, 0.0, 1.0)
			img.set_pixel(x, z, Color(v, v, v))
			var mw := mask.weight(origin + Vector2(x + 0.5, z + 0.5) / res)
			img.set_pixel(x + w, z, Color(mw, mw, mw))
	img.save_png(out)
	print("ciuffi=", cards.get(&"tuft_count"), " salvata ", out)
	quit(0)
