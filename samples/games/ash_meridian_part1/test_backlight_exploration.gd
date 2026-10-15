extends "res://test_bleed_city2.gd"

func capture(game: Node, label: String) -> void:
	var directory := OS.get_environment("ASH_EXPLORE_CAPTURE")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await frames(game, 6)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Save " + label)

func enter(game: Node, city: Node, index: int) -> void:
	city.position_xz = city.buildings[index].door
	await tap(game, KEY_E)
	await frames(game)
	check(city.place == "building" and city.building_index == index, "Real E enters separate building %d" % index)

func leave(game: Node, city: Node) -> void:
	city.position_xz = Vector2(0, 2)
	await tap(game, KEY_E)
	await frames(game)
	check(city.place == "surface", "Entry interaction returns to the city")

func travel(game: Node, city: Node, code: String) -> void:
	city.position_xz = Vector2(0, 21)
	await tap(game, KEY_E)
	check(city.keypad, "E opens the five-symbol keypad")
	for i in code.length():
		await tap(game, KEY_0 + int(code.substr(i, 1)))
	check(city.sequence == code, "Physical number keys select the intended glyphs")
	await tap(game, KEY_ENTER)
	check(city.place == "lift" and city.transit_left > 0, "Confirming the address starts an actual cabin transit")
	await frames(game)
	city.tick(1, game.get_node("Presentation"))
	await frames(game)
	check(city.lift_doors.size() == 2 and is_zero_approx(city.lift_doors[0].position.x), "Cabin doors close during the middle of travel")
	city.tick(4, game.get_node("Presentation"))
	await frames(game, 3)
	check(city.place == "floor" and city.floor_code == code, "Doors open onto the selected stratum")

func ascend(game: Node, city: Node) -> void:
	city.position_xz = Vector2(0, 2)
	await tap(game, KEY_E)
	check(city.place == "lift", "E at the underground lift calls an emergency ascent")
	city.tick(4, game.get_node("Presentation"))
	await frames(game)
	check(city.place == "building" and city.building_index == 7, "Ascent returns to the same elevator building")

func reachable(city: Node, start: Vector2, end: Vector2, bounds: Rect2i, spacing := 1.0) -> bool:
	var grid := AStarGrid2D.new()
	grid.region = bounds
	grid.cell_size = Vector2.ONE * spacing
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			grid.set_point_solid(Vector2i(x, y), city.blocked(Vector2(x, y) * spacing, 0.4))
	var a := Vector2i((start / spacing).round())
	var b := Vector2i((end / spacing).round())
	return not grid.get_id_path(a, b).is_empty()

func check_surface_routes(city: Node) -> void:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-58, -5, 117, 215)
	grid.cell_size = Vector2(2, 2)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(-5, 210):
		for x in range(-58, 59):
			grid.set_point_solid(Vector2i(x, y), city.blocked(Vector2(x, y) * 2, 0.4))
	for index in city.buildings.size():
		var door: Vector2 = city.buildings[index].door
		var target := Vector2i((door / 2).round())
		check(not grid.get_id_path(Vector2i(0, 1), target).is_empty(), "Surface building %d has a collision-free approach from the ship" % index)

