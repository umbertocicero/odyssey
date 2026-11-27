extends SceneTree
## Screenshot del bordo ovest del mare (la cascata che cade lungo il fianco del diorama).
## Avvio: godot --path . -s res://tests/screenshot_sea_edge.gd [-- nome_suffisso]
## Le immagini finiscono in tests/screenshots/.

## Camere libere fuori dal blocco (la camera di gioco è vincolata): posizione e punto guardato.
const VIEWS := {
	"fronte": {"pos": Vector3(-50, -3, 1.5), "look": Vector3(-32, -4, 1.5), "fov": 50.0},
	"basso": {"pos": Vector2(0, 0), "look": Vector3(-32, -6, 4), "fov": 60.0, "pos3": Vector3(-42, -9, 20)},
	"alto": {"pos": Vector3(-42, 8, 8), "look": Vector3(-32, -4, 4), "fov": 55.0},
	"gioco": {"pos": Vector3(-8, 14, 26), "look": Vector3(-26, -1, 6), "fov": 45.0},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var suffix := "dopo"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		suffix = args[0]
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	for i in 40:
		await process_frame
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var cam := Camera3D.new()
	cam.far = 400.0
	viewport.add_child(cam)
	cam.make_current()
	for view_name: String in VIEWS:
		var v: Dictionary = VIEWS[view_name]
		cam.fov = v["fov"]
		cam.global_position = v["pos3"] if v.has("pos3") else v["pos"]
		cam.look_at(v["look"])
		for i in 40:
			await process_frame
		var path := "res://tests/screenshots/sea_edge_%s_%s.png" % [view_name, suffix]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("salvata ", path)
	quit(0)
