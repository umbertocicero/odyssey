extends SceneTree
## Prova la scena salvata (level2.tscn con baked=true): stessi riferimenti, stesso aspetto.
## Avvio: godot --path . -s res://tests/screenshot_level2_baked.gd [-- --scene=res://scenes/levels/level2/level2.tscn]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_path := "res://scenes/levels/level2/level2.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_path = a.substr(8)
	var main: Node = load("res://scenes/main/main_level2.tscn").instantiate()
	var holder := main.get_node("GameView/GameViewport")
	var old := holder.get_node("Level2")
	holder.remove_child(old)
	old.free()
	var lvl: Node = (load(scene_path) as PackedScene).instantiate()
	lvl.name = "Level2"
	holder.add_child(lvl)
	root.add_child(main)
	for i in 80:
		await process_frame
	var w: Level2World = get_first_node_in_group(&"level2_world")
	print("baked=", w.baked, " ships=", w.ships.size(), " trees=", w.tree_nodes.size(), " all_trees=", w.all_trees.size(),
		" allies=", w.allies.size(), " carp=", w.carpenters.size(), " fires=", w.fires.size(), " horse=", w.horse != null,
		" blocked=", w.grid._blocked.size(), " player=", w.player.global_position)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/level2_baked_start.png"))
	w.set_horse_progress(1.0)
	w.camera._follow = null
	w.camera.target = w.horse.global_position
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screenshots/level2_baked_cavallo.png"))
	quit()
