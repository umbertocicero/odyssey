class_name GridUnit
extends CharacterBody3D
## Unità che si muove a passi sulla DioramaGrid (Ulisse, soldati achei, troiani).
## Il movimento è un tween da una cella all'altra; la cella occupata è
## registrata nella griglia, così le unità non si sovrappongono.
##
## Se can_swap_with_allies è attivo (Ulisse), quando la casella di arrivo è
## occupata da un alleato fermo, le due unità si scambiano di posto: gli
## alleati non possono mai chiudere la strada a Ulisse.

signal step_started(from_cell: Vector2i, to_cell: Vector2i)
signal step_finished(cell: Vector2i)
signal health_changed(current: int, maximum: int)
signal died
## Scavalcamento di un ostacolo basso (da una casella a quella oltre l'ostacolo).
signal vaulted(from_cell: Vector2i, to_cell: Vector2i)

## Arrampicata su un blocco alto (altezza in m) e discesa dall'altra parte.
signal climbed(from_cell: Vector2i, to_cell: Vector2i, height: float)

enum Team { ACHEI, TROIANI }

@export var team: Team = Team.ACHEI
## Durata di un passo, in secondi.
@export var step_duration := 0.18
## Se attivo, può scambiarsi di posto con un alleato fermo che gli sbarra la strada.
@export var can_swap_with_allies := false
## Nodo che contiene il modello: viene ruotato verso la direzione del passo.
@export var model_path: NodePath = ^"Model"
## Se attivo, davanti a un ostacolo basso l'unità lo scavalca con un balzo.
@export var can_vault := true
## Durata del balzo, in secondi, e altezza massima dell'arco.
@export_range(0.2, 1.5) var vault_duration := 0.55
@export_range(0.2, 2.0) var vault_height := 0.85
## Se attivo, davanti a un blocco più alto (ma non una parete) l'unità vi sale e scende dall'altra parte.
@export var can_climb := true
## Punti vita.
@export_range(1, 1000) var max_health := 60
## Mostra la barra della vita sopra la testa quando l'unità è ferita.
@export var show_health_bar := true
## Velocità dell'animazione "walk" (se il modello ne ha una).
@export var walk_anim_speed := 1.6
## Secondi da fermo prima di tornare all'animazione "idle" (evita lo scatto
## tra un passo e l'altro quando si tiene premuto il tasto).
@export var idle_delay := 0.08

var grid: DioramaGrid
var cell := Vector2i.ZERO
var facing := Vector2i(0, 1)
var is_moving := false
var health := 0

var _tween: Tween
var _health_bar: HealthBar3D
var _anim: AnimationPlayer
var _still_time := 0.0
var _hit_playing := false

@onready var _model: Node3D = get_node_or_null(model_path)


func _ready() -> void:
	health = max_health
	if show_health_bar:
		_health_bar = HealthBar3D.new()
		add_child(_health_bar)
		_health_bar.set_ratio(1.0)
	add_to_group(&"units")
	_setup_animation()
	add_to_group(&"achei" if team == Team.ACHEI else &"troiani")
	grid = get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	if grid == null:
		push_warning("%s: nessuna DioramaGrid nella scena." % name)
		return
	cell = grid.world_to_cell(global_position)
	global_position = grid.cell_to_world(cell)
	grid.occupy(cell, self)


## True se questa unità può entrare nella casella (libera, oppure occupata
## da un alleato fermo con cui scambiarsi di posto).
func can_enter(target: Vector2i) -> bool:
	if grid == null or not grid.is_inside(target) or grid.is_blocked(target):
		return false
	if not grid.step_allowed(cell, target):
		return false # parete di roccia: il dislivello è troppo alto
	var other := grid.get_occupant(target)
	if other == null:
		return true
	return _can_swap_with(other)


## Prova a fare un passo nella direzione indicata (un asse della griglia).
## Restituisce true se il passo è partito.
func try_step(direction: Vector2i) -> bool:
	if is_moving or grid == null or direction == Vector2i.ZERO:
		return false
	face(direction)
	var target := cell + direction
	if not can_enter(target):
		if can_vault and grid.can_vault_over(cell, direction):
			_vault(direction)
			return true
		if can_climb and grid.can_climb_over(cell, direction):
			_climb(direction)
			return true
		return false

	var from := cell
	var other := grid.get_occupant(target) as GridUnit
	grid.release(from, self)
	if other:
		# Scambio di posto con l'alleato.
		grid.release(target, other)
		other.cell = from
		grid.occupy(from, other)
		other.face(-direction)
		other._move_to(from)
	grid.occupy(target, self)
	cell = target
	step_started.emit(from, target)
	_move_to(target)
	return true


