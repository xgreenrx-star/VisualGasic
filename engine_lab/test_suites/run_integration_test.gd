extends SceneTree

## Standalone test runner for Godot Integration (Section 4.1)

var test_node: Control
var frame_count: int = 0

func _init():
	print("\n=== Section 4.1 Godot Integration Tests ===\n")

func _process(delta: float) -> bool:
	frame_count += 1
	
	if frame_count == 1:
		# Copy and run test
		_setup_test()
	elif frame_count > 10:
		# Cleanup and exit
		if test_node:
			test_node.queue_free()
		print("\n=== Test Complete ===")
		quit()
		return true
	
	return false

func _setup_test():
	# Copy test file to demo
	var src_path = "/home/Commodore/Documents/VisualGasic/tests/test_godot_integration.vg"
	var dst_path = "res://test_godot_integration.vg"
	
	var src = FileAccess.open(src_path, FileAccess.READ)
	if src:
		var content = src.get_as_text()
		src.close()
		
		var dst = FileAccess.open(dst_path, FileAccess.WRITE)
		if dst:
			dst.store_string(content)
			dst.close()
			print("Copied test script to demo/")
	
	# Load the script
	var script = load(dst_path)
	if not script:
		printerr("ERROR: Could not load test script")
		return
	
	# Create Control node (tests need position, modulate, etc.)
	test_node = Control.new()
	test_node.name = "TestNode"
	test_node.set_script(script)
	
	# Add to scene
	root.add_child(test_node)
	print("Test node created and added to tree\n")
