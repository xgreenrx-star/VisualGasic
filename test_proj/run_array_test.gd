extends SceneTree

func _init():
	var script_res = load("res://test_array_globals.vg")
	if not script_res:
		print("FAIL: Could not load test_array_globals.vg")
		quit()
		return
	var node = Node.new()
	node.name = "TestArrayGlobals"
	node.set_script(script_res)
	root.add_child(node)

var _frames = 0
func _process(delta):
	_frames += 1
	if _frames > 20:
		quit()
