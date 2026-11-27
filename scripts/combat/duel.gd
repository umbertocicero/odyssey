class_name Duel
extends Node
## Duello 1 contro 1 in prima persona tra Ulisse e un troiano.
##
## Quando Ulisse e un soldato troiano si battono, la camera passa dalla terza persona alla prima in
## rallentatore (il tempo scende a ~14% mentre la camera "entra" nella testa di Ulisse e il campo
## visivo si allarga), poi il tempo torna normale e il combattimento diventa uno scambio di colpi:
##  - ogni colpo ha una DIREZIONE (alto, sinistra, destra, basso): si sceglie tenendo premuto
##    W/A/S/D (o stick) mentre si attacca o si para;
##  - il troiano annuncia il proprio colpo (la freccia della direzione lampeggia, la lama si carica):
##    parare nella STESSA direzione è una parata perfetta (stordisce il nemico, che resta scoperto),
##    parare in un'altra direzione blocca solo in parte, schivare (spazio) evita tutto ma costa fiato;
##  - il nemico si guarda a sua volta in una direzione (indicata in alto): colpirlo da lì viene
##    parato, colpirlo da un'altra direzione lo ferisce; ferito durante la carica perde l'attacco;
##  - ogni azione consuma STAMINA; a zero si è esausti e senza difese. Anche il nemico si stanca,
##    e a stamina zero la guardia gli si spezza;
##  - i colpi a segno lasciano ferite sul corpo e sangue a particelle (DuelFx); quelli subiti
##    sporcano l'obiettivo.
## Le braccia di Ulisse (spada e scudo) si vedono in basso e si muovono con IK procedurale (DuelArms):
## fendenti con carica e accompagnamento, parate nella direzione scelta, sussulti. Ogni colpo porta il
## corpo in avanti (affondo); colpi a segno e parate hanno un istante di "hit-stop" che dà peso all'urto.
## Gli altri alleati e nemici restano in terza persona e continuano a combattere; nessuno si intromette
## nel duello. Alla fine la camera torna indietro con la stessa transizione: la camera scende (o risale)
## lungo una curva che passa dietro le spalle di Ulisse, con il tempo che rallenta e riprende piano.

## Direzione di un colpo (stessa enum di DuelFx.Aim).
enum Aim { HIGH, LEFT, RIGHT, LOW }
enum Phase { INTRO, FIGHT, KILL, OUTRO }
enum FoeState { IDLE, WINDUP, RECOVER, STAGGER }

const AIM_NAMES := ["HIGH", "LEFT", "RIGHT", "LOW"]

const INTRO_TIME := 1.7           ## secondi reali della transizione 3a -> 1a persona
const OUTRO_TIME := 1.35
const KILL_HOLD := 1.0            ## secondi reali di rallentatore dopo l'ultimo colpo
const SLOW_SCALE := 0.14
const FP_FOV := 64.0
const EYE_HEIGHT := 1.62
## L'occhio sta appena davanti al volto (la testa è nascosta): le braccia si vedono dal basso.
const EYE_FORWARD := 0.09
const DUEL_DISTANCE := 1.6         ## distanza tra i duellanti (m): con l'affondo la lama arriva al corpo
const LUNGE := 0.24                ## quanto il corpo avanza in un fendente (m)
const WINDUP_TIME := 0.64         ## dal segnale del nemico all'impatto: la finestra per reagire
const ANIM_IMPACT := 0.22         ## la lama arriva a bersaglio 0,22 s dopo l'inizio della clip
const PARRY_WINDOW := 0.45        ## una parata vale se è premuta fino a questo tempo prima dell'impatto
const DODGE_START := 0.05
const DODGE_END := 0.46
const COST_ATTACK := 16.0
const COST_PARRY := 8.0
const COST_DODGE := 22.0
const MAX_STAMINA := 100.0

## Duello in corso (uno solo alla volta).
static var active: Duel

static var _next_allowed_ms := 0
## Spento, i combattimenti restano quelli in terza persona (le demo registrate lo spengono).
static var enabled := true

var player: GridUnit
var foe: GridUnit
var phase := Phase.INTRO

# Stato esposto all'HUD.
var player_stamina := MAX_STAMINA
var foe_stamina := MAX_STAMINA
var player_exhausted := false
var foe_state := FoeState.IDLE
var foe_aim := Aim.HIGH           ## direzione del colpo in arrivo
var guard_aim := Aim.HIGH         ## direzione in cui il nemico si copre
var windup_progress := 0.0        ## 0..1: avvicinamento all'impatto
var player_aim := -1              ## direzione scelta dal giocatore (-1 = nessuna)
var fight_time := 0.0
var slash_flash := 0.0            ## lampo del colpo appena sferrato (HUD)
var slash_aim := 0

var _game_cam: Camera3D
var _cam: Camera3D
var _hud: DuelHud
var _layer: CanvasLayer
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _key_light: OmniLight3D
var _pm: CharacterModel
var _fm: CharacterModel
var _pipeline_mat: ShaderMaterial
var _prev_blur := 3.0
var _ui_layers: Array[CanvasLayer] = []
var _grass_saved: Array = []      ## [nodo, valori originali] dell'erba sfoltita durante il duello

var _real_clock := 0.0
var _phase_t := 0.0
var _start_xform := Transform3D.IDENTITY
var _start_fov := 28.0
var _last_fp := Transform3D.IDENTITY
var _victory := false
var _cleaned := false
var _head_idx := -1

