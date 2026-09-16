extends SceneTree

func _init():
	print("=== VisualGasic v2.2.2 Headless Test Runner ===")
	
	var script_path = "res://debug_select.vg"
	
	# Load the VG script
	var script = load(script_path)
	if script == null:
		printerr("ERROR: Could not load " + script_path)
		quit(1)
		return
	
	print("Loaded: " + script_path)
	
	# Create a Node and attach the VG script
	var obj = Node.new()
	obj.set_script(script)
	
	print("Instance created, calling Main()...")
	print("")
	
	# Call Main
	if obj.has_method("Main"):
		obj.Main()
	else:
		printerr("ERROR: No Main() method found")
	
	print("")
	print("=== Test Runner Complete ===")
	obj.free()
	quit(0)
