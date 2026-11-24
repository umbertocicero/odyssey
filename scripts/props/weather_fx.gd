class_name WeatherFx
extends Node
## Meteo e ambiente visibili (todo.md, sezioni 1, 3 e 5), tutto guidato da LevelClock e senza effetto sul
## gameplay: pioggia come overlay 2D a costo fisso, terreno e erba che si bagnano e si asciugano piano,
## pozze riflettenti che spariscono quando torna il sole, vento variabile sull'erba, foglie che cadono
## da pochi emettitori sugli alberi e polvere/polline nell'aria. Particelle (leggere, CPU): low 0,
## medium ~100, high ~250; con la pioggia polline e polvere si spengono.

@export var enabled := true
## Bagliori di temporale con la pioggia: solo luce (cielo, ambiente, un velo a schermo), nessuna saetta
## disegnata nella scena e nessun effetto sul gameplay. Intervalli irregolari, più evidenti di notte.
@export var lightning_enabled := true
@export var puddle_spots: PackedVector2Array = PackedVector2Array([
	Vector2(-15.0, 12.0), Vector2(-9.5, 11.0), Vector2(-2.0, 12.0), Vector2(5.0, 9.0), Vector2(6.5, 3.0), Vector2(6.0, -4.0),
	Vector2(7.0, -10.0), Vector2(6.0, -16.0), Vector2(-11.0, 4.0), Vector2(1.5, 3.0), Vector2(11.0, 8.0), Vector2(-4.0, -2.0),
	Vector2(14.0, -3.0), Vector2(-12.0, -8.0), Vector2(2.0, -12.0), Vector2(10.0, 14.0), Vector2(-6.0, 15.0), Vector2(16.0, 5.0),
	Vector2(-18.0, 3.0), Vector2(0.0, 17.0)])
@export var leaf_sources: PackedVector3Array = PackedVector3Array([Vector3(-17.0, 5.5, -5.0), Vector3(15.0, 4.5, 1.0)])

var clock: LevelClock
var grass: GrassCards
var terrain: PhotoTerrain
var overlay: ColorRect
var overlay_material: ShaderMaterial
var puddles: MultiMeshInstance3D
var puddle_material: StandardMaterial3D
var leaf_emitters: Array[CPUParticles3D] = []
var motes: CPUParticles3D
var particle_budget := 0
var puddle_count := 0
var _terrain_material: StandardMaterial3D
var _terrain_albedo0 := Color.WHITE
var _terrain_rough0 := 1.0

# Bagliori: ogni evento è una scarica di 1-3 impulsi ravvicinati (x = inizio, y = forza, z = durata, in s).
var flash := 0.0                       # 0..1, intensità del bagliore in questo frame (per i test)
var flash_overlay: ColorRect
var _env: Environment
var _sky: ShaderMaterial
var _flash_rng := RandomNumberGenerator.new()
var _flash_timer := 5.0
var _event_t := 0.0
var _event_pulses: Array[Vector3] = []
var _event_end := 0.0
var _flash_sky_dirty := false

## Sotto questa pioggia non partono nuovi lampi (il temporale arriva con la pioggia piena).
const STORM_MIN_RAIN := 0.4


func _ready() -> void:
	if not enabled:
		return
	# Dopo CicloNotte, che riscrive ambiente e nebbia a ogni frame: il bagliore si somma sopra.
	process_priority = 10
	await get_tree().process_frame
	await get_tree().process_frame
	clock = get_tree().get_first_node_in_group(&"level_clock") as LevelClock
	if clock == null:
		return
	var level := get_parent()
	_flash_rng.randomize()
	var we := level.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment
		if _env.sky and _env.sky.sky_material is ShaderMaterial:
			_sky = _env.sky.sky_material as ShaderMaterial
	grass = level.get_node_or_null(^"ErbaFotorealistica") as GrassCards
	terrain = get_tree().get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	_build_overlay()
	_build_puddles()
	_build_leaves()
	_build_motes()
	if terrain and terrain.surface:
		var m := terrain.surface.get_active_material(0) as StandardMaterial3D
		if m:
			_terrain_material = m.duplicate() as StandardMaterial3D
			terrain.surface.material_override = _terrain_material
			_terrain_albedo0 = _terrain_material.albedo_color
			_terrain_rough0 = _terrain_material.roughness
	set_process(true)


