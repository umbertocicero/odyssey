class_name AllySoldier
extends GridUnit
## Soldato acheo alleato: per ora segue Ulisse restando a qualche casella di
## distanza. Qui andrà la logica di combattimento contro i troiani (state machine).

## Distanza (in caselle, Manhattan) oltre la quale il soldato si avvicina al leader.
@export var follow_distance := 2
## Pausa tra un passo e l'altro, in secondi.
@export var think_interval := 0.35

var leader: GridUnit
var _think_timer := 0.0


func _ready() -> void:
	super._ready()
	leader = get_tree().get_first_node_in_group(&"player") as GridUnit


func _physics_process(delta: float) -> void:
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
