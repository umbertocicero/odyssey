class_name SeaShore
extends Node3D
## Riva naturale del livello 1 (la crea SeaWater quando il terreno è fotorealistico).
##
## - Sabbia: una mesh generata (heightfield) sopra la spiaggia dritta della mesh del terreno, con la
##   linea d'acqua sinuosa di ShoreProfile, fondale che sale dolcemente, battigia, berma e dune basse.
##   Si fonde con le texture cotte del terreno a est e a nord. Lo shader (shore_sand.gdshader)
##   fa sabbia bagnata, pellicola dell'onda che si ritira, schiuma e linee di alta marea.
## - Detriti portati dal mare con MultiMesh (una chiamata di disegno per tipo): ciottoli, conchiglie,
##   alghe, rametti, qualche tronco spiaggiato e scogli di Poly Haven. Tutto solo visivo.
## - Le quote delle caselle vicine alla riva seguono la sabbia (TerrainRelief.surface_detail).
## Il mare (sea.gdshader) legge lo stesso profilo analitico: la linea d'acqua combacia con la mesh.

const SAND_SHADER := preload("res://assets/shaders/shore_sand.gdshader")
const SAND_ALBEDO := preload("res://assets/environment/shore/T_riva_sabbia_albedo.png")
const SAND_NORMAL := preload("res://assets/environment/shore/T_riva_sabbia_normal.png")
const SAND_ORM := preload("res://assets/environment/shore/T_riva_sabbia_orm.png")
const NOISE_TEX := preload("res://assets/environment/water/sea_height.png")
const TERRAIN_DIR := "res://assets/models/custom/terreno/textures/"
const ROCKS_PATH := "res://assets/models/custom/polyhaven/rocce/coast_rocks_05/coast_rocks_05.gltf"
const LOG_PATH := "res://assets/models/custom/polyhaven/rocce/dead_tree_trunk_02/dead_tree_trunk_02.gltf"
const EAST_X := -18.6
const NORTH_Z := -21.5
const SKIRT := 0.65
## Il mare da una parte e le caselle di imbarco dei feriti dall'altra: lì niente rocce né tronchi.
const KEEP_CLEAR_Z := Vector2(8.5, 14.5)
## Nave in secca: niente tronchi né scogli sotto lo scafo.
const BEACHED_SHIP := Rect2(-22.5, -9.0, 4.0, 10.0)

## x mondiale del bordo ovest del mare (lo imposta SeaWater).
var west_x := -26.0
var quality := 2
var terrain: PhotoTerrain
var sand: MeshInstance3D
var stats := {"sand_vertices": 0, "sand_triangles": 0, "debris_instances": 0, "multimeshes": 0}

var _relief: TerrainRelief
var _previous_detail: Callable
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	quality = int(Quality.current())
	terrain = get_tree().get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	if terrain == null:
		return
	_rng.seed = 2024
	_noise.seed = 11
	_noise.frequency = 1.0
	_build_sand()
	_build_debris()
	_hook_relief()


## Quota della superficie visibile (sabbia fusa col terreno) nel punto (x, z).
func surface_y(x: float, z: float) -> float:
	var mine := ShoreProfile.sand_height(x, z)
	var tw := ShoreProfile.terrain_weight(x, z)
	if tw <= 0.0:
		return mine
	var base := terrain.height_at(x, z) if terrain else 0.0
	return maxf(lerpf(mine, base, tw), base + 0.004)


func _hook_relief() -> void:
	_relief = get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	if _relief == null:
		return
	_previous_detail = _relief.surface_detail
	_relief.surface_detail = _detail


## Le caselle sulla riva seguono la sabbia (entro ±12 cm dal livello della casella), il resto resta com'era.
func _detail(x: float, z: float, base: float) -> float:
	if x > ShoreProfile.LAND_X - 0.4 or x < west_x or z < ShoreProfile.Z_MIN or z > ShoreProfile.Z_MAX:
		return _previous_detail.call(x, z, base) if _previous_detail.is_valid() else 0.0
	return clampf(surface_y(x, z) - base, -0.12, 0.12)


# ───────────────────────────── sabbia ─────────────────────────────

