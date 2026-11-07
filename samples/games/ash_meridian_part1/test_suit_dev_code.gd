extends SceneTree

var failures := 0
const CODE := [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A, KEY_B, KEY_A]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func press(code: int, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.call("ReleaseBootTerminal")
	game.set("opt_orac_voice", false)
	for mode in ["help", "game", "result", "terminal"]:
		game.set("dev_on", false)
		game.set("code_i", 0)
		game.set("dev_i", 21 if mode == "terminal" else 20)
		game.call("WarpDev")
		var ring: Node = game.get("ownership_ring")
		if mode in ["game", "result"]:
			ring.call("set_help", false)
			ring.call("begin_round")
		if mode == "result":
			ring.call("finish_round")
		await process_frame
		await press(KEY_UP, true)
		check(game.get("code_i") == 0, "held_key_echo_does_not_advance_" + mode)
		for index in range(CODE.size()):
			await press(CODE[index])
			if index < CODE.size() - 1:
				check(not game.get("dev_on"), "no_early_unlock_" + mode + "_" + str(index))
		check(game.get("dev_on") and game.get("code_i") == 0, "full_code_opens_existing_dev_menu_" + mode)
		check(ring.get("loader_step") == (1 if mode == "terminal" else 0), "dev_menu_does_not_restart_terminal_or_match_" + mode)
	game.queue_free()
	await process_frame
	print("SUIT_DEV_CODE_COMPLETED: ", failures, " failures")
	quit(failures)
