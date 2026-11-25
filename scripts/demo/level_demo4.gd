extends Node
## Demo 4: il passare del tempo e il meteo sul diorama del livello 1, in circa 95 secondi.
##
## Pomeriggio dorato con vento sull'erba, poi un acquazzone (momento e durata casuali ma con seme
## fisso, quindi ripetibili), le pozzanghere che si asciugano al ritorno del sole, il tramonto e la
## notte con torce accese e luna fredda. Usa solo i sistemi veri: LevelClock, NightCycle, WeatherFx,
## LevelAtmosphere, shader dell'erba. Il livello è main.tscn senza ondate né feriti (Director senza
## auto-start): la demo pilota soltanto l'ora (LevelClock.time_of_day) e fa partire la pioggia.
##
## Argomenti (dopo "--"): --auto-quit, --clean (niente aiuto tasti), --seed=N,
## --pixelart=0|1|2, --shots=DIR --shot-times=a,b,c, --timescale=N (solo prove), --quality=low|medium|high.
## Tasti: Space pausa, R ricomincia, Esc esce.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const END_TIME := 95.0

## Ora di gioco in funzione del tempo della demo (secondi reali -> ore).
const HOUR_KEYS := [
	[0.0, 15.5], [12.0, 16.5], [40.0, 17.3], [50.0, 17.8], [60.0, 19.0],
	[70.0, 20.4], [80.0, 21.6], [95.0, 22.3],
]
## Fotogrammi chiave: [t, fuoco(x,y,z), yaw, pitch, distanza, fov].
const CAM_KEYS := [
	[0.0, Vector3(0, 0, 0), 28.0, -34.0, 52.0, 28.0],
	[13.0, Vector3(-4, 0, 2), 10.0, -30.0, 44.0, 29.0],
	[27.0, Vector3(-10, 0, 9), 22.0, -19.0, 24.0, 34.0],
	[41.0, Vector3(4, 0.3, 6), -26.0, -9.0, 14.0, 36.0],
	[55.0, Vector3(6.5, 0.2, 3), -38.0, -8.0, 10.0, 38.0],
	[68.0, Vector3(-6, 0, 6), 14.0, -22.0, 36.0, 30.0],
	[80.0, Vector3(-11.5, 0.8, 10), 32.0, -15.0, 19.0, 36.0],
	[95.0, Vector3(-2, 0, 2), 20.0, -38.0, 56.0, 28.0],
]
## Didascalie discrete, in inglese: [da, a, testo].
const CAPTIONS := [
	[1.0, 8.0, "Late afternoon"],
	[14.0, 24.0, "A storm rolls in"],
	[42.0, 52.0, "The sun returns, the puddles dry"],
	[60.0, 70.0, "Dusk"],
	[78.0, 90.0, "Night: torches and moonlight"],
]

var main: Node
var director: LevelDirector
var viewport: SubViewport
var cam: Camera3D
var clock: LevelClock
var t := 0.0
var rng := RandomNumberGenerator.new()
var rain_at := 14.0
var rain_for := 26.0
var rain_started := false
var rain_sheet: CPUParticles3D

var _seed := 1207
var _auto_quit := false
var _clean := false
var _shots := ""
var _shot_times: Array[float] = []
var _next_shot := 0
var _timescale := 1.0
## 0 = look normale, 1/2/3 = pixel art (vedi RenderPipeline.pixelart_mode). La demo 6 parte da 1.
var _pixelart := 0
var _paused := false
var _booting := true
var _gen := 0
var _label_time: Label
var _label_cap: Label
var _label_help: Label
var _ui: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto-quit":
			_auto_quit = true
		elif arg == "--clean":
			_clean = true
		elif arg.begins_with("--seed="):
			_seed = int(arg.substr(7))
		elif arg.begins_with("--shots="):
			_shots = arg.substr(8)
		elif arg.begins_with("--shot-times="):
			for s in arg.substr(13).split(",", false):
				_shot_times.append(float(s))
		elif arg.begins_with("--pixelart="):
			_pixelart = clampi(int(arg.substr(11)), 0, 3)
		elif arg.begins_with("--timescale="):
			_timescale = clampf(float(arg.substr(12)), 0.1, 16.0)
	if _timescale != 1.0:
		Engine.time_scale = _timescale
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
	_build_ui()
	_boot()


