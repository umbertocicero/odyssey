extends GridUnit
## Ulisse, controllato dal giocatore. Si muove di una casella alla volta;
## tenendo premuto il tasto continua a camminare.
##
## I comandi sono relativi alla camera: "su" sposta Ulisse verso l'alto dello
## schermo, lungo l'asse della griglia più vicino a quella direzione.
## Su mobile uno swipe fa un passo nella direzione dello swipe.
## Se un soldato acheo gli sbarra la strada, i due si scambiano di posto.

signal action_requested(action: StringName)

## Lunghezza minima di uno swipe, in pixel.
@export var swipe_min_distance := 40.0

var _touch_start := Vector2.ZERO
var _queued_swipe := Vector2.ZERO


func _ready() -> void:
	add_to_group(&"player")
	# Ulisse passa attraverso i suoi soldati scambiandosi di posto.
	can_swap_with_allies = true
	super._ready()
	if grid:
		grid.validate_connectivity(cell)


func _physics_process(_delta: float) -> void:
	for action: StringName in [&"attack", &"parry", &"dodge", &"interact", &"special"]:
		if Input.is_action_just_pressed(action):
			# Combattimento e interazioni non sono ancora implementati.
			action_requested.emit(action)

	if is_moving:
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input == Vector2.ZERO and _queued_swipe != Vector2.ZERO:
		input = _queued_swipe
	_queued_swipe = Vector2.ZERO
	if input != Vector2.ZERO:
		try_step(screen_to_grid_direction(input))


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_touch_start = touch.position
	else:
		var swipe := touch.position - _touch_start
		if swipe.length() >= swipe_min_distance:
			_queued_swipe = swipe.normalized()


## Converte una direzione sullo schermo (x a destra, y in basso) nell'asse
## della griglia che le somiglia di più, tenendo conto dell'orientamento della camera.
func screen_to_grid_direction(screen_direction: Vector2) -> Vector2i:
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	var camera := get_viewport().get_camera_3d()
	if camera:
		right = camera.global_basis.x
		forward = -camera.global_basis.z
	right = Vector3(right.x, 0.0, right.z).normalized()
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	var world := right * screen_direction.x - forward * screen_direction.y
	if absf(world.x) >= absf(world.z):
		return Vector2i(roundi(signf(world.x)), 0)
	return Vector2i(0, roundi(signf(world.z)))