var _foe_t := 0.0                 ## tempo nello stato corrente
var _atk_cd := 1.0
var _guard_cd := 1.2
var _windup_anim := false
var _player_cd := 0.0
var _parry_cd := 0.0
var _dodge_cd := 0.0
var _parry_time := -9.0
var _parry_aim := -1
var _dodge_time := -9.0
var _last_aim := Aim.HIGH
var _last_aim_time := -9.0
var _stamina_idle := 0.0
var _pending: Array[Dictionary] = []
var _splats: Array[Vector4] = []
var _hurt := 0.0
var _cam_off := Vector3.ZERO      ## spostamento della testa (schivata), nel sistema della camera
var _cam_off_target := Vector3.ZERO
var _kick := Vector2.ZERO         ## contraccolpo della camera (yaw, pitch)
var _shake := 0.0
var _roll := 0.0
var _fwd := Vector3.FORWARD
var _foe_dmg_mult := 1.0
var _eye_h := EYE_HEIGHT
var _look_h := 1.38
var _foe_rest := Vector3.ZERO
var _foe_moved := false
var _recover_time := 0.55         ## durata dello stato RECOVER corrente
var _aim_changed_at := -9.0       ## quando il giocatore ha cambiato direzione l'ultima volta
var _arms: DuelArms
var _lunge := 0.0                 ## avanzamento attuale del corpo nell'affondo (m)
var _lunge_t := -1.0              ## tempo dall'inizio dell'affondo (-1 = fermo)
var _inst_rest := Vector3.ZERO    ## posizione a riposo del modello di Ulisse (l'affondo lo sposta)
var _hitstop := 0.0               ## secondi reali di tempo quasi fermo dopo un urto
var _look_a := Vector3.ZERO       ## punto guardato dalla camera da diorama (inizio/fine transizione)
var _attack_aim_age := 0.0        ## da quanto era tenuta la direzione del colpo in corso


## Avvia un duello se possibile. `player` è Ulisse, `foe` un troiano. Restituisce true se è partito.
static func try_begin(player_unit: GridUnit, foe_unit: GridUnit) -> bool:
	if not enabled or active != null or Time.get_ticks_msec() < _next_allowed_ms:
		return false
	if player_unit == null or foe_unit == null or not player_unit.is_inside_tree() or not foe_unit.is_inside_tree():
		return false
	if player_unit.health <= 0 or foe_unit.health <= 0:
		return false
	# Ulisse che sorregge un ferito non può battersi in duello.
	if float(player_unit.get(&"speed_multiplier")) < 0.99 or bool(player_unit.get(&"is_defeated")):
		return false
	if player_unit.global_position.distance_to(foe_unit.global_position) > 2.9:
		return false
	var viewport := player_unit.get_viewport()
	if viewport == null or viewport.get_camera_3d() == null:
		return false
	var duel := Duel.new()
	duel.name = "Duello"
	duel.player = player_unit
	duel.foe = foe_unit
	viewport.add_child(duel)
	active = duel
	duel._start()
	return true


## Vero se `attacker` non può colpire `victim` perché uno dei due duellanti è coinvolto: il duello è
## uno contro uno, gli altri non si intromettono (né su Ulisse né sul suo avversario).
static func blocks_attack(victim: Node, attacker: Node) -> bool:
	if active == null or active.phase == Phase.OUTRO:
		return false
	if victim == active.player:
		return attacker != active.foe
	if victim == active.foe:
		return attacker != active.player
	return false


func _start() -> void:
	var vp := player.get_viewport()
	_game_cam = vp.get_camera_3d()
	_pm = player.get_node_or_null(^"Model") as CharacterModel
	_fm = foe.get_node_or_null(^"Model") as CharacterModel
	_start_xform = _game_cam.global_transform
	_start_fov = _game_cam.fov
	_cam = Camera3D.new()
	_cam.name = "CameraDuello"
	_cam.near = 0.02
	_cam.far = 140.0
	_cam.fov = _start_fov
	vp.add_child(_cam)
	_cam.global_transform = _start_xform
	_cam.make_current()
	# Ulisse e il nemico si fermano e si fronteggiano.
	player.set(&"in_duel", true)
	player.is_moving = false
	foe.is_moving = false
	if foe.has_method(&"halt"):
		foe.call(&"halt")
	if foe.get(&"target") != null or foe.has_method(&"halt"):
		foe.set(&"target", player)
	_face_each_other(0.0)
	_show_unit_bars(false)
	if _pm and _pm.skeleton:
		_head_idx = _pm.skeleton.find_bone("head")
		if _head_idx >= 0:
			var hy := _pm.skeleton.to_global(_pm.skeleton.get_bone_global_pose(_head_idx).origin).y - player.global_position.y
			_eye_h = clampf(hy + 0.06, 1.3, 2.0)
	if _fm and _fm.skeleton:
		var neck := _fm.skeleton.find_bone("neck")
		if neck >= 0:
			var ny := _fm.skeleton.to_global(_fm.skeleton.get_bone_global_pose(neck).origin).y - foe.global_position.y
			_look_h = clampf(ny - 0.12, 1.0, 1.8)
	# Il nemico arretra quanto basta per vederlo bene (posizione solo visiva: la casella non cambia).
	_foe_rest = foe.global_position
	var gap := foe.global_position - player.global_position
	gap.y = 0.0
	if gap.length() < DUEL_DISTANCE - 0.05 and gap.length() > 0.01:
		var dest := player.global_position + gap.normalized() * DUEL_DISTANCE
		dest.y = foe.global_position.y
		foe.create_tween().set_ignore_time_scale(true).tween_property(foe, "global_position", dest, 0.9).set_trans(Tween.TRANS_SINE)
		_foe_moved = true
	# Braccia in prima persona.
	if _pm and _pm.skeleton:
		_arms = DuelArms.new()
		_arms.name = "BracciaDuello"
		_arms.influence = 0.0
		_pm.skeleton.add_child(_arms)
		_arms.calibrate(_pm._gear())
		_inst_rest = _pm.instance.position if _pm.instance else Vector3.ZERO
	_look_a = _start_xform.origin - _start_xform.basis.z.normalized() * _start_xform.origin.distance_to(player.global_position)
	_foe_dmg_mult = 1.5
	# Luce calda sul nemico (rimbalzo del tramonto), poco costosa: niente ombre.
	_key_light = OmniLight3D.new()
	_key_light.light_color = Color(1.0, 0.82, 0.58)
	_key_light.light_energy = 0.0
	_key_light.omni_range = 6.0
	_key_light.shadow_enabled = false
	vp.add_child(_key_light)
	# Interfaccia e gradazione a tutto schermo (nella finestra principale, sopra il mondo 3D).
	_layer = CanvasLayer.new()
	_layer.layer = 70
	get_tree().root.add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = load("res://assets/shaders/duel_screen.gdshader") as Shader
	_overlay.material = _overlay_mat
	_layer.add_child(_overlay)
	_hud = DuelHud.new()
	_hud.duel = self
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_hud)
	_set_splat_uniforms()
	_overlay_mat.set_shader_parameter(&"strength", 0.0)
	# Niente sfocatura da miniatura (tilt-shift): in prima persona l'immagine deve essere nitida.
	for n in get_tree().root.get_children():
		if n is RenderPipeline:
			_pipeline_mat = (n as RenderPipeline).post_process_material as ShaderMaterial
			# L'interfaccia del livello si nasconde: resta solo quella del duello.
			var ui := n.get_node_or_null(^"UI") as CanvasLayer
			if ui == null and n.get_parent():
				ui = n.get_parent().get_node_or_null(^"UI") as CanvasLayer
			if ui != null and ui.visible:
				ui.visible = false
				_ui_layers.append(ui)
	if _pipeline_mat:
		var v: Variant = _pipeline_mat.get_shader_parameter(&"blur_amount")
		_prev_blur = float(v) if v != null else 3.0
	_thin_grass(true)
	DuelFx.prepare()
	Engine.time_scale = 1.0