func _boot() -> void:
	_gen += 1
	var gen := _gen
	_booting = true
	t = 0.0
	_next_shot = 0
	rain_started = false
	if main:
		main.free()
		main = null
	rng.seed = _seed
	rain_at = rng.randf_range(12.0, 17.0)
	rain_for = rng.randf_range(24.0, 29.0)
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	director = main.get_node("Director") as LevelDirector
	director.next_level_path = ""
	director.auto_start = false   # niente ondate, feriti o banner: solo il diorama
	add_child(main)
	if _pixelart > 0:
		main.set(&"pixelart_mode", _pixelart)
	for i in 8:
		await get_tree().process_frame
	if gen != _gen:
		return
	viewport = main.get_node("GameView/GameViewport") as SubViewport
	var ui := main.get_node_or_null(^"UI") as CanvasLayer
	if ui:
		ui.visible = false
	clock = get_tree().get_first_node_in_group(&"level_clock") as LevelClock
	if clock:
		clock.running = false
		clock.start_hour = HOUR_KEYS[0][1]
		clock.time_of_day = HOUR_KEYS[0][1]
		clock.random_seed = _seed
		clock.set("_next_roll", 1.0e9)   # la pioggia la decide la demo (con seme), non il dado del livello
	cam = Camera3D.new()
	cam.name = "DemoCamera"
	cam.far = 400.0
	viewport.add_child(cam)
	cam.make_current()
	_apply_camera()
	_build_rain_sheet()
	_booting = false


func _process(delta: float) -> void:
	if _booting or clock == null:
		return
	if _paused:
		return
	t += delta
	if not rain_started and t >= rain_at:
		rain_started = true
		clock.start_rain(rain_for)
	# Quando smette di piovere il sole asciuga le pozze in circa 20 s (il clock da solo ne userebbe 60).
	if clock.rain <= 0.0 and clock.wetness > 0.0:
		clock.wetness = move_toward(clock.wetness, 0.0, delta / 30.0)
	clock.time_of_day = _hour_at(t)
	_apply_camera()
	_update_rain_sheet()
	_update_labels()
	_update_shots()
	if t >= END_TIME + 2.0 and _auto_quit:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE:
			_paused = not _paused
			get_tree().paused = _paused
		KEY_R:
			get_tree().paused = false
			_paused = false
			_boot.call_deferred()


func _hour_at(time: float) -> float:
	for i in range(HOUR_KEYS.size() - 1):
		var a: Array = HOUR_KEYS[i]
		var b: Array = HOUR_KEYS[i + 1]
		if time <= b[0]:
			return lerpf(a[1], b[1], smoothstep(0.0, 1.0, inverse_lerp(a[0], b[0], time)) * 0.35 + inverse_lerp(a[0], b[0], time) * 0.65)
	return HOUR_KEYS[-1][1]


# ─────────────────────────── camera ───────────────────────────

func _apply_camera() -> void:
	if cam == null:
		return
	var n := CAM_KEYS.size()
	var i := 0
	while i < n - 2 and t >= float(CAM_KEYS[i + 1][0]):
		i += 1
	var k1: Array = CAM_KEYS[i]
	var k2: Array = CAM_KEYS[i + 1]
	var k0: Array = CAM_KEYS[maxi(i - 1, 0)]
	var k3: Array = CAM_KEYS[mini(i + 2, n - 1)]
	var u := clampf(inverse_lerp(float(k1[0]), float(k2[0]), t), 0.0, 1.0)
	var focus: Vector3 = (k1[1] as Vector3).cubic_interpolate(k2[1], k0[1], k3[1], u)
	var yaw := _cr(k0[2], k1[2], k2[2], k3[2], u)
	var pitch := _cr(k0[3], k1[3], k2[3], k3[3], u)
	var dist := _cr(k0[4], k1[4], k2[4], k3[4], u)
	# Piccolo respiro per non sembrare un binario perfetto.
	yaw += sin(t * 0.37) * 1.2
	focus.y += sin(t * 0.5) * 0.08
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))
	cam.global_transform = Transform3D(basis, focus + basis.z * dist)
	cam.fov = _cr(k0[5], k1[5], k2[5], k3[5], u)


