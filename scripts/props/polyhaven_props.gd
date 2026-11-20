class_name PolyhavenProps
extends Node3D
## Props Poly Haven di un livello, guidati dai dati (file JSON in data/props/).
##
## - "items": oggetti singoli e solidi (rocce, abeti, tronchi, pareti di roccia).
##   Diventano GridProp: occupano caselle, i tronchi bloccano solo un cerchio
##   sottile e la chioma si attraversa diventando semitrasparente.
## - "scatters": piante, fiori e ciuffi sparsi in un rettangolo con MultiMesh
##   (una chiamata di disegno per variante). Rispettano la maschera dell'erba
##   (strade, piazzali, sabbia) e le caselle bloccate.
##
## Budget per piattaforma: ogni modello ha una qualità minima nel catalogo, e
## i conteggi degli sparsi si moltiplicano per Quality.density() (web 0.35,
## mobile 0.7, PC 1.0).
##
## Importante: questo nodo va messo PRIMA di "Griglia" nella scena del livello,
## così gli oggetti solidi sono già nel gruppo grid_obstacle quando la griglia
## li registra. Gli sparsi si costruiscono dopo (differiti), a griglia pronta.

@export_file("*.json") var data_path := ""
## Forza una qualità (-1 = automatica da Quality).
@export var quality_override := -1

var stats := {"solid_nodes": 0, "solid_tris": 0, "scatter_instances": 0, "scatter_tris": 0, "multimeshes": 0, "skipped": []}

## Le texture del fogliame Poly Haven sono molto scure (media sRGB ~24,22,8, linear ~0.01):
## sotto la luce calda del diorama diventano nere. Il fogliame (materiali
## alpha-cutout di alberi e arbusti) viene schiarito con questo fattore,
## senza toccare i file. Non si applica ai fiori.
@export var foliage_gain := Color(5.5, 12.0, 6.0)

var _quality := 2
var _relief: TerrainRelief
var _tuned: Dictionary = {}   # Material -> Material schiarito
var _tuned_meshes: Dictionary = {}   # id -> Mesh sostituiti


func _ready() -> void:
	_quality = quality_override if quality_override >= 0 else int(Quality.current())
	_relief = get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	var data := _load_data()
	if data.is_empty():
		return
	for item: Dictionary in data.get("items", []):
		_add_solid(item)
	_build_scatters.call_deferred(data.get("scatters", []))


