class_name ClashFx
extends RefCounted
## Effetti dei combattimenti corpo a corpo: scintille e lampo al contatto lama contro lama o scudo,
## spruzzi e macchie di sangue al colpo andato a segno, cadaveri che restano a terra.
##
## Tutto vive in pool creati al primo uso (particelle GPU a scatto singolo, luci di lampo, quad delle
## macchie): nessuna istanza nuova durante la battaglia. Le macchie sono quad appoggiati al rilievo e
## non Decal perché il gioco usa il renderer Compatibility. A distanza o fuori dalla camera gli effetti
## non partono. Aggiungere un cadavere con register_corpse(): oltre il tetto sparisce il più vecchio
## che non è inquadrato.

const SPARK_POOL := 6
const BLOOD_POOL := 8
const LIGHT_POOL := 3
## Distanza massima dalla camera (m) oltre la quale gli effetti non partono.
const FX_DISTANCE := 45.0
const STAIN_DISTANCE := 70.0

## Spegne tutti gli effetti (misure di prestazioni prima/dopo).
static var enabled := true
static var _root: Node3D
static var _grid: DioramaGrid
static var _sparks: Array[GPUParticles3D] = []
static var _blood: Array[GPUParticles3D] = []
static var _lights: Array[OmniLight3D] = []
static var _stains: Array[MeshInstance3D] = []
static var _stain_tweens: Array[Tween] = []
static var _next_spark := 0
static var _next_blood := 0
static var _next_light := 0
static var _next_stain := 0
static var _spark_proc: ParticleProcessMaterial
static var _blood_proc: ParticleProcessMaterial
static var _spark_mesh: Mesh
static var _blood_mesh: Mesh
static var _stain_textures: Array[ImageTexture] = []
static var _stain_mesh: PlaneMesh
static var _corpses: Array[Node3D] = []


# =====================================================================================================
# Impostazioni per qualità
# =====================================================================================================

static func _stain_budget() -> int:
	match Quality.current():
		Quality.Level.LOW:
			return 12
		Quality.Level.MEDIUM:
			return 32
	return 64


static func _corpse_budget() -> int:
	match Quality.current():
		Quality.Level.LOW:
			return 30
		Quality.Level.MEDIUM:
			return 60
	return 120


static func _amount_ratio() -> float:
	match Quality.current():
		Quality.Level.LOW:
			return 0.4
		Quality.Level.MEDIUM:
			return 0.7
	return 1.0


# =====================================================================================================
# Contenitore, camera e terreno
# =====================================================================================================

## Il contenitore sta accanto alla griglia: nel mondo 3D del gioco (che può essere un SubViewport).
static func _ensure(anchor: Node) -> bool:
	if anchor == null or not anchor.is_inside_tree():
		return false
	if is_instance_valid(_root) and _root.is_inside_tree():
		return true
	_grid = anchor.get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	var parent: Node = _grid.get_parent() if _grid else anchor.get_parent()
	if parent == null:
		return false
	_sparks.clear()
	_blood.clear()
	_lights.clear()
	_stains.clear()
	_stain_tweens.clear()
	_next_spark = 0
	_next_blood = 0
	_next_light = 0
	_next_stain = 0
	_root = Node3D.new()
	_root.name = "ClashFxPool"
	parent.add_child(_root)
	return true


## Vero se il punto è abbastanza vicino alla camera (e, se `framed`, inquadrato).
static func _visible_enough(pos: Vector3, max_distance: float, framed := true) -> bool:
	if not is_instance_valid(_root) or not _root.is_inside_tree():
		return false
	var cam := _root.get_viewport().get_camera_3d()
	if cam == null:
		return true
	if cam.global_position.distance_to(pos) > max_distance and cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		return false
	return not framed or cam.is_position_in_frustum(pos)


## Quota del terreno nel punto (x, z) del mondo.
static func ground_y(pos: Vector3) -> float:
	if _grid == null or not is_instance_valid(_grid):
		return pos.y
	return _grid.to_global(Vector3.ZERO).y + _grid.get_height_at_world(pos)


# =====================================================================================================
# Scintille
# =====================================================================================================

