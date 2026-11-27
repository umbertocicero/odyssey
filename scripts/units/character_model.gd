class_name CharacterModel
extends Node3D
## Modello 3D animato di un'unità (glb dei personaggi riggati a 17 ossa).
## Va messo come nodo "Model" di un GridUnit: l'unità lo ruota verso la direzione del passo, questo
## script istanzia il glb come figlio e lo anima con un AnimationTree costruito a runtime sopra le clip
## procedurali di HumanoidAnims:
## - locomozione: riposo / camminata / corsa fusi in base alla velocità REALE misurata (non allo stato
##   "si muove"), con la velocità di riproduzione pari a velocità / passo, così i piedi non scivolano;
## - "stance" (normale, scorta di un ferito, ferito zoppo, barella) con dissolvenze lunghe;
## - azioni una tantum (attacchi, parata, colpo subito, balzo) come OneShot con dissolvenza in entrata e
##   in uscita; in movimento usano solo il busto e le braccia (le gambe continuano a camminare);
## - morte, sdraiato, rialzarsi e sdraiarsi come rami separati;
## - peso: il corpo si inclina in avanti accelerando, indietro frenando, e piega nelle curve; le svolte
##   brusche della griglia vengono ammorbidite.

## Scena glb da istanziare.
@export var model_scene: PackedScene
## Varianti del modello (per esempio Elpenore ed Euriloco): se ci sono, se ne sceglie una dal numero
## finale del nome dell'unità (SoldatoAcheo1 -> la seconda...). `variant_names` sono i nomi mostrati (HUD).
@export var model_variants: Array[PackedScene] = []
## Versioni leggere (5-8k triangoli) usate a qualità bassa e media (stesso ordine di model_variants / model_scene).
@export_file("*.gltf", "*.glb") var lod_scene_path := ""
@export var lod_variant_paths: PackedStringArray = PackedStringArray()
## Come model_variants ma per percorso (caricati solo quando servono; a qualità bassa e media si usa il file "<nome>_lod" se esiste).
@export var variant_paths: PackedStringArray = PackedStringArray()
@export var variant_names: PackedStringArray = PackedStringArray()
## Scala uniforme del modello (1 = misure native, 1 m = 1 casella).
@export_range(0.2, 3.0) var model_scale := 1.0
## Rotazione aggiuntiva attorno a Y: GridUnit e Ulisse fanno guardare il nodo Model verso -Z, ma i
## personaggi in personaggi_nuovi/ (glTF) hanno il fronte verso +Z: 180 li gira nel verso del movimento.
@export_range(-180.0, 180.0) var yaw_offset_degrees := 180.0
## Durata della dissolvenza fra un'animazione e l'altra, in secondi (cambi di stance: il doppio).
@export var blend_time := 0.18
## Nomi logici delle animazioni (riportati da current_animation()).
@export var anim_idle := &"idle"
@export var anim_walk := &"walk"
@export var anim_attack := &"attack"
@export var anim_hit := &"hit"
@export var anim_run := &"run"
@export var anim_block := &"block"
@export var anim_jump := &"jump"
## Usa le animazioni procedurali (HumanoidAnims + AnimationTree). Se falso usa quelle del glb.
@export var humanize := true
## Usa i clip Mixamo retargettati (azioni "mx_*" nel glb) per camminata, corsa e morte; il resto resta procedurale (vedi MixamoClips).
@export var mixamo_clips := true
@export var anim_death := &"death"
## Non più usato (la camminata segue sempre la velocità reale); tenuto per compatibilità.
@export var sync_walk_to_step := true
## Rapidità con cui il corpo si gira verso la nuova direzione (1/s): le svolte a 90° della griglia
## diventano curve morbide.
@export var turn_rate := 13.0

