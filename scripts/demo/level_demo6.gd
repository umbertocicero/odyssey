extends "res://scripts/demo/level_demo4.gd"
## Demo 6: la demo 4 (tempo e meteo) con l'effetto "32 bit" (modo 3: pixel 2x, colore a 15 bit).
## Stessi argomenti della demo 4; --pixelart=1|2 prova gli altri modi, --pixelart=0 lo spegne.


func _ready() -> void:
	_pixelart = 3
	super._ready()
