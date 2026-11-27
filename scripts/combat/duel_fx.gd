class_name DuelFx
extends RefCounted
## Effetti del duello in prima persona: ferite che restano sul corpo del nemico (tagli e punture
## procedurali, umidi e con colature, attaccati alle ossa così seguono le animazioni) e sangue a
## particelle (gocce pesanti + nebbia rossa) più vicino e abbondante di ClashFx, pensato per la
## camera a pochi metri. Tutto è creato una volta e riusato: pool fisso di emettitori.

## Direzione di un colpo (stessa enum di Duel.Aim).
enum Aim { HIGH, LEFT, RIGHT, LOW }

const MAX_WOUNDS_PER_UNIT := 8
const WOUND_SIZE := 0.3
const POOL := 4

static var _textures: Array[ImageTexture] = []
static var _images: Array[Image] = []
static var _task := -1
static var _quad: QuadMesh
static var _root: Node3D
static var _drops: Array[GPUParticles3D] = []
static var _mist: Array[GPUParticles3D] = []
static var _next := 0
static var _drop_mat: ParticleProcessMaterial
static var _mist_mat: ParticleProcessMaterial


## Quanti emettitori usare: a qualità bassa meno gocce.
static func _amount_ratio() -> float:
	match Quality.current():
		Quality.Level.LOW:
			return 0.45
		Quality.Level.MEDIUM:
			return 0.75
	return 1.0


# =====================================================================================================
# Ferite sul corpo
# =====================================================================================================

## Prepara in un thread le texture delle ferite (all'inizio del duello, durante la transizione):
## così il primo colpo a segno non causa uno scatto.
static func prepare() -> void:
	if not _textures.is_empty() or _task >= 0:
		return
	_task = WorkerThreadPool.add_task(_make_images)


## Le texture pronte (aspetta il thread se non ha ancora finito).
static func _ensure_textures() -> void:
	if not _textures.is_empty():
		return
	if _task < 0:
		_make_images()
	else:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for img in _images:
		_textures.append(ImageTexture.create_from_image(img))
	_images.clear()
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE * WOUND_SIZE


## Immagini delle ferite (variante 0 = taglio "\", 1 = orizzontale, 2 = taglio "/", 3 = verticale,
## 4 = puntura). Taglio dal bordo gonfio e ombra livida, interno scuro e lucido, colature verso il basso.
static func _make_images() -> void:
	var out: Array[Image] = []
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	const SIZE := 128
	var angles := [deg_to_rad(38.0), 0.0, deg_to_rad(-38.0), deg_to_rad(90.0)]
	for variant in 5:
		var puncture := variant == 4
		var dir := Vector2(cos(angles[variant]), sin(angles[variant])) if not puncture else Vector2.RIGHT
		var half_len := 0.74
		# Colature: punti di partenza lungo il taglio e lunghezza.
		var drips: Array[Vector3] = []
		for i in 4:
			var t := rng.randf_range(-0.55, 0.55) * half_len
			var start := dir * t
			if puncture:
				start = Vector2(rng.randf_range(-0.12, 0.12), 0.0)
			drips.append(Vector3(start.x, start.y, rng.randf_range(0.25, 0.7)))
		noise.seed = 31 * variant + 5
		var img := Image.create(SIZE, SIZE, true, Image.FORMAT_RGBA8)
		for y in SIZE:
			for x in SIZE:
				var p := Vector2((x + 0.5) / SIZE * 2.0 - 1.0, (y + 0.5) / SIZE * 2.0 - 1.0)
				var wob := noise.get_noise_2d(x * 1.7, y * 1.7)
				var d: float
				var w: float
				if puncture:
					d = p.length() + wob * 0.05
					w = 0.1
				else:
					var t := clampf(p.dot(dir), -half_len, half_len)
					d = (p - dir * t).length() + wob * 0.025
					var u := t / half_len
					w = 0.07 * pow(maxf(1.0 - u * u, 0.0), 0.6) + 0.004
				var col := Color(0, 0, 0, 0)
				# Alone livido e gonfio attorno al taglio.
				var halo := smoothstep(w + 0.26, w + 0.02, d)
				col = Color(0.28, 0.05, 0.06, halo * 0.34)
				# Labbra della ferita: carne scura e umida.
				var lip := smoothstep(w + 0.05, w + 0.012, d)
				if lip > 0.0:
					var lip_col := Color(0.42, 0.06, 0.05).lerp(Color(0.2, 0.02, 0.02), 1.0 - clampf((d - w) / 0.05, 0.0, 1.0))
					col = col.blend(Color(lip_col.r, lip_col.g, lip_col.b, lip * 0.92))
				# Interno: sangue scuro che brilla.
				var core := smoothstep(w, w * 0.55, d)
				if core > 0.0:
					var depth := clampf(1.0 - d / maxf(w, 0.001), 0.0, 1.0)
					var core_col := Color(0.26, 0.008, 0.008).lerp(Color(0.05, 0.002, 0.002), depth)
					col = col.blend(Color(core_col.r, core_col.g, core_col.b, core))
				# Colature.
				for dr in drips:
					var dy := p.y - dr.y
					if dy > 0.0 and dy < dr.z:
						var width := 0.018 * (1.0 - dy / dr.z * 0.65) + 0.004
						var a := smoothstep(width, width * 0.4, absf(p.x - dr.x - wob * 0.02))
						if a > 0.0:
							col = col.blend(Color(0.2, 0.008, 0.008, a * 0.88))
				img.set_pixel(x, y, col)
		img.generate_mipmaps()
		out.append(img)
	_images = out


