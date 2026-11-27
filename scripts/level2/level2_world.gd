class_name Level2World
extends Node3D
## Mondo del livello 2 ("Il dono del mare"): una baia boscosa lontana da Troia, in forma di diorama.
## A ovest il mare con le navi tirate in secca (e l'acqua che cade dal bordo), a est la foresta di abeti,
## in mezzo un ruscello che porta i tronchi alla spiaggia, dove sta il cantiere del cavallo.
## Troia si vede solo in lontananza, a nord-est, e non si raggiunge.
## Il nodo costruisce tutto da codice all'avvio; la regia (Level2Director) usa i punti esposti qui.

const SPLAT_SHADER := preload("res://assets/models/custom/terreno/godot/terreno_splat.gdshader")
const WATER_SHADER := preload("res://assets/shaders/stream_water.gdshader")
const SEA_NORMAL := preload("res://assets/environment/water/sea_normal.png")
const TEX_DIR := "res://assets/models/custom/terreno/textures/"
const L2 := "res://assets/models/custom/livello2/"
const POLY := "res://assets/models/custom/polyhaven/"
const CAMPO := "res://assets/models/custom/campo/"

const GRID := 40
const HALF := 20.0
const MAP := 52.0
## Riva: a ovest di questa x c'e' l'acqua.
const SEA_X := -15.0

## Il ruscello: entra dal bordo nord-est del blocco (il vertice opposto alla foce) e attraversa il diorama fino alla spiaggia.
const STREAM := [Vector2(22.0, -26.5), Vector2(18.0, -22.5), Vector2(13.5, -19.0), Vector2(10.5, -13.5), Vector2(5.5, -8.5), Vector2(0.5, -3.5),
	Vector2(-4.0, 1.0), Vector2(-8.0, 4.0), Vector2(-11.2, 5.6), Vector2(-14.8, 6.7)]
## Dove i tronchi si fermano (sbarramento di travi).
const LANDING := Vector2(-11.2, 5.6)
const BENCH := Vector2(-8.6, 8.0)
const SITE := Vector2(-6.0, 13.0)
const PILE := Vector2(-9.2, 11.0)
const CAMP := Vector2(-11.0, -9.0)
const START := Vector2(-9.0, -3.5)
## Sentiero che i troiani percorrono trascinando il cavallo fino alle mura lontane.
const TRACK := [Vector2(-6.0, 13.0), Vector2(-1.0, 9.5), Vector2(5.0, 4.0), Vector2(9.0, -4.0), Vector2(11.0, -13.0),
	Vector2(14.0, -24.0), Vector2(18.0, -44.0), Vector2(22.0, -70.0), Vector2(25.0, -96.0), Vector2(25.5, -103.0)]
const TROY_POS := Vector3(25.5, 0.0, -112.0)

## I dieci abeti da abbattere (posizioni nel mondo), vicino al ruscello.
const TREE_SPOTS := [Vector2(3.5, -11.5), Vector2(7.5, -6.5), Vector2(1.5, -8.5), Vector2(-1.5, -0.5),
	Vector2(4.0, 1.5), Vector2(-5.5, -3.5), Vector2(8.5, -12.0), Vector2(-2.5, 4.5), Vector2(11.5, -9.0), Vector2(2.0, -15.5)]

var env: Environment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var camera: FixedCamera
var grid: DioramaGrid
var units_root: Node3D
var sea: SeaWater
var player: GridUnit
var allies: Array[GridUnit] = []
var ships: Array[Node3D] = []
var tree_nodes: Array[Node3D] = []
## Tutti gli alberi (anche decorativi): si dissolvono quando coprono Ulisse alla camera.
var all_trees: Array[Node3D] = []
var horse: Node3D
var horse_material: ShaderMaterial
var horse_height := 0.0
var epeus: Node3D
var carpenters: Array[Node3D] = []
var fires: Array[OmniLight3D] = []
var troy: Node3D
var ground_mesh: MeshInstance3D
var stream_len := 0.0
var _stream_cum: PackedFloat32Array = []
var _rng := RandomNumberGenerator.new()
var _day := {}


func _ready() -> void:
	add_to_group(&"level2_world")
	_rng.seed = 2
	_build_stream_lengths()
	_build_environment()
	_build_ground()
	_build_far_world()
	_build_sea()
	_build_stream()
	_build_grid_and_camera()
	_build_forest()
	_build_camp_and_yard()
	_build_ships()
	_build_horse()
	_build_people()
	_build_ambience()


