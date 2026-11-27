class_name RenderPipeline
extends Control
## Radice della scena principale. Il mondo 3D viene disegnato dentro un
## SubViewport; il SubViewportContainer lo mostra a schermo.
##
## Questo è il punto in cui aggiungere il filtro pixel art in futuro:
##  - pixel_size > 1 abbassa la risoluzione di rendering (stretch_shrink) e
##    l'immagine viene ingrandita con filtro "nearest", quindi a blocchi;
##  - post_process_material è un ShaderMaterial (canvas_item) applicato
##    all'immagine finale del mondo 3D, per esempio un filtro gaussiano +
##    quantizzazione dei colori in stile pixel art.
## La UI (CanvasLayer "UI") non passa dal post-process del mondo: con il filtro spento resta a piena
## risoluzione; con un modo pixel art attivo viene disegnata a blocchi 2x2 e colore a 15 bit (vedi
## _apply_hud_filter), sempre con l'aspetto del "32 bit".

## 1 = risoluzione piena. 2, 3, 4... = pixel più grandi.
@export_range(1, 8) var pixel_size := 1:
	set(value):
		pixel_size = value
		_apply()
## Shader di post-process sull'immagine 3D (vuoto = nessun filtro).
@export var post_process_material: Material:
	set(value):
		post_process_material = value
		_apply()

## Sfocatura da miniatura ai bordi dello schermo (tilt-shift). Spegnerla
## toglie 8 letture di texture per pixel: utile sui telefoni più lenti.
@export var depth_of_field := true:
	set(value):
		depth_of_field = value
		_apply()
## Forza della sfocatura quando è attiva.
@export_range(0.0, 8.0) var depth_of_field_amount := 3.0:
	set(value):
		depth_of_field_amount = value
		_apply()

## Effetto pixel art sperimentale, spento di default. K lo fa ciclare:
## 0 = spento, 1 = palette fissa + dither Bayer, 2 = rampa di luminanza + dither,
## 3 = "32 bit" (pixel 2x, colore a 15 bit con dither leggero),
## 4 = intermedio (pixel 3x, colore a 12 bit con dither leggero),
## 5 = PSX / lo-fi 3D (risoluzione interna ~320x240, 15 bit con dither forte, nebbia densa).
@export_range(0, 5) var pixelart_mode := 0:
	set(value):
		pixelart_mode = value
		_apply()
## Dimensione dei pixel con l'effetto attivo (si somma a pixel_size solo quando è attivo).
@export_range(2, 8) var pixelart_pixel_size := 3:
	set(value):
		pixelart_pixel_size = value
		_apply()

## Variante del modo 1 (vedi post_process.gdshader): 0 = originale, 1 = dither morbido,
## 2 = palette del livello, 3 = palette del livello + contorni leggeri.
@export_range(0, 3) var pixelart_variant := 0:
	set(value):
		pixelart_variant = value
		_apply()

## Dimensione dei pixel nel modo 3 ("32 bit").
@export_range(1, 4) var retro_pixel_size := 2:
	set(value):
		retro_pixel_size = value
		_apply()

@onready var game_view: SubViewportContainer = $GameView
@onready var game_viewport: SubViewport = $GameView/GameViewport


var _toast_layer: CanvasLayer


func _ready() -> void:
	_apply()
	get_window().size_changed.connect(_apply)


func _apply() -> void:
	if not is_node_ready():
		return
	var shrink := pixel_size
	if pixelart_mode == 5:
		# Risoluzione interna ~240 righe (320x240 su schermo 4:3), sempre un divisore intero.
		shrink = clampi(roundi(float(get_window().get_visible_rect().size.y) / 240.0), 2, 8)
	elif pixelart_mode > 0:
		shrink = retro_pixel_size if pixelart_mode == 3 else pixelart_pixel_size
	game_view.stretch_shrink = shrink
	game_view.material = post_process_material
	if post_process_material is ShaderMaterial:
		var amount := depth_of_field_amount if depth_of_field else 0.0
		(post_process_material as ShaderMaterial).set_shader_parameter(&"blur_amount", amount)
		(post_process_material as ShaderMaterial).set_shader_parameter(&"pixelart_mode", pixelart_mode)
		(post_process_material as ShaderMaterial).set_shader_parameter(&"pixelart_variant", pixelart_variant)
	_apply_hud_filter()