const UPPER_BODY := ["spine", "neck", "head", "upperarm.L", "forearm.L", "hand.L", "upperarm.R", "forearm.R", "hand.R"]
## Velocità di riferimento (m/s) di camminata e corsa per ogni stance: sotto la prima si cammina, sopra
## la seconda si corre, in mezzo si fondono.
const GAIT_SPEEDS := {
	&"normal": Vector2(1.3, 3.8), &"support": Vector2(1.2, 3.0), &"limp": Vector2(0.9, 2.2),
	&"limp_l": Vector2(0.9, 2.2), &"limp_r": Vector2(0.9, 2.2), &"limp_lr": Vector2(0.9, 2.2),
	&"carry_r": Vector2(1.2, 3.0), &"carry_l": Vector2(1.2, 3.0),
	&"stretcher_r": Vector2(1.2, 2.6), &"stretcher_l": Vector2(1.2, 2.6),
	&"torch": Vector2(1.3, 3.8), &"row": Vector2(1.3, 3.8), &"drag": Vector2(0.8, 2.0), &"drag_l": Vector2(0.8, 2.0), &"drag_r": Vector2(0.8, 2.0), &"dragged": Vector2(0.8, 2.0),
}
const STANCE_CLIPS := {
	&"normal": [&"idle", &"walk", &"run"], &"support": [&"support_idle", &"support_walk", &"support_run"],
	&"limp": [&"limp_idle", &"limp_walk", &"limp_run"],
	# Ferito sorretto a piedi: braccio attorno al collo di chi gli sta a sinistra (l) / destra (r) / a entrambi (lr);
	# chi lo sorregge gli cinge la vita col braccio destro (carry_r: ferito a destra) o sinistro (carry_l).
	&"limp_l": [&"limp_l_idle", &"limp_l_walk", &"limp_l_run"], &"limp_r": [&"limp_r_idle", &"limp_r_walk", &"limp_r_run"],
	&"limp_lr": [&"limp_lr_idle", &"limp_lr_walk", &"limp_lr_run"],
	&"carry_r": [&"carry_r_idle", &"carry_r_walk", &"carry_r_run"], &"carry_l": [&"carry_l_idle", &"carry_l_walk", &"carry_l_run"],
	&"stretcher_r": [&"stretcher_r_idle", &"stretcher_r_walk", &"stretcher_r_run"],
	&"stretcher_l": [&"stretcher_l_idle", &"stretcher_l_walk", &"stretcher_l_run"],
	# Trascinamento sotto le ascelle: da solo (drag) o in due (drag_l / drag_r: mano sinistra / destra),
	# all'indietro verso il ferito; il ferito trascinato (dragged). Distanze in HumanoidAnims.DRAG_*.
	&"torch": [&"torch_idle", &"torch_walk", &"torch_run"],
	# Rematore seduto sul banco: sempre lo stesso ciclo di voga, qualunque sia la velocità della barca.
	&"row": [&"row_idle", &"row_walk", &"row_run"],
	&"drag": [&"drag_idle", &"drag_walk", &"drag_walk"], &"drag_l": [&"drag_l_idle", &"drag_l_walk", &"drag_l_walk"],
	&"drag_r": [&"drag_r_idle", &"drag_r_walk", &"drag_r_walk"], &"dragged": [&"dragged_idle", &"dragged_walk", &"dragged_walk"],
}
const ACTIONS := [&"attack", &"attack2", &"attack_thrust", &"block", &"hit", &"dodge", &"helpup", &"jump", &"shoot", &"climb_0", &"climb_1", &"climb_2"]
const DEATH_CLIPS := [&"death", &"death_front", &"death_side_r", &"death_side_l"]
const DEAD_CLIPS := [&"death", &"death_front", &"death_side_r", &"death_side_l", &"lie", &"lie_dead", &"getup", &"liedown"]

var instance: Node3D
## Nome della variante scelta (vuoto se il modello è unico).
var variant_name := ""
## AnimationPlayer del glb (fermo: lo anima l'AnimationTree). Contiene ancora le clip originali.
var player: AnimationPlayer
var tree: AnimationTree
var skeleton: Skeleton3D
var unit: GridUnit
var dead := false
## Velocità orizzontale misurata e filtrata (m/s).
var speed := 0.0
var stance := &"normal"
## Insiemi di clip da calcolare (vedi HumanoidAnims.library). Si decide in _ready dal tipo di unità.
var clip_sets := PackedStringArray()

var _lib: AnimationLibrary
var _mx: AnimationLibrary
var _mx_strides := {}
var _busy_until := 0.0      # fino a quando un'azione ha la precedenza (per current_animation)
var _action := &""
var _last_health := -1
var _prev_pos := Vector3.ZERO
var _has_prev := false
var _accel := 0.0
var _vis_yaw := 0.0
var _yaw_vel := 0.0
var _lean := 0.0
var _bank := 0.0
var _guard := 0.0
var _combat_until := 0.0
var _dead_clip := &""
var _getting_up_until := 0.0
var _attack_index := 0
var _defend_cd := 0.0
var _torch_on := false
var _no_hit_until := 0.0
var _stances: Array[StringName] = []


