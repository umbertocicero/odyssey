class_name BattleAtmosphere
extends Node3D
## Atmosfera della pianura di battaglia (STYLE.md, sezioni 6 e 8): polvere ocra lungo la strada e sotto
## le mura, fumo scuro basso vicino al campo, frecce infuocate decorative che attraversano il cielo
## dalle mura verso il campo (pool riusabile, non fanno danni: quelle vere sono WallShooter/Projectile)
## e frecce conficcate a terra (un MultiMesh). Tutto con particelle CPU a quad morbidi e budget per
## qualità: low ~30, medium ~85, high ~215 (con fumo, meteo e fuochi il totale resta sotto 60 / 250 / 600: tests/test_budgets.gd); frecce in volo 2 / 4 / 10.

const DUST_POINTS := [
	Vector3(-8.0, 0.5, 11.6), Vector3(0.0, 0.5, 11.4), Vector3(6.2, 0.5, 5.0), Vector3(6.6, 0.5, -3.0),
	Vector3(6.4, 0.5, -11.0), Vector3(-14.0, 0.5, -18.0), Vector3(14.0, 0.5, -17.5)]
const SMOKE_POINTS := [Vector3(-10.5, 0.4, 8.0), Vector3(-6.0, 0.4, 6.5), Vector3(14.0, 0.4, -9.5)]

@export var enabled := true
@export var random_seed := 71
## Direzione del vento sul piano XZ (stessa dell'erba).
@export var wind := Vector3(0.6, 0.0, 0.2)

var particle_budget := 0
var active_arrow_limit := 0
var stuck_arrows := 0

var _rng := RandomNumberGenerator.new()
var _arrows: Array[Dictionary] = []
var _next_launch := 2.0
var _arrow_mesh: Mesh
var _tip_mesh: Mesh
var _trail_texture: GradientTexture2D
var _relief: TerrainRelief
var _terrain: PhotoTerrain


func _ready() -> void:
	if not enabled:
		return
	_rng.seed = random_seed
	_relief = get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	_terrain = get_tree().get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	var q := int(Quality.current())
	_trail_texture = _soft_texture()
	var dust_emitters: int = [0, 6, 7][q]
	var dust_amount: int = [0, 8, 22][q]
	var smoke_emitters: int = [2, 3, 3][q]
	var smoke_amount: int = [10, 12, 20][q]
	active_arrow_limit = [2, 4, 10][q]
	for i in dust_emitters:
		_add_cloud("Polvere%d" % (i + 1), DUST_POINTS[i], dust_amount, Color(0.74, 0.58, 0.38, 0.32), 2.2, 4.6, 6.0, Vector3(4.0, 0.0, 3.0))
	for i in smoke_emitters:
		_add_cloud("Fumo%d" % (i + 1), SMOKE_POINTS[i], smoke_amount, Color(0.15, 0.12, 0.1, 0.38), 0.9, 2.2, 6.5, Vector3(0.5, 0.2, 0.5), 0.55)
	_build_arrow_pool()
	if q > 0:
		_build_stuck_arrows([0, 8, 16][q])
	particle_budget = dust_emitters * dust_amount + smoke_emitters * smoke_amount + active_arrow_limit * 5


func _ground(x: float, z: float) -> float:
	if _terrain and _terrain.is_active():
		return _terrain.height_at(x, z)
	return _relief.height_at_world(x, z) if _relief else 0.0


