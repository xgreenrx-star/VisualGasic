extends SceneTree

func _init():
	var script = load("res://test_piano_diag.vg")
	if not script:
		print("FAIL: Could not load test_piano_diag.vg")
		quit()
		return
	var node = Node2D.new()
	node.name = "PianoDiag"
	node.set_script(script)
	root.add_child(node)

var _frames = 0
func _process(delta):
	_frames += 1
	if _frames > 2050:
		quit()
