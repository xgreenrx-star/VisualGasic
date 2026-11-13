extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var resource := load("res://opening_bar_study.tscn") as PackedScene
	if resource == null:
		push_error("Cannot load bar study scene")
		quit(1)
		return
	var stage := resource.instantiate()
	if stage.get_script() == null:
		push_error("Bar study script failed to compile")
		stage.free()
		quit(1)
		return
	root.add_child(stage)
	await process_frame
	stage.set_process(false)
	check(stage.ready_for_review, "bar stage loads canonical edit and voices")
	if not stage.ready_for_review:
		stage.free()
		quit(1)
		return
	check(stage.lines.size() == 15 and stage.clips.size() == 15, "bar uses only its fifteen canonical lines")
	var departure_at := -1.0
	for shot: Dictionary in stage.timeline.shots:
		if shot.id == "departure":
			departure_at = float(shot.at)
	check(absf(stage.duration - departure_at) < 0.02, "bar ends at the measured station departure")
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	check(main_scene == "res://main.tscn", "campaign entry point unchanged")
	check(stage.materials.MARK_skin != stage.materials.JASON_skin, "characters retain separate surface identities")
	check(stage.speech_envelopes.size() == 15, "all bar lines have clip-derived performance")
	check(stage.speech_amount("MARK", 1) == 0.0 and stage.speech_amount("JASON", 1) == 0.0, "both mouths rest during silence")
	for line: Dictionary in stage.lines:
		var envelope: Dictionary = stage.speech_envelopes[line.id]
		var peak := 0.0
		var peak_time := 0.0
		for i in range(envelope.samples.size()):
			if float(envelope.samples[i]) > peak:
				peak = float(envelope.samples[i])
				peak_time = float(line.at) + i / 50.0
		check(peak > 0.1, "line %s has real voiced energy" % line.id)
		check(absf(stage.speech_amount(line.speaker, peak_time) - peak) < 0.001, "jaw follows recorded energy for line " + str(line.id))
		var listener := "JASON" if line.speaker == "MARK" else "MARK"
		check(stage.speech_amount(listener, peak_time) == 0, "listener mouth stays still for line " + str(line.id))
	stage.seek(20.0)
	var initial_mouth: Vector3 = stage.actors.MARK.features.lower_lip.position
	stage.seek(40.0)
	stage.seek(20.0)
	check(stage.actors.MARK.features.lower_lip.position.is_equal_approx(initial_mouth), "scrubbed facial pose is deterministic")
	var worst := INF
	var longest_upper := 0.0
	var longest_forearm := 0.0
	var worst_forearm_ratio := 0.0
	var max_wrist_reach := 0.0
	var highest_lap_wrist := 0.0
	var hidden_hands := true
	for tick in range(int(stage.duration * 10)):
		stage.seek(tick / 10.0)
		var clearance: float = stage.lap_rest_table_edge_clearance()
		worst = minf(worst, clearance)
		for identity in ["MARK", "JASON"]:
			var actor: Dictionary = stage.actors[identity]
			for arm: Dictionary in actor.arms:
				var pose: Dictionary = arm.pose
				var upper_length: float = pose.shoulder.distance_to(pose.elbow)
				var forearm_length: float = pose.elbow.distance_to(pose.wrist)
				longest_upper = maxf(longest_upper, upper_length)
				longest_forearm = maxf(longest_forearm, forearm_length)
				worst_forearm_ratio = maxf(worst_forearm_ratio, forearm_length / upper_length)
				max_wrist_reach = maxf(max_wrist_reach, arm.rest_wrist.distance_to(pose.wrist))
				highest_lap_wrist = maxf(highest_lap_wrist, pose.wrist.y)
				hidden_hands = hidden_hands and not (arm.hand as Node3D).visible
		if clearance < 0.002:
			check(false, "lap-rest arm/table-edge clearance at %.2fs: %.4fm" % [tick / 10.0, clearance])
			break
	check(worst >= 0.002, "lap-rest arms stay outside the tabletop footprint throughout staging")
	check(longest_upper <= 0.44 and longest_forearm <= 0.35, "blocked arm lengths stay in range (upper %.3fm, forearm %.3fm)" % [longest_upper, longest_forearm])
	check(worst_forearm_ratio <= 0.9, "forearms do not exceed the corresponding upper-arm length")
	check(highest_lap_wrist < stage.TABLE_TOP - 0.2, "wrists stay below tabletop in a lap-rest pose")
	check(hidden_hands, "hands remain hidden instead of showing the rejected wrist/hand pose")
	check(max_wrist_reach <= 0.06, "lap-rest arms move no more than 6 cm during the interrupted rise")
	for sample in [0.0, 15.0, 20.0, 24.5, 28.0, 34.0, 40.0, 46.0, 51.0, 57.0, 64.8, 70.0, 77.0]:
		stage.seek(sample)
		var camera: Camera3D = stage.camera
		var actor: Dictionary = stage.actors.JASON if sample in [24.5, 40.0, 64.8] else stage.actors.MARK
		var head: Node3D = actor.head
		check(not camera.is_position_behind(head.global_position), "coverage has subject in front at %ss" % sample)
		var projected := camera.unproject_position(head.global_position)
		check(Rect2(Vector2(50, 42), root.size - Vector2i(100, 160)).has_point(projected), "subject clear of letterbox/subtitles at %ss" % sample)
	stage.seek(20.0)
	stage.toggle_playback()
	check(stage.playing and stage.voice.playing, "warning starts canonical speech")
	check(stage.speaker.text == "MARK" and stage.subtitle.text == stage.lines[4].text, "speech and exact subtitle agree")
	var initial_id: String = stage.active_id
	var initial_audio: float = stage.voice.get_playback_position()
	var audio_deadline := Time.get_ticks_msec() + 2000
	while stage.voice.get_playback_position() <= initial_audio + 0.04 and Time.get_ticks_msec() < audio_deadline:
		await create_timer(0.05).timeout
	var voice_at: float = stage.voice.get_playback_position()
	print("BAR_AUDIO_PROBE: initial=%.4f advanced=%.4f" % [initial_audio, voice_at])
	check(voice_at > initial_audio + 0.04, "real audio playback advances from the authored seek offset")
	stage.pause()
	var paused_at: float = stage.position_seconds
	var paused_audio: float = stage.voice.get_playback_position()
	await create_timer(0.1).timeout
	stage._process(0.5)
	check(stage.position_seconds == paused_at and stage.voice.stream_paused, "pause freezes staging and speech")
	check(absf(stage.voice.get_playback_position() - paused_audio) < 0.05, "paused audio position does not advance")
	stage.toggle_playback()
	check(stage.active_id == initial_id and not stage.voice.stream_paused, "resume does not restart line")
	check(absf(stage.voice.get_playback_position() - paused_audio) < 0.08, "resume preserves speech offset")
	stage.mute.button_pressed = true
	check(not stage.voice.playing and not stage.subtitle.text.is_empty(), "mute retains subtitles and stops voice")
	var muted_lip: Vector3 = stage.actors.MARK.features.lower_lip.position
	check(muted_lip.is_equal_approx(initial_mouth), "muting does not remove authored mouth motion")
	stage.seek(40.0)
	check(stage.speaker.text == "JASON" and not stage.voice.playing, "muted scrub updates speaker without audio")
	stage.mute.button_pressed = false
	check(stage.voice.playing and stage.active_id == "09", "unmute resumes current line at seek position")
	stage.skip_study()
	check(stage.finished and not stage.playing and not stage.voice.playing, "skip stops all playback at study handoff")
	check(stage.subtitle.text.contains("separate production"), "study does not impersonate game handoff")
	stage.seek(0)
	check(not stage.finished and stage.position_seconds == 0 and not stage.voice.playing, "restart resets without accidental speech")
	stage.set_presentation_mode()
	check(not stage.review_controls[0].visible and stage.caption_panel.visible, "movie presentation hides controls but retains subtitles")
	var weak_voice: WeakRef = weakref(stage.voice)
	stage.free()
	await create_timer(0.2).timeout
	check(weak_voice.get_ref() == null, "freeing stage releases voice player")
	print("OPENING_BAR_TESTS: %d checks / %d failures / minimum table-edge gap %.4fm" % [checks, failures, worst])
	quit(1 if failures else 0)
