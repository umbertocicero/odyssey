class_name DirtRoad
extends Node3D
## Strada di terra battuta del livello 1 (STYLE.md, sezione 6): un nastro sottile che segue
## la quota del terreno (PhotoTerrain, altrimenti TerrainRelief) lungo una curva, con solchi di
## ruote e bordi sfumati (assets/shaders/dirt_road.gdshader), più sassi sparsi sui bordi e
## cumuli di pietre. Sostituisce i lastricati a scacchiera; non tocca la griglia di gioco.

const SHADER := preload("res://assets/shaders/dirt_road.gdshader")

## Punti (X, Z) del centro della strada in coordinate del mondo, da ovest a nord.
@export var path_points: PackedVector2Array = PackedVector2Array([
	Vector2(-17.5, 11.9), Vector2(-9.0, 11.2), Vector2(-1.0, 11.7), Vector2(4.8, 10.3),
	Vector2(6.9, 5.5), Vector2(6.1, -1.5), Vector2(6.9, -8.5), Vector2(6.2, -14.0), Vector2(6.5, -19.0)])
@export_range(1.0, 6.0) var width := 3.4
## Quanto il nastro sta sopra il terreno (m): evita il z-fighting.
@export_range(0.0, 0.1) var lift := 0.035
@export var random_seed := 17
## Cumuli di pietre (X, Z): barricate, margini della strada.
@export var stone_piles: PackedVector2Array = PackedVector2Array([
	Vector2(3.4, -15.3), Vector2(9.7, -15.0), Vector2(8.6, 2.0), Vector2(4.2, -9.0), Vector2(-3.5, 10.0)])

var stone_count := 0
var road_length := 0.0
var _terrain: PhotoTerrain
var _relief: TerrainRelief


func _ready() -> void:
	if not TerrainStyle.photo():
		visible = false
		return
	_terrain = get_tree().get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	_relief = get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	_build_road()
	_build_stones()


func _ground(x: float, z: float) -> float:
	if _terrain and _terrain.is_active():
		return _terrain.height_at(x, z)
	return _relief.height_at_world(x, z) if _relief else 0.0


func _samples() -> PackedVector2Array:
	# Catmull-Rom tra i punti, un campione ogni ~0,5 m.
	var pts := path_points
	var out := PackedVector2Array()
	for i in range(pts.size() - 1):
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		var steps := maxi(int(p1.distance_to(p2) / 0.5), 2)
		for s in steps:
			var t := float(s) / steps
			out.append(p1.cubic_interpolate(p2, p0, p3, t))
	out.append(pts[pts.size() - 1])
	return out


func _build_road() -> void:
	var s := _samples()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var tangents := PackedFloat32Array()
	var dist := 0.0
	for i in s.size():
		if i > 0:
			dist += s[i].distance_to(s[i - 1])
		var a := s[maxi(i - 1, 0)]
		var b := s[mini(i + 1, s.size() - 1)]
		var t := (b - a).normalized()
		var n := Vector2(-t.y, t.x)
		for side in [-1.0, 1.0]:
			var p: Vector2 = s[i] + n * side * width * 0.5
			var y := _ground(p.x, p.y) + lift
			vertices.append(Vector3(p.x, y, p.y) - global_position)
			normals.append(Vector3.UP)
			uvs.append(Vector2(side, dist))
			# Tangente lungo +U (attraverso la strada), binormale a segno concorde.
			tangents.append_array([n.x, 0.0, n.y, 1.0])
		if i > 0:
			var k := (i - 1) * 2
			indices.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	road_length = dist
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var instance := MeshInstance3D.new()
	instance.name = "Strada"
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Sassi irregolari: sfere schiacciate a bassa risoluzione, un solo MultiMesh.
func _build_stones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var s := _samples()
	var budget := int([22, 50, 100][int(Quality.current())])
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	for i in budget:
		var idx := rng.randi_range(0, s.size() - 1)
		var a := s[maxi(idx - 1, 0)]
		var b := s[mini(idx + 1, s.size() - 1)]
		var t := (b - a).normalized()
		var n := Vector2(-t.y, t.x)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var p := s[idx] + n * side * rng.randf_range(0.2, width * 0.62)
		_add_stone(transforms, tints, rng, Vector3(p.x, 0.0, p.y), rng.randf_range(0.07, 0.2))
	for pile in stone_piles:
		var count := int([4, 7, 11][int(Quality.current())])
		for j in count:
			var p := pile + Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
			var dist := p.distance_to(pile)
			_add_stone(transforms, tints, rng, Vector3(p.x, 0.0, p.y), rng.randf_range(0.18, 0.4) * (1.2 - dist * 0.5))
	stone_count = transforms.size()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radial_segments = 7
	sphere.rings = 4
	sphere.radius = 0.5
	sphere.height = 0.8
	mm.mesh = sphere
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, tints[i])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var instance := MultiMeshInstance3D.new()
	instance.name = "Sassi"
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	instance.global_transform = Transform3D.IDENTITY


func _add_stone(transforms: Array[Transform3D], tints: Array[Color], rng: RandomNumberGenerator, at: Vector3, size: float) -> void:
	at.y = _ground(at.x, at.z) - size * 0.18
	var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
	basis = basis.scaled_local(Vector3(size * rng.randf_range(0.9, 1.5), size * rng.randf_range(0.6, 1.0), size * rng.randf_range(0.9, 1.4)))
	transforms.append(Transform3D(basis, at))
	var v := rng.randf_range(0.8, 1.1)
	tints.append(Color(0.58 * v, 0.5 * v, 0.4 * v))
