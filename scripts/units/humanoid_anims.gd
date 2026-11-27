class_name HumanoidAnims
extends RefCounted
## Animazioni procedurali dei personaggi riggati a 17 ossa (personaggi_nuovi/), calcolate a runtime e
## condivise da tutti (i 13 rig hanno la stessa posa a riposo). Non si ruotano le ossa "a occhio": ogni
## fotogramma è descritto da obiettivi nello spazio del modello (caviglie, polsi, direzione della lama,
## scudo) e risolto con cinematica inversa a due ossa con cerniera fissa (ginocchio, gomito):
## - i piedi d'appoggio restano piantati a terra (camminata e corsa senza scivolare se la velocità
##   di riproduzione segue quella reale: vedi `stride()`), con rullata tallone-punta;
## - le mani tengono l'arma per l'impugnatura e la lama punta dove serve; lo scudo sta sull'avambraccio
##   come un hoplon (braccio nel porpax), la faccia segue il dorso dell'avambraccio;
## - il bacino si abbassa da solo quanto serve perché le gambe arrivino ai piedi (niente iperestensioni).
## Le chiavi delle azioni si interpolano con spline (Catmull-Rom): movimenti continui, non a scatti.
##
## Spazio dello scheletro: fronte +Z, su +Y. Attenzione: nei glb le ossa ".L" stanno a -X, cioè sul lato
## DESTRO anatomico del personaggio (che guarda +Z); le ".R" sono il lato sinistro. Qui il lato 0 è il
## destro anatomico (arma), il lato 1 il sinistro (scudo, arco).
## Le librerie sono in cache per configurazione d'armi + insiemi di clip; le tracce usano il percorso
## ".:osso" e vanno usate con un AnimationMixer il cui root_node è lo Skeleton3D.

enum Hand { NONE, SWORD, SPEAR, BOW }

## Mano: le dita sono chiuse a pugno da HandFist (deformazione della mesh all'avvio). Il manico di ogni
## oggetto passa nel pugno lungo la larghezza della mano, nel punto HandFist.grip_point, con la punta
## (lama, cuspide, fiamma, flettente alto dell'arco) dal lato del pollice: presa a martello.
## Distanza della faccia interna dello scudo dall'asse dell'avambraccio.
## Quota della caviglia sopra il terreno (m): e' la quota dell'osso del piede a riposo nei modelli di personaggi_nuovi (media 0,105; vecchi rig 0,072).
const ANKLE_H := 0.105
const SHIELD_OUT := 0.075
## Lunghezze delle armi dal centro della presa (spada: pomolo / punta; lancia: puntale / cuspide).
const SWORD_BACK := 0.07
const SWORD_TIP := 0.43
const SPEAR_BACK := 0.73
const SPEAR_TIP := 1.37
const SHIELD_RADIUS := 0.255

## Passo per ciclo (m) delle andature: la velocità di riproduzione è velocità / passo.
const STRIDE := {
	&"walk": 1.12, &"run": 2.3, &"limp_walk": 0.8, &"limp_run": 1.3,
	&"support_walk": 1.0, &"support_run": 2.0, &"stretcher_r_walk": 1.0, &"stretcher_l_walk": 1.0,
	&"stretcher_r_run": 1.7, &"stretcher_l_run": 1.7,
	&"torch_walk": 1.12, &"torch_run": 2.3,
	&"carry_r_walk": 1.0, &"carry_r_run": 2.0, &"carry_l_walk": 1.0, &"carry_l_run": 2.0,
	&"limp_l_walk": 0.8, &"limp_l_run": 1.3, &"limp_r_walk": 0.8, &"limp_r_run": 1.3, &"limp_lr_walk": 0.8, &"limp_lr_run": 1.3,
	&"drag_walk": 0.7, &"drag_l_walk": 0.7, &"drag_r_walk": 0.7, &"dragged_walk": 0.7,
}

static var _cache := {}
static var _rig: Rig


## Passo per ciclo dell'andatura `anim` (vedi STRIDE).
static func stride(anim: StringName) -> float:
	return STRIDE.get(anim, 1.12)


## Chiave di configurazione: arma nella mano destra, scudo o arco nella sinistra.
static func config_key(right: Hand, shield: bool, bow: bool) -> String:
	return "%d_%s_%s" % [int(right), "S" if shield else "-", "B" if bow else "-"]


## Libreria con le clip degli insiemi richiesti ("base", "support", "limp", "stretcher", "bow", "leader").
## `skeleton` serve solo la prima volta (le pose a riposo sono uguali per tutti i personaggi).
static func library(skeleton: Skeleton3D, right: Hand, shield: bool, bow: bool, sets: PackedStringArray) -> AnimationLibrary:
	if _rig == null:
		_rig = Rig.new(skeleton)
	var key := config_key(right, shield, bow) + "|" + ",".join(sets)
	if _cache.has(key):
		return _cache[key]
	var lib := AnimationLibrary.new()
	var cfg := Cfg.new(right, shield, bow)
	for s in sets:
		var clips := _clips_for(s, cfg)
		for name: StringName in clips:
			lib.add_animation(name, clips[name])
	_cache[key] = lib
	return lib


## Base dell'arma a riposo nello spazio del modello (per UnitGear). La mano visibile è pesata
## sull'avambraccio: l'osso della mano resta dritto e l'arma si orienta ruotando l'avambraccio.
static func weapon_rest_basis(skeleton: Skeleton3D, bone: StringName, kind: int) -> Basis:
	var x := skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin.x
	return _weapon_basis_rest(kind, signf(x) if absf(x) > 0.001 else 1.0)


## kind: 0 spada/torcia, 1 lancia, 2 arco (come UnitGear.WeaponKind); sx: lato della mano.
## Asse +Y dell'oggetto verso il pollice; per l'arco la corda (-Z del modello) verso il polso.
static func _weapon_basis_rest(kind: int, sx: float) -> Basis:
	var ax := HandFist.axes(sx)
	var fing: Vector3 = ax[0]
	var thumb: Vector3 = ax[2]
	if kind == 2:
		return Basis(thumb.cross(fing), thumb, fing)
	return Basis(fing, thumb, fing.cross(thumb))


## Centro della presa a riposo nello spazio del modello (nel palmo, vedi GRIP_OFFSET).
static func grip_rest_position(skeleton: Skeleton3D, bone: StringName) -> Vector3:
	var g := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	return g.origin + _grip_offset(g.origin.x)


## Posizione e orientamento locali (rispetto all'osso della mano) di un oggetto lungo con l'origine nel
## punto di presa e l'asse +Y verso la punta (spada, torcia): da assegnare al nodo figlio di un
## BoneAttachment3D sulla mano. `kind`: 0 spada/torcia, 1 lancia, 2 arco.
static func hand_item_transform(skeleton: Skeleton3D, bone: StringName, kind := 0) -> Transform3D:
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	return rest.affine_inverse() * Transform3D(weapon_rest_basis(skeleton, bone, kind), grip_rest_position(skeleton, bone))


static func _grip_offset(wrist_x: float) -> Vector3:
	return HandFist.grip_point(signf(wrist_x) if absf(wrist_x) > 0.001 else 1.0)


## Trasformazione dello scudo a riposo (spazio del modello) sull'avambraccio `forearm`: faccia sul dorso
## dell'avambraccio, centro a metà avambraccio. `center_local` è il centro del modello dello scudo.
static func shield_rest_transform(skeleton: Skeleton3D, forearm: StringName, scale: float, center_local: Vector3, flip: bool) -> Transform3D:
	var fi := skeleton.find_bone(forearm)
	var g := skeleton.get_bone_global_rest(fi)
	var child := -1
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_parent(i) == fi:
			child = i
	var end := skeleton.get_bone_global_rest(child).origin if child >= 0 else g.origin + g.basis.y * 0.15
	var f := (end - g.origin).normalized()
	var side := signf(g.origin.x) if absf(g.origin.x) > 0.001 else 1.0
	var n := Vector3(side, 0, 0)
	n = (n - f * n.dot(f)).normalized()
	var up := f.cross(n) if side > 0.0 else n.cross(f)
	var z := -n if flip else n
	var b := Basis(up.cross(z), up, z)
	var center := g.origin + f * (g.origin.distance_to(end) * 0.5) + n * SHIELD_OUT
	return Transform3D(b.scaled(Vector3.ONE * scale), center - (b * center_local) * scale)


# =====================================================================================================
# Rig e posa
# =====================================================================================================

class Rig:
	var count := 0
	var idx := {}
	var parent := PackedInt32Array()
	var rest: Array[Transform3D] = []
	var grest: Array[Transform3D] = []
	var hips := 0
	var spine := 0
	var neck := 0
	var head := 0
	var up := [0, 0]
	var lo := [0, 0]
	var hand := [0, 0]
	var thigh := [0, 0]
	var shin := [0, 0]
	var foot := [0, 0]
	var arm_hinge := [[Vector3.ZERO, Vector3.ZERO], [Vector3.ZERO, Vector3.ZERO]]
	var leg_hinge := [[Vector3.ZERO, Vector3.ZERO], [Vector3.ZERO, Vector3.ZERO]]
	var thumb_loc := [Vector3.ZERO, Vector3.ZERO]
	var axis_loc := [Vector3.ZERO, Vector3.ZERO]
	var grip_loc := [Vector3.ZERO, Vector3.ZERO]
	## Nello spazio locale dell'avambraccio (mano dritta): asse della lama, asse delle dita, normale del
	## palmo e presa rispetto al gomito.
	var blade_fl := [Vector3.ZERO, Vector3.ZERO]
	var fing_fl := [Vector3.ZERO, Vector3.ZERO]
	var palm_fl := [Vector3.ZERO, Vector3.ZERO]
	var grip_fl := [Vector3.ZERO, Vector3.ZERO]
	var dorsal_loc := Vector3.ZERO
	var leg_len := 0.63

	func _init(sk: Skeleton3D) -> void:
		count = sk.get_bone_count()
		for i in count:
			idx[sk.get_bone_name(i)] = i
			parent.append(sk.get_bone_parent(i))
			rest.append(sk.get_bone_rest(i).orthonormalized())
			grest.append(sk.get_bone_global_rest(i).orthonormalized())
		hips = idx["hips"]
		spine = idx["spine"]
		neck = idx.get("neck", spine)
		head = idx["head"]
		for s in 2:
			var suf: String = ".L" if s == 0 else ".R"
			up[s] = idx["upperarm" + suf]
			lo[s] = idx["forearm" + suf]
			hand[s] = idx["hand" + suf]
			thigh[s] = idx["thigh" + suf]
			shin[s] = idx["shin" + suf]
			foot[s] = idx["foot" + suf]
			# Cerniere anatomiche: il gomito punta indietro, il ginocchio in avanti.
			arm_hinge[s] = [_hinge(up[s], lo[s], Vector3(0, 0, -1)), _hinge(lo[s], hand[s], Vector3(0, 0, -1))]
			leg_hinge[s] = [_hinge(thigh[s], shin[s], Vector3(0, 0, 1)), _hinge(shin[s], foot[s], Vector3(0, 0, 1))]
			var hb: Basis = grest[hand[s]].basis
			var sxh := signf(grest[hand[s]].origin.x)
			var hax := HandFist.axes(sxh)
			thumb_loc[s] = hb.inverse() * (hax[2] as Vector3)
			axis_loc[s] = hb.inverse() * (hax[0] as Vector3)
			grip_loc[s] = hb.inverse() * HumanoidAnims._grip_offset(grest[hand[s]].origin.x)
			var fb: Basis = grest[lo[s]].basis
			# Tutti gli oggetti passano nel pugno lungo il pollice (anche lancia, arco e stanghe).
			blade_fl[s] = fb.inverse() * (hax[2] as Vector3)
			fing_fl[s] = blade_fl[s]
			palm_fl[s] = fb.inverse() * (hax[1] as Vector3)
			grip_fl[s] = fb.inverse() * (grest[hand[s]].origin + HumanoidAnims._grip_offset(grest[hand[s]].origin.x) - grest[lo[s]].origin)
		var fb: Basis = grest[lo[1]].basis
		var f := (grest[hand[1]].origin - grest[lo[1]].origin).normalized()
		var n := Vector3(1, 0, 0)
		dorsal_loc = fb.inverse() * (n - f * n.dot(f)).normalized()
		leg_len = rest[shin[0]].origin.length() + rest[foot[0]].origin.length()

	func _hinge(bone: int, child: int, pole: Vector3) -> Vector3:
		var d := (grest[child].origin - grest[bone].origin).normalized()
		return grest[bone].basis.inverse() * pole.cross(d).normalized()


class Pose:
	var rig: Rig
	var rot: Array[Quaternion] = []
	var hips_pos := Vector3.ZERO
	var g: Array[Transform3D] = []

	func _init(r: Rig) -> void:
		rig = r
		for i in r.count:
			rot.append(r.rest[i].basis.get_rotation_quaternion())
			g.append(r.grest[i])
		hips_pos = r.rest[r.hips].origin

	func fk() -> void:
		for i in rig.count:
			var o := hips_pos if i == rig.hips else rig.rest[i].origin
			var t := Transform3D(Basis(rot[i]), o)
			var p := rig.parent[i]
			g[i] = t if p < 0 else g[p] * t

	## Rotazione (gradi, assi del modello) relativa al genitore a riposo; si compone lungo la catena.
	func rel(i: int, deg: Vector3) -> void:
		var p := rig.parent[i]
		var pb: Basis = rig.grest[p].basis if p >= 0 else Basis.IDENTITY
		var d := Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)), EULER_ORDER_YXZ)
		rot[i] = (pb.inverse() * d * pb * rig.rest[i].basis).get_rotation_quaternion()

	## Imposta l'orientamento globale (spazio del modello) dell'osso; il genitore dev'essere aggiornato.
	func set_global(i: int, b: Basis) -> void:
		var p := rig.parent[i]
		var pb: Basis = g[p].basis if p >= 0 else Basis.IDENTITY
		rot[i] = (pb.inverse() * b).orthonormalized().get_rotation_quaternion()
		var o := hips_pos if i == rig.hips else rig.rest[i].origin
		g[i] = (g[p] if p >= 0 else Transform3D.IDENTITY) * Transform3D(Basis(rot[i]), o)

	## Cinematica inversa a due ossa con cerniera: `pole` è la direzione verso cui punta l'articolazione.
	func limb(i_up: int, i_lo: int, i_end: int, target: Vector3, pole: Vector3, h_up: Vector3, h_lo: Vector3) -> void:
		var a := g[i_up].origin
		var l1 := rig.rest[i_lo].origin.length()
		var l2 := rig.rest[i_end].origin.length()
		var dv := target - a
		var dist := dv.length()
		var dir := dv / dist if dist > 0.0001 else Vector3.DOWN
		var d := clampf(dist, absf(l1 - l2) + 0.02, (l1 + l2) * 0.9995)
		var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
		var sa := sqrt(maxf(0.0, 1.0 - ca * ca))
		var perp := pole - dir * pole.dot(dir)
		if perp.length_squared() < 0.000001:
			perp = dir.cross(Vector3.RIGHT)
		perp = perp.normalized()
		var b := a + dir * (l1 * ca) + perp * (l1 * sa)
		var c := a + dir * d
		var ud := (b - a).normalized()
		var ld := (c - b).normalized()
		var h := ud.cross(ld)
		h = h.normalized() if h.length() > 0.05 else perp.cross(dir).normalized()
		set_global(i_up, HumanoidAnims._align(rig.rest[i_lo].origin, h_up, ud, h))
		set_global(i_lo, HumanoidAnims._align(rig.rest[i_end].origin, h_lo, ld, h))
		var o := rig.rest[i_end].origin
		g[i_end] = g[i_lo] * Transform3D(Basis(rot[i_end]), o)


