extends Node
## Demo dei 15 personaggi di personaggi_nuovi: scheletro a 17 ossa con skinning Mixamo e clip Mixamo retargettati (camminata, corsa, morte).
## Tutti in fila con il nome sopra la testa; un giro automatico di azioni (idle, camminata, corsa, attacco, parata, morte, rialzarsi)
## che si puo' fermare e guidare a mano. Testi a schermo in inglese.
##
## Avvio:   scenes/demo/run_demo_characters.sh      oppure      godot --path . res://scenes/demo/demo_characters.tscn
## Tasti:   1..7 azione (idle, walk, run, attack, block, death, get up)   Space giro automatico on/off
##          Left/Right personaggio in primo piano   Esc / L tutti in fila   mouse: trascina = ruota, rotella = zoom
##          M clip Mixamo <-> procedurali (confronto)   G armi e scudi on/off   H aiuto   Q esci
## Argomenti (dopo "--"): --focus=<nome> (parte in primo piano, es. menelao), --noauto, --procedural, --nogear,
##                        --once (esce a fine giro), --shots=DIR (salva un PNG a meta' di ogni azione).

const PATH := "res://assets/models/custom/personaggi_nuovi/%s/%s.gltf"
const SHIELD := "res://assets/models/custom/campo/equipaggiamento/hoplon_tridente/hoplon_tridente.gltf"
const SWORD := "res://assets/models/custom/armi/xiphos/xiphos.gltf"
const SPEAR := "res://assets/models/custom/armi/lancia/lancia.gltf"
const BOW := "res://assets/models/custom/armi/arco/arco.gltf"

## [cartella, nome a schermo, equipaggiamento]: sword_shield, sword, spear, bow, none (Agamennone ha lo scudo nella mesh)
const CAST := [
	["ulisse", "Ulysses", "sword_shield"], ["menelao", "Menelaus", "sword_shield"], ["agamennone", "Agamemnon", "sword_shield"],
	["elpenore", "Elpenor", "sword_shield"], ["euriloco", "Eurylochus", "sword_shield"], ["euribate", "Eurybates", "sword_shield"],
	["polite", "Polites", "sword_shield"], ["filotete", "Philoctetes", "sword"], ["filotete_no_elmo", "Philoctetes (bareheaded)", "sword"],
	["perimede", "Perimedes", "sword_shield"], ["troiano_fanteria", "Trojan Infantry", "spear"], ["troiano_capitano", "Trojan Captain", "sword_shield"],
	["troiano_1", "Deiphobus A", "spear"], ["troiano_2", "Deiphobus B", "spear"], ["troiano_arciere", "Trojan Archer (Pandarus)", "bow"],
]
## [nome, durata s]: il giro automatico
const PHASES := [["Idle", 4.0], ["Walk", 7.0], ["Run", 3.2], ["Attack", 5.0], ["Block", 3.5], ["Death", 5.5], ["Get up", 2.0]]
const WALK_SPEED := 1.3
const RUN_SPEED := 3.8

var _chars: Array = []          # {mover, model, label, base}
var _cam: Camera3D
var _hud: Label
var _help: Label
var _auto := true
var _phase := 0
var _phase_t := 0.0
var _phase_fired := false
var _mixamo := true
var _gear := true
var _focus := -1                # -1 = tutti in fila
var _orbit := Vector2(0.0, 0.18)    # yaw, pitch (focus)
var _zoom := 3.2
var _line_t := 0.0
var _arg_once := false
var _arg_shots := ""
var _shot_done := {}
var _cycles := 0
var _start_phase := 0
var _focus_y := 1.0
var _burst := 0
var _burst_n := 0
var _burst_t := 0.0
var _quit_at := -1.0


func _ready() -> void:
	var focus_name := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--focus="): focus_name = a.substr(8)
		elif a == "--noauto": _auto = false
		elif a == "--procedural": _mixamo = false
		elif a == "--nogear": _gear = false
		elif a == "--once": _arg_once = true
		elif a.begins_with("--shots="): _arg_shots = a.substr(8)
		elif a.begins_with("--zoom="): _zoom = float(a.substr(7))
		elif a.begins_with("--burst="): _burst = int(a.substr(8))
		elif a.begins_with("--ty="): _focus_y = float(a.substr(5))
		elif a.begins_with("--yaw="): _orbit.x = deg_to_rad(float(a.substr(6)))
		elif a.begins_with("--phase="): _start_phase = int(a.substr(8))
	if _arg_shots != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_arg_shots) if _arg_shots.begins_with("res://") else _arg_shots)
	_build_stage()
	_spawn()
	for i in CAST.size():
		if CAST[i][0] == focus_name:
			_focus = i
	_set_phase(_start_phase)


