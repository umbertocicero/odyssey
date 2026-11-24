class_name AnimalIdle
extends Node
## Vita per gli animali di scena (cavalli, pecore, maiali). I modelli sono mesh statiche senza
## scheletro: le articolazioni sono nello shader `animal_rig.gdshader` (zampe che oscillano e si
## piegano, collo e testa che si flettono, schiena, coda), pilotato da parametri per istanza.
## Qui vivono la macchina a stati (riposo, brucare, zampata, passi), le transizioni morbide
## (accelerazione, rotazione smorzata, andatura che segue la velocità) e l'appoggio al terreno:
## la quota è presa dalla mesh vera (PhotoTerrain) sotto i piedi, così nessun animale affonda.
## Collisioni, caselle bloccate e griglia restano sul GridProp.

const SHADER := preload("res://assets/shaders/animal_rig.gdshader")

## Per specie: respiro (periodo s, ampiezza), testa bassa (ogni quanti s), andatura (m/s, lunghezza
## passo m), pausa fra spostamenti, rotazione (rad/s), collo (zf base, hy base, lunghezza zf),
## stile shader (zampe rad, testa rad, coda m, schiena m).
const KINDS := {
	"horse": {"breath_period": 4.2, "breath": 0.012, "dip_every": Vector2(9.0, 18.0),
		"speed": 0.7, "stride": 0.75, "rest": Vector2(6.0, 14.0), "turn": 1.2, "stomp": true,
		"neck": Vector4(-0.22, 0.80, 0.26, 0.0), "style": Vector4(0.40, 0.65, 0.07, 0.025)},
	"sheep": {"breath_period": 2.6, "breath": 0.016, "dip_every": Vector2(4.0, 9.0),
		"speed": 0.35, "stride": 0.36, "rest": Vector2(5.0, 12.0), "turn": 1.8, "stomp": false,
		"neck": Vector4(-0.25, 0.78, 0.22, 0.0), "style": Vector4(0.45, 0.75, 0.025, 0.015)},
	"pig": {"breath_period": 2.2, "breath": 0.018, "dip_every": Vector2(3.0, 8.0),
		"speed": 0.35, "stride": 0.34, "rest": Vector2(5.0, 11.0), "turn": 1.9, "stomp": false,
		"neck": Vector4(-0.25, 0.80, 0.22, 0.0), "style": Vector4(0.45, 0.45, 0.04, 0.02)},
}

static var _mats := {}
static var _terrain: PhotoTerrain
static var _relief: TerrainRelief

var kind := "horse"
var wander := 1.0
var max_turn_deg := 180.0

var _prop: GridProp
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _pos := Vector2.ZERO
var _yaw := 0.0
var _yaw_vel := 0.0
var _target := Vector2.ZERO
var _walking := false
var _rest_left := 0.0
var _speed := 0.0
var _gait := 0.0
var _walk := 0.0
var _dip_left := 0.0
var _dip_total := 1.0
var _next_dip := 5.0
var _stomp_left := 0.0
var _next_stomp := 12.0
var _ground_y := 0.0
var _ground_ready := false
var _pitch := 0.0
var _roll := 0.0
var _params: Dictionary
var _rigged: Node3D
var _meshes: Array[MeshInstance3D] = []
var _seed := 0.0


func setup(prop: GridProp, animal_kind: String, wander_radius: float, turn_limit_deg := 180.0) -> void:
	_prop = prop
	kind = animal_kind if KINDS.has(animal_kind) else "horse"
	wander = maxf(wander_radius, 0.0)
	max_turn_deg = turn_limit_deg
	_params = KINDS[kind]
	var p := prop.global_position
	_rng.seed = hash(Vector3i(roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0)))
	_seed = _rng.randf() * 50.0
	_t = _rng.randf() * 100.0
	_rest_left = _rng.randf_range(0.5, 5.0)
	_next_dip = _rng.randf_range(1.0, 6.0)
	_next_stomp = _rng.randf_range(6.0, 25.0)
	set_process(true)


