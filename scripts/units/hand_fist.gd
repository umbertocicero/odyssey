class_name HandFist
extends RefCounted
## Pugno chiuso per i personaggi riggati a 17 ossa: le mesh hanno le mani aperte e non ci sono ossa delle
## dita, quindi all'avvio si piegano i vertici delle dita (nella posa di legame, cioè la A-pose) intorno a
## un manico immaginario. Le dita seguono poi l'avambraccio come il resto della mano.
##
## Il telaio della mano è misurato sulle mesh (asse principale = dita, asse più sottile = normale del
## palmo, asse medio = larghezza, verso il pollice). Il manico passa nel centro della curva delle dita
## (`grip_point`), lungo la larghezza: le armi di HumanoidAnims usano lo stesso punto e lo stesso asse,
## con la lama dal lato del pollice (presa a martello).
## Valori per la mano a +X (sinistra anatomica, osso "hand.R"); per l'altra si specchia la x.

## Rispetto al polso (origine a riposo dell'osso della mano), mano a +X.
const FINGERS := Vector3(0.22, -0.79, 0.58)     # dal polso verso la punta delle dita
const PALM := Vector3(-0.91, -0.38, -0.16)      # normale del palmo, verso il corpo
const CENTER := Vector3(0.027, 0.0, 0.106)      # baricentro della mano
## Nocche: dove cominciano a piegarsi le dita (distanza dal baricentro lungo FINGERS).
const KNUCKLE := 0.012
## Raggio della curva delle dita (manico ~1,5 cm di raggio + metà dello spessore delle dita).
const CURL_RADIUS := 0.021
## Spostamento del piano medio delle dita rispetto al baricentro, lungo PALM.
const FINGER_PLANE := 0.004

static var _cache := {}


## Asse delle dita, normale del palmo e larghezza (verso il pollice) per la mano dal lato `sx` (+1 / -1).
static func axes(sx: float) -> Array:
	var f := _mirror(FINGERS, sx).normalized()
	var n := _mirror(PALM, sx)
	n = (n - f * n.dot(f)).normalized()
	var w := f.cross(n).normalized()
	# Il pollice sta verso il davanti (+Z) nella A-pose con i palmi verso le cosce.
	if w.z < 0.0:
		w = -w
	return [f, n, w]


## Centro del manico nel pugno, rispetto al polso, per la mano dal lato `sx`.
static func grip_point(sx: float) -> Vector3:
	var ax := axes(sx)
	var f: Vector3 = ax[0]
	var n: Vector3 = ax[1]
	return _mirror(CENTER, sx) + f * KNUCKLE + n * (FINGER_PLANE + CURL_RADIUS)


static func _mirror(v: Vector3, sx: float) -> Vector3:
	return Vector3(v.x * sx, v.y, v.z)


## Mesh con le dita chiuse a pugno (in cache per mesh). `skeleton` dà la posizione dei polsi a riposo.
static func fisted(mesh: Mesh, skeleton: Skeleton3D) -> Mesh:
	var am := mesh as ArrayMesh
	if am == null or skeleton == null or skeleton.find_bone("hand.L") < 0:
		return mesh
	var key := am.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var wrists: Array[Vector3] = []
	for b in ["hand.L", "hand.R"]:
		wrists.append(skeleton.get_bone_global_rest(skeleton.find_bone(b)).origin)
	var out := ArrayMesh.new()
	out.resource_name = am.resource_name
	for si in am.get_surface_count():
		var arrays := am.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		for w in wrists:
			_curl(verts, normals, tangents, w)
		arrays[Mesh.ARRAY_VERTEX] = verts
		if not normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = normals
		if not tangents.is_empty():
			arrays[Mesh.ARRAY_TANGENT] = tangents
		var fmt := am.surface_get_format(si)
		var flags := fmt & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		out.add_surface_from_arrays(am.surface_get_primitive_type(si), arrays, [], {}, flags)
		out.surface_set_material(si, am.surface_get_material(si))
		out.surface_set_name(si, am.surface_get_name(si))
	_cache[key] = out
	return out


## Piega verso il palmo i vertici oltre le nocche della mano col polso in `wrist`.
static func _curl(verts: PackedVector3Array, normals: PackedVector3Array, tangents: PackedFloat32Array, wrist: Vector3) -> void:
	var sx := signf(wrist.x)
	var ax := axes(sx)
	var f: Vector3 = ax[0]
	var n: Vector3 = ax[1]
	var w: Vector3 = ax[2]
	var c := wrist + _mirror(CENTER, sx)
	var k := c + f * KNUCKLE + n * FINGER_PLANE
	var r := CURL_RADIUS
	var rot_axis := f.cross(n).normalized()
	for i in verts.size():
		var p := verts[i]
		var d := p - c
		if d.length() > 0.13 or (p.x - wrist.x) * sx < -0.015:
			continue
		var q := p - k
		var s := q.dot(f)
		if s <= 0.0:
			continue
		var t := q.dot(n)
		var u := q.dot(w)
		if absf(t) > 0.045 or absf(u) > 0.075:
			continue
		var th := s / r
		var rho := r - t
		verts[i] = k + n * r - n * (rho * cos(th)) + f * (rho * sin(th)) + w * u
		var b := Basis(rot_axis, th)
		if i < normals.size():
			normals[i] = (b * normals[i]).normalized()
		if tangents.size() >= (i + 1) * 4:
			var tg := b * Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])
			tangents[i * 4] = tg.x
			tangents[i * 4 + 1] = tg.y
			tangents[i * 4 + 2] = tg.z
