extends SceneTree
## Tavole di fotogrammi delle animazioni procedurali (HumanoidAnims), su un set vuoto con griglia a terra:
## per ogni clip N fotogrammi in fila, da più angolazioni. Nelle andature il personaggio avanza di
## passo x tempo: i piedi d'appoggio devono restare fermi sulla griglia (niente scivolamento).
## Avvio (con finestra, una Godot alla volta):
##   godot --path . -s res://tests/anim_sheet.gd -- --cfg=sword_shield --clips=walk,run --frames=8 --out=gait
## cfg: sword_shield, sword, spear, bow, bare. view: side, front, three, back (anche più di una: side+front).

const CELL := Vector2i(300, 380)

var _out := "anim_sheets"
var _cfg := "sword_shield"
var _clips := PackedStringArray(["idle", "walk", "run"])
var _frames := 8
var _views := PackedStringArray(["side", "three"])
var _extras: Array = []
var _focus := Vector3(0, 0.8, 0)
var _dist := 0.0
var _model_path := "res://assets/models/custom/personaggi_nuovi/ulisse/ulisse.gltf"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--cfg="):
			_cfg = arg.substr(6)
		elif arg.begins_with("--clips="):
			_clips = arg.substr(8).split(",")
		elif arg.begins_with("--frames="):
			_frames = int(arg.substr(9))
		elif arg.begins_with("--view="):
			_views = arg.substr(7).split("+")
		elif arg.begins_with("--focus="):
			var v := arg.substr(8).split(",")
			_focus = Vector3(float(v[0]), float(v[1]), float(v[2]))
		elif arg.begins_with("--dist="):
			_dist = float(arg.substr(7))
		elif arg.begins_with("--model="):
			_model_path = arg.substr(8)
	_run.call_deferred()


