extends SceneTree
## Screenshot delle mura di Troia e della porta da più angolazioni (serve una finestra).
## DISPLAY=:0 godot --path . -s res://tests/screenshot_mura.gd -- --out=prima [--only=porta] [--quality=high]
## Salva tests/screenshots/mura/<out>_<vista>_<giorno|notte>.png

# vista: [target, distanza, pitch, yaw]
const VIEWS := {
	"insieme": [Vector3(0, 3.5, -21.6), 26.0, -24.0, 8.0],
	"porta": [Vector3(7, 2.6, -21.6), 8.5, -14.0, 0.0],
	"porta_obliqua": [Vector3(7, 2.6, -21.6), 8.5, -16.0, 28.0],
	"sx": [Vector3(-12, 3.2, -21.6), 11.0, -16.0, 6.0],
	"dx": [Vector3(19, 3.2, -21.6), 11.0, -16.0, -6.0],
	"torre": [Vector3(-25, 3.5, -21.6), 9.0, -14.0, 14.0],
	"alto": [Vector3(0, 3.0, -21.6), 16.0, -48.0, 20.0],
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots/mura"))
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
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/mura/%s_%s_%s.png" % [out, v, phase]))
	quit(0)
