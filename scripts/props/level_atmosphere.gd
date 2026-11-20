class_name LevelAtmosphere
extends Node
## Atmosfera del livello 1, applicata all'avvio sopra la scena generata:
## luci e ombre morbide, cielo caldo con ambiente azzurrino, falò e torce con
## fiamma che oscilla, fumo e scintille, ombre di contatto sotto gli oggetti
## e oggetti a terra leggermente inclinati e infossati.
## Tutti i valori sono esportati: si regolano dall'Inspector.

@export_group("Sole e ombre")
## Quanto sono scure le ombre del sole (1 = nere).
@export_range(0.0, 1.0) var shadow_opacity := 0.6
@export_range(0.0, 8.0) var shadow_blur := 2.6
## Altezza del sole sull'orizzonte, in gradi (più alto = ombre più corte).
@export_range(10.0, 70.0) var sun_elevation_degrees := 38.0

@export_group("Cielo e ambiente")
@export var sky_top_color := Color(0.36, 0.52, 0.82)
@export var sky_horizon_color := Color(1.0, 0.74, 0.48)
@export_range(0.0, 1.0) var ambient_sky_contribution := 0.65
@export_range(0.0, 2.0) var ambient_energy := 0.85

@export_group("Fuoco")
@export_range(0.0, 0.5) var flicker_amount := 0.14
@export var flicker_speed := 9.0

@export_group("Ombre di contatto")
@export_range(0.0, 1.0) var contact_strength := 0.75
## Quanto l'ombra supera l'ingombro dell'oggetto.
@export_range(1.0, 2.0) var contact_margin := 1.35

@export_group("Oggetti a terra")
@export_range(0.0, 15.0) var max_tilt_degrees := 6.0
@export_range(0.0, 0.2) var sink_depth := 0.04

const GROUND_PROPS := ["shield", "spear", "crate", "barrel", "box", "sword", "helmet", "bucket", "sack", "chest", "amphora", "vase", "jar"]

var level: Node3D
var grid: DioramaGrid
var fire_lights: Array[OmniLight3D] = []
var fire_base: Array[float] = []
var contact_count := 0
var particle_count := 0
var tilted_count := 0

var _t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	level = get_parent() as Node3D
	_noise.seed = 7
	_noise.frequency = 1.0
	await get_tree().process_frame
	grid = get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	_setup_light()
	_setup_fire()
	_tilt_ground_props()
	_setup_contact_shadows()  # costa un solo disegno: attiva a ogni qualità


func _process(delta: float) -> void:
	_t += delta
	for i in fire_lights.size():
		var l := fire_lights[i]
		if is_instance_valid(l):
			var n := _noise.get_noise_1d(_t * flicker_speed + i * 17.0)
			l.light_energy = fire_base[i] * (1.0 + flicker_amount * (n * 1.6 + 0.4 * sin(_t * flicker_speed * 1.7 + i)))


# --- Luce, cielo, ambiente --------------------------------------------------

func _setup_light() -> void:
	var sun := level.get_node_or_null(^"Sole") as DirectionalLight3D
	if sun:
		sun.shadow_opacity = shadow_opacity
		sun.shadow_blur = shadow_blur
		var dir := -sun.global_basis.z
		var heading := atan2(dir.x, dir.z)
		var pitch := deg_to_rad(sun_elevation_degrees)
		var nd := Vector3(cos(pitch) * sin(heading), -sin(pitch), cos(pitch) * cos(heading))
		sun.global_basis = Basis.looking_at(nd, Vector3.UP)
	var we := level.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env := we.environment
		env.ambient_light_sky_contribution = ambient_sky_contribution
		env.ambient_light_energy = ambient_energy
		var sky := env.sky
		if sky and sky.sky_material is ProceduralSkyMaterial:
			var m := sky.sky_material as ProceduralSkyMaterial
			m.sky_top_color = sky_top_color
			m.sky_horizon_color = sky_horizon_color


# --- Falò, torce, fumo e scintille ---------------------------------------------

func _setup_fire() -> void:
	for node in level.find_children("Luce*", "OmniLight3D", true, false):
		fire_lights.append(node as OmniLight3D)
		fire_base.append((node as OmniLight3D).light_energy)
	var quality := Quality.current()
	if quality == Quality.Level.LOW:
		return
	var falo := level.find_child("Falo", true, false) as Node3D
	if falo:
		var top := _world_aabb(falo)
		var base := Vector3(top.get_center().x, top.position.y + top.size.y * 0.35, top.get_center().z)
		_add_smoke(base + Vector3(0, 0.4, 0), 1.0 if quality == Quality.Level.HIGH else 0.5)
		_add_sparks(base + Vector3(0, 0.3, 0), 1.0 if quality == Quality.Level.HIGH else 0.5)
		_add_flame(base + Vector3(0, 0.15, 0), 0.55)
	if quality == Quality.Level.HIGH:
		for torch in level.find_children("Torcia*", "Node3D", true, false):
			var b := _world_aabb(torch as Node3D)
			_add_flame(Vector3(b.get_center().x, b.end.y, b.get_center().z))


