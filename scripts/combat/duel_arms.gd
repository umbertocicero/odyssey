class_name DuelArms
extends SkeletonModifier3D
## Braccia di Ulisse in prima persona durante il duello (spada nella destra, scudo sulla sinistra).
##
## Modificatore dello scheletro: gira dopo l'AnimationTree e riposiziona le due catene braccio-avambraccio
## con una IK analitica a due ossa verso polsi bersaglio espressi nel sistema dell'occhio (X a destra,
## Y in alto, -Z verso il nemico), così le braccia stanno sempre dove si vedono bene. Il resto del corpo
## continua a seguire le animazioni. `influence` sfuma dalla posa animata a questa (transizione).
##
## Orientare la lama: prima si ruota l'avambraccio sul proprio asse, poi si piega il polso (al massimo
## WRIST_MAX gradi): la mano è pesata sull'osso della mano (vedi fix_char_arms.py), quindi pugno e spada
## seguono il polso. Lo scudo sta sull'avambraccio: per girarne la faccia si sceglie la posizione del gomito
## e si ruota l'avambraccio.
##
## Nei glb le ossa ".L" sono il lato DESTRO anatomico: la spada è sulla catena ".L", lo scudo su ".R".
##
## Colpi (niente rotazioni della lama: la punta resta puntata o il filo guida il movimento):
##  - AFFONDO (alto = gola/petto, basso = ventre): polso e gomito tornano indietro vicino al corpo, poi il
##    braccio si distende dritto verso il bersaglio, la punta sempre verso il nemico;
##  - FENDENTE LARGO alla testa (da destra di dritto, da sinistra di rovescio): il braccio si allarga e
##    carica dietro la spalla, poi la lama descrive un arco orizzontale all'altezza del collo del nemico,
##    radiale rispetto al corpo, con il filo davanti.
## Parate nelle quattro direzioni (lama o scudo), sussulto quando si è colpiti, braccia più basse e lente
## quando Ulisse è sfinito.

const SWORD_CHAIN: Array[StringName] = [&"upperarm.L", &"forearm.L", &"hand.L"]
const SHIELD_CHAIN: Array[StringName] = [&"upperarm.R", &"forearm.R", &"hand.R"]
const WRIST_MAX := deg_to_rad(70.0)
const ATTACK_LEN := 0.62            ## durata di un colpo (s), impatto a 0,22 come Duel.ANIM_IMPACT
const IMPACT := 0.22
## Dove si trova il nemico nel sistema dell'occhio (petto/testa a ~1,5 m).
const FOE_HEAD := Vector3(0.0, 0.02, -1.5)
const FOE_BELLY := Vector3(0.0, -0.28, -1.5)
const ELBOW_DEFAULT := Vector3(0.35, -0.55, 0.25)

## Posa delle braccia nel sistema dell'occhio (metri): polso della spada, direzione della lama e suggerimento
## del gomito (rispetto al polso); polso dello scudo e normale della sua faccia.
class Pose:
	var r: Vector3
	var d: Vector3
	var l: Vector3
	var n: Vector3
	var e: Vector3

	func _init(r_: Vector3, d_: Vector3, l_: Vector3, n_: Vector3, e_ := ELBOW_DEFAULT) -> void:
		r = r_
		d = d_.normalized()
		l = l_
		n = n_.normalized()
		e = e_

	func mix(o: Pose, t: float) -> Pose:
		return Pose.new(r.lerp(o.r, t), d.slerp(o.d, t), l.lerp(o.l, t), n.slerp(o.n, t), e.lerp(o.e, t))

	func moved(dr: Vector3, dl: Vector3) -> Pose:
		return Pose.new(r + dr, d, l + dl, n, e)


## Riferimento nel mondo: occhio di Ulisse senza tremolii della camera. Lo aggiorna Duel ogni frame.
var frame := Transform3D.IDENTITY
var exhausted := false

