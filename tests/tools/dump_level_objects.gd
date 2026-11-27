extends SceneTree
## Elenca tutti gli oggetti visibili del livello 1 (mesh, MultiMesh, ostacoli della griglia)
## con posizione e dimensione nel mondo, ignorando nomi e gerarchia, così due esecuzioni si
## confrontano con `diff` (prima/dopo aver portato oggetti nella scena).
## Avvio: godot --headless --path . -s res://tests/tools/dump_level_objects.gd -- out.txt


var _scene_path := "res://scenes/levels/level1/level1.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _r(v: Vector3) -> String:
	return "%.2f,%.2f,%.2f" % [v.x, v.y, v.z]


func _run() -> void:
	var out_path := "/tmp/level_objects.txt"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.substr(8)
		else:
			out_path = arg
	var level_node: Node = load(_scene_path).instantiate()
	root.add_child(level_node)
	for i in 20:
		await process_frame
	var level := get_first_node_in_group(&"diorama_grid").get_parent()
	var lines: Array[String] = []
	var mesh_count := 0
	for n in level.find_children("*", "VisualInstance3D", true, false):
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi := n as MeshInstance3D
			var box := mi.global_transform * mi.mesh.get_aabb()
			lines.append("MESH|%s|%d|%s|%s" % [mi.mesh.resource_path.get_file(), mi.mesh.get_surface_count(), _r(box.position), _r(box.size)])
			mesh_count += 1
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			var mm := (n as MultiMeshInstance3D).multimesh
			lines.append("MULTI|%s|%d|%s" % [mm.mesh.resource_path.get_file() if mm.mesh else "-", mm.instance_count, _r(n.global_position)])
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	# Gli oggetti di data/props/level1_polyhaven.json, uno per uno (stessi valori a runtime e in scena).
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/props/level1_polyhaven.json"))
	for item: Dictionary in data["items_in_scene"]:
		var gp := level.find_child(String(item["name"]), true, false) as GridProp
		if gp == null:
			lines.append("ITEM|%s|MANCA" % item["name"])
			continue
		var cells := gp.get_blocked_cells(grid).map(func(c: Vector2i) -> String: return "%d,%d" % [c.x, c.y])
		var vb := gp.visual_box()
		var gt := gp.global_transform
		lines.append("ITEM|%s|pos=%s|rotY=%.2f|box=%s %s|fp=%s|block=%s|trunk=%.3f|thin=%s|vault=%s|climb=%s|tree=%s|cells=%s|groups=%s" % [
			item["name"], _r(gt.origin), rad_to_deg(gt.basis.get_euler().y), _r(vb.position), _r(vb.size), gp.footprint, gp.blocking,
			gp.trunk_radius, gp.thin_shape(), gp.is_vaultable(), gp.is_climbable(), gp.is_tree(), cells, gp.is_in_group(&"grid_obstacle")])
	var blocked := 0
	for y in grid.size.y:
		for x in grid.size.x:
			if grid.is_blocked(Vector2i(x, y)):
				blocked += 1
				lines.append("BLOCKED|%d,%d" % [x, y])
	lines.append("OBSTACLES|%d" % get_nodes_in_group(&"grid_obstacle").size())
	lines.sort()
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("meshes=", mesh_count, " blocked=", blocked, " obstacles=", get_nodes_in_group(&"grid_obstacle").size(), " lines=", lines.size())
	quit()
