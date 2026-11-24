extends "res://scripts/demo/level_demo4.gd"
## Demo 6: la demo 4 (tempo e meteo) con l'effetto pixel art opzione 1 (palette Endesga 32 + Bayer).
## Stessi argomenti della demo 4; --pixelart=2 prova la rampa di luminanza, --pixelart=0 lo spegne.


func _ready() -> void:
	_pixelart = 1
	super._ready()
