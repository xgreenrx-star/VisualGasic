extends SceneTree

func _init():
	var vg = load("res://addons/visual_gasic/visual_gasic.gdextension")
	
	var script = load("res://test_member_assign.vg")
	if not script:
		print("ERROR: Could not load test_member_assign.vg")
		quit(1)
		return
	
	var node = Node2D.new()
	node.set_script(script)
	root.add_child(node)
	
	# Give it a frame to initialize
	await process_frame
	
	# Call Main
	node.call("Main")
	
	await process_frame
	quit(0)
