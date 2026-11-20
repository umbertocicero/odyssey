@tool
class_name DioramaGrid
extends Node3D
## Griglia logica del diorama: converte celle <-> posizioni 3D, tiene traccia
## delle celle bloccate (ostacoli) e di quelle occupate (unità).
##
## Il centro della griglia coincide con l'origine del nodo, sul piano y = 0.
## Gli ostacoli sono nodi 3D nel gruppo "grid_obstacle": la loro cella viene
## calcolata dalla posizione e segnata come bloccata all'avvio.

const OBSTACLE_GROUP := &"grid_obstacle"

@export var size := Vector2i(12, 8):
	set(value):
		size = value
		_rebuild_tiles()
@export var cell_size := 1.0:
	set(value):
		cell_size = maxf(value, 0.1)
		_rebuild_tiles()
@export var tile_color_a := Color(0.56, 0.47, 0.30):
	set(value):
		tile_color_a = value
		_rebuild_tiles()
@export var tile_color_b := Color(0.50, 0.42, 0.27):
	set(value):
		tile_color_b = value
		_rebuild_tiles()
## Mostra le caselle a scacchiera (utile per il prototipo, da spegnere con i modelli definitivi).
@export var show_tiles := true:
	set(value):
		show_tiles = value
		_rebuild_tiles()

var _blocked: Dictionary = {}   # Vector2i -> true
var _occupants: Dictionary = {} # Vector2i -> Node
var _tiles: MultiMeshInstance3D


func _ready() -> void:
	add_to_group(&"diorama_grid")
	_rebuild_tiles()
	if not Engine.is_editor_hint():
		_register_obstacles()


func cell_to_world(cell: Vector2i) -> Vector3:
	var offset := Vector2(size) * cell_size * 0.5
	var local := Vector3((cell.x + 0.5) * cell_size - offset.x, 0.0, (cell.y + 0.5) * cell_size - offset.y)
	return to_global(local)


func world_to_cell(world_position: Vector3) -> Vector2i:
	var local := to_local(world_position)
	var offset := Vector2(size) * cell_size * 0.5
	return Vector2i(floori((local.x + offset.x) / cell_size), floori((local.z + offset.y) / cell_size))


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func get_occupant(cell: Vector2i) -> Node:
	return _occupants.get(cell)


func is_walkable(cell: Vector2i) -> bool:
	return is_inside(cell) and not is_blocked(cell) and not _occupants.has(cell)


func set_blocked(cell: Vector2i, blocked: bool) -> void:
	if blocked:
		_blocked[cell] = true
	else:
		_blocked.erase(cell)


func occupy(cell: Vector2i, unit: Node) -> void:
	_occupants[cell] = unit


func release(cell: Vector2i, unit: Node) -> void:
	if _occupants.get(cell) == unit:
		_occupants.erase(cell)


func _register_obstacles() -> void:
	for node in get_tree().get_nodes_in_group(OBSTACLE_GROUP):
		if node is Node3D:
			set_blocked(world_to_cell((node as Node3D).global_position), true)


func _rebuild_tiles() -> void:
	if not is_inside_tree():
		return
	if _tiles:
		_tiles.queue_free()
		_tiles = null
	if not show_tiles:
		return

	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * cell_size * 0.96
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = size.x * size.y

	var offset := Vector2(size) * cell_size * 0.5
	var i := 0
	for y in size.y:
		for x in size.x:
			var pos := Vector3((x + 0.5) * cell_size - offset.x, 0.01, (y + 0.5) * cell_size - offset.y)
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
			multimesh.set_instance_color(i, tile_color_a if (x + y) % 2 == 0 else tile_color_b)
			i += 1

	# Nodo generato: non ha owner, quindi non viene salvato nella scena.
	_tiles = MultiMeshInstance3D.new()
	_tiles.name = "Tiles"
	_tiles.multimesh = multimesh
	add_child(_tiles)