## Suoni ambientali in loop: ruscello (a monte e a valle), foce, onde sul mare, bosco.
func _build_ambience() -> void:
	var up := stream_point(stream_len * 0.25)
	var mid := stream_point(stream_len * 0.6)
	GameAudio.ambient_loop(self, "stream_loop", Vector3(up.x, 0.5, up.y), -4.0, 24.0)
	GameAudio.ambient_loop(self, "stream_loop", Vector3(mid.x, 0.5, mid.y), -4.0, 24.0)
	GameAudio.ambient_loop(self, "river_mouth_loop", Vector3(MOUTH.x, 0.5, MOUTH.y), -2.0, 32.0)
	GameAudio.ambient_loop(self, "sea_waves_loop", Vector3(SEA_X - 2.0, 0.5, -8.0), -3.0, 36.0)
	GameAudio.ambient_loop(self, "sea_waves_loop", Vector3(SEA_X - 2.0, 0.5, 14.0), -3.0, 36.0)
	for z in [-14.0, 0.0, 14.0]:
		GameAudio.ambient_loop(self, "sea_fall_loop", Vector3(-25.0, 0.0, z), -3.0, 34.0)
	GameAudio.ambient_loop(self, "forest_birds_loop", Vector3(8.0, 3.0, -8.0), -6.0, 40.0)
	GameAudio.ambient_loop(self, "forest_birds_loop", Vector3(0.0, 3.0, 4.0), -8.0, 40.0)


# ---------------------------------------------------------------- coordinate

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x + HALF), floori(p.y + HALF))


func world_of(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func block_rect(center: Vector2, size: Vector2) -> void:
	if grid == null:
		return
	var a := cell_of(center - size * 0.5)
	var b := cell_of(center + size * 0.5 - Vector2(0.01, 0.01))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			grid.set_blocked(Vector2i(x, y), true)


# ---------------------------------------------------------------- ruscello

func _build_stream_lengths() -> void:
	_stream_cum.resize(STREAM.size())
	var acc := 0.0
	for i in STREAM.size():
		if i > 0:
			acc += (STREAM[i] as Vector2).distance_to(STREAM[i - 1])
		_stream_cum[i] = acc
	stream_len = acc


## Punto del ruscello alla distanza `d` (m) dalla sorgente.
func stream_point(d: float) -> Vector2:
	d = clampf(d, 0.0, stream_len)
	for i in range(1, STREAM.size()):
		if d <= _stream_cum[i]:
			var t := (d - _stream_cum[i - 1]) / maxf(_stream_cum[i] - _stream_cum[i - 1], 0.001)
			return (STREAM[i - 1] as Vector2).lerp(STREAM[i], t)
	return STREAM[STREAM.size() - 1]


## Distanza lungo il ruscello del punto piu' vicino a `p`, e distanza trasversale.
func stream_project(p: Vector2) -> Vector2:
	var best := Vector2(0.0, 1e9)
	for i in range(1, STREAM.size()):
		var a: Vector2 = STREAM[i - 1]
		var b: Vector2 = STREAM[i]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best.y:
			best = Vector2(_stream_cum[i - 1] + t * ab.length(), d)
	return best


func ground_height(x: float, z: float) -> float:
	var h := 0.0
	var sd := stream_project(Vector2(x, z)).y
	if sd < 2.6:
		h -= 0.2 * (1.0 - smoothstep(0.7, 2.6, sd))
	if x < -13.5:
		h -= smoothstep(0.0, 4.0, -13.5 - x) * 0.9
	return h


# ---------------------------------------------------------------- ambiente

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.34, 0.45, 0.66)
	sky_mat.sky_horizon_color = Color(0.98, 0.72, 0.5)
	sky_mat.ground_horizon_color = Color(0.9, 0.68, 0.5)
	sky_mat.ground_bottom_color = Color(0.5, 0.4, 0.36)
	sky_mat.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.5, 0.46)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.9
	env.glow_hdr_threshold = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.68, 0.6)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sole"
	sun.light_color = Color(1.0, 0.76, 0.54)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 3.0
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.transform = Transform3D(Basis.looking_at(Vector3(-0.55, -0.62, -0.5)), Vector3(0, 12, 0))
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.name = "Riempimento"
	fill.light_color = Color(0.72, 0.6, 0.8)
	fill.light_energy = 0.25
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	fill.transform = Transform3D(Basis.looking_at(Vector3(0.6, -0.8, 0.4)), Vector3(0, 12, 0))
	add_child(fill)
	_day = {
		"sun_color": sun.light_color, "sun_energy": sun.light_energy, "ambient": env.ambient_light_color,
		"ambient_e": env.ambient_light_energy, "fog": env.fog_light_color,
		"top": sky_mat.sky_top_color, "hor": sky_mat.sky_horizon_color, "gh": sky_mat.ground_horizon_color,
		"exposure": env.tonemap_exposure,
	}


