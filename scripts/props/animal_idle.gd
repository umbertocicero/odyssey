class_name AnimalIdle
extends Node
## Vita leggera per gli animali di scena (cavalli, pecore, maiali). I modelli sono mesh statiche
## senza scheletro, quindi l'animazione è procedurale e agisce solo sul nodo "Visual" del GridProp:
## respiro, peso che passa da un lato all'altro, testa che si abbassa a brucare e si rialza,
## ogni tanto qualche passo in un cerchio piccolo attorno alla posizione di partenza.
## Collisioni, caselle bloccate e griglia non cambiano (restano sul GridProp). Costo: una
## Transform3D per animale per frame, nessuna risorsa nuova (niente VRAM, niente draw call extra).

## Parametri per specie: respiro (periodo s, ampiezza), testa bassa (gradi, ogni quanti secondi),
## andatura (m/s, frequenza passi Hz, rimbalzo m), pausa fra due spostamenti.
const KINDS := {
	"horse": {"breath_period": 4.2, "breath": 0.010, "dip_deg": 5.0, "dip_every": Vector2(9.0, 18.0),
		"speed": 0.45, "step_hz": 1.5, "bob": 0.012, "rest": Vector2(6.0, 14.0), "turn": 70.0},
	"sheep": {"breath_period": 2.6, "breath": 0.014, "dip_deg": 14.0, "dip_every": Vector2(4.0, 9.0),
		"speed": 0.28, "step_hz": 2.2, "bob": 0.008, "rest": Vector2(5.0, 12.0), "turn": 100.0},
	"pig": {"breath_period": 2.2, "breath": 0.016, "dip_deg": 10.0, "dip_every": Vector2(3.0, 8.0),
		"speed": 0.30, "step_hz": 2.4, "bob": 0.008, "rest": Vector2(5.0, 11.0), "turn": 110.0},
}

var kind := "horse"
## Raggio massimo (m) dello spostamento dal punto di partenza. 0 = fermo (solo respiro e testa).
var wander := 1.0
## Rotazione massima rispetto all'orientamento di partenza (gradi), per chi non deve girarsi molto.
var max_turn_deg := 180.0

var _prop: GridProp
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _pos := Vector2.ZERO       # offset XZ nello spazio locale del prop
var _yaw := 0.0
var _target := Vector2.ZERO
var _walking := false
var _rest_left := 0.0
var _gait := 0.0
var _dip_left := 0.0
var _dip_total := 1.0
var _next_dip := 5.0
var _pivot_z := 0.7
var _params: Dictionary
var _grid: DioramaGrid


func setup(prop: GridProp, animal_kind: String, wander_radius: float, turn_limit_deg := 180.0) -> void:
	_prop = prop
	kind = animal_kind if KINDS.has(animal_kind) else "horse"
	wander = maxf(wander_radius, 0.0)
	max_turn_deg = turn_limit_deg
	_params = KINDS[kind]
	var p := prop.global_position
	_rng.seed = hash(Vector3i(roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0)))
	_t = _rng.randf() * 100.0
	_rest_left = _rng.randf_range(0.5, 5.0)
	_next_dip = _rng.randf_range(1.0, 6.0)
	set_process(true)
	_register_body.call_deferred()


func _exit_tree() -> void:
	if _grid != null and is_instance_valid(_grid):
		_grid.remove_body(_prop)


## Corpo dell'animale sulla griglia: una catena di cerchi lungo il corpo (un cavallo ne occupa
## più caselle), che segue i passi. Ulisse, alleati e nemici non lo attraversano e il pathfinding lo aggira.
func _register_body() -> void:
	if _prop == null or not is_instance_valid(_prop) or not _prop.is_inside_tree():
		return
	_grid = get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	if _grid != null:
		_grid.set_body(_prop, _circles(_pos, _yaw))