## Sposta istantaneamente l'unità in una casella (spawn, cutscene, test).
func place_at(target: Vector2i) -> bool:
	if grid == null or not grid.is_walkable(target):
		return false
	if _tween:
		_tween.kill()
	is_moving = false
	grid.release(cell, self)
	cell = target
	grid.occupy(cell, self)
	global_position = grid.cell_to_world(cell)
	return true


## Colpo corpo a corpo da `attacker`: il modello può parare o schivare (CharacterModel.defend),
## poi passa il danno rimasto. Versione istantanea (senza scambio di colpi): vedi melee_strike().
func take_melee(amount: int, attacker: Node3D) -> void:
	var m := _model as CharacterModel
	if m and health > 0:
		amount = m.defend(amount, attacker.global_position if attacker else global_position)
	if amount > 0:
		take_damage(amount, (global_position - attacker.global_position) if attacker else Vector3.ZERO)


## Scambio di colpi con tempi credibili. L'attacco parte subito (animazione di fendente); l'esito si
## decide subito (colpito / parato / schivato) così il bersaglio è in guardia quando la lama arriva,
## all'istante di impatto della clip. Parata: lama contro lama o scudo con scintille e lampo, danno
## dimezzato, e il parante contrattacca subito. Schivata: colpo a vuoto, l'attaccante resta scoperto.
## Colpo a segno: spruzzo di sangue, reazione, macchie.
func melee_strike(target: GridUnit, amount: int) -> void:
	if Duel.blocks_attack(target, self):
		return   # duello in prima persona in corso: uno contro uno, nessuno si intromette
	var m := _model as CharacterModel
	var tm := target._model as CharacterModel if target else null
	if m == null or tm == null or target.health <= 0 or health <= 0:
		if m:
			m.play_attack()
		if target:
			target.take_melee(amount, self)
		return
	m.play_attack()
	if not has_meta(&"drew_sword"):
		set_meta(&"drew_sword", true)
		GameAudio.draw(self, global_position + Vector3.UP)
	else:
		GameAudio.swing(self, global_position + Vector3.UP)
	var t_hit := m.attack_impact_remaining()
	var kind := tm.plan_defense()
	if kind != &"hit":
		tm.face_toward(global_position)
		tm.start_defense(kind, maxf(t_hit - CharacterModel.DEFENSE_LEAD, 0.0))
	get_tree().create_timer(t_hit).timeout.connect(_resolve_strike.bind(target, amount, kind))


func _resolve_strike(target: GridUnit, amount: int, kind: StringName) -> void:
	if not is_inside_tree() or health <= 0 or not is_instance_valid(target) or not target.is_inside_tree():
		return
	if Duel.blocks_attack(target, self):
		return   # nel frattempo è cominciato un duello: il colpo non arriva
	var to := target.global_position - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.01 else Vector3(-sin(_model.global_rotation.y), 0, -cos(_model.global_rotation.y))
	var tm := target._model as CharacterModel
	if target.health <= 0 or to.length() > 2.4:
		return   # il bersaglio è caduto o si è allontanato: colpo a vuoto
	if kind == &"hit":
		var lethal := target.health <= amount
		if lethal:
			GameAudio.slash_kill(self, target.global_position + Vector3.UP)
		else:
			GameAudio.hit(self, target.global_position + Vector3.UP)
		target.take_damage(amount, dir)
		target._shove(dir)
		return
	if kind == &"block":
		var shield := tm.has_shield()
		var contact := (tm.guard_point(shield) + (_model as CharacterModel).guard_point(false)) * 0.5
		ClashFx.sparks(self, contact, -dir + Vector3.UP * 0.4)
		GameAudio.clash(self, contact)
		target._shove(dir * 0.5)
		if amount / 2 > 0:
			target.take_damage(amount / 2, dir, false)
	else:
		# Schivata: il fendente taglia l'aria e l'attaccante si sbilancia in avanti.
		_shove(dir * 0.5)
	target.riposte()


