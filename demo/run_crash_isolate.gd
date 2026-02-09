extends SceneTree
func _init():
	var s = load("res://test_crash_isolate.vg")
	if not s:
		print("FAIL load")
		quit()
		return
	var o = Node.new()
	o.set_script(s)
	if o.has_method("Main"): o.Main()
	o.free()
	quit()