## 0 = tramonto dorato, 1 = notte (incursione). Le luci dei fuochi restano calde.
func set_night(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sun.light_color = (_day["sun_color"] as Color).lerp(Color(0.55, 0.62, 0.95), t)
	sun.light_energy = lerpf(_day["sun_energy"], 0.28, t)
	env.ambient_light_color = (_day["ambient"] as Color).lerp(Color(0.2, 0.26, 0.42), t)
	env.ambient_light_energy = lerpf(_day["ambient_e"], 0.55, t)
	env.fog_light_color = (_day["fog"] as Color).lerp(Color(0.12, 0.15, 0.26), t)
	env.tonemap_exposure = lerpf(_day["exposure"], 1.05, t)
	sky_mat.sky_top_color = (_day["top"] as Color).lerp(Color(0.03, 0.05, 0.12), t)
	sky_mat.sky_horizon_color = (_day["hor"] as Color).lerp(Color(0.1, 0.13, 0.25), t)
	sky_mat.ground_horizon_color = (_day["gh"] as Color).lerp(Color(0.08, 0.1, 0.18), t)
	for f in fires:
		f.light_energy = lerpf(1.4, 2.6, t)


# ---------------------------------------------------------------- terreno

func _splat_material(splat: Texture2D, mask: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SPLAT_SHADER
	m.set_shader_parameter(&"layer_albedo_height", _layer_array("T_terreno_array_albedo_height.png"))
	m.set_shader_parameter(&"layer_normal", _layer_array("T_terreno_array_normal.png"))
	m.set_shader_parameter(&"layer_orm", _layer_array("T_terreno_array_orm.png"))
	m.set_shader_parameter(&"splat_map", splat)
	m.set_shader_parameter(&"mask_map", mask)
	m.set_shader_parameter(&"grass_tint", Vector3(0.62, 0.74, 0.5))
	return m


static var _array_cache := {}


func _layer_array(file: String) -> Texture2DArray:
	if _array_cache.has(file):
		return _array_cache[file]
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
	_array_cache[file] = array
	return array


func _splat_images() -> Array[Image]:
	var n := 208
	var splat := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var mask := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var x := (float(i) + 0.5) / n * MAP - MAP * 0.5
			var z := (float(j) + 0.5) / n * MAP - MAP * 0.5
			var p := Vector2(x, z)
			var dirt := 0.0
			var sand := 0.0
			var path := 0.0
			sand = smoothstep(-12.0, -15.0, x) # spiaggia
			var sd := stream_project(p).y
			sand = maxf(sand, (1.0 - smoothstep(0.9, 2.8, sd)) * 0.9)
			dirt = (1.0 - smoothstep(3.0, 7.0, p.distance_to(SITE))) * 0.6
			dirt = maxf(dirt, (1.0 - smoothstep(2.5, 5.5, p.distance_to(CAMP))) * 0.7)
			dirt = maxf(dirt, (1.0 - smoothstep(2.0, 3.5, p.distance_to(BENCH))) * 0.5)
			for k in range(1, TRACK.size()):
				path = maxf(path, 1.0 - smoothstep(0.9, 2.0, _dist_segment(p, TRACK[k - 1], TRACK[k])))
			var dry := 0.5 + 0.5 * sin(x * 0.6) * sin(z * 0.5)
			var s := Color(dirt * (1.0 - sand), dry * 0.25 * (1.0 - sand), path * (1.0 - sand), sand)
			splat.set_pixel(i, j, s)
			mask.set_pixel(i, j, Color(0.0, 1.0, 0.8 - sand - dirt * 0.6, 0.25 + dry * 0.2))
	return [splat, mask]


static func _dist_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _build_ground() -> void:
	var imgs := _splat_images()
	var mat := _splat_material(ImageTexture.create_from_image(imgs[0]), ImageTexture.create_from_image(imgs[1]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.5
	var n := int(MAP / step)
	for j in n:
		for i in n:
			var corners := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var verts: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for c: Vector2i in corners:
				var x := c.x * step - MAP * 0.5
				var z := c.y * step - MAP * 0.5
				verts.append(Vector3(x, ground_height(x, z), z))
				uvs.append(Vector2(float(c.x) / n, float(c.y) / n))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uvs[idx])
				st.add_vertex(verts[idx])
	st.generate_normals()
	st.generate_tangents()
	ground_mesh = MeshInstance3D.new()
	ground_mesh.name = "Terreno"
	ground_mesh.mesh = st.commit()
	ground_mesh.material_override = mat
	add_child(ground_mesh)
	var sides := BlockSides.new()
	sides.name = "LatiBlocco"
	sides.base_size = Vector2(MAP, MAP)
	add_child(sides)


## Lontano a nord-est: la pianura che sale verso Troia (si vede solo da lontano, nella nebbia).
func _build_far_world() -> void:
	var imgs := _splat_images()
	var far_splat := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for j in 256:
		for i in 256:
			var x := -57.0 + (float(i) + 0.5) / 256.0 * 150.0
			var z := -146.0 + (float(j) + 0.5) / 256.0 * 120.0
			var q := Vector2(x, z)
			var path := 0.0
			for k in range(1, TRACK.size()):
				path = maxf(path, 1.0 - smoothstep(0.9, 2.2, _dist_segment(q, TRACK[k - 1], TRACK[k])))
			var plaza := (1.0 - smoothstep(4.0, 9.0, q.distance_to(Vector2(TROY_POS.x, TROY_POS.z + 5.0)))) * 0.8
			far_splat.set_pixel(i, j, Color(plaza, 0.0, path, 0.0))
	var mat := _splat_material(ImageTexture.create_from_image(far_splat), ImageTexture.create_from_image(imgs[1]))
	var far := MeshInstance3D.new()
	far.name = "PianuraLontana"
	var q := QuadMesh.new()
	q.size = Vector2(150, 120)
	q.orientation = PlaneMesh.FACE_Y
	far.mesh = q
	far.material_override = mat
	far.position = Vector3(18, -0.05, -86)
	add_child(far)
	var colle: PackedScene = load(CAMPO + "terreno/colle_acropoli_modulare/colle_acropoli_modulare.gltf")
	troy = Node3D.new()
	troy.name = "TroiaLontana"
	troy.position = TROY_POS
	add_child(troy)
	var hill := colle.instantiate() as Node3D
	var bb := _aabb_of(hill)
	var s := 46.0 / maxf(bb.size.x, 0.1)
	hill.scale = Vector3.ONE * s
	hill.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * s, -bb.position.y * s - 1.0, -(bb.position.z + bb.size.z * 0.5) * s - 18.0)
	troy.add_child(hill)
	# Mura e porta, di fronte alla collina (si vedono dal sentiero).
	var wall: PackedScene = load(CAMPO + "mura/mura_tratto/mura_tratto.gltf")
	var gate: PackedScene = load(CAMPO + "mura/porta_due_battenti/porta_due_battenti.gltf")
	var tower: PackedScene = load(CAMPO + "mura/torre_quadrata/torre_quadrata.gltf")
	for k in range(-5, 6):
		var piece: PackedScene = wall
		var width := 4.06 * 1.5
		if k == 0:
			piece = gate
			width = 5.5 * 1.5
		var n := piece.instantiate() as Node3D
		n.scale = Vector3.ONE * 1.5
		var x := k * 6.3
		if k > 0:
			x += 1.0
		if k < 0:
			x -= 1.0
		n.position = Vector3(x, 0.0, 0.0)
		troy.add_child(n)
	for sx in [-8, 8, -36, 36]:
		var t := tower.instantiate() as Node3D
		t.scale = Vector3.ONE * 1.5
		t.position = Vector3(sx, 0.0, 0.0)
		troy.add_child(t)
	troy.position.z = TROY_POS.z
	troy.rotation.y = 0.0


# ---------------------------------------------------------------- mare e ruscello

func _build_sea() -> void:
	sea = SeaWater.new()
	sea.name = "Mare"
	var box := BoxMesh.new()
	box.size = Vector3(11.4, 0.4, MAP)
	sea.mesh = box
	sea.position = Vector3(-26.0 + 11.4 * 0.5, -0.3, 0.0)
	sea.natural_shore = false
	sea.shore_x = SEA_X
	sea.add_to_group(&"grass_exclude")
	add_child(sea)
	# La cascata sul bordo ovest e' la stessa del livello 1 (SeaFall): SeaWater l'ha creata per il mare lungo 41 m del
	# livello 1 (z -19..22), qui il blocco e' lungo 52 m, quindi la rifaccio su tutto il lato.
	if sea.fall:
		sea.fall.free()
	var fall := SeaFall.new()
	fall.name = "Cascata"
	fall.edge_x = -26.0
	fall.z_range = Vector2(-MAP * 0.5, MAP * 0.5)
	sea.add_child(fall)
	sea.fall = fall


func _build_stream() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter(&"normal_tex", SEA_NORMAL)
	mat.set_shader_parameter(&"uv_scale", 0.45)
	mat.set_shader_parameter(&"mouth", MOUTH)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.6
	var count := int(stream_len / step)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0
	for i in range(count + 1):
		var d := minf(i * step, stream_len)
		var p := stream_point(d)
		var ahead := stream_point(minf(d + 0.3, stream_len)) - stream_point(maxf(d - 0.3, 0.0))
		var dir := ahead.normalized()
		var side := Vector2(-dir.y, dir.x)
		var w := 1.25 + 0.15 * sin(d * 0.7) + 1.7 * smoothstep(stream_len - 6.0, stream_len, d)
		var l := p - side * w
		var r := p + side * w
		var y := -0.12
		var vl := Vector3(l.x, y, l.y)
		var vr := Vector3(r.x, y, r.y)
		var v := d
		if i > 0:
			st.set_uv(Vector2(0, prev_v)); st.add_vertex(prev_l)
			st.set_uv(Vector2(1, prev_v)); st.add_vertex(prev_r)
			st.set_uv(Vector2(1, v)); st.add_vertex(vr)
			st.set_uv(Vector2(0, prev_v)); st.add_vertex(prev_l)
			st.set_uv(Vector2(1, v)); st.add_vertex(vr)
			st.set_uv(Vector2(0, v)); st.add_vertex(vl)
		prev_l = vl
		prev_r = vr
		prev_v = v
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Ruscello"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_build_river_mouth()
	# Schizzi di schiuma dove il ruscello si getta nel mare.
	var spray := spawn_model(POLY + "rocce/boulder_01/boulder_01.gltf", Vector3(-14.2, -0.35, 8.2), 20.0, 1.0, self)
	spray.name = "ScoglioFoce"


const MOUTH := Vector2(-15.4, 6.9)


## Foce: pennacchio schiumoso e onde che si propagano nel mare (shader river_mouth).
func _build_river_mouth() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/river_mouth.gdshader")
	mat.set_shader_parameter(&"normal_tex", SEA_NORMAL)
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 16.0)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	var mi := MeshInstance3D.new()
	mi.name = "FoceRuscello"
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(MOUTH.x, -0.07, MOUTH.y)
	add_child(mi)


# ---------------------------------------------------------------- griglia, camera, unita'

func _build_grid_and_camera() -> void:
	grid = DioramaGrid.new()
	grid.name = "Griglia"
	grid.size = Vector2i(GRID, GRID)
	grid.extra_cells = Vector2i.ZERO
	grid.show_tiles = false
	add_child(grid)
	# Acqua del mare: non si cammina.
	for cy in GRID:
		for cx in GRID:
			if (cx + 0.5) - HALF < SEA_X:
				grid.set_blocked(Vector2i(cx, cy), true)
	units_root = Node3D.new()
	units_root.name = "Unita"
	add_child(units_root)
	camera = FixedCamera.new()
	camera.name = "Camera"
	camera.fov = 28.0
	camera.yaw_degrees = 30.0
	camera.pitch_degrees = -38.0
	camera.distance = 31.0
	camera.follow_bounds = Rect2(-16, -17, 32, 34)
	camera.current = true
	add_child(camera)
	camera.target = world_of(START)
	var ulisse: GridUnit = (load("res://scenes/characters/ulisse/ulisse.tscn") as PackedScene).instantiate()
	ulisse.name = "Ulisse"
	ulisse.position = world_of(START)
	units_root.add_child(ulisse)
	player = ulisse
	camera.follow_target = camera.get_path_to(ulisse)
	camera._follow = ulisse
	var acheo := load("res://scenes/characters/achei/soldato_acheo.tscn") as PackedScene
	var spots := [Vector2(-11.5, -4.5), Vector2(-7.5, -5.5), Vector2(-12.5, -7.0), Vector2(-8.5, -8.5)]
	for i in spots.size():
		var a := acheo.instantiate() as GridUnit
		a.name = "SoldatoAcheo%d" % (i + 1)
		a.position = world_of(spots[i])
		units_root.add_child(a)
		allies.append(a)


# ---------------------------------------------------------------- foresta, accampamento, navi

func _build_forest() -> void:
	var trees := Node3D.new()
	trees.name = "Foresta"
	add_child(trees)
	var firs := ["alberi/fir_sapling_medium/fir_sapling_medium_a.gltf", "alberi/fir_sapling_medium/fir_sapling_medium_b.gltf",
		"alberi/fir_sapling_medium/fir_sapling_medium_c.gltf"]
	var q := int(Quality.current())
	var decor: int = [14, 22, 30][clampi(q, 0, 2)]
	var placed := 0
	var guard := 0
	while placed < decor and guard < 800:
		guard += 1
		var p := Vector2(_rng.randf_range(-13.0, 19.5), _rng.randf_range(-19.5, 19.0))
		if _too_close_to_work(p) or not _in_forest_belt(p):
			continue
		var tooclose := false
		for spot: Vector2 in TREE_SPOTS:
			if p.distance_to(spot) < 3.0:
				tooclose = true
		if tooclose:
			continue
		var t := spawn_model(POLY + firs[_rng.randi() % firs.size()], world_of(p), _rng.randf() * 360.0, _rng.randf_range(4.6, 6.4), trees)
		all_trees.append(t)
		block_rect(p, Vector2(0.7, 0.7))
		placed += 1
	for i in TREE_SPOTS.size():
		var spot: Vector2 = TREE_SPOTS[i]
		var tree := spawn_model(POLY + firs[i % 2], world_of(spot), _rng.randf() * 360.0, 5.6, trees)
		tree.name = "Abete%d" % (i + 1)
		tree.add_to_group(&"choppable")
		tree_nodes.append(tree)
		all_trees.append(tree)
		block_rect(spot, Vector2(0.7, 0.7))
	# Sottobosco di rocce e felci lungo le rive.
	for i in 16:
		var p := Vector2(_rng.randf_range(-12.0, 19.0), _rng.randf_range(-19.0, 18.0))
		if _too_close_to_work(p):
			continue
		spawn_model(POLY + "rocce/boulder_01/boulder_01.gltf", world_of(p), _rng.randf() * 360.0, _rng.randf_range(0.5, 1.1), trees)
	for i in 28:
		var p := Vector2(_rng.randf_range(-12.0, 19.0), _rng.randf_range(-19.0, 18.0))
		if _too_close_to_work(p):
			continue
		var fern: String = ["fern_02_a", "fern_02_b", "fern_02_c", "fern_02_d"][_rng.randi() % 4]
		spawn_model(POLY + "vegetazione/fern_02/%s.gltf" % fern, world_of(p), _rng.randf() * 360.0, _rng.randf_range(0.5, 0.9), trees)


## Fascia di bosco fitto ai bordi (est e nord): al centro restano radure ben visibili dalla camera.
func _in_forest_belt(p: Vector2) -> bool:
	return p.x > 12.5 or p.y < -16.5 or (p.x > 6.0 and p.y > 14.0)


func _too_close_to_work(p: Vector2) -> bool:
	if p.distance_to(SITE) < 6.0 or p.distance_to(CAMP) < 6.5 or p.distance_to(START) < 3.5 or p.distance_to(BENCH) < 3.0 or p.distance_to(PILE) < 3.0:
		return true
	if stream_project(p).y < 2.2:
		return true
	for k in range(1, TRACK.size()):
		if _dist_segment(p, TRACK[k - 1], TRACK[k]) < 2.2:
			return true
	return false


func _build_camp_and_yard() -> void:
	var camp := Node3D.new()
	camp.name = "Accampamento"
	add_child(camp)
	var t1 := spawn_model(CAMPO + "tende/tenda_pelli/tenda_pelli.gltf", world_of(CAMP + Vector2(-2.5, -1.5)), 20.0, 0.0, camp, 4.8)
	var t2 := spawn_model(CAMPO + "tende/tenda_tela_rami/tenda_tela_rami.gltf", world_of(CAMP + Vector2(2.8, -2.2)), -35.0, 0.0, camp, 5.0)
	block_rect(CAMP + Vector2(-2.5, -1.5), Vector2(3, 3))
	block_rect(CAMP + Vector2(2.8, -2.2), Vector2(3, 3))
	var fire := spawn_model(CAMPO + "fuochi/focolare_calderone/focolare_calderone.gltf", world_of(CAMP + Vector2(0.2, 2.0)), 0.0, 1.5, camp)
	block_rect(CAMP + Vector2(0.2, 2.0), Vector2(1, 1))
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.6, 0.25)
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.position = world_of(CAMP + Vector2(0.2, 2.0)) + Vector3(0, 1.1, 0)
	add_child(light)
	fires.append(light)
	TorchFlame.attach(fire, Vector3(0, 0.55, 0), 0.9, 0.7)
	# Cantiere: banco da lavoro, pila di travi, travi sparse, relitto portato dal mare.
	var yard := Node3D.new()
	yard.name = "Cantiere"
	add_child(yard)
	spawn_model(L2 + "panca.glb", world_of(BENCH), 70.0, 0.0, yard, 2.0)
	block_rect(BENCH, Vector2(2, 1))
	var pile := spawn_model(L2 + "travi_impilate.glb", world_of(PILE), 15.0, 0.0, yard, 2.4)
	pile.name = "PilaTravi"
	pile.visible = false
	spawn_model(L2 + "relitto.glb", Vector3(-13.0, -0.1, 11.5), 40.0, 0.0, yard, 3.0)
	# Sbarramento sul ruscello: i tronchi si fermano qui.
	for k in 3:
		var b := spawn_model(L2 + "trave.glb", Vector3(LANDING.x - 1.3, 0.05 + 0.2 * k, LANDING.y + (k - 1) * 0.9), 75.0, 0.0, yard, 1.9)
		b.rotation.x = 0.0
	# Fuochi/torce del cantiere.
	var tl := OmniLight3D.new()
	tl.light_color = Color(1, 0.62, 0.3)
	tl.light_energy = 1.4
	tl.omni_range = 7.0
	tl.position = world_of(SITE + Vector2(3, 3)) + Vector3(0, 1.5, 0)
	add_child(tl)
	fires.append(tl)


