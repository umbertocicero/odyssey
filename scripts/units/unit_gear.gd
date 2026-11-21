class_name UnitGear
extends Node
## Equipaggiamento aggiunto a un personaggio riggato (CharacterModel): elmo corinzio sulla testa e
## scudo hoplon sull'avambraccio sinistro, attaccati con BoneAttachment3D allo scheletro del glb,
## così seguono le animazioni. Va messo come figlio di "Model". A qualità bassa non aggiunge niente
## (budget). Gli scarti di posizione, rotazione e scala si regolano dall'Inspector.

@export var helmet: PackedScene
@export var shield: PackedScene
@export var helmet_bone := &"head"
@export var shield_bone := &"forearm.L"
@export var helmet_offset := Vector3(0.0, 0.1, 0.0)
@export var helmet_rotation_degrees := Vector3.ZERO
@export_range(0.1, 3.0) var helmet_scale := 0.55
@export var shield_offset := Vector3(0.0, 0.12, 0.06)
@export var shield_rotation_degrees := Vector3(0, 90, 0)
@export_range(0.1, 3.0) var shield_scale := 0.55
## Scudo allineato al corpo: nello scheletro a riposo (A-pose) l'osso dell'avambraccio è inclinato,
## quindi l'offset si dà nello spazio dello scheletro (x verso fuori, y su, z verso dietro) rispetto
## alla mano e la rotazione compensa la posa dell'osso: lo scudo guarda avanti e segue l'avambraccio.
@export var shield_aligned := true
@export var shield_hold_bone := &"hand.L"
@export var shield_hold_offset := Vector3(-0.1, 0.02, -0.09)
@export var shield_yaw_degrees := 0.0
@export_range(-45.0, 45.0) var shield_tilt_degrees := 8.0
## Tinta dell'elmo (cresta e bronzo smorzati); bianco = nessuna.
@export var helmet_tint := Color(1, 1, 1)
@export var min_quality := 1

var helmet_node: Node3D
var shield_node: Node3D


func _ready() -> void:
	if int(Quality.current()) < min_quality:
		return
	# Il modello glb viene istanziato dal CharacterModel (figlio più in basso del nodo "Model").
	await get_tree().process_frame
	var skeleton: Skeleton3D = null
	var holder := get_parent()
	if holder:
		var found := holder.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			skeleton = found[0]
	if skeleton == null:
		return
	helmet_node = _attach(skeleton, helmet, helmet_bone, helmet_offset, helmet_rotation_degrees, helmet_scale, helmet_tint)
	if shield_aligned:
		shield_node = _attach_aligned(skeleton)
	else:
		shield_node = _attach(skeleton, shield, shield_bone, shield_offset, shield_rotation_degrees, shield_scale, Color(1, 1, 1))


func _attach(skeleton: Skeleton3D, scene: PackedScene, bone: StringName, offset: Vector3, rot: Vector3, size: float, tint: Color) -> Node3D:
	if scene == null or skeleton.find_bone(bone) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "Gear_%s" % bone
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var node := scene.instantiate() as Node3D
	node.position = offset
	node.rotation_degrees = rot
	node.scale = Vector3.ONE * size
	attachment.add_child(node)
	if tint != Color(1, 1, 1):
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).mesh = FoliageTint.apply((mi as MeshInstance3D).mesh, Color(1, 1, 1), tint)
	return node


func _attach_aligned(skeleton: Skeleton3D) -> Node3D:
	if shield == null or skeleton.find_bone(shield_bone) < 0 or skeleton.find_bone(shield_hold_bone) < 0:
		return null
	var bone_index := skeleton.find_bone(shield_bone)
	var rest := skeleton.get_bone_global_rest(bone_index)
	var hold := skeleton.get_bone_global_rest(skeleton.find_bone(shield_hold_bone)).origin + shield_hold_offset
	var attachment := BoneAttachment3D.new()
	attachment.name = "Gear_%s" % shield_bone
	attachment.bone_name = shield_bone
	skeleton.add_child(attachment)
	var node := shield.instantiate() as Node3D
	var desired := Basis(Vector3.UP, deg_to_rad(shield_yaw_degrees)) * Basis(Vector3.RIGHT, deg_to_rad(shield_tilt_degrees))
	node.transform = Transform3D(rest.basis.inverse() * desired, rest.affine_inverse() * hold)
	node.scale = Vector3.ONE * shield_scale
	attachment.add_child(node)
	return node
