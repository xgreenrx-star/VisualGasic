extends SceneTree

const BASE := "res://assets/opening_cinematic/"
var speech: Node

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error("Opening animatic: " + message)
	if is_instance_valid(speech):
		speech.call("stop")
		speech.queue_free()
	quit(1)

func run() -> void:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(BASE + "script.json")) != OK:
		fail(parser.get_error_message())
		return
	var script_data: Dictionary = parser.data
	speech = Node.new()
	speech.set_script(load("res://flight_speech.vg"))
	root.add_child(speech)
	speech.call("configure", false)
	if not speech.call("KokoroReady"):
		fail("Local Kokoro is required. No robotic fallback is permitted.")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE + "voice")) != OK:
		fail("Cannot create voice output directory.")
		return
	var manifest: Array = []
	for line: Dictionary in script_data.lines:
		var wav := ProjectSettings.globalize_path("user://opening-animatic-%s.wav" % OS.get_process_id())
		var profile: String = line.profile
		var speed := float(line.speed)
		var silence := float(line.silence)
		if speed < 0.5 or speed > 2.0 or silence < 0.02 or silence > 1.0:
			fail("Invalid delivery settings for line " + line.id)
			return
		if not speech.call("SubmitDaemonJob", line.text, wav, profile, speed, silence):
			fail("Cannot submit line " + line.id)
			return
		var stem: String = speech.get("job_stem")
		var deadline := Time.get_ticks_msec() + 180000
		var status := 0
		while status == 0 and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
			status = speech.call("JobStatus", stem)
		speech.call("DropJobFiles", stem)
		if status != 1:
			if FileAccess.file_exists(wav):
				DirAccess.remove_absolute(wav)
			fail("Synthesis failed for line " + line.id)
			return
		var output: String = BASE + "voice/" + line.id + ".ogg"
		var errors: Array = []
		var result := OS.execute("ffmpeg", ["-v", "error", "-y", "-i", wav,
			"-ar", "48000", "-c:a", "libvorbis", "-q:a", "5",
			ProjectSettings.globalize_path(output)], errors, true)
		DirAccess.remove_absolute(wav)
		if result != 0:
			fail("Cannot encode line " + line.id + ": " + str(errors))
			return
		var probe: Array = []
		if OS.execute("ffprobe", ["-v", "error", "-show_entries", "format=duration",
			"-of", "default=noprint_wrappers=1:nokey=1",
			ProjectSettings.globalize_path(output)], probe, true) != 0:
			fail("Cannot measure line " + line.id)
			return
		var seconds := str(probe[0]).strip_edges().to_float()
		if seconds <= 0.0:
			fail("Invalid audio duration for line " + line.id)
			return
		manifest.append({"id": line.id, "speaker": line.speaker, "text": line.text,
			"profile": profile, "speed": speed, "silence": silence, "backend": "kokoro",
			"seconds": seconds, "audio": "voice/" + line.id + ".ogg"})
		print("OPENING_ANIMATIC_VOICE: ", line.id, " / ", seconds, "s")
	var file := FileAccess.open(BASE + "voices.json", FileAccess.WRITE)
	if file == null:
		fail("Cannot write voice manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	speech.queue_free()
	await process_frame
	quit()
