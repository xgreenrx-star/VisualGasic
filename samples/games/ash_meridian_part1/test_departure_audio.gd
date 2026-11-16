extends SceneTree

var failures := 0
var checks := 0

class VoiceOptions extends Node:
	var opt_orac_voice := true

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := VoiceOptions.new()
	root.add_child(game)
	for bus: StringName in [&"Music", &"SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	var preview := Node3D.new()
	preview.set_script(load("res://level1_departure.vg"))
	root.add_child(preview)
	preview.call("EnsureInit")
	var audio: Object = Node.new()
	audio.set_script(load("res://departure_audio.vg"))
	root.add_child(audio)
	check(audio.setup(game), "all recordings and ambience decode")
	if not audio.ready_audio:
		game.free()
		preview.free()
		audio.free()
		quit(1)
		return
	check(audio.music_player.stream.loop and is_equal_approx(audio.music_player.stream.get_length(), 48.0),
		"station soundtrack is a full 48-second loop")
	for caption: String in preview.get("radio_lines"):
		check(audio.clips.has(caption) and audio.clips[caption].get_length() > 0.5, "voiced negotiation: " + caption)
		audio.present(caption, 3, "connected")
		check(audio.voice_player.playing, "recorded voice starts immediately")
		check(audio.voice_player.bus == (&"DepartureRadio" if caption.begins_with("BUYER / RADIO:") else &"SFX"),
			"only remote speaker uses transmission filter")
	var boundaries := [[0.0, 5.0, 10.0, 14.0], [0.0, 4.0, 13.0, 18.0], [0.0, 7.0, 15.0, 19.0]]
	for shot in range(3):
		preview.set("shot", shot)
		for beat in range(3):
			preview.set("shot_elapsed", boundaries[shot][beat])
			var caption: String = preview.call("caption")
			check(audio.clips.has(caption), "flight caption has recording")
			if audio.clips.has(caption):
				check(audio.clips[caption].get_length() <= boundaries[shot][beat + 1] - boundaries[shot][beat],
					"flight voice finishes before next caption: " + caption)
	audio.present("BUYER / RADIO: Agreed. Now send the site.", 3, "connected")
	check(audio.static_player.playing and audio.music_player.playing, "radio interference and station music play")
	check(audio.music_player.volume_db <= -22.0, "music ducks immediately for the first spoken word")
	audio.tick(0.1)
	check(audio.music_player.volume_db < -14.0, "music ducks beneath speech")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var master := AudioServer.get_bus_index(&"Master")
	var effect_index := AudioServer.get_bus_effect_count(master)
	AudioServer.add_bus_effect(master, capture)
	await create_timer(0.4).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample: Vector2 in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(samples.size() > 1000 and peak > 0.0001, "voice, radio and music produce actual mixed audio samples")
	check(peak < 0.99, "combined radio/music mix does not clip")
	AudioServer.remove_bus_effect(master, effect_index)
	game.set("opt_orac_voice", false)
	audio.tick(0.1)
	check(not audio.voice_player.playing and not audio.static_player.playing, "speech mute stops voice and interference")
	game.set("opt_orac_voice", true)
	audio.restart()
	audio.present("JASON: Tell me we're clear.", 0, "closed")
	check(audio.engine_player.playing and audio.voice_player.playing and not audio.music_player.playing, "replay starts flight audio, not station music")
	audio.present("The Ash is berthed. For six hours, nobody needs anything from Jason.", 3, "idle")
	check(not audio.voice_player.playing and not audio.engine_player.playing and audio.music_player.playing, "rest has station music without voice or flight engines")
	audio.stop()
	check(not audio.music_player.playing and not audio.cue_player.playing and not audio.static_player.playing and not audio.ring_player.playing, "exit stops all departure audio")
	audio.restart()
	audio.present("The Ash is berthed. For six hours, nobody needs anything from Jason.", 3, "idle")
	audio.tick(1.0)
	check(not audio.ring_player.playing and not audio.conversation_ready(), "rest holds before telephone rings")
	audio.tick(1.1)
	check(audio.ring_player.playing and not audio.conversation_ready(), "telephone rings before Orac announces the call")
	audio.tick(3.0)
	check(audio.conversation_ready(), "call begins automatically after ringing")
	audio.present("ORAC: Jason. Incoming call.", 3, "incoming")
	audio.tick(100.0)
	check(not audio.conversation_ready(), "automatic progression never cuts off a playing recording")
	audio.voice_player.stop()
	check(audio.conversation_ready(), "finished recording advances after its trailing pause")
	audio.present("BUYER / RADIO: Agreed. Now send the site.", 3, "connected")
	check(not audio.ring_player.playing and audio.voice_player.volume_db == 5.0, "answer stops ringing and buyer gains eight dB")
	audio.tick(0.1)
	check(audio.static_player.volume_db >= -32.0, "radio static has an audible baseline and crackle bursts")
	game.opt_orac_voice = false
	var world := Node3D.new()
	preview.set("scene_root", world)
	preview.set("audio", audio)
	preview.set("shot", 3)
	preview.set("deal_line", -1)
	audio.restart()
	preview.call("tick", 5.1)
	check(preview.get("deal_line") == 0, "scene automatically answers without input")
	var lines: Array = preview.get("radio_lines")
	for i in range(lines.size()):
		check(preview.get("deal_line") == i, "hands-free subtitle turn " + str(i))
		preview.call("tick", 60.0)
	check(preview.get("shot") == 4, "entire muted conversation completes without Space")
	preview.set("scene_root", null)
	preview.set("audio", null)
	world.free()
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"DepartureRadio")) == 3, "radio uses high pass, low pass and restrained saturation")
	audio.free()
	preview.free()
	game.free()
	# Allow the audio thread to release stopped playback buffers before shutdown.
	await create_timer(0.3).timeout
	await process_frame
	await process_frame
	print("DEPARTURE_AUDIO_RESULT=", checks - failures, "/", checks, " FAILURES=", failures)
	quit(1 if failures else 0)
