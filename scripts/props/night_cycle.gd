class_name NightCycle
extends Node
## Dal tramonto alla notte (todo.md, sezione 4; STYLE.md "Notte"): legge LevelClock e muove il sole fino a
## spegnerlo, accende una luna piena fredda e fioca (senza ombre a low/medium, con ombre a high), scurisce
## cielo (sky_dusk: stelle e luna), ambiente e nebbia, fa crescere i fuochi e accende torce calde in mano
## ai soldati achei vicini al giocatore e luci sulle mura. Budget luci puntiformi: low 1, medium 5, high 9
## (più i fuochi del campo già presenti). Tutto si legge dall'orologio: nessuno stage visibile.

@export var enabled := true
@export var moon_energy := 0.22
@export var moon_color := Color(0.55, 0.65, 1.0)
@export var wall_light_range := 7.0

var level: Node3D
var clock: LevelClock
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_material: ShaderMaterial
var torch_lights: Array[OmniLight3D] = []
var wall_lights: Array[OmniLight3D] = []
var torch_count := 0

var _sun_energy0 := 0.95
var _fill_energy0 := 0.25
var _sun_color0 := Color(1, 0.7, 0.44)
var _heading := 0.0
var _ambient_energy0 := 0.85
var _ambient_color0 := Color(0.66, 0.5, 0.46)
var _fog_color0 := Color(0.96, 0.66, 0.48)
var _fog_density0 := 0.6
var _exposure0 := 0.9
var _timer := 0.0
var _grass_cards: GrassCards
var _grass_fields: Array[GrassField] = []

## Di notte l'erba perde il verde saturo: moltiplica R e B (più del verde) per avvicinarla al grigio-blu
## del terreno e della strada sotto la luna.
const NIGHT_GRASS_TINT := Color(1.0, 0.88, 1.5)


func _ready() -> void:
	if not enabled:
		return
	level = get_parent() as Node3D
	await get_tree().process_frame
	await get_tree().process_frame
	clock = get_tree().get_first_node_in_group(&"level_clock") as LevelClock
	sun = level.get_node_or_null(^"Sole") as DirectionalLight3D
	fill = level.get_node_or_null(^"Riempimento") as DirectionalLight3D
	var we := level.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if we:
		env = we.environment
	if clock == null or sun == null or env == null:
		return
	_sun_energy0 = sun.light_energy
	_sun_color0 = sun.light_color
	_heading = atan2(-sun.global_basis.z.x, -sun.global_basis.z.z)
	if fill:
		_fill_energy0 = fill.light_energy
	_ambient_energy0 = env.ambient_light_energy
	_ambient_color0 = env.ambient_light_color
	_fog_color0 = env.fog_light_color
	_fog_density0 = env.fog_density
	_exposure0 = env.tonemap_exposure
	if env.sky and env.sky.sky_material is ShaderMaterial:
		sky_material = env.sky.sky_material as ShaderMaterial
	_build_moon()
	_build_torches()
	_build_wall_lights()
	set_process(true)


func _build_moon() -> void:
	moon = DirectionalLight3D.new()
	moon.name = "Luna"
	moon.light_color = moon_color
	moon.light_energy = 0.0
	moon.shadow_enabled = Quality.current() == Quality.Level.HIGH
	moon.shadow_opacity = 0.5
	moon.directional_shadow_max_distance = 45.0
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	level.add_child(moon)
	moon.global_basis = Basis.looking_at(Vector3(0.45, -0.7, 0.55).normalized(), Vector3.UP)


func _build_torches() -> void:
	torch_count = [1, 5, 9][int(Quality.current())]
	for i in torch_count:
		var l := OmniLight3D.new()
		l.name = "TorciaSoldato%d" % (i + 1)
		l.light_color = Color(1.0, 0.62, 0.28)
		l.light_energy = 0.0
		l.omni_range = 5.5
		l.shadow_enabled = false
		l.visible = false
		level.add_child(l)
		torch_lights.append(l)


