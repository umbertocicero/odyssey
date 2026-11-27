class_name IdleFigure
extends Node3D
## Comparsa ferma (capi e ufficiali del campo): istanzia un personaggio riggato e ne gioca l'animazione
## di riposo. Non è una unità di gioco: niente collisioni né griglia. Da `min_quality` in su; a qualità
## bassa e media usa la versione leggera (`lod_path`), se c'è. Il modello si carica solo quando serve.

@export_file("*.gltf", "*.glb") var model_path := ""
@export_file("*.gltf", "*.glb") var lod_path := ""
@export_range(0, 2) var min_quality := 1
@export var idle_animation := &"idle"
## Nome mostrato (HUD, debug), in inglese.
@export var display_name := ""
## Arma in mano (UnitGear.weapon_*): percorso e tipo (0 spada, 1 lancia, 2 arco).
@export_file("*.gltf", "*.glb") var weapon_path := ""
@export_file("*.gltf", "*.glb") var weapon_lod_path := ""
@export_range(0, 2) var weapon_kind := 0
## Scudo agganciato all'avambraccio (come UnitGear.shield): percorso del modello (es. hoplon_chevron.gltf).
@export_file("*.gltf", "*.glb") var shield_path := ""
@export var weapon_bone := &""

## Piccolo andirivieni e rotazioni a intervalli casuali, così le sentinelle non stanno immobili.
@export var sway := false
@export_range(0.0, 1.0) var sway_distance := 0.35
@export_range(0.0, 30.0) var sway_yaw_degrees := 12.0

var instance: Node3D
var player: AnimationPlayer
var _idle := &"idle"
var _tween: Tween


func _ready() -> void:
	if int(Quality.current()) < min_quality or model_path == "":
		return
	var path := model_path
	if lod_path != "":
		path = lod_path
	var scene := load(path) as PackedScene
	if scene == null:
		return
	instance = scene.instantiate() as Node3D
	add_child(instance)
	if weapon_path != "" or shield_path != "":
		var gear := UnitGear.new()
		gear.min_quality = 0
		if shield_path != "":
			gear.shield = load(shield_path) as PackedScene
		gear.weapon_path = weapon_path
		gear.weapon_lod_path = weapon_lod_path
		gear.weapon_kind = weapon_kind as UnitGear.WeaponKind
		gear.weapon_bone = weapon_bone
		gear.shield_aligned = shield_path != ""
		add_child(gear)
	_setup_animation()


## Anima la figura con le clip procedurali (HumanoidAnims): riposo vivo, capo che parla, arciere che
## mira e tira (tende, scocca, prende una freccia dalla faretra, incocca, ritende).
func _setup_animation() -> void:
	var sk_list := instance.find_children("*", "Skeleton3D", true, false)
	var glb: AnimationPlayer = null
	for p in instance.find_children("*", "AnimationPlayer", true, false):
		glb = p
		break
	if sk_list.is_empty() or (sk_list[0] as Skeleton3D).find_bone("upperarm.L") < 0:
		if glb and glb.has_animation(idle_animation):
			glb.play(idle_animation)
		return
	if glb:
		glb.stop()
		glb.active = false
	var sk := sk_list[0] as Skeleton3D
	ArmHelpers.attach(sk)
	for m in instance.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).mesh = HandFist.fisted((m as MeshInstance3D).mesh, sk)
	var bow := weapon_path != "" and weapon_kind == 2
	var right := HumanoidAnims.Hand.NONE
	if weapon_path != "" and not bow:
		right = HumanoidAnims.Hand.SPEAR if weapon_kind == 1 else HumanoidAnims.Hand.SWORD
	var sets := PackedStringArray(["base", "bow" if bow else "leader"])
	var lib := HumanoidAnims.library(sk, right, shield_path != "" and not bow, bow, sets)
	player = AnimationPlayer.new()
	player.name = "HumanPlayer"
	sk.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(&"", lib)
	player.playback_default_blend_time = 0.25
	var idle := idle_animation
	if bow:
		idle = &"aim"
	if not lib.has_animation(idle):
		idle = &"idle"
	_idle = idle
	player.play(idle)
	# Ogni figura parte da un punto diverso del ciclo: niente comparse sincronizzate.
	player.seek(randf() * lib.get_animation(idle).length, true)
	player.animation_finished.connect(func(_n: StringName) -> void: player.play(_idle, 0.3))
	# Arciere: quando il WallShooter tira, scocca e ricarica.
	var shooter := get_parent().get_parent() if get_parent() else null
	if bow and shooter and shooter.has_signal(&"fired"):
		shooter.connect(&"fired", func(_c) -> void: player.play(&"shoot", 0.06))
