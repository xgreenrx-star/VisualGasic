extends SceneTree

func _init():
	var script_res = load("res://test_process_count.vg")
	if not script_res:
		print("FAIL: Could not load test_process_count.vg")
		quit()
		return
	var node = Node.new()
	node.name = "TestProcessCount"
	node.set_script(script_res)
	root.add_child(node)

var _frames = 0
func _process(delta):
	_frames += 1
	var pc = node.get("processCount") if node else null
	if _frames <= 5:
		print("[GD frame %d] VG processCount=%s" % [_frames, pc])
	if _frames == 10:
		print("[GD frame %d] Final VG processCount=%s (expect ~10, not ~20)" % [_frames, pc])
		if pc != null and pc is int:
			if pc <= _frames + 2:
				print("PASS - single _Process per frame")
			else:
				print("FAIL - %d VG calls in %d frames = %.1fx" % [pc, _frames, float(pc)/_frames])
		quit()

var node: Node
