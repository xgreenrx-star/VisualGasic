@tool
extends EditorScript

func _run():
	print("Testing preload of immediate_window.gd...")
	var test = load("res://addons/visual_gasic/immediate_window.gd")
	if test:
		print("✅ Load succeeded!")
		var instance = test.new()
		print("✅ Instantiation succeeded!")
		instance.free()
	else:
		print("❌ Load failed!")
