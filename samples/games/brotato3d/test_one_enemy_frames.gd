extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("start_game")
	var go: Node = main.get_node("GameObjects")
	var e: Node = load("res://scenes/Enemy3D.tscn").instantiate()
	go.add_child(e)
	e.call("Setup", 30.0, 100.0, 5.0, 2, 1)
	e.call("ApplySkin", "character-b", Color(1, 0.5, 0.5))
	e.global_position = Vector3(50, 0.05, 0)
	print("1 enemy ready")
	for frame in range(50):
		print("before frame %d" % frame)
		await process_frame
		print("after frame %d" % frame)
	print("PASS: one enemy 50 frames")
	quit(0)
