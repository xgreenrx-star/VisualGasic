@tool
extends SceneTree

func _init():
	var bas_path = "res://test_modern.vg"
	print("Checking if resource exists: ", ResourceLoader.exists(bas_path))
	
	if ResourceLoader.exists(bas_path):
		var res = load(bas_path)
		print("Loaded: ", res)
	else:
		print("ResourceLoader does not recognize .vg directly.")
		
	# Check if we can fake it
	if ClassDB.class_exists("VisualGasicScript"):
		print("VisualGasicScript class exists.")
		var script = ClassDB.instantiate("VisualGasicScript")
		script.resource_path = bas_path
		
		# We can't actually 'edit' it from an EditorScript easily without EditorInterface access which EditorScript has.
		# But we know the class exists.
		print("Instance created okay.")
	else:
		print("VisualGasicScript class MISSING.")
	
	quit()

