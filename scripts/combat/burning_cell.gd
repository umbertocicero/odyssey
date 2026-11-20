class_name BurningCell
extends Node3D
## Casella in fiamme lasciata da una freccia infiammata. Per burn_duration
## secondi fa danno, una volta al secondo, all'acheo che ci sta sopra.

static var _active: Dictionary = {} # Vector2i -> BurningCell

var grid: DioramaGrid
var cell := Vector2i.ZERO
var time_left := 0.0
var damage_per_second := 0
var _tick := 0.0
var _flames: Array[MeshInstance3D] = []


## Accende (o ravviva) il fuoco su una casella.
static func ignite(on_grid: DioramaGrid, at_cell: Vector2i, duration: float, dps: int) -> BurningCell:
	var existing = _active.get(at_cell)
	if existing != null and is_instance_valid(existing):
		existing.time_left = maxf(existing.time_left, duration)
		return existing
	var fire := BurningCell.new()
	fire.name = "Fuoco"
	fire.grid = on_grid
	fire.cell = at_cell
	fire.time_left = duration
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
	for offset: Vector3 in [Vector3(-0.2, 0, -0.15), Vector3(0.2, 0, 0.1), Vector3(0, 0, 0.25)]:
		var flame := MeshInstance3D.new()
		flame.mesh = CombatFx.flame_mesh()
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = offset + Vector3.UP * 0.3
		add_child(flame)
		_flames.append(flame)


func _process(delta: float) -> void:
	time_left -= delta
	var t := Time.get_ticks_msec() * 0.012
	for i in _flames.size():
		var s := 0.8 + 0.3 * sin(t + i * 2.1)
		_flames[i].scale = Vector3(s, s * 1.2, s)
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
	if _active.get(cell) == self:
		_active.erase(cell)
