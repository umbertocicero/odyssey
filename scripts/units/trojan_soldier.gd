class_name TrojanSoldier
extends GridUnit
## Soldato troiano di guardia al castello. Tre stati:
##  - GUARD: sta alla sua postazione, si guarda attorno, ogni tanto fa qualche passo di ronda.
##  - CHASE: ha visto (o sentito, o subito un colpo da) un acheo: lo insegue e lo attacca. Dà l'allarme
##    ai commilitoni vicini, che si uniscono. Se perde il bersaglio per un po', o si allontana troppo
##    dalla postazione, torna indietro.
##  - RETURN: cammina verso la postazione (anche i rinforzi appena usciti dalla porta). Se vede un nemico
##    strada facendo, passa all'inseguimento.
## La vista è un cono davanti al soldato con portata ridotta dalla notte e dalla pioggia; sotto
## `hearing_range` caselle si accorge comunque di chi gli è vicino. Feriti a terra: non bersagli
## (vedi is_targetable()).

enum State { GUARD, CHASE, RETURN }

@export var attack_damage := 8
@export var attack_interval := 1.3
@export var think_interval := 0.3
## Portata della vista (caselle) di giorno e semi-angolo del cono (gradi).
@export_range(2.0, 30.0) var sight_range := 9.0
@export_range(10.0, 180.0) var sight_half_angle := 70.0
## Entro questa distanza si accorge comunque di chi gli è vicino, anche alle spalle.
@export_range(0.0, 8.0) var hearing_range := 2.5
## Distanza massima dalla postazione oltre la quale smette l'inseguimento.
@export_range(4.0, 60.0) var leash_range := 22.0
## Secondi senza vedere il bersaglio prima di rinunciare.
@export_range(1.0, 20.0) var lose_target_time := 4.0
## Raggio (caselle) entro cui l'allarme di un soldato fa scattare gli altri.
@export_range(0.0, 30.0) var alarm_radius := 10.0
## Raggio della ronda attorno alla postazione.
@export_range(0, 6) var patrol_radius := 2

var kills_credit := true
var state: State = State.GUARD
var post_cell := Vector2i(-1, -1)
var target: GridUnit
var _think := 0.0
var _attack_cd := 0.0
var _halted := false
var _model_node: CharacterModel
var _lost_timer := 0.0
var _last_seen := Vector2i.ZERO   # ultima casella in cui ha visto il bersaglio: da lì lo cerca, non conosce la posizione vera
var _idle_timer := 0.0
var _clock: LevelClock


## Assegna la postazione di guardia e parte camminando verso di essa (rinforzi dalla porta).
func assign_post(c: Vector2i, walk_there := true) -> void:
	post_cell = c
	if walk_there and grid != null and cell != c:
		state = State.RETURN


## Esce da un varco fuori dalla griglia: parte da `from_world` e cammina in linea retta fino alla propria
## casella (già occupata), poi agisce normalmente.
func emerge_from(from_world: Vector3, duration: float) -> void:
	var end := global_position
	from_world.y = end.y
	global_position = from_world
	face(Vector2i(0, 1))
	is_moving = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", end, duration)
	_tween.finished.connect(_on_step_finished)


func _ready() -> void:
	step_duration += think_interval   # passi concatenati, vedi AllySoldier
	super._ready()
	_model_node = get_node_or_null(^"Model") as CharacterModel
	_think = randf_range(0.0, think_interval)
	_idle_timer = randf_range(1.0, 3.0)
	_clock = get_tree().get_first_node_in_group(&"level_clock") as LevelClock
	if post_cell == Vector2i(-1, -1):
		post_cell = cell
		# Orientamento vario: ognuno guarda da una parte diversa invece di fissare tutti le mura.
		face([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].pick_random())


func halt() -> void:
	_halted = true


## Riprende il comportamento normale dopo un duello.
func resume() -> void:
	_halted = false
	_attack_cd = 0.8


func _physics_process(delta: float) -> void:
	if _halted or health <= 0:
		return
	_attack_cd -= delta
	_think -= delta
	if is_moving or _think > 0.0:
		return
	_think = think_interval
	match state:
		State.GUARD:
			_guard(think_interval)
		State.CHASE:
			_chase()
		State.RETURN:
			_return_to_post()