func _process(delta: float) -> void:
	if _prop == null or not is_instance_valid(_prop):
		return
	var visual := _prop.visual_node()
	if visual == null:
		return
	if visual != _rigged:
		_rig(visual)
	delta = minf(delta, 0.1)
	_t += delta
	_update_walk(delta)
	_update_events(delta)

	# Testa: riposo con deriva lenta, brucare con masticazione, cenno a tempo con i passi.
	var head := sin(_t * 0.7 + _seed) * 0.06 + sin(_t * 1.9 + _seed * 2.0) * 0.04
	if _dip_left > 0.0:
		var k := 1.0 - _dip_left / _dip_total
		var env := _smoother(0.0, 0.3, k) * (1.0 - _smoother(0.72, 1.0, k))
		head = lerpf(head, -1.0, env) + sin(_t * 5.5) * 0.03 * env
	head += sin(_gait) * 0.12 * _walk
	var look := sin(_t * 0.31 + _seed * 3.0) * 0.5 * (1.0 - _walk)
	var stomp := 0.0
	if _stomp_left > 0.0:
		var ks := 1.0 - _stomp_left / 1.1
		stomp = pow(maxf(sin(ks * PI * 2.0), 0.0), 2.0)
	var breath := sin(_t * TAU / float(_params["breath_period"]) + _seed) * float(_params["breath"])

	var vsize := _prop.visual_size()
	var yaw_b := Basis(Vector3.UP, _yaw)
	var world := _prop.global_transform
	var local := Vector3(_pos.x, 0.0, _pos.y)
	# Appoggio al terreno: quota sotto cinque punti (centro, avanti, dietro, lati); si sta sul più alto.
	var half_l := vsize.z * 0.32
	var half_w := vsize.x * 0.3
	var centre := world * local
	var fwd := (world.basis * yaw_b * Vector3(0, 0, -1)).normalized() * half_l
	var side := (world.basis * yaw_b * Vector3(1, 0, 0)).normalized() * half_w
	var hf := _ground(centre.x + fwd.x, centre.z + fwd.z)
	var hb := _ground(centre.x - fwd.x, centre.z - fwd.z)
	var hl := _ground(centre.x - side.x, centre.z - side.z)
	var hr := _ground(centre.x + side.x, centre.z + side.z)
	var hc := _ground(centre.x, centre.z)
	var top := maxf(maxf(hf, hb), maxf(maxf(hl, hr), hc))
	var want_y := top - _prop.global_position.y
	_ground_y = want_y if not _ground_ready else lerpf(_ground_y, want_y, 1.0 - exp(-delta * 8.0))
	_ground_ready = true
	# Inclinazione di metà della pendenza (non fa affondare né sollevare troppo le zampe).
	var slope_p := atan2(hf - hb, half_l * 2.0) * 0.5
	var slope_r := atan2(hr - hl, half_w * 2.0) * 0.5
	var k_s := 1.0 - exp(-delta * 5.0)
	_pitch = lerpf(_pitch, slope_p, k_s)
	_roll = lerpf(_roll, slope_r, k_s)

	var bob := absf(sin(_gait)) * 0.010 * vsize.y * _walk
	var roll := _roll + sin(_t * 0.37) * deg_to_rad(0.6) + sin(_gait) * deg_to_rad(1.0) * _walk
	var pitch := _pitch + sin(_gait * 2.0) * deg_to_rad(0.6) * _walk
	var body := Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	visual.transform = Transform3D(yaw_b * body, Vector3(_pos.x, _ground_y + bob, _pos.y))

	var pose := Vector4(_walk, _gait, head, look)
	var extra := Vector4(stomp, _seed, breath, 0.0)
	for mi in _meshes:
		mi.set_instance_shader_parameter("pose", pose)
		mi.set_instance_shader_parameter("extra", extra)


## Sostituisce i materiali standard con quello a rig, copiando le texture, e imposta le dimensioni.
func _rig(visual: Node3D) -> void:
	_rigged = visual
	_meshes.clear()
	for child in visual.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src != null:
				mi.set_surface_override_material(s, _rig_material(src))
		var box := mi.mesh.get_aabb()
		mi.set_instance_shader_parameter("dims", Vector4(box.position.y, box.size.y, box.get_center().z, box.size.z))
		var neck: Vector4 = _params["neck"]
		mi.set_instance_shader_parameter("dims2", Vector4(box.size.x, neck.x, neck.y, neck.z))
		var st: Vector4 = _params["style"]
		mi.set_instance_shader_parameter("style", Vector4(st.x, st.y, st.z, st.w))
		mi.extra_cull_margin = 0.6
		_meshes.append(mi)


