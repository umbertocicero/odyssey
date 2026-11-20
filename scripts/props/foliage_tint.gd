class_name FoliageTint
extends RefCounted
## Correzioni ai materiali dei modelli Poly Haven convertiti, senza toccare i file:
##  1. Fogliame: le texture di foglie e aghi hanno albedo molto basso (circa 24/22/8
##     su 255) e sotto la luce calda del diorama diventano nere. L'albedo dei materiali
##     alpha-cutout viene moltiplicato per `gain`; tronchi e rocce restano com'erano.
##  2. Metallo spurio: in 27 materiali (alberi island, attrezzi, molo...) il glTF non
##     dichiara metallicFactor (vale 1) e la texture rough, grigia, finisce anche nel
##     canale blu del metallico: legno e cortecce diventano argento bianco. Si azzera
##     il metallico (il metallo vero è comunque perso nella conversione).
## Il lavoro è fatto su una copia della mesh, in cache: più oggetti con lo stesso modello
## condividono una sola mesh (e si possono unire in un MultiMesh).
##  3. Tinta: moltiplica l'albedo di tutti i materiali per `tint` (smorzare colori vivaci,
##     per lo stile Età del bronzo di STYLE.md).
## Rimedio definitivo: scrivere metallicFactor = 0 nei .gltf (agente di conversione).

const DEFAULT_GAIN := Color(5.5, 12.0, 6.0)

static var _meshes := {}
static var _materials := {}


static func apply(mesh: Mesh, gain: Color = Color(1, 1, 1), tint: Color = Color(1, 1, 1), desat := 0.0) -> Mesh:
	if mesh == null:
		return mesh
	var key := "%d|%s|%s|%s" % [mesh.get_instance_id(), gain, tint, desat]
	if _meshes.has(key):
		return _meshes[key]
	var needs := false
	for i in mesh.get_surface_count():
		var material := mesh.surface_get_material(i) as BaseMaterial3D
		if material != null and (_wrong_metal(material) or _is_foliage(material, gain) or tint != Color(1, 1, 1) or desat > 0.0):
			needs = true
	if not needs:
		_meshes[key] = mesh
		return mesh
	var copy := mesh.duplicate() as Mesh
	for i in copy.get_surface_count():
		var material := copy.surface_get_material(i) as BaseMaterial3D
		if material != null and (_wrong_metal(material) or _is_foliage(material, gain) or tint != Color(1, 1, 1) or desat > 0.0):
			copy.surface_set_material(i, _tuned(material, gain, tint, desat))
	_meshes[key] = copy
	return copy


static func _wrong_metal(material: BaseMaterial3D) -> bool:
	# Solo le texture Poly Haven convertite (nelle altre il canale blu è metallo vero).
	return material.metallic > 0.05 and material.metallic_texture != null \
			and material.metallic_texture == material.roughness_texture \
			and material.metallic_texture.resource_path.contains("/polyhaven/")


static func _is_foliage(material: BaseMaterial3D, gain: Color) -> bool:
	return gain != Color(1, 1, 1) and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR


static func _tuned(material: BaseMaterial3D, gain: Color, tint: Color, desat: float) -> BaseMaterial3D:
	var key := "%d|%s|%s|%s" % [material.get_instance_id(), gain, tint, desat]
	if not _materials.has(key):
		var copy := material.duplicate() as BaseMaterial3D
		if _wrong_metal(material):
			copy.metallic = 0.0
			copy.metallic_texture = null
		if _is_foliage(material, gain):
			var c := material.albedo_color
			copy.albedo_color = Color(c.r * gain.r, c.g * gain.g, c.b * gain.b, c.a)
		if desat > 0.0:
			var d := copy.albedo_color
			var lum := d.r * 0.3 + d.g * 0.59 + d.b * 0.11
			copy.albedo_color = Color(lerpf(d.r, lum, desat), lerpf(d.g, lum, desat), lerpf(d.b, lum, desat), d.a)
		if tint != Color(1, 1, 1):
			copy.albedo_color = Color(copy.albedo_color.r * tint.r, copy.albedo_color.g * tint.g, copy.albedo_color.b * tint.b, copy.albedo_color.a)
		_materials[key] = copy
	return _materials[key]