var _chain_r: Array[int] = []
var _chain_l: Array[int] = []
var _blade_in_hand := Vector3.UP     # direzione della lama nel sistema dell'osso della mano
var _shield_in_fore := Vector3.BACK  # normale dello scudo nel sistema dell'avambraccio
var _has_blade := false
var _has_shield := false
var _last_elbow_l := Vector3.ZERO    # gomito dello scudo al frame prima (continuità)
var _last_elbow_r := Vector3.ZERO    # gomito della spada al frame prima

var _guard: Pose
var _keys: Array = []                # [[t, Pose], ...] della parata in corso
var _key_t := 0.0                    # tempo dall'inizio del movimento in corso (colpo o parata)
var _hold: Pose                      # parata tenuta
var _hold_t := 0.0
var _attack_aim := -1                # colpo in corso (-1 = nessuno)
var _attack_from: Pose
var _time := 0.0
var _jolt := Vector3.ZERO
var _jolt_v := Vector3.ZERO
var _tired := 0.0
var _current: Pose


func _init() -> void:
	_guard = _make_guard()
	_current = _guard


static func _make_guard() -> Pose:
	# Spada in basso a destra con la punta verso il nemico, scudo sul bordo sinistro.
	return Pose.new(Vector3(0.14, -0.13, -0.33), Vector3(-0.3, 0.6, -1.0), Vector3(-0.3, -0.25, -0.22), Vector3(0.45, 0.05, -1.0))


## Misura come sono montati spada e scudo: le armi sono figlie di BoneAttachment3D, quindi la loro
## trasformazione locale è già nel sistema dell'osso (indipendente dalla posa del momento).
func calibrate(gear: UnitGear) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_chain_r.clear()
	_chain_l.clear()
	for b in SWORD_CHAIN:
		_chain_r.append(sk.find_bone(b))
	for b in SHIELD_CHAIN:
		_chain_l.append(sk.find_bone(b))
	if gear == null:
		return
	if gear.weapon_node != null and gear.weapon_node.get_parent() is BoneAttachment3D:
		# Asse +Y del modello dell'arma = dalla presa verso la punta.
		_blade_in_hand = gear.weapon_node.transform.basis.y.normalized()
		_has_blade = true
	if gear.shield_node != null and gear.shield_node.get_parent() is BoneAttachment3D:
		var xf := gear.shield_node.transform
		var normal := xf.basis.z.normalized()
		# Verso fuori: dall'asse dell'avambraccio (Y dell'osso) verso il centro dello scudo.
		var off := xf * Vector3(0.0, 0.464, 0.0)
		off.y = 0.0
		if normal.dot(off) < 0.0:
			normal = -normal
		_shield_in_fore = normal
		_has_shield = true


func _valid() -> bool:
	return _chain_r.size() == 3 and _chain_l.size() == 3 and not _chain_r.has(-1) and not _chain_l.has(-1)


# =====================================================================================================
# Movimenti
# =====================================================================================================

## Colpo nella direzione `aim` (Duel.Aim: 0 alto, 1 sinistra, 2 destra, 3 basso). Impatto a 0,22 s.
func play_attack(aim: int) -> void:
	_attack_aim = aim
	_attack_from = _current
	_key_t = 0.0
	_keys = []
	_hold = null


## Parata nella direzione `aim` (-1 = scudo davanti al centro), tenuta per `hold` secondi.
func play_parry(aim: int, hold := 0.38) -> void:
	var g := _guard
	var p: Pose
	match aim:
		0:   # lama di traverso sopra la testa
			p = Pose.new(Vector3(0.06, 0.0, -0.3), Vector3(-1.0, 0.12, -0.2), g.l + Vector3(0.0, 0.03, 0.0), g.n, Vector3(0.35, -0.3, 0.2))
		1:   # scudo a sinistra davanti
			p = Pose.new(g.r + Vector3(0.02, 0.02, 0.0), g.d, Vector3(-0.11, -0.1, -0.32), Vector3(-0.45, 0.05, -1.0))
		2:   # lama dritta a destra
			p = Pose.new(Vector3(0.22, -0.06, -0.3), Vector3(0.05, 1.0, -0.2), g.l, g.n)
		3:   # lama verso il basso, scudo abbassato
			p = Pose.new(Vector3(0.12, -0.22, -0.32), Vector3(0.15, -1.0, -0.25), Vector3(-0.13, -0.22, -0.3), Vector3(0.0, -0.25, -1.0))
		_:   # scudo davanti al centro
			p = Pose.new(g.r, g.d, Vector3(-0.07, -0.11, -0.3), Vector3(0.0, 0.05, -1.0))
	_attack_aim = -1
	_keys = [[0.0, _current], [0.09, p]]
	_key_t = 0.0
	_hold = p
	_hold_t = hold