func _ready() -> void:
	unit = get_parent() as GridUnit
	_pick_variant()
	if model_scene == null:
		return
	instance = model_scene.instantiate() as Node3D
	if instance == null:
		return
	instance.scale = Vector3.ONE * model_scale
	instance.rotation.y = deg_to_rad(yaw_offset_degrees)
	add_child(instance)
	var found := instance.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		player = found[0]
	var sk := instance.find_children("*", "Skeleton3D", true, false)
	if not sk.is_empty():
		skeleton = sk[0]
	for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if humanize and skeleton:
			mesh.mesh = HandFist.fisted(mesh.mesh, skeleton)   # mani chiuse a pugno intorno al manico
	if humanize and skeleton and skeleton.find_bone("hips") >= 0 and skeleton.find_bone("upperarm.L") >= 0:
		_build_tree()
	elif player:
		player.playback_default_blend_time = blend_time
		_play_glb(anim_idle)
	_vis_yaw = global_rotation.y
	if unit:
		# Il _ready dell'unità (che imposta health) gira dopo quello dei figli.
		_last_health = unit.max_health
		if unit.has_signal(&"vaulted"):
			unit.connect(&"vaulted", func(_a, _b): _fire(&"jump", true))
		if unit.has_signal(&"climbed"):
			unit.connect(&"climbed", func(_a, _b, h: float): _fire(HumanoidAnims.climb_clip(HumanoidAnims.climb_index(h)), true))
		unit.health_changed.connect(_on_health_changed)
		unit.died.connect(_on_died)
		if unit.has_signal(&"action_requested"):
			unit.connect(&"action_requested", _on_action)


# =====================================================================================================
# Costruzione dell'AnimationTree
# =====================================================================================================

func _gear() -> UnitGear:
	for c in get_children():
		if c is UnitGear:
			return c
	return null


func _default_sets() -> PackedStringArray:
	var s := PackedStringArray(["base"])
	if unit is AllySoldier or (unit and unit.is_in_group(&"player")):
		s.append("torch")
	if unit is WoundedSoldier:
		s.append("limp")
	elif unit is AllySoldier:
		s.append("support")
		s.append("carry")
		s.append("stretcher")
		s.append("drag")
		s.append("row")
	elif unit and unit.is_in_group(&"player"):
		s.append("support")
		s.append("carry")
	return s


