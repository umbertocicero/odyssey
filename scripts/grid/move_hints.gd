class_name MoveHints
extends Node3D
## Evidenzia le caselle dove Ulisse può andare adesso: la griglia non si vede
## mai per intero, solo queste caselle accanto a lui (stile "diorama").

## Unità di cui mostrare le mosse possibili.
@export var unit_path: NodePath = ^"../Unita/Ulisse"
@export var color := Color(1.0, 0.86, 0.55, 0.22)
@export var show_hints := true:
	set(value):
		show_hints = value
		visible = value

const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _unit: GridUnit
var _tiles: Array[MeshInstance3D] = []


func _ready() -> void:
	_unit = get_node_or_null(unit_path) as GridUnit
	if _unit == null:
		return
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * 0.84
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	for i in DIRECTIONS.size():
		var tile := MeshInstance3D.new()
		tile.mesh = mesh
		tile.material_override = material
		tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tile.visible = false
		add_child(tile)
		_tiles.append(tile)
	_unit.step_started.connect(func(_from, _to): _hide_all())
	_unit.step_finished.connect(func(_cell): _refresh())
	visible = show_hints
	_refresh.call_deferred()


func _hide_all() -> void:
	for tile in _tiles:
		tile.visible = false


func _refresh() -> void:
	if _unit == null or not is_instance_valid(_unit) or _unit.grid == null:
		return
	for i in DIRECTIONS.size():
		var target := _unit.cell + DIRECTIONS[i]
		var ok := _unit.can_enter(target)
		var shown := target
		if not ok and _unit.can_vault and _unit.grid.can_vault_over(_unit.cell, DIRECTIONS[i]):
			# Ostacolo basso davanti: si mostra la casella dove si atterra scavalcando.
			ok = true
			shown = target + DIRECTIONS[i]
		_tiles[i].visible = ok
		if ok:
			_tiles[i].global_position = _unit.grid.cell_to_world(shown) + Vector3.UP * 0.025
