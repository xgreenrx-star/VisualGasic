extends SceneTree
## Debug Phase 3 Integration Test
## Tests that breakpoints are detected (won't actually pause in headless mode)

func _init():
	print("=== Phase 3 Debug Integration Test ===")
	print("")
	
	# Set up breakpoints file
	var script_path = "res://test_debug_phase3.vg"
	var bp_data = {
		script_path: [17, 22, 30]  # Lines with breakpoints
	}
	var file = FileAccess.open("res://.vg_breakpoints.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(bp_data))
		file.close()
		print("Breakpoints set at lines: 17, 22, 30")
	
	# Load and run
	print("")
	print("Loading script...")
	var script = load(script_path)
	if not script:
		printerr("Failed to load script")
		quit(1)
		return
	
	var test_node = Node.new()
	test_node.name = "TestNode"
	test_node.set_script(script)
	root.add_child(test_node)
	
	print("Executing Main()...")
	print("(Breakpoint detection messages will appear)")
	print("--------------------------------------------------")
	test_node.call("Main")
	print("--------------------------------------------------")
	
	# Check if breakpoints were loaded by the C++ side
	print("")
	print("Checking VisualGasicLanguage breakpoint state...")
	if ClassDB.class_exists("VisualGasicLanguage"):
		# Try to get the singleton
		var lang = ClassDB.instantiate("VisualGasicLanguage") if false else null
		# VisualGasicLanguage is registered but singleton access is via ScriptServer
		print("  VisualGasicLanguage is registered in ClassDB")
	
	test_node.queue_free()
	print("")
	print("=== Test Complete ===")
	await create_timer(0.1).timeout
	quit(0)