# --- Stati -----------------------------------------------------------------

func _guard(dt: float) -> void:
	var seen := _scan()
	if seen:
		_alert(seen)
		return
	_idle_timer -= dt
	if _idle_timer > 0.0:
		return
	_idle_timer = randf_range(1.5, 4.5)
	var r := randf()
	if r < 0.5:
		# Si guarda attorno.
		face([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].pick_random())
	elif patrol_radius > 0:
		# Ronda: un passo, restando vicino alla postazione.
		var d: Vector2i = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].pick_random()
		var to := cell + d
		if _cheb(to - post_cell) <= patrol_radius and not is_moving:
			try_step(d)


func _chase() -> void:
	if not _target_valid():
		target = null
		_to_return()
		return
	if _dist(post_cell) > leash_range:
		_to_return()
		return
	if _can_see(target):
		_lost_timer = 0.0
		_last_seen = target.cell
	else:
		_lost_timer += think_interval
		if _lost_timer >= lose_target_time:
			# Prima di arrendersi controlla se c'è un altro acheo a vista.
			var other := _scan()
			if other:
				target = other
				_last_seen = other.cell
				_lost_timer = 0.0
			else:
				_to_return()
				return
	var diff := target.cell - cell
	if absi(diff.x) + absi(diff.y) == 1:
		face(diff)
		if _attack_cd <= 0.0:
			if Duel.blocks_attack(target, self):
				return   # Ulisse è in duello con un altro: aspetta il suo turno
			# Un troiano che attacca Ulisse lo trascina in un duello in prima persona.
			if target.is_in_group(&"player") and Duel.try_begin(target, self):
				return
			_attack_cd = attack_interval
			melee_strike(target, attack_damage)
		return
	if _lost_timer > 0.0:
		# Fuori vista: va dove l'ha visto l'ultima volta (e si guarda attorno quando ci arriva).
		if _cheb(_last_seen - cell) <= 1:
			_lost_timer += think_interval * 2.0
			face([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].pick_random())
		else:
			_step_toward(_last_seen, false)
		return
	_step_toward(target.cell, true)


func _return_to_post() -> void:
	var seen := _scan()
	if seen:
		_alert(seen)
		return
	if cell == post_cell:
		state = State.GUARD
		_idle_timer = randf_range(0.5, 2.0)
		return
	# Se la postazione è occupata da un compagno, ci si ferma accanto.
	if _cheb(post_cell - cell) <= 1 and grid.get_occupant(post_cell) != null:
		post_cell = cell
		state = State.GUARD
		return
	if not _step_toward(post_cell, false):
		# Bloccato: si accontenta del punto in cui è.
		_idle_timer -= think_interval
		if _idle_timer < -3.0:
			post_cell = cell
			state = State.GUARD


# --- Percezione ------------------------------------------------------------

func _effective_sight() -> float:
	var s := sight_range
	if _clock != null and is_instance_valid(_clock):
		s *= 1.0 - 0.35 * _clock.night_amount() - 0.25 * clampf(_clock.rain, 0.0, 1.0)
	return maxf(s, hearing_range + 1.0)


func _can_see(u: GridUnit) -> bool:
	var diff := u.cell - cell
	var d := Vector2(diff).length()
	if d <= hearing_range:
		return true
	if d > _effective_sight():
		return false
	var fwd := Vector2(facing)
	if fwd == Vector2.ZERO:
		fwd = Vector2(0, 1)
	var ang := rad_to_deg(acos(clampf(fwd.normalized().dot(Vector2(diff).normalized()), -1.0, 1.0)))
	if ang > sight_half_angle:
		return false
	# Il terreno (muri, dislivelli) copre la vista.
	return grid == null or grid.has_line_of_fire(global_position + Vector3.UP * 1.5, u.global_position + Vector3.UP * 1.3)


func _target_valid() -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() or target.health <= 0:
		return false
	return not (target.has_method(&"is_targetable") and not target.is_targetable())


