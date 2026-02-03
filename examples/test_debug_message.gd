@tool
extends SceneTree
## Headless test to verify debug message flow

func _init():
	print("=== Debug Message Test ===")
	
	# Check if VisualGasicImmediate is available
	if not ClassDB.class_exists("VisualGasicImmediate"):
		print("✗ VisualGasicImmediate class not found")
		quit(1)
		return
	
	print("✓ VisualGasicImmediate class exists")
	
	# Check if EngineDebugger is available
	var engine_debugger = EngineDebugger
	print("✓ EngineDebugger singleton available")
	print("  - is_active: ", EngineDebugger.is_active())
	
	# Create a simple VG script and run it
	var vg_code = """
Sub Main()
    Dim x As Integer
    x = 1
    Print "Line 4"
    x = 2
    Print "Line 6"
    x = 3
    Print "Line 8"
End Sub
"""
	
	# Save test script
	var f = FileAccess.open("res://test_debug_bp.vg", FileAccess.WRITE)
	f.store_string(vg_code)
	f.close()
	print("✓ Created test_debug_bp.vg")
	
	# Try to load and compile
	if ClassDB.class_exists("VisualGasicLanguage"):
		var lang = ClassDB.instantiate("VisualGasicLanguage")
		print("✓ VisualGasicLanguage instantiated")
	
	# Load the script
	var script = load("res://test_debug_bp.vg")
	if script:
		print("✓ Script loaded: ", script)
		print("  - Type: ", script.get_class())
		
		# Check if we can set a breakpoint
		if EngineDebugger.is_active():
			print("  - Setting breakpoint at line 5...")
			EngineDebugger.insert_breakpoint(5, "res://test_debug_bp.vg")
			var has_bp = EngineDebugger.is_breakpoint(5, "res://test_debug_bp.vg")
			print("  - Has breakpoint: ", has_bp)
		else:
			print("  - EngineDebugger not active (expected in headless)")
	else:
		print("✗ Failed to load script")
	
	# Check VisualGasicImmediate methods
	var imm = ClassDB.instantiate("VisualGasicImmediate")
	if imm:
		print("✓ VisualGasicImmediate instantiated")
		
		# List available methods
		var methods = imm.get_method_list()
		print("  Debug-related methods:")
		for m in methods:
			var name = m["name"]
			if "debug" in name.to_lower() or "step" in name.to_lower():
				print("    - ", name)
	
	print("")
	print("=== Note ===")
	print("Debug messages only flow when:")
	print("1. Running from editor (not headless)")
	print("2. EngineDebugger.is_active() returns true")
	print("3. A session is connected to vg_debugger_plugin.gd")
	print("")
	print("To test break_hit messages:")
	print("1. Open the examples project in Godot editor")
	print("2. Set a breakpoint in any .vg file")
	print("3. Run the scene with that script")
	print("4. Check Output panel for [VG Debugger] messages")
	
	quit(0)
