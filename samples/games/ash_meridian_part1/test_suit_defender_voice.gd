extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func rendered_face(feedback: Node) -> Image:
	var viewport: SubViewport = feedback.get("face_view")
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	feedback.get("defender").queue_redraw()
	for index in range(3):
		await process_frame
	return viewport.get_texture().get_image()

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set("opt_orac_voice", true)
	game.set("dev_i", 20)
	game.call("WarpDev")
	var ring: Node = game.get("ownership_ring")
	var feedback: Node = ring.get("terminal_feedback")
	feedback.set_process(false)
	var voice: Node = feedback.get("defender_voice")
	var face: Node = feedback.get("defender")
	ring.call("set_help", false)
	ring.call("begin_round")
	check(voice.get("last_intent") == "threat", "round_starts_with_alien_threat")
	var player: AudioStreamPlayer = voice.get("player")
	check(player.playing and player.bus == "SFX", "existing_narcean_audio_plays_through_sfx_bus")
	check(player.volume_db == -3, "alien_voice_is_six_db_louder_without_orac")
	check(player.stream.get_length() > 8, "existing_alien_voice_asset_loaded")
	check(not voice.call("say", "insult"), "taunts_cannot_spam_or_queue")
	ring.call("claim_sector", 0, -1)
	ring.call("claim_sector", 0, 1)
	check(voice.get("last_intent") == "shock", "stealing_defender_sector_triggers_shock")
	var count: int = voice.get("phrase_count")
	for sector in range(1, 4):
		ring.call("claim_sector", sector, 1)
	check(voice.get("phrase_count") == count, "continuing_stream_does_not_repeat_shock")
	for sector in range(4, 7):
		ring.call("claim_sector", sector, 1)
	check(voice.get("last_intent") == "curse", "winning_majority_triggers_angry_curse")
	voice.call("advance", 0.1, true)
	check(player.stream_paused and voice.call("mouth_level") == 0, "pause_freezes_speech_and_mouth")
	voice.call("advance", 0.1, false)
	check(not player.stream_paused, "voice_resumes_after_pause")
	ring.hide()
	feedback.call("_process", 0.1)
	check(player.stream_paused and voice.get("active_round"), "hidden_pause_preserves_active_defender_round")
	ring.show()
	feedback.call("_process", 0.1)
	check(not player.stream_paused and voice.get("active_round"), "visible_resume_restores_defender_reactions")
	for intent in voice.PHRASES:
		voice.call("say", intent, true)
		var first: Array = voice.get("segments").duplicate(true)
		voice.call("say", intent, true)
		check(first != voice.get("segments"), "different_phrase_variant_" + intent)
		for variant in voice.PHRASES[intent]:
			for segment in variant:
				check(segment[0] >= 0 and segment[0] + segment[1] < player.stream.get_length(), "phrase_segment_within_recorded_source")
	voice.call("say", "shock", true)
	player.seek(0)
	feedback.set("mode", "DEFENDER")
	feedback.call("update_displays")
	check(face.get("mode") == "talk" and face.get("voice_level") > 0, "mouth_uses_actual_playback_envelope")
	face.call("set_time", 1.0)
	var first_pose: Vector2 = face.call("posed", Vector2(510, 680), Vector2(1, 0))
	face.call("set_time", 1.2)
	var next_pose: Vector2 = face.call("posed", Vector2(510, 680), Vector2(1, 0))
	check(not first_pose.is_equal_approx(next_pose), "head_moves_while_speaking")
	face.call("set_mode", "idle")
	var closed: Vector2 = face.call("posed", Vector2(510, 680), Vector2(1, 0))
	check(closed.distance_to(next_pose) > 5, "spoken_syllable_opens_weighted_jaw")
	if DisplayServer.get_name() != "headless":
		var closed_image := await rendered_face(feedback)
		face.call("set_mode", "talk")
		face.call("set_voice_level", 0.75)
		face.call("set_time", 1.4)
		var talking_image := await rendered_face(feedback)
		var changed := 0
		for y in range(closed_image.get_height()):
			for x in range(closed_image.get_width()):
				if closed_image.get_pixel(x, y) != talking_image.get_pixel(x, y):
					changed += 1
		check(changed > 1000, "speaking_head_and_jaw_change_rendered_face_pixels")
	ring.set("reduced_motion", true)
	feedback.call("update_displays")
	face.call("set_time", 3)
	var reduced: Vector2 = face.call("posed", Vector2(510, 680), Vector2(1, 0))
	face.call("set_time", 4)
	check(reduced == face.call("posed", Vector2(510, 680), Vector2(1, 0)), "reduced_motion_holds_face_steady")
	check(ring.get("orac_message") == "", "alien_speech_never_adds_subtitles")
	ring.call("finish_round")
	check(voice.get("last_intent") == "curse", "defeated_defender_curses")
	game.set("opt_orac_voice", false)
	voice.call("advance", 0.1, false)
	check(not player.playing, "speech_option_stops_alien_voice")
	voice.call("say", "shock", true)
	check(not player.playing and voice.get("emotion") == "shock", "speech_off_retains_visual_reaction_without_audio")
	game.set("opt_orac_voice", true)
	voice.call("say", "insult", true)
	ring.call("leave_terminal")
	check(not player.playing and voice.get("segments").is_empty(), "scene_exit_clears_voice")
	ring.call("start_loader")
	check(not player.playing and not voice.get("active_round"), "terminal_mode_never_plays_defender_speech")
	game.queue_free()
	await process_frame
	print("SUIT_DEFENDER_VOICE_COMPLETED: ", failures, " failures")
	quit(failures)
