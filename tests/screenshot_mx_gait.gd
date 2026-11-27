extends SceneTree
## Camminata, corsa e morte con i clip Mixamo retargettati (CharacterModel + MixamoClips): un personaggio che avanza a velocita'
## costante, ripreso di lato, e la sua morte. Una striscia di fotogrammi per scena.
## Avvio (finestra, una Godot alla volta):
##   godot --path . -s res://tests/screenshot_mx_gait.gd -- --model=menelao --out=mx_gait [--mx=0] (mx=0: clip procedurali, per confronto)

const CELL := Vector2i(300, 380)
var _model := "menelao"
var _out := "mx_gait"
var _mx := true


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="): _model = arg.substr(8)
		elif arg.begins_with("--out="): _out = arg.substr(6)
		elif arg.begins_with("--mx="): _mx = arg.substr(5) != "0"
	_run.call_deferred()


func _run() -> void:
	root.size = CELL
	var dir := ProjectSettings.globalize_path("res://tests/screenshots/" + _out)
	DirAccess.make_dir_recursive_absolute(dir)
	var world := Node3D.new(); root.add_child(world)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.62, 0.66, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.75, 0.72, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 35, 0); world.add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 80); ground.mesh = pm
	var gm := StandardMaterial3D.new(); var img := Image.create(128, 128, false, Image.FORMAT_RGB8); img.fill(Color(0.4, 0.37, 0.32))
	for i in 128:
		for k in [0, 1, 64, 65]:
			img.set_pixel(i, k, Color(0.25, 0.22, 0.2)); img.set_pixel(k, i, Color(0.25, 0.22, 0.2))
	gm.albedo_texture = ImageTexture.create_from_image(img); gm.uv1_scale = Vector3(40, 40, 1); ground.material_override = gm; world.add_child(ground)
	var cam := Camera3D.new(); cam.fov = 30.0; world.add_child(cam); cam.current = true
	var mover := Node3D.new(); world.add_child(mover)
	var cm := CharacterModel.new()
	cm.model_scene = load("res://assets/models/custom/personaggi_nuovi/%s/%s.gltf" % [_model, _model])
	cm.mixamo_clips = _mx
	mover.add_child(cm)
	for i in 6: await process_frame
	await _strip(mover, cm, cam, dir, "walk", 1.3, 8, 0.13)
	await _strip(mover, cm, cam, dir, "run", 3.8, 8, 0.08)
	mover.global_position = Vector3.ZERO
	await _strip(mover, cm, cam, dir, "idle", 0.0, 3, 0.4)
	cm.play_death()
	await _strip(mover, cm, cam, dir, "death", 0.0, 8, 0.4)
	quit()


func _strip(mover: Node3D, cm: CharacterModel, cam: Camera3D, dir: String, label: String, v: float, n: int, dt: float) -> void:
	var sheet := Image.create(CELL.x * n, CELL.y, false, Image.FORMAT_RGB8)
	# a regime: un secondo di andatura prima di fotografare
	if v > 0.0:
		var t := 0.0
		while t < 1.2:
			await process_frame
			var d := 1.0 / maxf(Engine.get_frames_per_second(), 30.0)
			mover.global_position += Vector3(0, 0, -v * d); t += d
	for k in n:
		var t := 0.0
		while t < dt:
			await process_frame
			var d := 1.0 / maxf(Engine.get_frames_per_second(), 30.0)
			if v > 0.0:
				mover.global_position += Vector3(0, 0, -v * d)
			t += d
		var p := mover.global_position + Vector3(0, 0.85, 0)
		cam.global_position = p + Vector3(3.2, 0.1, 0)
		cam.look_at(p, Vector3.UP)
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image(); frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * k, 0))
	sheet.save_png("%s/%s.png" % [dir, label])
	print("salvata ", label)