func _build_tree() -> void:
	var gear := _gear()
	var right := HumanoidAnims.Hand.NONE
	var has_shield := false
	var has_bow := false
	if gear:
		right = gear.hand_kind()
		has_shield = gear.has_shield() and gear.shield_aligned
		has_bow = gear.has_bow()
	if clip_sets.is_empty():
		clip_sets = _default_sets()
	_lib = HumanoidAnims.library(skeleton, right, has_shield, has_bow, clip_sets)
	if player:
		player.stop()
		player.active = false
	tree = AnimationTree.new()
	tree.name = "HumanTree"
	skeleton.add_child(tree)
	tree.add_animation_library(&"", _lib)
	_mx = null
	_mx_strides = {}
	if mixamo_clips and player and model_scene:
		var d := MixamoClips.for_model(model_scene.resource_path, player, skeleton)
		if (d["lib"] as AnimationLibrary).get_animation_list().size() > 0:
			_mx = d["lib"]
			_mx_strides = d["strides"]
			tree.add_animation_library(&"mx", _mx)
	tree.root_node = NodePath("..")
	var bt := AnimationNodeBlendTree.new()
	var stance_tr := AnimationNodeTransition.new()
	stance_tr.xfade_time = blend_time * 2.0
	_stances.clear()
	for s: StringName in STANCE_CLIPS:
		var clips: Array = STANCE_CLIPS[s]
		if not _lib.has_animation(clips[0]) or not _lib.has_animation(clips[1]):
			continue
		_stances.append(s)
		_add_input(stance_tr, String(s))
		var idle_node := _anim_node(clips[0])
		var idle_out := StringName("idle_%s" % s)
		bt.add_node(idle_out, idle_node)
		if s == &"normal" and _lib.has_animation(&"idle_guard"):
			bt.add_node(&"idle_guard", _anim_node(&"idle_guard"))
			bt.add_node(&"guard_mix", AnimationNodeBlend2.new())
			bt.connect_node(&"guard_mix", 0, idle_out)
			bt.connect_node(&"guard_mix", 1, &"idle_guard")
			idle_out = &"guard_mix"
		var bs := AnimationNodeBlendSpace1D.new()
		bs.min_space = 0.0
		bs.max_space = 1.0
		bs.sync = true
		bs.add_blend_point(_anim_node(clips[1]), 0.0, -1, &"walk")
		bs.add_blend_point(_anim_node(clips[2] if _lib.has_animation(clips[2]) else clips[1]), 1.0, -1, &"run")
		bt.add_node(StringName("gait_%s" % s), bs)
		bt.add_node(StringName("ts_%s" % s), AnimationNodeTimeScale.new())
		bt.connect_node(StringName("ts_%s" % s), 0, StringName("gait_%s" % s))
		bt.add_node(StringName("mv_%s" % s), AnimationNodeBlend2.new())
		bt.connect_node(StringName("mv_%s" % s), 0, idle_out)
		bt.connect_node(StringName("mv_%s" % s), 1, StringName("ts_%s" % s))
	bt.add_node(&"stance", stance_tr)
	for i in _stances.size():
		bt.connect_node(&"stance", i, StringName("mv_%s" % _stances[i]))
	# Azioni: a corpo intero (da fermo) e solo busto (in movimento).
	var last := &"stance"
	for layer in [&"full", &"upper"]:
		var sel := AnimationNodeTransition.new()
		sel.xfade_time = 0.0
		var n := 0
		for a: StringName in ACTIONS:
			if _lib.has_animation(a):
				_add_input(sel, String(a))
				bt.add_node(StringName("%s_%s" % [layer, a]), _anim_node(a))
				n += 1
		bt.add_node(StringName("sel_%s" % layer), sel)
		var i := 0
		for a: StringName in ACTIONS:
			if _lib.has_animation(a):
				bt.connect_node(StringName("sel_%s" % layer), i, StringName("%s_%s" % [layer, a]))
				i += 1
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.08
		shot.fadeout_time = 0.22
		if layer == &"upper":
			shot.filter_enabled = true
			for b: String in UPPER_BODY:
				shot.set_filter_path(NodePath(".:" + b), true)
		bt.add_node(StringName("act_%s" % layer), shot)
		bt.connect_node(StringName("act_%s" % layer), 0, last)
		bt.connect_node(StringName("act_%s" % layer), 1, StringName("sel_%s" % layer))
		last = StringName("act_%s" % layer)
	# Morte e sdraiato.
	var dsel := AnimationNodeTransition.new()
	dsel.xfade_time = 0.3
	var di := 0
	for d: StringName in DEAD_CLIPS:
		if _lib.has_animation(d):
			_add_input(dsel, String(d))
			bt.add_node(StringName("dead_%s" % d), _anim_node(d))
			di += 1
	bt.add_node(&"dead_sel", dsel)
	# Velocita' della caduta regolabile (ogni caduto cade un po' diverso): ts_dead/scale.
	bt.add_node(&"ts_dead", AnimationNodeTimeScale.new())
	bt.connect_node(&"ts_dead", 0, &"dead_sel")
	var j := 0
	for d: StringName in DEAD_CLIPS:
		if _lib.has_animation(d):
			bt.connect_node(&"dead_sel", j, StringName("dead_%s" % d))
			j += 1
	var life := AnimationNodeTransition.new()
	life.xfade_time = 0.2
	_add_input(life, "alive")
	_add_input(life, "dead")
	bt.add_node(&"life", life)
	bt.connect_node(&"life", 0, last)
	bt.connect_node(&"life", 1, &"ts_dead")
	bt.connect_node(&"output", 0, &"life")
	tree.tree_root = bt
	tree.active = true
	_apply_locomotion(0.0)


## Aggiunge un ingresso con nome a una Transition (in 4.7 add_input() non crea un ingresso valido).
func _add_input(tr: AnimationNodeTransition, input_name: String) -> void:
	tr.input_count += 1
	tr.set_input_name(tr.input_count - 1, input_name)