func _ground(x: float, z: float) -> float:
	if terrain and terrain.is_active():
		return terrain.height_at(x, z)
	return 0.0


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PioggiaOverlay"
	layer.layer = 4
	add_child(layer)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = load("res://assets/shaders/rain_overlay.gdshader")
	overlay.material = overlay_material
	overlay.visible = false
	layer.add_child(overlay)
	# Velo del bagliore: un solo rettangolo additivo, quasi trasparente, acceso solo durante i lampi.
	flash_overlay = ColorRect.new()
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.color = Color(0.6, 0.7, 1.0, 0.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash_overlay.material = add
	flash_overlay.visible = false
	layer.add_child(flash_overlay)


func _build_puddles() -> void:
	var count: int = [6, 10, 14][int(Quality.current())]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var disc := QuadMesh.new()
	disc.size = Vector2(1, 1)
	disc.orientation = PlaneMesh.FACE_Y
	mm.mesh = disc
	mm.instance_count = count
	for i in count:
		var s: Vector2 = puddle_spots[i % puddle_spots.size()] + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
		var size := rng.randf_range(0.9, 2.0)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size * rng.randf_range(1.0, 1.6), 1.0, size))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(s.x, _ground(s.x, s.y) + 0.025, s.y)))
	puddle_count = count
	puddle_material = StandardMaterial3D.new()
	puddle_material.albedo_color = Color(0.1, 0.13, 0.18, 0.0)
	puddle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle_material.roughness = 0.04
	puddle_material.metallic = 0.0
	puddle_material.metallic_specular = 1.0
	puddle_material.albedo_texture = _round_texture()
	puddles = MultiMeshInstance3D.new()
	puddles.name = "Pozze"
	puddles.multimesh = mm
	puddles.material_override = puddle_material
	puddles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puddles.visible = false
	add_child(puddles)


func _round_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.7, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _quad(texture: Texture2D, color_albedo := true) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = color_albedo
	material.albedo_texture = texture
	material.disable_receive_shadows = true
	quad.material = material
	return quad


func _build_leaves() -> void:
	var amount: int = [0, 10, 25][int(Quality.current())]
	if amount == 0:
		return
	var leaf := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	leaf.gradient = g
	leaf.fill = GradientTexture2D.FILL_RADIAL
	leaf.fill_from = Vector2(0.5, 0.5)
	leaf.fill_to = Vector2(1.0, 0.5)
	leaf.width = 32
	leaf.height = 32
	for src in leaf_sources:
		var p := CPUParticles3D.new()
		p.name = "Foglie%d" % (leaf_emitters.size() + 1)
		p.amount = amount
		p.lifetime = 9.0
		p.preprocess = 9.0
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(3.5, 0.5, 3.5)
		p.direction = Vector3(1, -1, 0.2)
		p.spread = 35.0
		p.initial_velocity_min = 0.2
		p.initial_velocity_max = 0.7
		p.gravity = Vector3(0.0, -0.45, 0.0)
		p.angular_velocity_min = -120.0
		p.angular_velocity_max = 120.0
		p.scale_amount_min = 0.07
		p.scale_amount_max = 0.14
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.46, 0.42, 0.16, 0.0))
		ramp.add_point(0.1, Color(0.5, 0.44, 0.16, 1.0))
		ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.3, 0.12, 0.0))
		p.color_ramp = ramp
		var quad := _quad(leaf)
		(quad.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		(quad.material as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		p.mesh = quad
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.position = Vector3(src.x, _ground(src.x, src.z) + src.y, src.z)
		add_child(p)
		leaf_emitters.append(p)
		particle_budget += amount


func _build_motes() -> void:
	var amount: int = [0, 20, 60][int(Quality.current())]
	if amount == 0:
		return
	motes = CPUParticles3D.new()
	motes.name = "Polline"
	motes.amount = amount
	motes.lifetime = 10.0
	motes.preprocess = 10.0
	motes.local_coords = false
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(20.0, 1.5, 20.0)
	motes.direction = Vector3(1, 0.2, 0.3)
	motes.spread = 60.0
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.2
	motes.gravity = Vector3.ZERO
	motes.scale_amount_min = 0.03
	motes.scale_amount_max = 0.06
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.5, 0.0))
	ramp.add_point(0.3, Color(1.0, 0.85, 0.5, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.85, 0.5, 0.0))
	motes.color_ramp = ramp
	var dot := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = g
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 16
	dot.height = 16
	motes.mesh = _quad(dot)
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.position = Vector3(0, 1.8, -2)
	add_child(motes)
	particle_budget += amount


