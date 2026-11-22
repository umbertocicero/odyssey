class_name GrassCards
extends Node3D
## Prato fotorealistico: ciuffi d'erba a cards alpha-cutout (erba_ciuffi.gltf)
## sparsi con GPU instancing. Un MultiMeshInstance3D per ogni variante e per
## ogni blocco di `block_size` metri, così Godot scarta i blocchi fuori
## dall'inquadratura. Dove crescono lo decidono le maschere del terreno
## (T_terreno_maschere: densità e secchezza; T_terreno_maschere2: altezza e
## chiazze di colore) e GrassMask (gruppi grass_ground / grass_exclude e
## caselle solide), come per GrassField. Il numero di ciuffi segue
## Quality.grass_budget(). I personaggi, i proiettili e il fuoco piegano i fili
## (stesse sorgenti di GrassField), tramite una mappa di calpestio 128x128 che
## lo shader campiona una volta per vertice. Attivo solo con TerrainStyle.photo().
## Uniformità: le maschere decidono solo dove c'è prato (sentieri, roccia,
## bordi), la densità dentro il prato è costante e i ciuffi stanno su una
## griglia jitterata; altezza e colore variano poco e a grana fine.

const MODEL := preload("res://assets/models/custom/terreno/erba_ciuffi.gltf")
const SHADER := preload("res://assets/shaders/grass_cards.gdshader")
const TEX_DIR := "res://assets/models/custom/terreno/textures/"
## Risoluzione della mappa di calpestio (texel sul lato di map_size: 128 = 0.4 m).
const TRAMPLE_RES := 128

## Pesi suggeriti dal README del terreno. R = altezza macro dell'erba (0..1).
const GREEN := {
	"Erba_Alta": 3.0, "Erba_Media": 4.0, "Erba_Bassa": 3.0, "Prato_Denso_A": 5.0,
	"Prato_Denso_C": 5.0, "Erbacce_Foglie": 0.7, "Fiori_Selvatici": 0.6,
}
const DRY := {
	"Erba_PunteSecche": 4.0, "Erba_Secca": 3.0, "Prato_Denso_B": 5.0, "Erba_Media": 2.0,
	"Graminacee_Semi": 0.7,
}
## Varianti ammesse a qualità bassa: poche mesh = pochi disegni.
const LOW_VARIANTS := ["Prato_Denso_A", "Prato_Denso_B", "Prato_Denso_C", "Erba_Media", "Prato_Alto", "Erba_Lunga"]

@export var enabled := true
## Angolo nord-ovest e dimensioni dell'area delle maschere (come TerrainRelief).
@export var origin := Vector2(-26, -30)
@export var map_size := Vector2(52, 52)
## Lato dei blocchi di culling (m): x2 a qualità media, x4 a bassa (meno MultiMesh = meno draw call).
@export_range(2.0, 32.0) var block_size := 8.0
## Moltiplicatore del budget di ciuffi (1 = Quality.grass_budget()).
@export_range(0.1, 4.0) var density_scale := 1.0
@export var random_seed := 5
## Larghezza della fascia in cui l'erba sfuma verso sabbia, sentieri e costruzioni (m).
@export_range(0.05, 3.0) var mask_fade := 0.5
## Rientro della radura sui lati liberi delle caselle solide (alberi, casse, pali):
## l'erba arriva fin quasi all'oggetto invece di lasciare un quadrato rasato.
@export_range(0.0, 0.45) var solid_inset := 0.3
## Tinta dei ciuffi verdi e secchi (moltiplica l'atlas, che è già verde naturale:
## valori vicini a 1, altrimenti col sole basso il prato vira all'arancione).
@export var tint := Color(1.0, 0.98, 0.8)
@export var dry_tint := Color(1.12, 1.0, 0.62)
## Quota dei ciuffi secchi sul totale (la maschera dà la secchezza, qui la si riduce: verdi freschi con punte secche).
@export_range(0.0, 1.0) var dry_share := 0.6
## Quanto le chiazze di colore della maschera (T_terreno_maschere2.G) ingialliscono il prato.
@export_range(0.0, 1.0) var colour_patches := 0.12
## Quanto l'altezza macro della maschera (T_terreno_maschere2.R) cambia l'altezza (0 = tutto uguale).
@export_range(0.0, 1.0) var macro_height := 0.3
## Scala comune dei ciuffi.
@export_range(0.4, 2.0) var tuft_scale := 1.0
## Soglie del canale B (densità) di T_terreno_maschere: sotto path_low niente erba
## (sentieri, terra battuta), sopra path_high prato pieno.
@export_range(0.0, 1.0) var path_low := 0.08
@export_range(0.0, 1.0) var path_high := 0.3

