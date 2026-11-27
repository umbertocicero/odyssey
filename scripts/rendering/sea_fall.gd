class_name SeaFall
extends Node3D
## Cascata del mare sul lato ovest del diorama: il mare non si ferma sul bordo, scivola oltre il
## ciglio, cade lungo il fianco del blocco e si perde in una nebbia di spruzzi (stile "bordo del mondo").
## Due mesh generate (nessuna texture nuova): la lastra d'acqua che cade (sea_fall.gdshader) e una
## striscia orizzontale di nebbia sotto il blocco (sea_fall_mist.gdshader). Le crea SeaWater.

const FALL_SHADER := preload("res://assets/shaders/sea_fall.gdshader")
const MIST_SHADER := preload("res://assets/shaders/sea_fall_mist.gdshader")
const HEIGHT_TEX := preload("res://assets/environment/water/sea_height.png")

## x del bordo ovest del mare e quote del ciglio e della base (mondo).
@export var edge_x := -26.0
@export var top_y := -0.1
@export var bottom_y := -8.6
## Quanto la lastra sta fuori dal fianco del blocco (i blocchi sporgono fino a ~0.6 m).
@export var wall_offset := 1.0
@export var z_range := Vector2(-19.0, 22.0)
@export var z_step := 0.5
## x mondiale a cui arriva la nebbia verso l'esterno.
@export var mist_reach := 3.3

var stats := {"fall_triangles": 0, "mist_triangles": 0}


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_build_fall()
	_build_mist()


## Profilo (x, y) della lastra: piana sul pelo dell'acqua, curva sul ciglio, poi verticale fino alla base.
func _profile() -> PackedVector2Array:
	var out_x := edge_x - wall_offset
	# curva a "ogee" sul ciglio: scende dolcemente e poi si fa verticale (visibile anche dalla camera di gioco)
	var points := PackedVector2Array()
	var steps := 10
	var reach := 0.7 + wall_offset
	for i in steps + 1:
		var u := float(i) / steps
		var px := (edge_x + 0.7) - reach * u
		var py := top_y - 0.015 - 2.4 * pow(u, 2.2)
		points.append(Vector2(px, py))
	points[steps].x = out_x
	var y := points[steps].y
	while y > bottom_y + 0.01:
		y = maxf(y - 1.4, bottom_y)
		points.append(Vector2(out_x - 0.03 * (top_y - y) * 0.15, y))
	return points


func _build_fall() -> void:
	var profile := _profile()
	var nz := ceili((z_range.y - z_range.x) / z_step)
	var rows := profile.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for iz in nz + 1:
		var z := minf(z_range.x + iz * z_step, z_range.y)
		for r in rows:
			var p := profile[r]
			verts.append(Vector3(p.x, p.y, z))
			var tangent := (profile[mini(r + 1, rows - 1)] - profile[maxi(r - 1, 0)])
			var n2 := Vector2(-tangent.y, tangent.x).normalized()   # esterno: -X sulla parte verticale, +Y sul ciglio
			if n2.x > 0.0:
				n2 = -n2
			normals.append(Vector3(n2.x, n2.y, 0.0).normalized())
	for iz in nz:
		for r in rows - 1:
			var a := iz * rows + r
			var b := a + rows
			indices.append_array([a, b, a + 1, b, b + 1, a + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = FALL_SHADER
	mat.set_shader_parameter(&"height_tex", HEIGHT_TEX)
	mat.set_shader_parameter(&"top_y", top_y)
	mat.set_shader_parameter(&"bottom_y", bottom_y)
	mat.set_shader_parameter(&"fade_start", top_y - (top_y - bottom_y) * 0.55)
	var inst := MeshInstance3D.new()
	inst.name = "Lastra"
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 2.0
	add_child(inst)
	stats["fall_triangles"] = indices.size() / 3


func _build_mist() -> void:
	var x_in := edge_x - wall_offset
	var x_out := x_in - mist_reach
	var y := bottom_y + 0.9
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(mist_reach, z_range.y - z_range.x)
	mesh.subdivide_width = 1
	mesh.subdivide_depth = 1
	var mat := ShaderMaterial.new()
	mat.shader = MIST_SHADER
	mat.set_shader_parameter(&"height_tex", HEIGHT_TEX)
	mat.set_shader_parameter(&"x_inner", x_in)
	mat.set_shader_parameter(&"x_outer", x_out)
	var inst := MeshInstance3D.new()
	inst.name = "Nebbia"
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = Vector3((x_in + x_out) * 0.5, y, (z_range.x + z_range.y) * 0.5)
	add_child(inst)
	stats["mist_triangles"] = 2