## Le barre della vita sopra le teste (ingombranti in prima persona: per i duellanti c'è l'HUD).
func _show_unit_bars(on: bool) -> void:
	for n in get_tree().get_nodes_in_group(&"units"):
		var u := n as GridUnit
		if u and is_instance_valid(u._health_bar):
			u._health_bar.suppressed = not on


## In prima persona la camera è a terra e guarda lontano: si vede molto più mondo che dalla camera da
## diorama. Per non perdere troppi FPS, durante il duello il LOD dei ciuffi d'erba si stringe, i fili
## d'erba si sfoltiscono e le ombre del sole si limitano ai metri attorno ai duellanti (dove si guarda).
func _thin_grass(on: bool) -> void:
	if not on:
		for entry in _grass_saved:
			var node: Node = entry[0]
			if not is_instance_valid(node):
				continue
			if node is GrassCards:
				var g := node as GrassCards
				g.lod_start = entry[1][0]
				g.lod_end = entry[1][1]
				g.lod_keep = entry[1][2]
				g._apply_parameters()
			elif node is GrassField:
				var mm := (node as GrassField).multimesh_instance.multimesh if (node as GrassField).multimesh_instance else null
				if mm:
					mm.visible_instance_count = entry[1]
			elif node is DirectionalLight3D:
				(node as DirectionalLight3D).directional_shadow_max_distance = entry[1]
		_grass_saved.clear()
		return
	for node in get_tree().root.find_children("*", "", true, false):
		if node is GrassCards:
			var g := node as GrassCards
			_grass_saved.append([g, [g.lod_start, g.lod_end, g.lod_keep]])
			g.lod_start = 3.0
			g.lod_end = 14.0
			g.lod_keep = 0.18
			g._apply_parameters()
		elif node is GrassField and (node as GrassField).multimesh_instance:
			var mm := (node as GrassField).multimesh_instance.multimesh
			if mm:
				_grass_saved.append([node, mm.visible_instance_count])
				mm.visible_instance_count = int(mm.instance_count * 0.4)
		elif node is DirectionalLight3D and (node as DirectionalLight3D).shadow_enabled:
			var sun := node as DirectionalLight3D
			_grass_saved.append([sun, sun.directional_shadow_max_distance])
			sun.directional_shadow_max_distance = minf(sun.directional_shadow_max_distance, 12.0)


func _exit_tree() -> void:
	# Il duello può sparire con il livello (ricominciato, chiuso): si rimette tutto a posto lo stesso.
	_cleanup()


# =====================================================================================================
# Ciclo
# =====================================================================================================

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(foe) or not is_instance_valid(_game_cam):
		_cleanup()
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.01)
	_real_clock += real_dt
	_phase_t += real_dt
	if phase == Phase.FIGHT:
		# Hit-stop: il tempo quasi si ferma per un istante all'urto, poi riparte.
		if _hitstop > 0.0:
			_hitstop -= real_dt
			Engine.time_scale = 0.04 if _hitstop > 0.0 else 1.0
	match phase:
		Phase.INTRO:
			_intro()
		Phase.FIGHT:
			_fight(delta)
		Phase.KILL:
			_kill()
		Phase.OUTRO:
			_outro()
	_update_effects(delta)


func _intro() -> void:
	var p := clampf(_phase_t / INTRO_TIME, 0.0, 1.0)
	var e := _smoother(p)
	# Tempo: rallenta dolcemente all'inizio, resta lento durante il volo, riprende piano alla fine.
	var slow := smoothstep(0.0, 0.22, p) * (1.0 - smoothstep(0.8, 1.0, p))
	Engine.time_scale = lerpf(1.0, SLOW_SCALE, slow)
	_face_each_other(0.0)
	var fp := _fp_transform(0.0)
	_cam.global_transform = _swoop(_start_xform.origin, _look_a, fp, e, false)
	_cam.fov = _fov_mix(_start_fov, FP_FOV, smoothstep(0.15, 1.0, p))
	_set_effect_strength(smoothstep(0.3, 1.0, p))
	if _arms:
		_arms.influence = smoothstep(0.45, 0.9, p)
	_hide_head(_cam.global_position.distance_to(fp.origin) < 0.5)
	if p >= 1.0:
		Engine.time_scale = 1.0
		phase = Phase.FIGHT
		_phase_t = 0.0
		_hud.popup("EN GARDE!", Color(1.0, 0.86, 0.5))