class Cfg:
	var right: int
	var shield: bool
	var bow: bool
	func _init(r: int, s: bool, b: bool) -> void:
		right = r
		shield = s
		bow = b


static func _frame(a: Vector3, b: Vector3) -> Basis:
	var x := a.normalized()
	var y := b - x * b.dot(x)
	if y.length_squared() < 0.0000001:
		y = x.cross(Vector3.UP if absf(x.y) < 0.9 else Vector3.RIGHT)
	y = y.normalized()
	return Basis(x, y, x.cross(y))


## Rotazione che porta u1 su v1 e (per quanto possibile) u2 su v2.
static func _align(u1: Vector3, u2: Vector3, v1: Vector3, v2: Vector3) -> Basis:
	return _frame(v1, v2) * _frame(u1, u2).transposed()


# =====================================================================================================
# Risolutore: campi di una posa -> rotazioni delle ossa
# =====================================================================================================
# Campi (spazio del modello salvo dove indicato; lato 0 = destro anatomico, 1 = sinistro):
#  hp  scarto del bacino (m)          hr  rotazione del bacino (gradi: x avanti, y torsione, z fianco)
#  sp, nk, hd  busto, collo, testa (gradi, relativi)
#  f0, f1  caviglie;  p0, p1  piede (x punta in su, y punta in fuori, z);  q0, q1  piede libero (0..1)
#  k0, k1  direzione del ginocchio (spazio del bacino)
#  w0, w1  polsi (spazio del busto a riposo);  m0, m1 polsi nel modello;  mw0, mw1 peso di m
#  e0, e1  direzione del gomito (busto);  d0, d1  direzione dell'arma / del pollice (busto, ZERO = libera)
#  a0, a1  asse della mano (busto, ZERO = prosegue l'avambraccio)
#  se, sf, sn  scudo (lato 1): gomito, direzione dell'avambraccio, normale dello scudo (busto)
#  th  0..1 la mano sinistra impugna la lancia (a td metri dalla presa destra)

const _STAND := {
	"hp": Vector3(0, -0.025, 0), "hr": Vector3.ZERO, "sp": Vector3(2, 0, 0), "nk": Vector3.ZERO, "hd": Vector3(-2, 0, 0),
	"f0": Vector3(-0.105, ANKLE_H, -0.01), "f1": Vector3(0.105, ANKLE_H, 0.01),
	"p0": Vector3(0, 8, 0), "p1": Vector3(0, 8, 0), "q0": 0.0, "q1": 0.0,
	"k0": Vector3(-0.15, 0, 1), "k1": Vector3(0.15, 0, 1),
	"w0": Vector3(-0.2, 0.71, 0.04), "w1": Vector3(0.2, 0.71, 0.04),
	"m0": Vector3(-0.2, 0.71, 0.04), "m1": Vector3(0.2, 0.71, 0.04), "mw0": 0.0, "mw1": 0.0,
	"e0": Vector3(-0.35, 0, -1), "e1": Vector3(0.35, 0, -1),
	"d0": Vector3.ZERO, "d1": Vector3.ZERO, "a0": Vector3.ZERO, "a1": Vector3.ZERO,
	"se": Vector3(0.19, 0.84, -0.02), "sf": Vector3(-0.3, -0.25, 0.92), "sn": Vector3(0.85, 0, 0.45),
	"th": 0.0, "td": 0.42, "x0": 0.0, "x1": 0.0,
}


static func _solve(f: Dictionary, cfg: Cfg) -> Pose:
	var r := _rig
	var p := Pose.new(r)
	p.hips_pos = r.rest[r.hips].origin + (f["hp"] as Vector3)
	p.rel(r.hips, f["hr"])
	p.rel(r.spine, f["sp"])
	if r.neck != r.spine:
		p.rel(r.neck, f["nk"])
	p.rel(r.head, f["hd"])
	p.fk()
	# Il bacino scende quanto serve perché le gambe d'appoggio arrivino alle caviglie.
	var reach := r.leg_len * 0.985
	var drop := 0.0
	for s in 2:
		var q: float = f["q%d" % s]
		if q >= 0.99:
			continue
		var a := p.g[r.thigh[s]].origin
		var t: Vector3 = f["f%d" % s]
		var dxz := Vector2(t.x - a.x, t.z - a.z).length()
		if dxz >= reach:
			continue
		var need := (a.y - t.y) - sqrt(reach * reach - dxz * dxz)
		drop = maxf(drop, need * (1.0 - q))
	if drop > 0.0:
		p.hips_pos.y -= drop
		p.fk()
	var hb := p.g[r.hips].basis
	for s in 2:
		var t: Vector3 = f["f%d" % s]
		var pole: Vector3 = hb * (f["k%d" % s] as Vector3)
		p.limb(r.thigh[s], r.shin[s], r.foot[s], t, pole, r.leg_hinge[s][0], r.leg_hinge[s][1])
		var pr: Vector3 = f["p%d" % s]
		var sx := -1.0 if s == 0 else 1.0
		var planted := Basis(Vector3.UP, deg_to_rad(pr.y * sx)) * Basis(Vector3.RIGHT, deg_to_rad(-pr.x)) \
			* Basis(Vector3.BACK, deg_to_rad(pr.z * sx)) * r.grest[r.foot[s]].basis
		var q: float = f["q%d" % s]
		if q > 0.0:
			var free := p.g[r.shin[s]].basis * r.rest[r.foot[s]].basis * Basis(Vector3.RIGHT, deg_to_rad(-25.0))
			planted = Basis(planted.get_rotation_quaternion().slerp(free.get_rotation_quaternion(), q))
		p.set_global(r.foot[s], planted)
	# Braccia nello spazio del busto. Lancia e arco si tengono lungo le dita.
	if cfg.right == Hand.SPEAR:
		f["x0"] = 1.0
	if cfg.bow:
		f["x1"] = 1.0
	var chest := p.g[r.spine] * r.grest[r.spine].affine_inverse()
	_arm(p, f, chest, 0)
	if cfg.shield:
		_shield_arm(p, f, chest)
	elif (f["th"] as float) > 0.001 and cfg.right == Hand.SPEAR:
		_spear_left(p, f, chest)
	else:
		_arm(p, f, chest, 1)
	return p


static func _arm(p: Pose, f: Dictionary, chest: Transform3D, s: int) -> void:
	var r := _rig
	var w: Vector3 = chest * (f["w%d" % s] as Vector3)
	var mw: float = f["mw%d" % s]
	if mw > 0.0:
		w = w.lerp(f["m%d" % s], mw)
	var d: Vector3 = f["d%d" % s]
	if d == Vector3.ZERO:
		var pole: Vector3 = chest.basis * (f["e%d" % s] as Vector3)
		p.limb(r.up[s], r.lo[s], r.hand[s], w, pole, r.arm_hinge[s][0], r.arm_hinge[s][1])
		return
	var a: Vector3 = f["a%d" % s]
	var sx := -1.0 if s == 0 else 1.0
	var palm: Vector3 = chest.basis * (a if a != Vector3.ZERO else Vector3(-sx, -0.25, 0.15))
	_weapon_arm(p, s, w, chest.basis * d, (f["x%d" % s] as float) > 0.5, palm)


## Braccio con un oggetto in mano: `grip` è dove deve stare l'impugnatura, `dir` la direzione dell'arma
## (lama o, con `fingers`, asse lungo le dita), `palm` verso cui guarda il palmo. Si orienta l'avambraccio
## (la mano visibile segue lui), il braccio punta al gomito che ne risulta, poi l'avambraccio si
## corregge di poco perché l'impugnatura arrivi davvero al punto voluto.
static func _weapon_arm(p: Pose, s: int, grip: Vector3, dir: Vector3, fingers: bool, palm: Vector3) -> void:
	var r := _rig
	var wl: Vector3 = r.fing_fl[s] if fingers else r.blade_fl[s]
	var dn := dir.normalized()
	var bf0 := _align(wl, r.palm_fl[s], dn, palm)
	var gl: Vector3 = r.grip_fl[s]
	var sh := p.g[r.up[s]].origin
	var l1 := r.rest[r.lo[s]].origin.length()
	var fl := r.rest[r.hand[s]].origin.normalized()
	# La lama fissa l'avambraccio a meno di una rotazione attorno alla lama stessa: si sceglie quella che
	# porta il gomito alla distanza giusta dalla spalla (presa raggiungibile), con il gomito in basso e
	# all'esterno e senza torcere l'avambraccio rispetto al braccio (niente pieghe della pelle al gomito).
	var best := bf0
	var best_cost := INF
	var sx := -1.0 if s == 0 else 1.0
	for i in 36:
		var bf := Basis(dn, TAU * i / 36.0) * bf0
		var e := grip - bf * gl
		var to_e := e - sh
		var miss := absf(to_e.length() - l1)
		var ud := to_e.normalized()
		var fdir := bf * fl
		var h := ud.cross(fdir)
		if h.length() < 0.05:
			h = Vector3(0, 0, -1).cross(ud)
		var up_b := _align(r.rest[r.lo[s]].origin, r.arm_hinge[s][0], ud, h.normalized())
		var natural := up_b * r.rest[r.lo[s]].basis * (r.palm_fl[s] as Vector3)
		var twist := 1.0 - (bf * (r.palm_fl[s] as Vector3)).dot(natural)
		var elbow_up := maxf(0.0, ud.y + 0.2)
		var elbow_in := maxf(0.0, -ud.x * sx)
		# Gomito vicino al fianco: il braccio scende lungo il busto, non si apre "ad ala".
		var elbow_out := maxf(0.0, absf(ud.x * sx - 0.15) - 0.1)
		var cost := miss * miss * 400.0 + twist * 0.6 + elbow_up * 0.8 + elbow_in * 0.5 + elbow_out * 2.5
		if cost < best_cost:
			best_cost = cost
			best = bf
	var bfx := best
	var e_want := grip - bfx * gl
	var ud2 := (e_want - sh).normalized()
	var h2 := ud2.cross(bfx * fl)
	if h2.length() < 0.05:
		h2 = Vector3(0, 0, -1).cross(ud2)
	p.set_global(r.up[s], _align(r.rest[r.lo[s]].origin, r.arm_hinge[s][0], ud2, h2.normalized()))
	var elbow := p.g[r.up[s]] * r.rest[r.lo[s]].origin
	p.g[r.lo[s]] = Transform3D(p.g[r.lo[s]].basis, elbow)
	var cur := (bfx * gl).normalized()
	var want := (grip - elbow).normalized()
	if cur.dot(want) < 0.99999:
		bfx = Basis(Quaternion(cur, want)) * bfx
	p.set_global(r.lo[s], bfx)
	p.g[r.hand[s]] = p.g[r.lo[s]] * Transform3D(Basis(p.rot[r.hand[s]]), r.rest[r.hand[s]].origin)


static func _shield_arm(p: Pose, f: Dictionary, chest: Transform3D) -> void:
	var r := _rig
	var sh := p.g[r.up[1]].origin
	var e: Vector3 = chest * (f["se"] as Vector3)
	var ud := (e - sh).normalized()
	var fd: Vector3 = (chest.basis * (f["sf"] as Vector3)).normalized()
	var n: Vector3 = chest.basis * (f["sn"] as Vector3)
	var h := ud.cross(fd)
	if h.length() < 0.05:
		h = (chest.basis * Vector3(0, 0, -1)).cross(ud)
	h = h.normalized()
	p.set_global(r.up[1], _align(r.rest[r.lo[1]].origin, r.arm_hinge[1][0], ud, h))
	p.g[r.lo[1]] = p.g[r.up[1]] * Transform3D(Basis(p.rot[r.lo[1]]), r.rest[r.lo[1]].origin)
	p.set_global(r.lo[1], _align(r.rest[r.hand[1]].origin, r.dorsal_loc, fd, n))
	p.g[r.hand[1]] = p.g[r.lo[1]] * Transform3D(Basis(p.rot[r.hand[1]]), r.rest[r.hand[1]].origin)


static func _spear_left(p: Pose, f: Dictionary, chest: Transform3D) -> void:
	var r := _rig
	var hg := p.g[r.hand[0]]
	var d := (hg.basis * (r.thumb_loc[0] as Vector3)).normalized()
	var grip := hg.origin + hg.basis * (r.grip_loc[0] as Vector3)
	var on := grip + d * (f["td"] as float)
	var th: float = f["th"]
	if th < 0.5:
		var pole: Vector3 = chest.basis * (f["e1"] as Vector3)
		p.limb(r.up[1], r.lo[1], r.hand[1], (chest * (f["w1"] as Vector3)).lerp(on, th * 2.0), pole, r.arm_hinge[1][0], r.arm_hinge[1][1])
		return
	_weapon_arm(p, 1, on, d, true, chest.basis * Vector3(-1, -0.6, 0.0))


# =====================================================================================================
# Interpolazione delle chiavi e scrittura delle animazioni
# =====================================================================================================

static func _neutral() -> Dictionary:
	return _STAND.duplicate()


static func _with(base: Dictionary, over: Dictionary) -> Dictionary:
	var r := base.duplicate()
	for k in over:
		r[k] = over[k]
	return r


static func _lerpv(a: Variant, b: Variant, t: float) -> Variant:
	return a + (b - a) * t


## Hermite (Catmull-Rom non uniforme) del campo k fra le chiavi i e i+1.
static func _hermite(keys: Array, i: int, k: String, u: float) -> Variant:
	var n := keys.size()
	var k0: Dictionary = keys[i]
	var k1: Dictionary = keys[i + 1]
	var p1: Variant = k0["f"][k]
	var p2: Variant = k1["f"][k]
	var t1: float = k0["t"]
	var t2: float = k1["t"]
	var dt := maxf(t2 - t1, 0.0001)
	var m1: Variant = p1 * 0.0
	var m2: Variant = p2 * 0.0
	if i > 0 and not k0.get("stop", false):
		var kp: Dictionary = keys[i - 1]
		m1 = (p2 - kp["f"][k]) / maxf(t2 - float(kp["t"]), 0.0001) * dt
	if i + 2 < n and not k1.get("stop", false):
		var kn: Dictionary = keys[i + 2]
		m2 = (kn["f"][k] - p1) / maxf(float(kn["t"]) - t1, 0.0001) * dt
	var u2 := u * u
	var u3 := u2 * u
	return p1 * (2 * u3 - 3 * u2 + 1) + m1 * (u3 - 2 * u2 + u) + p2 * (-2 * u3 + 3 * u2) + m2 * (u3 - u2)


static func _sample_keys(keys: Array, t: float) -> Dictionary:
	if t <= float(keys[0]["t"]):
		return keys[0]["f"]
	var last: Dictionary = keys[keys.size() - 1]
	if t >= float(last["t"]):
		return last["f"]
	var i := 0
	while i + 1 < keys.size() and float(keys[i + 1]["t"]) < t:
		i += 1
	var t1: float = keys[i]["t"]
	var t2: float = keys[i + 1]["t"]
	var u := (t - t1) / maxf(t2 - t1, 0.0001)
	var out := {}
	for k in keys[i]["f"]:
		var v: Variant = keys[i]["f"][k]
		if v is float or v is Vector3:
			out[k] = _hermite(keys, i, k, u)
		else:
			out[k] = v
	return out


## Chiave: tempo, campi (sopra la base), opzioni ("stop": velocità nulla nella chiave).
static func _k(t: float, base: Dictionary, over: Dictionary, stop := false) -> Dictionary:
	return {"t": t, "f": _with(base, over), "stop": stop}