## Con un qualsiasi modo pixel art di K attivo l'HUD usa sempre l'aspetto del "32 bit": la UI (CanvasLayer
## "UI" e scritta del modo) viene disegnata in un SubViewport a metà risoluzione (blocchi 2x2, indipendenti
## dal modo del mondo), mostrato con filtro nearest e colore a 15 bit. Con il filtro spento la UI torna
## nella finestra principale, a piena risoluzione.
const HUD_PIXEL := 2

var _hud_container: SubViewportContainer
var _hud_viewport: SubViewport
var _hud_layer: CanvasLayer


func _apply_hud_filter() -> void:
	if not is_node_ready():
		return
	var ui := get_parent().get_node_or_null(^"UI") as CanvasLayer if get_parent() else null
	if ui == null:
		ui = get_node_or_null(^"UI") as CanvasLayer
	var on := pixelart_mode > 0
	if on and _hud_viewport == null:
		_hud_layer = CanvasLayer.new()
		_hud_layer.layer = 101
		add_child(_hud_layer)
		_hud_container = SubViewportContainer.new()
		_hud_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_hud_container.stretch = true
		_hud_container.stretch_shrink = HUD_PIXEL
		_hud_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/hud_pixelart.gdshader")
		_hud_container.material = mat
		_hud_layer.add_child(_hud_container)
		_hud_viewport = SubViewport.new()
		_hud_viewport.transparent_bg = true
		_hud_viewport.disable_3d = true
		_hud_viewport.handle_input_locally = false
		_hud_viewport.gui_embed_subwindows = false
		_hud_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_hud_container.add_child(_hud_viewport)
	if _hud_viewport:
		_hud_container.visible = on
		_hud_viewport.size_2d_override_stretch = true
		_hud_viewport.size_2d_override = Vector2i(get_window().get_visible_rect().size)
	HudWidgets.pixel_cell = float(HUD_PIXEL) if on else 0.0
	for layer: CanvasLayer in [ui, _toast_layer]:
		if layer and on:
			layer.custom_viewport = _hud_viewport
		elif layer and layer.custom_viewport != null:
			layer.custom_viewport = get_viewport()   # null non è ammesso: si torna alla finestra principale
	if ui:
		# La UI cambia viewport: ricalcola subito la disposizione dell'HUD.
		var hud := ui.get_node_or_null(^"LevelHud")
		if hud:
			hud.call_deferred(&"_layout")


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_K:
		pixelart_mode = (pixelart_mode + 1) % MODE_NAMES.size()
		_show_mode_toast()


const MODE_NAMES: Array[String] = [
	"Pixel art: off", "Pixel art: palette", "Pixel art: luminance ramp",
	"Pixel art: 32-bit", "Pixel art: 12-bit", "PSX: lo-fi 3D",
]
var _toast: Label
var _toast_tween: Tween


## Scritta in basso che compare per un istante quando si cambia modo con K.
func _show_mode_toast() -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_toast_layer = layer
		if _hud_viewport and pixelart_mode > 0:
			layer.custom_viewport = _hud_viewport
		_toast = Label.new()
		_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_toast.offset_top = -64.0
		_toast.offset_bottom = -24.0
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.add_theme_font_size_override(&"font_size", 22)
		_toast.add_theme_font_override(&"font", HudWidgets.font())
		_toast.add_theme_color_override(&"font_color", Color(1.0, 0.93, 0.78))
		_toast.add_theme_color_override(&"font_outline_color", Color(0.1, 0.06, 0.04, 0.9))
		_toast.add_theme_constant_override(&"outline_size", 6)
		layer.add_child(_toast)
	_toast.text = MODE_NAMES[pixelart_mode]
	# Con il filtro attivo la scritta è bold, più grande e a contorno spesso (sempre leggibile).
	var cell := HudWidgets.pixel_cell
	_toast.add_theme_font_override(&"font", HudWidgets.font())
	_toast.add_theme_font_size_override(&"font_size", 22 if cell <= 0.0 else maxi(int(8.0 * cell), 24))
	_toast.add_theme_constant_override(&"outline_size", 6 if cell <= 0.0 else int(2.0 * cell))
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5 if cell <= 0.0 else 0.01)