func _fight(dt: float) -> void:
	fight_time += dt
	_face_each_other(dt)
	_tick_player(dt)
	_tick_foe(dt)
	_tick_pending(dt)
	if foe.health <= 0:
		_begin_kill(true)
	elif player.health <= 0:
		_begin_kill(false)


func _begin_kill(victory: bool) -> void:
	_victory = victory
	phase = Phase.KILL
	_phase_t = 0.0
	_hud.popup("VICTORY" if victory else "DEFEATED", Color(1.0, 0.86, 0.5) if victory else Color(0.9, 0.2, 0.15))


func _kill() -> void:
	Engine.time_scale = lerpf(SLOW_SCALE * 1.3, 0.35, clampf(_phase_t / KILL_HOLD, 0.0, 1.0))
	var real_dt := get_process_delta_time() / maxf(Engine.time_scale, 0.01)
	if _victory:
		# Lo sguardo segue il nemico che cade.
		_look_h = lerpf(_look_h, 0.45, minf(1.0, real_dt * 2.2))
	else:
		# Ulisse cade: la vista crolla verso terra (il suo corpo si nasconde, la camera ci finirebbe dentro).
		if _pm:
			_pm.visible = false
		_cam_off_target = Vector3(0.0, -1.15, -0.25)
		_roll = lerpf(_roll, 0.45, minf(1.0, real_dt * 2.0))
	if _phase_t >= KILL_HOLD:
		phase = Phase.OUTRO
		_phase_t = 0.0
		_last_fp = _cam.global_transform


func _outro() -> void:
	var p := clampf(_phase_t / OUTRO_TIME, 0.0, 1.0)
	var e := _smoother(p)
	Engine.time_scale = lerpf(0.35, 1.0, smoothstep(0.0, 0.75, p))
	var gx := _game_cam.global_transform
	var look_b := gx.origin - gx.basis.z.normalized() * gx.origin.distance_to(player.global_position)
	_cam.global_transform = _swoop(gx.origin, look_b, _last_fp, 1.0 - e, true)
	_cam.fov = _fov_mix(_game_cam.fov, FP_FOV, 1.0 - smoothstep(0.0, 0.85, p))
	_set_effect_strength(1.0 - smoothstep(0.0, 0.7, p))
	if _arms:
		_arms.influence = 1.0 - smoothstep(0.0, 0.45, p)
	_hide_head(_cam.global_position.distance_to(_last_fp.origin) < 0.5 and _victory)
	if p > 0.4 and _pm and not _pm.visible:
		_pm.visible = true   # la camera è ormai uscita dal corpo: Ulisse a terra torna visibile
	if p >= 1.0:
		_cleanup()


## Curva della transizione tra la camera da diorama (`far_pos`, che guarda `far_look`) e l'occhio
## (`eye`), con `t` = 0 lontano e 1 sull'occhio: la camera passa alta dietro Ulisse, poi sopra la sua
## spalla, e intanto lo sguardo scivola dal punto del diorama al petto del nemico. Niente rollio.
func _swoop(far_pos: Vector3, far_look: Vector3, eye: Transform3D, t: float, _back: bool) -> Transform3D:
	var right := _fwd.cross(Vector3.UP).normalized()
	var base := player.global_position
	var p1 := base - _fwd * 3.2 + Vector3.UP * 4.2 + right * 0.6
	var p2 := base - _fwd * 1.1 + Vector3.UP * (_eye_h + 0.32) + right * 0.42
	var pos := _bezier(far_pos, p1.lerp(far_pos, 0.25), p2, eye.origin, t)
	var near_look := eye.origin - eye.basis.z.normalized() * 2.0
	var look := far_look.lerp(near_look, _smoother(clampf(t * 1.2, 0.0, 1.0)))
	var dir := look - pos
	if dir.length() < 0.01:
		return eye
	var b := Basis.looking_at(dir.normalized(), Vector3.UP)
	# Negli ultimi istanti la camera si allinea esattamente all'occhio (respiro e contraccolpi compresi).
	var w := smoothstep(0.85, 1.0, t)
	if w > 0.0:
		b = Basis(Quaternion(b.orthonormalized()).slerp(Quaternion(eye.basis.orthonormalized()), w))
	return Transform3D(b, pos)


static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