static func _make_sparks() -> void:
	_spark_proc = ParticleProcessMaterial.new()
	_spark_proc.direction = Vector3(0, 0, -1)
	_spark_proc.spread = 70.0
	_spark_proc.initial_velocity_min = 2.0
	_spark_proc.initial_velocity_max = 6.0
	_spark_proc.gravity = Vector3(0, -9.8, 0)
	_spark_proc.damping_min = 1.0
	_spark_proc.damping_max = 3.0
	_spark_proc.particle_flag_align_y = true
	_spark_proc.scale_min = 0.6
	_spark_proc.scale_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.15))
	var tex := CurveTexture.new()
	tex.curve = curve
	_spark_proc.scale_curve = tex
	var box := BoxMesh.new()
	box.size = Vector3(0.006, 0.07, 0.006)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.7, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.2)
	mat.emission_energy_multiplier = 4.0
	box.material = mat
	_spark_mesh = box
	for i in SPARK_POOL:
		var p := GPUParticles3D.new()
		p.name = "Scintille%d" % i
		p.amount = 18
		p.lifetime = 0.35
		p.one_shot = true
		p.explosiveness = 1.0
		p.emitting = false
		p.local_coords = false
		p.process_material = _spark_proc
		p.draw_pass_1 = _spark_mesh
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
		_root.add_child(p)
		_sparks.append(p)
	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.name = "LampoLama%d" % i
		l.light_color = Color(1.0, 0.8, 0.5)
		l.omni_range = 2.8
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		_root.add_child(l)
		_lights.append(l)


## Scintille e lampo al contatto metallo contro metallo. `normal`: verso da cui arriva il colpo.
static func sparks(anchor: Node, pos: Vector3, normal: Vector3) -> void:
	if not enabled:
		return
	if not _ensure(anchor) or not _visible_enough(pos, FX_DISTANCE):
		return
	if _sparks.is_empty():
		_make_sparks()
	var p := _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	p.amount_ratio = _amount_ratio()
	var dir := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	p.global_position = pos
	if absf(dir.dot(Vector3.UP)) > 0.98:
		p.global_basis = Basis.looking_at(dir, Vector3.RIGHT)
	else:
		p.global_basis = Basis.looking_at(dir, Vector3.UP)
	p.restart()
	p.emitting = true
	var l := _lights[_next_light]
	_next_light = (_next_light + 1) % _lights.size()
	l.global_position = pos
	l.visible = true
	l.light_energy = 2.5
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, 0.14)
	t.tween_callback(func() -> void: l.visible = false)


# =====================================================================================================
# Sangue
# =====================================================================================================

static func _make_blood() -> void:
	_blood_proc = ParticleProcessMaterial.new()
	_blood_proc.direction = Vector3(0, 0, -1)
	_blood_proc.spread = 32.0
	_blood_proc.initial_velocity_min = 1.2
	_blood_proc.initial_velocity_max = 4.2
	_blood_proc.gravity = Vector3(0, -9.8, 0)
	_blood_proc.damping_min = 0.4
	_blood_proc.damping_max = 1.2
	_blood_proc.scale_min = 0.6
	_blood_proc.scale_max = 1.7
	_blood_proc.particle_flag_align_y = true
	var sphere := BoxMesh.new()
	sphere.size = Vector3(0.007, 0.03, 0.007)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.008, 0.008)
	mat.roughness = 0.35
	sphere.material = mat
	_blood_mesh = sphere
	for i in BLOOD_POOL:
		var p := GPUParticles3D.new()
		p.name = "Sangue%d" % i
		p.amount = 26
		p.lifetime = 0.8
		p.one_shot = true
		p.explosiveness = 0.92
		p.emitting = false
		p.local_coords = false
		p.process_material = _blood_proc
		p.draw_pass_1 = _blood_mesh
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
		_root.add_child(p)
		_blood.append(p)


