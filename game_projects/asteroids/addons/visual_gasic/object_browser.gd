@tool
extends Window
# VisualGasic Object Browser

var tree: Tree

func _init():
	title = "Object Browser"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	size = Vector2(600, 450)
	visible = false
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 5; vbox.offset_top = 5; vbox.offset_right = -5; vbox.offset_bottom = -5
	panel.add_child(vbox)
	
	var search = LineEdit.new()
	search.placeholder_text = "Search..."
	search.text_changed.connect(_on_search)
	vbox.add_child(search)
	
	tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.columns = 2
	tree.set_column_title(0, "Member")
	tree.set_column_title(1, "Description")
	tree.set_column_titles_visible(true)
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, true)
	tree.set_column_custom_minimum_width(0, 200)
	vbox.add_child(tree)
	
	_populate("")

func _populate(filter: String):
	tree.clear()
	var root = tree.create_item()
	
	var data = {
		"Globals": {
			"ScreenSize": "Vector2 - Screen dimensions.",
			"Global": "Keyword - Declare global variable.",
			"Set": "Keyword - Assign object reference."
		},
		"Math": {
			"Abs": "Function - Absolute value.",
			"Int": "Function - Integer part.",
			"Rnd": "Function - Random float 0-1.",
			"RandRange": "Function - Random integer in range.",
			"Clamp": "Function - Clamp value."
		},
		"Audio": {
			"PlaySound": "Sub - Play audio file.",
			"PlayTone": "Sub - Generate sine wave."
		},
		"Graphics": {
			"DrawLine": "Sub - Draw line segment.",
			"DrawRect": "Sub - Draw rectangle.",
			"DrawText": "Sub - Draw text string."
		},
		"AI": {
			"AI_Wander": "Sub - Random movement.",
			"AI_Patrol": "Sub - Patrol points.",
			"AI_Stop": "Sub - Stop AI."
		}
	}
	
	for category in data:
		var cat_item = tree.create_item(root)
		cat_item.set_text(0, category)
		cat_item.set_selectable(0, false)
		cat_item.set_expand_right(0, true)
		
		var items = data[category]
		var has_matches = false
		
		for key in items:
			if filter == "" or key.to_lower().contains(filter.to_lower()):
				var item = tree.create_item(cat_item)
				item.set_text(0, key)
				item.set_text(1, items[key])
				has_matches = true
		
		if filter != "" and not has_matches:
			root.remove_child(cat_item) # Remove empty category if filtering

func _on_search(txt):
	_populate(txt)
