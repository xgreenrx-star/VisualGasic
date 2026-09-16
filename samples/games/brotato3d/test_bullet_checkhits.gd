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
	e.global_position = Vector3(0, 0.05, 0)
	var b: Node = load("res://scenes/Bullet3D.tscn").instantiate()
	go.add_child(b)
	b.global_position = Vector3(0, 0.8, 0)
	var p: Dictionary = {}
	p["dir"] = Vector3(1, 0, 0)
	p["damage"] = 14.0
	p["pierce"] = 1
	p["speed"] = 26.0
	p["lifetime"] = 1.8
	p["color"] = Color.YELLOW
	b.call("SetupExtended", p)
	await process_frame
	print("calling CheckHits from GDScript")
	b.call("CheckHits")
	print("CheckHits returned")
	print("PASS: bullet_checkhits")
	quit(0)
