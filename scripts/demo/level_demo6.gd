extends "res://scripts/demo/level_demo4.gd"
## Demo 6: la demo 4 (tempo e meteo) con l'effetto intermedio (modo 4: pixel 3x, colore a 12 bit); --pixelart=3 è il "32 bit".
## Stessi argomenti della demo 4; --pixelart=1|2|3 prova gli altri modi, --pixelart=0 lo spegne.


func _ready() -> void:
	_pixelart = 4
	super._ready()
