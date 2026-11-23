extends SceneTree
## Morte dei soldati: clip scelta secondo la direzione del colpo, corpo fermo e a terra (quota giusta,
## niente compenetrazione), niente collisioni, anche se muore mentre cammina.
## Avvio: godot --headless --path . -s res://tests/test_death_variants.gd   (con --shots=<cartella>: screenshot, serve la finestra)

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1


func _bones_y(m: CharacterModel) -> Vector2:
	var sk := m.instance.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var lo := INF
	var hi := -INF
	for i in sk.get_bone_count():
		var y := (sk.global_transform * sk.get_bone_global_pose(i)).origin.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return Vector2(lo, hi)


func _initialize() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	(main.get_node("Director") as LevelDirector).rules = rules
	root.add_child(main)
	await create_timer(0.6).timeout
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var spot := grid.world_to_cell(Vector3(-9.0, 0.0, 4.0))
	var cx := spot.x
	var cz := spot.y
	# (squadra, direzione del colpo rispetto al verso del soldato, clip attesa); il soldato guarda -Z (face).
	var cases := [
		["troiano", Vector3(0, 0, 1), &"death"],          # colpito da davanti (colpo verso +Z, lui guarda -Z)
		["troiano", Vector3(0, 0, -1), &"death_front"],   # da dietro
		["acheo", Vector3(1, 0, 0), &"death_side_r"],
		["acheo", Vector3(-1, 0, 0), &"death_side_l"],
		["troiano", Vector3.ZERO, &""],                   # senza direzione: una qualunque
		["acheo", Vector3(0, 0, 1), &"death"],
	]
	var units: Array = []
	var i := 0
	for cs in cases:
		var troy: bool = cs[0] == "troiano"
		var u: GridUnit
		if troy:
			u = UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 10, "T%d" % i)
		else:
			u = UnitFactory.make(AllySoldier, UnitFactory.MODEL_ACHEO, GridUnit.Team.ACHEI, 10, "A%d" % i)
		main.add_child(u)
		u.place_at(Vector2i(cx - 6 + i * 2, cz))
		u.face(Vector2i(0, -1))
		if troy:
			(u as TrojanSoldier)._halted = true
		else:
			u.set_physics_process(false)   # niente IA: resta dov'e', rivolto a -Z
		units.append(u)
		i += 1
	await create_timer(0.5).timeout
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	i = 0
	for cs in cases:
		(units[i] as GridUnit).take_damage(999, cs[1])
		i += 1
	# Il settimo muore a meta' passo.
	var walker := UnitFactory.make(AllySoldier, UnitFactory.MODEL_ACHEO, GridUnit.Team.ACHEI, 10, "Walker")
	main.add_child(walker)
	walker.place_at(Vector2i(cx - 6, cz + 3))
	walker.set_physics_process(false)
	await create_timer(0.3).timeout
	walker.is_moving = true
	var tw := walker.create_tween()
	walker._tween = tw
	tw.tween_property(walker, "global_position:x", walker.global_position.x + 3.0, 1.5)
	await create_timer(0.3).timeout
	walker.take_damage(999, Vector3(0, 0, 1))
	var wpos := walker.global_position
	if shots != "":
		await _shots(units, shots)
	await create_timer(3.0).timeout
	i = 0
	for cs in cases:
		var u := units[i] as GridUnit
		var m := u._model as CharacterModel
		var tag := "%s[%d]" % [cs[0], i]
		_check(is_instance_valid(u) and u.is_inside_tree() and u.is_in_group(&"corpses"), "%s resta a terra come cadavere" % tag)
		if cs[2] != &"":
			_check(m.current_animation() == &"death" and m._dead_clip == cs[2], "%s clip %s (scelta: %s)" % [tag, cs[2], m._dead_clip])
		else:
			_check(CharacterModel.DEATH_CLIPS.has(m._dead_clip), "%s senza direzione: clip valida (%s)" % [tag, m._dead_clip])
		var coll := true
		for c in u.get_children():
			if c is CollisionShape3D and not c.disabled:
				coll = false
		_check(coll, "%s nessuna collisione attiva" % tag)
		var p0 := m.global_position
		var yb := _bones_y(m)
		var gy := ClashFx.ground_y(u.global_position)
		await create_timer(0.5).timeout
		_check(m.global_position.distance_to(p0) < 0.001, "%s corpo fermo" % tag)
		_check(yb.x > gy - 0.12 and yb.y < gy + 0.85, "%s a terra (ossa da %.2f a %.2f sul terreno %.2f)" % [tag, yb.x - gy, yb.y - gy, gy])
		i += 1
	_check(walker.is_in_group(&"corpses") and not walker.is_moving, "morto durante il passo: cadavere, fermo")
	_check(walker.global_position.distance_to(wpos) < 0.01, "morto durante il passo: il corpo non scivola via sul tween")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)


func _shots(units: Array, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots/" + dir))
	var mid := (units[0] as Node3D).global_position.lerp((units[units.size() - 1] as Node3D).global_position, 0.5)
	var vp: SubViewport = root.get_node("Main/GameView/GameViewport") if root.has_node("Main/GameView/GameViewport") else get_first_node_in_group(&"diorama_grid").get_tree().root.find_child("GameViewport", true, false)
	var cam := vp.get_camera_3d()
	cam.set(&"_follow", null)
	cam.set(&"target", mid + Vector3(0, 0.1, 0))
	cam.set(&"distance", 7.0)
	cam.set(&"pitch_degrees", -50.0)
	cam.set(&"yaw_degrees", 0.0)
	for pr in root.find_children("*", "GridProp", true, false):
		(pr as Node3D).visible = false      # tende e casse non coprono la scena
	var n := 0
	for t in [0.3, 0.25, 0.35, 1.5]:
		await create_timer(t).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/%s/death_%d.png" % [dir, n]))
		n += 1
