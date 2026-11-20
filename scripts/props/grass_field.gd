class_name GrassField
extends Node3D
## Campo d'erba che si muove: migliaia di ciuffi in un solo MultiMesh, piegati
## da uno shader (assets/shaders/grass.gdshader). Oltre al vento leggero, il
## campo reagisce agli oggetti 3D che lo toccano: personaggi (Ulisse, soldati
## achei e troiani), proiettili in volo e caselle in fiamme. Ogni interattore è
## una posizione con un raggio, passata allo shader come uniform; le posizioni
## sono ammorbidite, quindi l'erba si piega subito e si rialza piano, e un
## interattore che sparisce svanisce gradualmente invece di scattare.
## Il costo è basso: un solo disegno, al massimo MAX_INTERACTORS interattori,
## nessuna texture.

const MAX_INTERACTORS := 12
const SHADER := preload("res://assets/shaders/grass.gdshader")

@export_group("Campo")
## Vecchio prato procedurale: con il terreno fotorealistico (TerrainStyle.photo())
## non viene costruito, lo sostituisce GrassCards. Spegnere per averlo sempre.
@export var procedural_only := false
## Area (X, Z) centrata sul nodo in cui crescono i ciuffi.
@export var area_size := Vector2(40, 40)
## Spostamento del centro dell'area (X, Z), nelle stesse coordinate locali.
@export var area_offset := Vector2.ZERO
## Maschera per tipo di superficie (gruppi grass_ground e grass_exclude, vedi GrassMask):
## niente erba su mare, riva, sabbia, strade, piazzali e sotto le costruzioni.
@export var use_surface_mask := true
## Larghezza della fascia in cui l'erba sfuma verso sabbia, sentieri e costruzioni (m).
@export_range(0.05, 3.0) var mask_fade := 0.6
## Rettangoli (coordinate locali X, Z) senza erba, in più rispetto alla maschera.
@export var exclude_rects: Array[Rect2] = []
@export_range(0, 30000) var count := 4200
@export var random_seed := 21
## Altezza media di un ciuffo, in metri.
@export_range(0.1, 1.5) var blade_height := 0.42
## Variazione casuale dell'altezza (0.3 = ±30%).
@export_range(0.0, 0.8) var height_variation := 0.35
## Larghezza dei fili (1 = quella base del ciuffo).
@export_range(0.5, 4.0) var blade_width := 1.0
## Fili per ciuffo (più fili = prato più fitto a parità di istanze).
@export_range(3, 8) var blades_per_tuft := 3
@export var base_color := Color(0.24, 0.36, 0.11)
@export var tip_color := Color(0.50, 0.60, 0.23)

@export_group("Vento")
## Quanto si piegano i fili col vento, in metri alla punta.
@export_range(0.0, 0.5) var wind_strength := 0.07
@export_range(0.0, 6.0) var wind_speed := 1.4
## Direzione del vento sul piano, in gradi (0 = verso +X).
@export_range(0.0, 360.0) var wind_direction_degrees := 37.0

@export_group("Interazione")
## Di quanto si sposta la punta di un filo al centro di un interattore, in metri.
@export_range(0.0, 1.5) var push_strength := 0.7
## Moltiplicatore del raggio d'azione di tutti gli interattori.
@export_range(0.2, 3.0) var radius_scale := 1.0
## Rigidità: quanto in fretta l'erba segue l'oggetto e si rialza (1/s).
## Più è alta, più l'erba torna subito dritta; più è bassa, più resta piegata a lungo.
@export_range(1.0, 30.0) var stiffness := 7.0
## Raggi d'azione per tipo di interattore, in metri.
@export var unit_radius := 1.2
@export var projectile_radius := 0.7
@export var fire_radius := 1.0
@export var interaction_enabled := true

