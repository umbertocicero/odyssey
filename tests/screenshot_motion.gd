extends SceneTree
## Fotogrammi in sequenza dei movimenti NEL LIVELLO (camera ravvicinata che segue il soggetto):
## Ulisse che parte, corre, curva, attacca correndo e si ferma; il ferito che si rialza e zoppica
## sorretto; la barella con quattro portatori; un arciere sulle mura che tira; un troiano che attacca.
## Ogni scena diventa una striscia di fotogrammi (un fotogramma ogni `step` secondi).
## Avvio (con finestra, una Godot alla volta):
##   ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_motion.gd -- --out=movimenti

const CELL := Vector2i(360, 400)

var _out := "movimenti"
var _main: Node
var _cam: Camera3D
var _dir := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	_run.call_deferred()


func _run() -> void:
	_dir = ProjectSettings.globalize_path("res://tests/screenshots/" + _out)
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = load("res://scenes/main/main.tscn").instantiate()
	var director := _main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.duration = 600.0
	rules.first_wave_delay = 999.0
	rules.ferry_sail_time = 2.0
	rules.severe_wounded = 1
	director.rules = rules
	root.add_child(_main)
	for i in 30:
		await process_frame
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	_cam = (_main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	_cam.set_process(false)
	_cam.set_physics_process(false)
	_cam.fov = 34.0
	var hud := _main.get_node_or_null("UI/LevelHud") as Control
	if hud:
		hud.visible = false
	var ulisse := get_first_node_in_group(&"player") as GridUnit

	# 1) Ulisse: partenza, corsa, curva a destra, attacco in corsa, frenata.
	var done := {}
	var plan := func(t: float) -> void:
		Input.action_release(&"move_up")
		Input.action_release(&"move_right")
		if t < 1.6:
			Input.action_press(&"move_up")
		elif t < 2.4:
			Input.action_press(&"move_right")
		if t > 1.2 and not done.has("a"):
			done["a"] = true
			ulisse.emit_signal(&"action_requested", &"attack")
	# In pianura, lontano dalle tende: un ferito lontano dà una casella libera di riferimento.
	var open_ref: WoundedSoldier = director.wounded[2]
	for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2)]:
		if ulisse.place_at(open_ref.cell + d):
			break
	await _strip("ulisse_corsa", ulisse, 3.2, 0.2, Vector3(2.4, 2.0, 2.4), plan)
	Input.action_release(&"move_right")
	# Attacchi da fermo: fendente, affondo, taglio, parata.
	var fight := func(t: float) -> void:
		for at in [0.1, 1.0, 1.9]:
			if t > at and not done.has(at):
				done[at] = true
				ulisse.emit_signal(&"action_requested", &"attack")
		if t > 2.8 and not done.has("p"):
			done["p"] = true
			ulisse.emit_signal(&"action_requested", &"parry")
	await _strip("ulisse_attacchi", ulisse, 3.6, 0.15, Vector3(2.0, 1.5, 1.6), fight)

	# 1b) Duello: un troiano attacca Ulisse, che para, schiva e risponde.
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var foe := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 400, "DuelTrojan") as TrojanSoldier
	foe.attack_interval = 0.9
	var ucell: Vector2i = ulisse.get("cell")
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if grid.is_walkable(ucell + d):
			foe.position = grid.cell_to_world(ucell + d)
			break
	ulisse.get_parent().add_child(foe)
	var duel := func(t: float) -> void:
		var k := int(t / 0.75)
		if not done.has("d%d" % k) and is_instance_valid(foe):
			done["d%d" % k] = true
			var to := foe.global_position - ulisse.global_position
			ulisse.set("_face_yaw", atan2(-to.x, -to.z))
			if k % 2 == 1:
				ulisse.emit_signal(&"action_requested", &"attack")
				ulisse.call(&"_melee_attack")
	await _strip("duello", ulisse, 4.8, 0.15, Vector3(2.6, 1.7, 1.2), duel)
	if is_instance_valid(foe):
		foe.queue_free()

	# 2) Ferito leggero: Ulisse arriva, il ferito si rialza e lo segue zoppicando.
	var w: WoundedSoldier = director.wounded[0]
	for d in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if ulisse.place_at(w.cell + d):
			break
	await _strip("ferito_rialzo", w, 2.4, 0.2, Vector3(2.0, 2.2, 2.0), Callable())
	var walk_away := func(_t: float) -> void:
		Input.action_press(&"move_left")
	await _strip("ferito_sorretto", w, 3.2, 0.2, Vector3(2.6, 2.6, 2.6), walk_away)
	Input.action_release(&"move_left")

	# 3) Ferito grave: la barella con quattro portatori.
	var sv: WoundedSoldier = director.wounded[director.wounded.size() - 1]
	for d in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if ulisse.place_at(sv.cell + d):
			break
	for i in 60:
		await process_frame
	await _strip("barella", sv, 3.2, 0.2, Vector3(3.0, 3.6, 3.0), Callable())

	# 4) Arciere sulle mura: tira e ricarica.
	var archer: WallShooter = null
	for n in get_nodes_in_group(&"wall_shooters"):
		if String((n as Node).scene_file_path).contains("arciere"):
			archer = n
			break
	if archer:
		var shoot := func(t: float) -> void:
			if t > 0.3 and not done.has("s"):
				done["s"] = true
				var target := archer.pick_target()
				archer.fire_at(target.cell if target else ulisse.cell)
		await _strip("arciere", archer, 2.4, 0.15, Vector3(1.6, 0.4, 1.6), shoot, Vector3(0, 1.1, 0))
	print("fatto")
	quit()


## Cattura una striscia di fotogrammi seguendo `subject` (camera a `offset`), chiamando plan(t) ogni frame.
func _strip(name_: String, subject: Node3D, length: float, step: float, offset: Vector3, plan: Callable, look_up := Vector3(0, 0.85, 0)) -> void:
	var n := int(round(length / step))
	var sheet := Image.create(CELL.x * mini(n, 8), CELL.y * int(ceil(n / 8.0)), false, Image.FORMAT_RGB8)
	var t := 0.0
	var next := 0.0
	var idx := 0
	var focus := subject.global_position
	var start := Time.get_ticks_msec()
	while idx < n:
		if plan.is_valid():
			plan.call(t)
		focus = focus.lerp(subject.global_position, 0.15)
		_cam.global_position = focus + offset
		_cam.look_at(focus + look_up, Vector3.UP)
		await process_frame
		t = (Time.get_ticks_msec() - start) / 1000.0
		if t >= next:
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var vs := img.get_size()
			var crop := Rect2i((vs.x - vs.y * CELL.x / CELL.y) / 2, 0, vs.y * CELL.x / CELL.y, vs.y)
			var part := img.get_region(crop)
			part.resize(CELL.x, CELL.y)
			part.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(part, Rect2i(Vector2i.ZERO, CELL), Vector2i((idx % 8) * CELL.x, (idx / 8) * CELL.y))
			idx += 1
			next += step
	sheet.save_png("%s/%s.png" % [_dir, name_])
	print("salvata ", name_)

