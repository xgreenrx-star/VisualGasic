extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("start_game")
	var wm: Node = main.get_node("WaveManager")
	for frame in range(2000):
		var t := Time.get_ticks_msec()
		if frame == 60 or frame == 120 or frame == 180:
			wm.call("_on_spawn_timer_timeout")
		await process_frame
		var dt := Time.get_ticks_msec() - t
		var enemies := main.get_tree().get_nodes_in_group("enemies").size()
		if dt > 200 or frame % 20 == 0:
			print("frame %d dt=%dms enemies=%d warnings=%d" % [
				frame, dt,
				enemies,
				main.get_tree().get_nodes_in_group("spawn_warning").size() if main.get_tree().has_group("spawn_warning") else -1
			])
		if dt > 3000:
			print("HANG at frame %d dt=%dms enemies=%d" % [frame, dt, enemies])
			quit(1)
			return
	print("PASS: no hang in 2000 frames")
	quit(0)