func _load_data() -> Dictionary:
	if data_path == "" or not FileAccess.file_exists(data_path):
		push_warning("PolyhavenProps: file di dati assente (%s)" % data_path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if parsed is Dictionary:
		return parsed
	push_warning("PolyhavenProps: JSON non valido (%s)" % data_path)
	return {}


func _ground(x: float, z: float) -> float:
	return _relief.height_at_world(x, z) if _relief else 0.0


# --- Oggetti solidi ---------------------------------------------------------

func _add_solid(item: Dictionary) -> void:
	var id: String = item.get("id", "")
	if not PolyhavenCatalog.allowed(id, _quality):
		# Con qualità bassa si usa l'eventuale sostituto leggero ("fallback").
		id = item.get("fallback", "")
		if not PolyhavenCatalog.allowed(id, _quality):
			stats["skipped"].append(item.get("id", "?"))
			return
	var scene := PolyhavenCatalog.get_scene(id)
	if scene == null:
		stats["skipped"].append(id)
		return
	var pos: Array = item["pos"]
	var height: float = item.get("height", 1.0)
	var role := PolyhavenCatalog.role(id)
	var prop := GridProp.new()
	prop.name = item.get("name", "%s_%d" % [id, get_child_count()])
	prop.model = scene
	prop.fit_axis = ModelFit.Axis.HEIGHT if item.get("fit", "height") == "height" else ModelFit.Axis.LONGEST
	prop.fit_size = height
	# Attrezzi e basamenti piatti non bloccano la griglia; il resto sì (salvo "blocking": false).
	prop.blocking = item.get("blocking", role != PolyhavenCatalog.Role.TOOL and role != PolyhavenCatalog.Role.GROUND)
	if item.has("rotate"):
		prop.model_rotation_degrees = Vector3(item["rotate"][0], item["rotate"][1], item["rotate"][2])
	prop.cast_shadows = true
	var meshes := ModelFit.extract_meshes(scene, "")
	var fit := ModelFit.fit_transform(meshes, Vector3.ZERO, prop.fit_axis, height)
	var box := AABB()
	var first := true
	for entry in meshes:
		var b: AABB = (fit * (entry[1] as Transform3D)) * (entry[0] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var yaw: float = item.get("yaw", 0.0)
	if role == PolyhavenCatalog.Role.TREE:
		# Chioma attraversabile: blocca solo il fusto.
		prop.add_to_group(&"tree")
		prop.trunk_radius = item.get("trunk_radius", clampf(box.size.x * 0.035, 0.18, 0.45))
		prop.footprint = Vector2i.ONE
		prop.canopy_fade_radius = box.size.x * 0.5
	else:
		prop.footprint = Vector2i(maxi(1, roundi(box.size.x * 0.8)), maxi(1, roundi(box.size.z * 0.8)))
		if item.has("footprint"):
			prop.footprint = Vector2i(int(item["footprint"][0]), int(item["footprint"][1]))
		if role == PolyhavenCatalog.Role.ROCK:
			prop.vault_mode = 1 if box.size.y <= 1.1 else 2
		elif role == PolyhavenCatalog.Role.WALL or role == PolyhavenCatalog.Role.CLIFF:
			prop.vault_mode = 2
	add_child(prop)
	_tune_visual(prop, role)
	prop.global_position = Vector3(pos[0], _ground(pos[0], pos[1]) - float(item.get("sink", 0.0)), pos[1])
	prop.rotation.y = deg_to_rad(yaw)
	stats["solid_nodes"] += 1
	stats["solid_tris"] += PolyhavenCatalog.tris(id)


# --- Fogliame -----------------------------------------------------------------

func _wants_gain(role: int) -> bool:
	return role == PolyhavenCatalog.Role.TREE or role == PolyhavenCatalog.Role.PLANT


func _tuned_material(mat: Material) -> Material:
	var base := mat as BaseMaterial3D
	if base == null or base.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		return mat
	if not _tuned.has(mat):
		var copy := base.duplicate() as BaseMaterial3D
		copy.albedo_color = Color(base.albedo_color.r * foliage_gain.r, base.albedo_color.g * foliage_gain.g,
			base.albedo_color.b * foliage_gain.b, base.albedo_color.a)
		_tuned[mat] = copy
	return _tuned[mat]


func _tune_visual(prop: GridProp, role: int) -> void:
	if not _wants_gain(role):
		return
	for mi in prop.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i)
			if mat != null:
				var t := _tuned_material(mat)
				if t != mat:
					m.set_surface_override_material(i, t)


func _tuned_mesh(id: String, mesh: Mesh) -> Mesh:
	if not _wants_gain(PolyhavenCatalog.role(id)):
		return mesh
	var key := str(mesh.get_instance_id())
	if not _tuned_meshes.has(key):
		var copy := mesh.duplicate() as Mesh
		for i in copy.get_surface_count():
			var mat := copy.surface_get_material(i)
			if mat != null:
				copy.surface_set_material(i, _tuned_material(mat))
		_tuned_meshes[key] = copy
	return _tuned_meshes[key]


# --- Sparsi (MultiMesh) -----------------------------------------------------

func _build_scatters(scatters: Array) -> void:
	var mask := GrassMask.from_tree(get_tree())
	var grid := get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var density: float = Quality.density() if quality_override < 0 else [0.35, 0.7, 1.0][_quality]
	for sc: Dictionary in scatters:
		var ids: Array[String] = []
		for id: String in sc.get("ids", []):
			if PolyhavenCatalog.allowed(id, _quality) and PolyhavenCatalog.get_scene(id) != null:
				ids.append(id)
		if ids.is_empty():
			stats["skipped"].append(str(sc.get("name", "scatter")))
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(sc.get("seed", 1))
		var rect: Array = sc["rect"]
		var count := int(round(float(sc.get("count", 20)) * density))
		var hmin: float = sc.get("height", [0.4, 0.6])[0]
		var hmax: float = sc.get("height", [0.4, 0.6])[1]
		var min_weight: float = sc.get("min_grass", 0.6)
		var respect_mask: bool = sc.get("use_mask", true)
		var per_id: Dictionary = {}
		for id in ids:
			per_id[id] = []
		var tries := 0
		var placed := 0
		while placed < count and tries < count * 12:
			tries += 1
			var x := rng.randf_range(rect[0], rect[0] + rect[2])
			var z := rng.randf_range(rect[1], rect[1] + rect[3])
			if respect_mask and mask.weight(Vector2(x, z)) < min_weight:
				continue
			if grid and grid.is_inside(grid.world_to_cell(Vector3(x, 0, z))) and grid.is_blocked(grid.world_to_cell(Vector3(x, 0, z))):
				continue
			var id: String = ids[rng.randi() % ids.size()]
			var h := rng.randf_range(hmin, hmax)
			(per_id[id] as Array).append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * h),
				Vector3(x, _ground(x, z), z)))
			placed += 1
		for id: String in per_id:
			_emit_multimesh(id, per_id[id], sc.get("cast_shadows", false), sc.get("name", "scatter"))


func _emit_multimesh(id: String, transforms: Array, shadows: bool, label: String) -> void:
	if transforms.is_empty():
		return
	var meshes := ModelFit.extract_meshes(PolyhavenCatalog.get_scene(id), "")
	# Altezza 1 m come base: poi ogni istanza scala all'altezza voluta.
	var fit := ModelFit.fit_transform(meshes, Vector3.ZERO, ModelFit.Axis.HEIGHT, 1.0)
	var part_index := 0
	for entry in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _tuned_mesh(id, entry[0])
		mm.instance_count = transforms.size()
		var local: Transform3D = fit * (entry[1] as Transform3D)
		for i in transforms.size():
			mm.set_instance_transform(i, (transforms[i] as Transform3D) * local)
		var inst := MultiMeshInstance3D.new()
		inst.name = "%s_%s_%d" % [label, id, part_index]
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		part_index += 1
		stats["multimeshes"] += 1
	stats["scatter_instances"] += transforms.size()
	stats["scatter_tris"] += transforms.size() * PolyhavenCatalog.tris(id)
