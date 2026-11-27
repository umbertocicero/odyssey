extends SceneTree
## Screenshot dell'HUD per ogni modo del filtro (K): 0 = spento ... 4.
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_hud_pixelart.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := ProjectSettings.globalize_path("res://tests/screenshots/hud_pixelart")
	DirAccess.make_dir_recursive_absolute(dir)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 90:
		await process_frame
	var clock := get_first_node_in_group(&"level_clock") as LevelClock
	if clock:
		clock.running = false
	var director := main.get_node("Director")
	var hud: LevelHud = director.hud
	hud.show_subtitle("Odysseus", "Hold the line, men!", 60.0)
	for mode in 5:
		main.pixelart_mode = mode
		main.pixelart_variant = 0
		hud.show_banner("Wave 1: 2 Trojans advance!", 60.0)
		hud._banner_alpha = 0.5   # banner a metà dissolvenza
		main._show_mode_toast()
		main._toast_tween.kill()
		main._toast.modulate.a = 1.0
		for i in 30:
			await process_frame
		hud._banner_alpha = 0.5
		root.get_texture().get_image().save_png("%s/hud_mode%d.png" % [dir, mode])
		hud.show_end({"title": "Level complete", "text": "You held the line.", "saved": 3, "total": 4,
			"evacuated": 2, "kills": 7, "waves": 3, "score": 1200})
		for i in 20:
			await process_frame
		root.get_texture().get_image().save_png("%s/end_mode%d.png" % [dir, mode])
		hud._end_panel.visible = false
	# Ritorno a filtro spento e prova del click sul pulsante della schermata finale con un modo attivo.
	main.pixelart_mode = 3
	hud.show_end({"title": "Level complete", "text": "x", "saved": 1, "total": 1, "evacuated": 0, "kills": 0, "waves": 1, "score": 1})
	for i in 20:
		await process_frame
	var pressed := [false]
	hud.continue_pressed.connect(func(): pressed[0] = true)
	var c := hud._continue.get_global_rect().get_center()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = c
		ev.global_position = c
		Input.parse_input_event(ev)
		for i in 5:
			await process_frame
	print("CLICK END BUTTON with filter on: ", pressed[0])
	hud._end_panel.visible = false
	main.pixelart_mode = 0
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png("%s/hud_back_off.png" % dir)
	quit()
