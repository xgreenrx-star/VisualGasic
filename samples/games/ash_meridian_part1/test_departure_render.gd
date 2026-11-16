extends SceneTree

var failures := 0
var game: Node2D
var output_dir := "user://departure_render"

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(240).timeout.connect(func() -> void:
		push_error("Departure visual regression timed out")
		quit(1)
	)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output_dir = arg.trim_prefix("--capture-dir=")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir)) != OK:
		push_error("Cannot create departure capture directory: " + output_dir)
		quit(1)
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var boot: Object = game.get("boot_term")
	if boot != null:
		boot.get("sfx").call("stop")
	game.call("ReleaseBootTerminal")
	game.set("phase", 12)
	game.set("dev_on", true)
	game.set("dev_i", 23)
	game.call("WarpDev")
	var view: Object = game.get("presentation")
	var preview: Object = view.get("level1_departure")
	if preview == null:
		push_error("Actual dev-menu launch failed")
		game.free()
		quit(1)
		return
	check(root.size.x >= 1280 and root.size.y >= 720, "verification uses a real HD game window")
	for shot in range(3):
		for fraction: float in [0.0, 0.5, 0.99]:
			preview.set("shot", shot)
			preview.set("shot_elapsed", fraction * float(preview.call("shot_duration")))
			preview.set("elapsed", fraction * 10.0)
			await _capture("%d_%02d" % [shot, roundi(fraction * 100)], shot, preview)
	preview.set("shot", 3)
	preview.set("deal_line", -1)
	await _capture("3_rest", 3, preview)
	await _check_cabin_enclosure(preview, "rest")
	var lines: Array = preview.get("radio_lines")
	var capture_turns := [0, int(preview.get("call_end_line")), lines.size() - 1]
	for phrase: String in ["JASON: A ship.", "BUYER / RADIO: I have a Kestrel-class", "ORAC: The records include",
		"JASON: I need the Antique before", "BUYER / RADIO: And what stops", "JASON: To an independent",
		"JASON: I return the Antique."]:
		var found := -1
		for i in range(lines.size()):
			if str(lines[i]).begins_with(phrase):
				found = i
				break
		check(found >= 0, "capture finds negotiation beat " + phrase)
		capture_turns.append(found)
	for index in range(int(preview.get("radio_lines").size())):
		preview.set("deal_line", index)
		if index in capture_turns:
			await _capture("3_radio_%02d" % index, 3, preview)
		else:
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(game.get("departure_ui_caption").get_line_count() <= 2, "radio turn %d fits the caption panel" % index)
	await _check_cabin_enclosure(preview, "call")
	preview.set("shot", 4)
	await _capture("4_complete", 4, preview)
	await _check_cabin_enclosure(preview, "completion")
	for profile_shot in [0, 3]:
		preview.set("shot", profile_shot)
		preview.set("deal_line", 4 if profile_shot == 3 else -1)
		await _profile_frames(preview, profile_shot)
	view.call("restart_level1_departure")
	await _capture("0_replay", 0, preview)
	preview.set("shot_elapsed", 7.0)
	game.set_process(true)
	await _press_key(KEY_R)
	check(preview.get("shot") == 0 and preview.get("shot_elapsed") < 1.0, "R input replays departure")
	await _press_key(KEY_ESCAPE)
	game.set_process(false)
	check(view.get("level1_departure") == null and game.get("dev_on"), "Escape input returns to dev menu and releases preview")
	check(view.get("viewport").size == Vector2i(960, 540), "exit restores gameplay render resolution")
	game.free()
	for i in range(3):
		await process_frame
	print("DEPARTURE_RENDER_FAILURES=", failures)
	print("DEPARTURE_CAPTURES=", ProjectSettings.globalize_path(output_dir))
	quit(1 if failures else 0)

