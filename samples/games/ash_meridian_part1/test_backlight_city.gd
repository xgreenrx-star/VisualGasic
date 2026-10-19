extends "res://test_bleed_city2.gd"

func capture(game: Node, label: String) -> void:
	var directory := OS.get_environment("ASH_BACKLIGHT_CAPTURE")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await frames(game, 6)
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Save " + label)

func _run() -> void:
	var script = load("res://backlight_exploration.gd")
	if script == null or not script.can_instantiate():
		push_error("Backlight City cannot be instantiated")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set("opt_fps", false)
	game.set("opt_detail", 1)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	for i in 4:
		check(game.call("DevLabel", i + 10) == ["BLEED CITY", "BLEED CITY 2", "BLEED CITY 3", "BACKLIGHT CITY"][i], "Destination %d preserves its label" % (i + 10))
	game.set("phase", 12)
	for i in 12:
		await tap(game, int(game.call("CodeKey", i)))
	check(game.get("dev_on"), "Hidden sequence opens the real terminal")
	check(game.call("RowLabel", 1) == "LANDING" and game.call("RowLabel", 2) == "ELEVATOR" and game.call("RowLabel", 3) == "FEB", "Main list keeps landing, elevator, and FEB")
	check(game.call("RowLabel", 4) == "BACKLIGHT YARD" and game.call("RowLabel", 5) == "ARCHIVE", "Backlight Yard stays on the main list")
	for i in 5:
		await tap(game, KEY_DOWN)
	await tap(game, KEY_ENTER)
	check(game.get("dev_page") == 1, "Archive opens from the main list")
	for i in 9:
		await tap(game, KEY_DOWN)
	check(game.get("dev_i") == 13, "Archive selection lands on Backlight City")
	await capture(game, "terminal")
	await tap(game, KEY_ENTER)
	await frames(game, 5)
	check(game.get("phase") == 17 and not game.get("dev_on"), "Enter opens the independent Backlight destination")
	var renderer = game.get_node("Presentation")
	var city = renderer.backlight_city
	check(city != null and city.initialized, "District builds on first visit")
	check(city.world.mesh.get_surface_count() == 2, "Architecture separates opaque shells from luminous insets")
	check(city.world.mesh.surface_get_array_len(0) > 6000, "District contains substantial solid geometry")
	check(city.world.mesh.surface_get_array_len(1) > 3000, "Illuminated panels are actual surface geometry")
	print("BACKLIGHT_VERTICES=", city.world.mesh.surface_get_array_len(0), " LUMINOUS_VERTICES=", city.world.mesh.surface_get_array_len(1))
	check(city.shell_material.shader.code.contains("satin") and not city.shell_material.shader.code.contains("ALPHA"), "Satin shell shading remains opaque")
	check(city.light_material.next_pass == null, "Inserts use surface materials, not wireframe halo passes")
	check(city.vehicle.mesh.get_surface_count() == 2 and city.wheels.size() == 4, "Original courier has a body and four animated wheels")
	check(city.carrier != null and city.bottles.size() == 3, "Carrier and three charge cells are separate assets")
	check(renderer.camera.environment == city.atmosphere, "District supplies its own violet-horizon environment")
	renderer.present(3.8, 1.8, 4, -0.06, -0.025, 220)
	check(renderer.viewport.msaa_3d == Viewport.MSAA_2X, "Shared camera update preserves district MSAA without reallocating it")
	renderer.begin_frame(true)
	check(not renderer.viewport.transparent_bg and renderer.camera.environment == city.atmosphere, "Active frames preserve the sky and opaque render target instead of toggling them")
	await frames(game)
	check(city.optics.size() == 3 and city.optics[0].size == Vector2i(320, 180), "Optical glow uses two low-resolution blur passes and a composite")
	check(city.optics[0].get_child(0).size == Vector2(320, 180), "Glow downsampling scales the whole source instead of cropping its top-left corner")
	check(not renderer.world_mesh.visible and not renderer.frame_mesh.visible, "Chapter and wireframe geometry stay hidden")
	var mesh_id: int = city.world.mesh.get_instance_id()
	var save_path := "user://ash_meridian_save.txt"
	var had_save := FileAccess.file_exists(save_path)
	var save_bytes := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	game.call("SaveRun")
	check(game.get("save_msg") == "BACKLIGHT CITY IS A DEV DEMO - CHAPTER SAVE UNCHANGED", "Save reports this is a dev demo")
	check(FileAccess.file_exists(save_path) == had_save, "No chapter save is created or removed")
	if had_save:
		check(FileAccess.get_file_as_bytes(save_path) == save_bytes, "Chapter save bytes remain unchanged")
	await capture(game, "street")
	if DisplayServer.get_name() != "headless":
		await frames(game, 6)
		await RenderingServer.frame_post_draw
		var raw: Image = renderer.viewport.get_texture().get_image()
		var film: Image = city.optics.back().get_texture().get_image()
		var directory := OS.get_environment("ASH_BACKLIGHT_CAPTURE")
		if not directory.is_empty():
			check(raw.save_png(directory.path_join("raw.png")) == OK, "Save raw scene comparison")
			for i in 2:
				check(city.optics[i].get_texture().get_image().save_png(directory.path_join("glow-%d.png" % i)) == OK, "Save optical pass comparison")
		var broad_halo := 0
		var matte := 0
		for y in range(70, 480, 3):
			for x in range(40, 920, 3):
				var a := raw.get_pixel(x, y)
				var b := film.get_pixel(x, y)
				if maxf(a.r, maxf(a.g, a.b)) < 0.4 and b.r + b.g + b.b > a.r + a.g + a.b + 0.035:
					broad_halo += 1
				if a.b > 0.055 and a.b < 0.4 and a.a > 0.99:
					matte += 1
		check(broad_halo > 80, "Bloom spreads luminous insets onto neighboring dark pixels")
		check(matte > 2000, "Rendered scene has readable opaque blue-gray surfaces, not just bright edges")
		check(raw.get_pixel(480, 80).a > 0.99, "Sky background renders opaque")
		print("BACKLIGHT_HALO_SAMPLES=", broad_halo, " MATTE_SAMPLES=", matte)
	await tap(game, KEY_V)
	check(city.inspection == 1, "V opens district overview")
	await capture(game, "overview")
	await tap(game, KEY_V)
	check(city.inspection == 2, "V opens courier inspection")
	await capture(game, "courier")
	await tap(game, KEY_V)
	check(city.inspection == 0, "V returns to street view")
	city.position_xz = Vector2(-4.5, 35)
	city.heading = -0.4
	await capture(game, "carrier")
	city.position_xz = Vector2(2.5, 14)
	await tap(game, KEY_F)
	check(city.driving, "F enters the nearby courier")
	var start_z: float = city.position_xz.y
	key(KEY_W, true)
	game.set_process(true)
	for i in 24:
		await process_frame
	game.set_process(false)
	key(KEY_W, false)
	check(city.position_xz.y > start_z and city.velocity > 0, "Actual input drives the courier")
	check(city.wheel_angle > 0, "Wheels rotate with speed")
	await frames(game)
	check(not city.vehicle.visible, "Driving does not show the exterior body inside the cockpit")
	check(is_equal_approx(renderer.buggy_instruments.speed, city.velocity), "Restored cockpit reads live vehicle speed")
	await capture(game, "driving")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var first: Image = renderer.buggy_view.get_texture().get_image()
		game.set("clock", float(game.get("clock")) + 1)
		await frames(game, 3)
		await RenderingServer.frame_post_draw
		var second: Image = renderer.buggy_view.get_texture().get_image()
		check(first.get_data() != second.get_data(), "Cockpit telemetry visibly animates")
	await tap(game, KEY_ESCAPE)
	check(game.get("menu_on"), "Escape opens normal pause menu")
	var paused: Vector2 = city.position_xz
	key(KEY_W, true)
	game.set_process(true)
	await process_frame
	await process_frame
	game.set_process(false)
	key(KEY_W, false)
	check(city.position_xz == paused, "Pause freezes vehicle movement")
	await tap(game, KEY_ESCAPE)
	check(not game.get("menu_on") and game.get("phase") == 17, "Pause resumes the same district")
	await tap(game, KEY_F)
	check(not city.driving and city.position_xz.distance_to(city.buggy_position) > 2, "F parks and exits to a clear side")
	city.position_xz = Vector2(7, 29)
	await tap(game, KEY_E)
	check(city.collected == 1 and not city.bottles[0].visible, "E collects a charge cell on foot")
	await tap(game, KEY_E)
	check(city.collected == 1, "Cells cannot be collected twice")
	check(city.blocked(Vector2(13, 26), 0.35), "Opaque portal columns have collision")
	check(not city.blocked(Vector2(0, 26), 1.4), "Main portal opening fits the vehicle")
	check(city.blocked(Vector2(-11, 48), 0.35), "Parked carrier has collision")
	city.position_xz = Vector2(0, 23)
	city.heading = 0
	city.move_distance(10)
	check(city.position_xz.y > 32, "Portal center remains traversable")
	city.position_xz = Vector2(30, 8)
	city.heading = 0
	city.move_distance(20)
	check(city.position_xz.y < 10, "Long movement cannot tunnel through a building")
	city.position_xz = Vector2(38, 9)
	city.move_distance(3)
	check(city.position_xz.y > 11, "Recessed building doorway is open")
	check(city.blocked(Vector2(119, 15), 0.35), "Expanded district boundary remains bounded")
	if DisplayServer.get_name() != "headless":
		for pose in [Vector3(30, 0, 8), Vector3(30, PI, 11)]:
			city.position_xz = Vector2(pose.x, pose.z)
			city.heading = pose.y
			await frames(game, 3)
			await RenderingServer.frame_post_draw
			var wall: Color = renderer.viewport.get_texture().get_image().get_pixel(480, 270)
			check(wall.a > 0.99 and wall.b > 0.025 and wall.b < 0.6, "Building wall is opaque and readable from either side")
	city.position_xz = Vector2(9, 65)
	city.heading = -0.12
	await capture(game, "boulevard")
	city.position_xz = Vector2(0, 87)
	city.heading = 0
	await capture(game, "transit-court")
	check(city.blocked(Vector2(10.2, 95), 0.35) and not city.blocked(Vector2(0, 95), 1.4), "Transit kiosks block their plinths but leave the center lane clear")
	game.set("opt_detail", 0)
	await frames(game)
	check(renderer.viewport.msaa_3d == Viewport.MSAA_DISABLED, "Low detail disables MSAA")
	check(city.optics.all(func(output: SubViewport) -> bool: return output.render_target_update_mode == SubViewport.UPDATE_DISABLED), "Low detail disables all film passes")
	check(renderer.camera.environment == city.atmosphere and city.world.mesh.get_instance_id() == mesh_id, "Low detail preserves the horizon and opaque architecture")
	await capture(game, "low-detail")
	game.set("opt_detail", 2)
	await frames(game)
	check(city.optics.all(func(output: SubViewport) -> bool: return output.render_target_update_mode == SubViewport.UPDATE_ALWAYS), "High detail enables optical glow")
	check(renderer.viewport.msaa_3d == Viewport.MSAA_2X, "High detail uses bounded 2x MSAA")
	check(city.world.mesh.get_instance_id() == mesh_id, "Driving, pickups, views, and detail do not rebuild the city")
	var started := Time.get_ticks_usec()
	await frames(game, 12)
	print("BACKLIGHT_FRAME_US=", (Time.get_ticks_usec() - started) / 12)
	for destination in [10, 11, 12]:
		game.set("dev_i", destination)
		game.call("WarpDev")
		await frames(game, 3)
		check(not city.visible and renderer.camera.environment == null and renderer.viewport.transparent_bg, "Leaving for destination %d restores its environment" % destination)
		check(city.optics.all(func(output: SubViewport) -> bool: return output.render_target_update_mode == SubViewport.UPDATE_DISABLED), "Film passes stop outside Backlight City")
	check(renderer.city3.visible and not renderer.city2.visible, "Original scaffold city still opens independently")
	game.set("dev_i", 13)
	game.call("WarpDev")
	await frames(game, 3)
	check(city.collected == 0 and city.bottles[0].visible and not city.driving, "Re-entry resets demo state")
	check(city.world.mesh.get_instance_id() == mesh_id, "Re-entry reuses geometry")
	game.set("phase", 12)
	await frames(game)
	check(not city.visible and renderer.camera.environment == null, "Title screen has no district geometry or environment")
	check(city.dashboard_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Unused cockpit rendering stops")
	print("BACKLIGHT_RESULT=", checks - failures, "/", checks)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
