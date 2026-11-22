extends SceneTree
## Colonne davanti all'accampamento solide e lontane dai passaggi; i troiani caduti restano a terra.
## Avvio: godot --headless --path . -s res://tests/test_columns_corpses.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	var director := main.get_node("Director") as LevelDirector
	var rules := LevelRules.new()
	rules.first_wave_delay = 999.0
	director.rules = rules
	root.add_child(main)
	await create_timer(0.6).timeout
	var grid := get_first_node_in_group(&"diorama_grid") as DioramaGrid
	for n in ["ColonnaSpezzata1", "ColonnaSpezzata2", "ColonnaSpezzata3", "Rocchio2"]:
		var p := main.find_child(n, true, false) as GridProp
		_check(p != null and p.blocking and not p.is_vaultable() and p.thin_shape().has("radius"), "%s è solida (non scavalcabile, cerchio di collisione)" % n)
	# Il cavallo e le colonne non stanno sul percorso Ulisse → accampamento.
	var route := [Vector2(-0.6, 7.0), Vector2(-2.5, 9.6), Vector2(-11.0, 11.0)]
	for n in ["CavalloCampo2", "ColonnaSpezzata3", "Rocchio2"]:
		var node := main.find_child(n, true, false) as Node3D
		var c := Vector2(node.global_position.x, node.global_position.z)
		var dmin := INF
		for i in route.size() - 1:
			var cp := Geometry2D.get_closest_point_to_segment(c, route[i], route[i + 1])
			dmin = minf(dmin, c.distance_to(cp))
		_check(dmin > 2.0, "%s a %.1f m dal percorso della demo" % [n, dmin])
	# Un troiano ucciso resta a terra.
	var t := UnitFactory.make(TrojanSoldier, UnitFactory.MODEL_TROIANO, GridUnit.Team.TROIANI, 10, "TroianoTest") as TrojanSoldier
	main.add_child(t)
	t.place_at(Vector2i(grid.size.x / 2, grid.size.y / 2))
	t.take_damage(999)
	await create_timer(4.0).timeout
	_check(is_instance_valid(t) and t.is_inside_tree(), "il troiano caduto resta a terra dopo 4 s")
	_check(t.is_in_group(&"corpses") and not t.is_in_group(&"troiani"), "è un cadavere, non più un nemico")
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
