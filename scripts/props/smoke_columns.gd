class_name SmokeColumns
extends Node3D
## Colonne di fumo scuro sulla piana e su Troia (STYLE.md, sezioni 6 e 11): particelle CPU a
## quad con sprite morbido, economiche. Il numero di colonne e la quantità di particelle
## seguono la qualità (alta 6 colonne, media 3, bassa 1).

## Basi delle colonne (X, Z) in coordinate del mondo; la prima è la più importante.
@export var bases: PackedVector3Array = PackedVector3Array([
	Vector3(-6.0, 3.2, -27.0), Vector3(14.0, 0.0, -9.5), Vector3(-15.0, 0.0, -13.0),
	Vector3(3.0, 0.0, -24.0), Vector3(18.5, 0.8, 2.5), Vector3(-10.0, 2.4, -20.0)])
@export var smoke_color := Color(0.16, 0.13, 0.11, 0.55)
@export var rise_height := 9.0

var column_count := 0


func _ready() -> void:
	var columns: int = [1, 3, 6][int(Quality.current())]
	var amount: int = [10, 14, 16][int(Quality.current())]
	var texture := _soft_texture()
	for i in mini(columns, bases.size()):
		var p := CPUParticles3D.new()
		p.name = "Fumo%d" % (i + 1)
		p.amount = amount
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.local_coords = false
		p.direction = Vector3(0.25, 1, 0.1)
		p.spread = 9.0
		p.initial_velocity_min = rise_height / 7.0 * 0.8
		p.initial_velocity_max = rise_height / 7.0 * 1.2
		p.gravity = Vector3.ZERO
		p.scale_amount_min = 1.2
		p.scale_amount_max = 2.2
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.35))
		curve.add_point(Vector2(1, 2.6))
		p.scale_amount_curve = curve
		var ramp := Gradient.new()
		ramp.set_color(0, Color(smoke_color.r, smoke_color.g, smoke_color.b, 0.0))
		ramp.add_point(0.15, smoke_color)
		ramp.set_color(ramp.get_point_count() - 1, Color(smoke_color.r * 1.4, smoke_color.g * 1.3, smoke_color.b * 1.2, 0.0))
		p.color_ramp = ramp
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = texture
		material.particles_anim_h_frames = 1
		material.particles_anim_v_frames = 1
		material.disable_receive_shadows = true
		quad.material = material
		p.mesh = quad
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.position = bases[i]
		add_child(p)
		column_count += 1


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