func _build_ships() -> void:
	var holder := Node3D.new()
	holder.name = "Navi"
	add_child(holder)
	var path := CAMPO.replace("campo/", "navi/nave_achea/nave_achea.gltf")
	for spec in [[Vector2(-13.0, -5.0), 95.0], [Vector2(-13.5, 2.0), 85.0], [Vector2(-14.0, 16.5), 100.0]]:
		var ship := spawn_model(path, Vector3(spec[0].x, -0.55, spec[0].y), spec[1], 0.0, holder, 11.0)
		ships.append(ship)
		block_rect(Vector2(spec[0].x + 0.5, spec[0].y), Vector2(4.0, 10.0))
	# Navi al largo, gia' in mare.
	var far_ship := spawn_model(path, Vector3(-21.5, -0.7, -10.0), 80.0, 0.0, holder, 11.0)
	ships.append(far_ship)


# ---------------------------------------------------------------- cavallo e persone

func _build_horse() -> void:
	horse = Node3D.new()
	horse.name = "CavalloDiTroia"
	horse.position = world_of(SITE)
	add_child(horse)
	var inst := (load(L2 + "cavallo_troia.glb") as PackedScene).instantiate() as Node3D
	var bb := _aabb_of(inst)
	var scale := 4.6
	horse_height = bb.size.y
	inst.scale = Vector3.ONE * scale
	inst.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * scale, -bb.position.y * scale, -(bb.position.z + bb.size.z * 0.5) * scale)
	horse.add_child(inst)
	horse_material = ShaderMaterial.new()
	horse_material.shader = load("res://assets/shaders/horse_reveal.gdshader")
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var src := m.get_active_material(0) as BaseMaterial3D
		if src:
			horse_material.set_shader_parameter(&"albedo_tex", src.albedo_texture)
			horse_material.set_shader_parameter(&"orm_tex", src.orm_texture if src.orm_texture else src.roughness_texture)
			horse_material.set_shader_parameter(&"normal_tex", src.normal_texture)
		m.material_override = horse_material
		m.set_meta(&"base_y", bb.position.y)
	horse_material.set_shader_parameter(&"reveal_y", bb.position.y - 0.1)
	horse.set_meta(&"base_y", bb.position.y)
	horse.set_meta(&"top_y", bb.position.y + bb.size.y)
	horse.set_meta(&"scale", scale)
	block_rect(SITE, Vector2(4.0, 8.0))
	horse.visible = true


