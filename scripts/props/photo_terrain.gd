class_name PhotoTerrain
extends Node3D
## Terreno fotorealistico del livello 1: istanzia terreno_pianura.gltf (PC) o
## terreno_pianura_mobile.gltf (mobile e web) al posto del terreno procedurale.
## La mesh è solo visiva: collisioni, griglia e quote restano su TerrainRelief.
## I nodi del vecchio terreno stanno nel gruppo `procedural_terrain` e vengono
## nascosti (non cancellati: i gruppi grass_ground / grass_exclude servono
## ancora alla maschera dell'erba). Con TerrainStyle.photo() == false (o
## `enabled` spento) non succede niente e resta il terreno procedurale.
##
## Espone height_at() con la quota vera della mesh (colline di pochi cm
## comprese), così l'erba poggia sul terreno senza fluttuare.

const FULL := preload("res://assets/models/custom/terreno/terreno_pianura.gltf")
const MOBILE := preload("res://assets/models/custom/terreno/terreno_pianura_mobile.gltf")
const SPLAT_SHADER := preload("res://assets/models/custom/terreno/godot/terreno_splat.gdshader")
const TEX_DIR := "res://assets/models/custom/terreno/textures/"
const CELLS_PER_METER := 4
const MAX_DETAIL := 0.12

@export var enabled := true
## Qualità piena: shader a 6 strati PBR con splat map invece delle texture cotte.
## Solo a qualità alta (5 sampler, texture array create all'avvio).
@export var use_splat_shader := false
## Usa sempre la mesh mobile (per prove).
@export var force_mobile := false
## Angolo nord-ovest e dimensioni della mappa (come TerrainRelief).
@export var origin := Vector2(-26, -30)
@export var map_size := Vector2(52, 52)

var terrain_instance: Node3D
var surface: MeshInstance3D
var _grid_w := 0
var _grid_h := 0
var _heights := PackedFloat32Array()


func is_active() -> bool:
	return enabled and TerrainStyle.photo()


func _ready() -> void:
	if not is_active():
		return
	add_to_group(&"photo_terrain")
	var mobile := force_mobile or Quality.current() != Quality.Level.HIGH
	terrain_instance = (MOBILE if mobile else FULL).instantiate()
	terrain_instance.name = "TerrenoFoto"
	add_child(terrain_instance)
	for node in terrain_instance.find_children("*Superficie*", "MeshInstance3D", true, false):
		surface = node as MeshInstance3D
	for node in terrain_instance.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if node != surface else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for node in get_tree().get_nodes_in_group(&"procedural_terrain"):
		(node as Node3D).visible = false
	if surface:
		_build_height_grid(surface.mesh)
		var relief := get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
		if relief:
			relief.surface_detail = detail_offset
		if use_splat_shader and not mobile:
			surface.set_surface_override_material(0, _splat_material())


## Quota (m) della superficie nel punto (x, z) del mondo; bilineare sulla griglia
## ricavata dai vertici. Fuori mappa o senza mesh: 0.
func height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var fx := clampf((x - origin.x) * CELLS_PER_METER, 0.0, _grid_w - 1.001)
	var fz := clampf((z - origin.y) * CELLS_PER_METER, 0.0, _grid_h - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := _heights[iz * _grid_w + ix]
	var h10 := _heights[iz * _grid_w + ix + 1]
	var h01 := _heights[(iz + 1) * _grid_w + ix]
	var h11 := _heights[(iz + 1) * _grid_w + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## Scarto della mesh rispetto alla quota a gradini `base` del livello, limitato a ±MAX_DETAIL:
## le colline basse contano, i pendii delle pareti no (lì decide il livello).
func detail_offset(x: float, z: float, base: float) -> float:
	return clampf(height_at(x, z) - base, -MAX_DETAIL, MAX_DETAIL)


func _build_height_grid(mesh: Mesh) -> void:
	_grid_w = int(map_size.x * CELLS_PER_METER) + 1
	_grid_h = int(map_size.y * CELLS_PER_METER) + 1
	var NONE := -1000.0
	_heights.resize(_grid_w * _grid_h)
	_heights.fill(NONE)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Per ogni cella vale il vertice più alto (la cima del terreno, non le pareti).
	for v in vertices:
		var ix := roundi((v.x - origin.x) * CELLS_PER_METER)
		var iz := roundi((v.z - origin.y) * CELLS_PER_METER)
		if ix < 0 or iz < 0 or ix >= _grid_w or iz >= _grid_h:
			continue
		var i := iz * _grid_w + ix
		_heights[i] = maxf(_heights[i], v.y)
	# Celle senza vertice: media dei vicini già noti (poche passate bastano).
	for pass_index in 4:
		var next := _heights.duplicate()
		for iz in _grid_h:
			for ix in _grid_w:
				var i := iz * _grid_w + ix
				if _heights[i] > NONE:
					continue
				var sum := 0.0
				var n := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var jx: int = ix + d.x
					var jz: int = iz + d.y
					if jx < 0 or jz < 0 or jx >= _grid_w or jz >= _grid_h:
						continue
					if _heights[jz * _grid_w + jx] > NONE:
						sum += _heights[jz * _grid_w + jx]
						n += 1
				if n > 0:
					next[i] = sum / n
		_heights = next
	for i in _heights.size():
		if _heights[i] <= NONE:
			_heights[i] = 0.0


## Shader a 6 strati: le tre PNG verticali (6 strati da 1024 px) diventano Texture2DArray a runtime,
## perché gli .import in assets/models/custom/terreno/ le trattano come texture normali.
func _splat_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SPLAT_SHADER
	material.set_shader_parameter(&"layer_albedo_height", _layer_array("T_terreno_array_albedo_height.png"))
	material.set_shader_parameter(&"layer_normal", _layer_array("T_terreno_array_normal.png"))
	material.set_shader_parameter(&"layer_orm", _layer_array("T_terreno_array_orm.png"))
	material.set_shader_parameter(&"splat_map", load(TEX_DIR + "T_terreno_splat.png"))
	material.set_shader_parameter(&"mask_map", load(TEX_DIR + "T_terreno_maschere.png"))
	return material


func _layer_array(file: String) -> Texture2DArray:
	var image := (load(TEX_DIR + file) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var size := image.get_width()
	var slices: Array[Image] = []
	for i in image.get_height() / size:
		var slice := image.get_region(Rect2i(0, i * size, size, size))
		slice.generate_mipmaps()
		slices.append(slice)
	var array := Texture2DArray.new()
	array.create_from_images(slices)
	return array
