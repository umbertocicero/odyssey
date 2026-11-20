class_name GrassCards
extends Node3D
## Prato fotorealistico: ciuffi d'erba a cards alpha-cutout (erba_ciuffi.gltf)
## sparsi con GPU instancing. Un MultiMeshInstance3D per ogni variante e per
## ogni blocco di `block_size` metri, così Godot scarta i blocchi fuori
## dall'inquadratura. Dove crescono lo decidono le maschere del terreno
## (T_terreno_maschere: densità e secchezza; T_terreno_maschere2: altezza e
## chiazze di colore) e GrassMask (gruppi grass_ground / grass_exclude e
## caselle solide), come per GrassField. Il numero di ciuffi segue
## Quality.grass_budget(). I personaggi, i proiettili e il fuoco piegano i fili
## (stesse sorgenti di GrassField). Attivo solo con TerrainStyle.photo().

const MODEL := preload("res://assets/models/custom/terreno/erba_ciuffi.gltf")
const SHADER := preload("res://assets/shaders/grass_cards.gdshader")
const TEX_DIR := "res://assets/models/custom/terreno/textures/"
const MAX_INTERACTORS := 12

## Pesi suggeriti dal README del terreno. R = altezza macro dell'erba (0..1).
const GREEN := {
	"Erba_Alta": 3.0, "Erba_Media": 4.0, "Erba_Bassa": 3.0, "Prato_Denso_A": 5.0,
	"Prato_Denso_C": 5.0, "Erbacce_Foglie": 0.7, "Fiori_Selvatici": 0.6,
}
const DRY := {
	"Erba_PunteSecche": 4.0, "Erba_Secca": 3.0, "Prato_Denso_B": 5.0, "Erba_Media": 2.0,
	"Graminacee_Semi": 0.7,
}
## Varianti ammesse a qualità bassa: poche mesh = pochi disegni.
const LOW_VARIANTS := ["Prato_Denso_A", "Prato_Denso_B", "Prato_Denso_C", "Erba_Media", "Prato_Alto", "Erba_Lunga"]

@export var enabled := true
## Angolo nord-ovest e dimensioni dell'area delle maschere (come TerrainRelief).
@export var origin := Vector2(-26, -30)
@export var map_size := Vector2(52, 52)
## Lato dei blocchi di culling (m): x2 a qualità media, x4 a bassa (meno MultiMesh = meno draw call).
@export_range(2.0, 32.0) var block_size := 8.0
## Moltiplicatore del budget di ciuffi (1 = Quality.grass_budget()).
@export_range(0.1, 4.0) var density_scale := 1.0
@export var random_seed := 5
## Larghezza della fascia in cui l'erba sfuma verso sabbia, sentieri e costruzioni (m).
@export_range(0.05, 3.0) var mask_fade := 0.5
@export var tint := Color(0.86, 1.04, 0.80)
@export var dry_tint := Color(1.08, 1.0, 0.76)
## Quota dei ciuffi secchi sul totale (la maschera dà la secchezza, qui la si riduce: verdi freschi con punte secche).
@export_range(0.0, 1.0) var dry_share := 0.45

@export_group("Vento")
@export var wind_direction := Vector2(1.0, 0.3)
@export_range(0.0, 0.6) var wind_strength := 0.12
@export_range(0.0, 5.0) var wind_speed := 1.2

@export_group("Interazione")
@export var interaction_enabled := true
@export_range(0.2, 3.0) var radius_scale := 1.0
@export_range(1.0, 30.0) var stiffness := 7.0
@export var unit_radius := 1.2
@export var projectile_radius := 0.7
@export var fire_radius := 1.0

var material: ShaderMaterial
## Ciuffi creati (somma dei MultiMesh), per test e statistiche.
var tuft_count := 0
var block_count := 0
var instance_count_by_variant := {}
var triangle_count := 0
var _uniform := PackedVector4Array()
var _tracked: Dictionary = {}
var _reference: Node3D
var _relief: TerrainRelief
var _terrain: PhotoTerrain


func _ready() -> void:
	if not enabled or not TerrainStyle.photo():
		visible = false
		set_process(false)
		return
	_uniform.resize(MAX_INTERACTORS)
	_build()


