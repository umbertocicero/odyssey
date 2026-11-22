class_name UnitGear
extends Node
## Equipaggiamento aggiunto a un personaggio riggato (CharacterModel): elmo sulla testa, scudo hoplon
## sull'avambraccio sinistro e arma nella mano destra (arco nella sinistra), attaccati con
## BoneAttachment3D allo scheletro del glb, così seguono le animazioni. Va messo come figlio di "Model".
## Sotto `min_quality` non aggiunge niente (budget).
##
## Nei glb le ossa ".L" sono il lato DESTRO anatomico (stanno a -X, il personaggio guarda +Z): perciò
## l'arma va su "hand.L" e lo scudo su "forearm.R". Con i nomi vuoti l'osso si sceglie da solo.
## Le armi sono orientate come le tiene HumanoidAnims: asse lungo nella direzione del pollice, presa al
## palmo (HumanoidAnims.GRIP_OFFSET dal polso). Lo scudo sta sull'avambraccio come un hoplon: centro a
## metà avambraccio, faccia sul dorso (HumanoidAnims.shield_rest_transform).

@export var helmet: PackedScene
@export var shield: PackedScene
@export var helmet_bone := &"head"
## Osso dello scudo (vuoto = avambraccio sinistro anatomico, "forearm.R").
@export var shield_bone := &""
@export var helmet_offset := Vector3(0.0, 0.1, 0.0)
@export var helmet_rotation_degrees := Vector3.ZERO
@export_range(0.1, 3.0) var helmet_scale := 0.55
@export var shield_offset := Vector3(0.0, 0.12, 0.06)
@export var shield_rotation_degrees := Vector3(0, 90, 0)
@export_range(0.1, 3.0) var shield_scale := 0.55
## Scudo sull'avambraccio come lo usano le animazioni (consigliato). Se falso usa offset e rotazione liberi.
@export var shield_aligned := true
## Gira lo scudo se la faccia decorata finisce verso il braccio.
@export var shield_flip := false
## Non più usati (vecchio aggancio alla mano), tenuti per compatibilità delle scene.
@export var shield_hold_bone := &"hand.L"
@export var shield_hold_offset := Vector3(-0.1, 0.02, -0.09)
@export var shield_yaw_degrees := 0.0
@export_range(-45.0, 45.0) var shield_tilt_degrees := 8.0
## Tinta dell'elmo (cresta e bronzo smorzati); bianco = nessuna.
@export var helmet_tint := Color(1, 1, 1)
@export var min_quality := 1

## Arma tenuta in mano (xiphos, lancia o arco di assets/models/custom/armi/): percorso del modello e della
## versione leggera (usata a qualità bassa e media). L'origine dei modelli è il centro della presa.
enum WeaponKind { SWORD, SPEAR, BOW }
@export_file("*.gltf", "*.glb") var weapon_path := ""
@export_file("*.gltf", "*.glb") var weapon_lod_path := ""
@export var weapon_kind: WeaponKind = WeaponKind.SWORD
## Osso della mano (vuoto = destra anatomica "hand.L" per spada e lancia, sinistra "hand.R" per l'arco).
@export var weapon_bone := &""
@export var weapon_offset := Vector3(0.0, 0.0, 0.0)
## Correzione della direzione dell'arma rispetto a quella predefinita, in gradi (x, y, z, nello spazio del modello).
@export var weapon_adjust_degrees := Vector3.ZERO

var weapon_node: Node3D
var helmet_node: Node3D
var shield_node: Node3D


## Vero se l'equipaggiamento verrà davvero aggiunto (qualità sufficiente).
func is_active() -> bool:
	return int(Quality.current()) >= min_quality


func has_weapon() -> bool:
	return is_active() and weapon_path != ""


func has_shield() -> bool:
	return is_active() and shield != null


## Arma per HumanoidAnims (spada, lancia o niente; l'arco è nella sinistra).
func hand_kind() -> HumanoidAnims.Hand:
	if not has_weapon():
		return HumanoidAnims.Hand.NONE
	match weapon_kind:
		WeaponKind.SPEAR:
			return HumanoidAnims.Hand.SPEAR
		WeaponKind.BOW:
			return HumanoidAnims.Hand.NONE
	return HumanoidAnims.Hand.SWORD


func has_bow() -> bool:
	return has_weapon() and weapon_kind == WeaponKind.BOW


func _ready() -> void:
	if not is_active():
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
	_attach_weapon(skeleton)
	if shield_aligned:
		shield_node = _attach_aligned(skeleton)
	else:
		shield_node = _attach(skeleton, shield, _shield_bone(), shield_offset, shield_rotation_degrees, shield_scale, Color(1, 1, 1))


func _shield_bone() -> StringName:
	return shield_bone if shield_bone != &"" else &"forearm.R"


func _weapon_bone() -> StringName:
	if weapon_bone != &"":
		return weapon_bone
	return &"hand.R" if weapon_kind == WeaponKind.BOW else &"hand.L"


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
	var bone := _shield_bone()
	if shield == null or skeleton.find_bone(bone) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "Gear_%s" % bone
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var node := shield.instantiate() as Node3D
	var center := _local_center(node)
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	node.transform = rest.affine_inverse() * HumanoidAnims.shield_rest_transform(skeleton, bone, shield_scale, center, shield_flip)
	attachment.add_child(node)
	return node


## Centro del modello (AABB delle mesh) nelle sue coordinate locali.
func _local_center(node: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != node and n is Node3D:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center()


func _attach_weapon(skeleton: Skeleton3D) -> void:
	var bone := _weapon_bone()
	if weapon_path == "" or skeleton.find_bone(bone) < 0:
		return
	var path := weapon_path
	if weapon_lod_path != "" and Quality.current() != Quality.Level.HIGH:
		path = weapon_lod_path
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var idx := skeleton.find_bone(bone)
	var rest := skeleton.get_bone_global_rest(idx)
	var attachment := BoneAttachment3D.new()
	attachment.name = "Arma_%s" % bone
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var node := scene.instantiate() as Node3D
	var adjust := Basis.from_euler(Vector3(deg_to_rad(weapon_adjust_degrees.x), deg_to_rad(weapon_adjust_degrees.y), deg_to_rad(weapon_adjust_degrees.z)))
	var basis := adjust * HumanoidAnims.weapon_rest_basis(skeleton, bone, int(weapon_kind))
	var grip := HumanoidAnims.grip_rest_position(skeleton, bone) + weapon_offset
	node.transform = rest.affine_inverse() * Transform3D(basis, grip)
	attachment.add_child(node)
	weapon_node = node
