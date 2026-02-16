extends SceneTree

func _init():
	var script_res = load("res://test_piano_flow.vg")
	if not script_res:
		print("FAIL: Could not load test_piano_flow.vg")
		quit()
		return
	var node = Node.new()
	node.name = "TestPianoFlow"
	node.set_script(script_res)
	root.add_child(node)

var _frames = 0
func _process(delta):
	_frames += 1
	if _frames > 250:
		quit()
