extends SceneTree

func _init():
	var vg = load("res://addons/visual_gasic/visual_gasic.gdextension")
	
	var script = load("res://test_galdef_repro.vg")
	if not script:
		print("ERROR: Could not load test_galdef_repro.vg")
		quit(1)
		return
	
	var node = Node2D.new()
	node.set_script(script)
	root.add_child(node)
	
	await process_frame
	
	node.call("Main")
	
	await process_frame
	quit(0)
