class_name ShoreProfile
extends RefCounted
## Profilo della riva del livello 1: linea d'acqua sinuosa (golfi e promontori), fondale che
## sale dolcemente, battigia, berma e dune basse che si fondono col terreno fotorealistico.
## Le formule di waterline() e floor_height() sono copiate in
## assets/shaders/shore_profile.gdshaderinc (mare e sabbia): vanno tenute uguali.
## Usato da SeaShore (mesh della sabbia e dettagli) e dai test.

const WATER_Y := -0.1
const SEABED_Y := -0.6
const Z_MIN := -19.0
const Z_MAX := 22.0
const BASE_X := -21.75
## La sabbia generata finisce qui (est): da qui in poi vale il terreno.
const LAND_X := -19.2
const BLEND_X := -20.5

static var _noise: FastNoiseLite


static func smooth01(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## x mondiale della linea d'acqua alla coordinata z.
static func waterline(z: float) -> float:
	return BASE_X + 0.50 * sin(z * 0.29 + 0.9) + 0.28 * sin(z * 0.71 + 3.1) + 0.12 * sin(z * 1.63 + 5.0)


## Quota sotto il pelo dell'acqua (gemella di shore_floor() nello shader); a terra >= WATER_Y.
static func floor_height(x: float, z: float) -> float:
	var s := x - waterline(z)
	var h := SEABED_Y + 0.5 * exp(0.6 * minf(s, 0.0))
	if s > 0.0:
		h = WATER_Y + 0.19 * (1.0 - exp(-0.85 * s))
	var wob := 0.30 * sin(x * 0.55 + 1.0) + 0.15 * sin(x * 1.37 + 2.0)
	var rn := SEABED_Y + 0.6 * smooth01(-16.3, -19.2, z + wob)
	return maxf(h, rn)


## Dune basse e ondulazioni della retrospiaggia (m, >= 0): allungate lungo la riva.
static func dunes(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 7
		_noise.frequency = 1.0
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var big := 0.5 + 0.5 * _noise.get_noise_2d(x * 0.42, z * 0.16)
	var fine := 0.5 + 0.5 * _noise.get_noise_2d(x * 1.3 + 40.0, z * 0.9)
	return 0.075 * big * big + 0.018 * fine


## Quota della sabbia generata (prima della fusione col terreno).
static func sand_height(x: float, z: float) -> float:
	var s := x - waterline(z)
	var h := floor_height(x, z)
	return h + dunes(x, z) * smooth01(0.8, 3.0, s)


## Peso del terreno originale (0 = solo sabbia generata, 1 = solo terreno) per x e per le teste.
static func terrain_weight(x: float, z: float) -> float:
	var wx := smooth01(BLEND_X, LAND_X, x)
	var wn := smooth01(-19.2, -20.9, z)
	return maxf(wx, wn)


## Il punto è in acqua (sotto il pelo) con la linea d'acqua di waterline().
static func is_water(x: float, z: float) -> bool:
	return x < waterline(z) and z > Z_MIN and z < Z_MAX
