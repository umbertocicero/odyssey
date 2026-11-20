extends Control
## Barra della vita di Ulisse in alto a sinistra.

@onready var _bar: ProgressBar = $VitaUlisse

var _player: GridUnit


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as GridUnit
		if _player:
			_player.health_changed.connect(_on_health_changed)
			_on_health_changed(_player.health, _player.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	_bar.max_value = maximum
	_bar.value = current
