extends SceneTree

func _init():
	print("Starting Button Runtime Wiring Test...")
	var root = Node2D.new()
	root.name = "Form"
	
	# Load Script
	var script = load("res://buttontest.bas")
	if not script:
		print("Error loading script")
		quit(1)
		return
		
	root.set_script(script)
	
	# Add to Scene Tree (Triggers _Ready and Wiring)
	get_root().add_child(root)
	
	# Wait for frames
	await process_frame
	await process_frame
	
	# Find Button
	var btn = root.get_node("MyButton")
	if not btn:
		print("FAIL: Button node not found. Runtime error in _Ready?")
		quit(1)
		return
		
	print("Found Button: " + btn.name)
	
	# Simulate Click
	print("Simulating Press...")
	btn.pressed.emit()
	
	await process_frame
	print("Test Finished.")
	quit()
