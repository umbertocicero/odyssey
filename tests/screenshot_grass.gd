extends SceneTree
## Schermate dell'erba fotorealistica (GrassCards) da più punti e a più ore.
## Serve una finestra (non headless). Qualità alta di default.
## Avvio: DISPLAY=:0 ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_grass.gd -- --out=erba
## Le immagini finiscono in tests/screenshots/<out>/ (ignorata da git).

## nome, bersaglio della camera, distanza, inclinazione (gradi)
const SHOTS := [
	["alto", Vector3(-1, 0, -4), 58.0, -70.0],
	["prato_est", Vector3(12.0, 0, 6.0), 9.0, -35.0],
	["prato_centro", Vector3(-2.0, 0, -2.0), 9.0, -35.0],
	["riva", Vector3(-17.0, 0, 2.0), 9.0, -38.0],
	["sentiero", Vector3(-4.0, 0, 11.0), 8.0, -38.0],
	["nord", Vector3(2.0, 0, -18.0), 12.0, -40.0],
	["radente", Vector3(6.0, 0, 0.0), 6.0, -14.0],
	["gioco", Vector3(4.0, 0, 2.0), 20.0, -42.0],
]
const HOURS := {"giorno": 14.0, "tramonto": 19.5, "notte": 22.5}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "erba"
	var hours: Array = HOURS.keys()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		if arg.begins_with("--hours="):
			hours = arg.substr(8).split(",")
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var clock := get_first_node_in_group(&"level_clock") as LevelClock
	if clock:
		clock.running = false
		clock.rain_chance = 0.0
	var ulisse := get_first_node_in_group(&"player") as Node3D
	if ulisse:
		ulisse.set_physics_process(false)
	var camera: Camera3D = main.get_node("GameView/GameViewport").get_camera_3d()
	camera.set(&"_follow", null)
	var cards := get_first_node_in_group(&"grass_cards")
	if cards:
		print("ciuffi=", cards.get(&"tuft_count"), " blocchi=", cards.get(&"block_count"), " triangoli=", cards.get(&"triangle_count"))
	for hour_name: String in hours:
		if clock:
			clock.time_of_day = HOURS[hour_name]
		for shot in SHOTS:
			camera.set(&"target", shot[1])
			camera.set(&"distance", shot[2])
			camera.set(&"pitch_degrees", shot[3])
			for i in 45:
				await process_frame
			var path := "%s/%s_%s.png" % [dir, shot[0], hour_name]
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("salvata ", path)
	quit(0)
