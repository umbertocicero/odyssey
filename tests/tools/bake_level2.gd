extends SceneTree
## Salva il mondo del livello 2 (costruito da codice da Level2World) come nodi in una scena, cosi' si vede e si modifica
## nell'editor. Sovrascrive level2.tscn (chiudere prima l editor Godot, o passare --out= per scrivere altrove).
## Avvio (con l'editor CHIUSO se si sovrascrive level2.tscn):
##   godot --headless --path . -s res://tests/tools/bake_level2.gd [-- --out=res://scenes/levels/level2/level2.tscn]
## Scrive anche in assets/models/custom/livello2/: level2_splat.png, level2_mask.png, level2_far_splat.png,
## level2_terreno.res, level2_ruscello.res (mesh generate, troppo pesanti per stare dentro il .tscn).
## Non salva: i nodi che creano da soli gli altri script (SeaWater, BlockSides, DioramaGrid, audio) e l'interno dei
## modelli istanziati: si rigenerano all'avvio.

const DEFAULT_OUT := "res://scenes/levels/level2/level2.tscn"
const NO_DESCEND := ["SeaWater", "BlockSides", "DioramaGrid", "FixedCamera", "SeaFall"]

var _counter := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := DEFAULT_OUT
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var world := Level2World.new()
	world.name = "Level2"
	root.add_child(world)
	for i in 20:
		await process_frame
	world.export_bake_assets()
	# stato da non salvare
	world.ground_mesh.material_override = null
	(world.get_node("PianuraLontana") as MeshInstance3D).material_override = null
	world.sea.material_override = null
	# caselle bloccate dagli oggetti statici
	var cells := PackedVector2Array()
	for key in world.grid._blocked.keys():
		cells.append(Vector2(key.x, key.y))
	world.blocked_cells = cells
	world.baked = true
	_rename(world)
	_own(world, world)
	var scene := PackedScene.new()
	var err := scene.pack(world)
	if err != OK:
		push_error("bake_level2: pack ha dato errore %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(scene, out)
	print("bake_level2: salvata ", out, " err=", err, " caselle bloccate=", cells.size())
	quit(0 if err == OK else 1)


func _rename(n: Node) -> void:
	for c in n.get_children():
		if String(c.name).contains("@"):
			_counter += 1
			c.name = "%s%d" % [c.get_class(), _counter]
		if c.scene_file_path != "":
			continue
		_rename(c)


func _own(n: Node, scene_root: Node) -> void:
	for c in n.get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer3D or c is SeaFall:
			continue
		c.owner = scene_root
		if c.scene_file_path != "":
			continue
		var script := c.get_script() as Script
		if script and NO_DESCEND.has(script.get_global_name()):
			continue
		_own(c, scene_root)
