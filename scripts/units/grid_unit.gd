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
## poi passa il danno rimasto.
func take_melee(amount: int, attacker: Node3D) -> void:
	var m := _model as CharacterModel
	if m and health > 0:
		amount = m.defend(amount, attacker.global_position if attacker else global_position)
	if amount > 0:
		take_damage(amount)


## Toglie punti vita; a zero l'unità muore.
func take_damage(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_on_health_changed()
	if _model and not _model is CharacterModel:
		# Piccolo sussulto quando viene colpita (i personaggi riggati hanno l'animazione "hit").
		var tween := create_tween()
		tween.tween_property(_model, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
		tween.tween_property(_model, "scale", Vector3.ONE, 0.12)
	if health > 0 and _anim and _anim.has_animation(&"hit"):
		_hit_playing = true
		_anim.play(&"hit", 0.05)
	if health == 0:
		died.emit()
		_on_died()


func heal_full() -> void:
	health = max_health
	_on_health_changed()


func _on_health_changed() -> void:
	health_changed.emit(health, max_health)
	if _health_bar:
		_health_bar.set_ratio(float(health) / max_health)


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
