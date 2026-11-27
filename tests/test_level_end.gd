extends SceneTree
## Il livello finisce quando TUTTI i feriti sono sulle navi (senza timer), non prima.
## Avvio: godot --headless --path . -s res://tests/test_level_end.gd

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	director.rules = rules
	root.add_child(main)
	await create_timer(0.8).timeout
	_check(rules.duration >= 600.0, "nessun timer breve di ritirata (%.0f s)" % rules.duration)
	_check(director.phase == LevelDirector.Phase.RUNNING and not director.all_wounded_resolved(), "all'inizio il livello corre")
	for i in director.wounded.size() - 1:
		director.wounded[i].state = WoundedSoldier.State.EVACUATED
	await create_timer(1.2).timeout
	_check(director.phase == LevelDirector.Phase.RUNNING, "con un ferito ancora a terra il livello continua")
	var last := director.wounded[director.wounded.size() - 1]
	last.take_damage(1000)   # still lying: untouchable
	await create_timer(1.2).timeout
	_check(director.phase == LevelDirector.Phase.RUNNING and last.health > 0, "a lying wounded man cannot die; the level keeps going")
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	last.start_support(ulisse, WoundedSoldier.State.FOLLOWING)   # helped up: now he can be killed
	last.take_damage(1000)
	await create_timer(1.2).timeout
	_check(last.state == WoundedSoldier.State.LOST and director.lost_count() == 1, "a raised wounded man can die and counts as lost")
	_check(director.phase == LevelDirector.Phase.ENDED, "all wounded saved or lost: the level ends")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)
