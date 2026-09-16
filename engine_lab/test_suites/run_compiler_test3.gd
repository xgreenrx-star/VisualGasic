extends SceneTree

func _init():
	var script_res = load("res://test_compiler_features3.vg")
	if script_res == null:
		print("ERROR: Could not load test_compiler_features3.vg")
		quit(1)
		return

	var obj = RefCounted.new()
	obj.set_script(script_res)
	obj.call("Main")
	quit()
