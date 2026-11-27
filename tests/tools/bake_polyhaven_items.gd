extends SceneTree
## Calcola, per ogni oggetto solido di data/props/level1_polyhaven.json, gli stessi valori che
## PolyhavenProps calcola a runtime (quota del terreno, impronta, raggio del tronco, ecc.) e li
## scrive in JSON, per poterli salvare come nodi GridProp in level1.tscn.
## Avvio: godot --headless --path . -s res://tests/tools/bake_polyhaven_items.gd -- out.json


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_path := "/tmp/polyhaven_baked.json"
	for arg in OS.get_cmdline_user_args():
		out_path = arg
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var relief := get_first_node_in_group(&"terrain_relief") as TerrainRelief
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/props/level1_polyhaven.json"))
	var out: Array = []
	for item: Dictionary in data["items_in_scene"]:
		var id: String = item["id"]
		var rec := {"name": item["name"], "id": id, "fallback": item.get("fallback", "")}
		var scene := PolyhavenCatalog.get_scene(id)
		var role := PolyhavenCatalog.role(id)
		var axis: int = ModelFit.Axis.HEIGHT if item.get("fit", "height") == "height" else ModelFit.Axis.LONGEST
		var height: float = item.get("height", 1.0)
		var meshes := ModelFit.extract_meshes(scene, "")
		var fit := ModelFit.fit_transform(meshes, Vector3.ZERO, axis, height)
		var box := AABB()
		var first := true
		for entry in meshes:
			var b: AABB = (fit * (entry[1] as Transform3D)) * (entry[0] as Mesh).get_aabb()
			box = b if first else box.merge(b)
			first = false
		var pos: Array = item["pos"]
		rec["x"] = pos[0]
		rec["z"] = pos[1]
		rec["y"] = relief.height_at_world(pos[0], pos[1]) - float(item.get("sink", 0.0))
		rec["yaw"] = item.get("yaw", 0.0)
		rec["fit_axis"] = axis
		rec["fit_size"] = height
		rec["min_quality"] = int(PolyhavenCatalog.ENTRIES[id]["min_quality"])
		rec["primary_path"] = PolyhavenCatalog.ROOT + String(PolyhavenCatalog.ENTRIES[id]["path"])
		if rec["fallback"] != "":
			rec["fallback_path"] = PolyhavenCatalog.ROOT + String(PolyhavenCatalog.ENTRIES[rec["fallback"]]["path"])
			rec["fallback_min_quality"] = int(PolyhavenCatalog.ENTRIES[rec["fallback"]]["min_quality"])
		var blocking: bool = item.get("blocking", role != PolyhavenCatalog.Role.TOOL and role != PolyhavenCatalog.Role.GROUND \
				and role != PolyhavenCatalog.Role.PLANT and role != PolyhavenCatalog.Role.FLOWER and role != PolyhavenCatalog.Role.GRASS)
		rec["blocking"] = blocking
		rec["tree"] = role == PolyhavenCatalog.Role.TREE
		rec["island"] = id.begins_with("island_tree")
		if role == PolyhavenCatalog.Role.TREE:
			rec["trunk_radius"] = item.get("trunk_radius", clampf(box.size.x * 0.035, 0.18, 0.45))
			rec["footprint"] = [1, 1]
			rec["canopy_fade_radius"] = box.size.x * 0.5
		else:
			var fp := Vector2i(maxi(1, roundi(box.size.x * 0.8)), maxi(1, roundi(box.size.z * 0.8)))
			if item.has("footprint"):
				fp = Vector2i(int(item["footprint"][0]), int(item["footprint"][1]))
			rec["footprint"] = [fp.x, fp.y]
			if role == PolyhavenCatalog.Role.ROCK:
				rec["vault_mode"] = 1 if box.size.y <= 1.1 else 2
			elif role == PolyhavenCatalog.Role.WALL or role == PolyhavenCatalog.Role.CLIFF:
				rec["vault_mode"] = 2
				rec["climb_mode"] = 2
		out.append(rec)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("baked ", out.size())
	quit()
