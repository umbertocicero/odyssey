extends SceneTree
## HUD con i ritratti dei feriti: vivi a colori (con barra), morti in grigio.
## Avvio: godot --path . -s res://tests/screenshot_wounded_hud.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	rules.duration = 300.0
	director.rules = rules
	root.add_child(main)
	for i in 60:
		await process_frame
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var w := director.wounded
	# Uno rialzato (mezza vita), uno ferito ancora a terra, uno morto dopo essere stato rialzato, uno imbarcato.
	w[0].start_support(ulisse, WoundedSoldier.State.FOLLOWING)
	w[1].start_support(ulisse, WoundedSoldier.State.FOLLOWING)
	w[1].take_damage(1000)
	w[2].start_support(ulisse, WoundedSoldier.State.FOLLOWING)
	w[2].take_damage(8)
	w[3].state = WoundedSoldier.State.EVACUATED
	ulisse.speed_multiplier = 1.0
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/hud_feriti.png"))
	quit()