func _process(_delta: float) -> void:
	if clock == null:
		return
	var rain := clock.rain
	var wet := clock.wetness
	# Pioggia: overlay a schermo intero (costo fisso), spento quando non piove.
	overlay.visible = rain > 0.01
	if overlay.visible:
		overlay_material.set_shader_parameter(&"amount", rain)
		overlay_material.set_shader_parameter(&"wind", Vector2(clock.wind_direction.x * 0.3, 0.0))
	# Terreno: scuro e meno ruvido da bagnato, si asciuga piano (wetness scende in ~60 s).
	if _terrain_material:
		_terrain_material.albedo_color = _terrain_albedo0 * lerpf(1.0, 0.62, wet)
		_terrain_material.roughness = lerpf(_terrain_rough0, 0.55, wet)
	# Pozze: compaiono con la pioggia e svaniscono quando il terreno si asciuga.
	puddles.visible = wet > 0.04
	if puddles.visible:
		var a := clampf((wet - 0.15) * 1.3, 0.0, 0.85)
		puddle_material.albedo_color = Color(0.09, 0.12, 0.17, a)
	# Erba: più scura da bagnata e vento variabile.
	if grass and grass.material:
		grass.material.set_shader_parameter(&"tint", Color(1, 1, 1).lerp(Color(0.62, 0.66, 0.7), wet))
		grass.material.set_shader_parameter(&"wind_direction", clock.wind_direction)
		grass.material.set_shader_parameter(&"wind_strength", 0.06 + clock.wind_strength * 0.5)
	# Foglie: la direzione del vento orienta la caduta.
	for p in leaf_emitters:
		p.direction = Vector3(clock.wind_direction.x, -0.8, clock.wind_direction.y)
		p.initial_velocity_max = 0.5 + clock.wind_strength * 4.0
	# Polline: di giorno e col sereno, a zero di notte e con la pioggia.
	if motes:
		motes.emitting = clock.night_amount() < 0.6 and rain < 0.15
	_update_lightning(_delta, rain)


## Avvia subito un temporale di bagliori (test, demo).
func force_flash() -> void:
	_start_flash_event()


func _start_flash_event() -> void:
	_event_pulses.clear()
	var start := 0.0
	var count := _flash_rng.randi_range(1, 3)
	for i in count:
		var peak := 1.0 if i == 0 else _flash_rng.randf_range(0.45, 0.9)
		var length := _flash_rng.randf_range(0.1, 0.28)
		_event_pulses.append(Vector3(start, peak, length))
		start += length * 0.5 + _flash_rng.randf_range(0.05, 0.16)
	_event_end = 0.0
	for p in _event_pulses:
		_event_end = maxf(_event_end, p.x + p.z + 0.05)
	_event_t = 0.0
	# Zona del cielo da cui arriva la luce (lontana, bassa sull'orizzonte): cambia a ogni scarica.
	if _sky:
		var az := _flash_rng.randf() * TAU
		var el := _flash_rng.randf_range(0.12, 0.5)
		_sky.set_shader_parameter(&"flash_dir", Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el)))


func _update_lightning(delta: float, rain: float) -> void:
	if not lightning_enabled:
		return
	var active := not _event_pulses.is_empty()
	if not active and rain > STORM_MIN_RAIN:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			# Intervalli irregolari: spesso 3-8 s, ogni tanto una pausa lunga.
			var r := _flash_rng.randf()
			_flash_timer = 3.0 + r * r * 16.0 + (_flash_rng.randf_range(6.0, 14.0) if _flash_rng.randf() < 0.15 else 0.0)
			_start_flash_event()
			active = true
	var f := 0.0
	if active:
		_event_t += delta
		for p in _event_pulses:
			var x := _event_t - p.x
			if x < 0.0:
				continue
			# Attacco quasi istantaneo, poi spegnimento con un lieve tremolio.
			var env_v := clampf(x / 0.025, 0.0, 1.0) * pow(clampf(1.0 - x / p.z, 0.0, 1.0), 2.0)
			env_v *= 0.85 + 0.15 * sin(x * 90.0)
			f = maxf(f, env_v * p.y)
		if _event_t >= _event_end:
			_event_pulses.clear()
			f = 0.0
	flash = f
	var night := clock.night_amount()
	# Di giorno il cielo è già chiaro, quindi il bagliore è più contenuto; di notte è molto più evidente.
	var strength := f * lerpf(0.55, 1.0, night)
	if strength > 0.002:
		_flash_sky_dirty = true
		if _sky:
			_sky.set_shader_parameter(&"flash", strength * 1.1)
		if _env:
			_env.ambient_light_energy += strength * lerpf(0.7, 1.3, night)
			_env.ambient_light_color = _env.ambient_light_color.lerp(Color(0.72, 0.8, 1.0), clampf(strength * 0.6, 0.0, 0.6))
			_env.fog_light_color = _env.fog_light_color.lerp(Color(0.7, 0.78, 1.0), clampf(strength * 0.5, 0.0, 0.5))
		flash_overlay.visible = true
		flash_overlay.color.a = strength * 0.1
	elif _flash_sky_dirty:
		_flash_sky_dirty = false
		if _sky:
			_sky.set_shader_parameter(&"flash", 0.0)
		flash_overlay.visible = false