func _profile_frames(preview: Object, shot: int) -> void:
	var draw_ms := 0.0
	var frame_ms := 0.0
	for i in range(20):
		var frame_start := Time.get_ticks_usec()
		preview.set("elapsed", float(i) / 60)
		var draw_start := Time.get_ticks_usec()
		game.call("DrawLevel1Departure")
		draw_ms += (Time.get_ticks_usec() - draw_start) / 1000.0
		await process_frame
		await RenderingServer.frame_post_draw
		frame_ms += (Time.get_ticks_usec() - frame_start) / 1000.0
	print("DEPARTURE_PROFILE shot=", shot, " cpu_present_ms=", draw_ms / 20,
		" frame_ms=", frame_ms / 20, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	check(Input.is_key_pressed(key), "synthetic key reaches Godot input " + str(key))
	await process_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func _check_cabin_enclosure(preview: Object, label: String) -> void:
	var environment: Environment = preview.get("environment")
	var cabin: Node3D = preview.get("cabin")
	var previous_color := environment.background_color
	environment.background_color = Color(1, 0, 1)
	for i in range(2):
		await process_frame
		await RenderingServer.frame_post_draw
	var image: Image = preview.get("viewport").get_texture().get_image()
	check(_background_fraction(image) < 0.001, label + " room geometry occludes the entire background, including screen edges")
	cabin.visible = false
	for i in range(2):
		await process_frame
		await RenderingServer.frame_post_draw
	image = preview.get("viewport").get_texture().get_image()
	check(_background_fraction(image) > 0.95, label + " enclosure test detects exposed background when the room is hidden")
	cabin.visible = true
	environment.background_color = previous_color

func _background_fraction(image: Image) -> float:
	var exposed := 0
	var total := 0
	for y in range(0, image.get_height(), 5):
		for x in range(0, image.get_width(), 5):
			var color := image.get_pixel(x, y)
			if color.r > 0.4 and color.b > 0.4 and color.g < 0.1:
				exposed += 1
			total += 1
	return float(exposed) / total

func _capture(label: String, shot: int, preview: Object) -> void:
	for i in range(5):
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(output_dir.path_join(label + ".png")) == OK, "saved actual game window " + label)
	var lit := 0
	var sampled := 0
	var warm := 0
	for y in range(roundi(image.get_height() * 0.19), roundi(image.get_height() * 0.88), 4):
		for x in range(0, image.get_width(), 4):
			var color := image.get_pixel(x, y)
			if color.get_luminance() > 0.035:
				lit += 1
			if color.r > color.b * 1.15 and color.r > 0.08:
				warm += 1
			sampled += 1
	var coverage := float(lit) / sampled
	print("RENDER_COVERAGE ", label, " ", coverage)
	var minimum := 0.02 if shot < 3 else 0.3
	check(coverage > minimum, label + " has rendered artwork, not captions over black")
	if shot == 0:
		check(float(warm) / sampled > 0.025, label + " shows the ochre world, not a blue replacement")
	if shot < 3:
		var camera: Camera3D = preview.get("camera")
		var ship: Node3D = preview.get("ship")
		var position := camera.unproject_position(ship.global_position)
		var viewport_size: Vector2i = preview.get("viewport").size
		var half_size := Vector2(viewport_size) * 0.5
		check(absf(position.x - half_size.x) < half_size.x * 0.9 and absf(position.y - half_size.y) < half_size.y * 0.7,
			label + " ship center remains inside the caption-safe picture")
		if shot == 2:
			var station: Node3D = preview.get("station")
			for x: float in [-74.0, 74.0]:
				for y: float in [-40.0, 40.0]:
					var corner := camera.unproject_position(station.global_position + Vector3(x, y, 0))
					check(corner.x > viewport_size.x * 0.04 and corner.x < viewport_size.x * 0.96
						and corner.y > viewport_size.y * 0.18 and corner.y < viewport_size.y * 0.89,
						label + " station facade stays fully inside the picture " + str(Vector2(x, y)))
	if shot == 3:
		var caption: Label = game.get("departure_ui_caption")
		check(caption.get_line_count() <= 2, label + " caption fits without clipping")
