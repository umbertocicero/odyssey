extends SceneTree
## Screenshot ravvicinati di Ulisse e di un soldato acheo (serve una finestra, non headless).
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_achei.gd -- --out=achei2_after

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "achei2_after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var ulisse := get_first_node_in_group(&"player") as Node3D
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var allies := get_nodes_in_group(&"units").filter(func(n: Node) -> bool: return n != ulisse and n.get("team") == 0)
	var targets := {"ulisse": ulisse}
	if not allies.is_empty():
		targets["soldato_acheo"] = allies[0]
	var head_views := {"ulisse_testa_fronte": Vector3(0.0, 1.3, -1.3), "ulisse_testa_lato": Vector3(1.3, 1.3, 0.0)}
	for hv: String in head_views:
		cam.fov = 26.0
		cam.global_position = ulisse.global_position + head_views[hv]
		cam.look_at(ulisse.global_position + Vector3(0, 1.22, 0), Vector3.UP)
		for i in 40:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, hv]))
		print("salvata ", hv)
	var trojans := get_nodes_in_group(&"troiani")
	if not trojans.is_empty():
		targets["soldato_troiano"] = trojans[0]
	var archer := main.find_child("Arciere1", true, false) as Node3D
	if archer:
		targets["arciere"] = archer
	# Scudo: viste frontale e laterale di Ulisse e di un acheo, a riposo e dopo qualche passo di camminata.
	var shield_targets := {"ulisse": ulisse}
	if targets.has("soldato_acheo"):
		shield_targets["acheo"] = targets["soldato_acheo"]
	for sk: String in shield_targets:
		var st: Node3D = shield_targets[sk]
		for view in {"fronte": Vector3(0.0, 1.0, -1.7), "lato": Vector3(-1.7, 1.0, 0.0)}:
			cam.fov = 34.0
			cam.global_position = st.global_position + Vector3(view == "fronte" and 0.0 or -1.7, 1.0, -1.7 if view == "fronte" else 0.0)
			cam.look_at(st.global_position + Vector3(0, 0.85, 0), Vector3.UP)
			for i in 40:
				await process_frame
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/scudo_%s_%s.png" % [dir, sk, view]))
			print("salvata scudo ", sk, " ", view)
	for key: String in targets:
		var t: Node3D = targets[key]
		cam.fov = 38.0
		cam.global_position = t.global_position + (Vector3(-1.1, 1.35, -2.0) if key != "arciere" else Vector3(0.0, 1.0, 2.6))
		cam.look_at(t.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		for i in 60:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, key]))
		print("salvata ", key, " ", t.name)
	quit()
