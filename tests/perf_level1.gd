extends SceneTree
## Misure di prestazioni del livello 1 (serve una finestra, non headless).
## DISPLAY=:0 godot --path . -s res://tests/perf_level1.gd -- --quality=high [--hide=grass] [--hide=particles]
## 3 s di assestamento + 10 s di misura; vsync spento per vedere il costo reale.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var hide_grass := false
	var hide_particles := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--hide=grass":
			hide_grass = true
		if arg == "--hide=particles":
			hide_particles = true
	var t0 := Time.get_ticks_msec()
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var load_ms := Time.get_ticks_msec() - t0
	var level := main.get_node("GameView/GameViewport/Level1")
	if hide_grass:
		level.get_node("ErbaMossa").visible = false
		level.get_node("Cespugli").visible = false
		level.get_node("ErbaFotorealistica").visible = false
	var parts := 0
	if hide_particles:
		for n in level.find_children("*", "CPUParticles3D", true, false):
			(n as Node3D).visible = false
			(n as CPUParticles3D).emitting = false
			parts += 1
	var settle := Time.get_ticks_msec()
	while Time.get_ticks_msec() - settle < 3000:
		await process_frame
	var times: Array[float] = []
	var draw := 0.0
	var prim := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	var samples := 0
	while Time.get_ticks_usec() - start < 10_000_000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		samples += 1
	var sum := 0.0
	var peak := 0.0
	for t in times:
		sum += t
		peak = maxf(peak, t)
	var mean := sum / times.size()
	var sorted := times.duplicate()
	sorted.sort()
	print("PERF quality=%s hide_grass=%s hide_particles=%s(%d nodi) | load=%d ms | frame medio=%.2f ms (%.0f FPS) p99=%.2f picco=%.2f | draw=%.0f prim=%.0f | VRAM=%.0f MB texmem=%.0f MB" % [
		["low", "medium", "high"][Quality.current()], hide_grass, hide_particles, parts, load_ms,
		mean, 1000.0 / mean, sorted[int(sorted.size() * 0.99)], peak, draw / samples, prim / samples,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0])
	quit(0)
