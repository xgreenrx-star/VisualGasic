extends SceneTree

var frame_count: int = 0

func _init():
	print("\n=== Simple Me Keyword Test ===\n")

func _process(delta: float) -> bool:
	frame_count += 1
	
	if frame_count == 1:
		var script = load("res://test_me_simple.vg")
		if script:
			var test_node = Control.new()
			test_node.name = "TestMeNode"
			test_node.set_script(script)
			root.add_child(test_node)
		else:
			print("Failed to load script")
	elif frame_count > 5:
		print("\n=== Test Complete ===")
		quit()
		return true
	
	return false
