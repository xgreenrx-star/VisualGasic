extends SceneTree

func _initialize() -> void:
	Engine.max_fps = 0
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.call("ReleaseBootTerminal")
	game.set("opt_fps", false)
	game.set("dev_i", 20)
	game.call("WarpDev")
	var ring: Object = game.get("ownership_ring")
	ring.call("set_help", false)
	ring.call("begin_round")
	ring.set("practice", true)
	ring.set("untimed", true)
	var feedback: Node = ring.get("terminal_feedback")
	var face: Node2D = feedback.get("defender")
	for enabled in [true, false]:
		face.visible = enabled
		for index in range(15):
			await process_frame
		var start := Time.get_ticks_usec()
		for index in range(90):
			await process_frame
		var milliseconds := float(Time.get_ticks_usec() - start) / 90000.0
		print("PANEL_PERF face=", enabled, " mean_frame_ms=", snappedf(milliseconds, 0.01))
	game.queue_free()
	await process_frame
	print("PANEL_PERF_COMPLETED")
	quit()