@export_group("LOD")
## Oltre lod_start metri dalla camera resta una quota decrescente di ciuffi, fino
## a lod_keep a lod_end; i rimasti si allargano per coprire lo stesso prato.
## Lato CPU (visible_instance_count per blocco) e lato shader (per ciuffo).
@export var lod_start := 12.0
@export var lod_end := 36.0
@export_range(0.05, 1.0) var lod_keep := 0.3

@export_group("Vento")
@export var wind_direction := Vector2(1.0, 0.3)
@export_range(0.0, 0.6) var wind_strength := 0.12
@export_range(0.0, 5.0) var wind_speed := 1.2

@export_group("Interazione")
@export var interaction_enabled := true
@export_range(0.2, 3.0) var radius_scale := 1.0
@export_range(1.0, 30.0) var stiffness := 7.0
@export var unit_radius := 1.2
@export var projectile_radius := 0.7
@export var fire_radius := 1.0

var material: ShaderMaterial
## Ciuffi creati (somma dei MultiMesh), per test e statistiche.
var tuft_count := 0
var block_count := 0
var instance_count_by_variant := {}
var triangle_count := 0
## Posizioni (x, z) dei ciuffi creati, per test e diagnostica.
var tuft_positions := PackedVector2Array()
var _trample_image: Image
var _trample_texture: ImageTexture
var _trample_touched := PackedInt32Array()   # texel scritti nell'ultimo frame
var _push := PackedVector3Array()            # spinta x, z e schiacciamento per texel
var _lod_blocks: Array[Dictionary] = []      # {mm, rect, lod (soglie ordinate), shown}
var _tracked: Dictionary = {}
var _relief: TerrainRelief
var _terrain: PhotoTerrain


func _ready() -> void:
	add_to_group(&"grass_cards")
	if not enabled or not TerrainStyle.photo():
		visible = false
		set_process(false)
		return
	_trample_image = Image.create(TRAMPLE_RES, TRAMPLE_RES, false, Image.FORMAT_RGBA8)
	_trample_image.fill(Color(0.5, 0.5, 0.0, 1.0))
	_trample_texture = ImageTexture.create_from_image(_trample_image)
	_push.resize(TRAMPLE_RES * TRAMPLE_RES)
	_build()


