class_name FerrySystem
extends Node
## Evacuazione dei feriti: quando un ferito è in salvo all'accampamento, un
## soldato alleato lo sorregge e lo porta alla riva; lì sale su una barca che
## attraversa lo specchio d'acqua fino a una nave grande (pentecontera) e
## poi torna a prendere il prossimo.

signal wounded_evacuated(count: int)

const BOAT_MODEL := "res://assets/models/custom/campo/navi/barca_a_remi/barca_a_remi.gltf"
const BOAT_LENGTH := 3.6

enum Phase { WAIT_BEARER, GO_TO_WOUNDED, CARRY, WAIT_BOAT, STRETCH_CAMP, STRETCH_SHORE, RAISING }

class Job:
	var wounded: WoundedSoldier
	var bearer: AllySoldier
	## Secondo soldato che aiuta a trascinare il ferito (se ce ne sono almeno due liberi).
	var bearer2: AllySoldier
	## Quanti soldati devono trascinare il ferito (1 o 2).
	var want := 1
	## Ferito grave senza barella: prima va portato all'accampamento, poi alla riva.
	var to_camp := false
	var phase := Phase.WAIT_BEARER
	var stuck := 0.0
	# Barella: portata da quattro soldati (solo per i feriti gravi).
	var stretcher: Stretcher
	var crew: Array[AllySoldier] = []
	var pos := Vector2.ZERO
	var heading := 0.0

class Boat:
	var node: Node3D
	var home: Vector3
	var patient: WoundedSoldier
	var stretcher: Stretcher
	var busy := false
	## Soldati a bordo (rematori) mentre la barca è in viaggio.
	var crew: Array[AllySoldier] = []
	var rowing: BoatRowing

var grid: DioramaGrid
## Punto di imbarco sulla riva (x, z in metri) e specchio d'acqua dove stanno le barche.
var shore_point := Vector2(-21.0, 11.5)
var boats: Array[Boat] = []
var jobs: Array[Job] = []
var evacuated := 0
var ship_targets: Array[Vector3] = []
## Secondi per ogni tratta della barca.
var sail_time := 6.0

var _step_cd := 0.0
var units_root: Node
## Velocità (m/s) della barella.
var stretcher_speed := 1.7
## Quanti soldati portano il ferito grave all'ultima richiesta (4 = barella, 2 o 1 = trascinato).
var last_bearers := 4
## Soldati a bordo della barca piccola oltre al ferito (la manovrano).
const BOAT_CREW := 2
const STRETCHER_BEARERS := 4
var _shore_cell := Vector2i(-1, -1)
var _camp_start := Vector2i.ZERO


func setup(g: DioramaGrid, units_root_node: Node, level_root: Node, rules: LevelRules) -> void:
	grid = g
	add_to_group(&"ferry_system")
	units_root = units_root_node
	shore_point = rules.shore_point
	_camp_start = rules.camp_rect.position + rules.camp_rect.size / 2
	sail_time = rules.ferry_sail_time
	# Le navi grandi (pentecontere) sono nella scena del livello.
	for n in ["Drakkar1", "Drakkar2", "Nave1", "Nave2"]:
		var ship := level_root.find_child(n, true, false) as Node3D
		if ship:
			ship_targets.append(ship.global_position)
	if ship_targets.is_empty():
		ship_targets.append(Vector3(shore_point.x - 3.0, -0.2, shore_point.y - 12.0))
	var scene := load(BOAT_MODEL) as PackedScene
	for i in rules.ferry_boats:
		var home := Vector3(shore_point.x - 1.0, 0.12, shore_point.y + i * 9.5)
		var boat := _make_boat(scene, home, units_root.get_parent())
		_station_skipper(boat)
		boats.append(boat)


