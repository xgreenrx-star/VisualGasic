extends SceneTree

# Simulates pressing KEY_1 to trigger demo song playback in the Piano demo

var piano_node = null
var _frames = 0
var _key1_pressed = false

func _init():
	var script = load("res://piano.vg")
	if not script:
		print("FAIL: Could not load piano.vg")
		quit()
		return
	piano_node = Node2D.new()
	piano_node.name = "Piano"
	piano_node.set_script(script)
	root.add_child(piano_node)

func _process(delta):
	_frames += 1
	
	# Frame 5-10: simulate pressing KEY_1
	if _frames == 5:
		print("[test] Simulating KEY_1 press via InputMap is not possible headless.")
		print("[test] Instead, directly calling StartPlayback...")
		piano_node.call("call_vg_method", "StartPlayback", [true])
	
	# Report status every 30 frames
	if _frames % 30 == 0:
		print("[test frame " + str(_frames) + "] isPlaying = " + str(piano_node.get("isPlaying")) + " playbackIndex = " + str(piano_node.get("playbackIndex")))
	
	if _frames > 300:
		print("[test] Timeout - quitting")
		quit()
