extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("start_game")
	var go: Node = main.get_node("GameObjects")
	var enemy_ps: PackedScene = load("res://scenes/Enemy3D.tscn")
	for i in range(5):
		var e: Node = enemy_ps.instantiate()
		go.add_child(e)
		e.call("Setup", 30.0, 100.0, 5.0, 2, 1)
		e.call("ApplySkin", "character-b", Color(1, 0.5, 0.5))
		e.global_position = Vector3(50.0 + i * 2.0, 0.05, 0.0)
		await process_frame
	print("5 enemies ready")
	for frame in range(200):
		if frame % 10 == 0:
			print("before frame %d bullets=%d" % [
				frame, main.get_tree().get_nodes_in_group("bullets").size()
			])
		await process_frame
	print("PASS: five enemies 200 frames")
	quit(0)
