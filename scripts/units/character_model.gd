class_name CharacterModel
extends Node3D
## Modello 3D animato di un'unità (glb esportato da Blender con AnimationPlayer).
## Va messo come nodo "Model" di un GridUnit: l'unità lo ruota verso la
## direzione del passo, questo script istanzia il glb come figlio e pilota
## le animazioni idle, walk, attack, hit, death in base ai segnali dell'unità.

## Scena glb da istanziare.
@export var model_scene: PackedScene
## Scala uniforme del modello (1 = misure native, 1 m = 1 casella).
@export_range(0.2, 3.0) var model_scale := 1.0
## Rotazione aggiuntiva attorno a Y: serve se nel glb il "davanti" non è -Z.
@export_range(-180.0, 180.0) var yaw_offset_degrees := 0.0
## Durata della dissolvenza fra un'animazione e l'altra, in secondi.
@export var blend_time := 0.12
## Nomi delle animazioni nel glb.
@export var anim_idle := &"idle"
@export var anim_walk := &"walk"
@export var anim_attack := &"attack"
@export var anim_hit := &"hit"
@export var anim_death := &"death"
## Se vero, l'animazione di camminata segue la durata del passo.
@export var sync_walk_to_step := true

var instance: Node3D
var player: AnimationPlayer
var unit: GridUnit
var dead := false

var _busy_until := 0.0      # fino a quando un'animazione "una tantum" ha la precedenza
var _still_time := 0.0
var _last_health := -1


func _ready() -> void:
	unit = get_parent() as GridUnit
	if model_scene == null:
		return
	instance = model_scene.instantiate() as Node3D
	if instance == null:
		return
	instance.scale = Vector3.ONE * model_scale
	instance.rotation.y = deg_to_rad(yaw_offset_degrees)
	add_child(instance)
	var found := instance.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		player = found[0]
		player.playback_default_blend_time = blend_time
	for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_play(anim_idle)
	if unit:
		# Il _ready dell'unità (che imposta health) gira dopo quello dei figli.
		_last_health = unit.max_health
		unit.health_changed.connect(_on_health_changed)
		unit.died.connect(_on_died)
		if unit.has_signal(&"action_requested"):
			unit.connect(&"action_requested", _on_action)


func _process(delta: float) -> void:
	if player == null or dead or unit == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _busy_until:
		return
	if unit.is_moving:
		_still_time = 0.0
		_play(anim_walk)
		if sync_walk_to_step:
			player.speed_scale = 1.0
	else:
		_still_time += delta
		# Piccolo ritardo: fra un passo e il successivo non deve tornare in idle.
		if _still_time > 0.12:
			_play(anim_idle)


## Esegue l'attacco (animazione una tantum).
func play_attack() -> void:
	_one_shot(anim_attack)


## Avvia la morte e resta sull'ultimo fotogramma finché non si chiama revive().
func play_death() -> void:
	dead = true
	_busy_until = 0.0
	_play(anim_death, true)


## Rialza il modello dopo la morte (Ulisse riappare all'accampamento).
func revive() -> void:
	dead = false
	_still_time = 0.0
	_play(anim_idle, true)


## Lunghezza di un'animazione in secondi (0 se manca).
func anim_length(anim: StringName) -> float:
	if player and player.has_animation(anim):
		return player.get_animation(anim).length
	return 0.0


func current_animation() -> StringName:
	return player.current_animation if player else &""


func _one_shot(anim: StringName) -> void:
	if player == null or dead or not player.has_animation(anim):
		return
	_play(anim, true)
	_busy_until = Time.get_ticks_msec() / 1000.0 + player.get_animation(anim).length


func _play(anim: StringName, restart := false) -> void:
	if player == null or not player.has_animation(anim):
		return
	if player.current_animation == anim and player.is_playing() and not restart:
		return
	player.play(anim)


func _on_health_changed(current: int, _maximum: int) -> void:
	if current < _last_health and current > 0:
		_one_shot(anim_hit)
	_last_health = current


func _on_died() -> void:
	play_death()


func _on_action(action: StringName) -> void:
	if action == &"attack":
		play_attack()
