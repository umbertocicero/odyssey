extends SceneTree
## Sequenza di screenshot: una portina laterale si apre, i rinforzi escono e camminano alla postazione.
## DISPLAY=:0 godot --path . -s res://tests/screenshot_reinforcements.gd
## Salva tests/screenshots/rinforzi/seq_N.png

func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame


func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 900.0
	director.rules = rules
	root.add_child(main)
	for i in 40:
		await process_frame
	var clock := get_first_node_in_group(&"level_clock") as LevelClock
	clock.running = false
	clock.rain_chance = 0.0
	clock.time_of_day = 17.5
	for n in get_nodes_in_group(&"wall_shooters"):
		(n as WallShooter).auto_fire = false
	for n in get_nodes_in_group(&"troiani"):
		(n as TrojanSoldier).halt()
	var viewport: SubViewport = main.get_node("GameView/GameViewport")
	var camera := viewport.get_camera_3d()
	camera.set(&"_follow", null)
	camera.set(&"target", Vector3(2.9, 1.8, -19.0))
	camera.set(&"distance", 9.0)
	camera.set(&"pitch_degrees", -14.0)
	camera.set(&"yaw_degrees", 0.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots/rinforzi"))
	await _wait(1.0)
	_shot("seq_0_chiusa")
	# Forza l'ondata dalla portina di destra del riquadro (x=2.9).
	var doors := get_nodes_in_group(&"troy_gates").filter(func(d): return d.kind == 1 and absf(d.global_position.x - 2.9) < 0.1)
	var door: TroyGate = doors[0]
	door.set_open(true, 1.0)
	await _wait(0.5)
	_shot("seq_1_si_apre")
	await _wait(0.9)
	_shot("seq_2_aperta")
	for k in 3:
		director.phase = LevelDirector.Phase.RUNNING
		director._spawn_trojan(1, k, door)
		await _wait(1.0)
	_shot("seq_3_uscita")
	await _wait(1.0)
	_shot("seq_4_uscita2")
	await _wait(2.0)
	_shot("seq_5_cammino")
	quit(0)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/rinforzi/%s.png" % name))
