extends SceneTree

func _init():
	var script_res = load("res://test_packed_arrays.vg")
	if not script_res:
		print("FAIL: Could not load test_packed_arrays.vg")
		quit()
		return
	var node = Node.new()
	node.name = "TestPackedArrays"
	node.set_script(script_res)
	root.add_child(node)
	# Explicitly run Main so it's deterministic regardless of auto-run
	if node.has_method("Main"):
		node.call("Main")
	else:
		print("FAIL: no Main()")

var _frames = 0
func _process(_delta):
	_frames += 1
	if _frames > 3:
		quit()
