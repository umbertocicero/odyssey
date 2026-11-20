class_name ModelFit
extends RefCounted
## Funzioni comuni per usare i modelli .glb scaricati nella scena senza
## modificarli: estrae le mesh (anche un solo pezzo di un "pack"), corregge
## l'orientamento e calcola scala e spostamento per portarli alla misura
## voluta, appoggiati a terra (y = 0) e centrati.

enum Axis { LONGEST, FOOTPRINT, HEIGHT }


## Restituisce una lista di [Mesh, Transform3D] relativi alla radice del modello.
## Se piece non è vuoto, tiene solo il nodo con quel nome (e i suoi figli).
static func extract_meshes(scene: PackedScene, piece: String) -> Array:
	var result: Array = []
	if scene == null:
		return result
	var root := scene.instantiate()
	var start: Node = root
	if piece != "":
		start = root.find_child(piece.validate_node_name(), true, false)
		if start == null:
			push_warning("ModelFit: pezzo '%s' non trovato in %s" % [piece, scene.resource_path])
			root.free()
			return result
	_collect(start, root, result)
	root.free()
	return result


static func _collect(node: Node, root: Node, out: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append([(node as MeshInstance3D).mesh, _relative_transform(node, root)])
	for child in node.get_children():
		_collect(child, root, out)


static func _relative_transform(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Trasformazione da applicare a ogni mesh estratta: orientamento corretto,
## scala alla misura voluta e base del modello a terra, centrata nell'origine.
static func fit_transform(meshes: Array, rotation_degrees: Vector3, axis: Axis, size: float) -> Transform3D:
	var pre := Transform3D(Basis.from_euler(rotation_degrees * PI / 180.0), Vector3.ZERO)
	var box := AABB()
	var first := true
	for entry in meshes:
		var b: AABB = (pre * (entry[1] as Transform3D)) * (entry[0] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return pre
	var measure := maxf(box.size.x, maxf(box.size.y, box.size.z))
	match axis:
		Axis.FOOTPRINT:
			measure = maxf(box.size.x, box.size.z)
		Axis.HEIGHT:
			measure = box.size.y
	var s := size / maxf(measure, 0.0001)
	var bottom_center := Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
	return Transform3D(Basis.from_scale(Vector3.ONE * s), -bottom_center * s) * pre