## Passerella d'imbarco: due assi dalla riva verso la barca, con pali di ormeggio.
func _make_gangway(home: Vector3, parent: Node) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.40, 0.29, 0.17)
	wood.roughness = 0.9
	var root := Node3D.new()
	root.name = "Gangway"
	parent.add_child(root)
	root.global_position = Vector3(home.x + 1.15, 0.0, home.z)
	var plank := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.9, 0.07, 0.55)
	plank.mesh = box
	plank.material_override = wood
	plank.position = Vector3(0.0, 0.16, 0.0)
	plank.rotation.z = deg_to_rad(-6.0)
	root.add_child(plank)
	for dz in [-0.38, 0.38]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.06
		cyl.height = 0.9
		post.mesh = cyl
		post.material_override = wood
		post.position = Vector3(-0.8, 0.35, dz)
		root.add_child(post)


func _make_boat(scene: PackedScene, home: Vector3, parent: Node) -> Boat:
	var b := Boat.new()
	var root := Node3D.new()
	root.name = "FerryBoat"
	parent.add_child(root)
	root.global_position = home
	if scene:
		var model := scene.instantiate() as Node3D
		root.add_child(model)
		var box := _aabb(model)
		var longest := maxf(box.size.x, box.size.z)
		if longest > 0.01:
			model.scale = Vector3.ONE * (BOAT_LENGTH / longest)
		model.position = Vector3(0, -box.position.y * model.scale.y, 0) - box.get_center() * Vector3(model.scale.x, 0, model.scale.z)
		# Lo scafo è lungo sull'asse Z o X: la prua punta verso il mare (-X).
		if box.size.z > box.size.x:
			root.rotation.y = PI * 0.5
	b.node = root
	b.home = home
	return b


static func _aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not m.visible:
			continue
		var box := m.get_aabb()
		var t := node.global_transform.affine_inverse() * m.global_transform
		box = t * box
		out = box if first else out.merge(box)
		first = false
	return out


func busy_jobs() -> int:
	return jobs.size()


## Un ferito è arrivato in salvo all'accampamento: va organizzato il trasporto.
func request_evacuation(w: WoundedSoldier) -> void:
	# Anche i feriti gravi che Ulisse ha portato a piedi fino al campo vengono presi in consegna.
	if _has_job(w):
		return   # già in consegna a un soldato (cambio di sostegno lungo il percorso)
	var j := Job.new()
	j.wounded = w
	jobs.append(j)


func _has_job(w: WoundedSoldier) -> bool:
	for j in jobs:
		if j.wounded == w:
			return true
	return false


## Un compagno prende il posto di Ulisse nel sorreggere un ferito che cammina: lo porta all'accampamento e poi alla riva.
func request_handover(w: WoundedSoldier, a: AllySoldier) -> bool:
	if a == null or not _alive(a) or a.busy or _has_job(w):
		return false
	var j := Job.new()
	j.wounded = w
	j.bearer = a
	j.to_camp = not w.camp_rect.has_point(w.cell)
	j.phase = Phase.CARRY
	a.busy = true
	a.can_swap_with_allies = true
	a.step_duration = 0.42
	w.start_support(a, WoundedSoldier.State.CARRIED)
	jobs.append(j)
	return true


## Un ferito già rialzato che si è accasciato: un compagno libero vicino va a rialzarlo e portarlo al campo/alla riva.
func request_pickup(w: WoundedSoldier) -> bool:
	if _has_job(w) or w.state != WoundedSoldier.State.LYING:
		return false
	var near := false
	for node in get_tree().get_nodes_in_group(&"achei"):
		var a := node as AllySoldier
		if a and not a.busy and a.health > 0 and a.leader == null and _dist(a, w) <= w.helper_range:
			near = true
			break
	if not near:
		return false
	var j := Job.new()
	j.wounded = w
	j.to_camp = not w.camp_rect.has_point(w.cell)
	jobs.append(j)
	return true


## Soldati liberi (non impegnati con altri feriti) che possono portare un ferito.
func free_bearers() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(&"achei"):
		var a := node as AllySoldier
		if a and not a.busy and a.health > 0:
			n += 1
	return n