## Spruzzo di sangue da un colpo a segno in `pos`, lungo `dir` (verso di avanzamento della lama).
## `heavy`: ferita mortale, spruzzo più abbondante. Lascia anche qualche goccia a terra.
static func blood_hit(anchor: Node, pos: Vector3, dir: Vector3, heavy := false) -> void:
	if not enabled:
		return
	if not _ensure(anchor) or not _visible_enough(pos, FX_DISTANCE):
		return
	if _blood.is_empty():
		_make_blood()
	var d := Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length() > 0.01 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var aim := (d + Vector3.UP * 0.35).normalized()
	var p := _blood[_next_blood]
	_next_blood = (_next_blood + 1) % _blood.size()
	p.amount_ratio = _amount_ratio() * (1.0 if heavy else 0.6)
	p.global_position = pos
	p.global_basis = Basis.looking_at(aim, Vector3.UP)
	p.restart()
	p.emitting = true
	# Le gocce cadono a terra dopo il volo: macchie piccole nella direzione del colpo.
	var drops := 2 if heavy else 1
	if Quality.current() == Quality.Level.LOW:
		drops = 1
	for i in drops:
		var landing := pos + d * randf_range(0.5, 1.4) + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
		var wait := randf_range(0.3, 0.55)
		_root.get_tree().create_timer(wait).timeout.connect(func() -> void:
			stain(anchor, landing, randf_range(0.14, 0.3) * (1.3 if heavy else 1.0), 0.0, false))


# =====================================================================================================
# Macchie
# =====================================================================================================

## Tre macchie procedurali (macchia irregolare con gocce satellite), 128 px: poca memoria.
static func _make_stain_textures() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919
	const SIZE := 128
	for variant in 3:
		noise.seed = 100 + variant * 37
		var img := Image.create(SIZE, SIZE, true, Image.FORMAT_RGBA8)
		var drops: Array[Vector3] = []
		for i in 7 + variant * 2:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.5, 0.92)
			drops.append(Vector3(cos(a) * r, sin(a) * r, rng.randf_range(0.03, 0.09)))
		for y in SIZE:
			for x in SIZE:
				var u := (x + 0.5) / SIZE * 2.0 - 1.0
				var v := (y + 0.5) / SIZE * 2.0 - 1.0
				var r := sqrt(u * u + v * v)
				var edge := 0.34 + 0.2 * noise.get_noise_2d(x * 2.0, y * 2.0) + 0.1 * noise.get_noise_2d(x * 7.0 + 90, y * 7.0)
				edge += 0.06 * sin(atan2(v, u) * (3 + variant) + variant)
				var a := smoothstep(edge, edge - 0.1, r)
				for d in drops:
					a = maxf(a, smoothstep(d.z, d.z * 0.55, Vector2(u - d.x, v - d.y).length()))
				# Più scuro e denso al centro, bordo più chiaro e sottile.
				var core := clampf(1.0 - r / maxf(edge, 0.1), 0.0, 1.0)
				var c := Color(0.2 - 0.08 * core, 0.006, 0.006, a * (0.74 + 0.22 * core))
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		_stain_textures.append(ImageTexture.create_from_image(img))
	_stain_mesh = PlaneMesh.new()
	_stain_mesh.size = Vector2.ONE


static func _stain_instance() -> MeshInstance3D:
	if _stain_textures.is_empty():
		_make_stain_textures()
	var budget := _stain_budget()
	if _stains.size() < budget:
		var m := MeshInstance3D.new()
		m.name = "Macchia%d" % _stains.size()
		m.mesh = _stain_mesh
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _stain_textures[_stains.size() % _stain_textures.size()]
		mat.roughness = 0.22
		mat.metallic_specular = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = 2
		m.material_override = mat
		_root.add_child(m)
		_stains.append(m)
		_stain_tweens.append(null)
		return m
	var idx := _next_stain % _stains.size()
	_next_stain += 1
	var old_tween := _stain_tweens[idx]
	if old_tween:
		old_tween.kill()
	return _stains[idx]


