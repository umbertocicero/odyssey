class_name Stretcher
extends Node3D
## Barella improvvisata: un mantello teso su due pali. Il ferito grave ci sta sopra.

const POLE_LENGTH := 2.5
const WIDTH := 0.8


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.25, 0.14)
	wood.roughness = 0.9
	for sx in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = POLE_LENGTH
		cyl.radial_segments = 8
		pole.mesh = cyl
		pole.material_override = wood
		pole.rotation.x = PI * 0.5
		pole.position = Vector3(sx * WIDTH * 0.5, 0.55, 0.0)
		add_child(pole)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.42, 0.20, 0.14)
	cloth.roughness = 0.95
	var sheet := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH - 0.02, 0.035, 1.9)
	sheet.mesh = box
	sheet.material_override = cloth
	sheet.position = Vector3(0, 0.53, 0)
	add_child(sheet)
