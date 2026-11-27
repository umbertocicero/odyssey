class_name TroyGate
extends Node3D
## Porta di Troia costruita in codice (nessun modello esterno, solo le texture PBR già in _tex/).
##
## Il nodo sta a terra (y = 0 è il piano della strada), al centro dello spessore del muro,
## con il fronte verso +Z. Due modi:
##  - GATE: la porta principale. Riempie lo spazio tra due torri con stipiti a blocchi sfalsati,
##    architrave monolitico, cornicione e merli come i tratti di muro, soglia consumata;
##    i battenti sono incassati nello spessore del muro.
##  - TOWER_DOOR: portina a una torre. Non si può bucare la torre, quindi la porta è dentro un
##    portale di pietra che sporge dalla faccia della torre (il nodo sta sulla faccia).
## Battenti: assi verticali una a una (profondità e venatura diverse), fasce di ferro con
## cappi di cerniera, borchie di bronzo (un solo MultiMesh), anelli, listello di battuta.

enum Kind { GATE, TOWER_DOOR }

@export var kind: Kind = Kind.GATE
## GATE: larghezza dello spazio tra i corpi delle torri da riempire (m).
@export var gap_width := 4.9
@export var opening_width := 3.2
@export var opening_height := 2.9
## Metà dello spessore del muro (m).
@export var wall_half_thickness := 0.49
## Quanto i battenti sono incassati rispetto alla faccia del muro (m).
@export var recess := 0.42
## GATE: quota della cima del muro sopra la porta e dei merli.
@export var body_top := 3.55
@export var merlon_top := 4.45
## TOWER_DOOR: quanto il portale sporge dalla faccia della torre.
@export var porch_depth := 0.34
@export var seed_value := 7

const TEX := "res://assets/models/custom/campo/_tex/"
## Le texture del calcare nei modelli hanno 1 tile = 1 m nativo = circa 0.83 m in scena.
const STONE_UV := 1.2

var _rng := RandomNumberGenerator.new()
var _leaf_pivots: Array[Node3D] = []
var is_open := false


## Accumula parallelepipedi in una sola mesh (normali, UV e tangenti per la normal map).
class Mesher:
	extends RefCounted
	var st := SurfaceTool.new()
	var uv_scale := 1.0
	var swap_uv := false
	var count := 0

	const FACES := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func box(center: Vector3, size: Vector3, uv_off := Vector2.ZERO) -> void:
		var h := size * 0.5
		for f in FACES:
			var n: Vector3 = f[0]
			var a: Vector3 = f[1]
			var b: Vector3 = f[2]
			var ha := absf(a.dot(h))
			var hb := absf(b.dot(h))
			var c := center + n * absf(n.dot(h))
			var p := [c - a * ha - b * hb, c + a * ha - b * hb, c + a * ha + b * hb, c - a * ha + b * hb]
			for i in [0, 2, 1, 0, 3, 2]:
				var v: Vector3 = p[i]
				var uv := Vector2(v.dot(a), v.dot(b)) * uv_scale + uv_off
				if swap_uv:
					uv = Vector2(uv.y, uv.x)
				st.set_normal(n)
				st.set_uv(uv)
				st.add_vertex(v)
		count += 1

	func build(material: Material) -> ArrayMesh:
		if count == 0:
			return null
		st.generate_tangents()
		var m := st.commit()
		m.surface_set_material(0, material)
		return m


func _ready() -> void:
	add_to_group(&"troy_gates")
	if kind == Kind.GATE:
		add_to_group(&"troy_main_gate")
	_rng.seed = seed_value
	_build()


func _build() -> void:
	var stone := Mesher.new()
	stone.uv_scale = STONE_UV
	var wood := Mesher.new()
	wood.swap_uv = true
	var iron := Mesher.new()
	iron.uv_scale = 2.0
	var t := wall_half_thickness
	var leaf_thick := 0.12
	var leaf_front: float
	if kind == Kind.GATE:
		_gate_stone(stone, t)
		leaf_front = t - recess
	else:
		_porch_stone(stone)
		leaf_front = 0.04 + leaf_thick
	_leaves(wood, iron, leaf_front, leaf_thick)
	_add(stone.build(_material("limestone", Color.WHITE, 0.0)))


