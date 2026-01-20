extends SceneTree

func _init():
	print("Starting Signal Test...")
	var root = Node2D.new()
	root.name = "Form"
	
	# Load Script
	var script = load("res://test_signals_manual.bas")
	if not script:
		print("Error loading script")
		quit(1)
		return
		
	root.set_script(script)
	
	# Add Button
	var btn = Button.new()
	btn.name = "Button1"
	root.add_child(btn)
	
	# Add to Scene Tree to trigger Notification Ready
	get_root().add_child(root)
	
	# Wait for frames
	await process_frame
	await process_frame
	
	print("Checking connections for Button1...")
	var conns = btn.get_signal_connection_list("pressed")
	
	if conns.size() > 0:
		print("PASS: Button1 is connected. Count: " + str(conns.size()))
		for c in conns:
			print(" - Signal: " + c.signal.get_name() + " -> Method: " + str(c.callable.get_method()))
			
		# Simulate Click
		print("Simulating Press...")
		btn.pressed.emit()
	else:
		print("FAIL: Button1 is in tree but NOT connected.")
		print("Node Name: ", btn.name)
		# Script methods check
		print("Source Code: ", script.source_code)
		# NOTE: script.has_method might verify runtime detection
	
	quit()
