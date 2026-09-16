extends SceneTree

func _initialize() -> void:
	print("=== start_game frame probe ===")
	var main_ps: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = main_ps.instantiate()
	root.add_child(main)
	await process_frame
	print("frame 0 ok")
	main.call("start_game")
	print("start_game returned")
	for i in range(1, 120):
		await process_frame
		var enemies := root.get_node("Main").get_tree().get_nodes_in_group("enemies")
		print("frame %d enemies=%d" % [i, enemies.size()])
		if i >= 30 and enemies.size() >= 3:
			print("PASS: brotato3d_start_game_frames")
			quit(0)
			return
	print("FAIL: brotato3d_start_game_frames: insufficient spawns")
	quit(1)
