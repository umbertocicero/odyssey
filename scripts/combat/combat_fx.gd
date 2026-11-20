class_name CombatFx
extends RefCounted
## Effetti visivi condivisi del combattimento (avvisi a terra, proiettili,
## fiamme). Mesh e materiali sono creati una volta sola e riusati, per
## restare leggeri su mobile e web.

static var _marker_mesh: PlaneMesh
static var _flame_mesh: CylinderMesh
static var _flame_material: StandardMaterial3D
static var _projectile_cache: Dictionary = {}


## Avviso rosso pulsante sulla casella bersaglio; sparisce da solo dopo duration.
static func spawn_marker(grid: DioramaGrid, cell: Vector2i, duration: float, fire: bool) -> Node3D:
	if _marker_mesh == null:
		_marker_mesh = PlaneMesh.new()
		_marker_mesh.size = Vector2.ONE * grid.cell_size * 0.9
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.45, 0.0, 0.35) if fire else Color(1.0, 0.1, 0.05, 0.35)
	var marker := MeshInstance3D.new()
	marker.name = "AvvisoTiro"
	marker.mesh = _marker_mesh
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_to_group(&"target_markers")
	grid.get_parent().add_child(marker)
	marker.global_position = grid.cell_to_world(cell) + Vector3.UP * 0.03
	# L'avviso diventa più intenso man mano che il colpo si avvicina.
	var tween := marker.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.85, duration)
	tween.parallel().tween_property(marker, "scale", Vector3(0.6, 1, 0.6), duration).from(Vector3(1.1, 1, 1.1))
	tween.tween_callback(marker.queue_free)
	return marker


static func projectile_mesh(profile: AttackProfile) -> Array:
	var key := "%d_%s_%s_%s" % [profile.projectile_shape, profile.projectile_color.to_html(), profile.projectile_glow, profile.projectile_scale]
	if _projectile_cache.has(key):
		return _projectile_cache[key]
	var mesh: Mesh
	match profile.projectile_shape:
		AttackProfile.Shape.STONE:
			var sphere := SphereMesh.new()
			sphere.radius = 0.3 * profile.projectile_scale
			sphere.height = 0.6 * profile.projectile_scale
			sphere.radial_segments = 8
			sphere.rings = 4
			mesh = sphere
		AttackProfile.Shape.BOLT:
			var bolt := BoxMesh.new()
			bolt.size = Vector3(0.09, 0.09, 1.1) * profile.projectile_scale
			mesh = bolt
		_:
			var arrow := BoxMesh.new()
			arrow.size = Vector3(0.04, 0.04, 0.7) * profile.projectile_scale
			mesh = arrow
	var material := StandardMaterial3D.new()
	material.albedo_color = profile.projectile_color
	if profile.projectile_glow:
		material.emission_enabled = true
		material.emission = Color(1.0, 0.5, 0.1)
		material.emission_energy_multiplier = 3.0
	var entry := [mesh, material]
	_projectile_cache[key] = entry
	return entry


static func flame_mesh() -> CylinderMesh:
	if _flame_mesh == null:
		_flame_mesh = CylinderMesh.new()
		_flame_mesh.top_radius = 0.0
		_flame_mesh.bottom_radius = 0.18
		_flame_mesh.height = 0.6
		_flame_mesh.radial_segments = 6
		_flame_mesh.rings = 1
		_flame_material = StandardMaterial3D.new()
		_flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_material.albedo_color = Color(1.0, 0.55, 0.1)
		_flame_material.emission_enabled = true
		_flame_material.emission = Color(1.0, 0.4, 0.05)
		_flame_mesh.material = _flame_material
	return _flame_mesh
