class_name TerrainRelief
extends Node3D
## Rilievo del diorama: una mappa di livelli di altezza, una cifra per ogni
## quadrato di 1 m dell'intera base (anche fuori dalla griglia di gioco).
## Dove il livello è maggiore di 0 il terreno è un blocco rialzato: pareti di
## roccia fatte di blocchi di pietra (un blocco per livello, quindi a scalini)
## e un tappeto d'erba in cima. Tutto è disegnato con due MultiMesh.
##
## La griglia (DioramaGrid) legge da qui l'altezza delle caselle: si sale o
## si scende di un livello alla volta, una parete più alta non si supera.

## Angolo nord-ovest della mappa (X, Z) in metri.
@export var origin := Vector2(-26, -30)
## Dimensioni della mappa in quadrati da 1 m.
@export var map_size := Vector2i(52, 52)
## Altezza di un livello, in metri.
@export var level_height := 0.8
## Livelli per quadrato, riga per riga (prima Z, poi X): map_size.x * map_size.y valori.
@export var levels := PackedByteArray()
@export var random_seed := 11
@export var rock_colors: Array[Color] = [
	Color(0.55, 0.49, 0.43), Color(0.48, 0.43, 0.39), Color(0.60, 0.53, 0.45),
	Color(0.42, 0.39, 0.36), Color(0.52, 0.46, 0.38),
]
@export var grass_colors: Array[Color] = [
	Color(0.44, 0.46, 0.22), Color(0.40, 0.44, 0.21), Color(0.50, 0.48, 0.25), Color(0.46, 0.42, 0.22),
]

const SIDES: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]


func _enter_tree() -> void:
	add_to_group(&"terrain_relief")


func _ready() -> void:
	_build()


func level_at_index(ix: int, iz: int) -> int:
	if ix < 0 or iz < 0 or ix >= map_size.x or iz >= map_size.y or levels.is_empty():
		return 0
	return levels[iz * map_size.x + ix]


func level_at_world(x: float, z: float) -> int:
	return level_at_index(floori(x - origin.x), floori(z - origin.y))


func height_at_world(x: float, z: float) -> float:
	var base := level_at_world(x, z) * level_height
	if surface_detail:
		base += surface_detail.call(x, z, base)
	return base


## Rilievo fine della mesh fotorealistica (PhotoTerrain): Callable(x, z, quota_livello) -> scarto
## in metri. Così unità, piedi di Ulisse, tiri e oggetti seguono le colline basse della mesh
## e non solo i livelli a gradini. Vuoto = solo livelli.
var surface_detail: Callable


func _build() -> void:
	if levels.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var rocks: Array[Transform3D] = []
	var rock_tints: Array[Color] = []
	var caps: Array[Transform3D] = []
	var cap_tints: Array[Color] = []
	for iz in map_size.y:
		for ix in map_size.x:
			var level := level_at_index(ix, iz)
			if level <= 0:
				continue
			var centre := Vector3(origin.x + ix + 0.5, 0.0, origin.y + iz + 0.5)
			var top := level * level_height
			# Tappeto d'erba in cima, appena più largo per sporgere sulla roccia.
			var cap_basis := Basis.IDENTITY.scaled(Vector3(1.03, 0.16, 1.03))
			caps.append(Transform3D(cap_basis, centre + Vector3(0, top - 0.08, 0)))
			var g := grass_colors[rng.randi() % grass_colors.size()]
			var gv := rng.randf_range(0.92, 1.08)
			cap_tints.append(Color(g.r * gv, g.g * gv, g.b * gv))
			# Pareti: un blocco di pietra per ogni livello sul lato più basso.
			for side in SIDES:
				var neighbour := level_at_index(ix + side.x, iz + side.y)
				if neighbour >= level:
					continue
				var normal := Vector3(side.x, 0, side.y)
				var yaw := atan2(normal.x, normal.z)
				var basis_side := Basis(Vector3.UP, yaw)
				for k in range(neighbour, level):
					var depth := rng.randf_range(0.8, 1.0)
					var out := rng.randf_range(-0.02, 0.16)
					var pos := centre + normal * (0.5 + out - depth * 0.5) + Vector3(0, (k + 0.5) * level_height, 0)
					var t := Transform3D(basis_side.scaled_local(Vector3(0.99, level_height * 0.99, depth)), pos)
					rocks.append(t)
					var c := rock_colors[rng.randi() % rock_colors.size()]
					var v := rng.randf_range(0.88, 1.08)
					rock_tints.append(Color(c.r * v, c.g * v, c.b * v))
	_add_multimesh("Pareti", StoneMesh.build(0.06), rocks, rock_tints, true)
	var cap_mesh := BoxMesh.new()
	_add_multimesh("Erba", cap_mesh, caps, cap_tints, false)


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], tints: Array[Color], shadows: bool) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, tints[i])
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
