class_name HealthBar3D
extends Node3D
## Barra della vita semplice sopra un'unità: due rettangoli sempre rivolti
## alla camera. Si vede solo quando l'unità è ferita.

@export var bar_size := Vector2(0.8, 0.1)
@export var height := 1.9

var _fill: MeshInstance3D
var _ratio := 1.0
## Nascosta comunque (duello in prima persona: c'è l'HUD del duello).
var suppressed := false:
	set(value):
		suppressed = value
		visible = _ratio < 1.0 and not suppressed
var _fill_material: StandardMaterial3D


func _ready() -> void:
	position = Vector3.UP * height
	add_child(_make_quad(Color(0.08, 0.06, 0.06, 0.85), 0))
	_fill = _make_quad(Color(0.3, 0.9, 0.3), 1)
	_fill_material = _fill.material_override
	add_child(_fill)


func set_ratio(ratio: float) -> void:
	if not is_node_ready():
		await ready
	ratio = clampf(ratio, 0.0, 1.0)
	_ratio = ratio
	visible = ratio < 1.0 and not suppressed
	_fill.scale = Vector3(maxf(ratio, 0.001), 1, 1)
	_fill_material.albedo_color = Color(0.9, 0.2, 0.15).lerp(Color(0.3, 0.9, 0.3), ratio)


func _make_quad(color: Color, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = bar_size if priority == 0 else bar_size - Vector2(0.04, 0.04)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.no_depth_test = true
	material.render_priority = priority
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