## Dopo aver parato o schivato, l'IA contrattacca presto (la ridefiniscono soldati e troiani).
func riposte() -> void:
	pass


## Piccolo contraccolpo del corpo nella direzione del colpo, che poi si riassesta. Si sposta il modello
## interno (non il nodo Model, la cui velocità serve a scegliere l'andatura).
func _shove(dir: Vector3) -> void:
	var m := _model as CharacterModel
	if m == null or m.instance == null or health <= 0 or m.dead:
		return
	var body := m.instance
	var rest := body.position
	var push := m.to_local(m.global_position + dir * 0.14)
	var t := body.create_tween()
	t.tween_property(body, "position", rest + Vector3(push.x, 0, push.z), 0.06)
	t.tween_property(body, "position", rest, 0.22).set_trans(Tween.TRANS_SINE)


var _last_hit_dir := Vector3.ZERO   # verso dell'ultimo colpo (mondo): sceglie come cade il morto


## Toglie punti vita; a zero l'unità muore. `hit_dir`: verso del colpo (mondo), per lo spruzzo di sangue.
func take_damage(amount: int, hit_dir := Vector3.ZERO, bleed := true) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_on_health_changed()
	if bleed and _model is CharacterModel:
		ClashFx.blood_hit(self, global_position + Vector3.UP * 1.15, hit_dir, health == 0)
	if _model and not _model is CharacterModel:
		# Piccolo sussulto quando viene colpita (i personaggi riggati hanno l'animazione "hit").
		var tween := create_tween()
		tween.tween_property(_model, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
		tween.tween_property(_model, "scale", Vector3.ONE, 0.12)
	if health > 0 and _anim and _anim.has_animation(&"hit"):
		_hit_playing = true
		_anim.play(&"hit", 0.05)
	if health == 0:
		_last_hit_dir = hit_dir
		died.emit()
		_on_died()


func heal_full() -> void:
	health = max_health
	_on_health_changed()


func _on_health_changed() -> void:
	health_changed.emit(health, max_health)
	if _health_bar:
		_health_bar.set_ratio(float(health) / max_health)


## Il caduto resta a terra: niente collisioni né barra della vita, fuori dai gruppi di gioco, morte
## recitata con una piccola rotazione a caso, sangue che sgorga e posa sul rilievo. Il numero di
## cadaveri è limitato da ClashFx.register_corpse().
func _become_corpse() -> void:
	if grid:
		grid.release(cell, self)
	if _tween:
		_tween.kill()
	is_moving = false
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true
	if _health_bar:
		_health_bar.queue_free()
		_health_bar = null
	for g in [&"units", &"troiani", &"achei"]:
		remove_from_group(g)
	var m := _model as CharacterModel
	var fall := 1.0
	if m:
		var variant := _pick_death_variant(m)
		fall = randf_range(0.88, 1.15)
		m.play_death(variant, fall)
		var yaw := m.rotation.y + randf_range(-0.25, 0.25)
		create_tween().tween_property(m, "rotation:y", yaw, 0.6).set_trans(Tween.TRANS_SINE)
		# Il corpo si posa sul rilievo durante la caduta stessa: niente scatto a fine animazione.
		ClashFx.settle_on_ground(self, m, 0.9 / fall, m.death_head_world())
	ClashFx.register_corpse(self)
	var tree := get_tree()
	tree.create_timer(0.6 / fall).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			ClashFx.corpse_blood(self, m))


## Come cade: colpito da davanti all'indietro, da dietro in avanti, di lato sul fianco (verso dove spinge
## il colpo). Senza direzione (fuoco, frecce) a caso.
func _pick_death_variant(m: CharacterModel) -> StringName:
	var hit := _last_hit_dir
	hit.y = 0.0
	if hit.length() < 0.05:
		return [&"death", &"death", &"death_front", &"death_side_r", &"death_side_l"].pick_random()
	hit = hit.normalized()
	var fwd := -m.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var d := hit.dot(fwd)
	if d < -0.5:
		return &"death"
	if d > 0.5:
		return &"death_front"
	# Di lato: la testa va dove spinge il colpo. Destra anatomica del soldato = fwd x up... (guarda -Z: destra = +X).
	var right := fwd.cross(Vector3.UP)
	return &"death_side_r" if hit.dot(right) > 0.0 else &"death_side_l"


