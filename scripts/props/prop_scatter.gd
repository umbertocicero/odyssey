@tool
class_name PropScatter
extends Node3D
## Sparge molte copie decorative di un modello (alberi, cespugli, fiori,
## erba) in un'area rettangolare, usando MultiMesh: una sola chiamata di
## disegno per ogni mesh, adatto a mobile e web. Non blocca la griglia.

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
@export var piece := "":
	set(value):
		piece = value
		_rebuild()
@export var model_rotation_degrees := Vector3.ZERO:
	set(value):
		model_rotation_degrees = value
		_rebuild()
@export var fit_axis: ModelFit.Axis = ModelFit.Axis.HEIGHT:
	set(value):
		fit_axis = value
		_rebuild()
@export var fit_size := 1.0:
	set(value):
		fit_size = value
		_rebuild()
## Variazione casuale della misura (0.25 = ±25%).
@export_range(0.0, 0.9) var size_variation := 0.25:
	set(value):
		size_variation = value
		_rebuild()
## Area (X, Z) centrata sul nodo in cui spargere le copie.
@export var area_size := Vector2(10, 10):
	set(value):
		area_size = value
		_rebuild()
## Zone da lasciare libere (in coordinate locali X, Z), es. la strada.
@export var exclude_rects: Array[Rect2] = []:
	set(value):
		exclude_rects = value
		_rebuild()
@export var count := 20:
	set(value):
		count = maxi(value, 0)
		_rebuild()
@export var random_seed := 1:
	set(value):
		random_seed = value
		_rebuild()
@export var cast_shadows := false:
	set(value):
		cast_shadows = value
		_rebuild()
## Moltiplicatore dell'albedo del fogliame (vedi FoliageTint). Bianco = nessuna correzione.
@export var foliage_gain := Color(1, 1, 1):
	set(value):
		foliage_gain = value
		_rebuild()

var _generated: Array[Node] = []


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for node in _generated:
		node.queue_free()
	_generated.clear()
	if model == null or count == 0:
		return

	var meshes := ModelFit.extract_meshes(model, piece)
	var fit := ModelFit.fit_transform(meshes, model_rotation_degrees, fit_axis, fit_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var transforms: Array[Transform3D] = []
	var attempts := 0
	while transforms.size() < count and attempts < count * 20:
		attempts += 1
		var p := Vector2(rng.randf_range(-0.5, 0.5) * area_size.x, rng.randf_range(-0.5, 0.5) * area_size.y)
		if exclude_rects.any(func(r: Rect2) -> bool: return r.has_point(p)):
			continue
		var s := 1.0 + rng.randf_range(-size_variation, size_variation)
		var rot := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		transforms.append(Transform3D(rot, Vector3(p.x, 0.0, p.y)))

	for entry in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = FoliageTint.apply(entry[0], foliage_gain)
		mm.instance_count = transforms.size()
		var local: Transform3D = fit * (entry[1] as Transform3D)
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i] * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_generated.append(mmi)