## Calcola i fotogrammi da una funzione t -> campi e li scrive in un'Animation.
static func _bake(length: float, loop: bool, fps: float, fields_at: Callable, cfg: Cfg) -> Animation:
	var r := _rig
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var n := maxi(2, int(ceil(length * fps)))
	var tracks := {}
	for i in r.count:
		if r.parent[i] < 0:
			continue
		var tr := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tr, NodePath(".:" + _bone_name(i)))
		tracks[i] = tr
	var pt := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(pt, NodePath(".:" + _bone_name(r.hips)))
	var count := n if loop else n + 1
	for s in count:
		var t := length * s / float(n)
		var f: Dictionary = fields_at.call(t)
		var p := _solve(f, cfg)
		for i: int in tracks:
			a.rotation_track_insert_key(tracks[i], t, p.rot[i])
		a.position_track_insert_key(pt, t, p.hips_pos)
	if loop:
		# Chiude il ciclo con il primo fotogramma (niente salto alla ripetizione).
		var f0: Dictionary = fields_at.call(0.0)
		var p0 := _solve(f0, cfg)
		for i: int in tracks:
			a.rotation_track_insert_key(tracks[i], length, p0.rot[i])
		a.position_track_insert_key(pt, length, p0.hips_pos)
	return a


static var _names := {}

static func _bone_name(i: int) -> String:
	if _names.is_empty():
		for k: String in _rig.idx:
			_names[_rig.idx[k]] = k
	return _names[i]


static func _bake_keys(keys: Array, cfg: Cfg, fps := 30.0) -> Animation:
	var length: float = keys[keys.size() - 1]["t"]
	return _bake(length, false, fps, func(t: float) -> Dictionary: return _sample_keys(keys, t), cfg)


static func _bake_keys_loop(keys: Array, cfg: Cfg, fps := 20.0) -> Animation:
	var length: float = keys[keys.size() - 1]["t"]
	return _bake(length, true, fps, func(t: float) -> Dictionary: return _sample_keys(keys, t), cfg)


# =====================================================================================================
# Braccia: pose ricorrenti per arma
# =====================================================================================================

## Braccio destro a riposo con l'arma (o libero), `swing` avanti/indietro in metri.
static func _right_carry(cfg: Cfg, swing: float, run: float) -> Dictionary:
	match cfg.right:
		Hand.SWORD:
			if run > 0.5:
				# Corsa: il braccio armato pompa come l'altro, gomito stretto al fianco e avambraccio piegato;
				# la spada segue il pugno (lama in alto e in avanti), senza forzare il polso.
				var wr := Vector3(-0.2, 0.9, 0.1) + Vector3(0, absf(swing) * 0.3 + swing * 0.25, swing)
				return {"w0": wr, "e0": Vector3(-0.15, 0, -1), "d0": Vector3.ZERO, "a0": Vector3.ZERO}
			var w := Vector3(-0.215, 0.79, 0.1) + Vector3(0, absf(swing) * 0.25 + swing * 0.2, swing)
			var d := Vector3(-0.18, -0.72, 0.75).normalized()
			return {"w0": w, "e0": Vector3(-0.5, -0.1, -1), "d0": d, "a0": Vector3.ZERO}
		Hand.SPEAR:
			var w := Vector3(-0.24, 0.93, lerpf(0.17, 0.08, run)) + Vector3(0, swing * 0.15, swing * 0.4)
			var d := Vector3(0.0, 1.0, lerpf(0.2, 1.1, run)).normalized()
			return {"w0": w, "e0": Vector3(-0.4, -0.3, -1), "d0": d, "a0": Vector3.ZERO}
		_:
			var w := Vector3(-0.2, lerpf(0.71, 0.86, run), lerpf(0.04, 0.1, run)) + Vector3(0, absf(swing) * 0.3 + swing * 0.25, swing)
			return {"w0": w, "e0": Vector3(-0.3, 0, -1), "d0": Vector3.ZERO}


static func _left_carry(cfg: Cfg, swing: float, run: float) -> Dictionary:
	if cfg.shield:
		# Hoplon portato basso, sul fianco e un po' davanti.
		var b := Vector3(0, absf(swing) * 0.1, swing * 0.25)
		return {"se": Vector3(0.2, lerpf(0.85, 0.88, run), -0.02) + b, "sf": Vector3(-0.35, -0.2, 0.92), "sn": Vector3(0.8, 0.05, 0.55)}
	if cfg.bow:
		var w := Vector3(0.205, 0.73, 0.06) + Vector3(0, swing * 0.2, swing * 0.6)
		return {"w1": w, "e1": Vector3(0.4, 0, -1), "d1": Vector3(0.1, 0.9, 0.45).normalized(), "a1": Vector3.ZERO}
	var w2 := Vector3(0.2, lerpf(0.71, 0.86, run), lerpf(0.04, 0.1, run)) + Vector3(0, absf(swing) * 0.3 + swing * 0.25, swing)
	return {"w1": w2, "e1": Vector3(0.3, 0, -1), "d1": Vector3.ZERO}


## Guardia da combattimento: spada pronta all'altezza del fianco, scudo davanti al busto.
static func _guard(cfg: Cfg) -> Dictionary:
	var f := {}
	match cfg.right:
		Hand.SWORD:
			f.merge({"w0": Vector3(-0.23, 0.95, 0.17), "e0": Vector3(-0.7, -0.2, -0.8), "d0": Vector3(-0.05, 0.3, 0.95).normalized(), "a0": Vector3.ZERO}, true)
		Hand.SPEAR:
			f.merge({"w0": Vector3(-0.21, 0.92, 0.08), "e0": Vector3(-0.6, -0.5, -0.6), "d0": Vector3(0.3, 0.12, 0.95).normalized(), "a0": Vector3.ZERO, "th": 1.0, "td": 0.25}, true)
		_:
			f.merge({"w0": Vector3(-0.2, 0.95, 0.2), "e0": Vector3(-0.5, -0.3, -0.8)}, true)
	if cfg.shield:
		f.merge({"se": Vector3(0.14, 0.95, 0.23), "sf": Vector3(-0.85, 0.12, 0.5), "sn": Vector3(0.15, 0.05, 1.0)}, true)
	elif cfg.right != Hand.SPEAR:
		f.merge({"w1": Vector3(0.2, 0.95, 0.2), "e1": Vector3(0.5, -0.3, -0.8)}, true)
	return f


## Piedi della guardia: sinistro avanti, destro indietro e girato in fuori, ginocchia morbide.
static func _guard_feet() -> Dictionary:
	return {"f1": Vector3(0.12, ANKLE_H, 0.15), "f0": Vector3(-0.14, ANKLE_H, -0.13), "p0": Vector3(0, 30, 0), "p1": Vector3(0, 10, 0),
		"hp": Vector3(0.0, -0.06, 0.0), "hr": Vector3(0, -12, 0), "sp": Vector3(5, 6, 0), "hd": Vector3(-4, 6, 0)}


# =====================================================================================================
# Clip
# =====================================================================================================

static func _clips_for(set_name: String, cfg: Cfg) -> Dictionary:
	var c := {}
	match set_name:
		"base":
			c[&"idle"] = _idle(cfg, false)
			c[&"idle_guard"] = _idle(cfg, true)
			c[&"walk"] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(cfg, t, _WALK, &"normal"), cfg)
			c[&"run"] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(cfg, t, _RUN, &"normal"), cfg)
			c[&"attack"] = _attack_main(cfg)
			c[&"attack2"] = _attack_second(cfg)
			c[&"attack_thrust"] = _thrust(cfg)
			c[&"block"] = _block(cfg)
			c[&"hit"] = _hit(cfg)
			c[&"dodge"] = _dodge(cfg)
			c[&"helpup"] = _help_up(cfg)
			c[&"jump"] = _jump(cfg)
			for i in CLIP_CLIMB_HEIGHTS.size():
				c[climb_clip(i)] = _climb(cfg, CLIP_CLIMB_HEIGHTS[i])
			c[&"death"] = _death(cfg)
			for v: String in ["front", "side_r", "side_l"]:
				c[StringName("death_" + v)] = _death_variant(cfg, v)
		"support":
			c[&"support_idle"] = _idle(cfg, false, true)
			c[&"support_walk"] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(cfg, t, _WALK_SUPPORT, &"support"), cfg)
			c[&"support_run"] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(cfg, t, _RUN_SUPPORT, &"support"), cfg)
		"carry":
			# Chi sorregge un ferito camminando al suo fianco: braccio dietro la sua schiena (r: ferito a destra, l: a sinistra).
			for s in 2:
				var tag2 := "r" if s == 0 else "l"
				var st3 := StringName("carry_" + tag2)
				c[StringName("carry_%s_idle" % tag2)] = _idle(cfg, false, false, false, s)
				c[StringName("carry_%s_walk" % tag2)] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(cfg, t, _WALK_SUPPORT, st3), cfg)
				c[StringName("carry_%s_run" % tag2)] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(cfg, t, _RUN_SUPPORT, st3), cfg)
		"limp":
			var bare := Cfg.new(Hand.NONE, false, false)
			c[&"dragged_idle"] = _dragged(bare, false)
			c[&"dragged_walk"] = _dragged(bare, true)
			c[&"limp_idle"] = _limp_idle(bare)
			# Ferito sorretto da chi gli sta a sinistra (l), a destra (r) o da due compagni (lr): il braccio
			# del lato dal compagno va attorno alle sue spalle.
			for tag in ["l", "r", "lr"]:
				var st2 := StringName("limp_" + tag)
				var sides: Array = []
				if tag.contains("r"):
					sides.append(0)
				if tag.contains("l"):
					sides.append(1)
				c[StringName("limp_%s_idle" % tag)] = _limp_idle(bare, sides)
				c[StringName("limp_%s_walk" % tag)] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(bare, t, _LIMP, st2), bare)
				c[StringName("limp_%s_run" % tag)] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(bare, t, _LIMP_RUN, st2), bare)
			c[&"limp_walk"] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(bare, t, _LIMP, &"limp"), bare)
			c[&"limp_run"] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(bare, t, _LIMP_RUN, &"limp"), bare)
			c[&"lie"] = _lie(bare, false)
			c[&"lie_dead"] = _lie(bare, true)
			var up := _getup(bare)
			c[&"getup"] = up
			c[&"liedown"] = _reverse(up)
		"stretcher":
			var bare2 := Cfg.new(Hand.NONE, false, false)
			for s in 2:
				var tag := "r" if s == 0 else "l"
				c[StringName("stretcher_%s_idle" % tag)] = _stretcher_idle(bare2, s)
				c[StringName("stretcher_%s_walk" % tag)] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(bare2, t, _WALK_LOAD, StringName("stretcher_%d" % s)), bare2)
				c[StringName("stretcher_%s_run" % tag)] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(bare2, t, _RUN_LOAD, StringName("stretcher_%d" % s)), bare2)
		"row":
			# Rematore seduto sul banco: un solo ciclo di voga, uguale per tutti (idle/walk/run puntano allo stesso).
			var bare4 := Cfg.new(Hand.NONE, false, false)
			var rowing := _row(bare4)
			c[&"row_idle"] = rowing
			c[&"row_walk"] = rowing.duplicate()
			c[&"row_run"] = rowing.duplicate()
		"torch":
			c[&"torch_idle"] = _idle(cfg, false, false, true)
			c[&"torch_walk"] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(cfg, t, _WALK, &"torch"), cfg)
			c[&"torch_run"] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(cfg, t, _RUN, &"torch"), cfg)
		"drag":
			# Soccorso senza barella: il ferito trascinato sotto le ascelle da uno o due soldati.
			var bare3 := Cfg.new(Hand.NONE, false, false)
			for tag in ["", "_l", "_r"]:
				var st := StringName("drag" + tag)
				c[StringName("drag%s_idle" % tag)] = _drag_idle(bare3, st)
				c[StringName("drag%s_walk" % tag)] = _bake(1.0, true, 24.0, func(t: float) -> Dictionary: return _gait(bare3, t, _WALK_BACK, st), bare3)
		"bow":
			c[&"aim"] = _aim(cfg)
			c[&"shoot"] = _shoot(cfg)
		"leader":
			c[&"idle_talk"] = _idle_talk(cfg)
	return c


# --- andature ----------------------------------------------------------------------------------------

const _WALK := {"L": 1.12, "duty": 0.61, "lift": 0.085, "bob": 0.022, "drop": 0.02, "lean": 3.0, "yaw": 6.0, "roll": 4.0,
	"shift": 0.022, "swing": 0.12, "width": 0.088, "heel": 14.0, "toe": 30.0, "run": 0.0, "kick": 0.0}
const _RUN := {"L": 2.3, "duty": 0.31, "lift": 0.2, "bob": 0.035, "drop": 0.06, "lean": 11.0, "yaw": 9.0, "roll": 3.0,
	"shift": 0.012, "swing": 0.15, "width": 0.07, "heel": 4.0, "toe": 38.0, "run": 1.0, "kick": 0.12}
const _WALK_SUPPORT := {"L": 1.0, "duty": 0.63, "lift": 0.075, "bob": 0.02, "drop": 0.03, "lean": 6.0, "yaw": 5.0, "roll": 4.0,
	"shift": 0.025, "swing": 0.08, "width": 0.095, "heel": 12.0, "toe": 26.0, "run": 0.0, "kick": 0.0}
const _RUN_SUPPORT := {"L": 2.0, "duty": 0.36, "lift": 0.15, "bob": 0.03, "drop": 0.06, "lean": 12.0, "yaw": 7.0, "roll": 3.0,
	"shift": 0.015, "swing": 0.1, "width": 0.08, "heel": 5.0, "toe": 32.0, "run": 0.8, "kick": 0.06}
const _LIMP := {"L": 0.8, "duty": 0.66, "lift": 0.05, "bob": 0.03, "drop": 0.06, "lean": 16.0, "yaw": 4.0, "roll": 6.0,
	"shift": 0.035, "swing": 0.0, "width": 0.11, "heel": 6.0, "toe": 18.0, "run": 0.0, "kick": 0.0, "limp": 1.0}
const _LIMP_RUN := {"L": 1.3, "duty": 0.5, "lift": 0.08, "bob": 0.045, "drop": 0.08, "lean": 20.0, "yaw": 5.0, "roll": 6.0,
	"shift": 0.03, "swing": 0.0, "width": 0.11, "heel": 4.0, "toe": 22.0, "run": 0.4, "kick": 0.02, "limp": 1.0}
const _WALK_LOAD := {"L": 1.0, "duty": 0.64, "lift": 0.07, "bob": 0.014, "drop": 0.035, "lean": 4.0, "yaw": 4.0, "roll": 3.0,
	"shift": 0.02, "swing": 0.1, "width": 0.1, "heel": 10.0, "toe": 24.0, "run": 0.0, "kick": 0.0}
## Camminata all'indietro, chini, tirando il ferito (passo negativo: i piedi vanno verso il davanti).
const _WALK_BACK := {"L": -0.7, "duty": 0.66, "lift": 0.06, "bob": 0.012, "drop": 0.12, "lean": 26.0, "yaw": 3.0, "roll": 3.0,
	"shift": 0.02, "swing": 0.0, "width": 0.12, "heel": 0.0, "toe": 14.0, "run": 0.0, "kick": 0.0}
const _RUN_LOAD := {"L": 1.7, "duty": 0.42, "lift": 0.12, "bob": 0.022, "drop": 0.06, "lean": 8.0, "yaw": 5.0, "roll": 3.0,
	"shift": 0.015, "swing": 0.12, "width": 0.09, "heel": 6.0, "toe": 30.0, "run": 0.6, "kick": 0.04}


