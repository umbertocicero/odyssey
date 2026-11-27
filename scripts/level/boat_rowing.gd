class_name BoatRowing
extends Node3D
## Rematori a bordo di una barca: seduti sui banchi, tutti rivolti verso la prua (-Z della barca), che vogano
## insieme con lo stesso ritmo. Niente camminata né idle in piedi: lo stance "row" ha un solo ciclo
## (HumanoidAnims.row_hand). I remi sono semplici aste con la pala: ruotano attorno allo scalmo seguendo i polsi
## del rematore, quindi restano sempre in fase con la sua animazione. Il nodo va messo come figlio della barca.

## Altezza (m, nello spazio della barca) del pavimento su cui poggiano i piedi e del piano del banco.
const FLOOR_Y := 0.2
const SEAT_Y := 0.6
const SEAT_SIZE := Vector3(0.78, 0.05, 0.26)
const OAR_INBOARD := 0.62
const OAR_OUTBOARD := 1.55

var rowers: Array[GridUnit] = []
## Posizione (spazio barca) del soldato quando non rema: in piedi a poppa, rivolto alla riva, pronto ad aiutare a salire.
const STAND_POS := Vector3(-0.38, FLOOR_Y, 0.72)
var _seat_z: Array[float] = []
var oars: Array[Node3D] = []
var _wood: StandardMaterial3D
var _blade: StandardMaterial3D
## Per ogni remo: [rematore, indice osso della mano, scalmo (spazio barca)].
var _links: Array = []


## Imbarca `count` rematori nei punti `seats` (z lungo la barca, spazio locale della barca) e crea banchi e remi.
static func board(boat: Node3D, units_root: Node, seat_z: Array[float]) -> BoatRowing:
	var row := BoatRowing.new()
	row.name = "BoatRowing"
	boat.add_child(row)
	row._wood = StandardMaterial3D.new()
	row._wood.albedo_color = Color(0.43, 0.31, 0.18)
	row._wood.roughness = 0.88
	row._blade = StandardMaterial3D.new()
	row._blade.albedo_color = Color(0.5, 0.36, 0.2)
	row._blade.roughness = 0.82
	var i := 0
	for z in seat_z:
		row._add_thwart(z)
		row._seat_z.append(z)
		var u := UnitFactory.make(AllySoldier, UnitFactory.MODEL_ACHEO, GridUnit.Team.ACHEI, 60, "Rower%d" % i) as AllySoldier
		u.busy = true
		u.show_health_bar = false
		# Mani libere sui remi: niente spada.
		for g in u.get_node(^"Model").get_children():
			if g is UnitGear:
				(g as UnitGear).weapon_path = ""
		units_root.add_child(u)
		for g in [&"achei", &"units"]:
			u.remove_from_group(g)
		u.set_physics_process(false)
		u.reparent(row, false)
		u.position = Vector3(0.0, FLOOR_Y, z)
		u.rotation = Vector3.ZERO   # fronte verso la prua (-Z)
		row.rowers.append(u)
		var cm := u.get_node(^"Model") as CharacterModel
		if cm:
			cm.set_stance(&"row", true)
		i += 1
	row._build_oars()
	return row


func _add_thwart(z: float) -> void:
	var m := MeshInstance3D.new()
	m.name = "Thwart"
	var b := BoxMesh.new()
	b.size = SEAT_SIZE
	b.size = Vector3(SEAT_SIZE.x, SEAT_SIZE.y, SEAT_SIZE.z)
	m.mesh = b
	m.material_override = _wood
	m.position = Vector3(0.0, SEAT_Y - SEAT_SIZE.y * 0.5, z + 0.04)
	add_child(m)


func _build_oars() -> void:
	for u in rowers:
		var cm := u.get_node_or_null(^"Model") as CharacterModel
		if cm == null or cm.skeleton == null:
			continue
		for bone in [&"hand.L", &"hand.R"]:
			var bi := cm.skeleton.find_bone(bone)
			if bi < 0:
				continue
			# hand.L è il lato destro anatomico: sta a +X della barca (il rematore guarda -Z).
			var side := 1.0 if bone == &"hand.L" else -1.0
			var lock := u.position + Vector3(side * HumanoidAnims.ROW_LOCK_X, HumanoidAnims.ROW_LOCK_Y, 0.0)
			var pivot := Node3D.new()
			pivot.name = "Oar"
			pivot.position = lock
			add_child(pivot)
			var shaft := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.022
			cyl.bottom_radius = 0.03
			cyl.height = OAR_INBOARD + OAR_OUTBOARD
			cyl.radial_segments = 10
			shaft.mesh = cyl
			shaft.material_override = _wood
			shaft.rotation.x = PI * 0.5
			shaft.position.z = (OAR_INBOARD - OAR_OUTBOARD) * 0.5
			pivot.add_child(shaft)
			var blade := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.17, 0.025, 0.55)
			blade.mesh = bm
			blade.material_override = _blade
			blade.position.z = -OAR_OUTBOARD + 0.27
			pivot.add_child(blade)
			oars.append(pivot)
			_links.append([u, bi, lock, cm.skeleton])


func _process(_delta: float) -> void:
	for i in oars.size():
		var l: Array = _links[i]
		var sk: Skeleton3D = l[3]
		if not is_instance_valid(sk):
			continue
		var hand_world := sk.global_transform * sk.get_bone_global_pose(l[1]).origin
		var hand := to_local(hand_world)
		var lock: Vector3 = l[2]
		var dir := lock - hand
		if dir.length() < 0.05:
			continue
		var pivot := oars[i]
		# Rotazione tenendo il remo "dritto" (pala piatta): -Z del pivot punta verso l'esterno.
		pivot.basis = Basis.looking_at(dir.normalized(), Vector3.UP)


## Il soldato fisso della barca: `on` = seduto sul banco a vogare (remi in acqua), altrimenti in piedi a poppa.
func set_rowing(on: bool) -> void:
	for o in oars:
		o.visible = on
	for i in rowers.size():
		var u := rowers[i]
		u.position = Vector3(0.0, FLOOR_Y, _seat_z[i]) if on else STAND_POS
		u.rotation = Vector3.ZERO if on else Vector3(0.0, PI, 0.0)
		var cm := u.get_node_or_null(^"Model") as CharacterModel
		if cm:
			cm.set_stance(&"row" if on else &"normal", true)


## Rematori in posa da seduti/voga (per i test).
func all_rowing() -> bool:
	for u in rowers:
		var cm := u.get_node_or_null(^"Model") as CharacterModel
		if cm == null or cm.stance != &"row":
			return false
	return not rowers.is_empty()
