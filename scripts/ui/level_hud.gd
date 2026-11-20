class_name LevelHud
extends Control
## Interfaccia del livello: tempo alla ritirata, ondata, feriti salvati,
## annunci e schermata finale. Costruita da codice, tutti i testi in inglese.

signal continue_pressed

var _time_label: Label
var _wounded_label: Label
var _banner: Label
var _banner_tween: Tween
var _end_panel: PanelContainer
var _end_title: Label
var _end_body: Label
var _continue: Button


func _ready() -> void:
	# Con set_anchors_preset le dimensioni resterebbero 0x0: servono anche gli offset.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_label = _make_label(28, HORIZONTAL_ALIGNMENT_CENTER)
	_time_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_time_label.offset_top = 8
	_time_label.offset_left = -200
	_time_label.offset_right = 200
	_time_label.text = "Retreat signal in --:--"
	_wounded_label = _make_label(22, HORIZONTAL_ALIGNMENT_RIGHT)
	_wounded_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wounded_label.offset_left = -360
	_wounded_label.offset_right = -16
	_wounded_label.offset_top = 12
	_wounded_label.text = "Wounded rescued: 0 / 0"
	_banner = _make_label(34, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 150   # sotto le istruzioni in alto a sinistra
	_banner.offset_left = -420
	_banner.offset_right = 420
	_banner.modulate.a = 0.0
	_build_end_panel()


func _make_label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_outline_color", Color(0.1, 0.05, 0.02))
	l.add_theme_constant_override(&"outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _build_end_panel() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.visible = false
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.custom_minimum_size = Vector2(620, 0)
	_end_panel.offset_left = -310
	_end_panel.offset_right = 310
	_end_panel.offset_top = -190
	_end_panel.offset_bottom = 190
	add_child(_end_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	_end_panel.add_child(box)
	_end_title = Label.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override(&"font_size", 36)
	box.add_child(_end_title)
	_end_body = Label.new()
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_body.custom_minimum_size = Vector2(560, 0)
	box.add_child(_end_body)
	_continue = Button.new()
	_continue.text = "Continue to Level 2"
	_continue.pressed.connect(func(): continue_pressed.emit())
	box.add_child(_continue)


func set_time(seconds_left: float, wave: int) -> void:
	var s := int(ceil(seconds_left))
	_time_label.text = "Retreat signal in %d:%02d   |   Wave %d" % [s / 60, s % 60, wave]


func set_wounded(saved: int, lost: int, total: int) -> void:
	_wounded_label.text = "Wounded rescued: %d / %d   (lost %d)" % [saved, total, lost]


func show_banner(text: String, seconds: float) -> void:
	_banner.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func show_end(s: Dictionary) -> void:
	_end_title.text = str(s["title"])
	_end_body.text = "%s\n\nWounded rescued: %d of %d\nTrojans defeated: %d\nWaves survived: %d\n\nScore: %d" % [
		s["text"], s["saved"], s["total"], s["kills"], s["waves"], s["score"]]
	_end_panel.visible = true
	_end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_continue.grab_focus()


func end_panel_visible() -> bool:
	return _end_panel != null and _end_panel.visible