## L'acheo più vicino che il soldato vede, o null.
func _scan() -> GridUnit:
	var best: GridUnit = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"achei"):
		var u := node as GridUnit
		if u == null or u.health <= 0:
			continue
		if u.has_method(&"is_targetable") and not u.is_targetable():
			continue
		var d := Vector2(u.cell - cell).length()
		if d < best_d and _can_see(u):
			best_d = d
			best = u
	return best


## Passa all'inseguimento e dà l'allarme ai compagni vicini.
func _alert(who: GridUnit, raise_alarm := true) -> void:
	target = who
	_last_seen = who.cell
	state = State.CHASE
	_lost_timer = 0.0
	if raise_alarm:
		for node in get_tree().get_nodes_in_group(&"troiani"):
			var t := node as TrojanSoldier
			if t == null or t == self or t.health <= 0 or t.state == State.CHASE:
				continue
			if Vector2(t.cell - cell).length() <= alarm_radius:
				t._alert(who, false)


func _to_return() -> void:
	target = null
	state = State.RETURN
	_idle_timer = 0.0


## Chi mi colpisce, anche se non lo vedo (alle spalle, di notte), attira la mia attenzione.
func take_damage(amount: int, hit_dir := Vector3.ZERO, bleed := true) -> void:
	super.take_damage(amount, hit_dir, bleed)
	if health <= 0 or state == State.CHASE:
		return
	var near: GridUnit = null
	var best := 6.0
	for node in get_tree().get_nodes_in_group(&"achei"):
		var u := node as GridUnit
		if u == null or u.health <= 0:
			continue
		if u.has_method(&"is_targetable") and not u.is_targetable():
			continue
		var d := Vector2(u.cell - cell).length()
		if d < best:
			best = d
			near = u
	if near:
		_alert(near)


# --- Movimento -------------------------------------------------------------

## Un passo verso `goal` lungo il percorso più breve (BFS limitato); se non lo trova prova la direzione
## diretta. Con `adjacent` si ferma accanto alla casella obiettivo. True se il passo è partito.
func _step_toward(goal: Vector2i, adjacent: bool) -> bool:
	var dir := _bfs_first_step(goal, adjacent)
	if dir != Vector2i.ZERO and try_step(dir):
		return true
	var diff := goal - cell
	var primary := Vector2i(signi(diff.x), 0) if absi(diff.x) >= absi(diff.y) else Vector2i(0, signi(diff.y))
	var secondary := Vector2i(0, signi(diff.y)) if primary.x != 0 else Vector2i(signi(diff.x), 0)
	if primary != Vector2i.ZERO and try_step(primary):
		return true
	if secondary != Vector2i.ZERO and try_step(secondary):
		return true
	var sides: Array[Vector2i] = [Vector2i(primary.y, primary.x), Vector2i(-primary.y, -primary.x)]
	sides.shuffle()
	for s in sides:
		if s != Vector2i.ZERO and try_step(s):
			return true
	return false


const _DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const _BFS_LIMIT := 900


func _bfs_first_step(goal: Vector2i, adjacent: bool) -> Vector2i:
	if grid == null:
		return Vector2i.ZERO
	var first := {cell: Vector2i.ZERO}
	var queue: Array[Vector2i] = [cell]
	var head := 0
	while head < queue.size() and head < _BFS_LIMIT:
		var c := queue[head]
		head += 1
		for d in _DIRS:
			var n := c + d
			if first.has(n):
				continue
			var reached := n == goal
			if not reached:
				if not grid.is_inside(n) or grid.is_blocked(n) or not grid.step_allowed(c, n):
					continue
				if grid.get_occupant(n) != null:
					continue
			first[n] = first[c] if c != cell else d
			if reached or (adjacent and c == goal):
				return first[n]
			if adjacent and absi(n.x - goal.x) + absi(n.y - goal.y) == 1:
				return first[n]
			queue.append(n)
	return Vector2i.ZERO


func _dist(c: Vector2i) -> float:
	return Vector2(c - cell).length()


func _cheb(v: Vector2i) -> int:
	return maxi(absi(v.x), absi(v.y))


func _on_died() -> void:
	_halted = true
	_become_corpse()   # resta a terra; il tetto ai cadaveri è in ClashFx.register_corpse()


## Dopo una parata o una schivata contrattacca quasi subito.
func riposte() -> void:
	_attack_cd = minf(_attack_cd, 0.3)