func _build_sand() -> void:
	var step := 0.25 if quality == Quality.Level.HIGH else 0.5
	var x0 := west_x
	var z0 := NORTH_Z
	var z1 := ShoreProfile.Z_MAX
	var nx := ceili((EAST_X - x0) / step)
	var nz := ceili((z1 - z0) / step)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	verts.resize((nx + 1) * (nz + 1))
	normals.resize(verts.size())
	tangents.resize(verts.size() * 4)
	for iz in nz + 1:
		var z := minf(z0 + iz * step, z1)
		for ix in nx + 1:
			var x := minf(x0 + ix * step, EAST_X)
			var i := iz * (nx + 1) + ix
			verts[i] = Vector3(x, surface_y(x, z), z)
	for iz in nz + 1:
		for ix in nx + 1:
			var i := iz * (nx + 1) + ix
			var hx := verts[iz * (nx + 1) + mini(ix + 1, nx)].y - verts[iz * (nx + 1) + maxi(ix - 1, 0)].y
			var dx := verts[iz * (nx + 1) + mini(ix + 1, nx)].x - verts[iz * (nx + 1) + maxi(ix - 1, 0)].x
			var hz := verts[mini(iz + 1, nz) * (nx + 1) + ix].y - verts[maxi(iz - 1, 0) * (nx + 1) + ix].y
			var dz := verts[mini(iz + 1, nz) * (nx + 1) + ix].z - verts[maxi(iz - 1, 0) * (nx + 1) + ix].z
			var n := Vector3(-hx / maxf(dx, 0.001), 1.0, -hz / maxf(dz, 0.001)).normalized()
			normals[i] = n
			var tan := Vector3(1.0, hx / maxf(dx, 0.001), 0.0).normalized()
			tangents[i * 4] = tan.x
			tangents[i * 4 + 1] = tan.y
			tangents[i * 4 + 2] = tan.z
			tangents[i * 4 + 3] = 1.0
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			# Godot: vertici in senso orario visto da sopra (+Y).
			indices.append_array([a, b, c, b, d, c])
	# Gonne sul bordo sud e ovest (il bordo del diorama è un taglio netto): coprono la sezione del terreno.
	var skirt_verts := _add_skirts(verts, normals, tangents, indices, nx, nz)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	sand = MeshInstance3D.new()
	sand.name = "RivaSabbia"
	sand.mesh = mesh
	sand.material_override = _sand_material()
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sand.add_to_group(&"shore_sand")
	add_child(sand)
	stats["sand_vertices"] = verts.size()
	stats["sand_triangles"] = indices.size() / 3 + skirt_verts


## Una striscia verticale lungo il bordo sud (z = Z_MAX) e ovest (x = west_x), appena dentro il blocco.
func _add_skirts(verts: PackedVector3Array, normals: PackedVector3Array, tangents: PackedFloat32Array, indices: PackedInt32Array, nx: int, nz: int) -> int:
	var count := 0
	for edge in 2:
		var start := verts.size()
		var n_edge := nx if edge == 0 else nz
		for k in n_edge + 1:
			var top: Vector3 = verts[nz * (nx + 1) + k] if edge == 0 else verts[k * (nx + 1)]
			var tw := ShoreProfile.terrain_weight(top.x, top.z)
			var inset := Vector3(0, 0, -0.004) if edge == 0 else Vector3(0.004, 0, 0)
			var bottom := top - Vector3(0, SKIRT * (1.0 - tw), 0)
			verts.append(top + inset)
			verts.append(bottom + inset)
			var n := Vector3(0, 0, 1) if edge == 0 else Vector3(-1, 0, 0)
			normals.append(n)
			normals.append(n)
			var t := Vector3(1, 0, 0) if edge == 0 else Vector3(0, 0, 1)
			for j in 2:
				tangents.append_array([t.x, t.y, t.z, 1.0])
		for k in n_edge:
			var a := start + k * 2
			# L'ordine dei vertici dipende dal lato guardato (sud guarda +Z, ovest guarda -X).
			if edge == 0:
				indices.append_array([a, a + 1, a + 2, a + 2, a + 1, a + 3])
			else:
				indices.append_array([a, a + 2, a + 1, a + 2, a + 3, a + 1])
			count += 2
	return count


