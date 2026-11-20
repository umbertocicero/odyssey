extends SceneTree
## Verifica luci morbide, falò con particelle e flicker, ombre di contatto, oggetti inclinati.
## Esecuzione: godot --headless --path . -s res://tests/test_atmosphere.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  "), what)
	if not ok:
		_failures += 1

func _initialize() -> void:
	Quality.set_level(Quality.Level.HIGH)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	var level := main.get_node("GameView/GameViewport/Level1")
	var atmo := level.get_node_or_null(^"Atmosfera") as LevelAtmosphere
	_check(atmo != null, "il nodo Atmosfera esiste nel livello")
	var sun := level.get_node("Sole") as DirectionalLight3D
	_check(sun.shadow_opacity < 0.8, "ombre del sole più leggere (opacità %.2f)" % sun.shadow_opacity)
	var dir := -sun.global_basis.z
	_check(rad_to_deg(asin(-dir.y)) > 15.0 and rad_to_deg(asin(-dir.y)) < 30.0, "sole basso di tramonto, ombre lunghe e morbide (%.0f°)" % rad_to_deg(asin(-dir.y)))
	var we := level.get_node("WorldEnvironment") as WorldEnvironment
	var sky_material := we.environment.sky.sky_material
	if sky_material is ShaderMaterial:
		_check((sky_material as ShaderMaterial).get_shader_parameter(&"sun_dir") is Vector3, "cielo di tramonto (sky_dusk): il sole sta dove sta la luce")
	else:
		var sky := sky_material as ProceduralSkyMaterial
		_check(sky.sky_top_color.b > sky.sky_top_color.r, "cielo azzurro in alto: ambiente freddo nelle ombre")
	_check(atmo.fire_lights.size() > 0, "luci del fuoco registrate (%d)" % atmo.fire_lights.size())
	var l := atmo.fire_lights[0]
	var e0 := l.light_energy
	var changed := false
	for i in 30:
		await process_frame
		if absf(l.light_energy - e0) > 0.001:
			changed = true
	_check(changed, "la luce del falò oscilla")
	_check(level.find_child("FumoFalo", true, false) != null, "fumo del falò presente")
	_check(level.find_child("ScintilleFalo", true, false) != null, "scintille del falò presenti")
	_check(atmo.contact_count > 10, "ombre di contatto sotto gli oggetti (%d)" % atmo.contact_count)
	_check(atmo.tilted_count > 0, "oggetti a terra inclinati: %d" % atmo.tilted_count)
	print("INFO  particelle=", atmo.particle_count)
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)
