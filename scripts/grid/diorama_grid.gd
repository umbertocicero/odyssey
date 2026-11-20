@tool
class_name DioramaGrid
extends Node3D
## Griglia logica del diorama: converte celle <-> posizioni 3D, tiene traccia
## delle celle bloccate (ostacoli) e di quelle occupate (unità).
##
## Il centro della griglia coincide con l'origine del nodo, sul piano y = 0.
## Gli ostacoli sono nodi 3D nel gruppo "grid_obstacle": la loro cella viene
## calcolata dalla posizione e segnata come bloccata all'avvio. Se il nodo ha
## un metodo get_blocked_cells(grid) (es. GridProp), blocca tutte quelle caselle.

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
var _vaultable: Dictionary = {} # Vector2i -> true se l'ostacolo è basso e si può scavalcare
var _occupants: Dictionary = {} # Vector2i -> Node
var _tiles: MultiMeshInstance3D
var _thin: Array = []            # cerchi {center: Vector2, radius: float} di tronchi e pali
var _thin_cells: Dictionary = {} # caselle di tronchi/pali: per il movimento libero non sono quadrate


func _ready() -> void:
	add_to_group(&"diorama_grid")
	_rebuild_tiles()
	if not Engine.is_editor_hint():
		_register_obstacles()


## Dislivello massimo (in livelli) che si supera con un passo: 1 = scalino.
@export var max_step_levels := 1

var _relief: TerrainRelief
var _relief_searched := false


func cell_to_world(cell: Vector2i) -> Vector3:
	var offset := Vector2(size) * cell_size * 0.5
	var local := Vector3((cell.x + 0.5) * cell_size - offset.x, 0.0, (cell.y + 0.5) * cell_size - offset.y)
	var world := to_global(local)
	world.y += get_height_at_world(world)
	return world


## Rilievo del terreno (livelli di altezza), se il livello ne ha uno.
func get_relief() -> TerrainRelief:
	if not _relief_searched and is_inside_tree():
		_relief_searched = true
		_relief = get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	return _relief


## Livello di altezza di una casella (0 = pianura).
func get_level(cell: Vector2i) -> int:
	var relief := get_relief()
	if relief == null:
		return 0
	var offset := Vector2(size) * cell_size * 0.5
	var local := Vector3((cell.x + 0.5) * cell_size - offset.x, 0.0, (cell.y + 0.5) * cell_size - offset.y)
	var world := to_global(local)
	return relief.level_at_world(world.x, world.z)


## Altezza in metri del terreno in un punto del mondo (anche fuori dalla griglia).
func get_height_at_world(world: Vector3) -> float:
	var relief := get_relief()
	return relief.height_at_world(world.x, world.z) if relief else 0.0


## True se da "from" si può passare in "to" con un passo: il dislivello non
## deve superare max_step_levels (uno scalino sì, una parete di roccia no).
func step_allowed(from: Vector2i, to: Vector2i) -> bool:
	return absi(get_level(from) - get_level(to)) <= max_step_levels


## True se un tiro dal punto "from" al punto "to" non è fermato dal terreno:
## il rilievo in mezzo non deve superare la retta tra i due punti.
func has_line_of_fire(from: Vector3, to: Vector3) -> bool:
	var relief := get_relief()
	if relief == null:
		return true
	var distance := Vector2(to.x - from.x, to.z - from.z).length()
	var steps := maxi(int(ceil(distance / 0.5)), 1)
	for i in range(1, steps):
		var t := float(i) / steps
		var x := lerpf(from.x, to.x, t)
		var z := lerpf(from.z, to.z, t)
		var ray_y := lerpf(from.y, to.y, t)
		if relief.height_at_world(x, z) > ray_y:
			return false
	return true


func world_to_cell(world_position: Vector3) -> Vector2i:
	var local := to_local(world_position)
	var offset := Vector2(size) * cell_size * 0.5
	return Vector2i(floori((local.x + offset.x) / cell_size), floori((local.z + offset.y) / cell_size))


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func get_occupant(cell: Vector2i) -> Node:
	return _occupants.get(cell) as Node


## True se la casella è bloccata da ostacoli bassi (casse, scudi, sassi, barili...)
## che si possono scavalcare con un balzo. Muri, mura, torri, tende, alberi e
## rocce grandi non lo sono.
func is_vaultable(cell: Vector2i) -> bool:
	return _blocked.has(cell) and _vaultable.get(cell, false)


## True se da `from` si può scavalcare in direzione `dir`: davanti c'è un
## ostacolo basso, e subito dopo una casella libera dove atterrare.
func can_vault_over(from: Vector2i, dir: Vector2i) -> bool:
	var over := from + dir
	var landing := over + dir
	if not is_inside(over) or not is_inside(landing) or not is_vaultable(over):
		return false
	if is_blocked(landing) or _occupants.has(landing):
		return false
	return step_allowed(from, over) and step_allowed(over, landing)


## Caselle bloccate da oggetti che non si scavalcano (costruzioni, torri, tende,
## alberi, rocce grandi): serve a tenere l'erba lontana dalle loro basi.
func get_solid_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in _blocked:
		if not _vaultable.get(c, false):
			out.append(c)
	return out


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