## Un ferito grave è stato raggiunto da Ulisse: con quattro soldati liberi alzano la barella,
## altrimenti lo trascinano in due (o da soli, se ce n'è uno solo) fino all'accampamento e alla riva.
func request_stretcher(w: WoundedSoldier) -> void:
	var free := free_bearers()
	if free < STRETCHER_BEARERS:
		last_bearers = clampi(free, 1, 2)
		var d := Job.new()
		d.wounded = w
		d.want = last_bearers
		d.to_camp = true
		jobs.append(d)
		return
	last_bearers = STRETCHER_BEARERS
	var j := Job.new()
	j.wounded = w
	j.phase = Phase.STRETCH_CAMP
	j.pos = Vector2(w.global_position.x, w.global_position.z)
	j.stretcher = Stretcher.new()
	j.stretcher.name = "Stretcher"
	units_root.add_child(j.stretcher)
	j.stretcher.global_position = Vector3(j.pos.x, w.global_position.y, j.pos.y)
	grid.release(w.cell, w)
	for i in 4:
		var u := UnitFactory.make(AllySoldier, UnitFactory.MODEL_ACHEO, GridUnit.Team.ACHEI, 60, "StretcherBearer%d" % i) as AllySoldier
		u.busy = true
		u.show_health_bar = false
		u.position = Vector3(j.pos.x, w.global_position.y, j.pos.y)
		# I portatori hanno le mani sulle stanghe: niente spada.
		for g in u.get_node(^"Model").get_children():
			if g is UnitGear:
				(g as UnitGear).weapon_path = ""
		units_root.add_child(u)
		u.is_moving = true
		# Lati sinistro/destro della barella: la stanga sta dalla parte della mano destra o sinistra.
		var cm := u.get_node(^"Model") as CharacterModel
		if cm:
			cm.set_stance(&"stretcher_r" if i % 2 == 0 else &"stretcher_l")
		j.crew.append(u)
	jobs.append(j)


func _run_stretcher(j: Job, delta: float) -> void:
	var goal := shore_cell() if j.phase == Phase.STRETCH_SHORE else _camp_start
	var here := grid.world_to_cell(Vector3(j.pos.x, 0.0, j.pos.y))
	var arrived := here == goal
	if not arrived:
		var next := _next_step(here, goal)
		if next == Vector2i.ZERO:
			arrived = true   # nessun percorso: la posa dove si trova
		else:
			var tw := grid.cell_to_world(here + next)
			var to := Vector2(tw.x - j.pos.x, tw.z - j.pos.y)
			j.heading = lerp_angle(j.heading, atan2(-to.x, -to.y), minf(1.0, 6.0 * delta))
			j.pos += to.normalized() * minf(to.length(), stretcher_speed * delta)
	var y := grid.get_height_at_world(Vector3(j.pos.x, 0.0, j.pos.y))
	var origin := Vector3(j.pos.x, y, j.pos.y)
	j.stretcher.global_position = origin
	j.stretcher.rotation.y = j.heading
	var basis := Basis(Vector3.UP, j.heading)
	# Ogni portatore tiene la stanga accanto al fianco, a una spanna dall'estremità (mani a 0,26 m dal centro).
	var cx := Stretcher.WIDTH * 0.5 + 0.258   # la mano (HumanoidAnims) è a 0,258 m dal centro del portatore
	var cz := Stretcher.POLE_LENGTH * 0.5 - 0.2   # presa a una spanna dall'estremità della stanga
	var corners := [Vector3(-cx, 0, -cz), Vector3(cx, 0, -cz), Vector3(-cx, 0, cz), Vector3(cx, 0, cz)]
	for i in j.crew.size():
		var u := j.crew[i]
		if not is_instance_valid(u):
			continue
		u.global_position = origin + basis * corners[i]
		u.is_moving = not arrived
		var m := u.get_node_or_null(^"Model") as Node3D
		if m:
			m.rotation.y = j.heading
	var w := j.wounded
	if w.state != WoundedSoldier.State.LOST:
		w.global_position = origin + Vector3(0, Stretcher.BED_HEIGHT, 0)
		var wm := w.get_node_or_null(^"Model") as Node3D
		if wm:
			wm.rotation.y = j.heading
		w.is_moving = false
	if not arrived:
		return
	if j.phase == Phase.STRETCH_CAMP:
		w._model_node.play_lying(true)
		w.mark_saved()
		j.phase = Phase.STRETCH_SHORE
	else:
		j.phase = Phase.WAIT_BOAT


