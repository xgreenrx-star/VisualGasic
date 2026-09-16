extends SceneTree

var enemy_count := 1

func _initialize() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("start_game")
	var go: Node = main.get_node("GameObjects")
	var enemy_ps: PackedScene = load("res://scenes/Enemy3D.tscn")
	for i in range(enemy_count):
		var e: Node = enemy_ps.instantiate()
		go.add_child(e)
		e.call("Setup", 30.0, 100.0, 5.0, 2, 1)
		e.call("ApplySkin", "character-b", Color(1, 0.5, 0.5))
		e.global_position = Vector3(50.0 + i, 0.05, 0.0)
		await process_frame
	print("spawned %d enemies" % enemy_count)
	for frame in range(300):
		var t := Time.get_ticks_msec()
		await process_frame
		var dt := Time.get_ticks_msec() - t
		if dt > 2500:
			print("FAIL: %d enemies hung at frame %d dt=%d" % [enemy_count, frame, dt])
			quit(1)
			return
	print("PASS: %d enemies ok" % enemy_count)
	quit(0)
