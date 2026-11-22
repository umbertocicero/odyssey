class_name WallShooter
extends Node3D
## Difensore troiano sulle mura (arciere o macchina da guerra). Quando un
## acheo (Ulisse o un soldato) è entro la gittata, tira sulla sua casella:
## a terra compare subito un avviso, il proiettile vola per warning_time
## secondi e colpisce chi si trova ancora nelle caselle bersaglio.

signal fired(target_cell: Vector2i)

## Arma usata: un file in data/combat/ (gittata, danno, ricarica...).
@export var profile: AttackProfile
## Modello della macchina (alta qualità) e versione leggera (bassa e media): si carica solo quello che serve.
@export_file("*.gltf", "*.glb") var model_path := ""
@export_file("*.gltf", "*.glb") var model_lod_path := ""
## Se disattivo tira solo quando glielo si chiede con fire_at() (test, eventi).
@export var auto_fire := true
## Altezza da cui parte il proiettile, sopra il nodo.
@export var muzzle_height := 1.2

## Moltiplicatori regolati dal livello a ogni ondata (1 = valori dell'arma).
var reload_scale := 1.0
var damage_scale := 1.0

var grid: DioramaGrid
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"wall_shooters")
	_load_model()
	_rng.randomize()
	grid = get_tree().get_first_node_in_group(&"diorama_grid") as DioramaGrid
	if profile:
		_cooldown = _rng.randf_range(0.5, profile.reload_time)


func _process(delta: float) -> void:
	if not auto_fire or profile == null or grid == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := pick_target()
	if target == null:
		_cooldown = 0.3
		return
	var cell := target.cell
	if _rng.randf() < profile.miss_chance:
		var offsets: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		cell += offsets[_rng.randi() % offsets.size()]
	fire_at(cell)


## Istanzia il modello giusto per la qualità sotto Model, davanti verso +Z (il tiratore lo gira verso il bersaglio).
func _load_model() -> void:
	var path := model_path if model_lod_path == "" else model_lod_path
	var model := get_node_or_null(^"Model") as Node3D
	if path == "" or model == null:
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var mesh := scene.instantiate() as Node3D
	mesh.name = "Mesh"
	mesh.rotation.y = PI   # i modelli sono esportati con il fronte verso -Z
	model.add_child(mesh)


## Punto da cui parte il proiettile.
func muzzle_position() -> Vector3:
	return global_position + Vector3.UP * muzzle_height


## Distanza in caselle tra il tiratore e il centro di una casella.
func distance_in_cells(cell: Vector2i) -> float:
	var p := grid.cell_to_world(cell)
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() / grid.cell_size


func is_in_range(cell: Vector2i) -> bool:
	var d := distance_in_cells(cell)
	return d <= profile.range_cells and d >= profile.min_range_cells


## L'acheo vivo più vicino entro la gittata, oppure null.
func pick_target() -> GridUnit:
	var best: GridUnit = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"achei"):
		var unit := node as GridUnit
		if unit == null or unit.health <= 0 or not is_in_range(unit.cell):
			continue
		if unit.has_method(&"is_targetable") and not unit.is_targetable():
			continue
		# Un ferito grave a terra sotto le mura non va colpito prima che la barella lo raggiunga.
		if unit is WoundedSoldier and (unit as WoundedSoldier).severe and (unit as WoundedSoldier).state == WoundedSoldier.State.LYING:
			continue
		# Il rilievo in mezzo può coprire il bersaglio: niente tiro.
		if not grid.has_line_of_fire(muzzle_position(), unit.global_position + Vector3.UP * 0.8):
			continue
		var d := distance_in_cells(unit.cell)
		if d < best_distance:
			best_distance = d
			best = unit
	return best


## Tira sulla casella indicata (e sull'area intorno, se l'arma ce l'ha).
func fire_at(cell: Vector2i) -> void:
	_cooldown = (profile.reload_time + _rng.randf() * profile.reload_jitter) / maxf(reload_scale, 0.1)
	var cells := affected_cells(cell)
	var target_world := grid.cell_to_world(cell)
	var model := get_node_or_null(^"Model") as Node3D
	if model:
		var d := target_world - global_position
		model.rotation.y = atan2(d.x, d.z)
	var fire := profile.burn_duration > 0.0
	for c in cells:
		if grid.is_inside(c):
			CombatFx.spawn_marker(grid, c, profile.warning_time, fire)
	var projectile := Projectile.new()
	projectile.setup(profile, muzzle_position(), target_world)
	grid.get_parent().add_child(projectile)
	projectile.arrived.connect(_on_impact.bind(cells))
	fired.emit(cell)


func affected_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var r := profile.area_radius
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			cells.append(center + Vector2i(dx, dy))
	return cells


func _on_impact(cells: Array[Vector2i]) -> void:
	if grid == null:
		return
	for c in cells:
		if not grid.is_inside(c):
			continue
		var unit := grid.get_occupant(c) as GridUnit
		if unit and unit.team == GridUnit.Team.ACHEI:
			unit.take_damage(roundi(profile.damage * damage_scale))
		if profile.burn_duration > 0.0 and not grid.is_blocked(c):
			BurningCell.ignite(grid, c, profile.burn_duration, profile.burn_damage_per_second)
