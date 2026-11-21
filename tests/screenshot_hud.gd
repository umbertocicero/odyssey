extends SceneTree
## Screenshot dell'HUD in gioco (serve una finestra): desktop 1280x720, telefono in orizzontale
## 844x390 e in verticale 390x844. Avvio: godot --path . -s res://tests/screenshot_hud.gd -- --out=hud

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "hud"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var hud := main.get_node_or_null("UI/LevelHud") as LevelHud
	if hud:
		hud.show_subtitle("Odysseus", "Hold the line, men. The ships wait for no one.", 30.0)
		hud.show_banner("Wave 1: 2 Trojans advance!", 30.0)
	var sizes := {"desktop": Vector2i(1280, 720), "mobile_landscape": Vector2i(844, 390), "mobile_portrait": Vector2i(390, 844)}
	for key: String in sizes:
		DisplayServer.window_set_size(sizes[key])
		root.size = sizes[key]
		for i in 40:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/hud_%s.png" % [dir, key]))
		print("salvata ", key, " ", root.get_visible_rect().size)
	quit()
