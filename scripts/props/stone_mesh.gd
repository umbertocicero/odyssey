class_name StoneMesh
extends RefCounted
## Mesh di un blocco di pietra "a cuscino": faccia frontale leggermente
## rientrata e bordi smussati. I colori dei vertici scuriscono verso gli
## spigoli e le fughe (occlusione finta), così i muri sembrano fatti di
## blocchi separati anche senza texture. Il blocco è un cubo di lato 1
## centrato nell'origine, con la faccia visibile verso +Z.

static var _cache: Dictionary = {}


static func build(bevel := 0.07) -> ArrayMesh:
	var key := int(bevel * 1000.0)
	if _cache.has(key):
		return _cache[key]
	var h := 0.5
	var b := bevel
	var bright := Color(1, 1, 1)
	var edge := Color(0.62, 0.60, 0.58)
	var back := Color(0.45, 0.43, 0.42)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Faccia frontale (rientrata) e smusso verso il bordo.
	var f: Array[Vector3] = [Vector3(-h + b, -h + b, h), Vector3(h - b, -h + b, h), Vector3(h - b, h - b, h), Vector3(-h + b, h - b, h)]
	var r: Array[Vector3] = [Vector3(-h, -h, h - b), Vector3(h, -h, h - b), Vector3(h, h, h - b), Vector3(-h, h, h - b)]
	var k: Array[Vector3] = [Vector3(-h, -h, -h), Vector3(h, -h, -h), Vector3(h, h, -h), Vector3(-h, h, -h)]
	_quad(st, f[0], f[1], f[2], f[3], bright)
	for i in 4:
		var j := (i + 1) % 4
		_quad_c(st, f[i], f[j], r[j], r[i], bright, edge)
		_quad_c(st, r[i], r[j], k[j], k[i], edge, back)
	st.generate_normals()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_quad_c(st, a, b, c, d, col, col)


## Due triangoli con orientamento coerente (Godot vuole l'ordine orario visto da fuori);
## il colore va da col_a (vertici a, b) a col_b (vertici c, d).
static func _quad_c(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col_a: Color, col_b: Color) -> void:
	# I quattro punti sono dati in senso antiorario visto da fuori; qui si invertono.
	for v: Array in [[a, col_a], [c, col_b], [b, col_a], [a, col_a], [d, col_b], [c, col_b]]:
		st.set_color(v[1])
		st.add_vertex(v[0])
