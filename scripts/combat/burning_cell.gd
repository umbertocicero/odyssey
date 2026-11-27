class_name BurningCell
extends Node3D
## Casella in fiamme lasciata da una freccia infiammata. Per burn_duration
## secondi fa danno, una volta al secondo, all'acheo che ci sta sopra.

static var _active: Dictionary = {} # Vector2i -> BurningCell

var grid: DioramaGrid
var cell := Vector2i.ZERO
var time_left := 0.0
var _total := 1.0
var damage_per_second := 0
var _tick := 0.0
var _flames: Array[Node3D] = []
var _light: OmniLight3D
var _seed := 0.0


## Accende (o ravviva) il fuoco su una casella.
static func ignite(on_grid: DioramaGrid, at_cell: Vector2i, duration: float, dps: int) -> BurningCell:
	var existing = _active.get(at_cell)
	if existing != null and is_instance_valid(existing):
		existing.time_left = maxf(existing.time_left, duration)
		existing._total = maxf(existing._total, duration)
		return existing
	var fire := BurningCell.new()
	fire.name = "Fuoco"
	fire.grid = on_grid
	fire.cell = at_cell
	fire.time_left = duration
	fire._total = duration
	fire.damage_per_second = dps
	on_grid.get_parent().add_child(fire)
	_active[at_cell] = fire
	return fire


static func is_burning(at_cell: Vector2i) -> bool:
	var existing = _active.get(at_cell)
	return existing != null and is_instance_valid(existing)


func _ready() -> void:
	add_to_group(&"burning_cells")
	global_position = grid.cell_to_world(cell)
	grid.set_fire(cell, true)
	# Stessa fiamma animata delle torce (shader procedurale + braci + fumo), tre lingue sparse sulla casella.
	for offset: Vector3 in [Vector3(-0.2, 0, -0.15), Vector3(0.22, 0, 0.1), Vector3(0, 0, 0.25)]:
		_flames.append(TorchFlame.attach(self, offset, 0.85, 0.34))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = 4.0
	_light.light_energy = 1.6
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.6, 0)
	add_child(_light)
	_seed = randf() * 50.0
	# Freccia conficcata a terra, inclinata, con la fiamma sulla punta.
	var arrow := MeshInstance3D.new()
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.04, 0.04, 0.7)
	arrow.mesh = shaft
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.1, 0.06)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 0.25
	arrow.material_override = mat
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.position = Vector3(0, 0.22, 0)
	arrow.rotation = Vector3(deg_to_rad(-60), deg_to_rad(randf() * 360.0), 0)
	add_child(arrow)


func _process(delta: float) -> void:
	time_left -= delta
	var t := Time.get_ticks_msec() * 0.012
	# Si spegne gradualmente nell'ultimo quarto della durata.
	var fade := clampf(time_left / (_total * 0.25), 0.05, 1.0)
	for i in _flames.size():
		var sc := (0.9 + 0.1 * sin(t + i * 2.1)) * fade
		_flames[i].scale = Vector3(sc, sc, sc)
	if _light:
		_light.light_energy = 1.6 * fade * TorchFlame.flicker(Time.get_ticks_msec(), _seed)
	_tick += delta
	if _tick >= 1.0:
		_tick -= 1.0
		var unit := grid.get_occupant(cell) as GridUnit
		if unit and unit.team == GridUnit.Team.ACHEI:
			unit.take_damage(damage_per_second)
	if time_left <= 0.0:
		if _active.get(cell) == self:
			_active.erase(cell)
		queue_free()


func _exit_tree() -> void:
	if grid and _active.get(cell) == self:
		grid.set_fire(cell, false)
	if _active.get(cell) == self:
		_active.erase(cell)
