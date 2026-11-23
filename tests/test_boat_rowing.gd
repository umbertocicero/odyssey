extends SceneTree
## Verifica i rematori imbarcati: seduti sul banco in stance "row", tutti rivolti nella direzione di marcia della
## barca, stessa fase della voga, nessuna animazione di cammino/idle in piedi, remi che seguono i polsi.
## Esecuzione: godot --headless --path . -s res://tests/test_boat_rowing.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _hand_local(cm: CharacterModel, unit: Node3D, bone: StringName) -> Vector3:
	var sk := cm.skeleton
	var w := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
	return unit.to_local(w)

func _initialize() -> void:
	Quality.set_level(Quality.Level.HIGH)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	var ferry := get_first_node_in_group(&"ferry_system") as FerrySystem
	_check(ferry != null and not ferry.boats.is_empty(), "il sistema delle barche esiste")
	if ferry == null or ferry.boats.is_empty():
		quit(1)
		return
	var boat: FerrySystem.Boat = ferry.boats[0]
	ferry._board_crew(boat)
	# La barca naviga in una direzione qualunque (non allineata agli assi).
	boat.node.rotation.y = deg_to_rad(137.0)
	var rowing := boat.rowing
	_check(rowing != null and rowing.rowers.size() >= 2, "almeno due rematori a bordo")
	_check(rowing.oars.size() == rowing.rowers.size() * 2, "due remi per rematore")
	var fwd := -boat.node.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()

	# Campiona un paio di remate mentre la barca si muove (la velocità non deve far camminare nessuno).
	var series: Array = []
	for u in rowing.rowers:
		series.append([])
	var tip_series: Array = []
	var t0 := Time.get_ticks_msec()
	var start_pos := boat.node.global_position
	while (Time.get_ticks_msec() - t0) / 1000.0 < 5.0:
		boat.node.global_position += fwd * 0.05
		await process_frame
		for i in rowing.rowers.size():
			var u := rowing.rowers[i]
			var cm := u.get_node(^"Model") as CharacterModel
			series[i].append(_hand_local(cm, u, &"hand.L").z)
		tip_series.append(rowing.oars[0].global_position)
	_check(boat.node.global_position.distance_to(start_pos) > 0.5, "la barca si è mossa durante il test")

	for i in rowing.rowers.size():
		var u := rowing.rowers[i]
		var cm := u.get_node(^"Model") as CharacterModel
		_check(cm.stance == &"row", "rematore %d in stance row" % i)
		_check(not u.is_moving, "rematore %d non si muove sulla griglia" % i)
		# Nessuna andatura: i rami walk/run e l'idle in piedi hanno peso zero.
		var mv: float = cm.tree.get("parameters/mv_row/blend_amount")
		var ts: float = cm.tree.get("parameters/ts_row/scale")
		_check(is_zero_approx(mv) and is_equal_approx(ts, 1.0), "rematore %d: andatura azzerata, ritmo fisso (mv=%.2f ts=%.2f)" % [i, mv, ts])
		var stance_req = cm.tree.get("parameters/stance/current_state")
		_check(str(stance_req) == "row", "rematore %d: transizione stance = row" % i)
		var uf := -u.global_basis.z
		uf.y = 0.0
		_check(uf.normalized().dot(fwd) > 0.999, "rematore %d rivolto nella direzione di marcia" % i)
		var mf := -cm.instance.global_basis.z * -1.0   # il glb ha il fronte su +Z dello scheletro
		mf = cm.instance.global_basis * Vector3(0, 0, 1)
		mf.y = 0.0
		_check(absf(mf.normalized().dot(fwd)) > 0.99, "rematore %d: modello allineato alla barca" % i)
		# Seduto: l'osso del bacino sta molto più in basso che in piedi.
		var sk := cm.skeleton
		var hips := u.to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hips")).origin)
		_check(hips.y < 0.6 and hips.y > 0.35, "rematore %d seduto (bacino a %.2f m)" % [i, hips.y])
		var s: Array = series[i]
		var lo := 99.0
		var hi := -99.0
		for z in s:
			lo = minf(lo, z)
			hi = maxf(hi, z)
		_check(hi - lo > 0.2, "rematore %d voga: mani avanti/indietro di %.2f m" % [i, hi - lo])

	# Stessa fase: le serie dei polsi dei rematori coincidono.
	var a: Array = series[0]
	var b: Array = series[1]
	var worst := 0.0
	for k in a.size():
		worst = maxf(worst, absf(a[k] - b[k]))
	_check(worst < 0.01, "rematori in fase (scarto massimo %.4f m)" % worst)

	# I remi seguono i polsi: la direzione del remo (verso l'esterno) passa per la mano.
	var ok := true
	for i in rowing.oars.size():
		var l: Array = rowing._links[i]
		var sk: Skeleton3D = l[3]
		var hand: Vector3 = rowing.to_local(sk.global_transform * sk.get_bone_global_pose(l[1]).origin)
		var oar := rowing.oars[i]
		var axis := -oar.basis.z
		var to_hand := (hand - oar.position)
		var off := to_hand - axis * to_hand.dot(axis)
		if off.length() > 0.05 or to_hand.dot(axis) > 0.0:
			ok = false
	_check(ok, "ogni remo passa per la mano del rematore, con l'impugnatura all'interno")
	# E si muovono (oscillano insieme ai rematori).
	var moved := false
	for i in range(1, tip_series.size()):
		if (tip_series[i] as Vector3).distance_to(tip_series[0]) > 0.0:
			moved = true
	_check(moved, "i remi sono montati sulla barca che avanza")

	print("RESULT  ", "OK" if _failures == 0 else "%d FAIL" % _failures)
	quit(_failures)
