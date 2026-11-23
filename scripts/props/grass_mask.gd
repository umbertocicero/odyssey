class_name GrassMask
extends RefCounted
## Maschera di dove può crescere l'erba, per tipo di superficie e non per
## coordinate scritte a mano. Vale per il prato attuale e per quello nuovo:
## basta mettere i nodi giusti in questi gruppi.
##   grass_ground  = terreno erboso (mesh del prato): l'erba cresce solo qui dentro
##   grass_exclude = mare, riva e sabbia, strade, piazzali lastricati: niente erba
## Sono esclusi in automatico anche gli ingombri di costruzioni e oggetti alti
## (tende, torri, carri, alberi...), cioè le caselle bloccanti non scavalcabili.
## Il bordo è sfumato: nella fascia `fade` (metri) la densità scende gradualmente
## fino a zero verso sabbia, sentieri e costruzioni.
## Nodi supportati: MeshInstance3D (si usa il riquadro della mesh, sul piano X-Z)
## e nodi con `area_size` (lastricati, aree): rettangolo centrato sul nodo.

var fade := 0.6
var ground: Array[Rect2] = []
var deny: Array[Rect2] = []
var solid_cells := {}   # Vector2i -> true
## Rientro (m) del rettangolo di una casella solida sui lati senza vicini solidi.
var solid_inset := 0.0
var grid: DioramaGrid
## Strade di terra (DirtRoad): bordo curvo, niente erba sul nastro e sfumatura ai lati.
var roads: Array = []


## skip_hidden_areas: ignora i nodi ad area (lastricati, piazzali) spenti con visible = false.
## inset: vedi solid_inset.
static func from_tree(tree: SceneTree, fade_distance := 0.6, skip_hidden_areas := false, inset := 0.0) -> GrassMask:
	var m := GrassMask.new()
	m.fade = maxf(fade_distance, 0.01)
	m.solid_inset = inset
	for node in tree.get_nodes_in_group(&"grass_ground"):
		var r := _rect_of(node)
		if r.size != Vector2.ZERO:
			m.ground.append(r)
	for node in tree.get_nodes_in_group(&"dirt_road"):
		if node is Node3D and (node as Node3D).visible:
			m.roads.append(node)
	for node in tree.get_nodes_in_group(&"grass_exclude"):
		# I riquadri della strada procedurale cedono il posto alla curva della DirtRoad.
		if not m.roads.is_empty() and node.is_in_group(&"road_rect"):
			continue
		if skip_hidden_areas and not node is MeshInstance3D and node is Node3D and not (node as Node3D).visible:
			continue
		var r := _rect_of(node)
		if r.size != Vector2.ZERO:
			m.deny.append(r)
	m.grid = tree.get_first_node_in_group(&"diorama_grid") as DioramaGrid
	if m.grid:
		for c in m.grid.get_solid_cells():
			m.solid_cells[c] = true
	return m


## Densità relativa (0..1) nel punto (x, z) del mondo: 1 = prato pieno, 0 = niente erba.
func weight(world_xz: Vector2) -> float:
	var w := 1.0
	if not ground.is_empty():
		var best := 0.0
		for r in ground:
			if r.has_point(world_xz):
				var inside := minf(minf(world_xz.x - r.position.x, r.end.x - world_xz.x), minf(world_xz.y - r.position.y, r.end.y - world_xz.y))
				best = maxf(best, clampf(inside / fade, 0.0, 1.0))
		w = best
		if w <= 0.0:
			return 0.0
	for r in deny:
		var d := _distance(world_xz, r)
		if d < fade:
			w = minf(w, d / fade)
			if w <= 0.0:
				return 0.0
	for road in roads:
		var d: float = road.edge_distance(world_xz)
		if d < fade:
			w = minf(w, maxf(d, 0.0) / fade)
			if w <= 0.0:
				return 0.0
	if grid and not solid_cells.is_empty():
		var c := grid.world_to_cell(Vector3(world_xz.x, 0.0, world_xz.y))
		var s := fade * 0.6
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cc := c + Vector2i(dx, dy)
				if solid_cells.has(cc):
					var centre := grid.cell_to_world(cc)
					var half := grid.cell_size * 0.5
					var rect := Rect2(centre.x - half, centre.z - half, grid.cell_size, grid.cell_size)
					if solid_inset > 0.0:
						rect = _inset_cell(rect, cc)
					var d := _distance(world_xz, rect)
					if d < s:
						w = minf(w, d / s)
						if w <= 0.0:
							return 0.0
	return w


## Rettangolo della casella rientrato di solid_inset sui lati che non confinano con altre caselle solide.
func _inset_cell(rect: Rect2, c: Vector2i) -> Rect2:
	var left := 0.0 if solid_cells.has(c + Vector2i(-1, 0)) else solid_inset
	var right := 0.0 if solid_cells.has(c + Vector2i(1, 0)) else solid_inset
	var top := 0.0 if solid_cells.has(c + Vector2i(0, -1)) else solid_inset
	var bottom := 0.0 if solid_cells.has(c + Vector2i(0, 1)) else solid_inset
	return Rect2(rect.position.x + left, rect.position.y + top, rect.size.x - left - right, rect.size.y - top - bottom)


## Vero se in quel punto cresce erba (densità piena o sfumata).
func allows(world_xz: Vector2) -> bool:
	return weight(world_xz) > 0.0


static func _distance(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dy := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	return sqrt(dx * dx + dy * dy)


static func _rect_of(node: Node) -> Rect2:
	var n3 := node as Node3D
	if n3 == null:
		return Rect2()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var b := n3.global_transform * (node as MeshInstance3D).mesh.get_aabb()
		return Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
	var size = node.get("area_size")
	if size is Vector2:
		var c := n3.global_position
		return Rect2(c.x - size.x * 0.5, c.z - size.y * 0.5, size.x, size.y)
	return Rect2()