## Traiettoria di una caviglia nel ciclo (fase 0 = contatto del tallone), velocità costante del corpo.
static func _foot(gp: Dictionary, phi: float, side: int, limp: float) -> Array:
	var L: float = gp["L"]
	var duty: float = gp["duty"]
	# Gamba destra ferita: appoggio più breve, passo più corto e rigido.
	if limp > 0.0 and side == 0:
		duty = duty - 0.12 * limp
	var ld := L * duty
	var y := ANKLE_H
	var z := 0.0
	var pitch := 0.0
	var run: float = gp["run"]
	if phi < duty:
		var s := phi / duty
		z = ld * (0.5 - s)
		var heel: float = gp["heel"]
		var toe: float = gp["toe"]
		if s < 0.16:
			pitch = heel * pow(1.0 - s / 0.16, 2.0)
		elif s > 0.5:
			var rr := (s - 0.5) / 0.5
			pitch = -toe * rr * rr
		if pitch > 0.0:
			y += 0.055 * sin(deg_to_rad(pitch))          # perno sul tallone
		else:
			var rad := deg_to_rad(-pitch)
			y += 0.1 * sin(rad)                           # perno sulla pianta (tallone che si alza)
			z += 0.1 * (1.0 - cos(rad))
	else:
		var u := (phi - duty) / (1.0 - duty)
		var e := u * u * (3.0 - 2.0 * u)
		z = -ld * 0.5 + ld * e
		var kick: float = gp["kick"]
		z -= kick * sin(PI * minf(u / 0.6, 1.0)) * (1.0 - u)
		var lift: float = gp["lift"]
		if limp > 0.0 and side == 0:
			lift *= 0.6
		y += lift * pow(sin(PI * pow(u, lerpf(0.85, 0.65, run))), 1.2)
		var toe2: float = gp["toe"]
		var heel2: float = gp["heel"]
		pitch = lerpf(-toe2, heel2 * 0.8, smoothstep(0.0, 0.85, u)) + 10.0 * sin(PI * u) * (1.0 - run)
		y += 0.03 * maxf(0.0, -pitch) / 40.0
	return [z, y, pitch]


## Campi di un'andatura alla fase `t` (0..1): gambe, bacino, busto, braccia secondo lo stile.
static func _gait(cfg: Cfg, t: float, gp: Dictionary, style: StringName) -> Dictionary:
	var f := _neutral()
	var ph := fposmod(t, 1.0)
	var duty: float = gp["duty"]
	var run: float = gp["run"]
	var limp: float = gp.get("limp", 0.0)
	var width: float = gp["width"]
	for s in 2:
		var phi := fposmod(ph + (0.0 if s == 0 else 0.5), 1.0)
		var r := _foot(gp, phi, s, limp)
		var sx := -1.0 if s == 0 else 1.0
		f["f%d" % s] = Vector3(sx * width, r[1], r[0])
		f["p%d" % s] = Vector3(r[2], 7.0, 0.0)
	var c := cos(TAU * (ph - duty * 0.5))          # +1 appoggio destro a metà, -1 sinistro
	var c2 := cos(2.0 * TAU * (ph - duty * 0.5))   # due volte per ciclo
	var bob: float = gp["bob"]
	var vert := bob * c2 if run < 0.5 else -bob * c2 + bob * 0.6 * maxf(0.0, -c2)
	if limp > 0.0:
		# Sulla gamba ferita il corpo cade un po' (zoppia): abbassamento solo durante l'appoggio destro.
		vert -= 0.035 * limp * maxf(0.0, c)
	f["hp"] = Vector3(-(gp["shift"] as float) * c, -(gp["drop"] as float) + vert, 0.0)
	var yaw: float = (gp["yaw"] as float) * cos(TAU * ph)
	var roll: float = -(gp["roll"] as float) * c
	var lean: float = gp["lean"]
	f["hr"] = Vector3(lean * 0.35, yaw, roll)
	f["sp"] = Vector3(lean * 0.65 + 1.5 * c2 * (1.0 - run) - 2.0 * run * c2, -yaw * 1.6, -roll * 0.75)
	f["hd"] = Vector3(-lean * 0.8, yaw * 0.5, roll * 0.2)
	var sw: float = gp["swing"]
	var lag := 0.05
	var arm := cos(TAU * (ph - lag))
	f.merge(_right_carry(cfg, -sw * arm, run), true)
	f.merge(_left_carry(cfg, sw * arm, run), true)
	match style:
		&"support":
			# Scorta un compagno ferito: si volta spesso a guardarlo, scudo alto a coprirlo.
			var look := 0.5 + 0.5 * sin(TAU * ph)
			f["hd"] = (f["hd"] as Vector3) + Vector3(-4, 28 * look, 0)
			f["sp"] = (f["sp"] as Vector3) + Vector3(0, 6 * look, 0)
		&"carry_r":
			_carry_arm(f, 0)
		&"carry_l":
			_carry_arm(f, 1)
		&"limp", &"limp_l", &"limp_r", &"limp_lr":
			# Ferito: busto chino, mano sinistra sul fianco ferito, destra avanti sulla spalla di chi lo regge.
			f["hd"] = Vector3(-26, 0, 0)
			f["sp"] = (f["sp"] as Vector3) + Vector3(14, 0, 0)   # accasciato in avanti, peso sugli altri
			f["hp"] = (f["hp"] as Vector3) + Vector3(0, -0.045, 0)
			f["w1"] = Vector3(0.04, 0.9, 0.15) + Vector3(0, 0.01 * c, 0)
			f["e1"] = Vector3(0.8, -0.1, -0.5)
			f["w0"] = Vector3(-0.11, 1.16, 0.36) + Vector3(0, 0.015 * c2, 0)
			f["e0"] = Vector3(-0.6, -0.6, -0.3)
			f["k0"] = Vector3(-0.15, 0, 1)
			if style == &"limp_l" or style == &"limp_lr":
				_neck_arm(f, 1)
			if style == &"limp_r" or style == &"limp_lr":
				_neck_arm(f, 0)
		&"stretcher_0", &"stretcher_1":
			var hs := 0 if style == &"stretcher_0" else 1
			_stretcher_hand(f, hs)
		&"torch":
			_torch_arm(f, c)
		&"drag", &"drag_l", &"drag_r":
			_drag_hands(f, style, c)
	return f


## Distanza (m) tra chi sorregge e il ferito camminando fianco a fianco (asse contro asse).
const CARRY_SIDE := 0.46
## Il ferito sta un po' indietro rispetto a chi lo sorregge: visto da dietro non viene coperto dai due.
const CARRY_LAG := 0.2


## Chi sorregge: il braccio del lato del ferito gli cinge la vita, dietro la schiena (mano sul fianco lontano).
static func _carry_arm(f: Dictionary, s: int) -> void:
	var sx := -1.0 if s == 0 else 1.0
	f["m%d" % s] = Vector3(sx * (CARRY_SIDE + 0.2), 0.98, -0.3)
	f["mw%d" % s] = 1.0
	f["e%d" % s] = Vector3(sx * 0.9, -0.2, -0.3)
	f["d%d" % s] = Vector3.ZERO
	f["sp"] = (f["sp"] as Vector3) + Vector3(0, 0, -sx * 3.0)


## Ferito: il braccio del lato di chi lo sorregge va attorno al suo collo, mano sulla spalla lontana.
static func _neck_arm(f: Dictionary, s: int) -> void:
	var sx := -1.0 if s == 0 else 1.0
	f["m%d" % s] = Vector3(sx * (CARRY_SIDE + 0.26), 1.4, -0.2)
	f["mw%d" % s] = 1.0
	f["e%d" % s] = Vector3(sx * 0.3, 0.9, -0.5)
	f["d%d" % s] = Vector3.ZERO
	f["hr"] = (f["hr"] as Vector3) + Vector3(0, 0, -sx * 3.0)


## Mano che regge la stanga della barella: polso fisso nel modello (la stanga non balla col passo).
static func _stretcher_hand(f: Dictionary, s: int) -> void:
	var sx := -1.0 if s == 0 else 1.0
	f["m%d" % s] = Vector3(sx * 0.258, Stretcher.POLE_HEIGHT, 0.02)
	f["mw%d" % s] = 1.0
	f["w%d" % s] = Vector3(sx * 0.258, Stretcher.POLE_HEIGHT, 0.02)
	f["e%d" % s] = Vector3(sx * 0.6, 0, -1)
	f["d%d" % s] = Vector3(0, 0, 1)
	f["a%d" % s] = Vector3(-(-1.0 if s == 0 else 1.0), 0, 0)
	f["x%d" % s] = 1.0
	# Il peso tira giù il lato della mano: il busto compensa piegandosi dall'altra parte.
	f["sp"] = (f["sp"] as Vector3) + Vector3(0, 0, -sx * 4.0)
	f["hp"] = (f["hp"] as Vector3) + Vector3(-sx * 0.012, 0, 0)


## Distanze del trascinamento (spazio del soccorritore, che guarda il ferito): le mani sotto le ascelle
## sono a DRAG_REACH davanti e DRAG_HAND_Y da terra; il ferito ha la stessa direzione del soccorritore e
## la sua origine è DRAG_GAP più avanti. In due, i soccorritori stanno a ±DRAG_SIDE dall'asse del ferito.
const DRAG_REACH := 0.42
const DRAG_HAND_Y := 0.58
const DRAG_GAP := 0.7
const DRAG_SIDE := 0.34


## Torcia in mano destra: braccio piegato davanti al fianco, torcia dritta con la fiamma in alto.
static func _torch_arm(f: Dictionary, phase: float) -> void:
	f["w0"] = Vector3(-0.32, 0.93, 0.2 + 0.015 * phase)
	f["e0"] = Vector3(-0.8, -0.6, -0.3)
	f["d0"] = Vector3(-0.2, 1.0, 0.1).normalized()
	f["a0"] = Vector3(-1, -0.1, 0)
	f["x0"] = 0.0


static func _drag_hands(f: Dictionary, style: StringName, phase_c: float) -> void:
	var sides := [0, 1] if style == &"drag" else ([1] if style == &"drag_l" else [0])
	for s in sides:
		var sx := -1.0 if s == 0 else 1.0
		var x := sx * (0.14 if style == &"drag" else DRAG_SIDE - 0.17)
		f["m%d" % s] = Vector3(x, DRAG_HAND_Y + 0.01 * phase_c, DRAG_REACH)
		f["mw%d" % s] = 1.0
		f["e%d" % s] = Vector3(sx * 0.9, -0.2, -0.3)
		f["d%d" % s] = Vector3.ZERO
	# Busto chino in avanti, testa che guarda dietro le spalle dove si va.
	f["sp"] = (f["sp"] as Vector3) + Vector3(10, 0, 0)
	f["hd"] = Vector3(-20, 18.0 * phase_c, 0)


static func _drag_idle(cfg: Cfg, style: StringName) -> Animation:
	var length := 3.0
	return _bake(length, true, 15.0, func(t: float) -> Dictionary:
		var u := t / length
		var f := _neutral()
		var breath := sin(TAU * u * 3.0)
		f["f0"] = Vector3(-0.13, ANKLE_H, -0.08)
		f["f1"] = Vector3(0.13, ANKLE_H, 0.06)
		f["hp"] = Vector3(0, -0.13 - 0.006 * breath, -0.05)
		f["hr"] = Vector3(14, 0, 0)
		f["sp"] = Vector3(14 + breath, 0, 0)
		f["hd"] = Vector3(-18, 0, 0)
		f.merge(_right_carry(cfg, 0.0, 0.0), true)
		f.merge(_left_carry(cfg, 0.0, 0.0), true)
		_drag_hands(f, style, sin(TAU * u))
		return f, cfg)


## Ferito trascinato: mezzo seduto, busto all'indietro retto sotto le ascelle, braccia alzate e molli,
## gambe distese con i talloni che strisciano a terra.
static func _dragged(cfg: Cfg, moving: bool) -> Animation:
	var length := 1.0 if moving else 3.0
	return _bake(length, true, 15.0, func(t: float) -> Dictionary:
		var u := t / length
		var w := sin(TAU * u)
		var f := _neutral()
		f["hp"] = Vector3(0, -0.4 + (0.012 * w if moving else 0.004 * w), 0.0)
		f["hr"] = Vector3(-40, 3.0 * w if moving else 0.0, 0)
		f["sp"] = Vector3(-6, 0, 0)
		f["hd"] = Vector3(22, 8.0 * w, 6)
		f["f0"] = Vector3(-0.12, 0.075, 0.56 + (0.03 * w if moving else 0.0))
		f["f1"] = Vector3(0.13, 0.075, 0.6 - (0.03 * w if moving else 0.0))
		f["q0"] = 0.7
		f["q1"] = 0.7
		f["k0"] = Vector3(-0.2, 0.4, 1)
		f["k1"] = Vector3(0.2, 0.4, 1)
		# Braccia alzate in fuori (chi trascina le tiene sotto le ascelle), mani penzoloni.
		f["w0"] = Vector3(-0.4, 0.95, -0.02)
		f["e0"] = Vector3(-0.4, -0.6, -0.6)
		f["w1"] = Vector3(0.4, 0.95, -0.02)
		f["e1"] = Vector3(0.4, -0.6, -0.6)
		return f, cfg)


# --- riposo ------------------------------------------------------------------------------------------

## Riposo vivo: respiro, peso che passa da una gamba all'altra (piedi fermi), sguardo che si sposta.
## Durata 6 s; tutte le oscillazioni sono armoniche intere del ciclo, così il loop non salta.
static func _idle(cfg: Cfg, guard: bool, support := false, torch := false, hug := -1) -> Animation:
	var length := 6.0
	return _bake(length, true, 15.0, func(t: float) -> Dictionary:
		var u := t / length
		var f := _neutral()
		var breath := sin(TAU * u * 4.0)            # 4 respiri in 6 s
		var shift := sin(TAU * u)                    # peso da una gamba all'altra
		var look := sin(TAU * u * 2.0 + 0.7) * 0.6 + sin(TAU * u * 3.0) * 0.4
		if guard:
			f.merge(_guard_feet(), true)
			f.merge(_guard(cfg), true)
			f["hp"] = (f["hp"] as Vector3) + Vector3(0.01 * shift, -0.006 * breath, 0.008 * sin(TAU * u * 2.0))
			f["sp"] = (f["sp"] as Vector3) + Vector3(1.2 * breath, 2.0 * look, 0)
			f["hd"] = (f["hd"] as Vector3) + Vector3(-1.0 * breath, 5.0 * look, 0)
			if cfg.shield:
				f["se"] = (f["se"] as Vector3) + Vector3(0, 0.008 * breath, 0)
			return f
		f["f0"] = Vector3(-0.11, ANKLE_H, -0.02)
		f["f1"] = Vector3(0.12, ANKLE_H, 0.03)
		f["p0"] = Vector3(0, 12, 0)
		f["p1"] = Vector3(0, 6, 0)
		# Contrapposto: il bacino va sopra la gamba d'appoggio e si inclina, l'altra gamba si scarica.
		f["hp"] = Vector3(0.028 * shift, -0.025 - 0.006 * absf(shift) - 0.004 * breath, 0.006 * sin(TAU * u * 2.0))
		f["hr"] = Vector3(0, 3.0 * shift, -3.5 * shift)
		f["sp"] = Vector3(2.0 + 1.4 * breath, -2.5 * shift + 1.5 * look, 3.0 * shift)
		f["hd"] = Vector3(-2.0 - 1.0 * breath + 2.0 * sin(TAU * u * 3.0), 9.0 * look, -1.5 * shift)
		var arm := 0.012 * breath
		f.merge(_right_carry(cfg, 0.0, 0.0), true)
		f.merge(_left_carry(cfg, 0.0, 0.0), true)
		f["w0"] = (f["w0"] as Vector3) + Vector3(-0.01 * shift, arm, 0)
		if f.has("w1"):
			f["w1"] = (f["w1"] as Vector3) + Vector3(0.01 * shift, arm, 0)
		if support:
			f["hd"] = (f["hd"] as Vector3) + Vector3(-3, 22.0 * (0.5 + 0.5 * sin(TAU * u * 2.0)), 0)
		if torch:
			_torch_arm(f, breath)
		if hug >= 0:
			_carry_arm(f, hug)
		return f, cfg)


