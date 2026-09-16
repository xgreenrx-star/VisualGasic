extends SceneTree
## Debug Phase 3 Headless Test
## Run with: godot --headless --script res://test_debug_headless.gd

func _init():
	print("=== Phase 3 Debug Headless Test ===")
	print("")
	
	# Check EngineDebugger availability
	print("EngineDebugger check:")
	print("  is_active: ", EngineDebugger.is_active())
	print("")
	
	# Test 1: Load and validate VisualGasic script
	print("Test 1: Loading Visual Gasic script...")
	var script_path = "res://test_debug_phase3.vg"
	
	if not FileAccess.file_exists(script_path):
		printerr("  FAIL: Script not found")
		quit(1)
		return
	
	var script = load(script_path)
	if not script:
		printerr("  FAIL: Could not load script")
		quit(1)
		return
	
	print("  OK: Script loaded successfully")
	print("  Class: ", script.get_class())
	
	# Test 2: Check if VisualGasicLanguage is registered
	print("")
	print("Test 2: Checking VisualGasicLanguage...")
	if ClassDB.class_exists("VisualGasicLanguage"):
		print("  OK: VisualGasicLanguage class exists")
	else:
		print("  WARN: VisualGasicLanguage not in ClassDB (normal for GDExtension)")
	
	# Test 3: Create instance and run
	print("")
	print("Test 3: Creating script instance...")
	var test_node = Node.new()
	test_node.name = "TestNode"
	test_node.set_script(script)
	root.add_child(test_node)
	print("  OK: Instance created and added to tree")
	
	# Test 4: Set up breakpoints file
	print("")
	print("Test 4: Setting up breakpoints...")
	var bp_data = {
		script_path: [17, 22, 30]
	}
	var file = FileAccess.open("res://.vg_breakpoints.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(bp_data))
		file.close()
		print("  OK: Breakpoints file created")
	else:
		print("  WARN: Could not create breakpoints file")
	
	# Test 5: Execute Main
	print("")
	print("Test 5: Executing Main()...")
	print("--- Script Output Start ---")
	var result = test_node.call("Main")
	print("--- Script Output End ---")
	print("")
	print("  OK: Execution completed")
	if result != null:
		print("  Return value: ", result)
	
	# Cleanup
	test_node.queue_free()
	
	print("")
	print("=== All Tests Passed ===")
	print("")
	print("Note: To test actual breakpoint pausing, run with the debugger attached:")
	print("  godot --debug res://test_debug_phase3.vg")
	print("")
	
	# Exit cleanly
	await create_timer(0.1).timeout
	quit(0)
