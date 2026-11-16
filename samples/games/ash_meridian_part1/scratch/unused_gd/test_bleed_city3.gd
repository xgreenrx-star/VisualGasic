extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(game: Node, count := 2) -> void:
	for i in count:
		game.queue_redraw()
		await process_frame

func shot(game: Node, path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(path)
	print("BLEED3_SHOT=", path, " ", image.get_width(), "x", image.get_height(), " ", image.get_pixel(480, 270))

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set("opt_fps", false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	game.set("dev_i", 12)
	game.call("WarpDev")
	await frames(game, 4)
	var renderer = game.get_node("Presentation")
	var city = renderer.city3
	check(game.get("phase") == 16, "Terminal opens Bleed City 3")
	check(city != null and city.initialized, "Scaffold city builds")
	check(not renderer.world_mesh.visible, "Chapter yard stays hidden")
	check(renderer.city2 == null or not renderer.city2.visible, "City 2 stays hidden")
	check(city.world.mesh.get_surface_count() == 2, "City has opaque surfaces and neon edges")
	check(city.world.mesh.surface_get_array_len(0) > 4000, "Scaffolds, road, and silos have volume")
	check(city.world.mesh.surface_get_array_len(1) > 2000, "Neon edges are dense enough to read as wire")
	check(city.wheels.size() == 4 and city.bottles.size() == 3 and city.lamps.size() == 2, "Buggy, bottles, and searchlights are separate meshes")
	check(city.beam != null and city.beam.visible, "Shaft beam is its own mesh")
	var mesh_id: int = city.world.mesh.get_instance_id()
	await shot(game, "/tmp/bleed3-street.png")
	city.inspection = 1
	await frames(game, 3)
	await shot(game, "/tmp/bleed3-overview.png")
	city.inspection = 2
	await frames(game, 3)
	await shot(game, "/tmp/bleed3-buggy.png")
	city.inspection = 0
	city.position_xz = Vector2(4, 20)
	city.heading = 0.4
	await frames(game, 2)
	await shot(game, "/tmp/bleed3-bottle.png")
	check(city.world.mesh.get_instance_id() == mesh_id, "Camera moves do not rebuild the city")
	game.call("SaveRun")
	check(game.get("save_msg") == "CITY 3 IS A DEV DEMO - CHAPTER SAVE UNCHANGED", "City 3 does not write the chapter save")
	var detail: int = game.get("opt_detail")
	game.set("opt_detail", 2)
	await frames(game)
	check(renderer.viewport.msaa_3d == Viewport.MSAA_4X, "High detail uses 4x antialiasing")
	check(renderer.city3_output.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "City 3 keeps its own glow pass")
	game.set("opt_detail", detail)
	game.set("dev_i", 11)
	game.call("WarpDev")
	await frames(game, 3)
	check(game.get("phase") == 15 and not city.visible, "Leaving for City 2 hides the scaffold city")
	check(renderer.city2 != null and renderer.city2.visible, "City 2 still opens from its own terminal row")
	renderer.city2.inspection = 1
	await frames(game, 3)
	await shot(game, "/tmp/bleed2-overview.png")
	print("BLEED_CITY3_VERTS=", city.world.mesh.surface_get_array_len(0))
	print("BLEED_CITY3_EDGES=", city.world.mesh.surface_get_array_len(1))
	print("BLEED_CITY3_RESULT=", checks - failures, "/", checks)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
