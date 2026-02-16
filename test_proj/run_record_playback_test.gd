extends SceneTree

func _init():
	var script = load("res://test_record_playback.vg")
	if not script:
		print("FAIL: Could not load test_record_playback.vg")
		quit()
		return
	var node = Node.new()
	node.name = "TestRecordPlayback"
	node.set_script(script)
	root.add_child(node)

var _frames = 0
func _process(delta):
	_frames += 1
	if _frames > 280:
		quit()
