extends SceneTree
## Screenshot delle pose procedurali (idle, walk, run, attack, block, jump) di Ulisse e di un acheo, da vicino.
## Avvio: ODYSSEY_QUALITY=high godot --path . -s res://tests/screenshot_poses.gd -- --out=animazioni

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "animazioni"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	var dir := "res://tests/screenshots/" + out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var ulisse := get_first_node_in_group(&"player") as Node3D
	var model := ulisse.get_node("Model") as CharacterModel
	var cam: Camera3D = (main.get_node("GameView/GameViewport") as SubViewport).get_camera_3d()
	cam.set_process(false)
	var hud := main.get_node_or_null("UI/LevelHud") as Control
	if hud:
		hud.visible = false
	cam.fov = 30.0
	cam.global_position = ulisse.global_position + Vector3(2.0, 1.2, -1.6)
	cam.look_at(ulisse.global_position + Vector3(0, 0.8, 0), Vector3.UP)
	ulisse.get_node("Model").rotation.y = deg_to_rad(-70.0)
	for name_ in ["idle", "walk", "run", "attack", "block", "jump"]:
		var t: float = {"idle": 1.1, "walk": 0.25, "run": 0.15, "attack": 0.3, "block": 0.3, "jump": 0.42}[name_]
		model.player.speed_scale = 1.0
		model.player.play(name_, 0.0)
		model._busy_until = Time.get_ticks_msec() / 1000.0 + 5.0
		while model.player.current_animation_position < t and model.player.is_playing():
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/pose_%s.png" % [dir, name_]))
		print("salvata ", name_, " anim=", model.player.current_animation, " pos=", model.player.current_animation_position, " playing=", model.player.is_playing())
	quit()
