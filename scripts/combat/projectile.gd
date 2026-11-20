class_name Projectile
extends Node3D
## Proiettile con traiettoria a parabola visibile. Arriva sul bersaglio dopo
## esattamente flight_time secondi ed emette "arrived".

signal arrived

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _arc := 2.0
var _flight_time := 1.0
var _time := 0.0


func setup(profile: AttackProfile, from: Vector3, to: Vector3) -> void:
	_from = from
	_to = to
	_arc = profile.arc_height
	_flight_time = profile.warning_time
	var visual := CombatFx.projectile_mesh(profile)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = visual[0]
	mesh_instance.material_override = visual[1]
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	add_to_group(&"projectiles")


func _ready() -> void:
	global_position = _from


func _process(delta: float) -> void:
	_time += delta
	var t := clampf(_time / _flight_time, 0.0, 1.0)
	var position_now := _point_at(t)
	var ahead := _point_at(minf(t + 0.02, 1.0)) - position_now
	global_position = position_now
	if ahead.length() > 0.001 and absf(ahead.normalized().dot(Vector3.UP)) < 0.99:
		look_at(position_now + ahead, Vector3.UP)
	if t >= 1.0:
		arrived.emit()
		queue_free()


func _point_at(t: float) -> Vector3:
	var p := _from.lerp(_to, t)
	p.y += sin(PI * t) * _arc
	return p
