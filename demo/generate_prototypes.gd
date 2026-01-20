@tool
extends SceneTree

func _init():
	var tools = {
		"TextureRect": "TextureRect", # Was Control
		"Label": "Label",
		"LineEdit": "LineEdit",       # Was Control
		"Button": "Button",
		"CheckBox": "CheckBox",       # Was Button (CheckBox inherits Button, but explicit is better)
		"OptionButton": "OptionButton", # Was Button
		"Panel": "Panel",             # Was Control
		"ItemList": "ItemList",       # Was Control (ListBox)
		"HScrollBar": "HScrollBar",   # Was Control
		"VScrollBar": "VScrollBar",   # Was Control
		"Timer": "Timer",             # Was Node
		"FileDialog": "FileDialog"    # Was Node
	}
	
	var base_dir = "res://addons/visual_gasic/prototypes/"
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(base_dir):
		dir.make_dir_recursive(base_dir)
		
	for type in tools:
		var path = base_dir + type + ".tscn"
		var content = '[gd_scene format=3]\n\n[node name="' + type + '" type="' + tools[type] + '"]\n'
		
		# Add defaults for size so they aren't "dots"
		# Most controls (Control, Button, etc) benefit from a minimum size or offset
		if tools[type] != "Timer" and tools[type] != "FileDialog":
			if type == "ItemList":
				content += 'offset_right = 100.0\noffset_bottom = 100.0\n'
			elif type == "HScrollBar":
				content += 'offset_right = 200.0\noffset_bottom = 20.0\n'
			elif type == "VScrollBar":
				content += 'offset_right = 20.0\noffset_bottom = 200.0\n'
			else:
				content += 'offset_right = 100.0\noffset_bottom = 30.0\n'
		
		if type == "Label":
			content += 'text = "Label"\n'
		elif type == "Button":
			content += 'text = "Button"\n'
		elif type == "CheckBox":
			content += 'text = "Check1"\n'
		elif type == "Panel":
			content += 'offset_right = 200.0\noffset_bottom = 200.0\n'
			
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		print("Created prototype: " + path)

	quit()
