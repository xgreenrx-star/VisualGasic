extends SceneTree

func _init():
	var script = load("res://test_playback_live.vg")
	if not script:
		print("FAIL: Could not load test_playback_live.vg")
		quit()
		return
	var node = Node.new()
	node.name = "TestPlaybackLive"
	node.set_script(script)
	root.add_child(node)

var _frames = 0
func _process(delta):
	_frames += 1
	if _frames > 220:
		quit()