## Sussulto: le braccia vengono spinte indietro e in basso dal colpo (o dalla parata).
func jolt(strength := 1.0) -> void:
	_jolt_v += Vector3(randf_range(-0.3, 0.3), -0.45, 0.8) * strength


static func _ease(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Posa del colpo `aim` al tempo `t` (s dall'inizio), partendo dalla guardia `g`.
func _attack_pose(aim: int, t: float, g: Pose) -> Pose:
	if aim == 0 or aim == 3:
		# AFFONDO: carica indietro (polso e gomito vicino al corpo), poi distensione dritta al bersaglio.
		var target := FOE_HEAD if aim == 0 else FOE_BELLY
		# Polso basso e a destra: la lama sale in diagonale verso il bersaglio e resta visibile.
		var ty := -0.22 if aim == 0 else -0.3
		var chamber := Vector3(0.24, ty - 0.04, -0.12)
		var reach := Vector3(0.2, ty, -0.4)
		var hand: Vector3
		var elbow: Vector3
		if t < 0.14:
			var f := _ease(0.0, 0.14, t)
			hand = g.r.lerp(chamber, f)
			elbow = ELBOW_DEFAULT.lerp(Vector3(0.12, -0.3, 0.42), f)   # gomito indietro
		else:
			var f2 := clampf((t - 0.14) / (IMPACT - 0.14), 0.0, 1.0)
			f2 = f2 * f2   # accelera fino all'impatto
			hand = chamber.lerp(reach, f2)
			elbow = Vector3(0.12, -0.3, 0.42).lerp(Vector3(0.18, -0.45, 0.1), f2)
		var d := (target - hand).normalized()   # la punta guarda sempre il bersaglio
		return Pose.new(hand, d, g.l, g.n, elbow)
	# FENDENTE LARGO alla testa: il braccio si allarga e carica, poi la lama gira in orizzontale.
	var side := 1.0 if aim == 2 else -1.0
	var center := Vector3(0.07, -0.05, -0.02)
	var radius := 0.3
	var th0 := deg_to_rad(78.0) if side > 0.0 else deg_to_rad(-62.0)
	var th1 := deg_to_rad(-52.0) if side > 0.0 else deg_to_rad(48.0)
	var arc_y := -0.02
	var chamber_r := center + Vector3(sin(th0) * radius, arc_y + 0.05, -cos(th0) * radius)
	var chamber_d := Vector3(sin(th0 + side * 0.9), 0.35, -cos(th0 + side * 0.9)).normalized()   # lama dietro la spalla
	var chamber_e := Vector3(side * 0.28, -0.12, 0.28)   # gomito alto e in fuori
	if t < 0.15:
		var f := _ease(0.0, 0.15, t)
		return Pose.new(g.r.lerp(chamber_r, f), g.d.slerp(chamber_d, f), g.l, g.n, ELBOW_DEFAULT.lerp(chamber_e, f))
	# Arco: velocità massima all'impatto (0,22, a metà arco, davanti al nemico), poi rallenta.
	var u := clampf((t - 0.15) / 0.14, 0.0, 1.3)
	var s := 0.5 - 0.5 * cos(PI * minf(u, 1.0)) + (u - 1.0) * 0.25 * float(u > 1.0)
	var th := lerpf(th0, th1, s)
	var hand := center + Vector3(sin(th) * radius, arc_y - 0.04 * sin(PI * clampf(s, 0.0, 1.0)), -cos(th) * radius)
	# Lama di traverso: punta in avanti e verso dove va il colpo (il filo guida il taglio), così dalla
	# prima persona attraversa lo schermo invece di sparire di scorcio.
	var radial := Vector3(sin(th), 0.0, -cos(th))
	var tangent := Vector3(cos(th), 0.0, sin(th)) * -side
	var d := (radial * 0.55 + tangent + Vector3(0.0, 0.08, 0.0)).normalized()
	var w := _ease(0.0, 0.25, u)
	d = chamber_d.slerp(d, w)
	var elbow := chamber_e.lerp(Vector3(-side * 0.05, -0.35, 0.2), s)
	return Pose.new(hand, d, g.l + Vector3(-0.03, -0.03, 0.04) * sin(PI * s), g.n, elbow)


# =====================================================================================================
# Calcolo
# =====================================================================================================

func _sample(dt: float) -> Pose:
	_time += dt
	_tired = move_toward(_tired, 1.0 if exhausted else 0.0, dt * 2.0)
	var base := _guard
	# Respiro: la punta della spada disegna un piccolo otto.
	var br := Vector3(sin(_time * 1.1) * 0.006, sin(_time * 1.8) * 0.008, 0.0)
	base = Pose.new(base.r + br + Vector3(0, -0.07, 0.03) * _tired, base.d.lerp(Vector3(0.1, -0.2, -1.0), _tired * 0.6), base.l + br * 0.6 + Vector3(0, -0.06, 0.03) * _tired, base.n)
	var pose := base
	if _attack_aim >= 0:
		_key_t += dt * (1.0 - 0.25 * _tired)
		var t := _key_t
		var ap := _attack_pose(_attack_aim, minf(t, 0.36), base)
		# Ingresso dalla posa del momento e ritorno in guardia dopo l'accompagnamento.
		if t < 0.05:
			ap = _attack_from.mix(ap, _ease(0.0, 0.05, t))
		if t > 0.36:
			ap = ap.mix(base, _ease(0.36, ATTACK_LEN, t))
		pose = ap
		if t >= ATTACK_LEN:
			_attack_aim = -1
			pose = base
	elif not _keys.is_empty():
		_key_t += dt * (1.0 - 0.25 * _tired)
		var last: float = _keys[_keys.size() - 1][0]
		if _key_t >= last:
			pose = _keys[_keys.size() - 1][1]
			if _hold != null:
				_hold_t -= dt
				if _hold_t <= 0.0:
					_keys = [[0.0, _hold], [0.2, base]]
					_key_t = 0.0
					_hold = null
			else:
				_keys = []
				pose = base
		else:
			for i in range(1, _keys.size()):
				var t1: float = _keys[i][0]
				if _key_t <= t1:
					var t0: float = _keys[i - 1][0]
					var f := _ease(t0, t1, _key_t)
					pose = (_keys[i - 1][1] as Pose).mix(_keys[i][1] as Pose, f)
					break
	# Sussulto a molla, a passi piccoli (un frame lento non deve farla esplodere).
	var rest := minf(dt, 0.25)
	while rest > 0.0:
		var h := minf(rest, 1.0 / 120.0)
		_jolt_v += (-_jolt * 160.0 - _jolt_v * 16.0) * h
		_jolt += _jolt_v * h
		rest -= h
	_jolt = _jolt.limit_length(0.15)
	pose = pose.moved(_jolt, _jolt * 0.7)
	_current = pose
	return pose


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or not _valid() or not frame.origin.is_finite():
		return
	var pose := _sample(delta)
	var to_sk := sk.global_transform.affine_inverse()
	var eb := frame.basis
	_solve_sword(sk, to_sk * (frame * pose.r), to_sk * (frame * (pose.r + pose.e)), to_sk.basis * (eb * pose.d))
	_solve_shield(sk, to_sk * (frame * pose.l), to_sk * (frame * (pose.l + Vector3(-0.35, -0.5, 0.25))), to_sk.basis * (eb * pose.n))


## Braccio della spada: IK con il gomito verso `pole`, poi avambraccio ruotato sul suo asse e polso piegato
## (al massimo WRIST_MAX) perché la lama punti lungo `want`.
func _solve_sword(sk: Skeleton3D, target: Vector3, pole: Vector3, want: Vector3) -> void:
	if _has_blade and want.length() > 0.001:
		# Gomito scelto perché l'avambraccio formi con la lama il suo angolo naturale (presa a martello):
		# così la lama punta dove serve senza piegare troppo il polso. Continuo da un frame all'altro.
		var gu := sk.get_bone_global_pose(_chain_r[0])
		var gf := sk.get_bone_global_pose(_chain_r[1])
		var gh := sk.get_bone_global_pose(_chain_r[2])
		var v := (gf.basis.inverse() * gh.basis * _blade_in_hand).normalized()
		pole = _pick_elbow(gu.origin, target, want.normalized(), v.y, gu.origin.distance_to(gf.origin), gf.origin.distance_to(gh.origin), pole, _last_elbow_r)
		_last_elbow_r = pole
	var r := _ik(sk, _chain_r, target, pole)
	if r.is_empty():
		return
	var fore: Basis = r["fore"]
	var hand: Basis = fore * (r["hand_rel"] as Basis)
	if _has_blade and want.length() > 0.001:
		var w := want.normalized()
		fore = _twist(fore, (r["hand_rel"] as Basis) * _blade_in_hand, w)
		hand = fore * (r["hand_rel"] as Basis)
		var blade := (hand * _blade_in_hand).normalized()
		var ang := blade.angle_to(w)
		if ang > 0.001:
			var axis := blade.cross(w)
			if axis.length() > 0.0001:
				hand = Basis(axis.normalized(), minf(ang, WRIST_MAX)) * hand
	_apply(sk, _chain_r, r, fore, hand)


## Braccio dello scudo: gomito scelto perché l'avambraccio possa girare la faccia dello scudo verso `want`
## (continuo da un frame all'altro), poi rotazione dell'avambraccio sul suo asse.
func _solve_shield(sk: Skeleton3D, target: Vector3, pole: Vector3, want: Vector3) -> void:
	if _has_shield and want.length() > 0.001:
		var gf := sk.get_bone_global_pose(_chain_l[1])
		var gu := sk.get_bone_global_pose(_chain_l[0])
		var gh := sk.get_bone_global_pose(_chain_l[2])
		var cos_t := _shield_in_fore.y / maxf(gf.basis.y.length(), 0.0001)
		pole = _pick_elbow(gu.origin, target, want.normalized(), cos_t, gu.origin.distance_to(gf.origin), gf.origin.distance_to(gh.origin), pole, _last_elbow_l)
		_last_elbow_l = pole
	var r := _ik(sk, _chain_l, target, pole)
	if r.is_empty():
		return
	var fore: Basis = r["fore"]
	if _has_shield and want.length() > 0.001:
		fore = _twist(fore, _shield_in_fore, want.normalized())
	_apply(sk, _chain_l, r, fore, fore * (r["hand_rel"] as Basis))


## IK a due ossa (spalla-gomito-polso) verso `target`, con il gomito dalla parte di `pole` (spazio dello
## scheletro). Restituisce le basi e i punti calcolati (vuoto se lo scheletro non è utilizzabile).
func _ik(sk: Skeleton3D, chain: Array[int], target: Vector3, pole: Vector3) -> Dictionary:
	var gu := sk.get_bone_global_pose(chain[0])
	var gf := sk.get_bone_global_pose(chain[1])
	var gh := sk.get_bone_global_pose(chain[2])
	var a := gu.origin.distance_to(gf.origin)
	var b := gf.origin.distance_to(gh.origin)
	if a < 0.001 or b < 0.001 or not target.is_finite():
		return {}
	var s := gu.origin
	var to := target - s
	var dist := clampf(to.length(), absf(a - b) + 0.002, (a + b) * 0.998)
	var dir := to.normalized() if to.length() > 0.0001 else gu.basis.y.normalized()
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var perp := pole - s
	perp -= dir * perp.dot(dir)
	if perp.length() < 0.0001:
		perp = gu.basis.z
		perp -= dir * perp.dot(dir)
	perp = perp.normalized()
	var elbow := s + dir * (cos_a * a) + perp * (sqrt(maxf(1.0 - cos_a * cos_a, 0.0)) * a)
	var wrist := s + dir * dist
	return {"s": s, "elbow": elbow, "wrist": wrist, "upper": _aim_y(gu.basis, elbow - s),
		"fore": _aim_y(gf.basis, wrist - elbow), "hand_rel": gf.basis.inverse() * gh.basis}


## Scrive le pose locali, calcolate dai genitori già modificati (la cache globale dello scheletro non si
## aggiorna a metà modifica).
func _apply(sk: Skeleton3D, chain: Array[int], r: Dictionary, fore: Basis, hand: Basis) -> void:
	var parent := sk.get_bone_parent(chain[0])
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var gu_new := Transform3D(r["upper"], r["s"])
	var gf_new := Transform3D(fore, r["elbow"])
	sk.set_bone_pose(chain[0], pg.affine_inverse() * gu_new)
	sk.set_bone_pose(chain[1], gu_new.affine_inverse() * gf_new)
	sk.set_bone_pose(chain[2], gf_new.affine_inverse() * Transform3D(hand, r["wrist"]))


## Cerca, attorno a `want`, la direzione dell'avambraccio (a coseno `cos_t` da `want`) per cui il gomito
## cade alla giusta distanza dalla spalla, preferendo quella vicina a `pole` e al gomito del frame prima.
static func _pick_elbow(s: Vector3, target: Vector3, want: Vector3, cos_t: float, a: float, b: float, pole: Vector3, last: Vector3) -> Vector3:
	cos_t = clampf(cos_t, -1.0, 1.0)
	var sin_t := sqrt(1.0 - cos_t * cos_t)
	var e1 := want.cross(Vector3.UP if absf(want.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := want.cross(e1).normalized()
	var best := pole
	var best_score := INF
	for k in 24:
		var phi := TAU * k / 24.0
		var f := want * cos_t + (e1 * cos(phi) + e2 * sin(phi)) * sin_t
		var elbow := target - f * b
		var score := absf(elbow.distance_to(s) - a) * 12.0 + elbow.distance_to(pole) * 0.6
		if last != Vector3.ZERO:
			score += elbow.distance_to(last) * 3.0
		if score < best_score:
			best_score = score
			best = elbow
	return best


## Ruota `basis` (rotazione più breve) perché il suo asse Y punti lungo `dir`.
static func _aim_y(basis: Basis, dir: Vector3) -> Basis:
	if basis.y.length_squared() < 1e-10 or dir.length_squared() < 1e-10 or not dir.is_finite():
		return basis
	var from := basis.y.normalized()
	var to := dir.normalized()
	if from.dot(to) > 0.99999:
		return basis
	if from.dot(to) < -0.99999:
		return Basis(basis.x.normalized(), PI) * basis
	return Basis(Quaternion(from, to)) * basis


## Ruota `basis` attorno al proprio asse Y finché `basis * local_v` è il più vicino possibile a `want`.
static func _twist(basis: Basis, local_v: Vector3, want: Vector3) -> Basis:
	var axis := basis.y.normalized()
	var cur := basis * local_v
	cur -= axis * cur.dot(axis)
	var w := want - axis * want.dot(axis)
	if cur.length() < 0.0001 or w.length() < 0.0001:
		return basis
	var ang := cur.normalized().signed_angle_to(w.normalized(), axis)
	return Basis(axis, ang) * basis