func _sand_material() -> ShaderMaterial:
	var mobile := terrain.force_mobile or quality != Quality.Level.HIGH
	var mat := ShaderMaterial.new()
	mat.shader = SAND_SHADER
	mat.set_shader_parameter(&"sand_albedo", SAND_ALBEDO)
	mat.set_shader_parameter(&"sand_normal", SAND_NORMAL)
	mat.set_shader_parameter(&"sand_orm", SAND_ORM)
	mat.set_shader_parameter(&"noise_tex", NOISE_TEX)
	mat.set_shader_parameter(&"terrain_albedo", load(TERRAIN_DIR + ("T_terreno_baked_albedo_1k.png" if mobile else "T_terreno_baked_albedo.png")))
	mat.set_shader_parameter(&"terrain_origin", terrain.origin)
	mat.set_shader_parameter(&"terrain_size", terrain.map_size.x)
	mat.set_shader_parameter(&"shore_base_x", ShoreProfile.BASE_X)
	return mat


# ───────────────────────────── detriti ─────────────────────────────

func _build_debris() -> void:
	var density := Quality.density()
	var pebble_mesh := _pebble_mesh()
	var shell_mesh := _shell_mesh()
	var weed_mesh := _weed_mesh()
	# Ciottoli: dalla battigia verso terra, più fitti sui promontori; molti restano sott'acqua e si vedono in trasparenza.
	var pebbles := _scatter(int(520 * density), -1.6, 3.6, 0.0)
	_add_multimesh("Ciottoli", pebble_mesh, pebbles, _pebble_palette(), 0.022, 0.07, true, 1.0)
	# Conchiglie: poche, soprattutto sulla linea dell'alta marea e nella risacca.
	var shells := _scatter(int(150 * density), -0.5, 2.4, 0.0)
	_add_multimesh("Conchiglie", shell_mesh, shells, _shell_palette(), 0.018, 0.04, true, 1.0)
	# Alghe portate dal mare: ammassi lungo la linea dell'alta marea e nel bagnato.
	var weeds := _scatter(int(150 * density), 0.2, 1.8, 0.7)
	_add_multimesh("Alghe", weed_mesh, weeds, _weed_palette(), 0.14, 0.34, false, 0.9, true)
	if quality == Quality.Level.LOW:
		return
	_add_rocks(int(8 * density) + 3)
	_add_logs(3 if quality == Quality.Level.HIGH else 2)


## Posizioni lungo la riva: s = distanza dalla linea d'acqua (m, > 0 verso terra). `cluster` > 0 le raggruppa
## in ammassi lungo la riva (la linea d'alta marea non è uniforme).
func _scatter(count: int, s_min: float, s_max: float, cluster: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var attempts := 0
	while out.size() < count and attempts < count * 12:
		attempts += 1
		var z := _rng.randf_range(ShoreProfile.Z_MIN + 0.3, ShoreProfile.Z_MAX - 0.3)
		if cluster > 0.0:
			var drift := 0.5 + 0.5 * _noise.get_noise_2d(z * 0.55, 30.0)
			if _rng.randf() > lerpf(1.0, drift * drift * 1.6, cluster):
				continue
		var s := _rng.randf_range(s_min, s_max)
		if cluster > 0.0:
			# i detriti si fermano sulla linea dell'alta marea: s attorno a 0.3 + rumore
			s = clampf(0.9 + 0.5 * _noise.get_noise_2d(z * 0.7, 5.0) + _rng.randfn(0.0, 0.35), s_min, s_max)
		var x := ShoreProfile.waterline(z) + s
		if x < west_x + 0.3 or x > ShoreProfile.LAND_X - 0.5:
			continue
		out.append(Vector3(x, surface_y(x, z), z))
	return out


func _add_multimesh(node_name: String, mesh: Mesh, points: Array[Vector3], palette: Array[Color], size_min: float, size_max: float, flat: bool, vary: float, ribbon := false) -> void:
	if points.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		var p := points[i]
		var yaw := _rng.randf() * TAU
		var sc := _rng.randf_range(size_min, size_max)
		var basis := Basis(Vector3.UP, yaw)
		if flat:
			# ciottoli e conchiglie: leggermente inclinati, piantati nella sabbia
			basis = basis * Basis(Vector3.RIGHT, _rng.randf_range(-0.25, 0.25)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.25, 0.25))
			basis = basis.scaled_local(Vector3(sc * _rng.randf_range(0.8, 1.25), sc * _rng.randf_range(0.55, 0.9), sc * _rng.randf_range(0.8, 1.2)))
			p.y += sc * 0.12 - 0.004
		else:
			basis = basis.scaled_local(Vector3(sc, 1.0 + (sc - size_min) * 0.3, sc * (0.9 if ribbon else 1.0)))
			p.y += 0.006
		mm.set_instance_transform(i, Transform3D(basis, p))
		var c := palette[_rng.randi() % palette.size()]
		var v := _rng.randf_range(1.0 - 0.22 * vary, 1.0 + 0.08 * vary)
		mm.set_instance_color(i, Color(c.r * v, c.g * v, c.b * v))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.55 if ribbon else 0.75
	if ribbon:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.45
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	stats["debris_instances"] += points.size()
	stats["multimeshes"] += 1