func _build() -> void:
	var low := Quality.current() == Quality.Level.LOW
	_relief = get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	_terrain = get_tree().get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	var mask := GrassMask.from_tree(get_tree(), mask_fade)
	var m1 := _image("T_terreno_maschere.png")
	var m2 := _image("T_terreno_maschere2.png")
	var meshes := {}
	var root := MODEL.instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		meshes[String(node.name)] = (node as MeshInstance3D).mesh
	root.free()

	var green := GREEN.duplicate()
	var dry := DRY.duplicate()
	var block := block_size * (4.0 if low else (2.0 if Quality.current() == Quality.Level.MEDIUM else 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var target := int(Quality.grass_budget() * density_scale)
	var buckets := {}   # Vector3i(bx, bz, variant index) -> {t, c, d}
	var names: Array = meshes.keys()
	names.sort()
	var placed := 0
	var attempts := 0
	var w1 := m1.get_width()
	var h1 := m1.get_height()
	var w2 := m2.get_width()
	var h2 := m2.get_height()
	while placed < target and attempts < target * 40:
		attempts += 1
		var x := origin.x + rng.randf() * map_size.x
		var z := origin.y + rng.randf() * map_size.y
		var u := (x - origin.x) / map_size.x
		var v := (z - origin.y) / map_size.y
		var a := m1.get_pixel(mini(int(u * w1), w1 - 1), mini(int(v * h1), h1 - 1))
		var b := m2.get_pixel(mini(int(u * w2), w2 - 1), mini(int(v * h2), h2 - 1))
		if a.r > 0.5:
			continue
		var weight := mask.weight(Vector2(x, z))
		if weight <= 0.0 or rng.randf() > a.b * weight:
			continue
		var tall := b.r
		var is_dry := rng.randf() < a.a * dry_share
		var variant := _pick(green if not is_dry else dry, tall, is_dry, low, rng, meshes)
		if variant == "":
			continue
		var y := _ground(x, z) - 0.02
		var scale := (0.5 + tall) * rng.randf_range(0.85, 1.15) * (0.8 + 0.4 * a.b)
		if variant in ["Erba_Lunga", "Erba_Lunga_Secca", "Prato_Alto"]:
			scale = minf(scale, 1.2)
		if low:
			scale *= 1.1
		var colour := tint.lerp(dry_tint, a.a * dry_share * rng.randf_range(0.5, 1.0))
		colour = colour.lerp(Color(1.12, 1.02, 0.78), b.g * 0.2)
		var bright := rng.randf_range(0.9, 1.08)
		colour = Color(colour.r * bright, colour.g * bright, colour.b * bright)
		var key := Vector3i(floori((x - origin.x) / block), floori((z - origin.y) / block), names.find(variant))
		if not buckets.has(key):
			buckets[key] = {"t": [], "c": [], "d": []}
		var bucket: Dictionary = buckets[key]
		bucket["t"].append(Vector3(x - global_position.x, y - global_position.y, z - global_position.z))
		bucket["c"].append(colour)
		bucket["d"].append(Color(rng.randf() * TAU, scale, rng.randf(), 0.0))
		placed += 1

	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"albedo_alpha", load(TEX_DIR + "T_erba_cards_albedo_alpha.png"))
	material.set_shader_parameter(&"card_normal", load(TEX_DIR + "T_erba_cards_normal.png"))
	material.set_shader_parameter(&"sss_rough_ao", load(TEX_DIR + "T_erba_cards_sss_rough_ao.png"))
	_apply_parameters()

	var blocks := {}
	for key: Vector3i in buckets:
		var bucket: Dictionary = buckets[key]
		var variant_name: String = names[key.z]
		var mesh: Mesh = meshes[variant_name]
		var n: int = bucket["t"].size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = n
		for i in n:
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, bucket["t"][i]))
			mm.set_instance_color(i, bucket["c"][i])
			mm.set_instance_custom_data(i, bucket["d"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [variant_name, key.x, key.y]
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Vento e interattori spostano i fili: il riquadro di visibilità va allargato.
		mmi.extra_cull_margin = 1.5
		add_child(mmi)
		blocks[Vector2i(key.x, key.y)] = true
		tuft_count += n
		instance_count_by_variant[variant_name] = instance_count_by_variant.get(variant_name, 0) + n
		triangle_count += n * (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3)
	block_count = blocks.size()


func _pick(table: Dictionary, tall: float, is_dry: bool, low: bool, rng: RandomNumberGenerator, meshes: Dictionary) -> String:
	var weights := table.duplicate()
	var t2 := tall * tall
	if is_dry:
		weights["Erba_Lunga_Secca"] = 6.0 * t2
		weights["Prato_Alto"] = 3.0 * t2
	else:
		weights["Erba_Lunga"] = 6.0 * t2
		weights["Prato_Alto"] = 7.0 * t2
	var total := 0.0
	for k: String in weights:
		if not meshes.has(k) or (low and not k in LOW_VARIANTS):
			weights[k] = 0.0
		total += weights[k]
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for k: String in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return ""


## Quota del terreno: la mesh vera se c'è, altrimenti i livelli di TerrainRelief.
func _ground(x: float, z: float) -> float:
	if _terrain and _terrain.is_active():
		return _terrain.height_at(x, z)
	return _relief.height_at_world(x, z) if _relief else 0.0


func _image(file: String) -> Image:
	var image := (load(TEX_DIR + file) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	return image


func _apply_parameters() -> void:
	if material == null:
		return
	material.set_shader_parameter(&"wind_direction", wind_direction)
	material.set_shader_parameter(&"wind_strength", wind_strength)
	material.set_shader_parameter(&"wind_speed", wind_speed)
	material.set_shader_parameter(&"interactors", _uniform)


func _process(delta: float) -> void:
	if material == null:
		return
	if not interaction_enabled:
		_uniform.fill(Vector4.ZERO)
		material.set_shader_parameter(&"interactors", _uniform)
		return
	_collect_sources()
	_update_tracked(delta)
	_write_uniform()
	material.set_shader_parameter(&"interactors", _uniform)


## Interattori attivi in questo momento (per i test).
func active_interactor_count() -> int:
	var n := 0
	for entry: Dictionary in _tracked.values():
		if entry["alpha"] > 0.05:
			n += 1
	return n


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
			if pos.distance_to(target) > 2.5:
				entry["pos"] = target
				entry["alpha"] = 0.0
			else:
				entry["pos"] = pos.lerp(target, follow)
			entry["alpha"] = lerpf(entry["alpha"], 1.0, fade)
		else:
			entry["alpha"] = lerpf(entry["alpha"], 0.0, fade)
			if entry["alpha"] < 0.02:
				gone.append(id)
	for id in gone:
		_tracked.erase(id)


func _write_uniform() -> void:
	if _reference == null or not is_instance_valid(_reference):
		_reference = get_tree().get_first_node_in_group(&"player") as Node3D
	var centre := _reference.global_position if _reference else global_position
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