static func _limp_idle(cfg: Cfg, sides: Array = []) -> Animation:
	var length := 4.0
	return _bake(length, true, 15.0, func(t: float) -> Dictionary:
		var u := t / length
		var f := _neutral()
		var breath := sin(TAU * u * 4.0)       # respiro affannato
		f["f0"] = Vector3(-0.12, 0.09, 0.04)
		f["p0"] = Vector3(-12, 10, 0)           # gamba ferita scarica, sulla punta
		f["f1"] = Vector3(0.11, ANKLE_H, -0.02)
		f["hp"] = Vector3(0.04, -0.07 - 0.008 * breath, -0.02)
		f["hr"] = Vector3(8, 4, -5)
		f["sp"] = Vector3(14 + 3.0 * breath, -4, 4)
		f["hd"] = Vector3(-6 + 2.0 * breath, 6.0 * sin(TAU * u), 0)
		f["w1"] = Vector3(0.04, 0.9, 0.15)
		f["e1"] = Vector3(0.8, -0.1, -0.5)
		f["w0"] = Vector3(-0.12, 1.12, 0.34) + Vector3(0, 0.01 * breath, 0)
		f["e0"] = Vector3(-0.6, -0.6, -0.3)
		for sd in sides:
			_neck_arm(f, sd)
		return f, cfg)


static func _stretcher_idle(cfg: Cfg, s: int) -> Animation:
	var length := 4.0
	return _bake(length, true, 15.0, func(t: float) -> Dictionary:
		var u := t / length
		var f := _neutral()
		var breath := sin(TAU * u * 3.0)
		f["hp"] = Vector3(0, -0.035 - 0.004 * breath, 0)
		f["sp"] = Vector3(3 + breath, 0, 0)
		f["hd"] = Vector3(-3, 6.0 * sin(TAU * u), 0)
		f.merge(_right_carry(cfg, 0.0, 0.0), true)
		f.merge(_left_carry(cfg, 0.0, 0.0), true)
		_stretcher_hand(f, s)
		return f, cfg)


# --- voga ---------------------------------------------------------------------------------------------
## Durata di una remata (s), altezza del bacino da seduto (rispetto a in piedi) e geometria dei remi nello
## spazio dello scheletro del rematore (fronte +Z): scalmo a ROW_LOCK_X di lato, ROW_LOCK_Y in alto, la mano
## impugna il remo a ROW_GRIP dall'interno dello scalmo e lo fa ruotare di ±ROW_SWING gradi.
const ROW_PERIOD := 2.4
const ROW_SIT_DROP := -0.22
const ROW_LOCK_X := 0.78
const ROW_LOCK_Y := 0.80
const ROW_GRIP := 0.46
const ROW_SWING := 24.0


## Posizione del polso del lato `s` (spazio dello scheletro) alla fase `u` (0..1) della remata, e angolo del remo
## (gradi, positivo = impugnatura in avanti). Spinta (0..0.5): l'impugnatura va in avanti e la pala indietro in acqua;
## recupero: torna indietro con la pala fuori dall'acqua (l'impugnatura si abbassa).
static func row_hand(s: int, u: float) -> Dictionary:
	var sx := -1.0 if s == 0 else 1.0
	var ang := -ROW_SWING * cos(TAU * u)            # u=0: fine recupero (impugnatura indietro), u=.5 fine spinta
	var th := deg_to_rad(ang)
	var lift := -0.07 * maxf(0.0, -sin(TAU * u))    # recupero: l'impugnatura scende, la pala esce dall'acqua
	var pos := Vector3(sx * (ROW_LOCK_X - ROW_GRIP * cos(th)), ROW_LOCK_Y - 0.1 + lift, ROW_GRIP * sin(th) + 0.02)
	return {"pos": pos, "angle": ang}


static func _row(cfg: Cfg) -> Animation:
	return _bake(ROW_PERIOD, true, 20.0, func(t: float) -> Dictionary:
		var u := t / ROW_PERIOD
		var f := _neutral()
		var lean := -cos(TAU * u)                    # -1 busto indietro (impugnatura indietro), +1 avanti
		var breath := sin(TAU * u * 5.0)
		f["hp"] = Vector3(0, ROW_SIT_DROP, -0.05 + 0.02 * lean)
		f["hr"] = Vector3(-4.0 + 3.0 * lean, 0, 0)
		f["sp"] = Vector3(6.0 + 11.0 * lean + 0.6 * breath, 0, 0)
		f["hd"] = Vector3(-5.0 - 2.0 * lean, 0, 0)
		f["f0"] = Vector3(-0.15, 0.075, 0.36)
		f["f1"] = Vector3(0.15, 0.075, 0.36)
		f["p0"] = Vector3(6, 14, 0)
		f["p1"] = Vector3(6, 14, 0)
		f["k0"] = Vector3(-0.2, 0, 1)
		f["k1"] = Vector3(0.2, 0, 1)
		for s in 2:
			var h := row_hand(s, u)
			var pos: Vector3 = h["pos"]
			f["m%d" % s] = pos
			f["mw%d" % s] = 1.0
			f["w%d" % s] = pos
			f["e%d" % s] = Vector3((-1.0 if s == 0 else 1.0) * 0.5, -0.4, -1)
			f["d%d" % s] = Vector3(0, 0, 1)
			f["a%d" % s] = Vector3(-(-1.0 if s == 0 else 1.0), 0, 0)
			f["x%d" % s] = 1.0
		return f, cfg)


static func _idle_talk(cfg: Cfg) -> Animation:
	# Capo che parla: mano che gesticola ogni tanto, peso che si sposta, sguardo che passa sui presenti.
	var base := _with(_neutral(), {"f0": Vector3(-0.12, ANKLE_H, -0.03), "f1": Vector3(0.12, ANKLE_H, 0.04), "p0": Vector3(0, 14, 0)})
	base.merge(_left_carry(cfg, 0.0, 0.0), true)
	base.merge(_right_carry(cfg, 0.0, 0.0), true)
	var keys := [
		_k(0.0, base, {"hd": Vector3(-2, -12, 0), "hp": Vector3(-0.02, -0.03, 0)}),
		_k(1.4, base, {"hd": Vector3(-4, 8, 0), "hp": Vector3(0.01, -0.03, 0), "sp": Vector3(3, 4, 0),
			"w0": Vector3(-0.2, 0.98, 0.28), "e0": Vector3(-0.6, -0.4, -0.7), "d0": Vector3(0.3, 0.2, 0.9)}),
		_k(2.2, base, {"hd": Vector3(-1, 14, 0), "hp": Vector3(0.015, -0.03, 0), "sp": Vector3(2, 8, 0),
			"w0": Vector3(-0.25, 1.02, 0.3), "e0": Vector3(-0.6, -0.4, -0.7), "d0": Vector3(0.6, 0.3, 0.7)}),
		_k(3.4, base, {"hd": Vector3(-3, 2, 0), "hp": Vector3(0.02, -0.03, 0)}),
		_k(5.0, base, {"hd": Vector3(-2, -14, 0), "hp": Vector3(-0.01, -0.03, 0), "sp": Vector3(2, -5, 0)}),
		_k(6.0, base, {"hd": Vector3(-2, -12, 0), "hp": Vector3(-0.02, -0.03, 0)}),
	]
	return _bake_keys_loop(keys, cfg, 15.0)


# --- attacchi ---------------------------------------------------------------------------------------

## Fendente dall'alto (spada) o affondo di lancia: caricamento breve (il colpo arriva subito nel gioco),
## colpo con passo avanti del piede sinistro e rotazione del busto, accompagnamento, ritorno in guardia.
static func _attack_main(cfg: Cfg) -> Animation:
	if cfg.right == Hand.SPEAR:
		return _spear_thrust(cfg, 0.0)
	if cfg.right == Hand.BOW:
		return _shoot(cfg)
	var g := _with(_with(_neutral(), _guard_feet()), _guard(cfg))
	var sh_out := {"se": Vector3(0.28, 0.95, 0.06), "sf": Vector3(-0.55, 0.12, 0.83), "sn": Vector3(0.7, 0.05, 0.75)} if cfg.shield else {}
	var wind := _with(g, {"w0": Vector3(-0.29, 1.27, -0.03), "e0": Vector3(-1, 0.4, -0.3), "d0": Vector3(-0.15, 0.75, -0.65), "a0": Vector3.ZERO,
		"hr": Vector3(0, -20, 0), "sp": Vector3(-4, -16, 2), "hd": Vector3(-2, 22, 0), "hp": Vector3(0, -0.05, -0.04)})
	var hit := _with(g, {"w0": Vector3(-0.1, 1.06, 0.38), "e0": Vector3(-0.8, -0.3, -0.5), "d0": Vector3(0.08, -0.2, 0.98), "a0": Vector3.ZERO,
		"hr": Vector3(6, 8, 0), "sp": Vector3(12, 14, -3), "hd": Vector3(-8, -14, 0), "hp": Vector3(0, -0.1, 0.1),
		"f1": Vector3(0.12, ANKLE_H, 0.34)})
	hit.merge(sh_out, true)
	var follow := _with(hit, {"w0": Vector3(-0.07, 0.85, 0.3), "d0": Vector3(0.12, -0.8, 0.58), "sp": Vector3(16, 18, -4), "hp": Vector3(0, -0.12, 0.12)})
	var lifted := _with(g, {"f1": Vector3(0.12, 0.11, 0.25), "hp": Vector3(0, -0.07, 0.03)})
	var keys := [
		_k(0.0, g, {}, true),
		_k(0.1, wind, {}),
		_k(0.15, _with(wind, {"f1": lifted["f1"]}), {}),
		_k(0.22, hit, {}),
		_k(0.32, follow, {}),
		_k(0.48, _with(g, {"f1": Vector3(0.12, 0.09, 0.22), "hp": Vector3(0, -0.07, 0.04)}), {}),
		_k(0.7, g, {}, true),
	]
	return _bake_keys(keys, cfg)


## Secondo colpo: taglio orizzontale da destra verso il centro, all'altezza della vita.
static func _attack_second(cfg: Cfg) -> Animation:
	if cfg.right == Hand.SPEAR:
		return _spear_thrust(cfg, 1.0)
	if cfg.right == Hand.BOW:
		return _shoot(cfg)
	var g := _with(_with(_neutral(), _guard_feet()), _guard(cfg))
	var sh_out := {"se": Vector3(0.29, 0.93, 0.04), "sf": Vector3(-0.5, 0.1, 0.86), "sn": Vector3(0.75, 0.05, 0.7)} if cfg.shield else {}
	var wind := _with(g, {"w0": Vector3(-0.36, 1.02, -0.06), "e0": Vector3(-0.6, 0.6, -0.6), "d0": Vector3(-0.75, 0.25, -0.6), "a0": Vector3.ZERO,
		"hr": Vector3(0, -24, 0), "sp": Vector3(2, -18, 0), "hd": Vector3(-4, 26, 0), "hp": Vector3(-0.03, -0.07, -0.02)})
	var hit := _with(g, {"w0": Vector3(-0.14, 1.0, 0.36), "e0": Vector3(-0.6, -0.6, -0.4), "d0": Vector3(0.55, 0.05, 0.83), "a0": Vector3.ZERO,
		"hr": Vector3(4, 14, 0), "sp": Vector3(8, 16, 0), "hd": Vector3(-6, -16, 0), "hp": Vector3(0.01, -0.09, 0.08),
		"f1": Vector3(0.14, ANKLE_H, 0.3)})
	hit.merge(sh_out, true)
	var follow := _with(hit, {"w0": Vector3(-0.02, 0.97, 0.33), "d0": Vector3(0.85, -0.1, 0.5), "sp": Vector3(9, 22, 0)})
	var keys := [
		_k(0.0, g, {}, true),
		_k(0.1, wind, {}),
		_k(0.14, _with(wind, {"f1": Vector3(0.13, 0.105, 0.24)}), {}),
		_k(0.22, hit, {}),
		_k(0.31, follow, {}),
		_k(0.47, _with(g, {"f1": Vector3(0.13, 0.09, 0.22)}), {}),
		_k(0.68, g, {}, true),
	]
	return _bake_keys(keys, cfg)


## Affondo di punta con la spada: dal fianco in avanti, affondo lungo sul piede sinistro.
static func _thrust(cfg: Cfg) -> Animation:
	if cfg.right == Hand.SPEAR:
		return _spear_thrust(cfg, 0.5)
	if cfg.right == Hand.BOW:
		return _shoot(cfg)
	var g := _with(_with(_neutral(), _guard_feet()), _guard(cfg))
	var cock := _with(g, {"w0": Vector3(-0.26, 0.92, -0.08), "e0": Vector3(-0.5, -0.2, -1), "d0": Vector3(0.05, 0.1, 1.0), "a0": Vector3.ZERO,
		"hr": Vector3(0, -18, 0), "sp": Vector3(2, -14, 0), "hd": Vector3(-3, 16, 0), "hp": Vector3(0, -0.07, -0.05)})
	var hit := _with(g, {"w0": Vector3(-0.08, 1.02, 0.42), "e0": Vector3(-0.5, -0.5, -0.6), "d0": Vector3(0.12, 0.04, 1.0), "a0": Vector3.ZERO,
		"hr": Vector3(8, 10, 0), "sp": Vector3(10, 12, 0), "hd": Vector3(-10, -10, 0), "hp": Vector3(0, -0.13, 0.16),
		"f1": Vector3(0.13, ANKLE_H, 0.42), "f0": Vector3(-0.14, ANKLE_H, -0.12), "p0": Vector3(-18, 30, 0)})
	if cfg.shield:
		hit.merge({"se": Vector3(0.28, 0.95, 0.05), "sf": Vector3(-0.5, 0.12, 0.86), "sn": Vector3(0.75, 0.05, 0.7)}, true)
	var keys := [
		_k(0.0, g, {}, true),
		_k(0.1, cock, {}),
		_k(0.14, _with(cock, {"f1": Vector3(0.13, 0.11, 0.26)}), {}),
		_k(0.21, hit, {}),
		_k(0.3, _with(hit, {"w0": Vector3(-0.09, 1.0, 0.4)}), {}),
		_k(0.46, _with(g, {"f1": Vector3(0.13, 0.095, 0.25), "hp": Vector3(0, -0.08, 0.04)}), {}),
		_k(0.66, g, {}, true),
	]
	return _bake_keys(keys, cfg)


## Affondo di lancia a due mani (variante: 0 alto, 0.5 medio, 1 basso).
static func _spear_thrust(cfg: Cfg, v: float) -> Animation:
	var g := _with(_with(_neutral(), _guard_feet()), _guard(cfg))
	var hgt := lerpf(0.06, -0.08, v)
	var cock := _with(g, {"w0": Vector3(-0.33, 0.92 + hgt * 0.5, -0.02), "d0": Vector3(0.28, 0.1 + hgt, 0.96).normalized(), "td": 0.3,
		"hr": Vector3(0, -16, 0), "sp": Vector3(0, -12, 0), "hd": Vector3(-3, 14, 0), "hp": Vector3(0, -0.07, -0.05)})
	var hit := _with(g, {"w0": Vector3(-0.27, 0.98 + hgt, 0.3), "d0": Vector3(0.26, 0.05 + hgt, 1.0).normalized(), "td": 0.26,
		"hr": Vector3(8, 12, 0), "sp": Vector3(10, 10, 0), "hd": Vector3(-10, -10, 0), "hp": Vector3(0, -0.13, 0.15),
		"f1": Vector3(0.13, ANKLE_H, 0.42), "p0": Vector3(-16, 30, 0)})
	var keys := [
		_k(0.0, g, {}, true),
		_k(0.11, cock, {}),
		_k(0.15, _with(cock, {"f1": Vector3(0.13, 0.11, 0.26)}), {}),
		_k(0.23, hit, {}),
		_k(0.33, _with(hit, {"w0": Vector3(-0.28, 0.97 + hgt, 0.27)}), {}),
		_k(0.5, _with(g, {"f1": Vector3(0.13, 0.095, 0.25), "hp": Vector3(0, -0.08, 0.04), "w0": Vector3(-0.32, 0.94, 0.12)}), {}, true),
		_k(0.72, g, {}, true),
	]
	return _bake_keys(keys, cfg)


