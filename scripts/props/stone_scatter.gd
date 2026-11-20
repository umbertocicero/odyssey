class_name StoneScatter
extends Node3D
## Lastricato: tante lastre di pietra irregolari in un rettangolo (strade,
## piazzali), un solo MultiMesh. Le lastre sono quasi a filo del terreno e non
## bloccano la griglia. L'erba e i fiori che crescono tra le lastre sono le
## decorazioni (PropScatter) sopra di esse.

## Area (X, Z) centrata sul nodo.
@export var area_size := Vector2(10, 3)
## Lato medio di una lastra, in metri.
@export_range(0.4, 3.0) var slab_size := 1.0
@export_range(0.0, 0.6) var size_variation := 0.18
## Spessore della lastra: sporge dal suolo di questa altezza.
@export_range(0.02, 0.5) var thickness := 0.12
@export var random_seed := 3
@export var colors: Array[Color] = [
	Color(0.74, 0.60, 0.44), Color(0.68, 0.55, 0.40), Color(0.78, 0.65, 0.48),
	Color(0.62, 0.50, 0.37), Color(0.72, 0.62, 0.50),
]


func _ready() -> void:
	var terrain := get_tree().get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	var step := slab_size * 1.04
	var nx := int(ceil(area_size.x / step))
	var nz := int(ceil(area_size.y / step))
	for ix in nx:
		for iz in nz:
			var jitter := Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05)) * slab_size
			var px := -area_size.x * 0.5 + (ix + 0.5) * area_size.x / nx + jitter.x
			var pz := -area_size.y * 0.5 + (iz + 0.5) * area_size.y / nz + jitter.y
			var sx := slab_size * (1.0 + rng.randf_range(-size_variation, size_variation)) * (area_size.x / nx / step)
			var sz := slab_size * (1.0 + rng.randf_range(-size_variation, size_variation)) * (area_size.y / nz / step)
			var yaw := rng.randf_range(-0.08, 0.08)
			# La mesh guarda verso +Z: la si sdraia in modo che la faccia bella sia in alto.
			var orientation := Basis(Vector3.UP, yaw) * Basis(Vector3.LEFT, PI * 0.5)
			var py := thickness * 0.5 - 0.02
			if terrain:
				# Terreno fotorealistico: la lastra segue la mesh (quota e pendenza) e
				# affonda di 5 cm al centro, così gli spigoli non galleggiano né fanno z-fighting.
				var world := global_transform * Vector3(px, 0.0, pz)
				var d := 0.4
				var dx := (terrain.height_at(world.x + d, world.z) - terrain.height_at(world.x - d, world.z)) / (2.0 * d)
				var dz := (terrain.height_at(world.x, world.z + d) - terrain.height_at(world.x, world.z - d)) / (2.0 * d)
				orientation = Basis(Quaternion(Vector3.UP, Vector3(-dx, 1.0, -dz).normalized())) * orientation
				py = terrain.height_at(world.x, world.z) - global_position.y + thickness * 0.5 - 0.05
			var basis := orientation.scaled_local(Vector3(sx * 0.94, sz * 0.94, thickness))
			transforms.append(Transform3D(basis, Vector3(px, py, pz)))
			var col := colors[rng.randi() % colors.size()]
			var v := rng.randf_range(0.9, 1.08)
			tints.append(Color(col.r * v, col.g * v, col.b * v))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = StoneMesh.build(0.03)
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, tints[i])
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	var instance := MultiMeshInstance3D.new()
	instance.name = "Lastre"
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
