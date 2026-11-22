extends SceneTree
## Verifica che Ulisse usi il modello Blender e che le animazioni seguano le azioni.
## Esecuzione: godot --headless --path . -s res://tests/test_ulisse_model.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ulisse := get_first_node_in_group(&"player") as GridUnit
	_check(ulisse != null, "Ulisse esiste")
	var model := ulisse.get_node_or_null(^"Model") as CharacterModel
	_check(model != null and model.player != null, "il modello ha un AnimationPlayer")
	_check(ulisse.get_node_or_null(^"Model/Body") == null, "la capsula verde non c'è più")
	for a in [&"idle", &"walk", &"attack", &"hit", &"death"]:
		_check(model.player.has_animation(a), "animazione %s presente" % a)
	_check(model.current_animation() == &"idle", "da fermo: idle")

	# Direzione davanti: la ossa 'cape' deve stare dietro (+Z locale) se il davanti è -Z.
	var sk := model.instance.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var cape := sk.find_bone("cape")
	var hips := sk.find_bone("hips")
	var dz := 0.0
	if cape >= 0 and hips >= 0:
		dz = sk.get_bone_global_rest(cape).origin.z - sk.get_bone_global_rest(hips).origin.z
	print("INFO  cape - hips lungo Z = ", dz, " (positivo: il davanti è -Z)")

	# Passo: walk.
	var moved := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if ulisse.try_step(d):
			moved = true
			break
	_check(moved, "Ulisse fa un passo")
	await create_timer(0.05).timeout
	_check(model.current_animation() in [&"walk", &"run"], "durante il passo: walk o run (%s)" % model.current_animation())
	await create_timer(0.6).timeout
	_check(model.current_animation() == &"idle", "dopo il passo: idle")

	# Attacco.
	ulisse.action_requested.emit(&"attack")
	await process_frame
	_check(model.current_animation() == &"attack", "azione attacco: attack")
	await create_timer(model.anim_length(&"attack") + 0.3).timeout
	_check(model.current_animation() == &"idle", "finito l'attacco: idle")

	# Colpo.
	ulisse.take_damage(10)
	await process_frame
	_check(model.current_animation() == &"hit", "danno: hit")
	await create_timer(0.8).timeout

	# Morte e rinascita.
	var spawn: Vector2i = ulisse.spawn_cell
	ulisse.take_damage(1000)
	await create_timer(0.2).timeout
	_check(model.current_animation() == &"death" and ulisse.is_defeated, "vita a zero: death e comandi bloccati")
	await create_timer(model.anim_length(&"death") + 1.0).timeout
	_check(not ulisse.is_defeated and ulisse.health == ulisse.max_health, "dopo la morte riappare con la vita piena")
	_check(model.current_animation() == &"idle", "riappare in idle")

	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
