extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("start_game")
	var gm := root.get_node("GameManager")
	gm.set("player_weapons", [])
	var go: Node = main.get_node("GameObjects")
	var enemy_ps: PackedScene = load("res://scenes/Enemy3D.tscn")
	for i in range(5):
		var e: Node = enemy_ps.instantiate()
		go.add_child(e)
		e.call("Setup", 30.0, 100.0, 5.0, 2, 1)
		e.call("ApplySkin", "character-b", Color(1, 0.5, 0.5))
		e.global_position = Vector3(8.0, 0.05, float(i) * 2.0)
		await process_frame
	for frame in range(200):
		await process_frame
	print("PASS: no weapons 5 close enemies")
	quit(0)