# ------------------------------------------------------------------ scena
func _build_stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.28, 0.36, 0.55)
	sm.sky_horizon_color = Color(0.95, 0.62, 0.38)
	sm.ground_horizon_color = Color(0.62, 0.42, 0.3)
	sm.ground_bottom_color = Color(0.3, 0.22, 0.16)
	sm.sun_angle_max = 25.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -35, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.7, 0.75, 0.9)
	add_child(fill)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color(0.36, 0.29, 0.21))
	for i in 128:
		for k in [0, 1, 64, 65]:
			img.set_pixel(i, k, Color(0.25, 0.2, 0.14))
			img.set_pixel(k, i, Color(0.25, 0.2, 0.14))
	gm.albedo_texture = ImageTexture.create_from_image(img)
	gm.uv1_scale = Vector3(60, 60, 1)       # una cella ogni 2 m: serve a vedere se i piedi scivolano
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground.material_override = gm
	add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	add_child(_cam)
	_cam.current = true
	var ui := CanvasLayer.new()
	add_child(ui)
	_hud = Label.new()
	_hud.position = Vector2(24, 18)
	_hud.add_theme_font_size_override("font_size", 30)
	_hud.add_theme_color_override("font_color", Color(1, 0.93, 0.78))
	_hud.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	_hud.add_theme_constant_override("outline_size", 8)
	ui.add_child(_hud)
	_help = Label.new()
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 24
	_help.offset_top = -92
	_help.add_theme_font_size_override("font_size", 20)
	_help.add_theme_color_override("font_color", Color(1, 0.93, 0.78))
	_help.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	_help.add_theme_constant_override("outline_size", 6)
	_help.text = "1-7 action  |  Space auto tour  |  Left/Right focus character, Esc line-up  |  drag = orbit, wheel = zoom\nM Mixamo clips / procedural  |  G weapons & shields  |  H hide help  |  Q quit"
	ui.add_child(_help)


func _spawn() -> void:
	for c in _chars:
		(c["mover"] as Node3D).queue_free()
	_chars.clear()
	var n := CAST.size()
	var per_row := 5
	for i in n:
		var row := i / per_row
		var k := i % per_row
		var x := (k - (per_row - 1) * 0.5) * 2.0 + (1.0 if row == 1 else 0.0) * 0.0
		var mover := Node3D.new()
		mover.position = Vector3(x, 0, row * 2.3)
		add_child(mover)
		var cm := CharacterModel.new()
		cm.mixamo_clips = _mixamo
		cm.model_scene = load(PATH % [CAST[i][0], CAST[i][0]])
		if _gear:
			_add_gear(cm, CAST[i][2])
		mover.add_child(cm)
		var label := Label3D.new()
		label.text = CAST[i][1]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = false
		label.pixel_size = 0.0028
		label.font_size = 40
		label.outline_size = 14
		label.modulate = Color(1, 0.93, 0.78)
		label.outline_modulate = Color(0.1, 0.06, 0.03)
		label.position = Vector3(0, 1.85, 0)
		mover.add_child(label)
		_chars.append({"mover": mover, "model": cm, "label": label, "base": mover.position})
	_apply_phase_start()


func _add_gear(cm: CharacterModel, kind: String) -> void:
	var gear := UnitGear.new()
	gear.min_quality = 0
	match kind:
		"sword_shield":
			gear.shield = load(SHIELD)
			gear.weapon_path = SWORD
		"sword":
			gear.weapon_path = SWORD
		"spear":
			gear.weapon_path = SPEAR
			gear.weapon_kind = UnitGear.WeaponKind.SPEAR
		"bow":
			gear.weapon_path = BOW
			gear.weapon_kind = UnitGear.WeaponKind.BOW
	cm.add_child(gear)


# ------------------------------------------------------------------ giro delle azioni
func _set_phase(i: int) -> void:
	_phase = i % PHASES.size()
	_phase_t = 0.0
	_phase_fired = false
	_apply_phase_start()


func _apply_phase_start() -> void:
	for c in _chars:
		var cm: CharacterModel = c["model"]
		var mover: Node3D = c["mover"]
		mover.rotation.y = 0.0
		mover.position = c["base"]
		match String(PHASES[_phase][0]):
			"Death":
				cm.play_death()
			"Get up":
				cm.revive()
			"Idle":
				if cm.dead:
					cm.revive()


func _phase_name() -> String:
	return String(PHASES[_phase][0])


func _process(delta: float) -> void:
	if _quit_at > 0.0 and Time.get_ticks_msec() / 1000.0 > _quit_at:
		get_tree().quit()
		return
	_phase_t += delta
	_run_phase(delta)
	_update_camera(delta)
	_update_hud()
	if _auto and _phase_t >= float(PHASES[_phase][1]):
		var nxt := _phase + 1
		if nxt >= PHASES.size():
			_cycles += 1
			if _arg_once and _quit_at < 0.0:
				_quit_at = Time.get_ticks_msec() / 1000.0 + 0.5
		_set_phase(nxt)
	_maybe_shot()