var material: ShaderMaterial
var multimesh_instance: MultiMeshInstance3D
# id dell'oggetto -> {pos: Vector3, radius: float, alpha: float, seen: bool}
var _tracked: Dictionary = {}
var _uniform := PackedVector4Array()
var _reference: Node3D
## Posizioni locali dei ciuffi generati (per test e diagnostica; in headless il MultiMesh non le conserva).
var tuft_positions := PackedVector3Array()


func _ready() -> void:
	if procedural_only and TerrainStyle.photo():
		visible = false
		set_process(false)
		return
	_uniform.resize(MAX_INTERACTORS)
	_build()


func _build() -> void:
	var transforms: Array[Vector3] = []
	var customs: Array[Color] = []
	var tints: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var relief := get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	var attempts := 0
	var target := int(count * Quality.density())
	var mask := GrassMask.from_tree(get_tree(), mask_fade) if use_surface_mask else null
	while transforms.size() < target and attempts < target * 30:
		attempts += 1
		var p := area_offset + Vector2(rng.randf_range(-0.5, 0.5) * area_size.x, rng.randf_range(-0.5, 0.5) * area_size.y)
		var blocked := false
		for rect in exclude_rects:
			if rect.has_point(p):
				blocked = true
				break
		if blocked:
			continue
		var world := global_transform * Vector3(p.x, 0.0, p.y)
		if mask:
			var w := mask.weight(Vector2(world.x, world.z))
			if w < 1.0 and rng.randf() >= w:
				continue
		var ground := relief.height_at_world(world.x, world.z) if relief else 0.0
		transforms.append(Vector3(p.x, ground, p.y))
		var scale_y := blade_height * (1.0 + rng.randf_range(-height_variation, height_variation))
		customs.append(Color(rng.randf() * TAU, scale_y, rng.randf(), 0.0))
		var v := rng.randf_range(0.85, 1.12)
		tints.append(Color(v, v * rng.randf_range(0.95, 1.05), v * rng.randf_range(0.85, 1.0)))

	tuft_positions = PackedVector3Array(transforms)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _tuft_mesh(blade_width, blades_per_tuft)
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, transforms[i]))
		mm.set_instance_color(i, tints[i])
		mm.set_instance_custom_data(i, customs[i])

	material = ShaderMaterial.new()
	material.shader = SHADER
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "Ciuffi"
	multimesh_instance.multimesh = mm
	multimesh_instance.material_override = material
	multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# I fili si piegano nello shader: il riquadro di visibilità va allargato.
	multimesh_instance.extra_cull_margin = 2.0
	add_child(multimesh_instance)
	_apply_parameters()


