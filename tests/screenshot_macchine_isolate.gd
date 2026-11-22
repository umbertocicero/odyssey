extends SceneTree
## Le quattro macchine isolate su sfondo neutro: scala e orientamento (serve una finestra).
## godot --path . -s res://tests/screenshot_macchine_isolate.gd -- --out=macchine_iso

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "macchine_iso"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	world.add_child(sun)
	var items := {
		"catapulta": load("res://scenes/enemies/troiano/catapulta.tscn"),
		"balista": load("res://scenes/enemies/troiano/balista.tscn"),
		"carro": load("res://assets/models/custom/campo/macchine/carro/carro.gltf"),
	}
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	for k: String in items:
		var n := (items[k] as PackedScene).instantiate()
		if n is WallShooter:
			(n as WallShooter).auto_fire = false
		world.add_child(n)
		# Fronte = verso +Z nelle scene dei tiratori, -Z nel carro: la camera guarda da fronte-destra.
		cam.global_position = Vector3(7.0, 1.2, 0.0) if k != "carro" else Vector3(8.0, 1.2, 0.0)
		cam.fov = 25
		cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
		for i in 8:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(dir + "/%s.png" % k))
		n.queue_free()
		await process_frame
	var st := Stretcher.new()
	world.add_child(st)
	cam.global_position = Vector3(2.5, 1.6, 2.5)
	cam.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(dir + "/barella.png"))
	quit()
