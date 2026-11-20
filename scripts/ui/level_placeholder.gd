extends Control
## Segnaposto del livello 2: mostra un titolo e permette di rigiocare il livello 1.

func _ready() -> void:
	$Box/Button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main/main.tscn"))