func _run_phase(delta: float) -> void:
	var name := _phase_name()
	for i in _chars.size():
		var c: Dictionary = _chars[i]
		var mover: Node3D = c["mover"]
		var cm: CharacterModel = c["model"]
		match name:
			"Walk", "Run":
				var v := WALK_SPEED if name == "Walk" else RUN_SPEED
				var leg := 3.0 if name == "Walk" else 1.2
				# va verso la camera, si gira, torna: un giro dura 2*leg + la svolta
				var t := fposmod(_phase_t, 2.0 * leg + 0.6)
				var dir := 1.0
				if t < leg:
					mover.rotation.y = 0.0
				elif t < leg + 0.3:
					v = 0.0
					mover.rotation.y = PI
				elif t < 2.0 * leg + 0.3:
					mover.rotation.y = PI
					dir = 1.0
				else:
					v = 0.0
					mover.rotation.y = 0.0
				mover.global_position += -mover.global_transform.basis.z * v * delta * dir
			"Attack":
				if fposmod(_phase_t + float(i % 5) * 0.12, 1.25) < delta:
					cm.play_attack()
			"Block":
				if fposmod(_phase_t + float(i % 5) * 0.1, 1.6) < delta:
					cm._fire(&"block")
	if name == "Walk" or name == "Run":
		pass


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_7:
			_auto = false
			_set_phase(k - KEY_1)
		elif k == KEY_SPACE:
			_auto = not _auto
		elif k == KEY_RIGHT:
			_focus = (_focus + 1) % _chars.size() if _focus >= 0 else 0
		elif k == KEY_LEFT:
			_focus = (_focus - 1 + _chars.size()) % _chars.size() if _focus >= 0 else _chars.size() - 1
		elif k == KEY_ESCAPE or k == KEY_L:
			_focus = -1
		elif k == KEY_M:
			_mixamo = not _mixamo
			_spawn()
		elif k == KEY_G:
			_gear = not _gear
			_spawn()
		elif k == KEY_H:
			_help.visible = not _help.visible
		elif k == KEY_Q:
			get_tree().quit()
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_orbit.x -= ev.relative.x * 0.006
		_orbit.y = clampf(_orbit.y + ev.relative.y * 0.004, -0.2, 1.2)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 0.9, 1.2, 9.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom * 1.1, 1.2, 9.0)


func _update_camera(delta: float) -> void:
	_line_t += delta
	var target: Vector3
	var pos: Vector3
	if _focus < 0:
		# tutti in fila: camera frontale che oscilla lentamente
		var sway := sin(_line_t * 0.25) * 2.2
		var run_back := 3.0 if _phase_name() == "Run" else 0.0
		target = Vector3(0, 0.8, 2.3)
		pos = Vector3(sway, 3.5, -10.0 - run_back)
	else:
		var m: Node3D = _chars[_focus]["mover"]
		target = m.global_position + Vector3(0, _focus_y, 0)
		var yaw := _orbit.x + PI       # PI = di fronte (il personaggio guarda -Z)
		pos = target + Vector3(sin(yaw) * cos(_orbit.y), sin(_orbit.y), cos(yaw) * cos(_orbit.y)) * _zoom
		if _auto and _orbit.x == 0.0:
			_orbit.x = 0.0
	_cam.global_position = _cam.global_position.lerp(pos, 1.0 - exp(-delta * 4.0))
	_cam.look_at(target + (Vector3.ZERO), Vector3.UP)


func _update_hud() -> void:
	var who := "all 15 characters" if _focus < 0 else String(CAST[_focus][1])
	_hud.text = "Action: %s%s    |    %s    |    %s\nClips: %s    Gear: %s" % [
		_phase_name(), "" if _auto else " (manual)", who, "auto tour" if _auto else "manual",
		"Mixamo walk / run / death" if _mixamo else "procedural", "on" if _gear else "off"]


func _maybe_shot() -> void:
	if _arg_shots == "":
		return
	if _burst > 0:
		# serie di fotogrammi a distanza di 0,2 s dall'inizio dell'azione (prova delle pose)
		if _burst_n < _burst and _phase_t >= 0.6 + _burst_n * 0.2:
			_burst_n += 1
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/b%02d.png" % [_arg_shots, _burst_n])
		return
	var key := "%d_%d" % [_cycles, _phase]
	if _shot_done.has(key) or _phase_t < float(PHASES[_phase][1]) * 0.55:
		return
	_shot_done[key] = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var f := "%s/%d_%s%s.png" % [_arg_shots, _phase, _phase_name().to_lower().replace(" ", "_"), "" if _focus < 0 else "_" + String(CAST[_focus][0])]
	img.save_png(f)
	print("saved ", f)
