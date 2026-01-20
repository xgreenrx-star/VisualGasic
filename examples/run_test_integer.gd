extends SceneTree

func _init():
	var node = Node.new()
	var script = load("res://test_integer.bas")
	if not script:
		print("Failed to load basic script (is the plugin active/compiled?)")
		# If this fails, perhaps we need to manually enable the plugin in project settings or it's auto-detected.
		quit()
		return
	
	node.set_script(script)
	root.add_child(node)
	
	print("Runner finished setup")
	quit()