## Porta la parte visibile del cavallo a `fraction` (0..1 dell'altezza).
func set_horse_progress(fraction: float) -> void:
	var base := float(horse.get_meta(&"base_y"))
	var top := float(horse.get_meta(&"top_y"))
	horse_material.set_shader_parameter(&"reveal_y", lerpf(base - 0.1, top + 0.1, clampf(fraction, 0.0, 1.0)))


func _build_people() -> void:
	var people := Node3D.new()
	people.name = "Carpentieri"
	add_child(people)
	epeus = _spawn_rigged(L2 + "epeo.glb", SITE + Vector2(-3.2, 2.5), 0.95, people)
	epeus.name = "Epeo"
	for i in 3:
		var c := _spawn_rigged(L2 + "carpentiere.glb", SITE + Vector2(2.6 + i * 1.0, 1.0 - i * 1.3), 0.92, people)
		c.name = "Carpentiere%d" % (i + 1)
		carpenters.append(c)
	_play(epeus, "Walking")
	var tasks := ["Sega", "Heavy_Hammer_Swing", "Sega"]
	for i in carpenters.size():
		_play(carpenters[i], tasks[i])


func _spawn_rigged(path: String, p: Vector2, scale: float, parent: Node) -> Node3D:
	var root := Node3D.new()
	root.position = world_of(p)
	parent.add_child(root)
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.scale = Vector3.ONE * scale
	root.add_child(inst)
	return root


