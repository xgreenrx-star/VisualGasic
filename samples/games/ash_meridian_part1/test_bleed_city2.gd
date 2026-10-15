extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(game: Node, count := 2) -> void:
	for i in count:
		game.queue_redraw()
		await process_frame

func tap(game: Node, code: Key) -> void:
	key(code, true)
	game.set_process(true)
	await process_frame
	await process_frame
	game.set_process(false)
	key(code, false)
	game.set_process(true)
	await process_frame
	await process_frame
	game.set_process(false)

func capture(game: Node, label: String) -> void:
	var directory := OS.get_environment("ASH_CITY2_CAPTURE")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await frames(game, 4)
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Save " + label + " preview")

func _run() -> void:
	var city_script = load("res://bleed_city_2.gd")
	if city_script == null or not city_script.can_instantiate():
		push_error("Bleed City 2 script cannot be instantiated")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set("opt_fps", false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	check(game.call("DevLabel", 10) == "BLEED CITY", "Cursor's original terminal destination remains")
	check(game.call("DevLabel", 11) == "BLEED CITY 2", "New destination has its own terminal label")
	check(game.call("DevLabel", 12) == "BLEED CITY 3", "Scaffold city keeps its own terminal label")
	game.set("phase", 12)
	for i in 12:
		await tap(game, int(game.call("CodeKey", i)))
	check(game.get("dev_on"), "Existing hidden key sequence opens the actual dev terminal")
	await tap(game, KEY_UP)
	check(game.get("dev_i") == 13, "Terminal navigation wraps up to the newest destination")
	await tap(game, KEY_UP)
	check(game.get("dev_i") == 12, "Another up step lands on Bleed City 3")
	await tap(game, KEY_UP)
	check(game.get("dev_i") == 11, "Another up step lands on Bleed City 2")
	await capture(game, "terminal")
	await tap(game, KEY_ENTER)
	check(game.get("phase") == 15 and not game.get("dev_on"), "Actual terminal Enter opens Bleed City 2")
	await frames(game, 4)
	var renderer = game.get_node("Presentation")
	var city = renderer.city2
	check(city != null and city.initialized, "District builds successfully")
	check(city.world.mesh.get_surface_count() == 2, "District contains opaque geometry and neon edges")
	check(city.world.mesh.surface_get_array_len(0) > 10000, "Buildings are volumetric meshes, not placeholder outlines")
	check(city.vehicle.mesh.get_surface_count() == 2 and city.wheels.size() == 4, "Buggy has a solid chassis and four separate wheels")
	check(city.bottles.size() == 3, "Air bottles are individual collectible meshes")
	check(not renderer.world_mesh.visible, "Original yard mesh stays hidden in the new destination")
	var save_path := "user://ash_meridian_save.txt"
	var had_save := FileAccess.file_exists(save_path)
	var save_bytes := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	game.call("SaveRun")
	check(game.get("save_msg") == "CITY 2 IS A DEV DEMO - CHAPTER SAVE UNCHANGED", "Demo save action explicitly reports that it is not a chapter save")
	check(FileAccess.file_exists(save_path) == had_save, "Demo save does not create or remove the chapter save")
	if had_save:
		check(FileAccess.get_file_as_bytes(save_path) == save_bytes, "Demo save leaves chapter bytes untouched")
	var mesh_id: int = city.world.mesh.get_instance_id()
	await capture(game, "street")
	await tap(game, KEY_V)
	check(city.inspection == 1, "V opens the district overview")
	await capture(game, "overview")
	await tap(game, KEY_V)
	check(city.inspection == 2, "V opens the buggy asset inspection")
	await capture(game, "buggy")
	await tap(game, KEY_V)
	check(city.inspection == 0, "V returns to the playable view")
	city.position_xz = Vector2(2.5, 18)
	await tap(game, KEY_F)
	check(city.driving, "F enters the nearby buggy")
	var start_z: float = city.position_xz.y
	key(KEY_W, true)
	game.set_process(true)
	for i in 24:
		await process_frame
	game.set_process(false)
	key(KEY_W, false)
	check(city.position_xz.y > start_z and city.velocity > 0, "Real process callbacks drive the buggy forward")
	check(city.wheel_angle > 0, "Driving rotates the wheels")
	await frames(game)
	check(not city.vehicle.visible, "First-person driving hides the exterior chassis")
	check(renderer.buggy_instruments.range_end == 154 and renderer.buggy_instruments.max_speed == 18, "City cockpit uses this district's range and buggy speed")
	await capture(game, "driving")
	await tap(game, KEY_ESCAPE)
	check(game.get("menu_on"), "Escape opens the normal pause menu in City 2")
	var paused_position: Vector2 = city.position_xz
	key(KEY_W, true)
	game.set_process(true)
	await process_frame
	await process_frame
	game.set_process(false)
	key(KEY_W, false)
	check(city.position_xz == paused_position, "Paused City 2 does not move its buggy")
	await tap(game, KEY_ESCAPE)
	check(not game.get("menu_on") and game.get("phase") == 15, "Escape resumes the same City 2 session")
	await tap(game, KEY_F)
	check(not city.driving and city.position_xz.distance_to(city.buggy_position) > 2, "F exits beside the parked buggy")
	city.position_xz = Vector2(8, 27)
	city.heading = -0.46
	await capture(game, "air-bottle")
	city.position_xz = Vector2(7, 29)
	await tap(game, KEY_E)
	check(city.collected == 1 and not city.bottles[0].visible, "E collects a nearby bottle on foot")
	await tap(game, KEY_E)
	check(city.collected == 1, "An already collected bottle cannot be taken twice")
	check(city.blocked(Vector2(-31, 20), 0.35), "Refinery walls block movement")
	check(not city.blocked(Vector2(-24, 12), 0.35), "Hall doorway is actually open")
	city.position_xz = Vector2(-24, 10)
	city.heading = 0
	city.move_distance(8)
	check(city.position_xz.y > 17, "Walk through the open hall doorway")
	city.heading = -PI / 2
	city.move_distance(25)
	check(city.position_xz.x > -30.5, "Long movement cannot tunnel through a hall wall")
	city.position_xz = Vector2(0, 89)
	city.heading = 0
	city.move_distance(30)
	check(city.position_xz.y < 94, "The shaft blocks walking into the pit")
	city.position_xz = Vector2(12, 89)
	city.heading = 0
	city.move_distance(30)
	check(city.position_xz.y > 118, "The shaft has a traversable route around it")
	if DisplayServer.get_name() != "headless":
		city.position_xz = Vector2(-30, 20)
		city.heading = -PI / 2
		await frames(game, 3)
		game.queue_redraw()
		await RenderingServer.frame_post_draw
		var wall: Image = renderer.viewport.get_texture().get_image()
		check(wall.get_pixel(480, 270).a > 0.99, "Hall wall pixels are opaque from the inside")
	city.position_xz = Vector2(8, 86)
	city.heading = -0.5
	await capture(game, "shaft")
	city.position_xz = Vector2(-35, 85)
	city.heading = -0.55
	await capture(game, "dock")
	check(city.world.mesh.get_instance_id() == mesh_id, "Camera, driving, and pickup changes do not rebuild the district")
	var detail: int = game.get("opt_detail")
	game.set("opt_detail", 0)
	await frames(game)
	check(renderer.viewport.msaa_3d == Viewport.MSAA_DISABLED, "Low detail disables City 2 antialiasing")
	check(renderer.city2_output.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Low detail disables the City 2 glow pass")
	check(city.world.mesh.get_instance_id() == mesh_id, "Low detail preserves the same solid district geometry")
	check(is_equal_approx(renderer.camera.far, float(game.get("opt_view"))), "Street view respects the view-distance option")
	game.set("opt_detail", 2)
	await frames(game)
	check(renderer.viewport.msaa_3d == Viewport.MSAA_4X, "High detail enables City 2 4x antialiasing")
	game.set("opt_detail", detail)
	city.inspection = 1
	await frames(game, 3)
	var start := Time.get_ticks_usec()
	await frames(game, 12)
	print("BLEED_CITY2_FRAME_US=", (Time.get_ticks_usec() - start) / 12)
	game.set("dev_i", 10)
	game.call("WarpDev")
	await frames(game)
	check(game.get("phase") == 14 and not city.visible and renderer.yard_key == "bleed-city", "Cursor's city still works after leaving City 2")
	check(renderer.viewport.msaa_3d == Viewport.MSAA_DISABLED, "Original city retains its original render settings")
	game.set("dev_i", 11)
	game.call("WarpDev")
	await frames(game)
	check(city.collected == 0 and city.bottles[0].visible and not city.driving, "Re-entering the destination resets its demo state")
	check(city.world.mesh.get_instance_id() == mesh_id, "Re-entering reuses the completed city meshes")
	game.set("phase", 12)
	await frames(game)
	check(not city.visible, "City geometry is hidden on the title screen")
	check(renderer.city2_output.render_target_update_mode == SubViewport.UPDATE_DISABLED, "City-only glow pass stops rendering after leaving the demo")
	print("BLEED_CITY2_RESULT=", checks - failures, "/", checks)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
