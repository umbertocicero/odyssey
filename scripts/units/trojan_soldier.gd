class_name TrojanSoldier
extends GridUnit
## Soldato troiano che esce dalle mura: avanza verso l'acheo più vicino e,
## quando gli è accanto, lo colpisce con la spada.

@export var attack_damage := 8
@export var attack_interval := 1.3
@export var think_interval := 0.3

var kills_credit := true
var _think := 0.0
var _attack_cd := 0.0
var _halted := false
var _model_node: CharacterModel


func _ready() -> void:
	step_duration += think_interval   # passi concatenati, vedi AllySoldier
	super._ready()
	_model_node = get_node_or_null(^"Model") as CharacterModel
	_think = randf_range(0.0, think_interval)


const MAX_CORPSES := 40


func halt() -> void:
	_halted = true


func _physics_process(delta: float) -> void:
	if _halted or health <= 0:
		return
	_attack_cd -= delta
	_think -= delta
	if is_moving:
		return
	if _think > 0.0:
		return
	_think = think_interval
	var target := _nearest_target()
	if target == null:
		return
	var diff := target.cell - cell
	if absi(diff.x) + absi(diff.y) == 1:
		face(diff)
		if _attack_cd <= 0.0:
			_attack_cd = attack_interval
			if _model_node:
				_model_node.play_attack()
			target.take_melee(attack_damage, self)
		return
	var primary := Vector2i(signi(diff.x), 0) if absi(diff.x) >= absi(diff.y) else Vector2i(0, signi(diff.y))
	var secondary := Vector2i(0, signi(diff.y)) if primary.x != 0 else Vector2i(signi(diff.x), 0)
	if try_step(primary):
		return
	if secondary != Vector2i.ZERO and try_step(secondary):
		return
	# Strada sbarrata: un passo di lato a caso per aggirare l'ostacolo.
	var sides: Array[Vector2i] = [Vector2i(primary.y, primary.x), Vector2i(-primary.y, -primary.x)]
	sides.shuffle()
	for s in sides:
		if try_step(s):
			return


func _nearest_target() -> GridUnit:
	var best: GridUnit = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"achei"):
		var u := node as GridUnit
		if u == null or u.health <= 0:
			continue
		if u.has_method(&"is_targetable") and not u.is_targetable():
			continue
		var d := absi(u.cell.x - cell.x) + absi(u.cell.y - cell.y)
		if d < best_d:
			best_d = d
			best = u
	return best


func _on_died() -> void:
	_halted = true
	if grid:
		grid.release(cell, self)
	if _tween:
		_tween.kill()
	is_moving = false
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true
	if _model_node:
		_model_node.play_death()
	remove_from_group(&"units")
	remove_from_group(&"troiani")
	# Il caduto resta a terra (senza collisioni): se ce ne sono troppi, sparisce il più vecchio.
	add_to_group(&"corpses")
	var corpses := get_tree().get_nodes_in_group(&"corpses")
	if corpses.size() > MAX_CORPSES:
		(corpses[0] as Node).queue_free()