## Macchia di sangue sul terreno in `pos`, appoggiata al rilievo. `radius` in metri; `rise`: altezza
## sopra il suolo (macchie sul corpo di un caduto); `grow`: la macchia si allarga a poco a poco.
static func stain(anchor: Node, pos: Vector3, radius: float, rise := 0.0, grow := false) -> void:
	if not enabled:
		return
	if not _ensure(anchor) or not _visible_enough(pos, STAIN_DISTANCE, false):
		return
	var m := _stain_instance()
	var idx := _stains.find(m)
	var gy := ground_y(pos)
	# Inclinazione dal rilievo: differenze finite sul terreno.
	var step := 0.3
	var dx := ground_y(pos + Vector3(step, 0, 0)) - ground_y(pos - Vector3(step, 0, 0))
	var dz := ground_y(pos + Vector3(0, 0, step)) - ground_y(pos - Vector3(0, 0, step))
	var normal := Vector3(-dx, 2.0 * step, -dz).normalized()
	var basis := Basis(Vector3.UP, randf() * TAU)
	var tilt := Quaternion(Vector3.UP, normal)
	m.global_transform = Transform3D(Basis(tilt) * basis, Vector3(pos.x, gy + 0.025 + rise, pos.z))
	m.visible = true
	var mat := m.material_override as StandardMaterial3D
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	var target := Vector3.ONE * radius * 2.0
	var tween := m.create_tween()
	if grow:
		m.scale = target * 0.25
		tween.tween_property(m, "scale", target, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		m.scale = target
	# Il sangue si rapprende: da rosso vivo a scuro e opaco.
	tween.parallel().tween_property(mat, "albedo_color", Color(0.6, 0.6, 0.6), 40.0)
	_stain_tweens[idx] = tween


# =====================================================================================================
# Cadaveri
# =====================================================================================================

## Registra un caduto che resta a terra. Oltre il tetto sparisce il più vecchio fra quelli che la
## camera non inquadra; se sono tutti inquadrati si aspetta, il tetto si supera di qualche unità.
static func register_corpse(unit: Node3D) -> void:
	unit.add_to_group(&"corpses")
	_corpses.append(unit)
	_corpses = _corpses.filter(func(c: Node3D) -> bool: return is_instance_valid(c) and c.is_inside_tree())
	var budget := _corpse_budget()
	if _corpses.size() <= budget:
		return
	var cam := unit.get_viewport().get_camera_3d()
	for i in _corpses.size() - budget:
		for c in _corpses:
			if cam == null or not cam.is_position_in_frustum(c.global_position + Vector3.UP * 0.3):
				_corpses.erase(c)
				c.queue_free()
				break


## Posa il caduto sul rilievo: quota media sotto il corpo e inclinazione secondo la pendenza lungo e
## di traverso al corpo, a tempo con la caduta (`duration`). `head`: verso (mondo) della testa del
## caduto, da cui dipende l'asse lungo cui giace (schiena, faccia in giu' o fianco).
static func settle_on_ground(unit: Node3D, model: Node3D, duration := 0.3, head := Vector3.ZERO) -> void:
	if model == null or not unit.is_inside_tree():
		return
	var axis := head
	if axis == Vector3.ZERO:
		axis = model.global_basis.z
	axis.y = 0.0
	axis = axis.normalized()
	var side := Vector3(axis.z, 0.0, -axis.x)
	var c := unit.global_position
	var h := ground_y(c + axis * 0.8)
	var f := ground_y(c - axis * 0.8)
	var l := ground_y(c + side * 0.3)
	var r := ground_y(c - side * 0.3)
	var mean := (h + f + l + r) * 0.25
	# Pendenza lungo gli assi locali del modello (X e Z), per ruotarlo attorno ai suoi assi.
	var bx := model.global_basis.x.normalized()
	var bz := model.global_basis.z.normalized()
	var gz := (ground_y(c + bz * 0.8) - ground_y(c - bz * 0.8)) / 1.6
	var gx := (ground_y(c + bx * 0.6) - ground_y(c - bx * 0.6)) / 1.2
	var pitch := clampf(-atan(gz), -0.45, 0.45)
	var roll := clampf(atan(gx), -0.35, 0.35)
	var t := model.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(model, "position:y", clampf(mean - c.y, -0.3, 0.3), duration)
	t.tween_property(model, "rotation:x", model.rotation.x + pitch, duration)
	t.tween_property(model, "rotation:z", model.rotation.z + roll, duration)


## Sangue che sgorga da un caduto: macchia che si allarga sotto il corpo e una sul corpo.
static func corpse_blood(unit: Node3D, model: Node3D) -> void:
	if not unit.is_inside_tree():
		return
	var axis := Vector3.BACK
	if model is CharacterModel:
		axis = (model as CharacterModel).death_head_world()
	elif model:
		axis = model.global_basis.z
		axis.y = 0.0
		axis = axis.normalized()
	var base := unit.global_position
	stain(unit, base + axis * 0.15, 0.62, 0.0, true)
	stain(unit, base + axis * 0.35 + Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1)), 0.2, 0.28, true)
