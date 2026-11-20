class_name AllySoldier
extends GridUnit
## Soldato acheo alleato: per ora segue Ulisse restando a qualche casella di
## distanza. Qui andrà la logica di combattimento contro i troiani (state machine).

## Distanza (in caselle, Manhattan) oltre la quale il soldato si avvicina al leader.
@export var follow_distance := 2
## Pausa tra un passo e l'altro, in secondi.
@export var think_interval := 0.35

var leader: GridUnit
@export var attack_damage := 12
@export var attack_cooldown := 1.0

var _think_timer := 0.0
var _attack_cd := 0.0


func _ready() -> void:
	super._ready()
	leader = get_tree().get_first_node_in_group(&"player") as GridUnit


func _physics_process(delta: float) -> void:
	_attack_cd -= delta
	if _fight():
		return
	if leader == null or is_moving:
		return
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = think_interval

	var diff := leader.cell - cell
	if absi(diff.x) + absi(diff.y) <= follow_distance:
		return
	# Prova prima l'asse con la distanza maggiore, poi l'altro.
	var primary := Vector2i(signi(diff.x), 0) if absi(diff.x) >= absi(diff.y) else Vector2i(0, signi(diff.y))
	var secondary := Vector2i(0, signi(diff.y)) if primary.x != 0 else Vector2i(signi(diff.x), 0)
	if not try_step(primary) and secondary != Vector2i.ZERO:
		try_step(secondary)


## Se un troiano è accanto, lo colpisce (e non si muove). True se ha combattuto.
func _fight() -> bool:
	if grid == null or is_moving or health <= 0:
		return false
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var unit := grid.get_occupant(cell + d) as GridUnit
		if unit and unit.team == GridUnit.Team.TROIANI and unit.health > 0:
			face(d)
			if _attack_cd <= 0.0:
				_attack_cd = attack_cooldown
				var m := get_node_or_null(^"Model") as CharacterModel
				if m:
					m.play_attack()
				unit.take_damage(attack_damage)
			return true
	return false