func _build_wall_lights() -> void:
	if Quality.current() == Quality.Level.LOW:
		return
	var n := 0
	for node in level.find_children("BrazierTorre*", "Node3D", true, false):
		if n >= [0, 3, 5][int(Quality.current())]:
			break
		var l := OmniLight3D.new()
		l.name = "LuceMura%d" % (n + 1)
		l.light_color = Color(1.0, 0.58, 0.25)
		l.light_energy = 0.0
		l.omni_range = wall_light_range
		l.shadow_enabled = false
		level.add_child(l)
		l.global_position = (node as Node3D).global_position + Vector3(0, 1.2, 0.8)
		wall_lights.append(l)
		n += 1


func _process(delta: float) -> void:
	if clock == null or env == null:
		return
	var t := clock.time_of_day
	var night := clock.night_amount()
	var dusk := smoothstep(17.5, 20.5, t)
	var rain := clock.rain
	var sun_factor := 1.0 - smoothstep(19.0, 20.8, t)
	# Sole: scende sotto l'orizzonte, si arrossa e si spegne.
	var elevation := lerpf(22.0, -6.0, dusk)
	var pitch := deg_to_rad(elevation)
	var dir := Vector3(cos(pitch) * sin(_heading), -sin(pitch), cos(pitch) * cos(_heading))
	sun.global_basis = Basis.looking_at(dir, Vector3.UP)
	sun.light_energy = _sun_energy0 * sun_factor * (1.0 - 0.45 * rain)
	sun.light_color = _sun_color0.lerp(Color(1.0, 0.4, 0.2), dusk * 0.8)
	sun.visible = sun.light_energy > 0.01
	if fill:
		fill.light_energy = _fill_energy0 * lerpf(1.0, 0.25, night)
	# Luna: fredda e fioca, senza ombre a low/medium.
	var moon_visible := night * (1.0 - 0.5 * rain)
	moon.light_energy = moon_energy * moon_visible * (1.4 if Quality.current() == Quality.Level.HIGH else 1.0)
	moon.visible = moon.light_energy > 0.005
	# Ambiente, nebbia, esposizione.
	env.ambient_light_color = _ambient_color0.lerp(Color(0.2, 0.26, 0.46), night)
	env.ambient_light_energy = _ambient_energy0 * lerpf(1.0, 0.7, night) * (1.0 - 0.25 * rain)
	env.fog_light_color = _fog_color0.lerp(Color(0.1, 0.14, 0.26), night).lerp(Color(0.5, 0.52, 0.56), rain * 0.5)
	env.fog_density = _fog_density0 * (1.0 + 0.9 * rain)
	env.tonemap_exposure = lerpf(_exposure0, 1.05, night)
	if _grass_cards == null:
		_grass_cards = level.get_node_or_null(^"ErbaFotorealistica") as GrassCards
	if _grass_fields.is_empty():
		for n in level.get_children():
			if n is GrassField:
				_grass_fields.append(n)
	for g in _grass_fields:
		g.set_night(night)
	if _grass_cards and _grass_cards.material:
		_grass_cards.material.set_shader_parameter(&"tint", Color(1, 1, 1).lerp(NIGHT_GRASS_TINT, night))
	if sky_material:
		sky_material.set_shader_parameter(&"night", night)
		sky_material.set_shader_parameter(&"rain_amount", rain)
		sky_material.set_shader_parameter(&"moon_dir", -moon.global_basis.z)
		sky_material.set_shader_parameter(&"sun_dir", -dir)
	# Fuochi: crescono al buio.
	var atmo := level.get_node_or_null(^"Atmosfera") as LevelAtmosphere
	if atmo:
		atmo.fire_boost = 1.0 + 0.9 * night
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.4
		_update_torches(night)
	for i in torch_lights.size():
		var l := torch_lights[i]
		if l.visible and i < _carriers.size() and is_instance_valid(_carriers[i]):
			var unit := _carriers[i]
			var hand := _hand_torches.get(unit) as Node3D
			l.global_position = hand.global_position + Vector3(0, 0.45, 0) if hand != null and hand.visible else unit.global_position + Vector3(0.35, 1.25, 0.25)
		if l.visible:
			l.light_energy = lerpf(l.light_energy, 0.95 * TorchFlame.flicker(Time.get_ticks_msec(), float(l.get_instance_id() % 97)) * night * 1.6, minf(1.0, 14.0 * delta))
	for l in wall_lights:
		l.light_energy = night * 1.1 * TorchFlame.flicker(Time.get_ticks_msec(), float(l.get_instance_id() % 89))


