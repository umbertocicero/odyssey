extends SceneTree
## Screenshot di mare e riva da più angolazioni, giorno e notte (serve una finestra).
## DISPLAY=:0 godot --path . -s res://tests/screenshot_riva.gd -- --out=prima [--quality=high]
## Salva tests/screenshots/riva/<out>_<vista>_<giorno|notte>.png

const VIEWS := {
	"alto": [Vector3(-21, 0, 11.5), 14.0, -55.0, 30.0],
	"insieme": [Vector3(-21, 0, 4), 34.0, -38.0, 30.0],
	"radente": [Vector3(-21, 0, 11.5), 9.0, -22.0, 60.0],
	"nave": [Vector3(-20, 0, -4), 12.0, -40.0, 100.0],
	"imbarco": [Vector3(-21, 0, 12), 7.0, -35.0, 20.0],
	"sud": [Vector3(-21, 0, 18), 14.0, -45.0, 150.0],
}


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame


func _run() -> void:
	var out := "test"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--only="):
			only = a.substr(7)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var clock := get_first_node_in_group(&"level_clock") as LevelClock
	clock.running = false
	clock.rain_chance = 0.0
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var camera := viewport.get_camera_3d()
	camera.set(&"_follow", null)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots/riva"))
	for phase in ["giorno", "notte"]:
		clock.time_of_day = 16.0 if phase == "giorno" else 22.0
		await _wait(4.0)
		for v: String in VIEWS:
			if only != "" and v != only:
				continue
			var cfg: Array = VIEWS[v]
			camera.set(&"target", cfg[0])
			camera.set(&"distance", cfg[1])
			camera.set(&"pitch_degrees", cfg[2])
			camera.set(&"yaw_degrees", cfg[3])
			await _wait(1.2)
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/riva/%s_%s_%s.png" % [out, v, phase]))
	quit(0)
