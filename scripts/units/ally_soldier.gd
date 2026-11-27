class_name AllySoldier
extends GridUnit
## Soldato acheo alleato. Non segue Ulisse (niente sciame): resta al suo posto (`post_cell`) e agisce
## solo per ragioni locali. Se vede un troiano entro `sight_range` lo ingaggia e chiama in aiuto i
## compagni vicini (al massimo `max_responders`); finito il combattimento torna al posto.
## Con `leader` assegnato da fuori (soccorso: scorta al ferito) segue quel bersaglio.

## Distanza (in caselle, Manhattan) oltre la quale il soldato si avvicina al leader.
@export var follow_distance := 2
## Pausa tra un passo e l'altro, in secondi.
@export var think_interval := 0.35

## Se assegnato (dal soccorso), il soldato segue questo bersaglio invece di fare la guardia.
var leader: GridUnit
## Postazione: la casella in cui nasce. Qui torna dopo ogni scontro.
var post_cell := Vector2i(-1, -1)
## Raggio (m) entro cui nota un troiano.
@export var sight_range := 8.0
## Raggio (m) entro cui un compagno che ingaggia chiama in aiuto gli altri.
@export var assist_range := 10.0
## Massimo di compagni che accorrono in aiuto di chi ha ingaggiato (oltre a lui).
@export var max_responders := 2
## Distanza massima (m) dalla postazione a cui insegue un nemico.
@export var leash_range := 14.0
var target: GridUnit
@export var attack_damage := 12
@export var attack_cooldown := 1.0

## Se vero, il soldato è impegnato in un compito (soccorso) comandato da fuori.
var busy := false

var _think_timer := 0.0
var _attack_cd := 0.0


## Chiamato dal ferito che questo soldato accompagna alla riva: andatura di scorta: il ferito gli cammina a sinistra, col suo braccio attorno alle spalle.
func set_carrying(on: bool, _helped := false) -> void:
	var model := get_node_or_null(^"Model") as CharacterModel
	if model:
		model.set_stance(&"carry_l" if on else &"normal")


## Si ferma, si volta verso `target_pos` (mondo) e si china ad aiutare un ferito a rialzarsi.
func start_help_up(target_pos: Vector3, _seconds: float) -> void:
	is_moving = false
	var d := Vector2(target_pos.x - global_position.x, target_pos.z - global_position.z)
	if d.length() > 0.01 and _model:
		_model.rotation.y = atan2(-d.x, -d.y)
	var model := get_node_or_null(^"Model") as CharacterModel
	if model:
		model.play_help_up()


func _ready() -> void:
	# Passi concatenati: il passo dura quanto la pausa di ragionamento, così il soldato cammina con
	# continuità (stessa velocità media di prima) invece di scattare e fermarsi a ogni casella.
	step_duration += think_interval
	super._ready()
	post_cell = cell


func _physics_process(delta: float) -> void:
	_attack_cd -= delta
	if busy:
		return
	if _fight():
		return
	_think_timer -= delta
	if is_moving or _think_timer > 0.0:
		return
	_think_timer = think_interval
	if leader != null and is_instance_valid(leader):
		_follow_leader()
		return
	_guard_think()


## Scorta: si avvicina al bersaglio assegnato dal soccorso.
func _follow_leader() -> void:
	var diff := leader.cell - cell
	if absi(diff.x) + absi(diff.y) <= follow_distance:
		return
	_step_towards(leader.cell)


## Guardia: ingaggia i troiani in vista, altrimenti torna al posto.
func _guard_think() -> void:
	if target != null and not _target_ok(target):
		target = null
	if target == null:
		target = _scan_enemy()
		if target != null:
			_call_for_help(target)
	if target != null:
		var d := target.cell - cell
		if absi(d.x) + absi(d.y) > 1:
			_step_towards(target.cell)
		return
	if post_cell != Vector2i(-1, -1) and cell != post_cell:
		_step_towards(post_cell)


func _target_ok(t: GridUnit) -> bool:
	if not is_instance_valid(t) or t.health <= 0:
		return false
	return _dist_to_post(t) <= leash_range


func _dist_to_post(u: Node3D) -> float:
	if post_cell == Vector2i(-1, -1) or grid == null:
		return 0.0
	var p := grid.cell_to_world(post_cell)
	return Vector2(u.global_position.x - p.x, u.global_position.z - p.z).length()


func _scan_enemy() -> GridUnit:
	var best: GridUnit = null
	var best_d := sight_range
	for n in get_tree().get_nodes_in_group(&"troiani"):
		var t := n as GridUnit
		if t == null or t.health <= 0:
			continue
		var d := Vector2(t.global_position.x - global_position.x, t.global_position.z - global_position.z).length()
		if d < best_d and _dist_to_post(t) <= leash_range and _engaged_count(t) < 1 + max_responders:
			best_d = d
			best = t
	return best


## Quanti alleati stanno già ingaggiando questo nemico (a ciascun nemico accorre un gruppo piccolo).
func _engaged_count(enemy: GridUnit) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(&"achei"):
		var a := node as AllySoldier
		if a != null and a != self and a.target == enemy and a.health > 0:
			n += 1
	return n


## Chiama in soccorso i compagni liberi più vicini (piccoli gruppi, non tutto il campo).
func _call_for_help(enemy: GridUnit) -> void:
	var cands: Array[AllySoldier] = []
	for n in get_tree().get_nodes_in_group(&"achei"):
		var a := n as AllySoldier
		if a == null or a == self or a.busy or a.health <= 0 or a.leader != null or a.target != null:
			continue
		if a.global_position.distance_to(global_position) <= assist_range:
			cands.append(a)
	cands.sort_custom(func(x: AllySoldier, y: AllySoldier) -> bool:
		return x.global_position.distance_to(enemy.global_position) < y.global_position.distance_to(enemy.global_position))
	for i in mini(max_responders - _engaged_count(enemy), cands.size()):
		cands[i].target = enemy


## Un passo verso `goal`: prova gli assi dal più lungo al più corto, poi i laterali.
func _step_towards(goal: Vector2i) -> void:
	var diff := goal - cell
	var dirs: Array[Vector2i] = []
	var px := Vector2i(signi(diff.x), 0)
	var py := Vector2i(0, signi(diff.y))
	if absi(diff.x) >= absi(diff.y):
		dirs = [px, py]
	else:
		dirs = [py, px]
	for d in dirs:
		if d != Vector2i.ZERO and try_step(d):
			return
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if d != -dirs[0] and not dirs.has(d) and try_step(d):
			return


## Se un troiano è accanto, lo colpisce (e non si muove). True se ha combattuto.
func _fight() -> bool:
	if grid == null or is_moving or health <= 0:
		return false
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var unit := grid.get_occupant(cell + d) as GridUnit
		if unit and unit.team == GridUnit.Team.TROIANI and unit.health > 0:
			face(d)
			if _attack_cd <= 0.0:
				_attack_cd = attack_cooldown
				melee_strike(unit, attack_damage)
			return true
	return false


func _on_died() -> void:
	_become_corpse()


## Dopo una parata o una schivata contrattacca quasi subito.
func riposte() -> void:
	_attack_cd = minf(_attack_cd, 0.3)
