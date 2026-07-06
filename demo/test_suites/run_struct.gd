extends SceneTree

func _init():
	var script = load("res://test_struct_simple.vg")
	if not script:
		print("Failed to load script")
		quit()
		return

	print("=== Struct/Type Test ===")
	
	var obj = Node.new()
	obj.set_name("StructTest")
	obj.set_script(script)
	
	if obj.has_method("Main"):
		obj.Main()
	
	obj.free()
	quit()
