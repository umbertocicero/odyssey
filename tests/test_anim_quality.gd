extends SceneTree
## Qualità delle animazioni procedurali (HumanoidAnims): tutte le clip si calcolano, i loop si chiudono,
## armi e scudo non entrano nel corpo, i piedi d'appoggio non scivolano nelle andature.
## Avvio: godot --headless --path . -s res://tests/test_anim_quality.gd

var _failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var inst := (load("res://assets/models/custom/personaggi_nuovi/ulisse/ulisse.gltf") as PackedScene).instantiate()
	root.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var configs := [
		["spada+scudo", HumanoidAnims.Hand.SWORD, true, false, PackedStringArray(["base", "support"])],
		["spada", HumanoidAnims.Hand.SWORD, false, false, PackedStringArray(["base", "support", "stretcher"])],
		["lancia", HumanoidAnims.Hand.SPEAR, false, false, PackedStringArray(["base"])],
		["arco", HumanoidAnims.Hand.NONE, false, true, PackedStringArray(["base", "bow"])],
		["disarmato", HumanoidAnims.Hand.NONE, false, false, PackedStringArray(["base", "limp", "leader", "drag"])],
	]
	for c in configs:
		var t0 := Time.get_ticks_usec()
		var lib := HumanoidAnims.library(sk, c[1], c[2], c[3], c[4])
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("INFO  %s: %d clip in %.0f ms" % [c[0], lib.get_animation_list().size(), ms])
		for name in lib.get_animation_list():
			var a := lib.get_animation(name)
			# I portatori della barella non hanno armi.
			var res := HumanoidAnims.audit(a, HumanoidAnims.Hand.NONE if String(name).begins_with("stretcher") else c[1], c[2])
			var limit := 0.02
			if String(name).begins_with("dragged"):
				pass   # il ferito trascinato striscia i talloni: niente controllo di scivolamento
			elif String(name).ends_with("_walk") or String(name).ends_with("_run") or name == &"walk" or name == &"run":
				var slip := HumanoidAnims.foot_slip(a, HumanoidAnims.stride(name) * (-1.0 if String(name).begins_with("drag") else 1.0))   # si trascina camminando all'indietro
				_check(slip <= 0.03, "%s/%s: scivolamento del piede d'appoggio %.3f m" % [c[0], name, slip])
			_check(res["pen"] <= limit, "%s/%s: compenetrazione %.3f m (%s a %.2f s)" % [c[0], name, res["pen"], res["what"], res["t"]])
	print("RISULTATO: ", "OK" if _failures == 0 else "%d FALLITI" % _failures)
	quit(0 if _failures == 0 else 1)
