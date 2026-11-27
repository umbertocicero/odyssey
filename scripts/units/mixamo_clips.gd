class_name MixamoClips
extends RefCounted
## Clip Mixamo retargettati sulle 17 ossa del gioco: le azioni "mx_*" dentro i glb di personaggi_nuovi
## (generate da assets/models/custom/_source/scripts/build_char_mixamo.py, che trasferisce le rotazioni globali delle ossa Mixamo
## sulle ossa del gioco e toglie il moto in avanti dai cicli di andatura).
##
## Sostituiscono nell'AnimationTree le clip procedurali di andatura (walk, run) e di morte (death) dello stance normale; tutto il resto
## (idle, attacchi guidati dall'arma, parate, trasporto feriti, remo, duello in prima persona) resta procedurale, perche' dipende
## dall'arma e dallo scudo agganciati alle ossa. Le clip sono per modello (cache per percorso), non condivise: le proporzioni differiscono.

## Clip del gioco che si lasciano sostituire dalle Mixamo.
const OVERRIDES := [&"walk", &"run", &"death"]

static var _cache := {}


## {"lib": AnimationLibrary, "strides": {walk: m/ciclo, run: m/ciclo}} per il modello di `key` (vuoto se il glb non ha clip mx_*).
static func for_model(key: String, player: AnimationPlayer, skeleton: Skeleton3D) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var lib := AnimationLibrary.new()
	var strides := {}
	if player != null and skeleton != null:
		for n in player.get_animation_list():
			var s := String(n)
			var target := &""
			if s.begins_with("mx_walk"):
				target = &"walk"
			elif s.begins_with("mx_run"):
				target = &"run"
			elif s == "mx_death_0":
				target = &"death"
			if target == &"" or lib.has_animation(target):
				continue
			var a := _retarget(player.get_animation(n), skeleton)
			var loop := target == &"walk" or target == &"run"
			a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			lib.add_animation(target, a)
			if loop:
				var i := s.find("_v")
				if i >= 0:
					strides[target] = s.substr(i + 2).replace("p", ".").to_float() * a.length
	var out := {"lib": lib, "strides": strides}
	_cache[key] = out
	return out


## Copia la clip con i soli canali di rotazione e posizione, sul percorso ".:osso" (radice dell'AnimationTree = scheletro).
static func _retarget(src: Animation, skeleton: Skeleton3D) -> Animation:
	var a := Animation.new()
	a.length = src.length
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var path := String(src.track_get_path(t))
		var bone := path.substr(path.rfind(":") + 1)
		if skeleton.find_bone(bone) < 0:
			continue
		var nt := a.add_track(type)
		a.track_set_path(nt, NodePath(".:" + bone))
		a.track_set_interpolation_type(nt, Animation.INTERPOLATION_LINEAR)
		for k in src.track_get_key_count(t):
			if type == Animation.TYPE_ROTATION_3D:
				a.rotation_track_insert_key(nt, src.track_get_key_time(t, k), src.track_get_key_value(t, k))
			else:
				a.position_track_insert_key(nt, src.track_get_key_time(t, k), src.track_get_key_value(t, k))
	return a
