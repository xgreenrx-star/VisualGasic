extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func render(ring: Node) -> Image:
	ring.queue_redraw()
	for index in range(3):
		await process_frame
	return root.get_texture().get_image()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Result display test requires a graphical renderer.")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.call("ReleaseBootTerminal")
	game.set_process(false)
	game.set("opt_orac_voice", false)
	game.set("dev_i", 20)
	game.call("WarpDev")
	var ring: Node = game.get("ownership_ring")
	var feedback: Node = ring.get("terminal_feedback")
	feedback.set_process(false)
	feedback.set("mode", "DEFENDER")
	feedback.call("update_displays")
	ring.set("reduced_motion", true)
	ring.call("set_help", false)
	ring.call("begin_round")
	var owners: Array = ring.get("owners")
	for index in range(12):
		owners[index] = 1 if index < 5 else -1 if index < 8 else 0
	ring.set("remaining", 0)
	ring.call("finish_round")
	check(ring.get("stage") == "WIN" and ring.call("score", 1) == 5 and ring.call("score", -1) == 3, "screenshot_five_three_result_is_player_victory")
	var first := await render(ring)
	var network: Array = ring.get("player_network")
	network[0][9]["kind"] = "LINK"
	network[1][7]["kind"] = "LINK"
	var no_repeaters := await render(ring)
	var scale_factor := Vector2(first.get_size()) / Vector2(960, 540)
	var rect := Rect2i(Vector2(230, 70) * scale_factor, Vector2(220, 290) * scale_factor)
	var changed := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if first.get_pixel(x, y) != no_repeaters.get_pixel(x, y):
				changed += 1
	check(changed > 30, "repeater_box_loops_change_actual_board_pixels")
	network[0][9]["kind"] = "LATCH"
	network[1][7]["kind"] = "LATCH"
	var directory := OS.get_environment("ASH_TERMINAL_CAPTURE_DIR")
	if directory != "":
		var image := await render(ring)
		check(image.save_png(directory.path_join("terminal-five-three-win.png")) == OK, "save_verified_five_three_victory")
	game.queue_free()
	await process_frame
	print("SUIT_RESULT_DISPLAY_COMPLETED: ", failures, " failures")
	quit(failures)
