extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var e: Node = load("res://scenes/Enemy3D.tscn").instantiate()
	main.get_node("GameObjects").add_child(e)
	e.call("Setup", 30.0, 100.0, 5.0, 2, 1)
	e.call("ApplySkin", "character-b", Color(1, 0.5, 0.5))
	print("calling TakeHit...")
	e.call("TakeHit", 5.0)
	print("TakeHit returned")
	await process_frame
	print("PASS: takehit")
	quit(0)
