
extends SceneTree

func _init():
	print("Running Tab Order Tool Test...")
	
	# 1. Setup Mock Scene
	var container = Control.new()
	container.name = "Form"
	
	var b1 = Button.new(); b1.name = "Button1"; container.add_child(b1)
	var b2 = Button.new(); b2.name = "Button2"; container.add_child(b2)
	var b3 = Button.new(); b3.name = "Button3"; container.add_child(b3)
	
	print("Initial Order: Using get_child(i)")
	print_children(container)
	if container.get_child(0).name != "Button1": printerr("FAIL: Initial order wrong"); quit(1); return
	
	# 2. Load Tool
	var tool_script = load("res://addons/visual_gasic/tab_order_editor.gd")
	if not tool_script:
		print("Error: Could not load tool script")
		quit(1)
		return
		
	var tool_instance = tool_script.new()
	# Don't add to tree, just use logic if possible, or add to root if needed for signals?
	# Signals aren't strictly needed for direct calls, but some UI components might need to be ready.
	# Let's try without adding to tree first.
	
	# 3. Initialize Tool with Container
	tool_instance.set_root(container)
	
	if tool_instance.tree.item_count != 3:
		printerr("FAIL: Tool did not populate list. Count: ", tool_instance.tree.item_count)
		quit(1); return
	
	# 4. Test Move Up
	# Select Button2 (Index 1)
	print("\nAction: Selecting Index 1 (Button2) and Moving Up")
	tool_instance.tree.select(1)
	tool_instance._move_up()
	
	print_children(container)
	if container.get_child(0).name == "Button2" and container.get_child(1).name == "Button1":
		print("SUCCESS: Button2 moved up.")
	else:
		printerr("FAIL: Button2 did not move up.")
		quit(1); return

	# 5. Test Move Down
	# Button2 is now at Index 0. Select and move down.
	print("\nAction: Selecting Index 0 (Button2) and Moving Down")
	tool_instance.tree.select(0)
	tool_instance._move_down()
	
	print_children(container)
	if container.get_child(1).name == "Button2":
		print("SUCCESS: Button2 moved down.")
	else:
		printerr("FAIL: Button2 did not move down.")
		quit(1); return
		
	# 6. Test Move Down (Boundary)
	# Button3 is at Index 2 (Last). Move Down should do nothing.
	print("\nAction: Selecting Index 2 (Button3) and Moving Down")
	tool_instance.tree.select(2)
	tool_instance._move_down()
	
	if container.get_child(2).name == "Button3":
		print("SUCCESS: Boundary check passed (Button3 stayed at bottom).")
	else:
		printerr("FAIL: Boundary check failed.")
		quit(1); return

	print("\nTests Complete. All passed.")
	
	# Cleanup
	tool_instance.free()
	container.free()
	
	quit(0)

func print_children(node):
	var s = "["
	for c in node.get_children():
		s += c.name + ", "
	s += "]"
	print(s)
