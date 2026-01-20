extends SceneTree

func _init():
	var script = load("res://test_inherit.bas")
	if not script:
		print("Failed to load script")
		quit(1)
		return

	# Create a Node2D to attach the script to
	var node = Node2D.new()
	node.set_script(script)
	
	# The script should have set the base type to Node2D if Inherits "Node2D" works?
	# Or at least instance_create wraps it.
	
	print("Script loaded. Base type: ", script.get_instance_base_type())
	
	# Add to tree to trigger _ready if implemented (but VisualGasic doesn't auto-hook _ready yet unless I did? 
	# Wait, VisualGasicInstance enables processing if _Process exists.
	# _Ready is called by Godot when entered tree.
	
	root.add_child(node)
	
	# Manually call _ready if needed or rely on Godot lifecycle
	# if node.has_method("_ready"):
	# 	node.call("_ready")
	
	quit(0)
