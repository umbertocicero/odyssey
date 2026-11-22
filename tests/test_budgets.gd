extends SceneTree
## Tetti per qualità: luci puntiformi della notte (torce 1/5/9, luci sulle mura 0/3/5) e particelle totali
## attive del livello (battaglia, fumo, meteo, fuochi... contate tutte) ≤ 60 / 250 / 600.
## Avvio: godot --headless --path . -s res://tests/test_budgets.gd

var _failures := 0
const PARTICLE_CAP := [60, 250, 600]
const TORCHES := [1, 5, 9]
const WALL_LIGHTS := [0, 3, 5]


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for q in [0, 1, 2]:
		Quality.set_level(q)
		var level: Node = load("res://scenes/levels/level1/level1.tscn").instantiate()
		root.add_child(level)
		for i in 8:
			await process_frame
		var total := 0
		for n in level.find_children("*", "CPUParticles3D", true, false):
			var p := n as CPUParticles3D
			if p.is_inside_tree() and p.visible:
				total += p.amount
		var night := level.get_node("CicloNotte") as NightCycle
		var walls := night.wall_lights.size()
		_check(night.torch_lights.size() == TORCHES[q], "q=%d: torce dei soldati %d" % [q, night.torch_lights.size()])
		_check(walls == WALL_LIGHTS[q], "q=%d: luci sulle mura %d" % [q, walls])
		_check(total <= PARTICLE_CAP[q], "q=%d: particelle totali %d <= %d" % [q, total, PARTICLE_CAP[q]])
		root.remove_child(level)
		level.free()
		await process_frame
	print("RISULTATO: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)