func _add_cloud(node_name: String, at: Vector3, amount: int, color: Color, size_min: float, size_max: float, life: float, spread_box: Vector3, rise := 0.12) -> void:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = spread_box
	p.direction = Vector3(wind.x, rise * 4.0, wind.z).normalized()
	p.spread = 25.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.45
	p.gravity = Vector3.ZERO
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	var growth := Curve.new()
	growth.add_point(Vector2(0, 0.5))
	growth.add_point(Vector2(1, 1.5))
	p.scale_amount_curve = growth
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 0.0))
	ramp.add_point(0.25, color)
	ramp.set_color(ramp.get_point_count() - 1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.mesh = _quad(_trail_texture)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(at.x, _ground(at.x, at.z) + at.y, at.z)
	add_child(p)


func _quad(texture: Texture2D) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.disable_receive_shadows = true
	quad.material = material
	return quad


func _soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


# --- Frecce infuocate decorative -------------------------------------------------------------------

func _build_arrow_pool() -> void:
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.035, 0.035, 0.7)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.24, 0.14)
	shaft.material = wood
	_arrow_mesh = shaft
	var tip := SphereMesh.new()
	tip.radius = 0.07
	tip.height = 0.14
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.albedo_color = Color(1.0, 0.65, 0.2)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.5, 0.1)
	fire.emission_energy_multiplier = 3.0
	tip.material = fire
	_tip_mesh = tip
	for i in active_arrow_limit:
		var root := Node3D.new()
		root.name = "FrecciaInfuocata%d" % (i + 1)
		root.visible = false
		var body := MeshInstance3D.new()
		body.mesh = _arrow_mesh
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(body)
		var head := MeshInstance3D.new()
		head.mesh = _tip_mesh
		head.position = Vector3(0, 0, -0.38)
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(head)
		var trail := CPUParticles3D.new()
		trail.name = "Scia"
		trail.amount = [4, 4, 5][int(Quality.current())]
		trail.lifetime = 0.7
		trail.local_coords = false
		trail.emitting = false
		trail.direction = Vector3(0, 1, 0)
		trail.spread = 40.0
		trail.initial_velocity_min = 0.1
		trail.initial_velocity_max = 0.4
		trail.gravity = Vector3(0, 0.5, 0)
		trail.scale_amount_min = 0.25
		trail.scale_amount_max = 0.5
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.7, 0.25, 0.9))
		ramp.add_point(0.35, Color(0.9, 0.35, 0.1, 0.5))
		ramp.set_color(ramp.get_point_count() - 1, Color(0.18, 0.15, 0.13, 0.0))
		trail.color_ramp = ramp
		trail.mesh = _quad(_trail_texture)
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.position = Vector3(0, 0, 0.2)
		root.add_child(trail)
		add_child(root)
		_arrows.append({"node": root, "trail": trail, "t": 1.0, "dur": 1.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "arc": 3.0})


func _process(delta: float) -> void:
	if not enabled or _arrows.is_empty():
		return
	_next_launch -= delta
	if _next_launch <= 0.0:
		_next_launch = _rng.randf_range(0.6, 2.4) * (3.0 if Quality.current() == Quality.Level.LOW else 1.0)
		_launch()
	for a in _arrows:
		if a["t"] >= 1.0:
			continue
		a["t"] += delta / float(a["dur"])
		var t: float = minf(a["t"], 1.0)
		var from: Vector3 = a["from"]
		var to: Vector3 = a["to"]
		var pos := from.lerp(to, t)
		pos.y += sin(t * PI) * float(a["arc"])
		var node := a["node"] as Node3D
		var previous := node.global_position
		node.global_position = pos
		if pos.distance_to(previous) > 0.001:
			node.look_at(pos + (pos - previous), Vector3.UP)
		if t >= 1.0:
			node.visible = false
			(a["trail"] as CPUParticles3D).emitting = false


func _launch() -> void:
	var free := _arrows.filter(func(a: Dictionary) -> bool: return a["t"] >= 1.0)
	if free.is_empty():
		return
	var a: Dictionary = free[0]
	var from := Vector3(_rng.randf_range(-23.0, 23.0), 5.6, -21.4)
	var to := Vector3(_rng.randf_range(-16.0, 10.0), 0.0, _rng.randf_range(-6.0, 14.0))
	to.y = _ground(to.x, to.z) + 0.2
	a["from"] = from
	a["to"] = to
	a["dur"] = _rng.randf_range(2.0, 3.2)
	a["arc"] = _rng.randf_range(5.0, 9.0)
	a["t"] = 0.0
	var node := a["node"] as Node3D
	node.global_position = from
	node.visible = true
	(a["trail"] as CPUParticles3D).restart()
	(a["trail"] as CPUParticles3D).emitting = true


# --- Frecce conficcate a terra -----------------------------------------------------------------------

func _build_stuck_arrows(count: int) -> void:
	var transforms: Array[Transform3D] = []
	var tries := 0
	while transforms.size() < count and tries < count * 30:
		tries += 1
		var x := _rng.randf_range(-14.0, 14.0)
		var z := _rng.randf_range(-16.0, 4.0)
		# Non sulla strada (x tra 4 e 9) né dentro le mura.
		if x > 4.0 and x < 9.0:
			continue
		var basis := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(0.9, 1.25))
		transforms.append(Transform3D(basis, Vector3(x, _ground(x, z) + 0.12, z)))
	stuck_arrows = transforms.size()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _arrow_mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FrecceConficcate"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