## Aggiunge una ferita al torso di `foe` (un GridUnit con CharacterModel) per un colpo `aim` visto
## dalla camera `cam`. La ferita segue il corpo (attaccata a un osso).
static func add_wound(foe: GridUnit, aim: int, cam: Camera3D) -> void:
	var m := foe.get_node_or_null(^"Model") as CharacterModel
	if m == null or m.skeleton == null or cam == null:
		return
	var sk := m.skeleton
	var hips := sk.find_bone("hips")
	var neck := sk.find_bone("neck")
	var spine := sk.find_bone("spine")
	if hips < 0 or neck < 0 or spine < 0:
		return
	_ensure_textures()
	# Il torso fa da asse: più alto per i colpi dall'alto, più basso per le stoccate.
	var k: float = [0.82, 0.55, 0.55, 0.22][aim]
	var p0 := sk.to_global(sk.get_bone_global_pose(hips).origin)
	var p1 := sk.to_global(sk.get_bone_global_pose(neck).origin)
	var center := p0.lerp(p1, k)
	var to_cam := cam.global_position - center
	to_cam.y = 0.0
	to_cam = to_cam.normalized() if to_cam.length() > 0.01 else Vector3.BACK
	var right := cam.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var side: float = [0.0, 0.05, -0.05, 0.0][aim]
	center += right * (side + randf_range(-0.03, 0.03))
	center.y += randf_range(-0.04, 0.04)
	var pos := center + to_cam * 0.135
	var variant := [[0, 2, 3][randi() % 3], 2, 0, 4][aim] as int
	var attach := _bone_attachment(sk, &"spine")
	# Troppe ferite: la più vecchia sparisce.
	var wounds: Array = []
	for c in attach.get_children():
		if c.name.begins_with("Ferita"):
			wounds.append(c)
	if wounds.size() >= MAX_WOUNDS_PER_UNIT:
		wounds[0].queue_free()
	var inst := MeshInstance3D.new()
	inst.name = "Ferita%d" % randi()
	inst.mesh = _quad
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _textures[variant]
	mat.roughness = 0.12
	mat.metallic_specular = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 3
	inst.material_override = mat
	attach.add_child(inst)
	var basis := Basis.looking_at(-to_cam, Vector3.UP)
	basis = basis.rotated(to_cam, randf_range(-0.2, 0.2))
	inst.global_transform = Transform3D(basis, pos)
	# Nasce piccola e si apre, poi cola per qualche istante (la texture ha già le colature).
	inst.scale = Vector3.ONE * 0.4
	var tw := inst.create_tween()
	tw.tween_property(inst, "scale", Vector3.ONE * randf_range(0.9, 1.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _bone_attachment(sk: Skeleton3D, bone: StringName) -> BoneAttachment3D:
	var node := sk.get_node_or_null(^"Ferite") as BoneAttachment3D
	if node == null:
		node = BoneAttachment3D.new()
		node.name = "Ferite"
		node.bone_name = bone
		sk.add_child(node)
	return node


# =====================================================================================================
# Sangue a particelle
# =====================================================================================================

static func _ensure(anchor: Node) -> bool:
	if anchor == null or not anchor.is_inside_tree():
		return false
	if is_instance_valid(_root) and _root.is_inside_tree():
		return true
	_drops.clear()
	_mist.clear()
	_next = 0
	_root = Node3D.new()
	_root.name = "DuelFxPool"
	anchor.get_viewport().add_child(_root)
	_drop_mat = ParticleProcessMaterial.new()
	_drop_mat.direction = Vector3(0, 0, -1)
	_drop_mat.spread = 38.0
	_drop_mat.initial_velocity_min = 1.4
	_drop_mat.initial_velocity_max = 5.2
	_drop_mat.gravity = Vector3(0, -9.8, 0)
	_drop_mat.damping_min = 0.3
	_drop_mat.damping_max = 1.0
	_drop_mat.scale_min = 0.5
	_drop_mat.scale_max = 1.8
	_drop_mat.particle_flag_align_y = true
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.0065
	drop_mesh.height = 0.024
	drop_mesh.radial_segments = 6
	drop_mesh.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.3, 0.01, 0.008)
	dmat.roughness = 0.3
	dmat.metallic_specular = 0.45
	drop_mesh.material = dmat
	# Nebbia: sbuffi rossi che si espandono e svaniscono.
	_mist_mat = ParticleProcessMaterial.new()
	_mist_mat.direction = Vector3(0, 0, -1)
	_mist_mat.spread = 55.0
	_mist_mat.initial_velocity_min = 0.3
	_mist_mat.initial_velocity_max = 1.6
	_mist_mat.gravity = Vector3(0, -0.8, 0)
	_mist_mat.damping_min = 1.5
	_mist_mat.damping_max = 3.0
	_mist_mat.scale_min = 0.5
	_mist_mat.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.4))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	_mist_mat.color_ramp = ramp_tex
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 1.6))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	_mist_mat.scale_curve = curve_tex
	var mist_mesh := QuadMesh.new()
	mist_mesh.size = Vector2.ONE * 0.2
	var mmat := StandardMaterial3D.new()
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mmat.vertex_color_use_as_albedo = true
	mmat.albedo_texture = _soft_blob()
	mmat.albedo_color = Color(0.46, 0.025, 0.015)
	mist_mesh.material = mmat
	for i in POOL:
		var p := GPUParticles3D.new()
		p.name = "Gocce%d" % i
		p.amount = 56
		p.lifetime = 1.1
		p.one_shot = true
		p.explosiveness = 0.95
		p.emitting = false
		p.local_coords = false
		p.process_material = _drop_mat
		p.draw_pass_1 = drop_mesh
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
		_root.add_child(p)
		_drops.append(p)
		var q := GPUParticles3D.new()
		q.name = "Nebbia%d" % i
		q.amount = 14
		q.lifetime = 0.9
		q.one_shot = true
		q.explosiveness = 0.9
		q.emitting = false
		q.local_coords = false
		q.process_material = _mist_mat
		q.draw_pass_1 = mist_mesh
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
		_root.add_child(q)
		_mist.append(q)
	return true