## Restituisce le caselle libere da ostacoli che non si possono raggiungere
## partendo da start (le unità non contano: si spostano o si scambiano).
## Una lista vuota significa che il livello non ha caselle chiuse.
func find_unreachable_cells(start: Vector2i) -> Array[Vector2i]:
	var reached := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := current + direction
			if is_inside(next) and not is_blocked(next) and not reached.has(next) and step_allowed(current, next):
				reached[next] = true
				frontier.append(next)
	var unreachable: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if not is_blocked(c) and not reached.has(c):
				unreachable.append(c)
	return unreachable


## Controlla che da start si possano raggiungere tutte le caselle libere;
## altrimenti avvisa nel log quali caselle sono chiuse dagli ostacoli.
func validate_connectivity(start: Vector2i) -> bool:
	if is_blocked(start):
		push_warning("DioramaGrid: la casella di partenza %s è bloccata da un ostacolo." % start)
		return false
	var unreachable := find_unreachable_cells(start)
	if not unreachable.is_empty():
		push_warning("DioramaGrid: caselle chiuse dagli ostacoli, irraggiungibili: %s" % [unreachable])
		return false
	return true


func _register_obstacles() -> void:
	for node in get_tree().get_nodes_in_group(OBSTACLE_GROUP):
		var low: bool = node.has_method(&"is_vaultable") and node.is_vaultable()
		if node.has_method(&"get_blocked_cells"):
			# Oggetti con un'impronta di più caselle (GridProp).
			var thin: Dictionary = node.thin_shape() if node.has_method(&"thin_shape") else {}
			if not thin.is_empty():
				_thin.append(thin)
			for c: Vector2i in node.get_blocked_cells(self):
				set_blocked(c, true)
				_vaultable[c] = _vaultable.get(c, true) and low
				if not thin.is_empty():
					_thin_cells[c] = true
		elif node is Node3D:
			var c := world_to_cell((node as Node3D).global_position)
			set_blocked(c, true)
			_vaultable[c] = _vaultable.get(c, true) and low


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
	if tile_color_a.a < 1.0 or tile_color_b.a < 1.0:
		# Caselle semitrasparenti: lasciano vedere il terreno sotto.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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


# --- Movimento libero ----------------------------------------------------------
# Le unità controllate dal giocatore si muovono in continuo sul piano XZ come un
# cerchio. Le caselle bloccate sono quadrati, tranne i tronchi e i pali che sono
# cerchi sottili: si passa sotto le chiome e si costeggiano i pali senza incastri.

## Risolve la collisione di un cerchio (centro XZ, raggio) contro ostacoli, bordi
## e pareti di roccia. Restituisce {"pos": Vector2, "vault_cell": Vector2i o null}.
func resolve_circle(pos: Vector2, radius: float, level_cell: Vector2i) -> Dictionary:
	var vault_cell = null
	var base_level := get_level(level_cell)
	for _iter in 2:
		var c := world_to_cell(Vector3(pos.x, 0.0, pos.y))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cc := c + Vector2i(dx, dy)
				if not _cell_solid_for_motion(cc, base_level):
					continue
				var rect := _cell_rect(cc)
				var closest := Vector2(clampf(pos.x, rect.position.x, rect.end.x), clampf(pos.y, rect.position.y, rect.end.y))
				var delta := pos - closest
				var dist := delta.length()
				if dist >= radius:
					continue
				if dist < 0.0001:
					# Centro dentro il quadrato: esce dal lato più vicino.
					var left := pos.x - rect.position.x
					var right := rect.end.x - pos.x
					var up := pos.y - rect.position.y
					var down := rect.end.y - pos.y
					var m := minf(minf(left, right), minf(up, down))
					if m == left: pos.x = rect.position.x - radius
					elif m == right: pos.x = rect.end.x + radius
					elif m == up: pos.y = rect.position.y - radius
					else: pos.y = rect.end.y + radius
				else:
					pos += delta / dist * (radius - dist)
				if _vaultable.get(cc, false) and is_blocked(cc):
					vault_cell = cc
		for thin: Dictionary in _thin:
			var center: Vector2 = thin["center"]
			var r: float = float(thin["radius"]) + radius
			var d := pos - center
			var l := d.length()
			if l < r:
				pos = center + (d / l if l > 0.0001 else Vector2.RIGHT) * r
	return {"pos": pos, "vault_cell": vault_cell}


func _cell_solid_for_motion(c: Vector2i, base_level: int) -> bool:
	if not is_inside(c):
		return true
	if is_blocked(c):
		return not _thin_cells.has(c)
	return absi(get_level(c) - base_level) > max_step_levels


func _cell_rect(c: Vector2i) -> Rect2:
	var offset := Vector2(size) * cell_size * 0.5
	var local := Vector3(c.x * cell_size - offset.x, 0.0, c.y * cell_size - offset.y)
	var world := to_global(local)
	return Rect2(Vector2(world.x, world.z), Vector2.ONE * cell_size)
