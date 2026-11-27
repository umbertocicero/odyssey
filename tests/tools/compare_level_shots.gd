extends SceneTree
## Screenshot di più punti del livello 1 e misura di FPS/VRAM, con il livello preso da un'altra scena
## (per confrontare prima e dopo). Serve una finestra: DISPLAY=:0 godot --path . -s res://tests/tools/compare_level_shots.gd -- --tag=dopo [--level=res://...tscn]
## Immagini in tests/screenshots/confronto_<tag>_<punto>.png (cartella ignorata da git).

const SHOTS := {
	"campo": Vector2i(6, 31),
	"casse": Vector2i(8, 30),
	"pianura": Vector2i(24, 20),
	"mura": Vector2i(26, 7),
	"porta": Vector2i(24, 7),
	"rilievo": Vector2i(8, 10),
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var tag := "dopo"
	var level_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.substr(6)
		elif arg.begins_with("--level="):
			level_path = arg.substr(8)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	if level_path != "":
		var old := main.get_node("GameView/GameViewport/Level1")
		var parent := old.get_parent()
		var idx := old.get_index()
		parent.remove_child(old)
		old.free()
		var fresh: Node = load(level_path).instantiate()
		fresh.name = "Level1"
		parent.add_child(fresh)
		parent.move_child(fresh, idx)
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	for i in 40:
		await process_frame
	var ulisse = get_first_node_in_group(&"player")
	for shot_name: String in SHOTS:
		ulisse.place_at(SHOTS[shot_name])
		for i in 90:
			await process_frame
		var path := "res://tests/screenshots/confronto_%s_%s.png" % [tag, shot_name]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	ulisse.place_at(Vector2i(8, 30))
	var settle := Time.get_ticks_msec()
	while Time.get_ticks_msec() - settle < 3000:
		await process_frame
	var start := Time.get_ticks_usec()
	var last := start
	var times: Array[float] = []
	var draw := 0.0
	while Time.get_ticks_usec() - start < 8_000_000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var sum := 0.0
	for t in times:
		sum += t
	var sorted := times.duplicate()
	sorted.sort()
	print("PERF %s | frame medio=%.2f ms (%.0f FPS) p99=%.2f | draw=%.0f | VRAM=%.0f MB texmem=%.0f MB | nodi=%d" % [tag, sum / times.size(),
		1000.0 * times.size() / sum, sorted[int(sorted.size() * 0.99)], draw / times.size(),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	quit()
