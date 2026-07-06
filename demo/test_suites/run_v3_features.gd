extends SceneTree

func _init():
	var script = load("res://test_v3_features.vg")
	if not script:
		print("FAILED to load test_v3_features.vg")
		quit()
		return
	var obj = Node.new()
	obj.set_script(script)
	if obj.has_method("Main"):
		obj.Main()
	else:
		print("No Main() found")
	obj.free()
	print("RUN_COMPLETE")
	quit()
