extends "res://scripts/demo/level_demo.gd"
## Demo 2: la stessa regia di level_demo.gd ma pensata per registrare il video.
## Sempre "pulita" (nessun indicatore di capitolo né aiuto tasti), nessun tasto
## attivo, si chiude da sola dopo la schermata finale.
## Registrazione: scenes/demo/run_demo2.sh (godot --write-movie ... --fixed-fps 30).


func _ready() -> void:
	super._ready()
	_arg_clean = true
	_arg_auto_quit = true
	_chapter_label.visible = false
	_help.visible = false


func _unhandled_input(_event: InputEvent) -> void:
	pass   # niente scorciatoie durante la registrazione