func _anim_node(anim: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = StringName("mx/" + String(anim)) if _mx != null and _mx.has_animation(anim) else anim
	return n


## Passo per ciclo dell'andatura (m): quello della clip Mixamo se c'e', altrimenti della procedurale.
func _stride(anim: StringName) -> float:
	return float(_mx_strides[anim]) if _mx_strides.has(anim) and _mx != null and _mx.has_animation(anim) else HumanoidAnims.stride(anim)


func _tp(param: String, value: Variant) -> void:
	tree.set("parameters/" + param, value)


## Esegue subito una transizione (senza dissolvenza): per lo stato iniziale.
func _snap(node_name: StringName, state: StringName) -> void:
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node(node_name) as AnimationNodeTransition
	var old := node.xfade_time
	node.xfade_time = 0.0
	_tp("%s/transition_request" % node_name, String(state))
	tree.advance(0.0)
	node.xfade_time = old


# =====================================================================================================
# Ogni fotogramma: velocità, inclinazione, svolte, parametri del tree
# =====================================================================================================

func _process(delta: float) -> void:
	if instance == null or delta <= 0.0:
		return
	_watch_torch()
	_measure(delta)
	if tree == null:
		_glb_process()
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not dead and _getting_up_until > 0.0 and now >= _getting_up_until:
		_getting_up_until = 0.0
		_tp("life/transition_request", "alive")
	_apply_locomotion(delta)
	_apply_body(delta)


func _measure(delta: float) -> void:
	var p := global_position
	if not _has_prev:
		_prev_pos = p
		_has_prev = true
	var d := Vector2(p.x - _prev_pos.x, p.z - _prev_pos.z)
	_prev_pos = p
	var v := d.length() / delta
	if d.length() > 1.5:
		v = speed           # teletrasporto (place_at): non è velocità
	var old := speed
	speed = lerpf(speed, v, 1.0 - exp(-delta * 7.0))
	if speed < 0.02:
		speed = 0.0
	_accel = lerpf(_accel, (speed - old) / delta, 1.0 - exp(-delta * 6.0))


func _apply_locomotion(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var refs: Vector2 = GAIT_SPEEDS.get(stance, Vector2(1.3, 3.8))
	var moving := smoothstep(0.12, 0.55, speed)
	for s in _stances:
		var clips: Array = STANCE_CLIPS[s]
		var r: Vector2 = GAIT_SPEEDS.get(s, refs)
		var b := clampf((speed - r.x) / (r.y - r.x), 0.0, 1.0)
		var st := lerpf(_stride(clips[1]), _stride(clips[2]), b)
		_tp("gait_%s/blend_position" % s, b)
		if s == &"row":
			# Seduto sul banco: la velocità della barca non c'entra, il ritmo è fisso e non si cammina mai.
			_tp("ts_row/scale", 1.0)
			_tp("mv_row/blend_amount", 0.0)
			continue
		# Sotto la velocità minima si rallenta la cadenza ma non sotto un terzo (passi corti, non moviola).
		_tp("ts_%s/scale" % s, maxf(speed, 0.45) / st)
		_tp("mv_%s/blend_amount" % s, moving)
	if _stances.has(&"normal"):
		var want := 1.0 if now < _combat_until else 0.0
		_guard = move_toward(_guard, want, delta * (3.0 if want > _guard else 0.8))
		_tp("guard_mix/blend_amount", smoothstep(0.0, 1.0, _guard))


func _apply_body(delta: float) -> void:
	# Svolte morbide: il modello visibile insegue la direzione del nodo Model.
	var target := global_rotation.y
	var prev := _vis_yaw
	_vis_yaw = lerp_angle(_vis_yaw, target, 1.0 - exp(-delta * turn_rate))
	var yaw_rate := wrapf(_vis_yaw - prev, -PI, PI) / delta
	_yaw_vel = lerpf(_yaw_vel, yaw_rate, 1.0 - exp(-delta * 8.0))
	var rel := wrapf(_vis_yaw - target, -PI, PI)
	if dead:
		rel = 0.0
		_vis_yaw = target
	# Peso: in avanti accelerando, indietro frenando; piega verso l'interno della curva.
	var want_lean := clampf(_accel * 0.022, -0.1, 0.12) if not dead else 0.0
	var want_bank := clampf(-_yaw_vel * speed * 0.012, -0.12, 0.12) if not dead else 0.0
	_lean = lerpf(_lean, want_lean, 1.0 - exp(-delta * 6.0))
	_bank = lerpf(_bank, want_bank, 1.0 - exp(-delta * 6.0))
	var yaw := deg_to_rad(yaw_offset_degrees) + rel
	instance.basis = (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _lean) * Basis(Vector3.BACK, _bank)).scaled(Vector3.ONE * model_scale)


# =====================================================================================================
# API usata dalle unità
# =====================================================================================================

## Cambia stance (normal, support, limp, stretcher_r, stretcher_l) con una dissolvenza.
func set_stance(s: StringName, instant := false) -> void:
	stance = s
	# Col braccio destro attorno al ferito la spada resta nel fodero.
	var gear := _gear()
	if gear and gear.weapon_node:
		gear.weapon_node.visible = not (s == &"carry_r" or s == &"row" or _torch_on)
	if tree == null or not _stances.has(s):
		return
	if instant:
		_snap(&"stance", s)
	else:
		_tp("stance/transition_request", String(s))


## Torcia accesa in mano (di notte): la spada resta nel fodero e il braccio destro regge la torcia
## dritta. Va chiamato con `true` quando la torcia compare e con `false` quando sparisce.
func set_torch(on: bool) -> void:
	var gear := _gear()
	if gear and gear.weapon_node:
		gear.weapon_node.visible = not on and stance != &"carry_r"
	if tree == null or not _stances.has(&"torch"):
		return
	if on and stance == &"normal":
		set_stance(&"torch")
	elif not on and stance == &"torch":
		set_stance(&"normal")


## Controlla se NightCycle ha acceso la torcia in mano (nodo "TorciaInMano" visibile sullo scheletro).
func _watch_torch() -> void:
	if skeleton == null:
		return
	var node := skeleton.get_node_or_null(^"TorciaInMano") as Node3D
	var on := node != null and node.visible
	if on != _torch_on:
		_torch_on = on
		set_torch(on)


## Esegue l'attacco (alterna fendente, taglio e affondo).
func play_attack() -> void:
	# Un colpo alla volta: richieste ravvicinate (tasto tenuto, IA) non ricominciano il fendente a metà.
	var now := Time.get_ticks_msec() / 1000.0
	if tree != null and _action in [&"attack", &"attack2", &"attack_thrust"] and now < _busy_until - 0.28:
		return
	var seq := [&"attack", &"attack_thrust", &"attack2"]
	var a: StringName = seq[_attack_index % seq.size()]
	_attack_index += 1
	if tree == null:
		_one_shot_glb(anim_attack)
		return
	_fire(a)


## Si china a dare la mano a un ferito a terra e lo tira su (lunghezza: anim_length(&"helpup")).
func play_help_up() -> void:
	_fire(&"helpup", true)


## Avvia la morte e resta sull'ultimo fotogramma finché non si chiama revive().
## `variant`: clip di caduta (DEATH_CLIPS; vuoto = all'indietro), `speed`: velocita' della caduta.
func play_death(variant := &"", speed_scale := 1.0) -> void:
	if tree == null:
		dead = true
		_busy_until = 0.0
		_play_glb(anim_death, true)
		return
	var lying := dead and (_dead_clip == &"lie" or _dead_clip == &"liedown")
	dead = true
	_busy_until = 0.0
	_action = &""
	_getting_up_until = 0.0
	if lying and _lib.has_animation(&"lie_dead"):
		_dead_clip = &"lie_dead"
	else:
		_dead_clip = variant if DEATH_CLIPS.has(variant) and _lib.has_animation(variant) else anim_death
	# la morte Mixamo dura 2-3,5 s (la procedurale ~1,2): leggermente accelerata
	var mx_death := _mx != null and _mx.has_animation(&"death") and _dead_clip == anim_death
	_tp("ts_dead/scale", speed_scale * (1.35 if mx_death else 1.0))
	_tp("dead_sel/transition_request", String(_dead_clip))
	_tp("life/transition_request", "dead")


## Durata della caduta in corso (secondi, alla velocita' impostata).
func death_duration() -> float:
	return anim_length(_dead_clip) / maxf(float(tree.get("parameters/ts_dead/scale")), 0.1) if tree else 1.0


## Verso (mondo, orizzontale) in cui punta la testa del caduto.
func death_head_world() -> Vector3:
	var d := instance.global_basis.orthonormalized() * HumanoidAnims.death_head_dir(_dead_clip)
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.BACK


## Sdraiato a terra, vivo (ferito). `instant`: senza animazione (inizio del livello).
func play_lying(instant := false) -> void:
	if tree == null or not _lib.has_animation(&"lie"):
		play_death()
		return
	var was_standing := not dead
	dead = true
	_action = &""
	_getting_up_until = 0.0
	if instant or not was_standing or not _lib.has_animation(&"liedown"):
		_dead_clip = &"lie"
		if instant:
			_snap(&"dead_sel", &"lie")
			_snap(&"life", &"dead")
		else:
			_tp("dead_sel/transition_request", "lie")
			_tp("life/transition_request", "dead")
		return
	_dead_clip = &"liedown"
	_snap(&"dead_sel", &"liedown")
	_tp("life/transition_request", "dead")
	var t := _lib.get_animation(&"liedown").length
	get_tree().create_timer(t).timeout.connect(func() -> void:
		if dead and _dead_clip == &"liedown":
			_dead_clip = &"lie"
			_tp("dead_sel/transition_request", "lie"))


## Rialza il modello (Ulisse riappare all'accampamento; il ferito si tira su).
func revive() -> void:
	if tree == null:
		dead = false
		_play_glb(anim_idle, true)
		return
	var from_lying := _dead_clip == &"lie" or _dead_clip == &"liedown"
	dead = false
	_action = &""
	if from_lying and _lib.has_animation(&"getup"):
		_dead_clip = &"getup"
		_tp("dead_sel/transition_request", "getup")
		_getting_up_until = Time.get_ticks_msec() / 1000.0 + _lib.get_animation(&"getup").length - 0.15
		return
	_dead_clip = &""
	_snap(&"life", &"alive")


## Lunghezza di un'animazione in secondi (0 se manca).
func anim_length(anim: StringName) -> float:
	if _mx != null and _mx.has_animation(anim):
		return _mx.get_animation(anim).length
	if _lib and _lib.has_animation(anim):
		return _lib.get_animation(anim).length
	if player and player.has_animation(anim):
		return player.get_animation(anim).length
	return 0.0


## Nome logico dell'animazione in corso: azione, morte/sdraiato, oppure idle / walk / run.
func current_animation() -> StringName:
	if tree == null:
		return player.current_animation if player else &""
	if dead:
		return anim_death if DEATH_CLIPS.has(_dead_clip) or _dead_clip == &"lie_dead" else _dead_clip
	if _getting_up_until > 0.0:
		return &"getup"
	var now := Time.get_ticks_msec() / 1000.0
	if _action != &"" and now < _busy_until:
		return _action
	if speed > 0.25 or (unit != null and unit.is_moving):
		var refs: Vector2 = GAIT_SPEEDS.get(stance, Vector2(1.3, 3.8))
		return anim_run if speed > (refs.x + refs.y) * 0.5 else anim_walk
	return anim_idle


## Esegue un'azione una tantum. `full`: anche le gambe (balzo); altrimenti in movimento solo il busto.
func _fire(a: StringName, full := false) -> void:
	if tree == null:
		_one_shot_glb(a)
		return
	if dead or not _lib.has_animation(a):
		return
	var layer := &"full" if full or speed < 0.6 else &"upper"
	var other := &"upper" if layer == &"full" else &"full"
	var shot := (tree.tree_root as AnimationNodeBlendTree).get_node(StringName("act_%s" % layer)) as AnimationNodeOneShot
	shot.fadein_time = 0.04 if a == &"hit" else (0.06 if a == &"jump" else 0.09)
	shot.fadeout_time = 0.25 if a != &"hit" else 0.2
	_tp("act_%s/request" % other, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_tp("sel_%s/transition_request" % layer, String(a))
	_tp("act_%s/request" % layer, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_action = a
	_busy_until = Time.get_ticks_msec() / 1000.0 + _lib.get_animation(a).length
	if a != &"jump" and not String(a).begins_with("climb"):
		_combat_until = Time.get_ticks_msec() / 1000.0 + 3.5


## Colpo in arrivo da `from` (corpo a corpo): para con lo scudo o la lancia, schiva, oppure lo
## incassa. Restituisce il danno che passa davvero (parata: metà, schivata: niente). Non si difende
## chi sta già affondando un colpo, chi è a terra o chi si è appena difeso.
func defend(amount: int, from: Vector3) -> int:
	var now := Time.get_ticks_msec() / 1000.0
	if tree == null or dead or String(stance).begins_with("limp") or stance == &"dragged" or now < _defend_cd:
		return amount
	if _action in [&"attack", &"attack2", &"attack_thrust"] and now < _busy_until - 0.3:
		return amount
	var gear := _gear()
	var guard := gear != null and (gear.has_shield() or gear.hand_kind() == HumanoidAnims.Hand.SPEAR)
	var roll := randf()
	if guard and roll < 0.5:
		_fire(&"block")
		_defend_cd = now + 0.9
		_no_hit_until = now + 0.35
		return amount / 2
	if roll < (0.75 if guard else 0.4) and speed < 0.6:
		_fire(&"dodge", true)
		_defend_cd = now + 1.2
		_no_hit_until = now + 0.35
		return 0
	return amount


## Istante (s dall'inizio del colpo) in cui la lama arriva a bersaglio, uguale per tutti gli attacchi
## (chiavi "hit" delle clip a 0,21-0,23 s).
const IMPACT_TIME := 0.22
## Anticipo con cui la parata o la schivata devono partire rispetto al colpo: la clip arriva in guardia a 0,12 s.
const DEFENSE_LEAD := 0.12


## Secondi che mancano all'impatto del colpo in corso (IMPACT_TIME se è appena partito).
func attack_impact_remaining() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	if _action in [&"attack", &"attack2", &"attack_thrust"] and _lib != null and _lib.has_animation(_action):
		var elapsed := _lib.get_animation(_action).length - (_busy_until - now)
		return maxf(IMPACT_TIME - elapsed, 0.02)
	return IMPACT_TIME


## Decide in anticipo come reagirà a un colpo in arrivo: &"hit" (lo incassa), &"block" (para con
## lama o scudo) o &"dodge" (schiva). Stessa logica e stesse probabilità di defend().
func plan_defense() -> StringName:
	var now := Time.get_ticks_msec() / 1000.0
	if tree == null or dead or String(stance).begins_with("limp") or stance == &"dragged" or now < _defend_cd:
		return &"hit"
	if _action in [&"attack", &"attack2", &"attack_thrust"] and now < _busy_until - 0.3:
		return &"hit"
	var gear := _gear()
	var guard := gear != null and (gear.has_shield() or gear.hand_kind() == HumanoidAnims.Hand.SPEAR)
	var roll := randf()
	if guard and roll < 0.5:
		_defend_cd = now + 1.1
		return &"block"
	if roll < (0.75 if guard else 0.4) and speed < 0.6:
		_defend_cd = now + 1.3
		return &"dodge"
	return &"hit"


## Fa partire la parata o la schivata pianificata dopo `delay` s, così è in guardia quando arriva la lama.
func start_defense(kind: StringName, delay: float) -> void:
	_no_hit_until = Time.get_ticks_msec() / 1000.0 + delay + 0.4
	var fire := func() -> void:
		if dead or tree == null:
			return
		_fire(&"block" if kind == &"block" else &"dodge", kind == &"dodge")
	if delay <= 0.01:
		fire.call()
	else:
		get_tree().create_timer(delay).timeout.connect(fire)


## Punto del mondo dove la lama (o lo scudo) incontra il colpo: l'arma impugnata, o lo scudo se c'è.
func guard_point(prefer_shield: bool) -> Vector3:
	var gear := _gear()
	if gear != null:
		if prefer_shield and gear.shield_node != null:
			return gear.shield_node.global_position
		if gear.weapon_node != null:
			return gear.weapon_node.global_position
		if gear.shield_node != null:
			return gear.shield_node.global_position
	return global_position + Vector3.UP * 1.1


## Vero se il modello para con uno scudo (suono e scintille diversi dalla lama contro lama).
func has_shield() -> bool:
	var gear := _gear()
	return gear != null and gear.has_shield()


## Pone la testa del bersaglio in guardia verso `world_pos` (i due si fronteggiano al momento dell'impatto).
func face_toward(world_pos: Vector3) -> void:
	if unit == null:
		return
	var to := world_pos - unit.global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	var yaw := atan2(-to.x, -to.z)
	var from := global_rotation.y
	create_tween().tween_method(func(f: float) -> void: global_rotation.y = lerp_angle(from, yaw, f), 0.0, 1.0, 0.1)


func _on_health_changed(current: int, _maximum: int) -> void:
	var parried := Time.get_ticks_msec() / 1000.0 < _no_hit_until
	if current < _last_health and current > 0 and not parried:
		if tree == null:
			_one_shot_glb(anim_hit)
		elif not dead:
			_fire(&"hit")
	_last_health = current


func _on_died() -> void:
	play_death()


func _on_action(action: StringName) -> void:
	if action == &"attack":
		play_attack()
	elif action == &"parry":
		_fire(&"block")
	elif action == &"dodge":
		_fire(&"dodge")


# =====================================================================================================
# Ripiego: animazioni del glb (humanize = false)
# =====================================================================================================

func _glb_process() -> void:
	if player == null or dead or unit == null:
		return
	if Time.get_ticks_msec() / 1000.0 < _busy_until:
		return
	_play_glb(anim_walk if speed > 0.3 else anim_idle)


func _one_shot_glb(anim: StringName) -> void:
	if player == null or dead or not player.has_animation(anim):
		return
	_play_glb(anim, true)
	_busy_until = Time.get_ticks_msec() / 1000.0 + player.get_animation(anim).length


func _play_glb(anim: StringName, restart := false) -> void:
	if player == null or not player.has_animation(anim):
		return
	if player.current_animation == anim and player.is_playing() and not restart:
		return
	player.play(anim)


func _pick_variant() -> void:
	if model_variants.is_empty() and variant_paths.is_empty():
		return
	var digits := ""
	var n := String(unit.name if unit else name)
	for i in range(n.length() - 1, -1, -1):
		if n[i].is_valid_int():
			digits = n[i] + digits
		else:
			break
	var count := model_variants.size() if not model_variants.is_empty() else variant_paths.size()
	var index := (int(digits) if digits != "" else 0) % count
	if model_variants.is_empty():
		var path := variant_paths[index]
		model_scene = load(path) as PackedScene
		variant_name = variant_names[index] if index < variant_names.size() else ""
		return
	model_scene = model_variants[index]
	variant_name = variant_names[index] if index < variant_names.size() else ""
