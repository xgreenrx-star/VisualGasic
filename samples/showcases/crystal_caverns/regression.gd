extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func blank_cave(game: Node) -> void:
	game.call("RestartCave")
	var board: Array = game.get("board").duplicate()
	for y in range(12):
		for x in range(20):
			board[y * 20 + x] = 1 if x == 0 or y == 0 or x == 19 or y == 11 else 0
	game.set("board", board)
	game.set("playerX", 2)
	game.set("playerY", 8)

func put(game: Node, x: int, y: int, tile: int) -> void:
	var board: Array = game.get("board").duplicate()
	board[y * 20 + x] = tile
	game.set("board", board)

func tile(game: Node, x: int, y: int) -> int:
	return int(game.call("TileAt", x, y))

func press(key: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func wait_for_window_mode(mode: Window.Mode) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while root.mode != mode and Time.get_ticks_msec() < deadline:
		await process_frame

func route_step(game: Node, goal: Vector2i) -> Vector2i:
	var start := Vector2i(int(game.get("playerX")), int(game.get("playerY")))
	var frontier: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var cursor := 0
	while cursor < frontier.size():
		var pos := frontier[cursor]
		cursor += 1
		if pos == goal:
			var first := goal
			while parents[first] != start and first != start:
				first = parents[first]
			return first - start
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = pos + direction
			if parents.has(next) or next.x < 1 or next.x > 18 or next.y < 1 or next.y > 10:
				continue
			var content := tile(game, next.x, next.y)
			if content == 1 or content == 3 or (content == 5 and not game.get("exitOpen")):
				continue
			if tile(game, next.x, next.y - 1) == 3:
				continue
			parents[next] = pos
			frontier.append(next)
	return Vector2i.ZERO

func play_cave(game: Node) -> Array:
	game.call("RestartCave")
	var trace: Array = []
	for goal in [Vector2i(6, 1), Vector2i(3, 4), Vector2i(7, 7),
			Vector2i(3, 9), Vector2i(14, 9), Vector2i(14, 4), Vector2i(18, 10)]:
		var steps := 0
		while Vector2i(int(game.get("playerX")), int(game.get("playerY"))) != goal:
			var direction := route_step(game, goal)
			if direction == Vector2i.ZERO or game.get("gameState") != "playing" or steps >= 240:
				check(false, "authored cave has a safe bounded path to %s" % goal)
				return trace
			game.call("StepCave", direction.x, direction.y)
			trace.append([game.get("board").duplicate(), game.get("falling").duplicate(),
				game.get("playerX"), game.get("playerY"), game.get("crystals"), game.get("ticks")])
			steps += 1
	check(game.get("gameState") == "won", "authored cave can be completed through gameplay")
	check(game.get("crystals") == 6 and game.get("exitSignals") == 1,
		"six real pickups unlock exit exactly once")
	return trace

func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		check(false, "main scene loads")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	check(game.get("gameState") == "playing", "game initializes")
	check(game.get("board").size() == 240, "DATA cave has 240 cells")
	check(game.get("gemLabel").get_theme_color("font_color").g > 0.9,
		"native HUD uses readable RGB colors")
	var gems := 0
	for content in game.get("board"):
		if content == 4:
			gems += 1
	check(gems == 6, "authored DATA cave has exactly six crystals")
	for i in range(12):
		var texture: Variant = game.get("art")[i]
		check(texture is Texture2D and texture.get_width() == 8 and texture.get_height() == 8,
			"DATA sprite %d is cached as an 8x8 texture" % i)
	var miner: Texture2D = game.get("art")[8]
	check(miner.get_image().get_pixel(0, 0).a == 0, "miner DATA transparency preserved")
	check(tile(game, -1, 4) == 1 and tile(game, 20, 4) == 1, "out-of-bounds cells are solid")

	blank_cave(game)
	put(game, 3, 8, 2)
	game.call("StepCave", 1, 0)
	check(game.get("playerX") == 3 and tile(game, 3, 8) == 0, "moving digs dirt")
	put(game, 4, 8, 1)
	game.call("StepCave", 1, 0)
	check(game.get("playerX") == 3, "wall blocks movement")
	game.call("StepCave", 1, 1)
	check(game.get("playerX") == 3 and game.get("playerY") == 8, "diagonal movement rejected")

	blank_cave(game)
	put(game, 3, 8, 3)
	game.call("StepCave", 1, 0)
	check(game.get("playerX") == 3 and tile(game, 4, 8) == 3 and tile(game, 4, 9) == 0,
		"pushed rock does not also fall in the same tick")
	game.call("StepCave", 0, 0)
	check(tile(game, 4, 9) == 3 and tile(game, 4, 10) == 0,
		"rock falls exactly one cell per tick")
	game.call("StepCave", 0, 0)
	game.call("StepCave", 0, 0)
	check(tile(game, 4, 10) == 3 and not game.get("falling")[204],
		"rock settles on solid support")
	blank_cave(game)
	put(game, 6, 5, 3)
	put(game, 6, 6, 3)
	put(game, 8, 5, 4)
	game.call("StepCave", 0, 0)
	check(tile(game, 6, 5) == 0 and tile(game, 6, 6) == 3 and tile(game, 6, 7) == 3
		and tile(game, 6, 8) == 0, "stacked rocks advance once in bottom-up order")
	check(tile(game, 8, 5) == 4, "crystals remain stationary above empty cells")

	blank_cave(game)
	put(game, 3, 8, 3)
	put(game, 4, 8, 2)
	put(game, 3, 9, 1)
	game.call("StepCave", 1, 0)
	check(game.get("playerX") == 2 and tile(game, 3, 8) == 3, "cannot push into dirt")
	game.set("playerX", 3)
	game.set("playerY", 7)
	game.call("StepCave", 0, 1)
	check(game.get("playerY") == 7, "cannot push vertically")
	blank_cave(game)
	put(game, 3, 8, 3)
	var airborne: Array = game.get("falling").duplicate()
	airborne[163] = true
	game.set("falling", airborne)
	game.call("StepCave", 1, 0)
	check(game.get("playerX") == 2 and tile(game, 3, 9) == 3,
		"cannot push an airborne rock")

	blank_cave(game)
	put(game, 2, 7, 3)
	game.call("StepCave", 0, 0)
	check(game.get("gameState") == "lost" and game.get("defeatSignals") == 1,
		"rock crush triggers WHENEVER defeat")
	var after_death: Array = game.get("board").duplicate()
	game.call("StepCave", 1, 0)
	check(game.get("board") == after_death and game.get("defeatSignals") == 1,
		"defeat stops simulation without duplicate callbacks")

	blank_cave(game)
	put(game, 3, 8, 5)
	game.call("StepCave", 1, 0)
	check(game.get("playerX") == 2, "locked exit blocks movement")
	for i in range(6):
		put(game, 3 + i, 8, 4)
		game.call("StepCave", 1, 0)
	check(game.get("gemChanges") == 6 and game.get("gemText") == "CRYSTALS 6 / 6",
		"Changes watcher updates HUD on all six pickups")
	check(game.get("gemLabel").text == "CRYSTALS 6 / 6", "watcher updates visible crystal label")
	check(game.get("exitOpen") and game.get("exitSignals") == 1,
		"Becomes watcher unlocks exit at target")
	game.set("crystals", 6)
	check(game.get("gemChanges") == 6 and game.get("exitSignals") == 1,
		"assigning the same value does not retrigger Changes or Becomes")
	game.call("StepCave", 0, 0)
	check(game.get("exitSignals") == 1, "unchanged target does not retrigger exit watcher")
	put(game, 9, 8, 5)
	game.call("StepCave", 1, 0)
	check(game.get("gameState") == "won", "unlocked exit completes cave")

	blank_cave(game)
	game.set("secondsLeft", 11)
	game.set("ticks", 7)
	game.call("StepCave", 0, 0)
	check(game.get("secondsLeft") == 10 and game.get("lowTime") and game.get("warningSignals") == 1,
		"Below watcher warns when timer crosses ten seconds")
	game.call("StepCave", 0, 0)
	check(game.get("warningSignals") == 1, "low-time warning is edge-triggered")
	game.set("secondsLeft", 1)
	game.set("ticks", 15)
	game.call("StepCave", 0, 0)
	check(game.get("gameState") == "lost" and game.get("defeatSignals") == 1,
		"zero-time watcher ends run")
	press(KEY_R)
	check(game.get("gameState") == "playing" and not game.get("exitOpen") and not game.get("lowTime"),
		"restart clears defeat, exit and warning state")
	check(game.get("crystals") == 0 and game.get("secondsLeft") == 120
		and game.get("clockText") == "TIME 120", "restart restores counters and HUD")
	game.set("secondsLeft", 11)
	game.set("ticks", 7)
	game.call("StepCave", 0, 0)
	check(game.get("lowTime") and game.get("warningSignals") == 1,
		"restart rearms Below watcher")
	blank_cave(game)
	put(game, 2, 7, 3)
	game.call("StepCave", 0, 0)
	check(game.get("defeatSignals") == 1 and game.get("gameState") == "lost",
		"restart rearms crushing watcher")
	press(KEY_R)

	press(KEY_P)
	var before_pause: Array = game.get("board").duplicate()
	var tick_before: int = game.get("ticks")
	game.call("StepCave", 1, 0)
	game.call("AdvanceFrame", 0.25)
	check(game.get("paused") and game.get("board") == before_pause and game.get("ticks") == tick_before,
		"pause freezes movement, rocks and clock")
	check(game.get("pausePanel").visible, "pause panel is visible")
	press(KEY_P, true)
	check(game.get("paused"), "key repeat does not toggle pause")
	press(KEY_ESCAPE)
	check(not game.get("paused"), "Escape resumes")
	game.call("AdvanceFrame", 0.125)
	check(game.get("ticks") == tick_before + 1,
		"process advances one fixed simulation tick (ticks=%s, accumulator=%s)" % [
		game.get("ticks"), game.get("accumulator")])
	game.call("RestartCave")
	game.call("AdvanceFrame", 5.0)
	check(game.get("ticks") == 2, "long frame has bounded catch-up (ticks=%s, accumulator=%s)" % [
		game.get("ticks"), game.get("accumulator")])

	var first_trace := play_cave(game)
	var second_trace := play_cave(game)
	check(not first_trace.is_empty() and first_trace == second_trace,
		"restart and replay reproduce every cave/rock/player state")
	check(game.get("gemChanges") == 6 and game.get("exitSignals") == 1,
		"watchers rearm correctly on replay")
	var cave_traces: Array = [first_trace]
	for level in range(1, 3):
		press(KEY_N)
		check(game.get("levelIndex") == level and game.get("gameState") == "playing",
			"N advances to cave %d after victory" % (level + 1))
		check(game.get("secondsLeft") == [120, 100, 90][level],
			"cave %d reads its DATA time limit" % (level + 1))
		press(KEY_N)
		check(game.get("levelIndex") == level, "cannot skip an unfinished cave")
		var level_trace := play_cave(game)
		check(not level_trace.is_empty() and level_trace != cave_traces[0],
			"cave %d has distinct playable terrain" % (level + 1))
		var replay := play_cave(game)
		check(level_trace == replay, "cave %d replay is deterministic" % (level + 1))
		check(game.get("nextButton").visible, "victory reveals next-cave button")
		cave_traces.append(level_trace)
	game.get("nextButton").emit_signal("pressed")
	check(game.get("levelIndex") == 0 and game.get("gameState") == "playing",
		"final-cave button starts a new expedition")
	press(KEY_R)
	game.set_process(true)
	Input.action_press("ui_right")
	var input_deadline := Time.get_ticks_msec() + 2000
	while (int(game.get("ticks")) < 1 or int(game.get("playerX")) <= 1) and Time.get_ticks_msec() < input_deadline:
		await process_frame
	Input.action_release("ui_right")
	game.set_process(false)
	check(game.get("ticks") >= 1 and game.get("playerX") > 1,
		"real process notifications consume held movement input")
	press(KEY_R)
	if DisplayServer.get_name() != "headless":
		game.get("fullscreenButton").emit_signal("pressed")
		await process_frame
		check(root.mode == Window.MODE_FULLSCREEN, "fullscreen button changes actual window mode")
		press(KEY_F11, true)
		check(root.mode == Window.MODE_FULLSCREEN, "repeated F11 does not toggle mode")
		press(KEY_F11)
		await process_frame
		await wait_for_window_mode(Window.MODE_WINDOWED)
		check(root.mode == Window.MODE_WINDOWED, "F11 restores windowed mode")
		check(game.get("fullscreenButton").text == "Fullscreen (F11)",
			"fullscreen button label follows mode")
		root.size = Vector2i(704, 600)
		game.queue_redraw()
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(not image.is_empty(), "graphical showcase renders")
		check(image.get_pixel(33, 97) != image.get_pixel(1, 1),
			"rendered DATA wall differs from background")
		var hud_pixels := 0
		for y in range(16, 94):
			for x in range(32, 672):
				var pixel := image.get_pixel(x, y)
				if pixel.r > 0.3 or pixel.g > 0.3 or pixel.b > 0.3:
					hud_pixels += 1
		check(hud_pixels > 1000, "title and HUD are actually rendered")
		var capture: String = OS.get_environment("CRYSTAL_CAPTURE")
		if not capture.is_empty():
			check(image.save_png(capture) == OK, "save graphical evidence")
	else:
		print("NOT TESTED: graphical output (headless control)")
	check(await preload("res://regression_lifecycle.gd").release_scene(self, game),
		"scene destruction releases cached sound and active playback")
	print("CRYSTAL-CAVERNS RESULTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
