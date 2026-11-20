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

@onready var game_view: SubViewportContainer = $GameView
@onready var game_viewport: SubViewport = $GameView/GameViewport


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	game_view.stretch_shrink = pixel_size
	game_view.material = post_process_material