## Parata: lo scudo sale davanti al busto e al volto, peso sul piede dietro, spada armata al fianco.
static func _block(cfg: Cfg) -> Animation:
	var g := _with(_with(_neutral(), _guard_feet()), _guard(cfg))
	var up := _with(g, {"hp": Vector3(0, -0.11, -0.05), "hr": Vector3(4, -14, 0), "sp": Vector3(9, 4, 0), "hd": Vector3(-6, 8, 0),
		"f0": Vector3(-0.15, ANKLE_H, -0.17)})
	if cfg.shield:
		up.merge({"se": Vector3(0.13, 1.06, 0.24), "sf": Vector3(-0.9, 0.25, 0.35), "sn": Vector3(0.05, 0.15, 1.0)}, true)
	elif cfg.right == Hand.SPEAR:
		up.merge({"w0": Vector3(-0.28, 1.04, 0.2), "d0": Vector3(0.35, 0.3, 0.88).normalized(), "td": 0.28}, true)
	else:
		up.merge({"w1": Vector3(0.12, 1.14, 0.24), "e1": Vector3(0.9, -0.3, -0.2), "d1": Vector3(-0.3, 0.9, 0.3)}, true)
	if cfg.right == Hand.SWORD:
		up.merge({"w0": Vector3(-0.25, 0.97, 0.06), "d0": Vector3(0.0, 0.45, 0.9).normalized()}, true)
	var shake := _with(up, {"hp": Vector3(0, -0.12, -0.08), "sp": Vector3(6, 4, 0)})
	var keys := [
		_k(0.0, g, {}, true),
		_k(0.12, up, {}),
		_k(0.2, shake, {}),
		_k(0.32, up, {}),
		_k(0.5, up, {}, true),
		_k(0.7, g, {}, true),
	]
	return _bake_keys(keys, cfg)


## Colpo subito: il busto cede all'indietro, la testa scatta, un passo indietro per non cadere.
static func _hit(cfg: Cfg) -> Animation:
	var g := _with(_with(_neutral(), _guard_feet()), _guard(cfg))
	var recoil := _with(g, {"hp": Vector3(0.02, -0.09, -0.08), "hr": Vector3(-8, 10, 4), "sp": Vector3(-14, 8, 5), "hd": Vector3(-16, -12, 6)})
	if cfg.shield:
		recoil.merge({"se": Vector3(0.27, 0.98, 0.08), "sf": Vector3(-0.6, 0.3, 0.75), "sn": Vector3(0.6, 0.2, 0.8)}, true)
	recoil["w0"] = (g["w0"] as Vector3) + Vector3(-0.06, 0.08, -0.12)
	var stepback := _with(recoil, {"f0": Vector3(-0.15, ANKLE_H, -0.3), "hp": Vector3(0.0, -0.1, -0.14), "sp": Vector3(-6, 4, 3), "hd": Vector3(-6, -4, 2)})
	var keys := [
		_k(0.0, g, {}, true),
		_k(0.07, recoil, {}),
		_k(0.14, _with(recoil, {"f0": Vector3(-0.15, 0.12, -0.2)}), {}),
		_k(0.26, stepback, {}),
		_k(0.5, _with(g, {"f0": Vector3(-0.14, ANKLE_H, -0.22), "hp": Vector3(0, -0.07, -0.05)}), {}, true),
	]
	return _bake_keys(keys, cfg)


## Aiuta un ferito a terra a rialzarsi: si china su un ginocchio, tende la mano, lo tira su e lo regge (1,9 s).
static func _help_up(cfg: Cfg) -> Animation:
	var n := _neutral()
	n.merge(_right_carry(cfg, 0.0, 0.0), true)
	n.merge(_left_carry(cfg, 0.0, 0.0), true)
	if cfg.shield:
		n.merge({"se": Vector3(0.17, 0.97, 0.18), "sf": Vector3(-0.75, 0.2, 0.6), "sn": Vector3(0.3, 0.1, 1.0)}, true)
	var bend := _with(n, {"hp": Vector3(0, -0.2, 0.08), "hr": Vector3(14, 0, 0), "sp": Vector3(18, 0, 0), "hd": Vector3(-16, 0, 0),
		"f0": Vector3(-0.14, ANKLE_H, -0.14), "f1": Vector3(0.2, ANKLE_H, 0.1), "k1": Vector3(0.1, 0, 1)})
	bend["w0"] = Vector3(-0.26, 0.55, 0.6)
	bend["e0"] = Vector3(-0.6, -0.3, -0.5)
	if cfg.shield:
		bend.merge({"se": Vector3(0.2, 1.12, 0.14), "sf": Vector3(-0.8, 0.3, 0.5), "sn": Vector3(0.1, 0.2, 1.0)}, true)
	var grip := _with(bend, {"hp": Vector3(0, -0.22, 0.08), "sp": Vector3(22, 0, 0)})
	grip["w0"] = Vector3(-0.24, 0.46, 0.66)
	var pull := _with(bend, {"hp": Vector3(0, -0.1, 0.02), "sp": Vector3(12, 0, 0), "hd": Vector3(-10, 0, 0)})
	pull["w0"] = Vector3(-0.22, 0.8, 0.5)
	var keys := [
		_k(0.0, n, {}, true),
		_k(0.4, bend, {}),
		_k(0.7, grip, {}, true),
		_k(1.2, grip, {}, true),
		_k(1.6, pull, {}),
		_k(1.95, n, {}, true),
	]
	return _bake_keys(keys, cfg)


## Schivata: scarto rapido a destra abbassandosi, scudo che copre, poi ritorno.
static func _dodge(cfg: Cfg) -> Animation:
	var g := _with(_with(_neutral(), _guard_feet()), _guard(cfg))
	var low := _with(g, {"hp": Vector3(-0.17, -0.2, -0.02), "hr": Vector3(10, -10, 8), "sp": Vector3(18, 4, 10), "hd": Vector3(-14, 6, -8),
		"f0": Vector3(-0.38, ANKLE_H, -0.08), "f1": Vector3(0.06, ANKLE_H, 0.12), "p0": Vector3(0, 40, 0)})
	if cfg.shield:
		low.merge({"se": Vector3(0.14, 1.0, 0.23), "sf": Vector3(-0.85, 0.25, 0.45), "sn": Vector3(0.1, 0.2, 1.0)}, true)
	var keys := [
		_k(0.0, g, {}, true),
		_k(0.08, _with(g, {"f0": Vector3(-0.25, 0.13, -0.1), "hp": Vector3(-0.06, -0.1, 0)}), {}),
		_k(0.18, low, {}),
		_k(0.36, low, {}, true),
		_k(0.5, _with(g, {"f0": Vector3(-0.22, 0.11, -0.12), "hp": Vector3(-0.06, -0.08, 0)}), {}),
		_k(0.66, g, {}, true),
	]
	return _bake_keys(keys, cfg)


## Balzo oltre un ostacolo basso (sincronizzato con l'arco del GridUnit: 0,55 s in aria):
## spinta, gambe raccolte sotto il bacino, braccia avanti, gambe tese per l'atterraggio, ammortizzo.
static func _jump(cfg: Cfg) -> Animation:
	var n := _neutral()
	n.merge(_right_carry(cfg, 0.0, 0.3), true)
	n.merge(_left_carry(cfg, 0.0, 0.3), true)
	if cfg.shield:
		n.merge({"se": Vector3(0.17, 0.97, 0.18), "sf": Vector3(-0.75, 0.2, 0.6), "sn": Vector3(0.3, 0.1, 1.0)}, true)
	var push := _with(n, {"hp": Vector3(0, -0.1, 0.02), "hr": Vector3(10, 0, 0), "sp": Vector3(14, 0, 0), "hd": Vector3(-12, 0, 0),
		"f0": Vector3(-0.1, 0.09, -0.12), "p0": Vector3(-30, 6, 0), "f1": Vector3(0.1, ANKLE_H, 0.04)})
	var tuck := _with(n, {"hp": Vector3(0, -0.08, 0.0), "hr": Vector3(14, 0, 0), "sp": Vector3(12, 0, 0), "hd": Vector3(-14, 0, 0),
		"f0": Vector3(-0.1, 0.33, -0.12), "f1": Vector3(0.1, 0.38, 0.04), "p0": Vector3(-20, 0, 0), "p1": Vector3(-5, 0, 0),
		"q0": 0.6, "q1": 0.5, "k0": Vector3(-0.1, 0.3, 1), "k1": Vector3(0.1, 0.3, 1)})
	tuck.merge(_arms_forward(cfg, 0.12), true)
	if cfg.shield:
		tuck.merge({"se": Vector3(0.2, 1.08, 0.2), "sf": Vector3(-0.7, 0.25, 0.65), "sn": Vector3(0.4, 0.15, 1.0)}, true)
	var reach := _with(n, {"hp": Vector3(0, -0.02, 0.0), "hr": Vector3(4, 0, 0), "sp": Vector3(6, 0, 0), "hd": Vector3(-6, 0, 0),
		"f0": Vector3(-0.1, 0.12, 0.12), "f1": Vector3(0.1, 0.1, 0.18), "p0": Vector3(5, 4, 0), "p1": Vector3(8, 4, 0), "q0": 0.2, "q1": 0.2})
	reach.merge(_arms_forward(cfg, 0.04), true)
	var land := _with(n, {"hp": Vector3(0, -0.2, 0.03), "hr": Vector3(12, 0, 0), "sp": Vector3(14, 0, 0), "hd": Vector3(-12, 0, 0),
		"f0": Vector3(-0.11, ANKLE_H, 0.02), "f1": Vector3(0.11, ANKLE_H, 0.1)})
	var keys := [
		_k(0.0, n, {}),
		_k(0.06, push, {}),
		_k(0.22, tuck, {}),
		_k(0.34, tuck, {}),
		_k(0.5, reach, {}),
		_k(0.6, land, {}),
		_k(0.72, _with(land, {"hp": Vector3(0, -0.12, 0.02), "sp": Vector3(8, 0, 0)}), {}),
		_k(0.9, n, {}, true),
	]
	return _bake_keys(keys, cfg)


# --- arrampicata ---------------------------------------------------------------------------------------

## Altezze (m) dei blocchi per cui esiste una clip di arrampicata ("climb_0", "climb_1", ...).
const CLIP_CLIMB_HEIGHTS := [1.25, 1.6, 1.95]
## Durata dell'arrampicata (s): clip e movimento del GridUnit sono sincronizzati su questa.
const CLIMB_TIME := 1.8
## Distanza (m) dalla faccia del blocco a cui ci si aggrappa, e posizione della presa sul piano.
const CLIMB_GRAB_Z := 0.65


static func climb_clip(index: int) -> StringName:
	return StringName("climb_%d" % index)


## Indice della clip di arrampicata più vicina all'altezza `h` del blocco.
static func climb_index(h: float) -> int:
	var best := 0
	for i in CLIP_CLIMB_HEIGHTS.size():
		if absf(CLIP_CLIMB_HEIGHTS[i] - h) < absf(CLIP_CLIMB_HEIGHTS[best] - h):
			best = i
	return best


## Percorso del bacino/piedi (radice dell'unità) durante l'arrampicata, per f in 0..1 del tempo:
## x = frazione dei 2 m fra la casella di partenza e quella di arrivo, y = scarto verticale dal
## terreno di partenza. `h` altezza del blocco, `y_end` dislivello del terreno d'arrivo.
static func climb_profile(f: float, h: float, y_end := 0.0) -> Vector2:
	var keys := [
		[0.0, 0.0, 0.0], [0.12, 0.17, 0.0], [0.5, 0.19, h - 0.9], [0.64, 0.4, h],
		[0.74, 0.5, h], [0.78, 0.55, h], [1.0, 1.0, y_end],
	]
	f = clampf(f, 0.0, 1.0)
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if f <= float(b[0]):
			var u := (f - float(a[0])) / (float(b[0]) - float(a[0]))
			var ux := smoothstep(0.0, 1.0, u)
			var uy := u * u if i == keys.size() - 2 else ux   # ultimo tratto: caduta
			return Vector2(lerpf(float(a[1]), float(b[1]), ux if i < keys.size() - 2 else u), lerpf(float(a[2]), float(b[2]), uy))
	return Vector2(1.0, y_end)


## Arrampicata su un blocco alto `h`: sguardo alla cornice, presa con le mani, trazione, bacino oltre
## il bordo, in piedi sul blocco, discesa dall'altra parte. Il corpo sale con climb_profile().
static func _climb(cfg: Cfg, h: float) -> Animation:
	return _bake(CLIMB_TIME, false, 30.0, func(t: float) -> Dictionary: return _climb_fields(cfg, h, t / CLIMB_TIME), cfg)