func _play(person: Node3D, anim: String, speed := 1.0) -> void:
	var ap := person.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for a in ap.get_animation_list():
		if String(a).ends_with(anim):
			var animation := ap.get_animation(a)
			if animation:
				animation.loop_mode = Animation.LOOP_LINEAR
			ap.speed_scale = speed
			ap.play(a)
			return


func person_play(person: Node3D, anim: String, speed := 1.0) -> void:
	_play(person, anim, speed)


func person_stop(person: Node3D) -> void:
	var ap := person.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.pause()


# ---------------------------------------------------------------- utilita'

## Scatola che contiene tutte le mesh sotto `node`, nello spazio di `node`.
static func _aabb_of(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != node:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var bb := t * m.mesh.get_aabb()
		result = bb if first else result.merge(bb)
		first = false
	return result


## Istanzia un modello, lo porta all'altezza `height` (o alla lunghezza maggiore `longest`) e lo appoggia a terra.
func spawn_model(path: String, pos: Vector3, yaw_deg: float, height: float, parent: Node, longest := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = deg_to_rad(yaw_deg)
	var ps := load(path) as PackedScene
	if ps == null:
		push_warning("Level2World: modello mancante %s" % path)
		parent.add_child(root)
		return root
	var inst := ps.instantiate() as Node3D
	if path.contains("/polyhaven/"):
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).mesh = FoliageTint.apply((mi as MeshInstance3D).mesh)
	var bb := _aabb_of(inst)
	var s := 1.0
	if height > 0.0 and bb.size.y > 0.001:
		s = height / bb.size.y
	elif longest > 0.0:
		s = longest / maxf(maxf(bb.size.x, bb.size.z), 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * s, -bb.position.y * s, -(bb.position.z + bb.size.z * 0.5) * s)
	root.add_child(inst)
	parent.add_child(root)
	return root
