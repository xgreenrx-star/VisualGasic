extends SceneTree

const OUTPUT := "res://assets/audio/club/alien/"
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
	for section: String in dialogue:
		for i in dialogue[section].size():
			var line: Dictionary = dialogue[section][i]
			var speaker: String = line["speaker"]
			var profile := "bm_lewis" if speaker == "ALIEN" else speaker
			var speed := 0.94 if speaker == "ALIEN" else float(speech.call("DeliverySpeed", profile, 0))
			var silence := 0.32 if speaker == "ALIEN" else float(speech.call("DeliverySilence", profile, 0))
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
			manifest.append({"audio": output, "speaker": speaker, "profile": profile,
				"sid": speech.call("KokoroSpeakerId", profile), "speed": speed,
				"silence": silence, "text": line["speech"], "backend": "kokoro"})
			print("CLUB_NEURAL_VOICE: ", output, " / ", profile)
	var file := FileAccess.open(OUTPUT + "voices.json", FileAccess.WRITE)
	if file == null:
		fail("Cannot write voice provenance manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	speech.queue_free()
	await process_frame
	quit()