func _soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _particle_material(unshaded_glow: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_texture()
	m.disable_receive_shadows = true
	if unshaded_glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _add_smoke(pos: Vector3, amount_scale: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "FumoFalo"
	p.amount = int(14 * amount_scale)
	p.lifetime = 5.0
	p.local_coords = false
	p.explosiveness = 0.0
	p.mesh = _quad(1.0)
	p.material_override = _particle_material(false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.25, 0.1, 0.1)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(0.62, 0.58, 0.54, 0.0), Color(0.68, 0.64, 0.60, 0.6), Color(0.80, 0.76, 0.72, 0.0)])
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(p)
	p.global_position = pos
	p.emitting = true
	particle_count += 1


func _add_sparks(pos: Vector3, amount_scale: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "ScintilleFalo"
	p.amount = int(14 * amount_scale)
	p.lifetime = 1.6
	p.local_coords = false
	p.explosiveness = 0.0
	p.randomness = 1.0
	p.mesh = _quad(0.13)
	p.material_override = _particle_material(true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3.UP
	p.spread = 28.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0.2, -0.6, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.5, 0.15, 0.9), Color(0.8, 0.2, 0.05, 0.0)])
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(p)
	p.global_position = pos
	p.emitting = true
	particle_count += 1


func _add_flame(pos: Vector3, size := 0.16) -> void:
	var p := CPUParticles3D.new()
	p.name = "FiammaTorcia"
	p.amount = 6
	p.lifetime = 0.7
	p.local_coords = false
	p.mesh = _quad(size)
	p.material_override = _particle_material(true)
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.8, 0.35, 0.9), Color(1.0, 0.45, 0.1, 0.7), Color(0.6, 0.1, 0.02, 0.0)])
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(p)
	p.global_position = pos
	p.emitting = true
	particle_count += 1


func _quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q


# --- Oggetti a terra: inclinati e infossati -----------------------------------------

func _tilt_ground_props() -> void:
	var scenario := level.get_node_or_null(^"Scenario")
	if scenario == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for node in scenario.find_children("*", "Node3D", true, false):
		var n := node as Node3D
		if n.has_meta(&"atmo_tilted"):
			continue
		# I prop del livello sono GridProp con il modello in `model` (mesh estratte),
		# quindi scene_file_path è vuoto: si usa il percorso del modello.
		var path := n.scene_file_path
		if path == "" and n is GridProp and (n as GridProp).model != null:
			path = (n as GridProp).model.resource_path
		if path == "":
			continue
		path = path.to_lower()
		var hit := false
		for key in GROUND_PROPS:
			if path.contains(key):
				hit = true
				break
		if not hit:
			continue
		n.set_meta(&"atmo_tilted", true)
		var tilt := deg_to_rad(max_tilt_degrees)
		n.rotate_x(rng.randf_range(-tilt, tilt))
		n.rotate_z(rng.randf_range(-tilt, tilt))
		n.global_position.y -= rng.randf_range(sink_depth * 0.5, sink_depth)
		tilted_count += 1


# --- Ombre di contatto (al posto di SSAO) ------------------------------------------

func _setup_contact_shadows() -> void:
	var scenario := level.get_node_or_null(^"Scenario")
	if scenario == null:
		return
	var boxes: Array[AABB] = []
	for group in scenario.get_children():
		for obj in group.get_children():
			var n := obj as Node3D
			if n == null:
				continue
			var b := _world_aabb(n)
			if b.size == Vector3.ZERO or b.size.y < 0.15 or b.size.x > 9.0 or b.size.z > 9.0:
				continue
			boxes.append(b)
	if boxes.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	mm.mesh = plane
	mm.instance_count = boxes.size()
	for i in boxes.size():
		var b := boxes[i]
		var c := b.get_center()
		var y := grid.get_height_at_world(Vector3(c.x, 0.0, c.z)) if grid else b.position.y
		y = minf(y, b.position.y + 0.1) + 0.035
		var sx := maxf(b.size.x, 0.5) * contact_margin
		var sz := maxf(b.size.z, 0.5) * contact_margin
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(sx, 1.0, sz)), Vector3(c.x, y, c.z)))
		mm.set_instance_color(i, Color(1, 1, 1, clampf(0.55 + b.size.y * 0.12, 0.55, 1.0)))
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.5;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = smoothstep(1.0, 0.25, d);
	ALBEDO = vec3(0.07, 0.04, 0.02);
	ALPHA = a * a * strength * COLOR.a;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(&"strength", contact_strength)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "OmbreContatto"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(mmi)
	contact_count = boxes.size()


# --- Utilità ------------------------------------------------------------------------

## AABB in coordinate mondo di tutte le mesh sotto un nodo.
func _world_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var b := m.global_transform * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	if root is MeshInstance3D and (root as MeshInstance3D).mesh:
		var rb := root.global_transform * (root as MeshInstance3D).mesh.get_aabb()
		out = rb if first else out.merge(rb)
	return out
