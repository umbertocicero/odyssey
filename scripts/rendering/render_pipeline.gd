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
## La UI (CanvasLayer "UI") resta fuori dal filtro e a piena risoluzione.

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
## 4 = intermedio (pixel 3x, colore a 12 bit con dither leggero).
@export_range(0, 4) var pixelart_mode := 0:
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


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	game_view.stretch_shrink = (retro_pixel_size if pixelart_mode == 3 else pixelart_pixel_size) if pixelart_mode > 0 else pixel_size
	game_view.material = post_process_material
	if post_process_material is ShaderMaterial:
		var amount := depth_of_field_amount if depth_of_field else 0.0
		(post_process_material as ShaderMaterial).set_shader_parameter(&"blur_amount", amount)
		(post_process_material as ShaderMaterial).set_shader_parameter(&"pixelart_mode", pixelart_mode)
		(post_process_material as ShaderMaterial).set_shader_parameter(&"pixelart_variant", pixelart_variant)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_K:
		pixelart_mode = (pixelart_mode + 1) % 5
		_show_mode_toast()


const MODE_NAMES: Array[String] = [
	"Pixel art: off", "Pixel art: palette", "Pixel art: luminance ramp",
	"Pixel art: 32-bit", "Pixel art: 12-bit",
]
var _toast: Label
var _toast_tween: Tween


## Scritta in basso che compare per un istante quando si cambia modo con K.
func _show_mode_toast() -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_toast = Label.new()
		_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_toast.offset_top = -64.0
		_toast.offset_bottom = -24.0
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.add_theme_font_size_override(&"font_size", 22)
		_toast.add_theme_color_override(&"font_color", Color(1.0, 0.93, 0.78))
		_toast.add_theme_color_override(&"font_outline_color", Color(0.1, 0.06, 0.04, 0.9))
		_toast.add_theme_constant_override(&"outline_size", 6)
		layer.add_child(_toast)
	_toast.text = MODE_NAMES[pixelart_mode]
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