static func _climb_fields(cfg: Cfg, h: float, f: float) -> Dictionary:
	var n := _neutral()
	n.merge(_right_carry(cfg, 0.0, 0.0), true)
	n.merge(_left_carry(cfg, 0.0, 0.0), true)
	var pr := climb_profile(f, h)
	var rx := pr.x * 2.0
	var ry := pr.y
	var grab := smoothstep(0.0, 0.12, f) * (1.0 - smoothstep(0.64, 0.8, f))
	var rel_h := h - ry
	var ledge_z := CLIMB_GRAB_Z - rx
	var o := {}
	var pull := smoothstep(0.12, 0.5, f) * (1.0 - smoothstep(0.5, 0.74, f))
	var over := smoothstep(0.5, 0.66, f) * (1.0 - smoothstep(0.7, 0.8, f))
	var drop := smoothstep(0.78, 0.92, f)
	# Busto: testa alla cornice, poi si piega sul bordo, poi in piedi.
	var lean := 8.0 + 26.0 * pull + 28.0 * over
	o["sp"] = Vector3(lean, 0, 0)
	o["hd"] = Vector3(-14.0 * grab - 4.0 * over, 0, 0)
	o["hp"] = Vector3(0, -0.03 - 0.2 * over - 0.18 * smoothstep(0.7, 0.8, f) * (1.0 - drop), 0.04 * pull)
	o["hr"] = Vector3(10.0 * pull + 10.0 * over, 0, 0)
	# Piedi: in appoggio sulla parete a destra/sinistra alternati (uno si alza e spinge).
	var scr := sin(f * TAU * 2.2) * pull
	var wall_z := 0.07
	var fz := lerpf(0.01, wall_z, smoothstep(0.1, 0.3, f) * (1.0 - over))
	o["f0"] = Vector3(-0.105, ANKLE_H + maxf(scr, 0.0) * 0.16, fz + 0.04 * maxf(scr, 0.0))
	o["f1"] = Vector3(0.105, ANKLE_H + maxf(-scr, 0.0) * 0.16, fz + 0.04 * maxf(-scr, 0.0))
	o["k0"] = Vector3(-0.15, 0.0, 1.0)
	o["k1"] = Vector3(0.15, 0.0, 1.0)
	o["p0"] = Vector3(10.0 * pull, 8, 0)
	o["p1"] = Vector3(10.0 * pull, 8, 0)
	var air := smoothstep(0.78, 0.84, f) * (1.0 - smoothstep(0.96, 1.0, f))
	var land_crouch := smoothstep(0.93, 1.0, f)
	o["hp"] = (o["hp"] as Vector3) + Vector3(0, -0.2 * land_crouch + 0.02 * air, 0.05 * land_crouch)
	o["sp"] = (o["sp"] as Vector3) + Vector3(18.0 * land_crouch - 14.0 * drop * (1.0 - land_crouch), 0, 0)
	if air > 0.0:
		o["f0"] = Vector3(-0.1, ANKLE_H + 0.18 * air, 0.1 * air)
		o["f1"] = Vector3(0.1, ANKLE_H + 0.12 * air, 0.14 * air)
		o["q0"] = 0.35 * air
		o["q1"] = 0.35 * air
	# Braccia: sulla cornice, poi in avanti/bilanciamento in caduta.
	var rest0: Vector3 = n["w0"]
	var rest1: Vector3 = n.get("w1", Vector3(0.2, 0.71, 0.04))
	var grip0 := Vector3(-0.2 if cfg.right == Hand.NONE else -0.32, rel_h, ledge_z)
	var grip1 := Vector3(0.2, rel_h, ledge_z)
	var bal0 := Vector3(-0.42, 0.95, 0.12)
	var bal1 := Vector3(0.42, 0.95, 0.12)
	var m0 := rest0.lerp(grip0, grab).lerp(bal0, drop)
	var m1 := rest1.lerp(grip1, grab).lerp(bal1, drop)
	if cfg.right == Hand.NONE:
		o["m0"] = m0
		o["mw0"] = 1.0 if (grab > 0.001 or drop > 0.001) else 0.0
		o["d0"] = Vector3.ZERO if o["mw0"] > 0.0 else n["d0"]
	else:
		# Con un'arma in pugno la mano destra si aggrappa lo stesso, ma l'arma resta lontana dal corpo:
		# spada e lancia verticali, lungo la parete.
		var hold := Vector3(0.35, 1.0, 0.15)
		var carry_d: Vector3 = n["d0"]
		o["w0"] = (rest0.lerp(grip0, grab) if not drop > 0.0 else rest0.lerp(grip0, grab).lerp(bal0, drop))
		o["d0"] = carry_d.lerp(hold.normalized(), grab).normalized()
	o["e0"] = Vector3(-0.7, -0.4, -0.6)
	if cfg.shield:
		var up_amt := grab
		o["se"] = (n["se"] as Vector3).lerp(Vector3(0.24, 1.2, 0.2), up_amt)
		o["sf"] = (n["sf"] as Vector3).lerp(Vector3(0.1, 0.55, 0.83).normalized(), up_amt)
		o["sn"] = (n["sn"] as Vector3).lerp(Vector3(1.0, 0.0, 0.3), up_amt)
	else:
		o["m1"] = m1
		o["mw1"] = 1.0 if (grab > 0.001 or drop > 0.001) else 0.0
		o["e1"] = Vector3(0.7, -0.4, -0.6)
		if n.has("d1"):
			o["d1"] = Vector3.ZERO if o["mw1"] > 0.0 else n["d1"]
	return _with(n, o)


static func _arms_forward(cfg: Cfg, lift: float) -> Dictionary:
	var f := {}
	if cfg.right == Hand.NONE:
		f["w0"] = Vector3(-0.19, 0.9 + lift, 0.26)
	else:
		f["w0"] = Vector3(-0.21, 0.88 + lift, 0.22)
	if not cfg.shield and not cfg.bow:
		f["w1"] = Vector3(0.19, 0.9 + lift, 0.26)
	return f


## Morte all'indietro (colpito da davanti): il colpo spinge, le ginocchia cedono, caduta sulla schiena,
## rimbalzo e quiete. Le altre varianti: _death_variant().
static func _death(cfg: Cfg) -> Animation:
	var n := _with(_neutral(), {})
	n.merge(_right_carry(cfg, 0.0, 0.0), true)
	n.merge(_left_carry(cfg, 0.0, 0.0), true)
	var recoil := _with(n, {"hp": Vector3(0, -0.05, -0.06), "hr": Vector3(-6, 8, 0), "sp": Vector3(-16, 6, 4), "hd": Vector3(-22, -8, 0)})
	recoil["w0"] = (n["w0"] as Vector3) + Vector3(-0.08, 0.12, -0.05)
	if not cfg.shield:
		recoil["w1"] = (n["w1"] as Vector3) + Vector3(0.08, 0.12, -0.05)
	var buckle := _with(n, {"hp": Vector3(0.03, -0.25, -0.12), "hr": Vector3(-14, 16, 10), "sp": Vector3(26, 10, 14), "hd": Vector3(24, -10, 12),
		"w0": Vector3(-0.4, 0.9, 0.02), "e0": Vector3(-0.3, 1, -0.3), "d0": Vector3(-0.7, -0.3, 0.6),
		"k0": Vector3(-0.3, 0, 1), "k1": Vector3(0.3, 0, 1)})
	if cfg.right == Hand.SPEAR:
		buckle["w0"] = Vector3(-0.42, 0.95, 0.12)
		buckle["d0"] = Vector3(-0.35, 0.85, 0.4)
		buckle["th"] = 0.0
	var fall := _with(buckle, {"hp": Vector3(0, -0.45, -0.3), "hr": Vector3(-50, 8, 6), "sp": Vector3(-6, 0, 4), "hd": Vector3(-14, 0, 0),
		"f0": Vector3(-0.12, 0.08, 0.05), "f1": Vector3(0.12, 0.08, 0.08)})
	var down := _with(fall, {"hp": Vector3(0, -0.582, -0.52), "hr": Vector3(-88, 6, 0), "sp": Vector3(-4, 0, 0), "hd": Vector3(-6, 30, 0),
		"f0": Vector3(-0.17, 0.075, 0.12), "f1": Vector3(0.14, 0.075, 0.2), "q0": 0.8, "q1": 0.8,
		"w0": Vector3(-0.52, 1.1, -0.06), "e0": Vector3(0, -1, 0), "w1": Vector3(0.48, 1.0, -0.06), "e1": Vector3(0, -1, 0)})
	if cfg.shield:
		down.merge({"se": Vector3(0.38, 1.0, -0.06), "sf": Vector3(0.6, -0.5, 0.1), "sn": Vector3(0.1, 0.0, 1.0)}, true)
	var bounce := _with(down, {"hp": Vector3(0, -0.56, -0.5), "hr": Vector3(-82, 6, 0), "hd": Vector3(-2, 26, 0)})
	var keys := [
		_k(0.0, n, {}, true),
		_k(0.1, recoil, {}),
		_k(0.3, buckle, {}),
		_k(0.48, fall, {}),
		_k(0.64, down, {}),
		_k(0.74, bounce, {}),
		_k(0.95, down, {}, true),
		_k(1.25, _with(down, {"hd": Vector3(-4, 34, 0)}), {}, true),
	]
	return _bake_keys(keys, cfg)



## Varianti di caduta (in spazio anim il soldato guarda +Z, la sua destra anatomica e' -X):
##  "front"  colpito da dietro: spinta in avanti, ginocchia a terra, crollo a faccia in giu';
##  "side_r" / "side_l"  colpito di lato: ginocchia che cedono e crollo sul fianco destro / sinistro.
## Dove finisce la testa (spazio anim) lo dice death_head_dir().
static func _death_variant(cfg: Cfg, kind: String) -> Animation:
	var n := _with(_neutral(), {})
	n.merge(_right_carry(cfg, 0.0, 0.0), true)
	n.merge(_left_carry(cfg, 0.0, 0.0), true)
	var keys: Array
	if kind == "front":
		var jolt := _with(n, {"hp": Vector3(0, -0.04, 0.05), "hr": Vector3(5, -6, 0), "sp": Vector3(-8, -6, 3), "hd": Vector3(-20, 6, 0),
			"w0": Vector3(-0.42, 0.85, -0.1), "w1": Vector3(0.42, 0.85, -0.1), "e0": Vector3(-1, 0, -0.3), "e1": Vector3(1, 0, -0.3)})
		if cfg.shield:
			jolt.merge({"se": Vector3(0.3, 0.9, -0.05), "sf": Vector3(0.3, -0.4, 0.8), "sn": Vector3(0.8, 0.1, 0.5)}, true)
		if cfg.right == Hand.SPEAR:
			jolt["d0"] = Vector3(-1.0, 0.1, 0.2).normalized()
			jolt["th"] = 0.0
			jolt["sp"] = Vector3(-3, -4, 2)
		var stagger := _with(n, {"hp": Vector3(0, -0.2, 0.14), "hr": Vector3(14, 6, 0), "sp": Vector3(18, 4, 0), "hd": Vector3(-6, 0, 0),
			"f0": Vector3(-0.12, ANKLE_H, 0.2), "f1": Vector3(0.12, ANKLE_H, -0.05), "k0": Vector3(-0.2, 0, 1), "k1": Vector3(0.2, 0, 1)})
		stagger.merge(_arms_forward(cfg, -0.12), true)
		if cfg.right == Hand.SPEAR:
			stagger["d0"] = Vector3(-0.6, -0.7, 0.2).normalized()
			stagger["th"] = 0.0
		var kneel := _with(stagger, {"hp": Vector3(0, -0.42, 0.14), "hr": Vector3(18, 4, 0), "sp": Vector3(26, 0, 0), "hd": Vector3(-12, -6, 0),
			"f0": Vector3(-0.14, 0.1, -0.4), "f1": Vector3(0.14, 0.1, -0.4), "q0": 0.9, "q1": 0.9})
		if cfg.right == Hand.SPEAR:
			kneel["d0"] = Vector3(-1.0, 0.2, 0.0).normalized()
		var fall := _with(kneel, {"hp": Vector3(0, -0.5, 0.34), "hr": Vector3(58, 0, 0), "sp": Vector3(10, 0, 0), "hd": Vector3(-14, 18, 0),
			"f0": Vector3(-0.14, 0.09, -0.5), "f1": Vector3(0.14, 0.09, -0.5), "q0": 1.0, "q1": 1.0,
			"w0": Vector3(-0.42, 0.95, 0.22), "w1": Vector3(0.42, 0.95, 0.22), "e0": Vector3(-1, 0, 0.2), "e1": Vector3(1, 0, 0.2)})
		var down := _with(fall, {"hp": Vector3(0, -0.57, 0.52), "hr": Vector3(86, 0, 0), "sp": Vector3(2, 0, 0), "hd": Vector3(-8, 34, 0),
			"f0": Vector3(-0.15, 0.09, -0.4), "f1": Vector3(0.16, 0.09, -0.46),
			"w0": Vector3(-0.5, 1.0, 0.12), "w1": Vector3(0.5, 1.0, 0.12), "e0": Vector3(-1, 0, 0), "e1": Vector3(1, 0, 0)})
		if cfg.shield:
			down.merge({"se": Vector3(0.4, 1.0, 0.1), "sf": Vector3(0.6, 0.1, 0.4), "sn": Vector3(0.1, 0.9, 0.2)}, true)
		if cfg.right != Hand.NONE:
			# L'arma sfugge di mano e giace lungo il corpo, non conficcata nel terreno.
			fall["d0"] = Vector3(-0.9, 0.5, 0.0).normalized() if cfg.right == Hand.SPEAR else Vector3(-0.4, 0.5, 0.2).normalized()
			down["d0"] = Vector3(-0.9, 0.5, 0.0).normalized() if cfg.right == Hand.SPEAR else Vector3(-0.6, 0.8, 0.0).normalized()
			down["w0"] = Vector3(-0.55, 1.0, 0.08)
		var bounce := _with(down, {"hp": Vector3(0, -0.55, 0.5), "hr": Vector3(82, 0, 0)})
		keys = [_k(0.0, n, {}, true), _k(0.1, jolt, {}), _k(0.3, stagger, {}), _k(0.52, kneel, {}), _k(0.74, fall, {}),
			_k(0.9, down, {}), _k(1.0, bounce, {}), _k(1.2, down, {}, true), _k(1.5, _with(down, {"hd": Vector3(-8, 36, 0)}), {}, true)]
	else:
		# Sul fianco: sg=+1 testa verso la destra anatomica (-X), il braccio destro finisce sotto.
		var sg := 1.0 if kind == "side_r" else -1.0
		var jolt := _with(n, {"hp": Vector3(0.05 * sg, -0.05, 0), "hr": Vector3(0, 0, -8 * sg), "sp": Vector3(-6, 0, -10 * sg), "hd": Vector3(-8, 0, -10 * sg),
			"w0": (n["w0"] as Vector3) + Vector3(-0.06, 0.1, 0), "w1": (n["w1"] as Vector3) + Vector3(0.06, 0.1, 0)})
		if cfg.shield:
			jolt.merge({"se": Vector3(0.3, 0.85, 0.05), "sf": Vector3(0.3, -0.2, 0.9), "sn": Vector3(0.8, 0.05, 0.5)}, true)
		var buckle := _with(n, {"hp": Vector3(-0.1 * sg, -0.28, 0.03), "hr": Vector3(0, 8 * sg, 14 * sg), "sp": Vector3(14, 0, 12 * sg), "hd": Vector3(8, 0, 14 * sg),
			"k0": Vector3(-0.3, 0, 1), "k1": Vector3(0.3, 0, 1)})
		if cfg.right != Hand.NONE:
			buckle["d0"] = Vector3(-0.3, -0.45, 0.8).normalized()
		if cfg.shield:
			buckle.merge({"se": Vector3(0.35, 0.8, 0.1), "sf": Vector3(0.3, -0.2, 0.9), "sn": Vector3(0.8, 0.05, 0.5)}, true)
		var fall := _with(buckle, {"hp": Vector3(-0.3 * sg, -0.42, 0.0), "hr": Vector3(0, 0, 55 * sg), "sp": Vector3(6, 0, 12 * sg), "hd": Vector3(0, 0, 8 * sg),
			"f0": Vector3(-0.13, 0.09, 0.1), "f1": Vector3(0.13, 0.09, 0.14), "q0": 0.6, "q1": 0.6})
		if cfg.shield:
			buckle.merge({"se": Vector3(0.35, 0.8, 0.1), "sf": Vector3(0.3, -0.2, 0.9), "sn": Vector3(0.8, 0.05, 0.5)}, true)
			fall.merge({"se": Vector3(0.4, 0.7, 0.45), "sf": Vector3(0.2, -0.1, 1.0), "sn": Vector3(0.7, 0.05, 0.6)} if sg < 0.0 else {"se": Vector3(0.15, 0.75, 0.4), "sf": Vector3(-0.2, -0.1, 1.0), "sn": Vector3(0.5 * sg, 0.1, 0.5)}, true)
		var down := _with(fall, {"hp": Vector3(-0.5 * sg, -0.44, -0.02), "hr": Vector3(0, 6 * sg, 86 * sg), "sp": Vector3(2, 0, 2 * sg), "hd": Vector3(0, 10 * sg, 4 * sg),
			"f0": Vector3(0.3 * sg, 0.1, 0.12), "f1": Vector3(0.3 * sg, 0.1, 0.34), "q0": 1.0, "q1": 1.0,
			"k0": Vector3(0, 0, 1), "k1": Vector3(0, 0, 1)})
		# Il braccio sotto resta lungo il corpo, quello sopra cade avanti sul terreno.
		var under := 0 if sg > 0.0 else 1
		var top := 1 - under
		down["w%d" % under] = Vector3(-0.3 * sg + (0.0), 0.8, 0.1)
		down["e%d" % under] = Vector3(0, -1, 0.2)
		down["w%d" % top] = Vector3(0.12 * sg, 0.7, 0.3)
		down["e%d" % top] = Vector3(0, -1, 0.3)
		if cfg.shield:
			# Lo scudo (braccio sinistro) giace piatto sul terreno davanti al corpo: la sua normale e' la verticale.
			down.merge({"se": Vector3(0.12, 0.62, 0.5) if sg > 0.0 else Vector3(0.45, 0.1, 1.4), "sf": Vector3(0.0, 0.05, 1.0), "sn": Vector3(sg, 0.05, 0.0)}, true)
		if cfg.right != Hand.NONE:
			down["d0"] = Vector3(0.0, -0.2, 1.0).normalized()
		var bounce := _with(down, {"hp": Vector3(-0.49 * sg, -0.43, -0.02), "hr": Vector3(0, 6 * sg, 83 * sg)})
		keys = [_k(0.0, n, {}, true), _k(0.1, jolt, {}), _k(0.3, buckle, {}), _k(0.5, fall, {}), _k(0.7, down, {}),
			_k(0.8, bounce, {}), _k(1.0, down, {}, true), _k(1.3, _with(down, {"hd": Vector3(0, 12 * sg, 4 * sg)}), {}, true)]
	return _bake_keys(keys, cfg)


