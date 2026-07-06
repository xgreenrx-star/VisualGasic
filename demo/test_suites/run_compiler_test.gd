extends SceneTree

func _init():
	var args = OS.get_cmdline_user_args()
	var file = "test_compiler_features.vg"
	if args.size() > 0:
		file = args[0]
	
	print("Loading: ", file)
	var script_class = load("res://" + file)
	if script_class == null:
		print("ERROR: Could not load ", file)
		quit(1)
		return
	var obj = RefCounted.new()
	obj.set_script(script_class)
	if obj.has_method("Main"):
		obj.Main()
	quit(0)
