extends SceneTree
## Test headless dell'audio: bus, import dei file, riproduzione dal pool.
## Avvio: godot --headless --path . -s res://tests/test_audio.gd
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameAudio.setup_buses()
	GameAudio.setup_buses()
	for b in [&"Music", &"SFX", &"Ambience"]:
		_check(AudioServer.get_bus_index(b) != -1, "bus %s presente" % b)
	_check(AudioServer.get_bus_count() == 4, "bus: 4 in tutto (%d)" % AudioServer.get_bus_count())
	GameAudio.set_volume(&"SFX", 0.5)
	_check(absf(GameAudio.get_volume(&"SFX") - 0.5) < 0.01, "volume SFX 0.5")
	for path in [GameAudio.SLASH_KILL] + GameAudio.CLASHES + GameAudio.HITS + GameAudio.DRAWS + GameAudio.SWINGS:
		var s := load(path) as AudioStream
		_check(s != null and s.get_length() > 0.1, "%s caricato" % path.get_file())
	var holder := Node3D.new()
	root.add_child(holder)
	await process_frame
	for i in 10:
		GameAudio.clash(holder, Vector3(i, 0, 0))
		GameAudio.slash_kill(holder, Vector3(0, 0, i))
		GameAudio.swing(holder, Vector3.ZERO)
		GameAudio.hit(holder, Vector3.ZERO)
		GameAudio.draw(holder, Vector3.ZERO)
	await create_timer(0.5).timeout
	var playing := 0
	for p in root.get_node("GameAudio").get_children():
		if p is AudioStreamPlayer3D and p.playing:
			playing += 1
	_check(playing > 0 and playing <= GameAudio.MAX_VOICES, "voci attive nel limite (%d)" % playing)
	print("FALLITI: %d" % _failures)
	quit(1 if _failures else 0)


func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_failures += 1