## Verso (spazio anim) in cui punta la testa del caduto, per posare il corpo sul rilievo.
static func death_head_dir(clip: StringName) -> Vector3:
	match clip:
		&"death_front": return Vector3.BACK
		&"death_side_r": return Vector3.LEFT
		&"death_side_l": return Vector3.RIGHT
	return Vector3.FORWARD


## Posa sdraiata del ferito (centrata sull'origine): una gamba piegata, mano sulla ferita, respiro.
static func _lie_pose(cfg: Cfg) -> Dictionary:
	var n := _neutral()
	return _with(n, {"hp": Vector3(0, -0.585, 0.08), "hr": Vector3(-88, 4, 0), "sp": Vector3(-3, 0, 0), "nk": Vector3(4, 0, 0), "hd": Vector3(0, 24, 0),
		"f0": Vector3(-0.13, 0.12, 0.42), "p0": Vector3(30, 8, 0), "k0": Vector3(-0.2, 0, 1),
		"f1": Vector3(0.16, 0.075, 0.68), "q1": 0.85, "k1": Vector3(0.3, 0, 1),
		"w0": Vector3(-0.05, 0.86, 0.17), "e0": Vector3(-1, -0.2, -0.2),
		"w1": Vector3(0.46, 0.98, -0.07), "e1": Vector3(0.2, -1, 0)})


static func _lie(cfg: Cfg, dead: bool) -> Animation:
	var length := 5.0
	var pose := _lie_pose(cfg)
	return _bake(length, true, 12.0, func(t: float) -> Dictionary:
		var u := t / length
		var f := pose.duplicate()
		if dead:
			f["hd"] = Vector3(-4, 36, 0)
			f["w0"] = Vector3(-0.42, 1.0, -0.07)
			f["e0"] = Vector3(-0.2, -1, 0)
			f["f0"] = Vector3(-0.15, 0.075, 0.66)
			f["q0"] = 0.85
			return f
		var breath := sin(TAU * u * 5.0)
		var writhe := 0.5 + 0.5 * sin(TAU * u - 1.0)
		f["sp"] = (f["sp"] as Vector3) + Vector3(-1.5 * breath, 0, 0)
		f["hd"] = (f["hd"] as Vector3) + Vector3(-4.0 * writhe, -10.0 * writhe, 0)
		f["f0"] = (f["f0"] as Vector3) + Vector3(0, 0.02 * writhe, -0.04 * writhe)
		f["w0"] = (f["w0"] as Vector3) + Vector3(0, 0.01 * breath, 0.012 * breath)
		return f, cfg)


## Rialzarsi da sdraiato: si tira su a sedere, si gira su un ginocchio, si alza (fino al riposo zoppo).
static func _getup(cfg: Cfg) -> Animation:
	var lie := _lie_pose(cfg)
	var sit := _with(lie, {"hp": Vector3(0, -0.56, 0.06), "hr": Vector3(-35, 6, 0), "sp": Vector3(22, 0, 0), "hd": Vector3(-10, 10, 0),
		"f0": Vector3(-0.13, 0.08, 0.32), "p0": Vector3(5, 8, 0), "q0": 0.0,
		"f1": Vector3(0.14, 0.08, 0.3), "q1": 0.0, "p1": Vector3(5, 8, 0), "k1": Vector3(0.2, 0, 1),
		"w0": Vector3(-0.22, 0.74, -0.18), "e0": Vector3(-0.5, 0, -1), "w1": Vector3(0.24, 0.7, -0.12), "e1": Vector3(0.5, 0, -1)})
	var kneel := _with(_neutral(), {"hp": Vector3(0, -0.36, -0.02), "hr": Vector3(6, 10, 0), "sp": Vector3(18, 0, 0), "hd": Vector3(-14, 0, 0),
		"f1": Vector3(0.13, ANKLE_H, 0.24), "k1": Vector3(0.2, 0, 1),
		"f0": Vector3(-0.12, 0.13, -0.38), "p0": Vector3(-60, 6, 0), "k0": Vector3(-0.15, -0.6, 1),
		"w1": Vector3(0.14, 0.82, 0.28), "e1": Vector3(0.7, 0, -0.6), "w0": Vector3(0.0, 0.9, 0.16), "e0": Vector3(-0.8, 0, -0.5)})
	var rise := _with(_neutral(), {"hp": Vector3(0.03, -0.17, 0.0), "hr": Vector3(10, 4, -3), "sp": Vector3(18, -2, 2), "hd": Vector3(-10, 0, 0),
		"f1": Vector3(0.12, ANKLE_H, 0.1), "f0": Vector3(-0.12, 0.1, -0.12), "p0": Vector3(-25, 8, 0),
		"w1": Vector3(0.06, 0.9, 0.16), "e1": Vector3(0.8, -0.1, -0.5), "w0": Vector3(-0.15, 0.95, 0.2), "e0": Vector3(-0.6, -0.4, -0.5)})
	var end_pose: Dictionary = _limp_idle_pose()
	var keys := [
		_k(0.0, lie, {}, true),
		_k(0.45, sit, {}),
		_k(0.9, kneel, {}),
		_k(1.35, rise, {}),
		_k(1.7, end_pose, {}, true),
	]
	return _bake_keys(keys, cfg, 24.0)


static func _limp_idle_pose() -> Dictionary:
	return _with(_neutral(), {"f0": Vector3(-0.12, 0.09, 0.04), "p0": Vector3(-12, 10, 0), "f1": Vector3(0.11, ANKLE_H, -0.02),
		"hp": Vector3(0.04, -0.07, -0.02), "hr": Vector3(8, 4, -5), "sp": Vector3(14, -4, 4), "hd": Vector3(-6, 0, 0),
		"w1": Vector3(0.04, 0.9, 0.15), "e1": Vector3(0.8, -0.1, -0.5), "w0": Vector3(-0.12, 1.12, 0.34), "e0": Vector3(-0.6, -0.6, -0.3)})


## Copia un'animazione all'indietro nel tempo (sdraiarsi = rialzarsi al contrario).
static func _reverse(src: Animation) -> Animation:
	var a := Animation.new()
	a.length = src.length
	for t in src.get_track_count():
		var tr := a.add_track(src.track_get_type(t))
		a.track_set_path(tr, src.track_get_path(t))
		var n := src.track_get_key_count(t)
		for i in n:
			var j := n - 1 - i
			var time := src.length - src.track_get_key_time(t, j)
			a.track_insert_key(tr, time, src.track_get_key_value(t, j))
	return a


# --- arco --------------------------------------------------------------------------------------------

## Arciere sulle mura: di fianco al bersaglio, arco teso, piccole correzioni di mira e respiro.
static func _aim_pose(cfg: Cfg, draw: float) -> Dictionary:
	var f := _with(_neutral(), {"f1": Vector3(0.14, ANKLE_H, 0.1), "f0": Vector3(-0.12, ANKLE_H, -0.14), "p0": Vector3(0, 70, 0), "p1": Vector3(0, 40, 0),
		"hp": Vector3(0, -0.05, 0), "hr": Vector3(0, -50, 0), "sp": Vector3(2, -8, -4), "hd": Vector3(-2, 52, 4)})
	# Braccio dell'arco teso verso il bersaglio (+Z nel modello), mano della corda all'altezza della guancia.
	f["m1"] = Vector3(0.07, 1.15, 0.56)
	f["mw1"] = 1.0
	f["e1"] = Vector3(0.9, -0.3, -0.1)
	f["d1"] = Vector3(-0.15, 0.95, 0.1)
	f["a1"] = Vector3.ZERO
	f["m0"] = Vector3(0.05, 1.16, 0.5).lerp(Vector3(-0.01, 1.21, 0.04), draw)
	f["mw0"] = 1.0
	f["e0"] = Vector3(-1, 0.3, -0.6)
	return f


static func _aim(cfg: Cfg) -> Animation:
	var length := 3.0
	var keys := [
		_k(0.0, _aim_pose(cfg, 1.0), {}),
		_k(1.0, _aim_pose(cfg, 1.0), {"hd": Vector3(-1, 50, 4), "m1": Vector3(0.08, 1.16, 0.56), "sp": Vector3(3, -8, -4)}),
		_k(2.0, _aim_pose(cfg, 0.97), {"m1": Vector3(0.06, 1.15, 0.56)}),
		_k(length, _aim_pose(cfg, 1.0), {}),
	]
	return _bake_keys_loop(keys, cfg, 15.0)


## Tiro: rilascio (la freccia parte subito), accompagnamento, mano alla faretra, incocca, ritende.
static func _shoot(cfg: Cfg) -> Animation:
	var aim := _aim_pose(cfg, 1.0)
	var rel := _with(aim, {"m0": Vector3(-0.08, 1.22, -0.05), "hd": Vector3(-1, 50, 4)})
	var quiver := _with(aim, {"m0": Vector3(-0.12, 1.36, -0.13), "e0": Vector3(-1, 0.5, 0.2), "m1": Vector3(0.18, 1.0, 0.36), "sp": Vector3(2, -2, -2), "hd": Vector3(-4, 30, 0)})
	var nock := _with(aim, {"m0": Vector3(0.1, 1.04, 0.3), "e0": Vector3(-1, 0, -0.3), "m1": Vector3(0.16, 1.04, 0.38), "hd": Vector3(4, 40, 0)})
	var keys := [
		_k(0.0, aim, {}),
		_k(0.08, rel, {}),
		_k(0.3, _with(rel, {"m1": Vector3(0.09, 1.12, 0.54)}), {}),
		_k(0.7, quiver, {}),
		_k(1.05, nock, {}),
		_k(1.4, _aim_pose(cfg, 0.5), {}),
		_k(1.7, aim, {}, true),
	]
	return _bake_keys(keys, cfg)


# =====================================================================================================
# Verifica (test): compenetrazioni di armi e scudo con il corpo
# =====================================================================================================

## Posa (trasformazioni globali delle ossa) di un'animazione al tempo t: per i test.
static func pose_at(anim: Animation, t: float) -> Pose:
	var r := _rig
	var p := Pose.new(r)
	for tr in anim.get_track_count():
		var bi: int = r.idx.get(String(anim.track_get_path(tr)).get_slice(":", 1), -1)
		if bi < 0:
			continue
		if anim.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
			p.rot[bi] = anim.rotation_track_interpolate(tr, t)
		elif anim.track_get_type(tr) == Animation.TYPE_POSITION_3D:
			p.hips_pos = anim.position_track_interpolate(tr, t)
	p.fk()
	return p


## Scivolamento dei piedi d'appoggio in un'andatura: massimo spostamento (m) nel mondo di una caviglia
## a terra durante un appoggio, con il corpo che avanza di `stride` per ciclo.
static func foot_slip(anim: Animation, stride_m: float) -> float:
	var r := _rig
	var worst := 0.0
	for s in 2:
		var start := Vector3.INF
		var n := 96
		for i in n + 1:
			var t := anim.length * i / float(n)
			var p := pose_at(anim, t)
			var a := p.g[r.foot[s]].origin + Vector3(0, 0, stride_m * t / anim.length)
			if a.y < 0.075:
				if start == Vector3.INF:
					start = a
				worst = maxf(worst, Vector2(a.x - start.x, a.z - start.z).length())
			else:
				start = Vector3.INF
	return worst


## Distanza fra un punto e un segmento.
static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Controlla un'animazione già calcolata: restituisce la compenetrazione massima (m) di arma e scudo
## nel corpo (capsule semplificate del busto, testa, gambe) e il fotogramma peggiore.
static func audit(anim: Animation, right: Hand, shield: bool, step := 1.0 / 30.0) -> Dictionary:
	var r := _rig
	var worst := 0.0
	var worst_t := 0.0
	var what := ""
	var tracks := {}
	for t in anim.get_track_count():
		var bone := String(anim.track_get_path(t)).get_slice(":", 1)
		tracks[t] = r.idx.get(bone, -1)
	var t := 0.0
	while t <= anim.length + 0.0001:
		var p := Pose.new(r)
		for tr: int in tracks:
			var bi: int = tracks[tr]
			if bi < 0:
				continue
			if anim.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
				p.rot[bi] = anim.rotation_track_interpolate(tr, t)
			elif anim.track_get_type(tr) == Animation.TYPE_POSITION_3D:
				p.hips_pos = anim.position_track_interpolate(tr, t)
		p.fk()
		var caps := [
			["busto", p.g[r.hips].origin + p.g[r.hips].basis * Vector3(0, 0.05, 0.0), p.g[r.neck].origin, 0.13],
			["testa", p.g[r.head].origin + p.g[r.head].basis * Vector3(0, 0.08, 0.02), p.g[r.head].origin + p.g[r.head].basis * Vector3(0, 0.12, 0.02), 0.1],
		]
		for s in 2:
			caps.append(["coscia%d" % s, p.g[r.thigh[s]].origin, p.g[r.shin[s]].origin, 0.07])
			caps.append(["stinco%d" % s, p.g[r.shin[s]].origin, p.g[r.foot[s]].origin, 0.055])
		var pts := []
		if right != Hand.NONE:
			var hg := p.g[r.hand[0]]
			var d := (hg.basis * (r.thumb_loc[0] as Vector3)).normalized()
			var grip := hg.origin + hg.basis * (r.grip_loc[0] as Vector3)
			var back := SPEAR_BACK if right == Hand.SPEAR else SWORD_BACK
			var tip := SPEAR_TIP if right == Hand.SPEAR else SWORD_TIP
			for i in 9:
				var k := lerpf(-back, tip, i / 8.0)
				if absf(k) < 0.06:
					continue
				pts.append(["arma", grip + d * k, 0.012])
		if shield:
			var fg := p.g[r.lo[1]]
			var fd := (p.g[r.hand[1]].origin - fg.origin).normalized()
			var nrm := (fg.basis * r.dorsal_loc).normalized()
			var c := fg.origin + fd * (r.rest[r.hand[1]].origin.length() * 0.5) + nrm * SHIELD_OUT
			var u := fd
			var v := nrm.cross(fd).normalized()
			pts.append(["scudo", c, 0.03])
			for i in 12:
				var ang := TAU * i / 12.0
				pts.append(["scudo", c + (u * cos(ang) + v * sin(ang)) * SHIELD_RADIUS * 0.92, 0.015])
				pts.append(["scudo", c + (u * cos(ang) + v * sin(ang)) * SHIELD_RADIUS * 0.5, 0.02])
		for pt in pts:
			for cp in caps:
				var dist := _seg_dist(pt[1], cp[1], cp[2])
				var pen: float = (cp[3] as float) + (pt[2] as float) - dist
				if pen > worst:
					worst = pen
					worst_t = t
					what = "%s nel %s" % [pt[0], cp[0]]
		t += step
	return {"pen": worst, "t": worst_t, "what": what}