static func _rig_material(src: BaseMaterial3D) -> ShaderMaterial:
	var id := src.get_instance_id()
	if _mats.has(id):
		return _mats[id]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if src.albedo_texture:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("albedo_color", src.albedo_color)
	if src.normal_texture:
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("normal_depth", src.normal_scale)
	if src.roughness_texture:
		m.set_shader_parameter("rough_tex", src.roughness_texture)
	m.set_shader_parameter("rough_scale", src.roughness)
	_mats[id] = m
	return m


func _update_events(delta: float) -> void:
	if _dip_left > 0.0:
		_dip_left -= delta
	elif not _walking:
		_next_dip -= delta
		if _next_dip <= 0.0:
			_dip_total = _rng.randf_range(4.0, 7.0)
			_dip_left = _dip_total
			var every: Vector2 = _params["dip_every"]
			_next_dip = _rng.randf_range(every.x, every.y)
	if _stomp_left > 0.0:
		_stomp_left -= delta
	elif bool(_params["stomp"]) and not _walking and _dip_left <= 0.0:
		_next_stomp -= delta
		if _next_stomp <= 0.0:
			_stomp_left = 1.1
			_next_stomp = _rng.randf_range(15.0, 35.0)


func _update_walk(delta: float) -> void:
	var vmax := float(_params["speed"])
	var target_speed := 0.0
	if wander > 0.01:
		if not _walking:
			_rest_left -= delta
			if _rest_left <= 0.0 and _dip_left <= 0.0 and _stomp_left <= 0.0:
				var a := _rng.randf() * TAU
				_target = Vector2(cos(a), sin(a)) * wander * sqrt(_rng.randf())
				_walking = true
		else:
			var to := _target - _pos
			var dist := to.length()
			if dist < 0.05 and _speed < 0.05:
				_walking = false
				var rest: Vector2 = _params["rest"]
				_rest_left = _rng.randf_range(rest.x, rest.y)
			else:
				var want := wrapf(atan2(-to.x, -to.y), -PI, PI)
				var lim := deg_to_rad(max_turn_deg)
				want = clampf(want, -lim, lim)
				var diff := wrapf(want - _yaw, -PI, PI)
				# Rotazione smorzata (accelera e frena), non uno scatto.
				var desired_vel := clampf(diff * 2.5, -float(_params["turn"]), float(_params["turn"]))
				_yaw_vel = lerpf(_yaw_vel, desired_vel, 1.0 - exp(-delta * 5.0))
				_yaw += _yaw_vel * delta
				var aligned := 1.0 - smoothstep(0.35, 1.0, absf(diff))
				target_speed = vmax * aligned * clampf(dist * 1.6, 0.0, 1.0) if dist > 0.05 else 0.0
	if not _walking:
		_yaw_vel = lerpf(_yaw_vel, 0.0, 1.0 - exp(-delta * 6.0))
		_yaw += _yaw_vel * delta
	# Velocità con inerzia; l'andatura segue la velocità reale (niente piedi che scivolano).
	_speed = lerpf(_speed, target_speed, 1.0 - exp(-delta * 2.2))
	if _walking and _speed > 0.0:
		var heading := Vector2(-sin(_yaw), -cos(_yaw))
		_pos += heading * _speed * delta
		_pos = _pos.limit_length(wander)
	_gait = fmod(_gait + _speed / float(_params["stride"]) * TAU * delta, TAU * 4.0)
	_walk = lerpf(_walk, clampf(_speed / vmax, 0.0, 1.0), 1.0 - exp(-delta * 6.0))


func _ground(x: float, z: float) -> float:
	if _terrain == null or not is_instance_valid(_terrain):
		_terrain = get_tree().get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	if _terrain and _terrain.is_active():
		return _terrain.height_at(x, z)
	if _relief == null or not is_instance_valid(_relief):
		_relief = get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	return _relief.height_at_world(x, z) if _relief else 0.0


static func _smoother(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
