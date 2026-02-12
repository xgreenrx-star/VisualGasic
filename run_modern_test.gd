extends SceneTree

func _init():
	var script_class = load("res://test_modern_features.vg")
	if script_class == null:
		print("ERROR: Could not load test_modern_features.vg")
		quit(1)
		return
	var obj = RefCounted.new()
	obj.set_script(script_class)
	print("--- Modern Features Test Complete ---")
	quit(0)
