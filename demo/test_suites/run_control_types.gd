@tool
extends SceneTree

func _init():
	# Load and run the control types test
	var script_class = load("res://addons/visual_gasic/visual_gasic_script.gd")
	if not script_class:
		# Try GDExtension version
		if ClassDB.class_exists("VisualGasicScript"):
			script_class = ClassDB.instantiate("VisualGasicScript")
		else:
			printerr("VisualGasicScript not found!")
			quit()
			return
	
	var script = script_class.new() if script_class is GDScript else script_class
	var source = FileAccess.get_file_as_string("res://test_control_types.vg")
	script.set_source_code(source)
	script.reload()
	
	# Create a simple Control as owner
	var root = Control.new()
	root.set_script(script)
	
	# Add to tree
	get_root().add_child(root)
	
	# Call Main
	print("")
	if root.has_method("Main"):
		root.Main()
	elif root.has_method("_ready"):
		# _ready should have called it
		pass
	
	print("")
	
	# Cleanup
	call_deferred("_cleanup", root)

func _cleanup(root):
	root.queue_free()
	call_deferred("quit")
