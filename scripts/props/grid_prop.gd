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
## Modello più leggero usato a qualità bassa e media (web, mobile) al posto di `model`
## (per esempio un albero da 9.000 triangoli invece di uno da 40.000). Vuoto = sempre `model`.
@export var low_quality_model: PackedScene
## Percorso del modello caricato solo se serve (alta qualità, o sempre se non c'è `low_quality_model`,
## e solo da `min_quality` in su): le texture di ciò che non si vede non finiscono in VRAM.
@export_file("*.gltf", "*.glb", "*.tscn") var lazy_model_path := ""

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
## Si può scavalcare? Auto = sì se l'oggetto è piccolo (una casella, al massimo
## vault_max_size metri di altezza reale): casse, scudi, barili, sassi, recinti. No = muro vero e proprio.
@export_enum("Auto", "Yes", "No") var vault_mode := 0
@export_range(0.5, 3.0) var vault_max_size := 1.1
## Raggio del tronco (alberi) o del palo: se > 0 l'oggetto blocca solo un cerchio
## di questo raggio e non tutta l'impronta. 0 = automatico (alberi e pali sottili).
@export var trunk_radius := 0.0
@export var cast_shadows := true:
	set(value):
		cast_shadows = value
		_rebuild()
## Moltiplicatore dell'albedo del fogliame (materiali alpha-cutout) per i modelli Poly Haven,
## che alla fonte sono molto scuri (vedi FoliageTint). Bianco = nessuna correzione.
## Tinta moltiplicata sull'albedo di tutti i materiali (smorza i colori vivaci). Bianco = nessuna.
@export var tint := Color(1, 1, 1):
	set(value):
		tint = value
		_rebuild()
## Quanto togliere ai colori vivaci dei materiali senza texture (0 = niente, 1 = grigio) prima della tinta.
@export_range(0.0, 1.0) var desaturate := 0.0:
	set(value):
		desaturate = value
		_rebuild()
## Qualità minima per mostrare il modello (0 = sempre, 1 = media e alta, 2 = solo alta): i decori
## lontani (cavalli, carri) spariscono a bassa qualità. Le collisioni non cambiano.
@export_range(0, 2) var min_quality := 0
@export var foliage_gain := Color(1, 1, 1):
	set(value):
		foliage_gain = value
		_rebuild()

var _visual: Node3D
var _height := -1.0
var _box := AABB()
var _box_ready := false


func _enter_tree() -> void:
	if blocking:
		add_to_group(&"grid_obstacle")


func _ready() -> void:
	_load_lazy()
	_rebuild()
	set_process(not Engine.is_editor_hint() and is_tree())


## Chioma semitrasparente quando un personaggio ci passa sotto, così non
## sparisce dietro le foglie.
@export var canopy_fade_radius := 2.2
@export_range(0.0, 1.0) var canopy_fade_amount := 0.7
var _fade := 0.0
var _player: Node3D


func _process(delta: float) -> void:
	if _visual == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	var d := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
	var target := 1.0 if d < canopy_fade_radius else 0.0
	if is_equal_approx(_fade, target):
		return
	_fade = move_toward(_fade, target, delta * 4.0)
	for child in _visual.get_children():
		var mi := child as MeshInstance3D
		if mi:
			mi.transparency = _fade * canopy_fade_amount


## Per PropBatcher: toglie il nodo visivo e restituisce le sue mesh come lista di
## {"mesh", "transform"} in coordinate del mondo, così più copie dello stesso modello
## si disegnano con un solo MultiMesh. L'oggetto resta nella griglia (collisioni invariate).
func take_visual() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _visual == null or not is_inside_tree():
		return result
	for child in _visual.get_children():
		var mi := child as MeshInstance3D
		if mi and mi.mesh:
			result.append({"mesh": mi.mesh, "transform": mi.global_transform})
	_visual.queue_free()
	_visual = null
	return result


## Una chiave uguale per oggetti con lo stesso aspetto (stesso modello, pezzo, misura): solo quelli si uniscono.
func visual_key() -> String:
	if _active_model() == null or is_tree():
		return ""
	return "%s|%s|%s|%d|%s|%s|%s|%s" % [_active_model().resource_path, piece, model_rotation_degrees, fit_axis, fit_size, cast_shadows, tint, desaturate]


## True se i personaggi possono scavalcare questo oggetto con un balzo.
func is_vaultable() -> bool:
	if vault_mode == 1:
		return true
	if vault_mode == 2:
		return false
	return visual_height() <= vault_max_size


## Il modello da mostrare: quello leggero a qualità bassa e media, se c'è.
func _load_lazy() -> void:
	if model != null or lazy_model_path == "" or int(Quality.current()) < min_quality:
		return
	if low_quality_model != null and Quality.current() != Quality.Level.HIGH:
		return
	model = load(lazy_model_path) as PackedScene


func _active_model() -> PackedScene:
	if low_quality_model != null and Quality.current() != Quality.Level.HIGH:
		return low_quality_model
	return model


## Altezza reale del modello dopo l'adattamento (non la misura di fit_size,
## che può riferirsi alla larghezza). Calcolata dalle mesh, anche prima che
## il nodo visivo esista.
func visual_height() -> float:
	_compute_box()
	return _height


## Ingombro reale del modello dopo l'adattamento (metri).
func visual_size() -> Vector3:
	_compute_box()
	return _box.size


## Albero: ha una chioma che non ostacola e un tronco sottile.
func is_tree() -> bool:
	var n := String(name).to_lower()
	return n.begins_with("cipresso") or n.begins_with("ulivo") or n.begins_with("albero") or is_in_group(&"tree")


## Cerchio di collisione (centro XZ, raggio) se l'oggetto è un tronco o un palo
## sottile; altrimenti un dizionario vuoto (valgono le caselle quadrate).
func thin_shape() -> Dictionary:
	if not blocking or not blocked_cells_in_footprint.is_empty():
		return {}
	var c := Vector2(global_position.x, global_position.z)
	if trunk_radius > 0.0:
		return {"center": c, "radius": trunk_radius}
	if is_tree():
		return {"center": c, "radius": 0.45 if footprint.x >= 2 else 0.3}
	var size := visual_size()
	if footprint == Vector2i.ONE and visual_height() >= 1.4 and not is_vaultable() \
			and minf(size.x, size.z) <= 0.7:
		return {"center": c, "radius": clampf(minf(size.x, size.z) * 0.5 + 0.04, 0.14, 0.4)}
	return {}


func _compute_box() -> void:
	if _box_ready:
		return
	_box_ready = true
	if _active_model() == null:
		_height = 0.0
		return
	var meshes := ModelFit.extract_meshes(_active_model(), piece)
	var fit := ModelFit.fit_transform(meshes, model_rotation_degrees, fit_axis, fit_size)
	var box := AABB()
	var first := true
	for entry in meshes:
		var b: AABB = (fit * (entry[1] as Transform3D)) * (entry[0] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	_box = box
	_height = 0.0 if first else box.size.y


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
	_height = -1.0
	_box_ready = false
	if not is_inside_tree():
		return
	if _visual:
		_visual.queue_free()
		_visual = null
	if _active_model() == null or int(Quality.current()) < min_quality:
		return
	var meshes := ModelFit.extract_meshes(_active_model(), piece)
	var fit := ModelFit.fit_transform(meshes, model_rotation_degrees, fit_axis, fit_size)
	# Nodi generati: senza owner, quindi non vengono salvati nella scena.
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	for entry in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = FoliageTint.apply(entry[0], foliage_gain, tint, desaturate)
		mi.transform = fit * (entry[1] as Transform3D)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(mi)
