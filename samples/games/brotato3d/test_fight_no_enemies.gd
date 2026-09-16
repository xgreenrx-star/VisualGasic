extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("start_game")
	for frame in range(600):
		var t := Time.get_ticks_msec()
		await process_frame
		var dt := Time.get_ticks_msec() - t
		if dt > 2500:
			print("FAIL: hang frame %d dt=%d" % [frame, dt])
			quit(1)
			return
		if frame % 120 == 0:
			print("frame %d dt=%d" % [frame, dt])
	print("PASS: fight_no_enemies")
	quit(0)