static func _smoother(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## Interpola il campo visivo sulla tangente: lo zoom appare uniforme.
static func _fov_mix(a: float, b: float, t: float) -> float:
	var ta := tan(deg_to_rad(a) * 0.5)
	var tb := tan(deg_to_rad(b) * 0.5)
	return rad_to_deg(2.0 * atan(lerpf(ta, tb, clampf(t, 0.0, 1.0))))


## Fine del duello: tutto torna come prima.
func _cleanup() -> void:
	if _cleaned:
		return
	_cleaned = true
	Engine.time_scale = 1.0
	_hide_head(false)
	if is_instance_valid(_arms):
		_arms.queue_free()
	if is_instance_valid(_pm) and is_instance_valid(_pm.instance):
		_pm.instance.position = _inst_rest
	if is_instance_valid(_pm):
		_pm.visible = true
	_thin_grass(false)
	_show_unit_bars(true)
	if is_instance_valid(_game_cam) and _game_cam.is_inside_tree():
		_game_cam.make_current()
	if is_instance_valid(_cam):
		_cam.queue_free()
	if is_instance_valid(_key_light):
		_key_light.queue_free()
	if is_instance_valid(_layer):
		_layer.queue_free()
	if _pipeline_mat:
		_pipeline_mat.set_shader_parameter(&"blur_amount", _prev_blur)
	for ui in _ui_layers:
		if is_instance_valid(ui):
			ui.visible = true
	_ui_layers.clear()
	if is_instance_valid(player):
		player.set(&"in_duel", false)
	if is_instance_valid(foe) and foe.is_inside_tree() and foe.health > 0:
		if _foe_moved:
			foe.create_tween().set_ignore_time_scale(true).tween_property(foe, "global_position", _foe_rest, 0.35)
		if foe.has_method(&"resume"):
			foe.call(&"resume")
	_next_allowed_ms = Time.get_ticks_msec() + 4000
	if active == self:
		active = null
	if is_inside_tree() and not is_queued_for_deletion():
		queue_free()


# =====================================================================================================
# Camera
# =====================================================================================================

func _horizontal_to_foe() -> Vector3:
	var to := foe.global_position - player.global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else _fwd


## Occhio di Ulisse senza tremolii: poco davanti al volto, spostato dalla schivata e dall'affondo, rivolto
## al petto del nemico. Le braccia (DuelArms) sono posate in questo sistema.
func _eye_frame() -> Transform3D:
	_fwd = _horizontal_to_foe()
	var right := _fwd.cross(Vector3.UP).normalized()
	var eye := player.global_position + Vector3.UP * (_eye_h + _cam_off.y) + _fwd * (EYE_FORWARD + _cam_off.z + _lunge) + right * _cam_off.x
	# Il nemico si guarda al petto: si vede il busto (dove restano le ferite) e il volto in alto.
	var target := foe.global_position + Vector3.UP * _look_h
	return Transform3D(Basis.looking_at((target - eye).normalized(), Vector3.UP), eye)


## La camera: l'occhio con respiro, contraccolpi, rollio e tremito.
func _fp_transform(_dt: float) -> Transform3D:
	var f := _eye_frame()
	var t := _real_clock
	var sway := Vector3(sin(t * 0.9) * 0.005, sin(t * 1.7) * 0.008 + sin(t * 0.5) * 0.004, 0.0)
	var eye := f.origin + f.basis * sway
	var basis := f.basis
	basis = basis.rotated(Vector3.UP, _kick.x)
	basis = basis * Basis(Vector3.RIGHT, _kick.y)
	basis = basis * Basis(Vector3.BACK, _roll + sin(t * 1.3) * 0.004)
	if _shake > 0.001:
		eye += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.04
	return Transform3D(basis, eye)


## I due si guardano: la testa del troiano e il corpo di Ulisse ruotano uno verso l'altro.
func _face_each_other(dt: float) -> void:
	var to := foe.global_position - player.global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	var yaw := atan2(-to.x, -to.z)
	if _pm:
		_pm.rotation.y = lerp_angle(_pm.rotation.y, yaw, 1.0 if dt <= 0.0 else minf(1.0, 12.0 * dt))
	player.set(&"_face_yaw", yaw)
	if _fm:
		var fyaw := atan2(to.x, to.z)
		_fm.rotation.y = lerp_angle(_fm.rotation.y, fyaw, 1.0 if dt <= 0.0 else minf(1.0, 12.0 * dt))


## Nasconde la testa di Ulisse (la camera sta dentro): scala dell'osso a quasi zero.
func _hide_head(on: bool) -> void:
	if _head_idx < 0 or not is_instance_valid(_pm) or not is_instance_valid(_pm.skeleton):
		return
	_pm.skeleton.set_bone_pose_scale(_head_idx, Vector3.ONE * (0.001 if on else 1.0))


func _update_effects(dt: float) -> void:
	# Spostamento della testa, contraccolpo e tremito tornano a zero.
	_cam_off = _cam_off.lerp(_cam_off_target, minf(1.0, 11.0 * dt))
	_cam_off_target = _cam_off_target.lerp(Vector3.ZERO, minf(1.0, 3.5 * dt))
	_kick = _kick.lerp(Vector2.ZERO, minf(1.0, 9.0 * dt))
	_shake = maxf(_shake - dt * 4.0, 0.0)
	_roll = lerpf(_roll, 0.0, minf(1.0, 6.0 * dt))
	_hurt = maxf(_hurt - dt * 1.4, 0.0)
	slash_flash = maxf(slash_flash - dt * 6.0, 0.0)
	_update_lunge(dt)
	if _arms:
		_arms.frame = _eye_frame()
		_arms.exhausted = player_exhausted
	if phase == Phase.FIGHT or phase == Phase.KILL:
		var fp := _fp_transform(dt)
		_cam.global_transform = fp
		_cam.fov = FP_FOV + (0.0 if windup_progress <= 0.0 else windup_progress * 2.5)
	# Splat: età e scadenza.
	for i in _splats.size():
		var s := _splats[i]
		if s.w >= 0.0:
			s.w += dt
			if s.w > 7.0:
				s.w = -1.0
			_splats[i] = s
	_set_splat_uniforms()
	_overlay_mat.set_shader_parameter(&"hurt", _hurt)
	var low := clampf(1.0 - float(player.health) / float(maxi(player.max_health, 1)) * 2.4, 0.0, 1.0)
	_overlay_mat.set_shader_parameter(&"low_health", low)
	_key_light.global_position = foe.global_position + Vector3.UP * 1.6 + _fwd * -0.6 + _fwd.cross(Vector3.UP) * 0.9
	_key_light.light_energy = lerpf(_key_light.light_energy, 1.6 if phase != Phase.OUTRO else 0.0, minf(1.0, 3.0 * dt))


## Affondo: il corpo avanza durante il fendente (massimo all'impatto) e torna indietro. Si sposta il
## modello di Ulisse insieme all'occhio (anche nella schivata), così le spalle seguono e la lama arriva
## al nemico.
func _update_lunge(dt: float) -> void:
	if _lunge_t < 0.0:
		_lunge = move_toward(_lunge, 0.0, dt * 0.8)
	else:
		_lunge_t += dt
		var t := _lunge_t
		_lunge = LUNGE * (smoothstep(0.04, ANIM_IMPACT, t) - smoothstep(0.3, 0.62, t))
		if t > 0.62:
			_lunge_t = -1.0
	if _pm and _pm.instance and phase != Phase.OUTRO:
		# Il corpo segue l'occhio: affondo e schivata (così le spalle restano sotto la camera).
		var right := _fwd.cross(Vector3.UP).normalized()
		var off := _pm.to_local(_pm.global_position + _fwd * (_lunge + _cam_off.z) + right * _cam_off.x)
		_pm.instance.position = _inst_rest + Vector3(off.x, 0.0, off.z)
	elif _pm and _pm.instance:
		_pm.instance.position = _pm.instance.position.lerp(_inst_rest, minf(1.0, dt * 6.0))


func _hit_stop(seconds: float) -> void:
	if phase == Phase.FIGHT:
		_hitstop = maxf(_hitstop, seconds)


func _set_effect_strength(e: float) -> void:
	_overlay_mat.set_shader_parameter(&"strength", e)
	_hud.alpha = clampf((e - 0.5) * 2.0, 0.0, 1.0)
	if _pipeline_mat:
		_pipeline_mat.set_shader_parameter(&"blur_amount", lerpf(_prev_blur, 0.0, e))


func _set_splat_uniforms() -> void:
	var arr := PackedVector4Array()
	for i in 6:
		arr.append(_splats[i] if i < _splats.size() else Vector4(0, 0, 0, -1))
	_overlay_mat.set_shader_parameter(&"splats", arr)


func _add_screen_blood(heavy: bool) -> void:
	var s := Vector4(randf_range(0.18, 0.82), randf_range(0.15, 0.6), randf_range(0.045, 0.085) * (1.4 if heavy else 1.0), 0.0)
	for i in _splats.size():
		if _splats[i].w < 0.0:
			_splats[i] = s
			return
	if _splats.size() < 6:
		_splats.append(s)
	else:
		_splats[0] = s


# =====================================================================================================
# Giocatore
# =====================================================================================================

func _read_aim() -> int:
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if v.length() > 0.4:
		var a: int
		if absf(v.x) >= absf(v.y):
			a = Aim.RIGHT if v.x > 0.0 else Aim.LEFT
		else:
			a = Aim.HIGH if v.y < 0.0 else Aim.LOW
		if a != _last_aim:
			_aim_changed_at = fight_time
		_last_aim = a as Aim
		_last_aim_time = fight_time
		return a
	if fight_time - _last_aim_time < 0.3:
		return _last_aim
	return -1


func _tick_player(dt: float) -> void:
	_player_cd -= dt
	_parry_cd -= dt
	_dodge_cd -= dt
	player_aim = _read_aim()
	_stamina_idle += dt
	if _stamina_idle > 0.7:
		player_stamina = minf(player_stamina + dt * 24.0, MAX_STAMINA)
	if player_exhausted and player_stamina >= 28.0:
		player_exhausted = false
	if Input.is_action_just_pressed(&"attack"):
		_player_attack()
	if Input.is_action_just_pressed(&"parry"):
		_player_parry()
	if Input.is_action_just_pressed(&"dodge"):
		_player_dodge()


func _spend(amount: float) -> void:
	player_stamina = maxf(player_stamina - amount, 0.0)
	_stamina_idle = 0.0
	if player_stamina <= 0.0 and not player_exhausted:
		player_exhausted = true
		_hud.popup("EXHAUSTED", Color(0.95, 0.55, 0.2))


func _can_act(cost: float) -> bool:
	if player_exhausted:
		_hud.popup("TOO TIRED", Color(0.95, 0.55, 0.2))
		return false
	return player_stamina >= minf(cost, 10.0)


## Fa partire l'animazione di attacco con la direzione giusta (alto = fendente, basso = affondo,
## lati = taglio).
func _play_attack_anim(m: CharacterModel, aim: int) -> void:
	if m == null:
		return
	m._attack_index = [0, 2, 2, 1][aim]
	m.play_attack()


func _player_attack() -> void:
	if _player_cd > 0.0 or not _can_act(COST_ATTACK):
		return
	var aim := player_aim if player_aim >= 0 else int(Aim.HIGH)
	_player_cd = 0.72
	_spend(COST_ATTACK)
	if _arms:
		_arms.play_attack(aim)
	_lunge_t = 0.0
	GameAudio.swing(player, player.global_position + Vector3.UP)
	slash_flash = 1.0
	slash_aim = aim
	_kick += Vector2([0.0, 0.03, -0.03, 0.0][aim], [-0.025, 0.0, 0.0, 0.01][aim])
	# Una direzione tenuta a lungo è leggibile: il nemico può accorgersene e coprirsi.
	_attack_aim_age = fight_time - _aim_changed_at if player_aim >= 0 else 1.0
	_pending.append({"t": ANIM_IMPACT, "aim": aim})


func _player_parry() -> void:
	if _parry_cd > 0.0 or not _can_act(COST_PARRY):
		return
	_parry_cd = 0.4
	_parry_time = fight_time
	_parry_aim = player_aim
	_spend(COST_PARRY)
	if _arms:
		_arms.play_parry(_parry_aim)
	# La testa si abbassa un poco dietro la lama.
	_cam_off_target += Vector3(0, -0.03, 0.04)


func _player_dodge() -> void:
	if _dodge_cd > 0.0 or not _can_act(COST_DODGE):
		return
	_dodge_cd = 0.7
	_dodge_time = fight_time
	_spend(COST_DODGE)
	# Direzione della schivata: a lato, indietro (nessuna direzione o alto) o accucciato (basso).
	var o := Vector3(0.0, 0.0, -0.45)
	match player_aim:
		Aim.LEFT:
			o = Vector3(-0.55, 0.0, 0.0)
			_roll = 0.1
		Aim.RIGHT:
			o = Vector3(0.55, 0.0, 0.0)
			_roll = -0.1
		Aim.LOW:
			o = Vector3(0.0, -0.4, 0.05)
	_cam_off_target = o
	_cam_off = o * 0.3


func _tick_pending(dt: float) -> void:
	var rest: Array[Dictionary] = []
	for e in _pending:
		e["t"] = float(e["t"]) - dt
		if float(e["t"]) <= 0.0:
			_resolve_player_strike(int(e["aim"]))
		else:
			rest.append(e)
	_pending = rest


## Esito del colpo di Ulisse all'istante di impatto.
func _resolve_player_strike(aim: int) -> void:
	if foe.health <= 0 or phase != Phase.FIGHT:
		return
	var contact := foe.global_position + Vector3.UP * 1.3
	var can_guard := foe_state == FoeState.IDLE and foe_stamina >= 10.0
	if can_guard and guard_aim != aim and _attack_aim_age > 0.45 and randf() < 0.55:
		guard_aim = aim as Aim   # ha letto il colpo annunciato e sposta la guardia
	var flank_guard := can_guard and guard_aim == aim
	if flank_guard:
		# Il nemico para: lama contro lama.
		ClashFx.sparks(player, contact, -_fwd + Vector3.UP * 0.4)
		GameAudio.clash(player, contact)
		foe_stamina = maxf(foe_stamina - 15.0, 0.0)
		_spend(6.0)
		_hud.popup("BLOCKED", Color(0.7, 0.8, 0.95))
		_atk_cd = minf(_atk_cd, 0.35)   # contrattacca presto
		if _fm:
			_fm._fire(&"block")
		_kick += Vector2(0.0, 0.012)
		_shake = maxf(_shake, 0.4)
		_lunge_t = maxf(_lunge_t, 0.3)   # la lama rimbalza: l'affondo si ritrae subito
		if _arms:
			_arms.jolt(0.8)
		_hit_stop(0.05)
		_check_foe_exhausted()
		return
	var mult := 1.0
	var crit := false
	if foe_state == FoeState.STAGGER:
		mult = 1.7
		crit = true
	var dmg := int(round(float((player.get(&"attack_damage") as int)) * 0.5 * mult))
	var dir := _horizontal_to_foe()
	# L'attacco del nemico viene interrotto se la sua clip non è ancora partita.
	if foe_state == FoeState.WINDUP and not _windup_anim:
		_enter_foe_state(FoeState.RECOVER)
		_recover_time = 0.6
		_hud.popup("INTERRUPTED", Color(1.0, 0.86, 0.5))
	elif foe_state == FoeState.IDLE:
		# Ferito, il nemico non resta inerme: risponde presto (niente colpi a catena senza rischi).
		_atk_cd = minf(_atk_cd, randf_range(0.25, 0.6))
	if crit:
		_hud.popup("CRITICAL!", Color(1.0, 0.45, 0.2))
	_hit_foe(dmg, aim, dir)


func _hit_foe(dmg: int, aim: int, dir: Vector3) -> void:
	var lethal := foe.health <= dmg
	_hit_stop(0.09 if lethal else 0.06)
	var pos := foe.global_position + Vector3.UP * (1.45 if aim == Aim.HIGH else (0.95 if aim == Aim.LOW else 1.2))
	var right := _cam.global_basis.x
	var up := _cam.global_basis.y
	# Verso in cui corre la lama (sul piano dello schermo).
	var blade := [-up, right, -right, up][aim] as Vector3
	if lethal:
		GameAudio.slash_kill(player, pos)
	else:
		GameAudio.hit(player, pos)
	foe.take_damage(dmg, dir, false)
	DuelFx.add_wound(foe, aim, _cam)
	var toward := (_cam.global_position - pos).normalized()
	DuelFx.spray(player, pos, toward * 0.8 + blade * 0.5 + Vector3.UP * 0.25, lethal)
	ClashFx.stain(player, foe.global_position + dir * randf_range(0.3, 0.9), randf_range(0.18, 0.34) * (1.4 if lethal else 1.0), 0.0, false)
	if foe_state == FoeState.IDLE or foe_state == FoeState.RECOVER:
		_enter_foe_state(FoeState.RECOVER)
		_recover_time = 0.3   # sussulto breve
	foe._shove(dir)
	_kick += Vector2(randf_range(-0.012, 0.012), 0.02)
	_shake = maxf(_shake, 0.5 if lethal else 0.3)


# =====================================================================================================
# Nemico
# =====================================================================================================

func _enter_foe_state(s: FoeState) -> void:
	foe_state = s
	_foe_t = 0.0
	_recover_time = 0.55
	_windup_anim = false
	windup_progress = 0.0


func _tick_foe(dt: float) -> void:
	_foe_t += dt
	if foe_state == FoeState.IDLE or foe_state == FoeState.RECOVER:
		foe_stamina = minf(foe_stamina + dt * (14.0 if foe_state == FoeState.IDLE else 7.0), MAX_STAMINA)
	match foe_state:
		FoeState.IDLE:
			_guard_cd -= dt
			if _guard_cd <= 0.0:
				guard_aim = [Aim.HIGH, Aim.LEFT, Aim.RIGHT, Aim.LOW][randi() % 4]
				_guard_cd = randf_range(1.0, 2.0)
			_atk_cd -= dt
			if _atk_cd <= 0.0 and foe_stamina >= 20.0 and player.health > 0:
				_foe_windup()
		FoeState.WINDUP:
			windup_progress = clampf(_foe_t / WINDUP_TIME, 0.0, 1.0)
			if not _windup_anim and _foe_t >= WINDUP_TIME - ANIM_IMPACT:
				_windup_anim = true
				_play_attack_anim(_fm, foe_aim)
				GameAudio.swing(foe, foe.global_position + Vector3.UP)
			if _foe_t >= WINDUP_TIME:
				_foe_impact()
		FoeState.RECOVER:
			if _foe_t >= _recover_time:
				var quick := _recover_time < 0.5
				_enter_foe_state(FoeState.IDLE)
				_atk_cd = randf_range(0.2, 0.5) if quick else randf_range(0.5, 1.2)
		FoeState.STAGGER:
			if _foe_t >= 1.15:
				_enter_foe_state(FoeState.IDLE)
				_atk_cd = randf_range(0.7, 1.2)


func _foe_windup() -> void:
	# Non ripete sempre la stessa direzione.
	var previous := foe_aim
	foe_aim = [Aim.HIGH, Aim.LEFT, Aim.RIGHT, Aim.LOW][randi() % 4]
	if foe_aim == previous and randf() < 0.5:
		foe_aim = [Aim.HIGH, Aim.LEFT, Aim.RIGHT, Aim.LOW][randi() % 4]
	_enter_foe_state(FoeState.WINDUP)
	# Si carica indietro (segnale del colpo in arrivo), poi affonda verso Ulisse all'impatto e torna in guardia.
	if _fm and _fm.instance:
		var body := _fm.instance
		var rest := body.position
		var away := _horizontal_to_foe()
		var back := _fm.to_local(_fm.global_position + away * 0.18)
		var lunge := _fm.to_local(_fm.global_position - away * 0.3)
		var t := body.create_tween()
		t.tween_property(body, "position", rest + Vector3(back.x, 0.0, back.z), WINDUP_TIME * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(body, "position", rest + Vector3(lunge.x, 0.0, lunge.z), WINDUP_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(body, "position", rest, 0.4).set_trans(Tween.TRANS_SINE)


func _foe_impact() -> void:
	foe_stamina = maxf(foe_stamina - 20.0, 0.0)
	_enter_foe_state(FoeState.RECOVER)
	var dir := -_horizontal_to_foe()
	var pos := player.global_position + Vector3.UP * 1.3
	var impact_time := fight_time
	var dmg := int(round(float((foe.get(&"attack_damage") as int)) * _foe_dmg_mult))
	# Schivata: i fotogrammi di invulnerabilità coprono l'impatto.
	var since_dodge := impact_time - _dodge_time
	if since_dodge >= DODGE_START and since_dodge <= DODGE_END:
		_hud.popup("DODGED!", Color(0.6, 0.95, 0.7))
		foe_stamina = maxf(foe_stamina - 6.0, 0.0)
		_atk_cd = 1.0
		_foe_t = 0.2   # resta scoperto un po' più a lungo
		_check_foe_exhausted()
		return
	var since_parry := impact_time - _parry_time
	if since_parry >= 0.0 and since_parry <= PARRY_WINDOW:
		var contact := (_fm.guard_point(false) if _fm else pos) * 0.5 + pos * 0.5
		ClashFx.sparks(player, contact, dir + Vector3.UP * 0.4)
		GameAudio.clash(player, contact)
		if _parry_aim == foe_aim:
			# Parata perfetta: il nemico è sbilanciato e scoperto.
			_hud.popup("PERFECT PARRY!", Color(1.0, 0.9, 0.45))
			_hit_stop(0.1)
			if _arms:
				_arms.jolt(0.6)
			_enter_foe_state(FoeState.STAGGER)
			foe_stamina = maxf(foe_stamina - 18.0, 0.0)
			_kick += Vector2(0.0, 0.03)
			_shake = maxf(_shake, 0.6)
			_check_foe_exhausted()
			return
		_hud.popup("BLOCKED", Color(0.7, 0.8, 0.95))
		_hit_stop(0.05)
		if _arms:
			_arms.jolt(1.1)
		_spend(14.0)
		_shake = maxf(_shake, 0.5)
		_kick += Vector2(randf_range(-0.02, 0.02), 0.025)
		_damage_player(int(round(dmg * 0.35)), dir, false)
		return
	_damage_player(dmg, dir, true)


## Il troiano non ha più fiato: la guardia gli si spezza.
func _check_foe_exhausted() -> void:
	if foe_stamina <= 0.0 and foe_state != FoeState.STAGGER and foe.health > 0:
		_enter_foe_state(FoeState.STAGGER)
		foe_stamina = 35.0
		_hud.popup("GUARD BROKEN!", Color(1.0, 0.7, 0.3))


func _damage_player(dmg: int, dir: Vector3, bleed: bool) -> void:
	if dmg <= 0:
		return
	GameAudio.hit(foe, player.global_position + Vector3.UP)
	player.take_damage(dmg, dir, false)
	_hit_stop(0.05)
	if _arms:
		_arms.jolt(1.4 if bleed else 0.9)
	_hurt = 1.0 if bleed else 0.5
	if bleed:
		_add_screen_blood(player.health <= 0)
		_kick += Vector2(randf_range(-0.05, 0.05), 0.07)
		_roll += randf_range(-0.07, 0.07)
		_shake = maxf(_shake, 1.0)
		_cam_off_target += Vector3(0, 0, -0.18)
