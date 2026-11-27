extends SceneTree
## Barca dei feriti: ogni barca ha il suo soldato fisso (mai spawn dal nulla, mai a terra). Prima: soldato in piedi;
## salita: lo aiuta a salire; durante: ferito sdraiato e soldato seduto che rema; dopo la consegna: ferito sparito e
## soldato ancora a bordo; al ritorno: di nuovo in piedi (la stessa unità). Due viaggi di fila, ogni barca col suo soldato.
## Esecuzione: godot --headless --path . -s res://tests/test_ferry_boat.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _people(boat: Node3D) -> Array:
	var out := []
	for n in boat.find_children("*", "CharacterModel", true, false):
		if (n as Node3D).is_visible_in_tree():
			out.append(n)
	return out

func _initialize() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.duration = 300.0
	rules.first_wave_delay = 999.0
	rules.ferry_sail_time = 2.0
	director.rules = rules
	root.add_child(main)
	await create_timer(0.6).timeout
	var ferry := director.ferry
	var boat: FerrySystem.Boat = ferry.boats[0]
	_check(ferry.boats.size() >= 2 and ferry.boats[0].rowing.rowers[0] != ferry.boats[1].rowing.rowers[0], "each boat has its own permanent soldier")
	var sk: GridUnit = boat.rowing.rowers[0]
	var skm := sk.get_node("Model") as CharacterModel
	_check(_people(boat.node).size() == 1 and skm.stance != &"row", "before: one soldier aboard, standing")
	var ids := [sk.get_instance_id()]
	for k in 2:
		var w: WoundedSoldier = director.wounded[k]
		var j := FerrySystem.Job.new()
		j.wounded = w
		j.phase = FerrySystem.Phase.WAIT_BOAT
		w.state = WoundedSoldier.State.SAVED
		ferry.jobs.append(j)
		var t := 0.0
		while t < 3.0 and not boat.busy:
			await create_timer(0.1).timeout
			t += 0.1
		await create_timer(0.6).timeout
		_check(skm.stance != &"row" and w.visible, "trip %d, boarding: the soldier helps him up, still standing" % (k + 1))
		await create_timer(2.6).timeout
		_check(skm.stance == &"row", "trip %d: the soldier sits and rows" % (k + 1))
		_check(w.get_node("Model").get("dead"), "trip %d: the wounded man lies on the boat" % (k + 1))
		_check(_people(boat.node).size() == 2, "trip %d, sailing: wounded + soldier (%d)" % [k + 1, _people(boat.node).size()])
		t = 0.0
		while t < 8.0 and w.visible:
			await create_timer(0.1).timeout
			t += 0.1
		_check(not w.visible, "trip %d: the wounded man disappears on arrival" % (k + 1))
		_check(_people(boat.node).size() == 1 and sk.get_parent() == boat.rowing, "trip %d: the soldier is still aboard after delivery" % (k + 1))
		t = 0.0
		while t < 10.0 and boat.busy:
			await create_timer(0.1).timeout
			t += 0.1
		_check(not boat.busy, "trip %d: the boat is back" % (k + 1))
		_check(_people(boat.node).size() == 1 and skm.stance != &"row" and is_instance_valid(sk), "trip %d: same soldier, standing again, no ghosts" % (k + 1))
		var rowers := 0
		for n in root.find_children("*", "AllySoldier", true, false):
			if (n as AllySoldier).name.begins_with("Rower") and (n as Node3D).is_visible_in_tree():
				rowers += 1
		_check(rowers == ferry.boats.size(), "trip %d: exactly one soldier per boat in the world (%d)" % [k + 1, rowers])
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
