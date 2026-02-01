extends SceneTree

func _init():
	print("Testing VGForm")
	var script = load("res://custom_widgets/VGFormMinimal.vg")
	if script == null:
		print("FAILED to load")
		quit(1)
		return
	print("SUCCESS loaded")
	var window = Window.new()
	window.set_script(script)
	window.title = "TestForm"
	window.size = Vector2(400, 300)
	root.add_child(window)
	await create_timer(0.1).timeout
	print("Position:", window.position)
	print("Size:", window.size)
	print("Children:", window.get_child_count())
	print("Complete")
	quit(0)