var _carriers: Array[Node3D] = []
var _hand_torches := {}   # unità -> nodo della torcia in mano (BoneAttachment3D su hand.L)

const TORCH_PATH := "res://assets/models/custom/campo/luci/torcia_achea/torcia_achea.gltf"


## Torcia in mano (hand.L) con la fiamma emissiva del modello: solo a media e alta qualità, solo di notte.
func _hand_torch_for(unit: Node3D) -> Node3D:
	if Quality.current() == Quality.Level.LOW:
		return null
	if _hand_torches.has(unit):
		return _hand_torches[unit]
	var skeleton: Skeleton3D = null
	var found := unit.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		skeleton = found[0]
	if skeleton == null or skeleton.find_bone("hand.L") < 0:
		_hand_torches[unit] = null
		return null
	var scene := load(TORCH_PATH) as PackedScene
	if scene == null:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "TorciaInMano"
	attachment.bone_name = "hand.L"
	skeleton.add_child(attachment)
	var torch := scene.instantiate() as Node3D
	# Impugnatura nel palmo, fiamma in alto (stessa presa dell'arma: HumanoidAnims.hand_item_transform);
	# l'origine del modello è il punto di presa. Il braccio la regge dritta grazie a CharacterModel.set_torch,
	# che si accorge da solo del nodo "TorciaInMano" visibile.
	torch.transform = HumanoidAnims.hand_item_transform(skeleton, &"hand.L", 0)
	attachment.add_child(torch)
	_replace_static_flame(torch)
	TorchFlame.attach(torch, Vector3(0.0, 0.25, 0.0), 0.4, 0.28)
	attachment.visible = false
	_hand_torches[unit] = attachment
	return attachment


## Le torce stanno sui soldati achei più vicini al giocatore (e su Ulisse): le luci vanno ai primi `torch_count`.
func _update_torches(night: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or night < 0.05:
		for l in torch_lights:
			l.visible = false
			l.light_energy = 0.0
		for k in _hand_torches.keys():
			if is_instance_valid(k) and _hand_torches[k] != null:
				(_hand_torches[k] as Node3D).visible = false
		return
	var carriers: Array[Node3D] = [player]
	var allies := get_tree().get_nodes_in_group(&"achei").filter(func(n): return n != player and n is Node3D and (n as GridUnit).health > 0 and not n is WoundedSoldier)
	allies.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	for a in allies:
		carriers.append(a)
	for k in _hand_torches.keys():
		if is_instance_valid(k) and _hand_torches[k] != null and not carriers.has(k):
			(_hand_torches[k] as Node3D).visible = false
	_carriers = carriers
	for i in torch_lights.size():
		var l := torch_lights[i]
		if i < carriers.size():
			l.visible = true
			var hand_torch := _hand_torch_for(carriers[i])
			if hand_torch != null:
				hand_torch.visible = true
		else:
			l.visible = false
			l.light_energy = 0.0


## Toglie la fiamma statica del modello (materiale M_flame): la sostituisce TorchFlame, animata.
func _replace_static_flame(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh != null:
			inst.mesh = FoliageTint.without_materials(inst.mesh, PackedStringArray(["M_flame"]))