## Cosa succede alla morte: di base l'unità sparisce (Ulisse la ridefinisce).
func _on_died() -> void:
	if grid:
		grid.release(cell, self)
	queue_free()


func face(direction: Vector2i) -> void:
	facing = direction
	if _model:
		# Il modello guarda verso -Z (convenzione Godot).
		_model.rotation.y = atan2(-direction.x, -direction.y)


func _can_swap_with(other: Node) -> bool:
	var unit := other as GridUnit
	return can_swap_with_allies and unit != null and unit != self \
		and unit.team == team and not unit.is_moving


## Scavalca l'ostacolo davanti: atterra due caselle più in là, con un arco.
func _vault(direction: Vector2i) -> void:
	var from := cell
	var landing := cell + direction * 2
	grid.release(from, self)
	grid.occupy(landing, self)
	cell = landing
	step_started.emit(from, landing)
	vaulted.emit(from, landing)
	is_moving = true
	if _tween:
		_tween.kill()
	var start := global_position
	var end := grid.cell_to_world(landing)
	var arc := vault_height
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		global_position = start.lerp(end, t) + Vector3.UP * (sin(t * PI) * arc),
		0.0, 1.0, vault_duration).set_trans(Tween.TRANS_SINE)
	_tween.finished.connect(_on_step_finished)
	if _model:
		# Si china in avanti durante il balzo.
		var lean := create_tween()
		var amount := -0.12 if _model is CharacterModel else -0.45   # i riggati si chinano con l'animazione
		lean.tween_property(_model, "rotation:x", amount, vault_duration * 0.4)
		lean.tween_property(_model, "rotation:x", 0.0, vault_duration * 0.6)


## Si arrampica sul blocco davanti e scende dall'altra parte (atterra due caselle più in là). Il corpo
## segue HumanoidAnims.climb_profile(), la stessa curva su cui è costruita la clip di arrampicata.
func _climb(direction: Vector2i) -> void:
	var from := cell
	var landing := cell + direction * 2
	var h := grid.obstacle_height(cell + direction)
	grid.release(from, self)
	grid.occupy(landing, self)
	cell = landing
	step_started.emit(from, landing)
	climbed.emit(from, landing, h)
	is_moving = true
	if _tween:
		_tween.kill()
	var start := global_position
	var end := grid.cell_to_world(landing)
	var flat := Vector3(end.x - start.x, 0.0, end.z - start.z)
	var y_end := end.y - start.y
	_tween = create_tween()
	_tween.tween_method(func(f: float) -> void:
		var p := HumanoidAnims.climb_profile(f, h, y_end)
		global_position = Vector3(start.x, start.y + p.y, start.z) + flat * p.x,
		0.0, 1.0, HumanoidAnims.CLIMB_TIME)
	_tween.finished.connect(_on_step_finished)


func _move_to(target: Vector2i) -> void:
	is_moving = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", grid.cell_to_world(target), step_duration)
	_tween.finished.connect(_on_step_finished)


func _on_step_finished() -> void:
	is_moving = false
	step_finished.emit(cell)


## Cerca un AnimationPlayer nel modello importato (es. i .glb di Blender
## con idle / walk / attack / hit / death). Le unità senza animazioni non
## fanno nulla di diverso.
func _setup_animation() -> void:
	if _model == null or _model is CharacterModel:
		return # CharacterModel pilota da sé le animazioni (anche morte e feriti a terra)
	var found := _model.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return
	_anim = found[0] as AnimationPlayer
	_anim.animation_finished.connect(_on_animation_finished)
	_play_loop(&"idle")


func _process(delta: float) -> void:
	if _anim == null or _hit_playing:
		return
	if is_moving:
		_still_time = 0.0
		_play_loop(&"walk", walk_anim_speed)
	else:
		_still_time += delta
		if _still_time >= idle_delay:
			_play_loop(&"idle")


func _play_loop(anim_name: StringName, speed := 1.0) -> void:
	if not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = speed
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.15)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"hit":
		_hit_playing = false
		_anim.speed_scale = 1.0
		_play_loop(&"walk" if is_moving else &"idle", walk_anim_speed if is_moving else 1.0)


func _exit_tree() -> void:
	if grid:
		grid.release(cell, self)