## Un ciuffo: tre fili a nastro incrociati, ognuno a tre segmenti (base, metà,
## punta) così si piega in modo morbido. UV.y è la frazione d'altezza.
static func _tuft_mesh(width := 1.0, blades := 3) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var blade_lean := [0.05, -0.04, 0.06, 0.03, -0.06, 0.04, -0.03, 0.05]
	for b in blades:
		var a: float = b * TAU / blades + 0.35 * b
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var offset := dir * 0.05
		var lean: float = blade_lean[b]
		var base := vertices.size()
		# Righe: base larga, metà, punta. Ogni riga ha due vertici (tranne la punta).
		var rows := [[0.0, 0.07], [0.5, 0.05], [1.0, 0.0]]
		for row: Array in rows:
			var h: float = row[0]
			var half: float = row[1] * width
			var centre := offset + Vector3(0, h, 0) + dir * lean * h
			vertices.append(centre - side * half)
			vertices.append(centre + side * half)
			uvs.append(Vector2(0, h))
			uvs.append(Vector2(1, h))
			colors.append(Color.WHITE)
			colors.append(Color.WHITE)
		# Due quadrilateri (base-metà, metà-punta) come triangoli.
		for r in 2:
			var i0 := base + r * 2
			indices.append_array([i0, i0 + 1, i0 + 2, i0 + 1, i0 + 3, i0 + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _apply_parameters() -> void:
	if material == null:
		return
	material.set_shader_parameter(&"base_color", base_color)
	material.set_shader_parameter(&"tip_color", tip_color)
	material.set_shader_parameter(&"wind_strength", wind_strength)
	material.set_shader_parameter(&"wind_speed", wind_speed)
	var a := deg_to_rad(wind_direction_degrees)
	material.set_shader_parameter(&"wind_direction", Vector2(cos(a), sin(a)))
	material.set_shader_parameter(&"push_strength", push_strength)
	material.set_shader_parameter(&"interactors", _uniform)


func _process(delta: float) -> void:
	if material == null:
		return
	_apply_parameters()
	if not interaction_enabled:
		_uniform.fill(Vector4.ZERO)
		material.set_shader_parameter(&"interactors", _uniform)
		return
	_collect_sources()
	_update_tracked(delta)
	_write_uniform()


## Interattori in questo momento attivi (con influenza visibile), per i test.
func active_interactor_count() -> int:
	var n := 0
	for entry: Dictionary in _tracked.values():
		if entry["alpha"] > 0.05:
			n += 1
	return n


## Posizione (ammorbidita) di un oggetto tracciato, oppure null se non c'è.
func tracked_position(node: Node3D) -> Variant:
	var entry: Variant = _tracked.get(node.get_instance_id())
	return entry["pos"] if entry else null


func _collect_sources() -> void:
	for entry: Dictionary in _tracked.values():
		entry["seen"] = false
	for node in get_tree().get_nodes_in_group(&"units"):
		_see(node as Node3D, unit_radius)
	for node in get_tree().get_nodes_in_group(&"projectiles"):
		_see(node as Node3D, projectile_radius)
	for node in get_tree().get_nodes_in_group(&"burning_cells"):
		_see(node as Node3D, fire_radius)


func _see(node: Node3D, radius: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	var id := node.get_instance_id()
	var entry: Dictionary = _tracked.get(id, {})
	if entry.is_empty():
		entry = {"pos": node.global_position, "radius": radius, "alpha": 0.0, "seen": true}
		_tracked[id] = entry
	entry["seen"] = true
	entry["radius"] = radius
	entry["target"] = node.global_position


func _update_tracked(delta: float) -> void:
	var follow := 1.0 - exp(-stiffness * delta)
	var fade := 1.0 - exp(-stiffness * 0.6 * delta)
	var gone: Array = []
	for id: int in _tracked:
		var entry: Dictionary = _tracked[id]
		if entry["seen"]:
			var target: Vector3 = entry["target"]
			var pos: Vector3 = entry["pos"]
			# Salti grandi (teletrasporto, rinascita): niente scia attraverso il campo.
			if pos.distance_to(target) > 2.5:
				entry["pos"] = target
				entry["alpha"] = 0.0
			else:
				entry["pos"] = pos.lerp(target, follow)
			entry["alpha"] = lerpf(entry["alpha"], 1.0, fade)
		else:
			# L'oggetto non c'è più: l'influenza svanisce piano.
			entry["alpha"] = lerpf(entry["alpha"], 0.0, fade)
			if entry["alpha"] < 0.02:
				gone.append(id)
	for id in gone:
		_tracked.erase(id)


func _write_uniform() -> void:
	if _reference == null or not is_instance_valid(_reference):
		_reference = get_tree().get_first_node_in_group(&"player") as Node3D
	var centre := _reference.global_position if _reference else global_position
	# I più vicini al giocatore (o al centro del campo) hanno la precedenza.
	var entries: Array = _tracked.values()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["pos"] as Vector3).distance_squared_to(centre) < (b["pos"] as Vector3).distance_squared_to(centre))
	for i in MAX_INTERACTORS:
		if i < entries.size():
			var entry: Dictionary = entries[i]
			var p: Vector3 = entry["pos"]
			_uniform[i] = Vector4(p.x, p.y, p.z, entry["radius"] * radius_scale * entry["alpha"])
		else:
			_uniform[i] = Vector4.ZERO
