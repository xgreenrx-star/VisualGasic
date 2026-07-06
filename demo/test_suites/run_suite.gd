extends SceneTree

# Universal VisualGasic Test Runner
# Reads test file path from res://current_test.txt
# Loads the VG script, attaches to a child Node, runs for N frames, quits.

var max_frames: int = 120

func _init():
	# Read test file path from current_test.txt
	var f = FileAccess.open("res://current_test.txt", FileAccess.READ)
	if f == null:
		print("ERROR: Cannot open res://current_test.txt")
		quit()
		return
	
	var vg_path = f.get_line().strip_edges()
	f.close()
	
	if vg_path == "":
		print("ERROR: Empty test file path")
		quit()
		return
	
	# Check if file has a max_frames override by reading the VG source
	var vgf = FileAccess.open(vg_path, FileAccess.READ)
	if vgf:
		for i in range(5):
			if vgf.eof_reached():
				break
			var line = vgf.get_line()
			if line.strip_edges().begins_with("' MAX_FRAMES:"):
				var val = line.strip_edges().substr(len("' MAX_FRAMES:")).strip_edges()
				if val.is_valid_int():
					max_frames = int(val)
		vgf.close()
	
	# Load the VG script
	var script = load(vg_path)
	if script == null:
		print("ERROR: Failed to load " + vg_path)
		quit()
		return
	
	# Create test node and attach script
	var test_node = Node.new()
	test_node.name = "TestNode"
	test_node.set_script(script)
	root.add_child(test_node)

var _frame: int = 0
func _process(_delta):
	_frame += 1
	if _frame >= max_frames:
		quit()
