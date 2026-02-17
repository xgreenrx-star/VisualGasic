extends SceneTree

func _init():
	print("=== Galactic Defender Full Flow Test ===")
	
	# Load the scene
	var scene = load("res://main.tscn")
	if scene == null:
		print("[FAIL] Could not load main.tscn")
		quit()
		return
	
	var node = scene.instantiate()
	root.add_child(node)
	
	# Let _Ready run (one frame)
	print("[INFO] Waiting for _Ready...")
