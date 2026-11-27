class_name Level2Hud
extends Control
## Interfaccia del livello 2, tutta da codice e in inglese: obiettivi in alto a sinistra, barra della vita,
## banner centrale, sottotitoli, suggerimento di interazione, barra di lavoro, dissolvenza e schermata finale.
## Colori e cornici in bronzo/pergamena come l'HUD del livello 1 (STYLE.md).

signal replay_pressed

const BRONZE := Color(0.72, 0.5, 0.24)
const PANEL := Color(0.11, 0.08, 0.055, 0.82)
const CREAM := Color(0.95, 0.88, 0.7)
const RED := Color(0.78, 0.22, 0.18)

var _title: Label
var _objectives: Label
var _health: ProgressBar
var _prompt: Label
var _work_bar: ProgressBar
var _work_label: Label
var _banner: Label
var _subtitle: Label
var _fade: ColorRect
var _end: PanelContainer
var _end_title: Label
var _end_body: Label
var _banner_tween: Tween
var _sub_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := _panel(Vector2(14, 12), Vector2(330, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	left.add_child(box)
	_title = _label("THE GIFT OF THE SEA", 17, BRONZE)
	box.add_child(_title)
	var hp_row := HBoxContainer.new()
	box.add_child(hp_row)
	hp_row.add_child(_label("Odysseus", 14, CREAM))
	_health = ProgressBar.new()
	_health.custom_minimum_size = Vector2(190, 16)
	_health.show_percentage = false
	_health.self_modulate = RED
	_health.value = 100.0
	hp_row.add_child(_health)
	_objectives = _label("", 14, CREAM)
	_objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objectives.custom_minimum_size = Vector2(300, 0)
	box.add_child(_objectives)

	_banner = _label("", 24, CREAM)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 70.0
	_banner.offset_left = -420.0
	_banner.offset_right = 420.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.modulate.a = 0.0
	add_child(_banner)

	_subtitle = _label("", 18, CREAM)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.offset_top = -120.0
	_subtitle.offset_left = -420.0
	_subtitle.offset_right = 420.0
	_subtitle.offset_bottom = -70.0
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)

	_prompt = _label("", 18, CREAM)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -190.0
	_prompt.offset_left = -300.0
	_prompt.offset_right = 300.0
	_prompt.offset_bottom = -160.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)

	_work_label = _label("", 16, CREAM)
	_work_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_work_label.offset_top = 90.0
	_work_label.offset_left = -200.0
	_work_label.offset_right = 200.0
	_work_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_work_label)
	_work_bar = ProgressBar.new()
	_work_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_work_bar.offset_top = 116.0
	_work_bar.offset_bottom = 134.0
	_work_bar.offset_left = -120.0
	_work_bar.offset_right = 120.0
	_work_bar.show_percentage = false
	_work_bar.max_value = 1.0
	_work_bar.self_modulate = BRONZE
	_work_bar.visible = false
	add_child(_work_bar)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)

	_end = PanelContainer.new()
	_end.add_theme_stylebox_override("panel", _style())
	_end.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_end.offset_left = -300.0
	_end.offset_right = 300.0
	_end.offset_top = -150.0
	_end.offset_bottom = 150.0
	_end.visible = false
	add_child(_end)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 14)
	_end.add_child(ev)
	_end_title = _label("", 28, BRONZE)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(_end_title)
	_end_body = _label("", 17, CREAM)
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev.add_child(_end_body)
	var btn := Button.new()
	btn.text = "Replay Level 2"
	btn.pressed.connect(func() -> void: replay_pressed.emit())
	ev.add_child(btn)


func _style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = BRONZE
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(10)
	return s


func _panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style())
	p.position = pos
	p.custom_minimum_size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func set_health(current: int, maximum: int) -> void:
	_health.max_value = maximum
	_health.value = current


func set_objectives(text: String) -> void:
	_objectives.text = text


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_work(label: String, ratio: float) -> void:
	_work_bar.visible = label != ""
	_work_label.text = label
	_work_bar.value = ratio


func show_banner(text: String, seconds := 3.0) -> void:
	_banner.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func show_subtitle(speaker: String, text: String, seconds := 4.0) -> void:
	_subtitle.text = ("%s: " % speaker if speaker != "" else "") + text
	if _sub_tween:
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.25)
	_sub_tween.tween_interval(seconds)
	_sub_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.5)


func fade_to(alpha: float, seconds: float) -> Tween:
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", alpha, seconds)
	return t


func show_end(title: String, body: String) -> void:
	_end_title.text = title
	_end_body.text = body
	_end.visible = true
