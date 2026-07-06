@tool
extends EditorScript
## Debug Phase 3 Test Runner
## Run this from the Godot editor: Script > Run (Ctrl+Shift+X)
## Tests breakpoints, stepping, and the new script_debug() integration

func _run():
	print("=== Phase 3 Debug Test Runner ===")
	print("")
	
	# Load the test script
	var script_path = "res://test_debug_phase3.vg"
	if not FileAccess.file_exists(script_path):
		printerr("Test script not found: ", script_path)
		return
	
	var script = load(script_path)
	if not script:
		printerr("Failed to load test script")
		return
	
	print("Loaded script: ", script_path)
	print("Script class: ", script.get_class())
	
	# Create a test node to attach the script
	var test_node = Node.new()
	test_node.name = "DebugTestNode"
	test_node.set_script(script)
	
	# Add to scene tree temporarily
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(test_node)
		print("Added test node to scene tree")
		
		# Check if EngineDebugger is available
		var debugger = EngineDebugger
		if debugger:
			print("EngineDebugger is available")
			print("  is_active: ", debugger.is_active())
		
		# Set up breakpoints via JSON file (the way our debugger loads them)
		_setup_test_breakpoints(script_path)
		
		# Try to call Main
		if test_node.has_method("Main"):
			print("")
			print("--- Calling Main() ---")
			print("(Breakpoints should pause execution if debugger is active)")
			print("")
			test_node.Main()
		else:
			# For Visual Gasic, we need to use call()
			print("")
			print("--- Executing via call('Main') ---")
			var result = test_node.call("Main")
			print("Result: ", result)
		
		# Cleanup
		test_node.queue_free()
		print("")
		print("=== Test Complete ===")
	else:
		printerr("Could not get scene tree")
		test_node.free()

func _setup_test_breakpoints(script_path: String):
	"""Create a breakpoints JSON file for testing"""
	var bp_data = {
		script_path: [17, 22, 30, 45]  # Lines with breakpoints
	}
	
	var json_str = JSON.stringify(bp_data)
	var file = FileAccess.open("res://.vg_breakpoints.json", FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("Created test breakpoints at lines: 17, 22, 30, 45")
	else:
		printerr("Could not create breakpoints file")
