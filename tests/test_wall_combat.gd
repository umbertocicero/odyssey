extends SceneTree
## Test headless delle difese troiane sulle mura.
## Avvio: godot --headless --path . -s res://tests/test_wall_combat.gd
## Esce con codice 0 se tutti i controlli passano, 1 altrimenti.

const LEVEL_PATH := "res://scenes/levels/level1/level1.tscn"
const NEIGHBOURS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _failures := 0
var grid: DioramaGrid
var ulisse: GridUnit


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load(LEVEL_PATH).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	grid = get_first_node_in_group(&"diorama_grid")
	ulisse = get_first_node_in_group(&"player")
	var shooters := get_nodes_in_group(&"wall_shooters")
	_check(grid != null and ulisse != null, "griglia e Ulisse presenti")
	_check(shooters.size() == 15, "15 difese sulle mura (trovate %d)" % shooters.size())
	for s in shooters:
		s.auto_fire = false
		_check(s.profile != null, "%s ha un profilo d'arma" % s.name)
	var allies: Array = get_nodes_in_group(&"achei").filter(func(u): return u != ulisse)
	for ally in allies:
		ally.leader = null

	# 1. All'accampamento nessuno è a portata di tiro.
	var any_target := false
	for s in shooters:
		if s.pick_target() != null:
			any_target = true
	_check(not any_target, "all'accampamento nessun acheo è a portata delle mura")

	var archer: WallShooter = level.get_node("DifeseSulleMura/Arciere4")
	var fire_archer: WallShooter = level.get_node("DifeseSulleMura/ArciereFuoco1")
	var catapult: WallShooter = level.get_node("DifeseSulleMura/Catapulta")
	Engine.time_scale = 2.0

	# 2. Colpo diretto: chi resta sulla casella bersaglio perde vita.
	var target := _walkable_near(grid.world_to_cell(Vector3(archer.global_position.x, 0, -15.5)))
	_check(archer.is_in_range(target), "casella %s a portata dell'arciere" % [target])
	ulisse.place_at(target)
	var before := ulisse.health
	archer.fire_at(target)
	_check(get_nodes_in_group(&"target_markers").size() == 1, "avviso a terra sulla casella bersaglio")
	_check(get_nodes_in_group(&"projectiles").size() == 1, "proiettile in volo")
	await create_timer(archer.profile.warning_time + 0.3).timeout
	_check(ulisse.health == before - archer.profile.damage,
		"colpo diretto: vita %d -> %d (danno %d)" % [before, ulisse.health, archer.profile.damage])
	_check(get_nodes_in_group(&"target_markers").is_empty(), "l'avviso sparisce dopo l'impatto")

	# 3. Schivata: un passo fuori dalla casella prima dell'impatto.
	before = ulisse.health
	archer.fire_at(target)
	var stepped := false
	for d in NEIGHBOURS:
		if grid.is_walkable(target + d) and ulisse.try_step(d):
			stepped = true
			break
	await create_timer(archer.profile.warning_time + 0.3).timeout
	_check(stepped and ulisse.health == before, "schivata: nessun danno spostandosi (vita %d)" % ulisse.health)

	# 4. Freccia infiammata: la casella resta in fiamme e brucia chi ci entra.
	ulisse.heal_full()
	var fire_cell := _walkable_near(grid.world_to_cell(Vector3(fire_archer.global_position.x, 0, -16.5)))
	ulisse.place_at(_walkable_near(fire_cell + Vector2i(3, 0)))
	fire_archer.fire_at(fire_cell)
	await create_timer(fire_archer.profile.warning_time + 0.1).timeout
	_check(BurningCell.is_burning(fire_cell), "la freccia infiammata accende la casella %s" % [fire_cell])
	ulisse.place_at(fire_cell)
	before = ulisse.health
	await create_timer(2.2).timeout
	_check(ulisse.health <= before - fire_archer.profile.burn_damage_per_second,
		"il fuoco brucia chi ci sta sopra (vita %d -> %d)" % [before, ulisse.health])
	ulisse.place_at(_walkable_near(fire_cell + Vector2i(3, 0)))
	await create_timer(fire_archer.profile.burn_duration).timeout
	_check(not BurningCell.is_burning(fire_cell) and get_nodes_in_group(&"burning_cells").is_empty(),
		"il fuoco si spegne dopo %.1f s" % fire_archer.profile.burn_duration)

	# 5. Catapulta: area 3×3 e distanza minima.
	_check(catapult.affected_cells(Vector2i(10, 5)).size() == 9, "la catapulta colpisce un'area 3×3")
	var too_close := grid.world_to_cell(Vector3(catapult.global_position.x, 0, -19.5))
	_check(not catapult.is_in_range(too_close), "la catapulta non tira sotto la distanza minima")

	# 6. Tiro automatico quando un acheo entra nella gittata.
	ulisse.heal_full()
	ulisse.place_at(target)
	var precise: AttackProfile = archer.profile.duplicate()
	precise.miss_chance = 0.0
	archer.profile = precise
	archer.auto_fire = true
	before = ulisse.health
	await create_timer(precise.reload_time + precise.reload_jitter + precise.warning_time + 0.5).timeout
	archer.auto_fire = false
	_check(ulisse.health < before, "l'arciere tira da solo su Ulisse a portata (vita %d -> %d)" % [before, ulisse.health])
	await create_timer(precise.warning_time + 0.2).timeout

	# 7. Sconfitta: Ulisse riparte dall'accampamento, un soldato invece cade.
	ulisse.take_damage(1000)
	await create_timer((ulisse.get_node(^"Model") as CharacterModel).anim_length(&"death") + 1.0).timeout
	_check(ulisse.health == ulisse.max_health and is_instance_valid(ulisse), "Ulisse sconfitto torna con la vita piena")
	_check(ulisse.cell.distance_to(ulisse.spawn_cell) <= 5.0, "Ulisse riparte vicino all'accampamento (%s)" % [ulisse.cell])
	var ally: GridUnit = allies[0]
	var ally_cell := ally.cell
	ally.take_damage(1000)
	await process_frame
	_check(is_instance_valid(ally) and ally.is_in_group(&"corpses") and grid.get_occupant(ally_cell) == null,
		"il soldato caduto resta a terra come cadavere e libera la casella")

	Engine.time_scale = 1.0
	print("RISULTATO: ", "OK" if _failures == 0 else "%d controlli falliti" % _failures)
	quit(0 if _failures == 0 else 1)


## La casella libera più vicina a quella indicata (ricerca a spirale).
func _walkable_near(c: Vector2i) -> Vector2i:
	for radius in range(0, 8):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var n := c + Vector2i(dx, dy)
				if grid.is_walkable(n) or grid.get_occupant(n) == ulisse:
					return n
	return c


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		print("FAIL  ", label)