func _run() -> void:
	root.size = CELL
	var dir := "res://tests/screenshots/" + _out
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.66, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.72, 0.68)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color(0.36, 0.34, 0.3))
	for i in 256:
		for k in [0, 1, 128, 129]:
			img.set_pixel(i, k, Color(0.25, 0.22, 0.2))
			img.set_pixel(k, i, Color(0.25, 0.22, 0.2))
	gm.albedo_texture = ImageTexture.create_from_image(img)
	gm.uv1_scale = Vector3(16, 16, 1)     # una cella scura ogni 25 cm
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground.material_override = gm
	world.add_child(ground)
	var holder := Node3D.new()
	world.add_child(holder)
	var inst := (load(_model_path) as PackedScene).instantiate() as Node3D
	holder.add_child(inst)
	var gear := UnitGear.new()
	gear.min_quality = 0
	var right := HumanoidAnims.Hand.NONE
	var shield := false
	var bow := false
	var sets := PackedStringArray(["base"])
	match _cfg:
		"sword_shield":
			gear.shield = load("res://assets/models/custom/campo/equipaggiamento/hoplon_tridente/hoplon_tridente.gltf")
			gear.weapon_path = "res://assets/models/custom/armi/xiphos/xiphos.gltf"
			right = HumanoidAnims.Hand.SWORD
			shield = true
			sets.append("support")
		"sword":
			gear.weapon_path = "res://assets/models/custom/armi/xiphos/xiphos.gltf"
			right = HumanoidAnims.Hand.SWORD
			sets.append("support")
			sets.append("stretcher")
		"torch":
			gear.shield = load("res://assets/models/custom/campo/equipaggiamento/hoplon_tridente/hoplon_tridente.gltf")
			gear.weapon_path = "res://assets/models/custom/armi/xiphos/xiphos.gltf"
			right = HumanoidAnims.Hand.SWORD
			shield = true
			sets.append("torch")
		"spear":
			gear.weapon_path = "res://assets/models/custom/armi/lancia/lancia.gltf"
			gear.weapon_kind = UnitGear.WeaponKind.SPEAR
			right = HumanoidAnims.Hand.SPEAR
		"bow":
			gear.weapon_path = "res://assets/models/custom/armi/arco/arco.gltf"
			gear.weapon_kind = UnitGear.WeaponKind.BOW
			bow = true
			sets.append("bow")
		_:
			sets.append("limp")
			sets.append("drag")
			sets.append("leader")
			sets.append("stretcher")
	holder.add_child(gear)
	await process_frame
	await process_frame
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).mesh = HandFist.fisted((m as MeshInstance3D).mesh, sk)
	if _cfg == "torch":
		(gear.weapon_node if gear.weapon_node else Node3D.new()).visible = false
		var att := BoneAttachment3D.new()
		att.bone_name = "hand.L"
		sk.add_child(att)
		var tn := (load("res://assets/models/custom/campo/luci/torcia_achea/torcia_achea.gltf") as PackedScene).instantiate() as Node3D
		tn.transform = HumanoidAnims.hand_item_transform(sk, &"hand.L", 0)
		att.add_child(tn)
	for p in inst.find_children("*", "AnimationPlayer", true, false):
		(p as AnimationPlayer).stop()
		(p as AnimationPlayer).active = false
	var lib := HumanoidAnims.library(sk, right, shield, bow, sets)
	var ap := AnimationPlayer.new()
	sk.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library(&"", lib)
	var cam := Camera3D.new()
	cam.fov = 32.0
	world.add_child(cam)
	cam.current = true
	for clip in _clips:
		if not lib.has_animation(clip):
			print("manca ", clip)
			continue
		var a := lib.get_animation(clip)
		# Barella: la stanga dove la tiene il portatore (davanti a destra: barella dietro a destra).
		for c in holder.get_children():
			if c is Stretcher:
				c.queue_free()
		# Trascinamento: il ferito (e il secondo soccorritore) alle distanze di HumanoidAnims.DRAG_*.
		for extra in _extras:
			extra[0].queue_free()
		_extras.clear()
		if String(clip).begins_with("drag"):
			var axis_x := 0.0
			if String(clip).begins_with("drag_l"):
				axis_x = HumanoidAnims.DRAG_SIDE
				_extras.append(_figure(holder, Vector3(2.0 * HumanoidAnims.DRAG_SIDE, 0, 0), lib, StringName(String(clip).replace("drag_l", "drag_r"))))
			_extras.append(_figure(holder, Vector3(axis_x, 0, HumanoidAnims.DRAG_GAP), lib, &"dragged_walk" if String(clip).ends_with("walk") else &"dragged_idle"))
		if String(clip).begins_with("stretcher_"):
			var st := Stretcher.new()
			holder.add_child(st)
			st.position = Vector3((Stretcher.WIDTH * 0.5 + 0.258) * (-1.0 if String(clip).begins_with("stretcher_r") else 1.0), 0, -(Stretcher.POLE_LENGTH * 0.5 - 0.2))
		var climb_h := 0.0
		for c in world.get_children():
			if c.name == "ClimbBlock":
				c.queue_free()
		if String(clip).begins_with("climb_"):
			# Blocco da scalare: faccia a 0,5 m, profondo 1 m; il corpo segue climb_profile().
			climb_h = HumanoidAnims.CLIP_CLIMB_HEIGHTS[int(String(clip).substr(6))]
			var blk := MeshInstance3D.new()
			blk.name = "ClimbBlock"
			var bm := BoxMesh.new()
			bm.size = Vector3(1.2, climb_h, 1.0)
			blk.mesh = bm
			blk.position = Vector3(0, climb_h * 0.5, 1.0)
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.55, 0.42, 0.3, 0.35)
			bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			blk.material_override = bmat
			world.add_child(blk)
		var gait := String(clip).contains("walk") or String(clip).contains("run")
		var stride := HumanoidAnims.stride(clip)
		var sheet := Image.create(CELL.x * _frames, CELL.y * _views.size(), false, Image.FORMAT_RGB8)
		ap.play(clip)
		ap.pause()
		for vi in _views.size():
			for fi in _frames:
				var t := a.length * fi / float(_frames if a.loop_mode != Animation.LOOP_NONE else maxi(_frames - 1, 1))
				ap.seek(t, true)
				for extra in _extras:
					(extra[1] as AnimationPlayer).seek(fmod(t, (extra[1] as AnimationPlayer).current_animation_length), true)
				# Andature: il personaggio avanza nel mondo come nel gioco (velocità = passo / ciclo).
				var z := stride * (t - a.length * 0.5) if gait else 0.0
				holder.position = Vector3(0, 0, z)
				if climb_h > 0.0:
					var cp := HumanoidAnims.climb_profile(t / a.length, climb_h, 0.0)
					holder.position = Vector3(0, cp.y, cp.x * 2.0)
				var focus := _focus
				var dist := _dist if _dist > 0.0 else (4.4 if gait else 3.6)
				match _views[vi]:
					"side":
						cam.position = focus + Vector3(-dist, 0.25, 0.0)
					"front":
						cam.position = focus + Vector3(0.0, 0.3, dist)
					"back":
						cam.position = focus + Vector3(0.6, 0.6, -dist)
					_:
						cam.position = focus + Vector3(-dist * 0.62, 0.7, dist * 0.78)
				cam.look_at(focus, Vector3.UP)
				await process_frame
				await RenderingServer.frame_post_draw
				var shot := root.get_texture().get_image()
				shot.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(fi * CELL.x, vi * CELL.y))
		var file := "%s/%s_%s.png" % [dir, _cfg, clip]
		sheet.save_png(ProjectSettings.globalize_path(file))
		print("salvata ", file)
	quit()


func _figure(parent: Node3D, pos: Vector3, lib: AnimationLibrary, anim: StringName) -> Array:
	var inst := (load(_model_path) as PackedScene).instantiate() as Node3D
	parent.add_child(inst)
	inst.position = pos
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for p in inst.find_children("*", "AnimationPlayer", true, false):
		(p as AnimationPlayer).active = false
	var ap := AnimationPlayer.new()
	sk.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library(&"", lib)
	ap.play(anim)
	ap.pause()
	return [inst, ap]
