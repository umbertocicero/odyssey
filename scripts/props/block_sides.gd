class_name BlockSides
extends Node3D
## Lati del blocco del diorama: un muro di blocchi di pietra sotto il prato e,
## più in basso, terra e roccia scura con radici. Tutto è generato con due
## MultiMesh (una chiamata di disegno ciascuno), quindi leggero su mobile e web.
## Il nodo sta al centro della base; i blocchi sporgono dai quattro lati.

## Dimensioni della base (X, Z) e profondità totale del blocco.
@export var base_size := Vector2(52, 52)
@export var top_y := -0.6
@export var bottom_y := -8.0
## Fino a questa profondità i lati sono un muro di pietra; sotto c'è terra.
@export var stone_depth := 3.4
@export var random_seed := 7
@export var stone_colors: Array[Color] = [
	Color(0.62, 0.55, 0.44), Color(0.55, 0.50, 0.42), Color(0.68, 0.60, 0.47),
	Color(0.50, 0.46, 0.40), Color(0.60, 0.52, 0.40),
]
@export var earth_colors: Array[Color] = [
	Color(0.27, 0.19, 0.13), Color(0.33, 0.24, 0.16), Color(0.22, 0.17, 0.13),
	Color(0.38, 0.30, 0.22), Color(0.30, 0.27, 0.24),
]
@export var root_color := Color(0.20, 0.13, 0.08)
@export var root_count := 90


func _ready() -> void:
	_build()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var stones: Array[Transform3D] = []
	var stone_cols: Array[Color] = []
	var roots: Array[Transform3D] = []
	var half := base_size * 0.5
	# Per ogni lato: direzione verso l'esterno e asse lungo il lato.
	var sides := [
		{"normal": Vector3(0, 0, 1), "length": base_size.x},
		{"normal": Vector3(0, 0, -1), "length": base_size.x},
		{"normal": Vector3(1, 0, 0), "length": base_size.y},
		{"normal": Vector3(-1, 0, 0), "length": base_size.y},
	]
	for side: Dictionary in sides:
		var n: Vector3 = side["normal"]
		var length: float = side["length"]
		var face_offset := (half.y if n.z != 0.0 else half.x)
		# Base della faccia: -Z locale -> il blocco guarda verso n.
		var yaw := atan2(n.x, n.z)
		var basis_side := Basis(Vector3.UP, yaw)
		var along := basis_side * Vector3.RIGHT
		var y := top_y
		var row := 0
		while y > bottom_y + 0.2:
			var in_stone := (top_y - y) < stone_depth
			var h := rng.randf_range(0.7, 1.0) if in_stone else rng.randf_range(1.0, 1.9)
			h = minf(h, y - bottom_y)
			var s := -length * 0.5 - rng.randf_range(0.0, 1.2)
			while s < length * 0.5:
				var w := rng.randf_range(0.9, 1.7) if in_stone else rng.randf_range(1.2, 2.8)
				var depth := rng.randf_range(0.7, 1.1)
				# I blocchi sporgono a caso, così il profilo non è liscio.
				var out := rng.randf_range(-0.05, 0.28) if in_stone else rng.randf_range(-0.2, 0.45)
				var centre := Vector3(n.x, 0, n.z) * (face_offset + out - depth * 0.5 + 0.15) + along * (s + w * 0.5)
				centre.y = y - h * 0.5
				var gap := 0.96
				var t := Transform3D(basis_side.scaled_local(Vector3(w * gap, h * gap, depth)), centre)
				stones.append(t)
				var palette := stone_colors if in_stone else earth_colors
				var col := palette[rng.randi() % palette.size()]
				var v := rng.randf_range(0.88, 1.08)
				# Più in basso i blocchi diventano un po' più scuri.
				var depth_shade := lerpf(1.0, 0.7, clampf((top_y - y) / (top_y - bottom_y), 0.0, 1.0))
				stone_cols.append(Color(col.r * v * depth_shade, col.g * v * depth_shade, col.b * v * depth_shade))
				s += w
			y -= h
			row += 1
		# Radici che pendono sulla zona di terra.
		for i in root_count / 4:
			var rs := rng.randf_range(-length * 0.5, length * 0.5)
			var ry := rng.randf_range(bottom_y + 1.0, top_y - stone_depth + 0.3)
			var rl := rng.randf_range(0.8, 2.2)
			var root_basis := basis_side * Basis(Vector3.BACK, rng.randf_range(-0.7, 0.7)) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
			var root_pos := Vector3(n.x, 0, n.z) * (face_offset + 0.35) + along * rs + Vector3(0, ry, 0)
			roots.append(Transform3D(root_basis.scaled_local(Vector3(1, rl, 1)), root_pos))

	_add_multimesh("Blocchi", StoneMesh.build(), stones, stone_cols, true)
	var root_mesh := CylinderMesh.new()
	root_mesh.top_radius = 0.015
	root_mesh.bottom_radius = 0.07
	root_mesh.height = 1.0
	root_mesh.radial_segments = 5
	root_mesh.rings = 1
	_add_multimesh("Radici", root_mesh, roots, [], false)


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], use_colors: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = use_colors
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if use_colors:
			mm.set_instance_color(i, colors[i])
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	if use_colors:
		material.vertex_color_use_as_albedo = true
	else:
		material.albedo_color = root_color
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