## Cerchi (x, z, raggio) in coordinate del mondo per la posizione/orientamento dati.
func _circles(pos: Vector2, yaw: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var box := _prop.visual_box()
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return out
	if _pivot_z == 0.7:
		_pivot_z = _prop.visual_size().z * 0.35
	var c := box.get_center()
	var r := clampf(box.size.x * 0.5, 0.22, 0.5)
	var half := maxf(box.size.z * 0.5 - r, 0.0)
	var n := maxi(ceili(half * 2.0 / (r * 1.2)) + 1, 1)
	var yaw_b := Basis(Vector3.UP, yaw)
	var pivot := Vector3(0.0, 0.0, _pivot_z)
	for i in n:
		var z := c.z if n == 1 else lerpf(c.z - half, c.z + half, float(i) / (n - 1))
		var local := yaw_b * (Vector3(c.x, 0.0, z) - pivot) + pivot + Vector3(pos.x, 0.0, pos.y)
		var w := _prop.global_transform * local
		out.append(Vector3(w.x, w.z, r))
	return out


## Applica un nuovo passo/orientamento solo se il corpo ci sta (niente ostacoli, animali o unità).
func _try_move(pos: Vector2, yaw: float) -> bool:
	if _grid != null and is_instance_valid(_grid):
		var circles := _circles(pos, yaw)
		if not _grid.body_fits(_prop, circles):
			return false
		_grid.set_body(_prop, circles)
	_pos = pos
	_yaw = yaw
	return true


func _process(delta: float) -> void:
	if _prop == null or not is_instance_valid(_prop):
		return
	var visual := _prop.visual_node()
	if visual == null:
		return
	delta = minf(delta, 0.1)
	_t += delta
	if _pivot_z == 0.7:
		_pivot_z = _prop.visual_size().z * 0.35

	_update_walk(delta)
	_update_dip(delta)

	# Respiro: il torace si gonfia appena, i piedi restano a terra.
	var b := sin(_t * TAU / float(_params["breath_period"])) * float(_params["breath"])
	var scale_v := Vector3(1.0 + b * 0.4, 1.0 + b, 1.0 + b * 0.5)

	# Testa: inclinazione attorno al posteriore (il fronte è -Z).
	var dip := 0.0
	if _dip_left > 0.0:
		var k := 1.0 - _dip_left / _dip_total
		dip = smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.7, 1.0, k))
	var pitch := -deg_to_rad(float(_params["dip_deg"])) * dip

	# Peso che passa da un lato all'altro e, camminando, dondolio dell'andatura.
	var roll := sin(_t * 0.37) * deg_to_rad(0.7)
	var bob := 0.0
	if _walking:
		var ph := _gait * TAU
		bob = absf(sin(ph)) * float(_params["bob"])
		roll += sin(ph) * deg_to_rad(1.2)
		pitch += sin(ph * 2.0) * deg_to_rad(0.8)

	var yaw_b := Basis(Vector3.UP, _yaw)
	var body := Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll) * Basis.from_scale(scale_v)
	var pivot := Vector3(0.0, 0.0, _pivot_z)
	var basis := yaw_b * body
	var origin := Vector3(_pos.x, bob, _pos.y) + yaw_b * (pivot - body * pivot)
	visual.transform = Transform3D(basis, origin)


func _update_dip(delta: float) -> void:
	if _dip_left > 0.0:
		_dip_left -= delta
		return
	_next_dip -= delta
	if _next_dip <= 0.0 and not _walking:
		_dip_total = _rng.randf_range(3.5, 6.0)
		_dip_left = _dip_total
		var every: Vector2 = _params["dip_every"]
		_next_dip = _rng.randf_range(every.x, every.y)


func _update_walk(delta: float) -> void:
	if wander <= 0.01:
		return
	if not _walking:
		_rest_left -= delta
		if _rest_left <= 0.0 and _dip_left <= 0.0:
			var a := _rng.randf() * TAU
			_target = Vector2(cos(a), sin(a)) * wander * sqrt(_rng.randf())
			_walking = true
		return
	var to := _target - _pos
	var dist := to.length()
	if dist < 0.06:
		_walking = false
		var rest: Vector2 = _params["rest"]
		_rest_left = _rng.randf_range(rest.x, rest.y)
		return
	# Prima ci si gira verso la meta, poi si cammina. Ogni gesto passa dal controllo d'ingombro:
	# se qualcosa è in mezzo (unità, ostacolo, altro animale) l'animale si ferma e riposa.
	var want := atan2(-to.x, -to.y)
	var lim := deg_to_rad(max_turn_deg)
	want = clampf(wrapf(want, -PI, PI), -lim, lim)
	var turn_rate := deg_to_rad(float(_params["turn"])) * delta
	var diff := wrapf(want - _yaw, -PI, PI)
	var new_yaw := _yaw + clampf(diff, -turn_rate, turn_rate)
	var new_pos := _pos
	var stepped := false
	if absf(diff) < deg_to_rad(35.0):
		new_pos = _pos + to / dist * minf(float(_params["speed"]) * delta, dist)
		stepped = true
	if not _try_move(new_pos, new_yaw):
		_walking = false
		_rest_left = _rng.randf_range(2.0, 5.0)
		return
	if stepped:
		_gait = fmod(_gait + float(_params["step_hz"]) * delta * 0.5, 1.0)