static func _soft_blob() -> ImageTexture:
	const SIZE := 64
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var r := Vector2((x + 0.5) / SIZE * 2.0 - 1.0, (y + 0.5) / SIZE * 2.0 - 1.0).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - r, 0.0, 1.0) * clampf(1.0 - r, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Spruzzo di sangue da un colpo a segno in `pos`: `spray` è la direzione verso cui schizza (di solito
## verso chi guarda, più la direzione della lama). `heavy`: colpo mortale, getto molto più abbondante.
static func spray(anchor: Node, pos: Vector3, spray_dir: Vector3, heavy := false) -> void:
	if not _ensure(anchor):
		return
	var aim := spray_dir.normalized() if spray_dir.length() > 0.01 else Vector3.BACK
	var basis := Basis.looking_at(aim, Vector3.UP)
	var i := _next
	_next = (_next + 1) % POOL
	var drops := _drops[i]
	drops.amount_ratio = _amount_ratio() * (1.0 if heavy else 0.62)
	drops.global_position = pos
	drops.global_basis = basis
	drops.restart()
	drops.emitting = true
	var mist := _mist[i]
	mist.amount_ratio = _amount_ratio() * (1.0 if heavy else 0.7)
	mist.global_position = pos
	mist.global_basis = basis
	mist.restart()
	mist.emitting = true
