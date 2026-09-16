extends SceneTree

## Run Godot Integration Tests for Section 4.1
## Execute via: godot --headless --path demo -s run_godot_tests.gd --quit

func _initialize():
	print("\n=== Running Godot Integration Tests ===\n")
	
	# Load the test script
	var script: Script = load("res://test_godot_integration.vg")
	
	if not script:
		print("ERROR: Could not load test_godot_integration.vg")
		quit()
		return
	
	# Create a test node
	var test_node = Control.new()
	test_node.name = "GodotIntegrationTestNode"
	test_node.set_script(script)
	
	# Add to tree
	root.add_child(test_node)
	
	print("Test node added. _Ready should have been called.")
	
	print("\nTest complete. Cleaning up...")
	test_node.queue_free()
	quit()
