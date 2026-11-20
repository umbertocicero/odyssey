@tool
class_name GridProp
extends Node3D
## Oggetto di scena basato su un modello .glb scaricato.
## Il modello viene portato alla misura voluta (fit_size) e appoggiato a terra,
## senza modificare il file originale. Se blocking è attivo, occupa sulla
## griglia le caselle della sua impronta (footprint), centrata sul nodo.

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
## Nome di un singolo pezzo dentro un modello "pack" (vuoto = tutto il modello).
@export var piece := "":
	set(value):
		piece = value
		_rebuild()
## Correzione dell'orientamento del modello, in gradi (es. X = 90 per stenderlo a terra).
@export var model_rotation_degrees := Vector3.ZERO:
	set(value):
		model_rotation_degrees = value
		_rebuild()
## Quale misura del modello portare a fit_size.
@export var fit_axis: ModelFit.Axis = ModelFit.Axis.LONGEST:
	set(value):
		fit_axis = value
		_rebuild()
## Misura finale in metri (1 casella = 1 m).
@export var fit_size := 1.0:
	set(value):
		fit_size = value
		_rebuild()
## Caselle occupate (larghezza X, profondità Z) prima della rotazione del nodo.
@export var footprint := Vector2i.ONE
## Se attivo, le caselle dell'impronta non sono calpestabili.
@export var blocking := true
## Se non vuoto, blocca solo queste caselle dell'impronta (indici X, Z da 0),
## per esempio solo i pilastri di un arco sotto cui si può passare.
@export var blocked_cells_in_footprint: Array[Vector2i] = []
@export var cell_size := 1.0
@export var cast_shadows := true:
	set(value):
		cast_shadows = value
		_rebuild()

var _visual: Node3D


func _enter_tree() -> void:
	if blocking:
		add_to_group(&"grid_obstacle")


func _ready() -> void:
	_rebuild()


## Caselle bloccate da questo oggetto (usato da DioramaGrid).
func get_blocked_cells(grid: DioramaGrid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not blocking:
		return cells
	var indices: Array[Vector2i] = blocked_cells_in_footprint.duplicate()
	if indices.is_empty():
		for i in footprint.x:
			for j in footprint.y:
				indices.append(Vector2i(i, j))
	for index in indices:
		var local := Vector3((index.x - (footprint.x - 1) * 0.5) * cell_size, 0.0, (index.y - (footprint.y - 1) * 0.5) * cell_size)
		cells.append(grid.world_to_cell(global_transform * local))
	return cells


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual:
		_visual.queue_free()
		_visual = null
	if model == null:
		return
	var meshes := ModelFit.extract_meshes(model, piece)
	var fit := ModelFit.fit_transform(meshes, model_rotation_degrees, fit_axis, fit_size)
	# Nodi generati: senza owner, quindi non vengono salvati nella scena.
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	for entry in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = entry[0]
		mi.transform = fit * (entry[1] as Transform3D)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(mi)
