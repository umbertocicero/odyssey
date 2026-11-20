@tool
class_name FixedCamera
extends Camera3D
## Camera fissa da diorama: guarda un punto (target) da una distanza e da
## un'angolazione costanti. In editor si aggiorna subito quando cambi i valori.
##
## Nota: lo yaw non deve essere esattamente 45°, altrimenti la conversione
## "direzione sullo schermo -> asse della griglia" diventa ambigua.

@export var target := Vector3.ZERO:
	set(value):
		target = value
		_update_transform()
@export_range(5.0, 60.0, 0.5) var distance := 20.0:
	set(value):
		distance = value
		_update_transform()
@export_range(-89.0, -10.0, 0.5) var pitch_degrees := -42.0:
	set(value):
		pitch_degrees = value
		_update_transform()
@export_range(-180.0, 180.0, 0.5) var yaw_degrees := 30.0:
	set(value):
		yaw_degrees = value
		_update_transform()


func _ready() -> void:
	_update_transform()


func _update_transform() -> void:
	var orientation := Basis.from_euler(Vector3(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees), 0.0))
	# Trasformazione locale: target è espresso nello spazio del nodo genitore.
	transform = Transform3D(orientation, target + orientation.z * distance)