func _add(mesh: Mesh) -> void:
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _material(tex: String, tint: Color, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "troy_gate_" + tex
	m.albedo_texture = load(TEX + tex + "_c.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX + tex + "_n.jpg")
	m.roughness_texture = load(TEX + tex + "_r.jpg")
	m.roughness = 1.0
	m.metallic = metallic
	m.metallic_specular = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _rand_off() -> Vector2:
	return Vector2(_rng.randf(), _rng.randf())


## Un blocco di pietra con un po' di irregolarità sulla faccia.
func _block(m: Mesher, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	var j := 0.006
	var size := Vector3(x1 - x0 - j, y1 - y0 - j, z1 - z0 - _rng.randf_range(0.0, 0.03))
	var center := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5 + _rng.randf_range(-0.012, 0.012))
	m.box(center, size, _rand_off())


func _gate_stone(m: Mesher, t: float) -> void:
	var hw := opening_width * 0.5
	var outer := gap_width * 0.5 + 0.12
	var h := opening_height
	# Anima scura dietro i blocchi: niente spiragli di luce tra un blocco e l'altro.
	for cs: float in [-1.0, 1.0]:
		m.box(Vector3(cs * (hw + outer) * 0.5, h * 0.5, 0), Vector3(outer - hw, h, (t - 0.06) * 2.0), _rand_off())
	m.box(Vector3(0, (h + body_top) * 0.5, 0), Vector3(outer * 2.0, body_top - h, (t - 0.06) * 2.0), _rand_off())
	for side: float in [-1.0, 1.0]:
		var y := 0.0
		var i := 0
		while y < h - 0.01:
			var ch := _rng.randf_range(0.34, 0.5)
			if h - y - ch < 0.22:
				ch = h - y
			var split := hw + (0.52 if i % 2 == 0 else 0.38) + _rng.randf_range(-0.04, 0.04)
			var xa := minf(side * hw, side * split)
			var xb := maxf(side * hw, side * split)
			_block(m, xa, xb, y, y + ch, -t, t)
			var xc := minf(side * split, side * outer)
			var xd := maxf(side * split, side * outer)
			_block(m, xc, xd, y, y + ch, -t, t)
			y += ch
			i += 1
	# Architrave monolitico (sporge un po' sui due lati) e cornicione sopra.
	var lintel_top := h + 0.45
	m.box(Vector3(0, (h + lintel_top) * 0.5, 0), Vector3(outer * 2.0, lintel_top - h - 0.006, (t + 0.04) * 2.0), _rand_off())
	var x := -outer
	while x < outer - 0.05:
		var w := minf(_rng.randf_range(1.2, 1.8), outer - x)
		if outer - (x + w) < 0.5:
			w = outer - x
		_block(m, x, x + w, lintel_top, body_top, -t - 0.02, t + 0.02)
		x += w
	# Merli, stesso ritmo dei tratti di muro (0.745 m di merlo, 0.37 m di vuoto).
	for k in 4:
		var cx := (k - 1.5) * 1.12
		_block(m, cx - 0.372, cx + 0.372, body_top, merlon_top, -t + 0.02, t - 0.02)
	# Soglia di pietra consumata, con un gradino davanti.
	m.box(Vector3(0, 0.035, 0.18), Vector3((hw + 0.12) * 2.0, 0.07, (t + 0.35 + t) ), _rand_off())


func _porch_stone(m: Mesher) -> void:
	var hw := opening_width * 0.5
	var h := opening_height
	var d := porch_depth
	var jw := 0.28
	for side: float in [-1.0, 1.0]:
		var y := 0.0
		while y < h - 0.01:
			var ch := _rng.randf_range(0.36, 0.52)
			if h - y - ch < 0.25:
				ch = h - y
			var xa := minf(side * hw, side * (hw + jw))
			var xb := maxf(side * hw, side * (hw + jw))
			_block(m, xa, xb, y, y + ch, 0.0, d)
			y += ch
	m.box(Vector3(0, h + 0.15, d * 0.5 + 0.02), Vector3((hw + jw) * 2.0 + 0.06, 0.3, d + 0.04), _rand_off())
	m.box(Vector3(0, 0.03, d * 0.5 + 0.06), Vector3((hw + 0.06) * 2.0, 0.06, d + 0.12), _rand_off())


## Battenti: ognuno è un nodo con perno sulla cerniera (lato esterno), così la porta si può aprire.
## Coordinate locali del battente: origine sul perno, il battente si estende verso la battuta centrale.
func _leaves(_wood_unused: Mesher, _iron_unused: Mesher, front: float, thick: float) -> void:
	var hw := opening_width * 0.5
	var lh := opening_height - 0.02
	var leaf_w := hw - 0.01
	var plank_n := maxi(3, roundi(leaf_w / 0.22))
	var plank_w := leaf_w / plank_n
	var zc := front - thick * 0.5
	var big := kind == Kind.GATE
	var strap_ys: Array = [0.45, 1.5, 2.45] if big else [0.4, 1.45]
	var edge_in := 0.01          # lato verso la battuta centrale
	var wood_mat := _material("planks", Color(0.74, 0.68, 0.62), 0.0)
	var iron_mat := _material("iron", Color(1, 1, 1), 0.35)
	var ring_mat := _material("iron", Color(0.85, 0.85, 0.85), 0.5)
	var bronze_mat := _material("bronze", Color(1, 1, 1), 0.55)
	for side: float in [-1.0, 1.0]:
		var px := side * (edge_in + leaf_w)   # cerniera
		var pivot := Node3D.new()
		pivot.name = "LeafR" if side > 0.0 else "LeafL"
		pivot.position = Vector3(px, 0, 0)
		add_child(pivot)
		_leaf_pivots.append(pivot)
		var wood := Mesher.new()
		wood.swap_uv = true
		var iron := Mesher.new()
		iron.uv_scale = 2.0
		var studs: Array[Transform3D] = []
		for i in plank_n:
			var xa := side * (edge_in + i * plank_w)
			var xb := side * (edge_in + (i + 1) * plank_w)
			var x0 := minf(xa, xb)
			var x1 := maxf(xa, xb)
			var top := lh + _rng.randf_range(-0.012, 0.0)
			var dz := _rng.randf_range(-0.008, 0.008)
			var off := Vector2(_rng.randf(), -x0 + float(_rng.randi_range(0, 3)) * 0.25 + 0.015)
			wood.box(Vector3((x0 + x1) * 0.5 - px, 0.02 + (top - 0.02) * 0.5, zc + dz), Vector3(x1 - x0 - 0.008, top - 0.02, thick), off)
		for sy in strap_ys:
			var sy_f: float = sy
			var cx := side * (edge_in + leaf_w * 0.5) - px
			iron.box(Vector3(cx, sy_f, front + 0.015), Vector3(leaf_w - 0.03, 0.15, 0.03), _rand_off())
			var hx := side * (edge_in + leaf_w - 0.14) - px
			iron.box(Vector3(hx, sy_f, front + 0.03), Vector3(0.26, 0.2, 0.026), _rand_off())
			for i in plank_n:
				var sx := side * (edge_in + (i + 0.5) * plank_w) - px
				for row in [-0.045, 0.045]:
					studs.append(Transform3D(Basis.from_scale(Vector3(1, 1, 0.55)), Vector3(sx, sy_f + row, front + 0.032)))
		# Listello di battuta sul bordo interno di ogni battente.
		iron.box(Vector3(side * edge_in - px - side * 0.035, lh * 0.5, front + 0.02), Vector3(0.035, lh, 0.04), _rand_off())
		_add_to(pivot, wood.build(wood_mat))
		_add_to(pivot, iron.build(iron_mat))
		# Anello di presa e borchia centrale.
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.045
		torus.outer_radius = 0.07
		torus.rings = 16
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = ring_mat
		ring.transform = Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(side * 0.2 - px, lh * 0.5 - 0.1, front + 0.075))
		pivot.add_child(ring)
		var boss := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.05
		sph.height = 0.1
		sph.radial_segments = 10
		sph.rings = 5
		boss.mesh = sph
		boss.material_override = ring_mat
		boss.transform = Transform3D(Basis.from_scale(Vector3(1, 1, 0.6)), Vector3(side * 0.2 - px, lh * 0.5, front + 0.045))
		pivot.add_child(boss)
		# Borchie di bronzo.
		var sphere := SphereMesh.new()
		sphere.radius = 0.034
		sphere.height = 0.068
		sphere.radial_segments = 10
		sphere.rings = 5
		sphere.material = bronze_mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sphere
		mm.instance_count = studs.size()
		for i in studs.size():
			mm.set_instance_transform(i, studs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		pivot.add_child(mmi)


func _add_to(parent: Node3D, mesh: Mesh) -> void:
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)


## Apre o chiude i battenti (verso il lato del campo, +Z). Restituisce il tween.
func set_open(opened: bool, duration := 1.2) -> Tween:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for pv in _leaf_pivots:
		var side := 1.0 if pv.position.x > 0.0 else -1.0
		tw.tween_property(pv, "rotation:y", side * deg_to_rad(100.0) if opened else 0.0, duration)
	is_open = opened
	return tw
