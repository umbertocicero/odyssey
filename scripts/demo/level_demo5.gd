extends Node
## Demo 5: gli animali del livello 1 (cavalli fermi che muovono la testa e ogni tanto battono uno zoccolo,
## gregge e maiali che brucano e fanno qualche passo, cavalli sui rilievi vicino alle mura che seguono
## la quota del terreno), in circa 90 secondi. Usa il livello vero (main.tscn senza ondate né feriti),
## con ora fissa al tramonto dorato e vento sull'erba. La demo pilota solo camera e didascalie.
##
## Argomenti (dopo "--"): --auto-quit, --clean (niente aiuto tasti), --shots=DIR --shot-times=a,b,c,
## --timescale=N (solo prove), --quality=low|medium|high (i cavalli sul rilievo si vedono da "high").
## Tasti: Space pausa, R ricomincia, Esc esce.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const END_TIME := 90.0
const HOUR := 17.4

## Fotogrammi chiave: [t, fuoco(x,y,z), yaw, pitch, distanza, fov].
const CAM_KEYS := [
	[0.0, Vector3(11.3, 0.5, 4.6), 22.0, -14.0, 7.5, 40.0],
	[11.0, Vector3(11.3, 0.5, 4.6), -28.0, -10.0, 5.5, 40.0],
	[22.0, Vector3(18.9, 0.5, 5.5), -60.0, -20.0, 4.6, 40.0],
	[33.0, Vector3(15.0, 0.9, -1.9), 38.0, -8.0, 7.0, 38.0],
	[44.0, Vector3(9.0, 0.9, -5.9), -32.0, -9.0, 7.0, 38.0],
	[55.0, Vector3(-4.5, 0.9, 21.5), 24.0, -10.0, 7.0, 38.0],
	[66.0, Vector3(-15.0, 0.9, 16.0), -22.0, -9.0, 7.0, 38.0],
	[78.0, Vector3(-10.1, 1.2, -14.5), -45.0, -20.0, 8.0, 38.0],
	[90.0, Vector3(-10.1, 1.0, -14.5), 10.0, -16.0, 14.0, 34.0],
]
## Didascalie discrete, in inglese: [da, a, testo].
const CAPTIONS := [
	[1.0, 10.0, "Sheep graze and drift a few slow steps"],
	[12.0, 20.0, "They lift their heads, turn gently, never spin"],
	[23.0, 31.0, "Pigs root about"],
	[34.0, 43.0, "Harnessed horses stand still: breathing, head, a hoof now and then"],
	[45.0, 53.0, "A lone horse on the road"],
	[56.0, 64.0, "Camp horses stay put, tossing their heads"],
	[67.0, 76.0, "Hooves follow the terrain"],
	[79.0, 88.0, "Even on the ledges by the walls"],
]

var main: Node
var director: LevelDirector
var viewport: SubViewport
var cam: Camera3D
var clock: LevelClock
var t := 0.0

var _auto_quit := false
var _clean := false
var _shots := ""
var _shot_times: Array[float] = []
var _next_shot := 0
var _timescale := 1.0
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
		elif arg.begins_with("--shots="):
			_shots = arg.substr(8)
		elif arg.begins_with("--shot-times="):
			for s in arg.substr(13).split(",", false):
				_shot_times.append(float(s))
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
	if main:
		main.free()
		main = null
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	director = main.get_node("Director") as LevelDirector
	director.next_level_path = ""
	director.auto_start = false   # niente ondate, feriti o banner
	add_child(main)
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
		clock.start_hour = HOUR
		clock.time_of_day = HOUR
		clock.set("_next_roll", 1.0e9)   # niente pioggia
	cam = Camera3D.new()
	cam.name = "DemoCamera"
	cam.far = 400.0
	viewport.add_child(cam)
	cam.make_current()
	_apply_camera()
	_booting = false


func _process(delta: float) -> void:
	if _booting or clock == null:
		return
	if _paused:
		return
	t += delta
	_apply_camera()
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
	_label_time.text = ""
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
		img.save_png("%s/demo5_%03d.png" % [_shots, int(_shot_times[_next_shot])])
		_next_shot += 1