func shore_cell() -> Vector2i:
	if _shore_cell == Vector2i(-1, -1):
		var want := grid.world_to_cell(Vector3(shore_point.x, 0.0, shore_point.y))
		# Una casella della riva raggiungibile a piedi dall'accampamento.
		var closed := {}
		for c in grid.find_unreachable_cells(_camp_start):
			closed[c] = true
		var best := want
		var best_d := INF
		for y in grid.total_size().y:
			for x in grid.total_size().x:
				var c := Vector2i(x, y)
				if grid.is_blocked(c) or closed.has(c):
					continue
				var d := Vector2(c - want).length()
				if d < best_d:
					best_d = d
					best = c
		_shore_cell = best
	return _shore_cell


func _near_walkable(c: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cc := c + Vector2i(dx, dy)
				if grid.is_inside(cc) and not grid.is_blocked(cc):
					return cc
	return c


func _physics_process(delta: float) -> void:
	if grid == null:
		return
	_step_cd -= delta
	for j in jobs.duplicate():
		if j.wounded == null or not is_instance_valid(j.wounded) or j.wounded.state == WoundedSoldier.State.LOST:
			_abort(j)
			continue
		_run(j, delta)


func _abort(j: Job) -> void:
	for u in j.crew:
		if is_instance_valid(u):
			u.queue_free()
	if j.stretcher and is_instance_valid(j.stretcher):
		j.stretcher.queue_free()
	_release_bearers(j)
	jobs.erase(j)


func _release_bearers(j: Job) -> void:
	for b in [j.bearer, j.bearer2]:
		if b and is_instance_valid(b):
			b.busy = false
			b.can_swap_with_allies = false


## Il secondo soldato segue il ferito (o il compagno) restando accanto.
func _escort(j: Job, goal: Vector2i) -> void:
	var a := j.bearer2
	if not _alive(a):
		j.bearer2 = null
		return
	if a.is_moving:
		return
	if absi(a.cell.x - goal.x) + absi(a.cell.y - goal.y) <= 1:
		return
	a.step_duration = 0.42
	var next := _next_step(a.cell, goal)
	if next != Vector2i.ZERO:
		a.try_step(next)


func _run(j: Job, delta: float) -> void:
	if j.phase == Phase.STRETCH_CAMP or j.phase == Phase.STRETCH_SHORE:
		_run_stretcher(j, delta)
		return
	match j.phase:
		Phase.WAIT_BEARER:
			var b := _pick_bearer(j.wounded)
			if b:
				j.bearer = b
				b.busy = true
				b.can_swap_with_allies = true   # passa tra i compagni scambiandosi di posto
				if j.want > 1:
					var b2 := _pick_bearer(j.wounded)
					if b2:
						j.bearer2 = b2
						b2.busy = true
						b2.can_swap_with_allies = true
				j.phase = Phase.GO_TO_WOUNDED
		Phase.GO_TO_WOUNDED:
			if not _alive(j.bearer):
				j.bearer = null
				j.phase = Phase.WAIT_BEARER
				return
			if _dist(j.bearer, j.wounded) <= 1.9:
				if j.wounded.state == WoundedSoldier.State.LYING:
					# A terra: il soldato lo aiuta a rialzarsi, poi lo sorregge.
					j.wounded.begin_help_up(j.bearer, WoundedSoldier.State.CARRIED)
					j.phase = Phase.RAISING
					return
				j.wounded.start_support(j.bearer, WoundedSoldier.State.CARRIED)
				j.phase = Phase.CARRY
				return
			if j.bearer2:
				_escort(j, j.wounded.cell)
			_walk_towards(j, j.wounded.cell, delta)
		Phase.RAISING:
			if not _alive(j.bearer):
				j.bearer = null
				j.phase = Phase.WAIT_BEARER
				return
			if j.wounded.state == WoundedSoldier.State.CARRIED:
				j.phase = Phase.CARRY
			elif j.wounded.state == WoundedSoldier.State.LYING and not j.wounded._helping:
				j.phase = Phase.GO_TO_WOUNDED   # l'aiuto è saltato: riprova
		Phase.CARRY:
			if j.wounded.state == WoundedSoldier.State.LYING:
				j.phase = Phase.GO_TO_WOUNDED   # il ferito si è accasciato: il soldato torna a rialzarlo
				return
			if not _alive(j.bearer) and _alive(j.bearer2):
				j.bearer = j.bearer2
				j.bearer2 = null
				j.wounded.start_support(j.bearer, WoundedSoldier.State.CARRIED)
			if not _alive(j.bearer):
				# Il soldato è caduto: il ferito resta a terra in attesa di un altro.
				j.wounded.lie_down()
				j.wounded.state = WoundedSoldier.State.SAVED
				j.bearer = null
				j.phase = Phase.WAIT_BEARER
				return
			var target := _camp_start if j.to_camp else shore_cell()
			var tw := grid.cell_to_world(target)
			if j.bearer2:
				_escort(j, j.bearer.cell)
			if j.bearer.cell == target or Vector2(j.bearer.global_position.x - tw.x, j.bearer.global_position.z - tw.z).length() < 1.5:
				if j.to_camp:
					# Il ferito grave è in salvo all'accampamento: da qui lo si porta alla riva.
					j.to_camp = false
					j.wounded.mark_saved()
					j.wounded.start_support(j.bearer, WoundedSoldier.State.CARRIED)
					return
				j.phase = Phase.WAIT_BOAT
				return
			_walk_towards(j, target, delta)
		Phase.WAIT_BOAT:
			var boat := _free_boat()
			if boat:
				_load(boat, j)
				jobs.erase(j)


func _alive(u: GridUnit) -> bool:
	return u != null and is_instance_valid(u) and u.health > 0


func _dist(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func _pick_bearer(w: WoundedSoldier) -> AllySoldier:
	var best: AllySoldier = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(&"achei"):
		var a := n as AllySoldier
		if a == null or a.busy or a.health <= 0:
			continue
		var d := _dist(a, w)
		if d < best_d:
			best_d = d
			best = a
	return best


func _free_boat() -> Boat:
	for b in boats:
		if not b.busy:
			return b
	return null


## Il soldato fa un passo lungo il percorso più breve (ricalcolato a ogni passo).
func _walk_towards(j: Job, goal: Vector2i, delta: float) -> void:
	var a := j.bearer
	if a.is_moving:
		j.stuck = 0.0
		return
	a.step_duration = 0.42
	var next := _next_step(a.cell, goal)
	if next == Vector2i.ZERO:
		j.stuck += delta
		if j.stuck > 1.5:
			a.place_at(_near_walkable(goal))
			j.stuck = 0.0
		return
	if not a.try_step(next):
		j.stuck += delta
		if j.stuck > 1.0:
			var alt := a.cell + next
			if grid.is_walkable(alt):
				a.place_at(alt)
			j.stuck = 0.0
	else:
		j.stuck = 0.0


## Prima mossa di un percorso breve (BFS sulla griglia, caselle libere dagli ostacoli).
func _next_step(from: Vector2i, goal: Vector2i) -> Vector2i:
	if from == goal:
		return Vector2i.ZERO
	var came := {from: from}
	var frontier: Array[Vector2i] = [from]
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var found := false
	while not frontier.is_empty() and not found:
		var next_frontier: Array[Vector2i] = []
		for c in frontier:
			for d in dirs:
				var n := c + d
				if came.has(n) or not grid.is_inside(n) or grid.is_blocked(n) or not grid.step_allowed(c, n):
					continue
				came[n] = c
				if n == goal:
					found = true
					break
				next_frontier.append(n)
			if found:
				break
		frontier = next_frontier
	if not came.has(goal):
		return Vector2i.ZERO
	var c := goal
	while came[c] != from:
		c = came[c]
	return c - from


func _load(boat: Boat, j: Job) -> void:
	boat.busy = true
	var w := j.wounded
	boat.patient = w
	w.release_support()
	w.is_moving = false
	w.mark_evacuated()
	w.reparent(boat.node, true)
	w.visible = true   # mark_evacuated lo nasconde: sulla barca si vede fino allo sbarco
	if j.stretcher:
		boat.stretcher = j.stretcher
		j.stretcher.reparent(boat.node, true)
		j.stretcher.position = Vector3(0, 0.0, 0)
		j.stretcher.rotation = Vector3.ZERO
		for u in j.crew:
			if is_instance_valid(u):
				u.queue_free()
	_release_bearers(j)
	var ship := ship_targets[evacuated % ship_targets.size()]
	var out := Vector3(ship.x + 1.3, boat.home.y, ship.z)
	var sk: AllySoldier = boat.rowing.rowers[0] as AllySoldier if boat.rowing and not boat.rowing.rowers.is_empty() else null
	var skm: CharacterModel = sk.get_node_or_null(^"Model") as CharacterModel if sk else null
	var from := w.position
	var spot := Vector3(0.12, BoatRowing.FLOOR_Y, 0.2)
	var tw := create_tween()
	# 1) Il soldato di bordo si volta verso il ferito e lo aiuta a salire (si china, lo sostiene).
	tw.tween_callback(func() -> void:
		if sk:
			sk.rotation.y = atan2(-(spot.x - sk.position.x), -(spot.z - sk.position.z))
		if skm:
			skm.play_help_up()
		w.is_moving = true)
	tw.tween_method(_move_patient.bind(w, from, spot), 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 2) Il ferito si adagia sul fondo della barca.
	tw.tween_callback(func() -> void:
		if is_instance_valid(w):
			w.is_moving = false
			w.lie_down())
	var lie_to := Vector3(0, 0.38 if not j.stretcher else 0.55, 0)
	tw.tween_method(_move_patient.bind(w, spot, lie_to), 0.0, 1.0, 0.7)
	# 3) Il soldato si siede al banco e rema; la barca parte.
	tw.tween_callback(func() -> void:
		if boat.rowing:
			boat.rowing.set_rowing(true))
	tw.tween_interval(0.5)
	tw.tween_method(func(t: float) -> void: _sail(boat, boat.home, out, t), 0.0, 1.0, sail_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: _unload(boat))
	tw.tween_interval(0.6)
	tw.tween_method(func(t: float) -> void: _sail(boat, out, boat.home, t), 0.0, 1.0, sail_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 4) Di ritorno il soldato (sempre a bordo) smette di vogare e aspetta in piedi il prossimo ferito.
	tw.tween_callback(func() -> void:
		if boat.rowing:
			boat.rowing.set_rowing(false)
		boat.busy = false)


## Sposta il ferito sulla barca (posizioni nello spazio della barca), voltandolo verso il centro.
func _move_patient(t: float, w: WoundedSoldier, a: Vector3, b: Vector3) -> void:
	if not is_instance_valid(w):
		return
	w.position = a.lerp(b, t)
	var wm := w.get_node_or_null(^"Model") as Node3D
	if wm and w.is_moving:
		wm.rotation.y = lerp_angle(wm.rotation.y, PI * 0.5, 0.08)


## Ogni barca ha il suo soldato fisso: non scende mai, aiuta a far salire il ferito, poi si siede e rema.
func _station_skipper(boat: Boat) -> void:
	boat.rowing = BoatRowing.board(boat.node, units_root, [0.85] as Array[float])
	boat.rowing.set_rowing(false)
	for u in boat.rowing.rowers:
		boat.crew.append(u as AllySoldier)


func _sail(boat: Boat, a: Vector3, b: Vector3, t: float) -> void:
	var p := a.lerp(b, t)
	var bob := sin(t * 20.0) * 0.04
	boat.node.global_position = Vector3(p.x, p.y + bob, p.z)
	var dir := b - a
	if dir.length() > 0.01:
		boat.node.rotation.y = lerp_angle(boat.node.rotation.y, atan2(-dir.x, -dir.z), 0.1)


func _unload(boat: Boat) -> void:
	if boat.patient and is_instance_valid(boat.patient):
		boat.patient.visible = false
	if boat.stretcher and is_instance_valid(boat.stretcher):
		boat.stretcher.visible = false
	boat.stretcher = null
	boat.patient = null
	evacuated += 1
	wounded_evacuated.emit(evacuated)
