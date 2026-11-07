extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set("opt_orac_voice", true)
	var speech: Object = game.get("speech")
	speech.call("configure", true)
	if speech.get("backend") not in ["kokoro", "espeak"]:
		push_error("Suit voice precache requires local Kokoro or espeak synthesis. Headless runs require ASH_SPEECH_LIVE=1.")
		quit(1)
		return
	game.set("dev_i", 21)
	game.call("WarpDev")
	var ring: Node = game.get("ownership_ring")
	ring.set_process(false)
	ring.get("terminal_feedback").set_process(false)
	var dialogue: Node = ring.get("orac_dialogue")
	var lines: Array = []
	for event_name in ["win", "loss", "tie"]:
		lines.append_array(dialogue.LINES[event_name])
	for event_name in dialogue.LINES:
		if event_name not in ["win", "loss", "tie"]:
			lines.append_array(dialogue.LINES[event_name])
	lines.append(ring.get("terminal").get("guidance"))
	lines.append("Loaded. Type SYS 49152. That starts Fast Hack'em; staring at READY. does not.")
	lines.append("The C64 is isolated from the programmer. F2 returns to the service terminal.")
	lines.append("Back on the service terminal. Load Fast Hack'em when you're ready.")
	lines.append("Type SYS 49152 to restart Fast Hack'em.")
	var cached := 0
	for line in lines:
		var path: String = dialogue.call("cache_path", line, speech)
		if ResourceLoader.exists(path):
			cached += 1
			continue
		game.call("OracStop")
		game.set("orac_said", "")
		speech.set("voice", "ORAC")
		speech.call("say", line, 0)
		var deadline := Time.get_ticks_msec() + 180000
		while not ResourceLoader.exists(path):
			# Offline preparation may exceed the interactive 30-second budget.
			speech.set("worker_started", Time.get_ticks_msec())
			speech.call("tick", false)
			dialogue.call("advance", 0.05)
			if speech.get("last_error") != "" or Time.get_ticks_msec() >= deadline:
				push_error("Cannot precache suit Orac line: " + line + " / " + str(speech.get("last_error")))
				game.queue_free()
				await process_frame
				quit(1)
				return
			await create_timer(0.05).timeout
		cached += 1
		print("SUIT_ORAC_CACHED: ", cached, "/", lines.size())
	game.call("OracStop")
	game.set("orac_said", "")
	var start := Time.get_ticks_msec()
	dialogue.call("register_cached_line", lines[0], speech)
	speech.set("voice", "ORAC")
	speech.call("say", lines[0], 0)
	speech.call("tick", false)
	var elapsed := Time.get_ticks_msec() - start
	var immediate: bool = speech.get("player").playing and speech.get("worker") == 0 and speech.get("job_stem") == ""
	print("SUIT_ORAC_CACHE_COMPLETED: ", cached, " clips; cached playback ", elapsed, " ms; no synthesis=", immediate)
	game.queue_free()
	await process_frame
	quit(0 if immediate and elapsed < 100 else 1)