func _cr(p0: float, p1: float, p2: float, p3: float, u: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


# ─────────────────────────── pioggia (solo demo) ───────────────────────────

## Strisce di pioggia 3D davanti alla camera, in più dell'overlay di WeatherFx, solo per rendere la
## pioggia ben visibile nel video. Non fa parte del gioco: costo solo qui.
func _build_rain_sheet() -> void:
	rain_sheet = CPUParticles3D.new()
	rain_sheet.name = "PioggiaDemo"
	rain_sheet.amount = 1100
	rain_sheet.lifetime = 0.7
	rain_sheet.local_coords = false
	rain_sheet.emitting = false
	rain_sheet.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_sheet.emission_box_extents = Vector3(14.0, 0.5, 14.0)
	rain_sheet.direction = Vector3(0.12, -1.0, 0.05)
	rain_sheet.spread = 2.0
	rain_sheet.initial_velocity_min = 19.0
	rain_sheet.initial_velocity_max = 23.0
	rain_sheet.gravity = Vector3.ZERO
	rain_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.5, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.78, 0.85, 0.95, 0.4)
	m.disable_receive_shadows = true
	drop.material = m
	rain_sheet.mesh = drop
	viewport.add_child(rain_sheet)


func _update_rain_sheet() -> void:
	if rain_sheet == null:
		return
	var amount := clock.rain
	rain_sheet.emitting = amount > 0.05
	(rain_sheet.mesh.material as StandardMaterial3D).albedo_color.a = 0.42 * amount
	var forward := -cam.global_basis.z
	var centre := cam.global_position + forward * minf(cam.global_position.distance_to(Vector3.ZERO) * 0.4, 14.0)
	rain_sheet.global_position = Vector3(centre.x, 11.0, centre.z)
	var wind := clock.wind_direction * clock.wind_strength
	rain_sheet.direction = Vector3(wind.x * 1.2, -1.0, wind.y * 1.2)


# ─────────────────────────── testi ───────────────────────────

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 60
	add_child(_ui)
	_label_time = _label(22, Control.PRESET_TOP_RIGHT)
	_label_time.offset_left = -170
	_label_time.offset_right = -24
	_label_time.offset_top = 18
	_label_time.offset_bottom = 48
	_label_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_time.modulate.a = 0.75
	_label_cap = _label(30, Control.PRESET_CENTER_BOTTOM)
	_label_cap.offset_left = -500
	_label_cap.offset_right = 500
	_label_cap.offset_top = -90
	_label_cap.offset_bottom = -44
	_label_cap.modulate.a = 0.0
	_label_help = _label(14, Control.PRESET_BOTTOM_RIGHT)
	_label_help.offset_left = -360
	_label_help.offset_right = -12
	_label_help.offset_top = -30
	_label_help.offset_bottom = -8
	_label_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_help.text = "R  restart    Space  pause    Esc  quit"
	_label_help.modulate.a = 0.7
	_label_help.visible = not _clean


func _label(size: int, preset: Control.LayoutPreset) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(preset)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", Color(1.0, 0.93, 0.78))
	l.add_theme_color_override(&"font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	l.add_theme_constant_override(&"outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(l)
	return l


func _update_labels() -> void:
	var h := clock.time_of_day
	_label_time.text = "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]
	var alpha := 0.0
	for c in CAPTIONS:
		if t >= c[0] and t <= c[1]:
			_label_cap.text = c[2]
			alpha = minf(minf(t - c[0], c[1] - t) / 1.2, 1.0)
	_label_cap.modulate.a = clampf(alpha, 0.0, 1.0)


func _update_shots() -> void:
	if _shots == "" or _next_shot >= _shot_times.size():
		return
	if t >= _shot_times[_next_shot]:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/demo4_%03d.png" % [_shots, int(_shot_times[_next_shot])])
		_next_shot += 1
