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

## Effetto pixel art sperimentale, spento di default. F9 lo fa ciclare:
## 0 = spento, 1 = palette fissa + dither Bayer, 2 = rampa di luminanza + dither.
@export_range(0, 2) var pixelart_mode := 0:
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

@onready var game_view: SubViewportContainer = $GameView
@onready var game_viewport: SubViewport = $GameView/GameViewport


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	game_view.stretch_shrink = pixelart_pixel_size if pixelart_mode > 0 else pixel_size
	game_view.material = post_process_material
	if post_process_material is ShaderMaterial:
		var amount := depth_of_field_amount if depth_of_field else 0.0
		(post_process_material as ShaderMaterial).set_shader_parameter(&"blur_amount", amount)
		(post_process_material as ShaderMaterial).set_shader_parameter(&"pixelart_mode", pixelart_mode)
		(post_process_material as ShaderMaterial).set_shader_parameter(&"pixelart_variant", pixelart_variant)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F9:
		pixelart_mode = (pixelart_mode + 1) % 3