func _build() -> void:
	var low := Quality.current() == Quality.Level.LOW
	_relief = get_tree().get_first_node_in_group(&"terrain_relief") as TerrainRelief
	_terrain = get_tree().get_first_node_in_group(&"photo_terrain") as PhotoTerrain
	# Piazzali e lastricati spenti (visible = false nella scena) non sono sul terreno
	# fotorealistico: lì cresce erba. Sotto gli oggetti piccoli la radura è stretta.
	var mask := GrassMask.from_tree(get_tree(), mask_fade, true, solid_inset)
	var m1 := _image("T_terreno_maschere.png")
	var m2 := _image("T_terreno_maschere2.png")
	var meshes := {}
	var root := MODEL.instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		meshes[String(node.name)] = (node as MeshInstance3D).mesh
	root.free()

	var green := GREEN.duplicate()
	var dry := DRY.duplicate()
	var block := block_size * (4.0 if low else (2.0 if Quality.current() == Quality.Level.MEDIUM else 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var target := int(Quality.grass_budget() * density_scale)
	var buckets := {}   # Vector3i(bx, bz, variant index) -> {t, c, d}
	var names: Array = meshes.keys()
	names.sort()
	var placed := 0
	# Densità relativa in ogni punto: 1 = prato pieno. Le maschere decidono solo
	# DOVE c'è erba (sentieri, roccia, terra battuta), non quanta: dentro il prato
	# la densità è costante, così non ci sono chiazze rade o buchi.
	# Prima passata: area utile, per ricavare il passo della griglia dal budget.
	var useful := 0.0
	var step := 0.5
	var nx := int(map_size.x / step)
	var nz := int(map_size.y / step)
	for iz in nz:
		for ix in nx:
			var d := _density(origin.x + (ix + 0.5) * step, origin.y + (iz + 0.5) * step, mask, m1)
			useful += _accept(d) * step * step
	# Seconda passata: un candidato per cella di una griglia jitterata (distribuzione
	# stratificata, quasi blue noise): niente grumi né radure casuali.
	var cell := sqrt(maxf(useful, 1.0) / maxf(target, 1))
	var cx := int(ceil(map_size.x / cell))
	var cz := int(ceil(map_size.y / cell))
	for iz in cz:
		for ix in cx:
			var x := origin.x + (ix + rng.randf()) * cell
			var z := origin.y + (iz + rng.randf()) * cell
			var d := _density(x, z, mask, m1)
			if d <= 0.0 or rng.randf() > _accept(d):
				continue
			var a := _sample(m1, x, z)
			var b := _sample(m2, x, z)
			var tall := b.r
			var is_dry := rng.randf() < clampf(a.a, 0.0, 1.0) * dry_share
			var variant := _pick(green if not is_dry else dry, tall, is_dry, low, rng, meshes)
			if variant == "":
				continue
			var y := _ground(x, z) - 0.02
			# Altezza quasi uniforme: la maschera macro la sposta solo di ±macro_height/2;
			# vicino a sentieri e bordi l'erba si accorcia (transizione naturale).
			var scale := lerpf(1.0, 0.6 + 0.8 * tall, macro_height) * rng.randf_range(0.88, 1.12)
			scale *= tuft_scale * lerpf(0.45, 1.0, smoothstep(0.0, 1.0, d))
			if variant in ["Erba_Lunga", "Erba_Lunga_Secca", "Prato_Alto"]:
				scale = minf(scale, 1.1)
			if low:
				scale *= 1.1
			var dryness := rng.randf_range(0.45, 0.9) if is_dry else rng.randf_range(0.0, 0.2)
			var colour := tint.lerp(dry_tint, dryness)
			colour = colour.lerp(dry_tint, b.g * colour_patches)
			var bright := rng.randf_range(0.92, 1.06)
			colour = Color(colour.r * bright, colour.g * bright, colour.b * bright)
			var key := Vector3i(floori((x - origin.x) / block), floori((z - origin.y) / block), names.find(variant))
			if not buckets.has(key):
				buckets[key] = {"t": [], "c": [], "d": []}
			var bucket: Dictionary = buckets[key]
			bucket["t"].append(Vector3(x - global_position.x, y - global_position.y, z - global_position.z))
			bucket["c"].append(colour)
			# w = soglia di LOD (0..1): a distanza restano i ciuffi con w < keep.
			bucket["d"].append(Color(rng.randf() * TAU, scale, rng.randf(), rng.randf()))
			tuft_positions.append(Vector2(x, z))
			placed += 1

	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"albedo_alpha", load(TEX_DIR + "T_erba_cards_albedo_alpha.png"))
	material.set_shader_parameter(&"card_normal", load(TEX_DIR + "T_erba_cards_normal.png"))
	material.set_shader_parameter(&"sss_rough_ao", load(TEX_DIR + "T_erba_cards_sss_rough_ao.png"))
	_apply_parameters()

	var blocks := {}
	for key: Vector3i in buckets:
		var bucket: Dictionary = buckets[key]
		var variant_name: String = names[key.z]
		var mesh: Mesh = meshes[variant_name]
		var n: int = bucket["t"].size()
		# Ordinati per soglia di LOD: tagliare visible_instance_count a k·n tiene
		# esattamente i ciuffi che lo shader terrebbe con keep = k.
		var order := range(n)
		var lod: Array = bucket["d"]
		order.sort_custom(func(i: int, j: int) -> bool: return lod[i].a < lod[j].a)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = n
		for i in n:
			var k: int = order[i]
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, bucket["t"][k]))
			mm.set_instance_color(i, bucket["c"][k])
			mm.set_instance_custom_data(i, bucket["d"][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [variant_name, key.x, key.y]
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Vento e interattori spostano i fili: il riquadro di visibilità va allargato.
		mmi.extra_cull_margin = 1.5
		add_child(mmi)
		var thresholds := PackedFloat32Array()
		for i in n:
			thresholds.append(lod[order[i]].a)
		_lod_blocks.append({"mm": mm, "rect": Rect2(origin.x + key.x * block, origin.y + key.y * block, block, block), "lod": thresholds, "shown": n})
		blocks[Vector2i(key.x, key.y)] = true
		tuft_count += n
		instance_count_by_variant[variant_name] = instance_count_by_variant.get(variant_name, 0) + n
		triangle_count += n * (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3)
	block_count = blocks.size()


func _pick(table: Dictionary, tall: float, is_dry: bool, low: bool, rng: RandomNumberGenerator, meshes: Dictionary) -> String:
	var weights := table.duplicate()
	# Le varianti alte sono accenti sparsi ovunque: la maschera d'altezza ne
	# sposta la frequenza solo un po', senza creare zone di erba alta.
	var f := lerpf(1.0, 0.4 + 1.2 * tall, macro_height)
	if is_dry:
		weights["Erba_Lunga_Secca"] = 2.0 * f
		weights["Prato_Alto"] = 1.2 * f
	else:
		weights["Erba_Lunga"] = 2.0 * f
		weights["Prato_Alto"] = 2.5 * f
	var total := 0.0
	for k: String in weights:
		if not meshes.has(k) or (low and not k in LOW_VARIANTS):
			weights[k] = 0.0
		total += weights[k]
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for k: String in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return ""


## Densità relativa (0..1) nel punto: maschera di superficie (sabbia, strade,
## costruzioni) per la roccia e i sentieri del terreno (canale B di
## T_terreno_maschere, ~0 su sentieri e terra battuta). Sopra la soglia vale 1.
func _density(x: float, z: float, mask: GrassMask, m1: Image) -> float:
	var w := mask.weight(Vector2(x, z))
	if w <= 0.0:
		return 0.0
	var a := _sample(m1, x, z)
	w *= 1.0 - smoothstep(0.3, 0.5, a.r)
	w *= smoothstep(path_low, path_high, a.b)
	return w


## Probabilità di tenere un candidato con densità d: piena da 0.45 in su,
## così il bordo resta fitto (erba più corta) e si dirada solo all'ultimo.
static func _accept(d: float) -> float:
	return smoothstep(0.0, 0.45, d)


## Campionamento bilineare di una maschera 52x52 m (niente scalini di pixel).
func _sample(image: Image, x: float, z: float) -> Color:
	var w := image.get_width()
	var h := image.get_height()
	var fx := clampf((x - origin.x) / map_size.x * w - 0.5, 0.0, w - 1.001)
	var fz := clampf((z - origin.y) / map_size.y * h - 0.5, 0.0, h - 1.001)
	var x0 := int(fx)
	var z0 := int(fz)
	var tx := fx - x0
	var tz := fz - z0
	var top := image.get_pixel(x0, z0).lerp(image.get_pixel(x0 + 1, z0), tx)
	var bottom := image.get_pixel(x0, z0 + 1).lerp(image.get_pixel(x0 + 1, z0 + 1), tx)
	return top.lerp(bottom, tz)


## Quota del terreno: la mesh vera se c'è, altrimenti i livelli di TerrainRelief.
func _ground(x: float, z: float) -> float:
	if _terrain and _terrain.is_active():
		return _terrain.height_at(x, z)
	return _relief.height_at_world(x, z) if _relief else 0.0


func _image(file: String) -> Image:
	var image := (load(TEX_DIR + file) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	return image


func _apply_parameters() -> void:
	if material == null:
		return
	material.set_shader_parameter(&"wind_direction", wind_direction)
	material.set_shader_parameter(&"wind_strength", wind_strength)
	material.set_shader_parameter(&"wind_speed", wind_speed)
	material.set_shader_parameter(&"lod_start", lod_start)
	material.set_shader_parameter(&"lod_end", lod_end)
	material.set_shader_parameter(&"lod_keep", lod_keep)
	material.set_shader_parameter(&"trample_map", _trample_texture)
	material.set_shader_parameter(&"trample_origin", origin)
	material.set_shader_parameter(&"trample_size", map_size)


func _process(delta: float) -> void:
	if material == null:
		return
	if interaction_enabled:
		_collect_sources()
		_update_tracked(delta)
	else:
		_tracked.clear()
	_write_trample()
	_update_lod()


## LOD per blocco: si disegnano solo i ciuffi con soglia sotto il keep del punto
## del blocco più vicino alla camera (lo shader poi sfoltisce ciuffo per ciuffo).
func _update_lod() -> void:
	var camera := get_viewport().get_camera_3d() if get_viewport() else null
	if camera == null:
		return
	var eye := camera.global_position
	for blk: Dictionary in _lod_blocks:
		var r: Rect2 = blk["rect"]
		var nearest := Vector2(clampf(eye.x, r.position.x, r.end.x), clampf(eye.z, r.position.y, r.end.y))
		# Quota: il ciuffo più alto (altopiani fino a 2.4 m) è il più vicino, come nello shader.
		var dist := Vector3(nearest.x - eye.x, maxf(eye.y - 2.5, 0.0), nearest.y - eye.z).length()
		var keep := lerpf(1.0, lod_keep, smoothstep(lod_start, lod_end, dist))
		var lod: PackedFloat32Array = blk["lod"]
		var shown := lod.bsearch(keep, false)
		if shown != blk["shown"]:
			blk["shown"] = shown
			(blk["mm"] as MultiMesh).visible_instance_count = shown if shown < lod.size() else -1


## Interattori attivi in questo momento (per i test).
func active_interactor_count() -> int:
	var n := 0
	for entry: Dictionary in _tracked.values():
		if entry["alpha"] > 0.05:
			n += 1
	return n


func _collect_sources() -> void:
	for entry: Dictionary in _tracked.values():
		entry["seen"] = false
	for node in get_tree().get_nodes_in_group(&"units"):
		_see(node as Node3D, unit_radius)
	for node in get_tree().get_nodes_in_group(&"projectiles"):
		_see(node as Node3D, projectile_radius)
	for node in get_tree().get_nodes_in_group(&"burning_cells"):
		_see(node as Node3D, fire_radius)


func _see(node: Node3D, radius: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	var id := node.get_instance_id()
	var entry: Dictionary = _tracked.get(id, {})
	if entry.is_empty():
		entry = {"pos": node.global_position, "radius": radius, "alpha": 0.0, "seen": true}
		_tracked[id] = entry
	entry["seen"] = true
	entry["radius"] = radius
	entry["target"] = node.global_position


func _update_tracked(delta: float) -> void:
	var follow := 1.0 - exp(-stiffness * delta)
	var fade := 1.0 - exp(-stiffness * 0.6 * delta)
	var gone: Array = []
	for id: int in _tracked:
		var entry: Dictionary = _tracked[id]
		if entry["seen"]:
			var target: Vector3 = entry["target"]
			var pos: Vector3 = entry["pos"]
			if pos.distance_to(target) > 2.5:
				entry["pos"] = target
				entry["alpha"] = 0.0
			else:
				entry["pos"] = pos.lerp(target, follow)
			entry["alpha"] = lerpf(entry["alpha"], 1.0, fade)
		else:
			entry["alpha"] = lerpf(entry["alpha"], 0.0, fade)
			if entry["alpha"] < 0.02:
				gone.append(id)
	for id in gone:
		_tracked.erase(id)


## Disegna gli interattori nella mappa di calpestio: per ogni texel nel raggio,
## spinta radiale (via dal centro) con caduta morbida, sommata tra interattori
## vicini, e schiacciamento = massimo. Si riscrivono solo i texel toccati in
## questo frame o nel precedente; senza interattori non si carica niente.
func _write_trample() -> void:
	if _tracked.is_empty() and _trample_touched.is_empty():
		return
	var texel := map_size / TRAMPLE_RES
	var touched := PackedInt32Array()
	var marked := {}
	for entry: Dictionary in _tracked.values():
		var r: float = entry["radius"] * radius_scale * entry["alpha"]
		if r <= 0.01:
			continue
		var p: Vector3 = entry["pos"]
		var x0 := maxi(int((p.x - r - origin.x) / texel.x), 0)
		var x1 := mini(int((p.x + r - origin.x) / texel.x), TRAMPLE_RES - 1)
		var z0 := maxi(int((p.z - r - origin.y) / texel.y), 0)
		var z1 := mini(int((p.z + r - origin.y) / texel.y), TRAMPLE_RES - 1)
		for tz in range(z0, z1 + 1):
			for tx in range(x0, x1 + 1):
				var cx := origin.x + (tx + 0.5) * texel.x
				var cz := origin.y + (tz + 0.5) * texel.y
				var away := Vector2(cx - p.x, cz - p.z)
				var dist := away.length()
				if dist >= r:
					continue
				var f := 1.0 - smoothstep(0.0, r, dist)
				f *= f
				var dir := away / dist if dist > 0.001 else Vector2(1.0, 0.0)
				var i := tz * TRAMPLE_RES + tx
				if not marked.has(i):
					marked[i] = true
					touched.append(i)
					_push[i] = Vector3.ZERO
				var cur := _push[i]
				_push[i] = Vector3(cur.x + dir.x * f, cur.y + dir.y * f, maxf(cur.z, f))
	# Texel del frame scorso non più toccati: tornano a riposo.
	for i in _trample_touched:
		if not marked.has(i):
			_trample_image.set_pixel(i % TRAMPLE_RES, i / TRAMPLE_RES, Color(0.5, 0.5, 0.0, 1.0))
	for i in touched:
		var v := _push[i]
		var push := Vector2(v.x, v.y).limit_length(1.0)
		_trample_image.set_pixel(i % TRAMPLE_RES, i / TRAMPLE_RES, Color(push.x * 0.5 + 0.5, push.y * 0.5 + 0.5, v.z, 1.0))
	_trample_touched = touched
	_trample_texture.update(_trample_image)


## Spinta (x, z) e schiacciamento nella mappa di calpestio nel punto del mondo (per i test).
func trample_at(world: Vector3) -> Vector3:
	var u := int((world.x - origin.x) / map_size.x * TRAMPLE_RES)
	var v := int((world.z - origin.y) / map_size.y * TRAMPLE_RES)
	if u < 0 or v < 0 or u >= TRAMPLE_RES or v >= TRAMPLE_RES:
		return Vector3.ZERO
	var c := _trample_image.get_pixel(u, v)
	return Vector3(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0, c.b)
