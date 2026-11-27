@tool
class_name FixedCamera
extends Camera3D
## Camera fissa da diorama: guarda un punto (target) da una distanza e da
## un'angolazione costanti. In editor si aggiorna subito quando cambi i valori.
##
## Se follow_target è impostato, durante il gioco la camera segue quel nodo
## (Ulisse) spostando solo il punto guardato: l'angolo resta sempre lo stesso.
## follow_bounds limita il punto guardato (X, Z) per non uscire dal diorama.
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


## Nodo da seguire durante il gioco (vuoto = camera ferma).
@export var follow_target: NodePath
## Velocità con cui la camera raggiunge il bersaglio (più alto = più rigida).
@export var follow_speed := 5.0
## Limiti del punto guardato: posizione = minimo (X, Z), size = estensione.
@export var follow_bounds := Rect2()

var _follow: Node3D


func _ready() -> void:
	_update_transform()
	if not Engine.is_editor_hint():
		_grow_bounds_to_grid()
	if not Engine.is_editor_hint() and not follow_target.is_empty():
		_follow = get_node_or_null(follow_target) as Node3D
		if _follow:
			target = _clamp_target(_follow.global_position)


## La griglia ha caselle in più a est e a sud (extra_cells): il punto guardato può seguire le unità fin lì.
func _grow_bounds_to_grid() -> void:
	var grid := get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	if grid and follow_bounds.has_area():
		follow_bounds.size += Vector2(grid.extra_cells) * grid.cell_size * 0.5


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _follow == null:
		return
	var wanted := _clamp_target(_follow.global_position)
	target = target.lerp(wanted, clampf(follow_speed * delta, 0.0, 1.0))


func _clamp_target(p: Vector3) -> Vector3:
	var t := Vector3(p.x, p.y, p.z)
	if follow_bounds.has_area():
		t.x = clampf(t.x, follow_bounds.position.x, follow_bounds.end.x)
		t.z = clampf(t.z, follow_bounds.position.y, follow_bounds.end.y)
	return t


func _update_transform() -> void:
	var orientation := Basis.from_euler(Vector3(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees), 0.0))
	# Trasformazione locale: target è espresso nello spazio del nodo genitore.
	transform = Transform3D(orientation, target + orientation.z * distance)
