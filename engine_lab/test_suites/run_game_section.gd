extends SceneTree

## Test Section 4.2 Game-Specific Keywords
## Execute via: godot --headless --path demo -s run_game_section.gd --quit

func _initialize():
	print("\n=== Section 4.2 Game-Specific Keywords Test ===\n")
	
	# Load the test script
	var script: Script = load("res://test_game_section42.vg")
	
	if not script:
		print("ERROR: Could not load test_game_section42.vg")
		quit()
		return
	
	# Create a test node (Control for 2D)
	var test_node = Control.new()
	test_node.name = "GameKeywordsTestNode"
	test_node.set_script(script)
	
	# Add to tree
	root.add_child(test_node)
	
	print("Test node added. Running tests...")
	print("")
	
	# Clean up and quit
	test_node.queue_free()
	quit()
