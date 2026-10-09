extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func counts(sound: Node) -> Array:
	return sound.get("cue_counts").duplicate()

func blank(game: Node) -> void:
	game.call("RestartCave")
	var board: Array = game.get("board").duplicate()
	for y in 12:
		for x in 20:
			board[y * 20 + x] = 1 if x == 0 or x == 19 or y == 0 or y == 11 else 0
	game.set("board", board)
	game.set("playerX", 2)
	game.set("playerY", 8)

func put(game: Node, x: int, y: int, kind: int) -> void:
	var board: Array = game.get("board").duplicate()
	board[y * 20 + x] = kind
	game.set("board", board)

func press(keycode: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)

func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.get_node("VisualEffects").set_process(false)
	var sound := game.get_node("SoundEffects")
	await process_frame
	check(sound.get_script().resource_path.ends_with(".vg"), "sound controller is VG")
	check(sound.get("ready_to_play") and sound.get("streams").size() == 10, "ten DATA sounds cached at startup")
	check(sound.get("voices").size() == 4, "four reusable audio voices")
	check(counts(sound)[0] == 1, "startup plays entrance once")
	var durations := [0.28, 0.045, 0.075, 0.10, 0.09, 0.16, 0.32, 0.48, 0.38, 0.18]
	var frequencies := [Vector2(220, 660), Vector2(140, 90), Vector2(170, 60), Vector2(110, 55),
		Vector2(90, 35), Vector2(880, 1760), Vector2(440, 1320), Vector2(523, 1568),
		Vector2(240, 30), Vector2(990, 660)]
	var noise_mix := [0.0, 0.15, 0.7, 0.4, 0.65, 0.0, 0.0, 0.0, 0.65, 0.0]
	var hashes: Array[int] = []
	var output := OS.get_environment("CRYSTAL_SOUND_CAPTURE")
	for index in 10:
		var stream: AudioStreamWAV = sound.get("streams")[index]
		var samples := stream.data
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 8000 and not stream.stereo,
			"cue %d has valid mono PCM format" % index)
		check(samples.size() == int(durations[index] * 8000) * 2 and is_equal_approx(stream.get_length(), durations[index]),
			"cue %d has exact DATA duration" % index)
		var peak := 0
		var energy := 0.0
		var phase := 0.0
		var seed := 12345
		var max_error := 0
		for sample_index in samples.size() / 2:
			var value := samples.decode_s16(sample_index * 2)
			peak = maxi(peak, absi(value))
			energy += float(value) * value
			var t := sample_index / float(samples.size() / 2 - 1)
			phase += lerpf(frequencies[index].x, frequencies[index].y, t) / 8000.0
			seed = (seed * 25173 + 13849) % 65536
			var envelope := minf(1.0, t * 30.0) * (1.0 - t) * (1.0 - t)
			var expected := floori((sin(phase * TAU) * (1.0 - noise_mix[index]) +
				(seed / 32768.0 - 1.0) * noise_mix[index]) * envelope * 12000)
			max_error = maxi(max_error, absi(value - expected))
		check(max_error <= 1, "cue %d samples match DATA frequency sweep/noise/envelope within one PCM unit" % index)
		check(peak > 1000 and peak <= 12000 and sqrt(energy / (samples.size() / 2)) > 500,
			"cue %d contains non-silent, bounded PCM" % index)
		check(samples.decode_s16(0) == 0 and samples.decode_s16(samples.size() - 2) == 0,
			"cue %d fades both ends to zero" % index)
		hashes.append(hash(samples))
		if not output.is_empty():
			check(stream.save_to_wav(output.path_join("cue-%02d" % index)) == OK, "save cue %d WAV evidence" % index)
		stream = null
	check(hashes.size() == 10 and hashes.all(func(h): return hashes.count(h) == 1), "all ten cues have distinct waveforms")
	var rebuilt: AudioStreamWAV = sound.call("BuildCue", 0.28, 220.0, 660.0, 0.0)
	check(rebuilt.data == sound.get("streams")[0].data, "synthesis is deterministic")
	rebuilt = null
	for voice in sound.get("voices"):
		check(voice is AudioStreamPlayer and voice.volume_db == -12.0 and voice.bus == &"Master",
			"voice routes conservative volume to Master")

	# Capture the mixer output, not just a playing flag or nonempty stream.
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, capture)
	var effect_index := AudioServer.get_bus_effect_count(0) - 1
	sound.call("StopAll")
	capture.clear_buffer()
	sound.call("PlayCue", 5)
	var deadline := Time.get_ticks_msec() + 2000
	var audible := false
	while not audible and Time.get_ticks_msec() < deadline:
		await process_frame
		var buffer := capture.get_buffer(capture.get_frames_available())
		for sample in buffer:
			if absf(sample.x) > 0.005 or absf(sample.y) > 0.005:
				audible = true
				break
	check(audible, "AudioServer mixer receives non-silent stereo output")
	AudioServer.remove_bus_effect(0, effect_index)
	capture = null
	sound.call("StopAll")

	blank(game)
	var before := counts(sound)
	game.call("TryMove", -2, 0)
	put(game, 3, 8, 1)
	game.call("TryMove", 1, 0)
	check(counts(sound) == before, "invalid or blocked movement is silent")
	put(game, 3, 8, 0)
	game.call("TryMove", 1, 0)
	check(counts(sound)[1] == before[1] + 1, "successful empty-cell step plays footstep")
	put(game, 4, 8, 2)
	game.call("TryMove", 1, 0)
	check(counts(sound)[2] == before[2] + 1, "digging plays dirt cue")
	put(game, 5, 8, 3)
	game.call("TryMove", 1, 0)
	check(counts(sound)[3] == before[3] + 1, "successful horizontal push plays rock cue")
	put(game, 6, 8, 4)
	game.call("TryMove", 1, 0)
	check(counts(sound)[5] == before[5] + 1, "real pickup triggers sound through Whenever")
	for x in range(7, 12):
		put(game, x, 8, 4)
		game.call("TryMove", 1, 0)
	check(counts(sound)[6] == before[6] + 1, "unlock watcher plays distinct cue")
	var unlocked := counts(sound)
	game.set("crystals", 6)
	check(counts(sound) == unlocked, "same crystal value does not replay watchers")
	put(game, 12, 8, 5)
	game.call("TryMove", 1, 0)
	check(counts(sound)[7] == before[7] + 1, "entering open exit plays victory")
	game.call("StepCave", 0, 0)
	check(counts(sound)[7] == before[7] + 1, "won cave cannot repeat victory cue")
	game.call("RestartCave")
	check(counts(sound)[0] == before[0] + 1, "restart plays entrance again")
	game.set("secondsLeft", 11)
	game.set("ticks", 7)
	game.call("StepCave", 0, 0)
	var hurry: int = counts(sound)[9]
	game.set("secondsLeft", 9)
	check(hurry == before[9] + 1 and counts(sound)[9] == hurry, "warning chirps once at low-time crossing")
	game.call("FinishDefeat", "Sound test")
	game.call("FinishDefeat", "Duplicate")
	check(counts(sound)[8] == before[8] + 1, "defeat cue plays once")
	blank(game)
	put(game, 10, 9, 3)
	put(game, 11, 9, 3)
	var falling: Array = game.get("falling").duplicate()
	falling[190] = true
	falling[191] = true
	game.set("falling", falling)
	put(game, 10, 10, 1)
	put(game, 11, 10, 1)
	before = counts(sound)
	game.call("StepCave", 0, 0)
	game.call("StepCave", 0, 0)
	check(counts(sound)[4] == before[4] + 1, "multiple settling rocks make one cue, supported rocks stay silent")

	sound.call("PlayCue", 7)
	var active: Array = sound.get("voices").filter(func(v): return v.playing)
	press(KEY_P)
	check(game.get("paused") and not active.is_empty() and active.all(func(v): return v.stream_paused), "pause freezes active sounds")
	press(KEY_ESCAPE)
	check(not game.get("paused") and sound.get("voices").all(func(v): return not v.stream_paused), "resume unpauses voices")
	sound.get("toggle").button_pressed = false
	check(not sound.get("enabled") and sound.get("voices").all(func(v): return not v.playing), "sound switch mutes and stops all voices")
	before = counts(sound)
	game.call("RestartCave")
	game.call("TryMove", 1, 0)
	check(counts(sound) == before and game.get("playerX") == 2, "muted movement/restart remain playable and silent")
	press(KEY_F9)
	check(sound.get("enabled") and sound.get("toggle").button_pressed, "real F9 input reenables sound")
	press(KEY_F9, true)
	check(sound.get("enabled"), "F9 key repeat is ignored")
	var effects := game.get_node("VisualEffects")
	var visual_enabled: bool = effects.get("effects_enabled")
	press(KEY_F9)
	check(not sound.get("enabled") and effects.get("effects_enabled") == visual_enabled, "sound mute is independent of visual effects")
	press(KEY_F9)
	var state_before: Array = [game.get("board").duplicate(), game.get("playerX"), game.get("playerY"),
		game.get("ticks"), game.get("crystals"), game.get("gameState"), game.get("secondsLeft")]
	for index in 20:
		sound.call("PlayCue", index % 10)
	check(state_before == [game.get("board"), game.get("playerX"), game.get("playerY"),
		game.get("ticks"), game.get("crystals"), game.get("gameState"), game.get("secondsLeft")],
		"playing sound never changes simulation state")
	check(sound.get("voices").size() == 4 and sound.get("next_voice") >= 0 and sound.get("next_voice") < 4,
		"rapid cues keep a bounded voice pool")
	var voices: Array = sound.get("voices").duplicate()
	var handles: Array = sound.get("streams").map(func(stream): return weakref(stream))
	game.free()
	await process_frame
	check(voices.all(func(v): return not is_instance_valid(v)), "scene destruction frees all audio players")
	voices.clear()
	deadline = Time.get_ticks_msec() + 2000
	while handles.any(func(h): return h.get_ref() != null) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(handles.all(func(h): return h.get_ref() == null), "scene destruction releases every cached sound stream")
	print("SOUND RESULTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
