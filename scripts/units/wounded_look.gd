class_name WoundedLook
extends RefCounted
## Aspetto da ferito: bende (testa, torace, braccio al collo) e macchie di
## sangue, attaccate alle ossa dello scheletro così seguono ogni animazione
## (anche quando il soldato giace a terra).

const CLOTH := Color(0.66, 0.59, 0.46)
const BLOOD := Color(0.42, 0.03, 0.03)


static func apply(unit: GridUnit) -> void:
	var skeleton: Skeleton3D = null
	var found := unit.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	skeleton = found[0]
	if skeleton.find_child("WoundedLook", false, false):
		return
	var holder := Node3D.new()
	holder.name = "WoundedLook"
	skeleton.add_child(holder)
	# Misure per i personaggi riggati attuali (alti circa 1,52 m, 17 ossa): ogni fascia sta sull'osso,
	# l'offset corre lungo l'osso (asse y locale) verso la sua punta.
	# Testa: benda attorno alla fronte, con sangue sul lato.
	_band(skeleton, "head", Vector3(0, 0.15, 0.0), 0.125, 0.05)
	_blot(skeleton, "head", Vector3(0.10, 0.15, -0.07), Vector3(0.06, 0.07, 0.04), 0.85)
	# Torace: fasciatura e sangue che trasuda.
	_band(skeleton, "spine", Vector3(0, 0.18, 0), 0.20, 0.13)
	_blot(skeleton, "spine", Vector3(-0.12, 0.2, -0.13), Vector3(0.07, 0.09, 0.05), 0.85)
	_blot(skeleton, "spine", Vector3(0.06, 0.18, -0.15), Vector3(0.08, 0.08, 0.04), 0.85)
	# Braccio sinistro fasciato.
	_band(skeleton, "forearm.L", Vector3(0, 0.10, 0), 0.06, 0.10)
	_blot(skeleton, "forearm.L", Vector3(0.0, 0.10, -0.05), Vector3(0.04, 0.05, 0.04), 0.85)
	# Coscia destra e stinco sinistro: bende macchiate.
	_band(skeleton, "thigh.R", Vector3(0, 0.18, 0), 0.10, 0.11)
	_blot(skeleton, "thigh.R", Vector3(0.0, 0.18, -0.08), Vector3(0.05, 0.06, 0.04), 0.85)
	_band(skeleton, "shin.L", Vector3(0, 0.16, 0), 0.07, 0.09)


static func _attach(skeleton: Skeleton3D, bone: String) -> BoneAttachment3D:
	if skeleton.find_bone(bone) < 0:
		return null
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	skeleton.add_child(a)
	return a


static func _band(skeleton: Skeleton3D, bone: String, offset: Vector3, radius: float, height: float) -> void:
	var a := _attach(skeleton, bone)
	if a == null:
		return
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius * 1.02
	c.height = height
	c.radial_segments = 14
	c.rings = 1
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CLOTH
	mat.roughness = 0.95
	m.material_override = mat
	m.position = offset
	a.add_child(m)


static func _blot(skeleton: Skeleton3D, bone: String, offset: Vector3, size: Vector3, _alpha: float) -> void:
	var a := _attach(skeleton, bone)
	if a == null:
		return
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 5
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BLOOD
	mat.roughness = 0.3
	m.material_override = mat
	m.position = offset
	m.scale = size
	a.add_child(m)