func _add_rocks(count: int) -> void:
	var mesh := _mesh_of(ROCKS_PATH)
	if mesh == null:
		return
	var transforms: Array[Transform3D] = []
	var attempts := 0
	while transforms.size() < count and attempts < 400:
		attempts += 1
		var north := _rng.randf() < 0.3
		var z := _rng.randf_range(-19.0, -17.0) if north else _rng.randf_range(ShoreProfile.Z_MIN + 1.0, ShoreProfile.Z_MAX - 1.0)
		if z > KEEP_CLEAR_Z.x and z < KEEP_CLEAR_Z.y:
			continue
		# a riva, mezzo in acqua; quelli del bacino nord stanno contro la testa del bacino
		var s := _rng.randf_range(-1.3, 0.5)
		var x := ShoreProfile.waterline(z) + s
		if BEACHED_SHIP.has_point(Vector2(x, z)):
			continue
		var sc := _rng.randf_range(0.14, 0.36)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12))
		b = b.scaled_local(Vector3(sc, sc * _rng.randf_range(0.8, 1.2), sc))
		transforms.append(Transform3D(b, Vector3(x, surface_y(x, z) - sc * 0.22, z)))
	_add_mesh_instances("Scogli", mesh, transforms, true)


func _add_logs(count: int) -> void:
	var mesh := _mesh_of(LOG_PATH)
	if mesh == null:
		return
	var transforms: Array[Transform3D] = []
	var attempts := 0
	while transforms.size() < count and attempts < 400:
		attempts += 1
		var z := _rng.randf_range(ShoreProfile.Z_MIN + 2.0, ShoreProfile.Z_MAX - 2.0)
		if z > KEEP_CLEAR_Z.x and z < KEEP_CLEAR_Z.y:
			continue
		var s := _rng.randf_range(1.0, 2.2)
		var x := ShoreProfile.waterline(z) + s
		if BEACHED_SHIP.has_point(Vector2(x, z)):
			continue
		var sc := _rng.randf_range(0.22, 0.34)
		# più o meno paralleli alla riva (asse lungo del modello = X)
		var yaw := PI * 0.5 + _rng.randf_range(-0.5, 0.5)
		var b := Basis(Vector3.UP, yaw).scaled_local(Vector3(sc, sc, sc))
		transforms.append(Transform3D(b, Vector3(x, surface_y(x, z) - sc * 0.2, z)))
	_add_mesh_instances("TronchiSpiaggiati", mesh, transforms, false)


func _add_mesh_instances(node_name: String, mesh: Mesh, transforms: Array[Transform3D], shadows: bool) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows and quality == Quality.Level.HIGH else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	stats["debris_instances"] += transforms.size()
	stats["multimeshes"] += 1


func _mesh_of(path: String) -> Mesh:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	var mesh: Mesh
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		mesh = (node as MeshInstance3D).mesh
		break
	inst.queue_free()
	return mesh


# ─────────────────────── mesh e tavolozze dei detriti ───────────────────────

