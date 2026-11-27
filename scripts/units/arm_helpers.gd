class_name ArmHelpers
extends SkeletonModifier3D
## Ossa di supporto delle spalle e degli avambracci (clavicle.R/L, forearm_twist.R/L nei glb di personaggi_nuovi), pilotate a runtime
## dopo le animazioni: le animazioni procedurali e Mixamo conoscono solo le 17 ossa del corpo.
## - clavicola: figlia del busto come il braccio; ruota di una frazione dell'elevazione del braccio (rispetto alla posa a riposo),
##   cosi' a braccio alzato la parte alta della spalla sale un po' invece di restare ferma (o di strapparsi) e il petto non segue il braccio;
## - twist: figlio dell'avambraccio; ruota di meta' della torsione della mano attorno all'asse dell'avambraccio, per distribuire la
##   rotazione del polso lungo l'avambraccio (niente effetto "caramella").

const CLAVICLE_FOLLOW := 0.35
const TWIST_FOLLOW := 0.5

var _sides: Array[Dictionary] = []


## Aggiunge il modificatore allo scheletro se ha le ossa di supporto (una sola volta).
static func attach(skeleton: Skeleton3D) -> void:
	if skeleton == null or skeleton.find_bone("clavicle.R") < 0 or skeleton.get_node_or_null("ArmHelpers") != null:
		return
	var h := ArmHelpers.new()
	h.name = "ArmHelpers"
	skeleton.add_child(h)
	h._setup(skeleton)


func _setup(sk: Skeleton3D) -> void:
	for sd in ["R", "L"]:
		var up := sk.find_bone("upperarm." + sd)
		var cl := sk.find_bone("clavicle." + sd)
		var fo := sk.find_bone("forearm." + sd)
		var tw := sk.find_bone("forearm_twist." + sd)
		var ha := sk.find_bone("hand." + sd)
		if up < 0 or cl < 0 or fo < 0 or tw < 0 or ha < 0:
			continue
		_sides.append({
			"up": up, "cl": cl, "tw": tw, "ha": ha,
			"up_rest": sk.get_bone_rest(up).basis.get_rotation_quaternion(),
			"cl_rest": sk.get_bone_rest(cl).basis.get_rotation_quaternion(),
			"tw_rest": sk.get_bone_rest(tw).basis.get_rotation_quaternion(),
			"ha_rest": sk.get_bone_rest(ha).basis.get_rotation_quaternion(),
		})


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for s in _sides:
		# elevazione del braccio rispetto al riposo, nel riferimento del busto (clavicola e braccio hanno lo stesso genitore)
		var d: Quaternion = sk.get_bone_pose_rotation(s["up"]) * (s["up_rest"] as Quaternion).inverse()
		var part := Quaternion.IDENTITY.slerp(d.normalized(), CLAVICLE_FOLLOW)
		sk.set_bone_pose_rotation(s["cl"], part * (s["cl_rest"] as Quaternion))
		# torsione della mano attorno all'asse dell'avambraccio (Y locale)
		var dh: Quaternion = sk.get_bone_pose_rotation(s["ha"]) * (s["ha_rest"] as Quaternion).inverse()
		var v := Vector3(dh.x, dh.y, dh.z)
		var twist := Quaternion(0.0, v.y, 0.0, dh.w)
		if twist.length_squared() < 1e-8:
			twist = Quaternion.IDENTITY
		var t := Quaternion.IDENTITY.slerp(twist.normalized(), TWIST_FOLLOW)
		sk.set_bone_pose_rotation(s["tw"], t * (s["tw_rest"] as Quaternion))
