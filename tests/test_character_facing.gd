extends SceneTree
## Test headless dell'orientamento dei personaggi: il fronte del modello (dai piedi: le punte stanno
## davanti alle caviglie) deve coincidere con la direzione in cui l'unità guarda. GridUnit e Ulisse
## ruotano il nodo Model in modo che -Z guardi nella direzione del passo; WallShooter (arcieri)
## usa +Z. Per ogni scena si controlla il fronte con Model non ruotato e ruotato in 4 direzioni.
## Avvio: godot --headless --path . -s res://tests/test_character_facing.gd

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1


## Fronte del modello nello spazio globale (XZ): dai vertici bassi (punte dei piedi) verso la caviglia.
func _front(root_node: Node3D) -> Vector2:
	var skeleton := root_node.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ankle := Vector3.ZERO
	var n := 0
	for b in ["foot.L", "foot.R"]:
		ankle += skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(b)).origin
		n += 1
	ankle /= n
	var toes := Vector3.ZERO
	var count := 0
	for m in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.get_parent() is BoneAttachment3D or mi.get_parent().get_parent() is BoneAttachment3D or mi.get_parent().get_parent().get_parent() is BoneAttachment3D:
			continue   # armi e scudi non contano per il fronte
		var arrays := mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var origin_y := root_node.global_position.y
		for v in verts:
			var g := mi.global_transform * v
			if g.y - origin_y < 0.07:
				toes += g
				count += 1
	if count == 0:
		return Vector2.ZERO
	toes /= count
	return Vector2(toes.x - ankle.x, toes.z - ankle.z).normalized()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scenes := {
		"Ulisse": "res://scenes/characters/ulisse/ulisse.tscn",
		"soldato_acheo": "res://scenes/characters/achei/soldato_acheo.tscn",
		"soldato_troiano": "res://scenes/enemies/troiano/soldato_troiano.tscn",
	}
	for key: String in scenes:
		var unit := load(scenes[key]).instantiate() as Node3D
		root.add_child(unit)
		await process_frame
		await process_frame
		var model := unit.get_node("Model") as Node3D
		for dir in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]:
			model.rotation.y = atan2(-dir.x, -dir.z)   # come GridUnit.face()
			if "_face_yaw" in unit:
				unit.set("_face_yaw", model.rotation.y)  # Ulisse riporta il modello verso la sua direzione
			await create_timer(0.6).timeout           # il modello gira con una curva morbida
			var f := _front(unit)
			_check(f.dot(Vector2(dir.x, dir.z)) > 0.3, "%s: guarda verso %s (fronte %s)" % [key, dir, f.snapped(Vector2(0.01, 0.01))])
		unit.queue_free()
		await process_frame
	# Unità create da UnitFactory (feriti, portatori, ondate): stesso modello.
	var wounded := UnitFactory.make(WoundedSoldier, UnitFactory.MODEL_ACHEO, GridUnit.Team.ACHEI, 40, "WoundedTest")
	root.add_child(wounded)
	await process_frame
	await process_frame
	var wm := wounded.get_node("Model") as Node3D
	wm.rotation.y = atan2(0.0, -1.0) + PI   # guarda verso -Z
	(wm as CharacterModel).revive()          # il ferito si rialza (sdraiato i piedi puntano in alto)
	await create_timer(2.4).timeout
	_check(_front(wounded).dot(Vector2(0, -1)) > 0.5, "ferito (UnitFactory): guarda verso -Z")
	wounded.queue_free()
	# Arcieri sulle mura: WallShooter orienta Model con atan2(dx, dz): il fronte è +Z.
	var archer := load("res://scenes/enemies/troiano/arciere_mura.tscn").instantiate() as Node3D
	root.add_child(archer)
	await process_frame
	await process_frame
	_check(_front(archer).dot(Vector2(0, 1)) > 0.5, "arciere sulle mura: fronte verso +Z (convenzione WallShooter)")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)
