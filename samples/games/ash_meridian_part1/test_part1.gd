extends SceneTree

var failures := 0
var checks := 0
var options_path := "user://ash_meridian_options.txt"
var options_existed := false
var options_bytes := PackedByteArray()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tick_menu(game: Node) -> void:
	game.set_process(true)
	await process_frame
	await process_frame
	game.set_process(false)

func tap_key(game: Node, code: Key) -> void:
	key(code, true)
	await tick_menu(game)
	key(code, false)
	await tick_menu(game)

func event_pos(game: Node, canvas_pos: Vector2) -> Vector2:
	return game.get_viewport().get_screen_transform() * canvas_pos

func send_mouse(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func mouse_at(game: Node, canvas_pos: Vector2) -> void:
	var pos := event_pos(game, canvas_pos)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	send_mouse(motion)

func click_at(game: Node, canvas_pos: Vector2) -> void:
	mouse_at(game, canvas_pos)
	var pos := event_pos(game, canvas_pos)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	send_mouse(down)
	await tick_menu(game)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	send_mouse(up)
	await tick_menu(game)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	options_existed = FileAccess.file_exists(options_path)
	if options_existed:
		options_bytes = FileAccess.get_file_as_bytes(options_path)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set("phase", 12)
	game.set("title_i", 1 if game.call("TitleCount") == 3 else 2)
	key(KEY_ENTER, true)
	await tick_menu(game)
	check(game.get("phase") == 13, "Enter on Options opens options")
	await tick_menu(game)
	check(game.get("phase") == 13, "Held Enter must not close options")
	key(KEY_ENTER, false)
	await tick_menu(game)
	var old_view: float = game.get("opt_view")
	game.set("opt_view", 80.0)
	key(KEY_ENTER, true)
	await tick_menu(game)
	check(game.get("phase") == 13, "Enter on view distance changes the option, not the screen")
	check(game.get("opt_view") == 90.0, "Enter applies exactly one option increment")
	game.set("opt_view", old_view)
	key(KEY_ENTER, false)
	await tick_menu(game)
	key(KEY_ESCAPE, true)
	await tick_menu(game)
	check(game.get("phase") == 12, "Escape returns to title")
	key(KEY_ESCAPE, false)
	await tick_menu(game)
	var title_index: int = game.get("title_i")
	await tap_key(game, KEY_W)
	check(game.get("title_i") == (title_index - 1 + int(game.call("TitleCount"))) % int(game.call("TitleCount")), "W navigates the title menu")
	await tap_key(game, KEY_DOWN)
	check(game.get("title_i") == title_index, "Arrow keys navigate the title menu")
	await tap_key(game, KEY_SPACE)
	check(game.get("phase") == 13, "Space opens Options without activating the next screen")
	game.set("opt_view", 80.0)
	await tap_key(game, KEY_LEFT)
	check(game.get("opt_view") == 70.0, "Left decreases the selected option once")
	await tap_key(game, KEY_D)
	check(game.get("opt_view") == 80.0, "D increases the selected option once")
	game.set("opt_view", old_view)
	game.set("opt_i", 6)
	game.set("opt_orac_voice", false)
	game.set("opt_flight_voice", false)
	await tap_key(game, KEY_RIGHT)
	check(game.get("opt_orac_voice"), "Right enables speech")
	check(game.get("opt_flight_voice"), "Speech toggle keeps flight voice in sync")
	await tap_key(game, KEY_LEFT)
	check(not game.get("opt_orac_voice"), "Left disables speech")
	check(not game.get("opt_flight_voice"), "Disabling speech mutes flight voice too")
	game.set("opt_i", 7)
	await tap_key(game, KEY_SPACE)
	check(game.get("phase") == 12, "Space on Back returns to the title")
	var options_row: int = 1 if int(game.call("TitleCount")) == 3 else 2
	await click_at(game, Vector2(480, 220.0 + options_row * 48.0 + 8.0))
	check(game.get("phase") == 13, "Clicking OPTIONS opens options")
	await click_at(game, Vector2(480, 475))
	check(game.get("phase") == 12, "Clicking BACK leaves options")
	game.set("phase", 2)
	game.set("menu_on", true)
	game.set("menu_i", 0)
	await click_at(game, Vector2(480, 306))
	check(game.get("phase") == 13, "Clicking pause OPTIONS opens options")
	await click_at(game, Vector2(480, 475))
	check(game.get("phase") == 2 and game.get("menu_on"), "Clicking BACK restores the pause menu")
	game.set("phase", 2)
	game.set("menu_on", false)
	await tap_key(game, KEY_ESCAPE)
	check(game.get("menu_on"), "Escape pauses gameplay")
	game.set("menu_i", 2)
	await tick_menu(game)
	key(KEY_ENTER, true)
	await tick_menu(game)
	check(game.get("phase") == 13, "Pause Options opens options")
	await tick_menu(game)
	check(game.get("phase") == 13, "Held Enter stays in pause options")
	key(KEY_ENTER, false)
	await tick_menu(game)
	key(KEY_ESCAPE, true)
	await tick_menu(game)
	check(game.get("phase") == 2 and game.get("menu_on"), "Escape from pause options restores paused game")
	key(KEY_ESCAPE, false)
	await tick_menu(game)
	await tap_key(game, KEY_ESCAPE)
	check(not game.get("menu_on"), "Escape resumes paused gameplay")
	game.call("StartRun")
	check(game.get("phase") == 0, "Play starts on the intro")
	game.set("clock", 26.0)
	await tap_key(game, KEY_SPACE)
	check(game.get("phase") == 0, "Space before the last-chance line does not start the approach")
	game.set("clock", 33.0)
	await tap_key(game, KEY_SPACE)
	check(game.get("phase") == 1, "Space after the last-chance line starts the approach")
	game.call("StartRun")
	game.set("phase", 2)
	game.set("on_buggy", true)
	game.set("px", 6.4)
	game.set("pz", -18.0)
	game.set("opt_fps", false)
	if OS.get_environment("ASH_VIEW") == "cockpit":
		game.set("phase", 0)
	elif OS.get_environment("ASH_VIEW") == "turret":
		game.set("on_buggy", false)
		game.set("px", -6.0)
		game.set("pz", 67.0)
		game.set("yaw", -0.85)
	elif OS.get_environment("ASH_VIEW") == "city":
		game.set("on_buggy", false)
		game.set("px", 0.0)
		game.set("pz", 32.0)
	elif OS.get_environment("ASH_VIEW") == "landing":
		game.set("phase", 1)
		game.set("ship_z", 110.0)
		game.set("ship_x", 0.2)
		game.set("ship_alt", -0.4)
		game.set("next_ring", 5)
		game.set("landing_speed", 16.8)
		if OS.get_environment("ASH_LAND_Z") != "":
			game.set("ship_z", float(OS.get_environment("ASH_LAND_Z")))
			game.set("next_ring", int((float(OS.get_environment("ASH_LAND_Z")) - 26.0) / 20.0) + 1)
		if OS.get_environment("ASH_LAND_HURT") != "":
			game.set("hurt", float(OS.get_environment("ASH_LAND_HURT")))
			game.set("ring_miss", 1)
	game.set("clock", 8.0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Warm the geometry cache separately from steady-state camera frames.
	for frame in 3:
		game.queue_redraw()
		await process_frame
	var renderer = game.get_node("Presentation")
	check(load("res://buggy_art.gd").can_instantiate(), "Buggy cockpit art loads successfully")
	var rebuilds: int = renderer.rebuild_count
	var start := Time.get_ticks_usec()
	for frame in 12:
		game.queue_redraw()
		await process_frame
	print("YARD_FRAME_US=", (Time.get_ticks_usec() - start) / 12)
	if game.get("phase") == 2:
		check(renderer.rebuild_count == rebuilds, "Unchanged yard is reused instead of rebuilt per frame")
		var faces: ArrayMesh = renderer.world_mesh.mesh
		check(faces != null and faces.get_surface_count() == 2, "Yard batches solid faces and neon edges")
	if OS.get_environment("ASH_CAPTURE") != "":
		var can_capture := DisplayServer.get_name() != "headless"
		check(can_capture, "Screenshot capture requires a rendering display")
		if can_capture:
			game.queue_redraw()
			await RenderingServer.frame_post_draw
			var capture: Image = root.get_texture().get_image()
			check(capture.save_png(OS.get_environment("ASH_CAPTURE")) == OK, "Screenshot was saved successfully")
			if game.get("phase") == 1:
				var text_pixels := 0
				var scale := Vector2(capture.get_size()) / Vector2(960, 540)
				for y in range(int(40 * scale.y), int(62 * scale.y)):
					for x in range(int(250 * scale.x), int(750 * scale.x)):
						if capture.get_pixel(x, y).g > 0.4:
							text_pixels += 1
				check(text_pixels > 30, "Landing captions remain visible over the cloud scene")
	await check_gameplay(game, renderer)
	await check_landing_view(game, renderer)
	await check_landing(game)
	check_terminal(game)
	await check_cache(game, renderer)
	await smoke_phases(game)
	if DisplayServer.get_name() != "headless":
		await check_depth(renderer)
		await check_instruments(renderer)
	if options_existed:
		var file := FileAccess.open(options_path, FileAccess.WRITE)
		check(file != null, "Original options file can be restored")
		if file != null:
			file.store_buffer(options_bytes)
	elif FileAccess.file_exists(options_path):
		check(DirAccess.remove_absolute(options_path) == OK, "Test-created options file is removed")
	print("ASH_TEST_RESULT=", checks - failures, "/", checks)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func check_gameplay(game: Node, renderer: Node) -> void:
	game.call("StartRun")
	game.set("phase", 2)
	game.set("on_buggy", true)
	game.set("px", 6.4)
	game.set("pz", -18.0)
	game.set("yaw", 0.0)
	for frame in 3:
		game.queue_redraw()
		await process_frame
	var rebuilds: int = renderer.rebuild_count
	key(KEY_W, true)
	game.set_process(true)
	var start := Time.get_ticks_usec()
	for frame in 30:
		await process_frame
	print("GAMEPLAY_FRAME_US=", (Time.get_ticks_usec() - start) / 30)
	game.set_process(false)
	key(KEY_W, false)
	check(game.get("phase") == 2 and game.get("on_buggy"), "Driving frames stay in the buggy without phantom interactions")
	check(float(game.get("pz")) > -18.0, "Held W drives the buggy forward during real process frames")
	check(renderer.rebuild_count == rebuilds, "Driving reuses the yard mesh")
	game.queue_redraw()
	await process_frame
	await process_frame
	check(is_equal_approx(float(renderer.buggy_instruments.speed), float(game.get("buggy_v"))), "Driving sends the actual buggy velocity to its dashboard")
	check(is_equal_approx(float(renderer.buggy_instruments.heading), float(game.get("yaw"))), "Driving sends the actual heading to its dashboard")
	check(is_equal_approx(float(renderer.buggy_instruments.progress), float(game.get("pz"))), "Driving sends the actual yard position to its range gauge")

func check_cache(game: Node, renderer: Node) -> void:
	game.set("phase", 2)
	game.set("opt_detail", 1)
	game.queue_redraw()
	await process_frame
	await process_frame
	var rebuilds: int = renderer.rebuild_count
	game.set("px", float(game.get("px")) + 1.0)
	game.set("yaw", float(game.get("yaw")) + 0.1)
	game.queue_redraw()
	await process_frame
	await process_frame
	check(renderer.rebuild_count == rebuilds, "Moving and turning do not rebuild static geometry")
	game.set("on_buggy", not game.get("on_buggy"))
	game.queue_redraw()
	await process_frame
	await process_frame
	check(renderer.rebuild_count == rebuilds + 1, "Leaving or entering the buggy refreshes its parked mesh")
	var items: Array = game.get("got")
	items[0] = true
	game.set("got", items)
	game.queue_redraw()
	await process_frame
	await process_frame
	check(renderer.rebuild_count == rebuilds + 2, "Collecting an item removes it from the cached yard")
	game.set("opt_detail", 0)
	game.queue_redraw()
	await process_frame
	await process_frame
	check(renderer.rebuild_count == rebuilds + 3, "Detail changes refresh the cache")
	check(renderer.world_mesh.mesh.surface_get_array_len(0) > 0, "Low detail retains opaque hull and building faces")

func project_gate(game: Node, renderer: Node, ring: int, x_off: float, alt_off: float, bank: float) -> Dictionary:
	game.call("StartRun")
	game.set("phase", 1)
	game.set("next_ring", ring)
	var rz: float = 26.0 + ring * 20.0
	game.set("ship_z", rz - 14.0)
	game.set("ship_x", float(game.call("RingOff", ring)) + x_off / 7.0)
	game.set("ship_alt", float(game.call("RingLift", ring)) + alt_off)
	game.set("ship_bank", bank)
	game.set("ship_yaw_aim", -0.34 * signf(bank))
	game.set("ship_pitch", -0.36)
	game.queue_redraw()
	await process_frame
	var camera: Camera3D = renderer.get("camera")
	var centre := Vector3(float(game.call("RingOff", ring)) * 7.0, float(game.call("GlideY", rz)) + float(game.call("RingLift", ring)), rz)
	var right_vec: Vector3 = camera.global_transform.basis.x.normalized()
	var p: Vector2 = camera.unproject_position(centre)
	var edge: Vector2 = camera.unproject_position(centre + right_vec * 2.15)
	return {"offset": p - Vector2(480, 270), "radius": p.distance_to(edge)}

func check_landing_view(game: Node, renderer: Node) -> void:
	# The cockpit marker sits at the 3D view's centre; what the pilot sees must agree with TickApproach.
	var deck: Node2D = renderer.get("deck")
	check(deck.call("marker_centre") + deck.position - Vector2(20, 20) == Vector2(480, 270), "The cockpit marker is drawn at the 3D view's centre")
	var aligned: Dictionary = await project_gate(game, renderer, 5, 0.0, 0.0, 0.6)
	check(aligned.offset.length() < 2.0, "An aligned landing gate is centred on the cockpit marker even while banked")
	var inside: Dictionary = await project_gate(game, renderer, 9, 1.6, -0.9, -0.5)
	check(inside.offset.length() < inside.radius and inside.offset.x < 0.0 and inside.offset.y < 0.0, "A gate offset up-left but within reach still encloses the marker")
	var outside: Dictionary = await project_gate(game, renderer, 9, 2.4, 0.0, 0.0)
	check(outside.offset.length() > outside.radius, "A gate the hull would miss does not enclose the marker")
	game.call("StartRun")

func check_landing(game: Node) -> void:
	game.call("StartRun")
	game.set("phase", 1)
	game.call("TickApproach", 0.1)
	check(is_equal_approx(float(game.get("ship_z")), 1.6), "Landing begins at 16 units/s rather than the old 5.4")
	game.set("mouse_fly", true)
	var before_x: float = float(game.get("ship_x"))
	mouse_at(game, Vector2(820, 270))
	game.call("TickApproach", 0.1)
	check(float(game.get("ship_x")) > before_x + 0.05, "Mouse right of centre steers the landing")
	game.set("mouse_fly", false)
	game.set("ship_x", 0.0)
	game.set("ship_z", 45.95)
	game.set("ship_x", -1.0)
	game.set("next_ring", 1)
	game.call("TickApproach", 0.01)
	check(game.get("ring_miss") == 1 and game.get("next_ring") == 1, "Missing a ring gives a hull strike without skipping it")
	check(is_equal_approx(float(game.get("ship_z")), 38.0), "A hull strike resets just short of the same ring")
	game.set("ship_z", 45.95)
	game.call("TickApproach", 0.01)
	check(game.get("landing_failed"), "Two hull strikes lose the approach")
	var stopped_z: float = game.get("ship_z")
	game.call("TickApproach", 0.2)
	check(game.get("ship_z") == stopped_z, "A failed approach waits for an explicit retry")
	await tap_key(game, KEY_ENTER)
	check(not game.get("landing_failed") and game.get("next_ring") == 0 and game.get("ring_miss") == 0, "Enter restarts the whole course after failure")
	game.call("StartRun")
	game.set("phase", 1)
	var previous_controls := [false, false, false, false]
	var controls := [KEY_A, KEY_D, KEY_W, KEY_S]
	var frames := 0
	while game.get("phase") == 1 and frames < 3600 and not game.get("landing_failed"):
		var ring: int = game.get("next_ring")
		var x_target := float(game.call("RingOff", mini(ring, 27))) if ring < 28 else 0.0
		var y_target := float(game.call("RingLift", mini(ring, 27))) if ring < 28 else 0.0
		var x: float = game.get("ship_x")
		var y: float = game.get("ship_alt")
		var down := [x > x_target + 0.025, x < x_target - 0.025, y < y_target - 0.05, y > y_target + 0.05]
		for i in 4:
			if down[i] != previous_controls[i]:
				key(controls[i], down[i])
		previous_controls = down
		game.call("TickApproach", 1.0 / 60.0)
		frames += 1
	for code in controls:
		key(code, false)
	check(game.get("phase") == 10 and game.get("next_ring") == 28, "Keyboard steering can complete all 28 rings and reach the bay")
	check(game.get("ring_miss") == 0, "The precision course is reachable without hull strikes")
	check(frames > 1800 and frames < 2400, "A clean approach lasts 30-40 seconds despite its faster speed")
	print("LANDING_CLEAN_SECONDS=", frames / 60.0)
	game.call("StartRun")
	game.set("phase", 1)
	game.set("next_ring", 28)
	game.set("ship_z", 595.9)
	game.call("TickApproach", 0.02)
	check(game.get("phase") == 10, "The bay starts only after the course's final approach")
	for offset in [2.05, 2.25]:
		game.call("StartRun")
		game.set("phase", 1)
		game.set("ship_x", offset / 7.0)
		game.set("ship_z", 25.99)
		game.call("TickApproach", 0.001)
		check(game.get("next_ring") == (1 if offset < 2.15 else 0), "Flying inside the drawn ring clears it, and missing the circle does not, at %.2f" % offset)
	game.call("StartRun")
	game.set("phase", 1)
	game.set("land_t", -3.0)
	game.call("TickApproach", 3.0)
	check(game.get("next_ring") == 1 and game.get("ring_miss") == 1, "A long frame checks every crossed ring rather than skipping the second")

func check_terminal(game: Node) -> void:
	var sequence := [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A, KEY_B, KEY_A]
	game.call("StartRun")
	game.set("dev_on", false)
	game.set("code_i", 0)
	for code in sequence.slice(0, 11):
		game.call("NoteCode", code)
	check(not game.get("dev_on"), "A partial sequence stays hidden")
	game.call("NoteCode", KEY_B)
	check(not game.get("dev_on") and game.get("code_i") == 0, "A wrong key clears the sequence")
	for code in sequence:
		game.call("NoteCode", code)
	check(game.get("dev_on") and game.get("code_i") == 0, "The full sequence opens the terminal")
	game.set("dev_i", 1)
	game.call("WarpDev")
	check(game.get("phase") == 1 and not game.get("dev_on"), "The terminal jumps to the selected scene and closes")
	game.set("dev_on", true)
	game.set("dev_i", 5)
	game.call("WarpDev")
	check(game.get("phase") == 4 and not game.get("have_device"), "Chamber skip starts before the coupler is taken")
	game.set("dev_on", true)
	game.set("dev_i", 6)
	game.call("WarpDev")
	check(game.get("phase") == 6 and game.get("have_device"), "Canyon skip starts with the coupler")
	game.call("StartRun")
	game.set("phase", 2)
	game.set("on_buggy", true)
	game.set("dev_on", false)
	game.set("code_i", 0)

func check_instruments(renderer: Node) -> void:
	renderer.buggy_texture(2, 0, 0, 10)
	await process_frame
	await RenderingServer.frame_post_draw
	var still: Image = renderer.buggy_view.get_texture().get_image()
	check(still.get_pixel(480, 210).a < 0.01, "Buggy windscreen remains transparent to the actual world")
	check(still.get_pixel(480, 80).a > 0.99, "Buggy canopy frame is opaque")
	check(still.get_pixel(480, 365).a > 0.99, "Buggy dashboard is opaque")
	renderer.buggy_texture(4, 16, 1.2, 80)
	await process_frame
	await RenderingServer.frame_post_draw
	var moving: Image = renderer.buggy_view.get_texture().get_image()
	check(still.get_region(Rect2i(219, 372, 121, 58)).get_data() != moving.get_region(Rect2i(219, 372, 121, 58)).get_data(), "Buggy speed gauge changes with actual velocity")
	check(still.get_region(Rect2i(359, 359, 242, 75)).get_data() != moving.get_region(Rect2i(359, 359, 242, 75)).get_data(), "Buggy heading, range, and telemetry respond")
	renderer.cockpit_texture(2, 80, 800, 1)
	await process_frame
	await RenderingServer.frame_post_draw
	still = renderer.cockpit_view.get_texture().get_image()
	renderer.cockpit_texture(7, 95, 720, 1)
	await process_frame
	await RenderingServer.frame_post_draw
	moving = renderer.cockpit_view.get_texture().get_image()
	check(still.get_region(Rect2i(219, 343, 522, 76)).get_data() != moving.get_region(Rect2i(219, 343, 522, 76)).get_data(), "Ship radar, readings, and fault gauges animate")
	check(still.get_region(Rect2i(220, 110, 520, 150)).get_data() != moving.get_region(Rect2i(220, 110, 520, 150)).get_data(), "Stars visibly move through the ship windscreen")
	var stars := 0
	for y in range(110, 260):
		for x in range(280, 680):
			if moving.get_pixel(x, y).a > 0.1:
				stars += 1
	check(stars > 20 and stars < 3000, "Ship windscreen shows sparse stars, not floating cockpit rings")

func smoke_phases(game: Node) -> void:
	for phase in range(14):
		game.set("phase", phase)
		game.queue_redraw()
		await process_frame
		await process_frame
		check(game.get("phase") == phase, "Drawing phase %d leaves gameplay state intact" % phase)

func check_depth(renderer: Node) -> void:
	renderer.begin_frame()
	renderer.face(Vector3(-1, -1, 3), Vector3(1, -1, 3), Vector3(1, 1, 3), Vector3(-1, 1, 3), Color(0.1, 0.2, 0.3))
	renderer.segment(Vector3(-1, 0, 5), Vector3(1, 0, 5), Color.RED)
	renderer.present(0, 0, 0, 0, 0, 100)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = renderer.viewport.get_texture().get_image()
	var center := image.get_pixel(480, 270)
	check(center.r < 0.2 and center.a > 0.99, "An opaque face hides a line behind it")
	renderer.begin_frame()
	renderer.face(Vector3(-1, 1, 3), Vector3(1, 1, 3), Vector3(1, -1, 3), Vector3(-1, -1, 3), Color(0.1, 0.2, 0.3))
	renderer.segment(Vector3(-1, 0, 5), Vector3(1, 0, 5), Color.RED)
	renderer.present(0, 0, 0, 0, 0, 100)
	await process_frame
	await RenderingServer.frame_post_draw
	image = renderer.viewport.get_texture().get_image()
	center = image.get_pixel(480, 270)
	check(center.r < 0.2 and center.a > 0.99, "Opposite face winding does not create transparent holes")
	renderer.begin_frame()
	renderer.face(Vector3(-1, -1, 3), Vector3(1, -1, 3), Vector3(1, 1, 3), Vector3(-1, 1, 3), Color(0.1, 0.2, 0.3))
	renderer.segment(Vector3(-1, 0, 3), Vector3(1, 0, 3), Color.RED)
	renderer.present(0, 0, 0, 0, 0, 100)
	await process_frame
	await RenderingServer.frame_post_draw
	image = renderer.viewport.get_texture().get_image()
	var red := 0.0
	for y in range(268, 273):
		red = maxf(red, image.get_pixel(480, y).r)
	check(red > 0.7, "A neon edge on its own face remains visible without depth fighting")
	renderer.begin_frame()
	renderer.face(Vector3(-1, -1, 0.05), Vector3(1, -1, 3), Vector3(1, 1, 3), Vector3(-1, 1, 0.05), Color(0.1, 0.2, 0.3))
	renderer.present(0, 0, 0, 0, 0, 100)
	await process_frame
	await RenderingServer.frame_post_draw
	image = renderer.viewport.get_texture().get_image()
	check(image.get_pixel(480, 270).a > 0.99, "A face crossing the near plane is clipped rather than discarded")
	image = renderer.cockpit_view.get_texture().get_image()
	check(image.get_pixel(480, 170).a < 0.01, "Cockpit windscreen stays clear without the reference's floating rings")
	check(image.get_pixel(480, 350).a > 0.99, "Cockpit instrument panel is opaque")
