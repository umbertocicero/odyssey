class_name HopliteMasses
extends Node3D
## Masse di opliti lontani (STYLE.md, sezione 8): blocchi da 8 figure statiche, un MultiMesh per modello
## (schieramento fermo e colonna in marcia), non bloccanti e solo da qualità media. Si trovano sotto le
## mura e sul bordo est della pianura, fuori dalla strada, e si perdono nella foschia.
## Budget: medium 6 + 3 blocchi, high 12 + 6 (circa 2.000 triangoli a blocco, 2 disegni in tutto).

const LINE_PATH := "res://assets/models/custom/campo/personaggi/masse/opliti_schieramento/opliti_schieramento.gltf"
const MARCH_PATH := "res://assets/models/custom/campo/personaggi/masse/opliti_marcia/opliti_marcia.gltf"
const SPACING := 3.8

@export var enabled := true
@export var random_seed := 53

var line_blocks := 0
var march_blocks := 0
var _relief: TerrainRelief
var _terrain: PhotoTerrain


func _ready() -> void:
	var q := int(Quality.current())
	if not enabled or q < 1:
		return
	_relief = get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	_terrain = get_tree().get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var line_target: int = [0, 6, 12][q]
	var march_target: int = [0, 3, 6][q]
	# Schieramento sotto le mura (z = -18.7), a destra e a sinistra della porta; poi seconda fila più indietro.
	var line_slots: Array[Vector3] = []
	for row in 2:
		for k in 11:
			var px := -19.5 + k * SPACING + row * SPACING * 0.5
			if px > 2.0 and px < 12.0:
				continue  # la strada e la porta restano libere
			line_slots.append(Vector3(px, 0.0, -18.7 + row * 1.3))
	line_slots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z or (a.z == b.z and absf(a.x) < absf(b.x)))
	var line_transforms := _transforms(line_slots, line_target, rng, 0.0)
	line_blocks = line_transforms.size()
	_spawn("Schieramento", LINE_PATH, line_transforms)
	# Colonna in marcia sul bordo est, verso nord (Troia).
	var march_slots: Array[Vector3] = []
	for k in 8:
		march_slots.append(Vector3(22.6, 0.0, 9.0 - k * SPACING))
	var march_transforms := _transforms(march_slots, march_target, rng, 0.0)
	march_blocks = march_transforms.size()
	_spawn("Marcia", MARCH_PATH, march_transforms)


func _ground(x: float, z: float) -> float:
	if _terrain and _terrain.is_active():
		return _terrain.height_at(x, z)
	return _relief.height_at_world(x, z) if _relief else 0.0


func _transforms(slots: Array[Vector3], count: int, rng: RandomNumberGenerator, base_yaw: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var used: Array[Vector3] = []
	for s in slots:
		if out.size() >= count:
			break
		var too_close := false
		for u in used:
			if Vector2(u.x - s.x, u.z - s.z).length() < SPACING:
				too_close = true
		if too_close:
			continue
		used.append(s)
		var scale := rng.randf_range(0.95, 1.05)
		var yaw := base_yaw + rng.randf_range(-0.14, 0.14)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
		out.append(Transform3D(basis, Vector3(s.x, _ground(s.x, s.z) - 0.02, s.z)))
	return out


func _spawn(node_name: String, path: String, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty() or not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	var meshes := ModelFit.extract_meshes(scene, "")
	for i in meshes.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i][0]
		mm.instance_count = transforms.size()
		var local: Transform3D = meshes[i][1]
		for j in transforms.size():
			mm.set_instance_transform(j, transforms[j] * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s%d" % [node_name, i]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
