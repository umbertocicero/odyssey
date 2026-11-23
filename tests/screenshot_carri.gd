extends SceneTree
## Carri isolati su sfondo neutro da piu angolazioni (serve una finestra).
## godot --path . -s res://tests/screenshot_carri.gd -- --out=carri_before

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "carri"
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
	env.environment.background_color = Color(0.45, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	world.add_child(sun)
	var items := {
		"coperto": "res://assets/models/custom/accampamento/carro_coperto.glb",
		"guerra": "res://assets/models/custom/campo/macchine/carro/carro.gltf",
		"rotto": "res://assets/models/custom/campo/carri/carro_rotto/carro_rotto.gltf",
	}
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	cam.fov = 35
	for k: String in items:
		var n := (load(items[k]) as PackedScene).instantiate()
		world.add_child(n)
		for a in [0, 1, 2]:
			var ang := deg_to_rad(40.0 + 120.0 * a)
			cam.global_position = Vector3(cos(ang), 0.5, sin(ang)) * 9.0
			cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
			for i in 6:
				await process_frame
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(dir + "/%s_%d.png" % [k, a]))
		n.queue_free()
		await process_frame
	quit()