func _pebble_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 9
	sphere.rings = 5
	sphere.radius = 0.5
	sphere.height = 1.0
	var arrays := sphere.get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(v.size())
	for i in v.size():
		var n := _noise.get_noise_3d(v[i].x * 3.1, v[i].y * 3.1, v[i].z * 3.1)
		v[i] = v[i] * (1.0 + 0.22 * n)
		var shade := clampf(0.65 + (v[i].y + 0.5) * 0.45, 0.5, 1.05)   # occlusione finta: il fondo è più scuro
		colors[i] = Color(shade, shade, shade)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays.resize(Mesh.ARRAY_MAX)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _shell_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 4
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.is_hemisphere = true
	var arrays := sphere.get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(v.size())
	for i in v.size():
		var a := atan2(v[i].z, v[i].x)
		var rib := sin(a * 7.0)
		var r := 1.0 + 0.10 * rib
		v[i] = Vector3(v[i].x * r * 1.1, v[i].y * 0.55, v[i].z * r * 0.85)
		var shade := 0.82 + 0.18 * rib * 0.5 + (v[i].y * 0.4)
		colors[i] = Color(shade, shade * 0.98, shade * 0.94)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Un ammasso di alghe: tre nastri curvi e sottili stesi a terra.
func _weed_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for ribbon in 2:
		var yaw := rng.randf_range(-0.4, 0.4) + ribbon * 0.7
		var length := rng.randf_range(0.5, 0.75)
		var width := rng.randf_range(0.22, 0.34)
		var segs := 6
		var curl := rng.randf_range(-0.5, 0.5)
		var pos := Vector3.ZERO
		var dir := Vector2(cos(yaw), sin(yaw))
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k in segs + 1:
			var t := float(k) / segs
			var ang := yaw + curl * t + sin(t * 5.0 + ribbon) * 0.25
			dir = Vector2(cos(ang), sin(ang))
			if k > 0:
				pos += Vector3(dir.x, 0, dir.y) * (length / segs)
			pos.y = 0.012 * sin(t * 9.0 + ribbon) + 0.004 + 0.02 * t * (1.0 - t)
			var side := Vector3(-dir.y, 0, dir.x) * width * (1.0 - 0.5 * absf(t - 0.4)) * 0.5
			var l := pos - side
			var r := pos + side
			var shade := lerpf(0.75, 1.1, t) * rng.randf_range(0.9, 1.0)
			if k > 0:
				for q: Array in [[prev_l, l, prev_r, shade], [prev_r, l, r, shade]]:
					for j in 3:
						st.set_color(Color(q[3], q[3], q[3]))
						st.set_normal(Vector3.UP)
						st.add_vertex(q[j])
			prev_l = l
			prev_r = r
	return st.commit()


func _stick_mesh() -> ArrayMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.006
	cyl.bottom_radius = 0.011
	cyl.height = 0.5
	cyl.radial_segments = 5
	cyl.rings = 1
	var arrays := cyl.get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(v.size())
	colors.fill(Color(1, 1, 1))
	# steso lungo X, con una lieve curvatura
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in v.size():
		var p := v[i]
		v[i] = Vector3(p.y, p.x + 0.02 * sin(p.y * 7.0), p.z)
		nrm[i] = Vector3(nrm[i].y, nrm[i].x, nrm[i].z)
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _pebble_palette() -> Array[Color]:
	return [Color(0.46, 0.42, 0.37), Color(0.58, 0.52, 0.43), Color(0.36, 0.34, 0.32), Color(0.66, 0.6, 0.5), Color(0.5, 0.4, 0.32), Color(0.72, 0.68, 0.6)]


func _shell_palette() -> Array[Color]:
	return [Color(0.92, 0.84, 0.72), Color(0.88, 0.7, 0.62), Color(0.95, 0.92, 0.86), Color(0.78, 0.66, 0.52)]


func _weed_palette() -> Array[Color]:
	return [Color(0.42, 0.40, 0.19), Color(0.5, 0.38, 0.2), Color(0.3, 0.36, 0.17), Color(0.55, 0.45, 0.26)]


func _wood_palette() -> Array[Color]:
	return [Color(0.62, 0.52, 0.4), Color(0.7, 0.62, 0.5), Color(0.5, 0.4, 0.3)]
