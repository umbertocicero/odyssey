class_name GameAudio
extends RefCounted
## Audio del gioco: bus separati (Master, Music, SFX, Ambience) creati al primo uso e un pool piccolo
## di AudioStreamPlayer3D per gli effetti posizionali. Nessun autoload: tutto vive in un nodo creato
## sotto la radice della scena al primo suono. Pochi voci simultanee (MAX_VOICES) per la GTX 860M;
## oltre il tetto il suono più lontano dalla camera non parte.

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_AMBIENCE := &"Ambience"
const MAX_VOICES := 6
const MAX_DISTANCE := 40.0
const SFX_DIR := "res://assets/audio/sfx/level2/"

const CLASHES: Array[String] = [
	"res://assets/audio/sfx/combat/sword_clash_heavy.mp3",
	"res://assets/audio/sfx/combat/sword_clash_b.mp3",
]
const SLASH_KILL := "res://assets/audio/sfx/combat/sword_slash_kill_grunt.wav"

const SWINGS: Array[String] = [
	"res://assets/audio/sfx/combat/sword_swing_a.mp3",
	"res://assets/audio/sfx/combat/sword_swing_b.mp3",
	"res://assets/audio/sfx/combat/sword_swing_c.mp3",
]
const HITS: Array[String] = [
	"res://assets/audio/sfx/combat/katana_hit.mp3",
	"res://assets/audio/sfx/combat/sword_slice_hit_b.mp3",
]
const DRAWS: Array[String] = [
	"res://assets/audio/sfx/combat/sword_draw.mp3",
	"res://assets/audio/sfx/combat/sword_draw_b.mp3",
]

static var enabled := true
static var _root: Node
static var _voices: Array[AudioStreamPlayer3D] = []
static var _cache: Dictionary = {}
static var _next := 0


## Crea i bus mancanti (idempotente). Si può chiamare all'avvio o lasciare che lo faccia il primo suono.
static func setup_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, &"Master")


## Volume lineare 0..1 di un bus ("Master", "Music", "SFX", "Ambience").
static func set_volume(bus_name: StringName, linear: float) -> void:
	setup_buses()
	var i := AudioServer.get_bus_index(bus_name)
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(linear, 0.0, 1.0)))


static func get_volume(bus_name: StringName) -> float:
	var i := AudioServer.get_bus_index(bus_name)
	return db_to_linear(AudioServer.get_bus_volume_db(i)) if i != -1 else 1.0


## Suono posizionale in `pos` (mondo). `anchor` è un nodo qualsiasi nell'albero.
static func play_3d(anchor: Node, path: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	if not enabled or anchor == null or not anchor.is_inside_tree():
		return
	var cam := anchor.get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > MAX_DISTANCE:
		return
	if not _ensure(anchor):
		return
	var stream := _load(path)
	if stream == null:
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


static func clash(anchor: Node, pos: Vector3) -> void:
	play_3d(anchor, CLASHES[randi() % CLASHES.size()], pos, -4.0)


## Fendente che uccide (con grugnito).
static func slash_kill(anchor: Node, pos: Vector3) -> void:
	play_3d(anchor, SLASH_KILL, pos, -2.0)


## Fendente a vuoto (inizio dell'attacco), una variante a caso.
static func swing(anchor: Node, pos: Vector3) -> void:
	play_3d(anchor, SWINGS[randi() % SWINGS.size()], pos, -6.0, 0.1)


## Colpo a segno non mortale.
static func hit(anchor: Node, pos: Vector3) -> void:
	play_3d(anchor, HITS[randi() % HITS.size()], pos, -3.0)


## Spada sguainata (la prima volta che un'unità attacca).
static func draw(anchor: Node, pos: Vector3) -> void:
	play_3d(anchor, DRAWS[randi() % DRAWS.size()], pos, -6.0)


## Effetto del livello 2 (o altro) in `pos`: stessa catena di play_3d con un volume proprio.
static func sfx(anchor: Node, name: String, pos: Vector3, volume_db := 0.0) -> void:
	play_3d(anchor, SFX_DIR + name + ".mp3", pos, volume_db, 0.05)


## Suono ambientale in loop (ruscello, onde, bosco), posizionale, sul bus Ambience.
## Ritorna il player: `queue_free()` lo ferma. Non conta nel tetto delle voci.
static func ambient_loop(parent: Node3D, name: String, pos: Vector3, volume_db := -6.0, max_distance := 30.0) -> AudioStreamPlayer3D:
	setup_buses()
	var stream := _load(SFX_DIR + name + ".mp3")
	if stream == null:
		return null
	stream = stream.duplicate()
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	var p := AudioStreamPlayer3D.new()
	p.name = "Amb_" + name
	p.stream = stream
	p.bus = BUS_AMBIENCE
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 10.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(p)
	p.global_position = pos
	p.play()
	return p


static func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func _ensure(anchor: Node) -> bool:
	if is_instance_valid(_root) and _root.is_inside_tree():
		return true
	setup_buses()
	_voices.clear()
	_root = Node.new()
	_root.name = "GameAudio"
	anchor.get_tree().root.add_child(_root)
	for i in MAX_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = BUS_SFX
		p.max_distance = MAX_DISTANCE
		p.unit_size = 8.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_root.add_child(p)
		_voices.append(p)
	return true
