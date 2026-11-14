extends SceneTree

const OUTPUT := "res://assets/audio/club/alien/"
const VOICE_MANIFEST := OUTPUT + "voices.json"
var speech: Node

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error("Club voice bake: " + message)
	speech.call("stop")
	speech.queue_free()
	quit(1)

func run() -> void:
	speech = Node.new()
	speech.set_script(load("res://flight_speech.vg"))
	root.add_child(speech)
	speech.call("configure", false)
	if not speech.call("KokoroReady"):
		fail("Install the game's local Kokoro tools; robotic fallback voices are not accepted.")
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://assets/ai_face/club_alien_dialogue.json")) != OK:
		fail(json.get_error_message())
		return
	var dialogue: Dictionary = json.data
	var manifest := []
	var generated_manifest := []
	var selected_section := OS.get_environment("ASH_CLUB_VOICE_SECTION")
	if selected_section != "" and not dialogue.has(selected_section):
		fail("Unknown dialogue section: " + selected_section)
		return
	if selected_section != "":
		if not FileAccess.file_exists(VOICE_MANIFEST):
			fail("Cannot update one section because the existing voice manifest is missing.")
			return
		var existing_json := JSON.new()
		if existing_json.parse(FileAccess.get_file_as_string(VOICE_MANIFEST)) != OK or not existing_json.data is Array:
			fail("The existing voice manifest is invalid.")
			return
		for entry: Dictionary in existing_json.data:
			if not str(entry.get("audio", "")).contains("/" + selected_section + "_"):
				manifest.append(entry)
	for section: String in dialogue:
		if selected_section != "" and section != selected_section:
			continue
		for i in dialogue[section].size():
			var line: Dictionary = dialogue[section][i]
			var speaker: String = line["speaker"]
			var profile := "bm_lewis" if speaker == "ALIEN" else "am_michael" if speaker == "ALIEN_ASIDE" else speaker
			var is_alien := speaker == "ALIEN" or speaker == "ALIEN_ASIDE"
			var speed := 0.94 if is_alien else float(speech.call("DeliverySpeed", profile, 0))
			var silence := 0.32 if is_alien else float(speech.call("DeliverySilence", profile, 0))
			var wav := ProjectSettings.globalize_path("user://club-voice-bake-%s.wav" % OS.get_process_id())
			var output := OUTPUT + section + "_" + str(i) + ".ogg"
			if not speech.call("SubmitDaemonJob", line["speech"], wav, profile, speed, silence):
				fail("Cannot submit neural voice job for " + output)
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
				fail("Neural synthesis failed or timed out for " + output)
				return
			var errors := []
			var result := OS.execute("ffmpeg", ["-v", "error", "-y", "-i", wav,
				"-ar", "48000", "-c:a", "libvorbis", "-q:a", "5",
				ProjectSettings.globalize_path(output)], errors, true)
			DirAccess.remove_absolute(wav)
			if result != 0:
				fail("Cannot encode " + output + ": " + str(errors))
				return
			generated_manifest.append({"audio": output, "speaker": speaker, "profile": profile,
				"sid": speech.call("KokoroSpeakerId", profile), "speed": speed,
				"silence": silence, "text": line["speech"], "backend": "kokoro"})
			print("CLUB_NEURAL_VOICE: ", output, " / ", profile)
	manifest.append_array(generated_manifest)
	var file := FileAccess.open(VOICE_MANIFEST, FileAccess.WRITE)
	if file == null:
		fail("Cannot write voice provenance manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	speech.queue_free()
	await process_frame
	quit()
