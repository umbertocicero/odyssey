class_name PropBatcher
extends Node
## Riduce le chiamate di disegno: i GridProp con lo stesso aspetto (stesso modello, pezzo, misura;
## palizzate, casse, botti, torce, rocce, cespugli...) smettono di essere un MeshInstance3D
## ciascuno e diventano le istanze di un MultiMeshInstance3D per ogni mesh del modello.
## Griglia, collisioni, scavalco e caselle bloccate non cambiano (restano sul GridProp).
## Gli alberi (chioma che sfuma al passaggio) e gli oggetti unici restano com'erano.
## Va messo dopo i nodi da unire: unisce i GridProp che trova sotto `root`
## (di default il nodo "Scenario" del livello).

@export var enabled := true
@export var root: NodePath = ^"../Scenario"
## Gruppi più piccoli di così non si uniscono.
@export var min_group := 2

## Statistiche per test e documentazione.
var batched_props := 0
var multimesh_count := 0
var removed_mesh_instances := 0


func _ready() -> void:
	if not enabled:
		return
	var base := get_node_or_null(root)
	if base == null:
		return
	var groups := {}
	for node in base.find_children("*", "GridProp", true, false):
		var key := (node as GridProp).visual_key()
		if key == "":
			continue
		if not groups.has(key):
			groups[key] = []
		groups[key].append(node)
	for key: String in groups:
		var props: Array = groups[key]
		if props.size() < min_group:
			continue
		# mesh -> lista di trasformazioni (più mesh per modello: una lista per ognuna).
		var by_mesh := {}
		for prop: GridProp in props:
			var parts := prop.take_visual()
			removed_mesh_instances += parts.size()
			for i in parts.size():
				var slot := "%d" % i
				if not by_mesh.has(slot):
					by_mesh[slot] = {"mesh": parts[i]["mesh"], "transforms": []}
				by_mesh[slot]["transforms"].append(parts[i]["transform"])
			batched_props += 1
		for slot: String in by_mesh:
			var entry: Dictionary = by_mesh[slot]
			var transforms: Array = entry["transforms"]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = entry["mesh"]
			mm.instance_count = transforms.size()
			for i in transforms.size():
				mm.set_instance_transform(i, transforms[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Batch_%d" % multimesh_count
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if "true" in key.get_slice("|", 5) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			# I MultiMesh stanno nel mondo: i trasformi sono già globali.
			mmi.global_transform = Transform3D.IDENTITY
			multimesh_count += 1
