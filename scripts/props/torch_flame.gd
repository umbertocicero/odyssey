class_name TorchFlame
extends RefCounted
## Fiamma animata unica per tutte le torce (in mano, sul palo, braceri delle mura): un billboard con shader
## procedurale (assets/shaders/torch_flame.gdshader) + scintille/braci (GPUParticles3D) + fumo sottile (solo alta).
## Mesh, materiali di particelle e process material sono condivisi: ogni torcia costa 1 quad + 1-2 emettitori.
## Il vento (LevelClock) piega la punta e fa derivare le braci: lo aggiorna `update_wind`.
## Qualità: bassa = solo fiamma; media = + braci (5); alta = + braci (8) e fumo (3). Oltre
## RANGE_PARTICLES / RANGE_FLAME metri dalla camera tutto sparisce da solo (visibility_range).

const SHADER := preload("res://assets/shaders/torch_flame.gdshader")
const RANGE_FLAME := 45.0
const RANGE_PARTICLES := 24.0

static var _flame_mesh: QuadMesh
static var _flame_materials: Array[ShaderMaterial] = []
static var _ember_process: ParticleProcessMaterial
static var _ember_mesh: QuadMesh
static var _smoke_process: ParticleProcessMaterial
static var _smoke_mesh: QuadMesh
static var _soft: GradientTexture2D
static var _wind := Vector2.ZERO
static var _next_phase := 0.0


## Aggiunge la fiamma a `parent` con la base in `local_pos`. `height` e `width` in metri nel mondo.
static func attach(parent: Node3D, local_pos: Vector3, height := 0.5, width := 0.3, with_particles := true) -> Node3D:
	var root := Node3D.new()
	root.name = "FiammaAnimata"
	root.position = local_pos
	parent.add_child(root)
	var quality := int(Quality.current())
	var seed := _next_phase
	_next_phase += 2.37
	var flame := MeshInstance3D.new()
	flame.name = "Fiamma"
	if _flame_mesh == null:
		_flame_mesh = QuadMesh.new()
		_flame_mesh.size = Vector2(1, 1)
		_flame_mesh.custom_aabb = AABB(Vector3(-1, -0.2, -1), Vector3(2, 2.5, 2))
	flame.mesh = _flame_mesh
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"size", Vector2(width, height))
	m.set_shader_parameter(&"phase", seed)
	m.set_shader_parameter(&"wind", _wind)
	flame.material_override = m
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.visibility_range_end = RANGE_FLAME
	root.add_child(flame)
	_flame_materials.append(m)
	if with_particles and quality >= 1:
		root.add_child(_embers(8 if quality == 2 else 5, height))
		if quality == 2:
			root.add_child(_smoke(3, height))
	return root


## Aggiorna il vento di tutte le fiamme. `wind` è la direzione XZ del vento già scalata dalla forza.
static func update_wind(wind_dir: Vector2, strength: float) -> void:
	_wind = wind_dir.normalized() * (0.1 + strength * 0.9) * 0.6
	_flame_materials = _flame_materials.filter(func(x): return is_instance_valid(x))
	for m in _flame_materials:
		m.set_shader_parameter(&"wind", _wind)
	if _ember_process != null:
		_ember_process.gravity = Vector3(_wind.x * 2.0, 0.35, _wind.y * 2.0)
	if _smoke_process != null:
		_smoke_process.gravity = Vector3(_wind.x * 1.5, 0.12, _wind.y * 1.5)


## Intensità luminosa con guizzo irregolare (somma di sinusoidi incommensurabili, ~1.0 ± 0.25), da usare
## per le luci delle torce: `energy * TorchFlame.flicker(ms, seed)`.
static func flicker(ticks_msec: float, seed: float) -> float:
	var t := ticks_msec * 0.001 + seed
	return 1.0 + 0.12 * sin(t * 11.3) + 0.09 * sin(t * 17.9 + 1.7) + 0.06 * sin(t * 29.0 + 4.1) + 0.04 * sin(t * 5.1)


static func _soft_texture() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 32
		_soft.height = 32
	return _soft


static func _particle_material(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_texture()
	m.disable_receive_shadows = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


static func _embers(amount: int, height: float) -> GPUParticles3D:
	if _ember_process == null:
		var p := ParticleProcessMaterial.new()
		p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.05
		p.direction = Vector3.UP
		p.spread = 28.0
		p.initial_velocity_min = 0.35
		p.initial_velocity_max = 0.95
		p.gravity = Vector3(0.0, 0.35, 0.0)
		p.damping_min = 0.1
		p.damping_max = 0.4
		p.scale_min = 0.5
		p.scale_max = 1.2
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1.0))
		curve.add_point(Vector2(1, 0.15))
		var ct := CurveTexture.new()
		ct.curve = curve
		p.scale_curve = ct
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.42, 0.08, 0.85), Color(0.5, 0.08, 0.02, 0.0)])
		var rt := GradientTexture1D.new()
		rt.gradient = ramp
		p.color_ramp = rt
		_ember_process = p
		_ember_mesh = QuadMesh.new()
		_ember_mesh.size = Vector2(0.035, 0.035)
		_ember_mesh.material = _particle_material(true)
	var g := GPUParticles3D.new()
	g.name = "Braci"
	g.amount = amount
	g.lifetime = 1.5
	g.local_coords = false
	g.randomness = 1.0
	g.fixed_fps = 30
	g.process_material = _ember_process
	g.draw_pass_1 = _ember_mesh
	g.position = Vector3(0, height * 0.55, 0)
	g.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3, 3.5, 3))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_range_end = RANGE_PARTICLES
	g.emitting = true
	return g


static func _smoke(amount: int, height: float) -> GPUParticles3D:
	if _smoke_process == null:
		var p := ParticleProcessMaterial.new()
		p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.05
		p.direction = Vector3.UP
		p.spread = 12.0
		p.initial_velocity_min = 0.25
		p.initial_velocity_max = 0.45
		p.gravity = Vector3(0.0, 0.12, 0.0)
		p.scale_min = 0.8
		p.scale_max = 1.2
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(1, 1.8))
		var ct := CurveTexture.new()
		ct.curve = curve
		p.scale_curve = ct
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		ramp.colors = PackedColorArray([Color(0.35, 0.3, 0.28, 0.0), Color(0.4, 0.36, 0.33, 0.16), Color(0.45, 0.42, 0.4, 0.0)])
		var rt := GradientTexture1D.new()
		rt.gradient = ramp
		p.color_ramp = rt
		_smoke_process = p
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.size = Vector2(0.5, 0.5)
		_smoke_mesh.material = _particle_material(false)
	var g := GPUParticles3D.new()
	g.name = "FumoSottile"
	g.amount = amount
	g.lifetime = 3.0
	g.local_coords = false
	g.randomness = 1.0
	g.fixed_fps = 20
	g.process_material = _smoke_process
	g.draw_pass_1 = _smoke_mesh
	g.position = Vector3(0, height * 0.9, 0)
	g.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 5, 4))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_range_end = RANGE_PARTICLES
	g.emitting = true
	return g
