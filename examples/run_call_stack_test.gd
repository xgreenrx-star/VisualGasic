@tool
extends EditorScript
## Run Call Stack Test
##
## This script runs the test_call_stack.vg to test the debugger's call stack feature.
## To use: Open this script in Godot and press Ctrl+Shift+X (or File > Run)

func _run():
	print("=== Call Stack Debugger Test ===")
	print("Loading test_call_stack.vg...")
	
	var script = load("res://test_call_stack.vg")
	if not script:
		printerr("Failed to load test_call_stack.vg")
		return
	
	print("Script loaded successfully!")
	print("")
	print("To test the Call Stack feature:")
	print("1. Open test_call_stack.vg in the script editor")
	print("2. Set a breakpoint on line 39 (inside LevelThree)")
	print("3. Run the project with F5 (not this EditorScript)")
	print("4. When breakpoint hits, check the Stack tab in Immediate Window")
	print("")
	print("Expected stack at line 39:")
	print("  LevelThree  <- current (yellow)")
	print("  LevelTwo")
	print("  LevelOne")
	print("  Main")
	print("")
	print("Or set breakpoint on line 54 (inside AddNumbers) for 5-level stack:")
	print("  AddNumbers  <- current (yellow)")
	print("  LevelThree")
	print("  LevelTwo")
	print("  LevelOne")
	print("  Main")
