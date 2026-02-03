extends SceneTree

func _init():
	print("=== Breakpoint Test Scene ===")
	print("Set a breakpoint in test_breakpoint.vg and run this scene")
	print("")
	
	# Load the VG script
	var script = load("res://test_breakpoint.vg")
	if not script:
		print("ERROR: Could not load test_breakpoint.vg")
		quit(1)
		return
	
	print("Loaded script: ", script)
	
	# Create a node and attach the script
	var node = Node.new()
	node.name = "TestNode"
	node.set_script(script)
	
	# Add to tree
	root.add_child(node)
	
	# Wait a frame for script to initialize
	await process_frame
	
	# Call Main
	if node.has_method("Main"):
		print("Calling Main()...")
		node.call("Main")
		print("Main() returned")
	else:
		print("ERROR: No Main() method found")
	
	# Exit
	await process_frame
	quit(0)
