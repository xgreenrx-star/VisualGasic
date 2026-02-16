extends SceneTree

func _init():
	var script = load("res://test_byref_loop.vg")
	if script == null:
		print("FAIL: Could not load test_byref_loop.vg")
		quit()
		return
	var node = Node.new()
	node.name = "TestByRefLoop"
	node.set_script(script)
	root.add_child(node)

var _frames = 0
func _process(delta):
	_frames += 1
	if _frames > 30:
		quit()
