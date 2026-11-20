extends SceneTree
## Screenshot dei props Poly Haven nel livello 1 (serve una finestra).
## DISPLAY=:0 godot --path . -s res://tests/tools/shot_polyhaven.gd -- [--quality=high] [--noprops] [--tag=x]
## Inietta PolyhavenProps prima di "Griglia", come farà level1.tscn.

const DATA := "res://data/props/level1_polyhaven.json"
const SHOTS := {
	"pianura": Vector2i(24, 20),
	"mura": Vector2i(26, 7),
	"rilievo": Vector2i(8, 10),
	"cresta": Vector2i(35, 9),
	"accampamento": Vector2i(6, 31),
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var noprops := false
	var tag := "props"
	for a in OS.get_cmdline_user_args():
		if a == "--noprops":
			noprops = true
			tag = "base"
		if a.begins_with("--tag="):
			tag = a.substr(6)
	var close_cell := Vector2i(0, 0)
	var want_close := false
	var close_dist := 8.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cell="):
			var p := a.substr(7).split(",")
			close_cell = Vector2i(int(p[0]), int(p[1]))
			want_close = true
		if a.begins_with("--dist="):
			close_dist = float(a.substr(7))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var level := main.get_node("GameView/GameViewport/Level1")
	var props: PolyhavenProps = null
	if not noprops:
		props = PolyhavenProps.new()
		props.name = "PropsPolyhaven"
		props.data_path = DATA
		level.add_child(props)
		level.move_child(props, level.get_node("Griglia").get_index())
	root.add_child(main)
	for i in 40:
		await process_frame
	if props:
		print("STATS ", props.stats, " tuned=", props._tuned.size())
	var ulisse = get_first_node_in_group(&"player")
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var camera := viewport.get_camera_3d()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots/polyhaven"))
	if want_close:
		camera.set(&"_follow", null)
		camera.set(&"target", Vector3(close_cell.x, 1.5, close_cell.y))
		camera.set(&"distance", close_dist)
		for i in 90:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/polyhaven/%s_closeup.png" % tag))
		print("closeup")
		quit(0)
		return
	for shot_name: String in SHOTS:
		ulisse.place_at(SHOTS[shot_name])
		for i in 80:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/polyhaven/%s_%s.png" % [tag, shot_name]))
	if camera:
		camera.set(&"_follow", null)
		camera.set(&"target", Vector3(0, 0, -4))
		camera.set(&"distance", 100.0)
		for i in 30:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/polyhaven/%s_panoramica.png" % tag))
	print("fine")
	quit(0)
