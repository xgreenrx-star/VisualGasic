extends SceneTree
## Debug Phase 3 Step Mode Verification Test
## Tests that step mode detection works correctly

func _init():
	print("=== Phase 3 Step Mode Verification ===")
	print("")
	
	# Check VisualGasicLanguage step methods are available
	print("Checking VisualGasicLanguage API...")
	
	if ClassDB.class_exists("VisualGasicLanguage"):
		print("  ✓ VisualGasicLanguage exists")
		
		# Check for methods we need
		var methods = ClassDB.class_get_method_list("VisualGasicLanguage")
		var step_methods = ["debug_step_into", "debug_step_over", "debug_step_out", "debug_continue"]
		
		for method_name in step_methods:
			var found = false
			for m in methods:
				if m["name"] == method_name:
					found = true
					break
			if found:
				print("  ✓ Has method: ", method_name)
			else:
				print("  ✗ Missing method: ", method_name)
	else:
		print("  ✗ VisualGasicLanguage not found")
	
	# Check EngineDebugger step methods
	print("")
	print("Checking EngineDebugger step API...")
	print("  lines_left: ", EngineDebugger.get_lines_left())
	print("  depth: ", EngineDebugger.get_depth())
	print("  is_active: ", EngineDebugger.is_active())
	
	# Note: We can't test actual stepping without running through a breakpoint first
	# But we can verify the API is available
	
	print("")
	print("=== Verification Complete ===")
	await create_timer(0.1).timeout
	quit(0)