func _run() -> void:
	var script = load("res://backlight_exploration.gd")
	if script == null or not script.can_instantiate():
		push_error("Exploration prototype does not compile")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set("opt_fps", false)
	game.set("opt_detail", 1)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	game.set("dev_i", 13)
	game.call("WarpDev")
	await frames(game, 5)
	var view = game.get_node("Presentation")
	var city = view.backlight_city
	check(city.buildings.size() == 24, "Expanded district has twenty-four separate building destinations")
	check(city.CITY_BOUNDS.size.x * city.CITY_BOUNDS.size.y > 5 * 116 * 166, "Surface footprint exceeds five times the first Backlight district")
	check(city.turrets.size() == 6, "Six independently sweeping turrets guard the district")
	check(city.world.get_child_count() > 0, "Expansion is cached with the original world")
	var mesh_id: int = city.world.mesh.get_instance_id()
	check(not city.blocked(Vector2(65, 180), 0.4) and city.blocked(Vector2(119, 180), 0.4), "Expanded traversable streets remain bounded")
	check_surface_routes(city)
	await capture(game, "expanded-city")
	city.inspection = 1
	await capture(game, "expanded-overview")
	city.inspection = 2
	await capture(game, "restored-buggy")
	city.inspection = 0
	city.position_xz = Vector2(2.5, 14)
	await tap(game, KEY_F)
	check(city.driving, "Restored buggy remains enterable")
	await frames(game)
	check(view.buggy_instruments.range_end == 420, "Restored original cockpit is wired to the expanded district")
	await capture(game, "restored-cockpit")
	await tap(game, KEY_F)
	var parked: Vector2 = city.buggy_position
	for index in 5:
		await enter(game, city, index)
		check(not city.world.visible and not city.vehicle.visible, "Interior hides the entire outdoor district")
		check(city.room_mesh != null and city.room_mesh.visible, "Separate interior renders")
		check(reachable(city, Vector2(0, 3), Vector2(0, 12), Rect2i(-21, 1, 43, 23)), "Entry can reach the archive workbench")
		city.position_xz = Vector2(0, 12)
		await tap(game, KEY_E)
		check(city.discovered.has(index), "Archive clue is copied only after examination")
		if index == 0:
			await capture(game, "archive")
		await leave(game, city)
	check(city.discovered.size() == 5, "All five fixed sequence fragments can be discovered")
	check(city.buggy_position == parked, "Entering buildings preserves the parked buggy")
	for index in [5, 6]:
		await enter(game, city, index)
		city.position_xz = Vector2(0, 12)
		await tap(game, KEY_E)
		await leave(game, city)
	check(city.inventory.has("regulator") and city.inventory.has("ignition"), "Two occasional surface finds supply ship repair components")
	await enter(game, city, 12)
	city.position_xz = Vector2(0, 12)
	var count: int = city.inventory.size()
	await tap(game, KEY_E)
	check(city.inventory.size() == count and city.message.contains("Nothing compatible"), "Most buildings contain only explicitly useless salvage")
	await capture(game, "empty-store")
	await leave(game, city)
	await enter(game, city, 7)
	city.position_xz = Vector2(0, 21)
	await tap(game, KEY_E)
	await tap(game, KEY_1)
	await tap(game, KEY_ENTER)
	check(city.keypad and city.transit_left == 0, "A short sequence is rejected without traveling")
	await tap(game, KEY_BACKSPACE)
	check(city.sequence.is_empty(), "Backspace erases a symbol")
	await capture(game, "alien-keypad")
	await tap(game, KEY_F)
	await travel(game, city, "58306")
	var first_signature: String = city.floor_signature
	check(not first_signature.is_empty() and city.pod_figure == null, "Ordinary destinations generate exploration rooms, not a random FEB reward")
	check(reachable(city, Vector2(0, 3), Vector2(0, 45), Rect2i(-21, 1, 43, 56)), "Generated floor has a connected route past its console")
	await capture(game, "procedural-floor")
	await ascend(game, city)
	await travel(game, city, "58306")
	check(city.floor_signature == first_signature, "Re-entering the same five symbols regenerates the same floor")
	await ascend(game, city)
	await travel(game, city, "91027")
	check(city.floor_signature != first_signature, "A different address changes the generated floor")
	for code in ["00000", "00001", "99999", "54321", "10101", "88888", "24680", "77777"]:
		city.floor_code = code
		city.pending_room = true
		await frames(game)
		check(reachable(city, Vector2(0, 3), Vector2(0, 45), Rect2i(-21, 1, 43, 56)), "Generated address %s has a traversable corridor" % code)
		check(city.interior.get_child_count() == 3, "Procedural floor replacement retains only one shell and two doors")
	await ascend(game, city)
	await travel(game, city, city.FEB_CODE)
	check(city.pod_figure != null and city.repair_part.visible, "The fixed clue destination contains FEB and the actual repair part")
	check(reachable(city, Vector2(0, 3), Vector2(3, 45), Rect2i(-21, 1, 43, 56)), "FEB's service socket is reachable from the lift")
	city.position_xz = Vector2(0, 39)
	city.heading = 0
	await capture(game, "feb-stasis")
	if DisplayServer.get_name() != "headless":
		await frames(game, 4)
		await RenderingServer.frame_post_draw
		var pod_image: Image = view.viewport.get_texture().get_image()
		var pink_samples := 0
		var cyan_samples := 0
		for y in range(50, 485, 2):
			for x in range(250, 710, 2):
				var pixel := pod_image.get_pixel(x, y)
				if pixel.r > 0.6 and pixel.b > 0.4 and pixel.g < 0.5:
					pink_samples += 1
				if pixel.g > 0.5 and pixel.b > 0.6:
					cyan_samples += 1
		check(pink_samples > 60 and cyan_samples > 100, "Rendered pod has visible magenta rings and cyan figure/supports")
	city.position_xz = Vector2(3.4, 45.5)
	await tap(game, KEY_E)
	check(city.inventory.has("coupler") and city.awakening and city.countdown > 254, "Actual part interaction starts the 255-second awakening")
	check(not city.repair_part.visible and city.message == "ZEN: RUN!", "Part disappears and Zen urgently returns online")
	city.take_coupler()
	check(city.countdown <= 255, "Repeated part use cannot reset or extend the escape")
	city.position_xz = Vector2(0, 39)
	await capture(game, "zen-run")
	city.tick(8, view)
	await frames(game, 4)
	check(city.mist.visible and city.atmosphere.fog_enabled and city.pod_figure.rotation.y != 0, "Fog appears and FEB slowly animates during revival")
	check(is_equal_approx(city.pod_figure.position.z, 49), "Revival rotates FEB about its own body, never around the room origin")
	await capture(game, "feb-awakening")
	var seconds: float = city.countdown
	await tap(game, KEY_ESCAPE)
	check(game.get("menu_on"), "The normal pause menu opens during the escape")
	game.set_process(true)
	await process_frame
	await process_frame
	game.set_process(false)
	check(city.countdown > seconds - 0.2, "Normal pause freezes the purge timer")
	await tap(game, KEY_ESCAPE)
	city.countdown = 0.01
	city.tick(0.1, view)
	check(city.failed and city.countdown == 0, "Timer expiry fails explicitly instead of continuing at zero")
	await tap(game, KEY_ENTER)
	await frames(game)
	check(not city.failed and not city.awakening and not city.inventory.has("coupler") and city.repair_part.visible, "Enter restores a playable chamber checkpoint")
	city.position_xz = Vector2(3.4, 45.5)
	await tap(game, KEY_E)
	var before: float = city.countdown
	await ascend(game, city)
	check(city.countdown < before - 3, "Emergency ascent consumes the same escape countdown")
	await leave(game, city)
	check(city.awakening and city.floor_code.is_empty(), "Awakening persists after returning to the city")
	check(reachable(city, city.surface_position, Vector2(0, 3), Rect2i(-58, -5, 117, 165)), "Elevator building has a collision-free return route to the ship")
	city.position_xz = Vector2(19, 80)
	city.turrets[1].rotation.y = atan2(city.position_xz.x - city.turrets[1].position.x, city.position_xz.y - city.turrets[1].position.z)
	city.damage_cooldown = 0
	var shield: int = city.shield
	city.tick(0.1, view)
	check(city.shield < shield, "Awakened turrets damage exposed players")
	var damaged: int = city.shield
	city.tick(0.1, view)
	check(city.shield == damaged, "Turret hits have a shared damage cooldown")
	check(not city._line_clear(Vector2(19, 80), Vector2(40, 80)), "Opaque buildings block turret fire")
	city.position_xz = Vector2(14, 194)
	city.heading = 0.36
	await capture(game, "turrets")
	city.shield = 1
	city.damage_cooldown = 0
	city.position_xz = Vector2(19, 80)
	city.tick(0.1, view)
	check(city.failed and city.shield == 0, "A suit breach has an explicit retry state")
	await tap(game, KEY_ENTER)
	await frames(game)
	city.position_xz = Vector2(3.4, 45.5)
	await tap(game, KEY_E)
	await ascend(game, city)
	await leave(game, city)
	city.position_xz = Vector2(0, 1)
	await tap(game, KEY_E)
	check(city.completed and not city.awakening, "All three recovered components repair the ship and finish the escape")
	city.tick(3, view)
	await frames(game)
	check(city.ship_model.position.y > 1, "Repaired ship actually lifts off")
	await capture(game, "ship-repaired")
	game.call("SaveRun")
	check(game.get("save_msg").contains("CHAPTER SAVE UNCHANGED"), "Prototype progression never overwrites the chapter save")
	check(city.world.mesh.get_instance_id() == mesh_id, "Interior travel and escape never rebuild the outdoor city")
	game.set("dev_i", 11)
	game.call("WarpDev")
	await frames(game)
	check(not city.visible and view.camera.environment == null and not city.audio.playing, "Leaving stops exploration rendering, environment, and alarm")
	game.set("dev_i", 13)
	game.call("WarpDev")
	await frames(game)
	check(city.place == "surface" and city.inventory.is_empty() and city.discovered.is_empty() and not city.awakening, "Fresh dev entry resets the independent prototype")
	check(city.world.mesh.get_instance_id() == mesh_id, "Fresh entry reuses the expanded city")
	print("EXPLORATION_RESULT=", checks - failures, "/", checks)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
