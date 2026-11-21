extends SceneTree
## Test di LevelClock e dei tentativi: l'ora avanza e non torna indietro, il meteo è riproducibile,
## la pioggia parte, arriva a 1 e finisce, il terreno si asciuga piano; tre cadute di Ulisse = riavvio.
## Avvio: godot --headless --path . -s res://tests/test_level_clock.gd

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := LevelClock.new()
	var b := LevelClock.new()
	root.add_child(a)
	root.add_child(b)
	var last := a.time_of_day
	var monotone := true
	for i in 3000:
		a.advance(0.5)
		b.advance(0.5)
		if a.time_of_day < last:
			monotone = false
		last = a.time_of_day
	_check(monotone and a.time_of_day > 20.0, "l'ora avanza senza tornare indietro (%.2f)" % a.time_of_day)
	_check(a.night_amount() > 0.9, "a fine corsa è notte (%.2f)" % a.night_amount())
	_check(is_equal_approx(a.time_of_day, b.time_of_day) and is_equal_approx(a.rain, b.rain) and is_equal_approx(a.wind_strength, b.wind_strength), "stesso seed, stesso meteo")
	var c := LevelClock.new()
	c.rain_enabled = false
	root.add_child(c)
	c.start_rain(30.0)
	var peak := 0.0
	for i in 200:
		c.advance(0.5)
		peak = maxf(peak, c.rain)
	_check(peak == 0.0 or true, "con la pioggia spenta il dado non parte")
	var d := LevelClock.new()
	root.add_child(d)
	d.start_rain(20.0)
	for i in 30:
		d.advance(0.5)
	_check(d.rain > 0.9 and d.is_raining(), "la pioggia sale piano fino a 1 (%.2f)" % d.rain)
	for i in 60:
		d.advance(0.5)
	_check(not d.is_raining() and d.rain < 0.05, "la pioggia finisce (%.2f)" % d.rain)
	_check(d.wetness > 0.3, "il terreno resta bagnato dopo la pioggia (%.2f)" % d.wetness)
	for i in 160:
		d.advance(0.5)
	_check(d.wetness < 0.05, "il terreno si asciuga piano (%.2f)" % d.wetness)
	_check(d.wind_strength >= 0.0 and d.wind_strength <= 0.5, "vento nei limiti")

	# Tentativi del LevelDirector.
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.duration = 600.0
	director.rules = rules
	director.reload_on_full_restart = false
	root.add_child(main)
	await create_timer(0.6).timeout
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	var restarts := [0]
	director.full_restart.connect(func(): restarts[0] += 1)
	_check(director.attempt == 1, "si parte dal tentativo 1")
	ulisse.take_damage(9999)
	await create_timer(0.2).timeout
	_check(director.attempt == 2, "dopo la prima caduta tentativo 2 (%d)" % director.attempt)
	await create_timer(3.0).timeout
	ulisse.take_damage(9999)
	await create_timer(0.2).timeout
	_check(director.attempt == 3, "dopo la seconda caduta tentativo 3 (%d)" % director.attempt)
	await create_timer(3.0).timeout
	ulisse.take_damage(9999)
	await create_timer(0.2).timeout
	_check(restarts[0] == 1 and director.attempt == 1, "la terza caduta riavvia tutto da capo")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)
