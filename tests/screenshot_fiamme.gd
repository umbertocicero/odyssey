extends SceneTree
## Fiamme delle torce di notte: screenshot (mano e strada) + misura FPS/VRAM. Serve una finestra.
## DISPLAY=:0 godot --path . -s res://tests/screenshot_fiamme.gd -- --out=before [--quality=high]
func _initialize() -> void:
	_run.call_deferred()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/fiamme_%s.png" % name))

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var out := "test"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var clock := get_first_node_in_group(&"level_clock") as LevelClock
	clock.running = false
	clock.rain_chance = 0.0
	clock.time_of_day = 22.0
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var camera := viewport.get_camera_3d()
	var player := get_first_node_in_group(&"player") as Node3D
	await _wait(10.0)
	camera.set(&"_follow", null)
	camera.set(&"target", player.global_position + Vector3(0, 1.3, 0))
	camera.set(&"distance", 3.0)
	await _wait(2.0)
	await _shot(out + "_mano")
	# torcia sulla strada
	var level := main.get_node("GameView/GameViewport/Level1")
	var t := level.find_child("Torcia1", true, false) as Node3D
	camera.set(&"target", t.global_position + Vector3(0, 2.0, 0))
	camera.set(&"distance", 5.0)
	await _wait(1.5)
	await _shot(out + "_strada")
	await _shot(out + "_strada2")
	# perf: vista sul campo, 8 s
	camera.set(&"target", t.global_position + Vector3(0, 1.0, 0))
	camera.set(&"distance", 14.0)
	await _wait(2.0)
	var times: Array[float] = []
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < 8_000_000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var sum := 0.0
	for x in times:
		sum += x
	var sorted := times.duplicate()
	sorted.sort()
	print("PERF %s quality=%d frame medio=%.2f ms (%.0f FPS) p99=%.2f | VRAM=%.0f MB | draw=%.0f" % [out, Quality.current(), sum / times.size(), 1000.0 / (sum / times.size()), sorted[int(sorted.size() * 0.99)],
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit(0)
