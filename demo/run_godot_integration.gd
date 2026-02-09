@tool
extends EditorScript

## Run Godot Integration Tests for Section 4.1
## Execute via: godot --headless --path demo --script ../tests/run_godot_integration.gd --quit

func _run():
	print("\n=== Running Godot Integration Tests ===\n")
	
	# Load the test script
	var script_path = "res://../tests/test_godot_integration.vg"
	var local_path = "res://test_godot_integration.vg"
	
	# Try to find the script
	var script: Script = null
	if FileAccess.file_exists(script_path):
		script = load(script_path)
	elif FileAccess.file_exists(local_path):
		script = load(local_path)
	elif FileAccess.file_exists("../tests/test_godot_integration.vg"):
		script = load("../tests/test_godot_integration.vg")
	
	if not script:
		# Copy test file to demo directory
		var source = FileAccess.open("/home/Commodore/Documents/VisualGasic/tests/test_godot_integration.vg", FileAccess.READ)
		if source:
			var dest = FileAccess.open("res://test_godot_integration.vg", FileAccess.WRITE)
			if dest:
				dest.store_string(source.get_as_text())
				dest.close()
			source.close()
			script = load("res://test_godot_integration.vg")
	
	if not script:
		printerr("ERROR: Could not load test_godot_integration.vg")
		return
	
	# Create a test node (Control since we test position, modulate, etc.)
	var test_node = Control.new()
	test_node.name = "GodotIntegrationTestNode"
	test_node.set_script(script)
	
	# Add to tree so _Ready fires
	get_editor_interface().get_edited_scene_root().add_child(test_node)
	
	# Let it run for a moment (for _Process tests)
	print("Test node added. _Ready should have been called.")
	print("Waiting for _Process tests (5 frames)...")
	
	# Schedule cleanup
	await get_tree().create_timer(0.5).timeout
	
	print("\nTest complete. Cleaning up...")
	test_node.queue_free()
