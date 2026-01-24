@tool
extends Window
## Modern Menu Editor for VisualGasic
## Improved UX with live preview and full functionality

signal menu_applied(menu_structure: Dictionary)

var tree: Tree
var txt_caption: LineEdit
var txt_name: LineEdit
var txt_shortcut: LineEdit
var chk_checked: CheckBox
var chk_enabled: CheckBox
var chk_visible: CheckBox
var root: TreeItem
var preview_label: Label

var updating_selection: bool = false

func _init():
	title = "Menu Editor"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	size = Vector2(700, 500)
	exclusive = true
	visible = false
	
	var main_split = HSplitContainer.new()
	main_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_split.split_offset = 400
	add_child(main_split)
	
	# Left side - tree and controls
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(380, 0)
	main_split.add_child(left_panel)
	
	# Properties panel
	var props_panel = PanelContainer.new()
	var props_vbox = VBoxContainer.new()
	props_vbox.add_theme_constant_override("separation", 8)
	props_panel.add_child(props_vbox)
	
	var props_label = Label.new()
	props_label.text = "Menu Item Properties"
	props_label.add_theme_font_size_override("font_size", 14)
	props_vbox.add_child(props_label)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	props_vbox.add_child(grid)
	
	grid.add_child(_lbl("Caption:"))
	txt_caption = LineEdit.new()
	txt_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt_caption.text_changed.connect(_on_caption_change)
	txt_caption.placeholder_text = "e.g. &File, &Save, or - for separator"
	grid.add_child(txt_caption)
	
	grid.add_child(_lbl("Name:"))
	txt_name = LineEdit.new()
	txt_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt_name.placeholder_text = "e.g. mnuFile, mnuSave"
	grid.add_child(txt_name)
	
	grid.add_child(_lbl("Shortcut:"))
	txt_shortcut = LineEdit.new()
	txt_shortcut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt_shortcut.placeholder_text = "e.g. Ctrl+S, F5"
	grid.add_child(txt_shortcut)
	
	# Options
	var opts_hbox = HBoxContainer.new()
	opts_hbox.add_theme_constant_override("separation", 12)
	chk_checked = CheckBox.new()
	chk_checked.text = "Checked"
	chk_enabled = CheckBox.new()
	chk_enabled.text = "Enabled"
	chk_enabled.button_pressed = true
	chk_visible = CheckBox.new()
	chk_visible.text = "Visible"
	chk_visible.button_pressed = true
	opts_hbox.add_child(chk_checked)
	opts_hbox.add_child(chk_enabled)
	opts_hbox.add_child(chk_visible)
	props_vbox.add_child(opts_hbox)
	
	left_panel.add_child(props_panel)
	
	left_panel.add_child(VSeparator.new())
	
	# Tree and control buttons
	var tree_section = HBoxContainer.new()
	tree_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(tree_section)
	
	# Control buttons
	var btn_column = VBoxContainer.new()
	btn_column.add_theme_constant_override("separation", 4)
	
	var btn_add_top = Button.new()
	btn_add_top.text = "+ Top Menu"
	btn_add_top.tooltip_text = "Add new top-level menu (File, Edit, View, etc.)"
	btn_add_top.pressed.connect(_on_add_top_menu)
	btn_column.add_child(btn_add_top)
	
	btn_column.add_child(HSeparator.new())
	
	var btn_insert = Button.new()
	btn_insert.text = "Insert"
	btn_insert.tooltip_text = "Insert new item before selected"
	btn_insert.pressed.connect(_on_insert)
	btn_column.add_child(btn_insert)
	
	var btn_add = Button.new()
	btn_add.text = "Add"
	btn_add.tooltip_text = "Add new item after selected (sibling)"
	btn_add.pressed.connect(_on_add)
	btn_column.add_child(btn_add)
	
	var btn_del = Button.new()
	btn_del.text = "Delete"
	btn_del.tooltip_text = "Delete selected item"
	btn_del.pressed.connect(_on_delete)
	btn_column.add_child(btn_del)
	
	btn_column.add_child(HSeparator.new())
	
	var btn_up = Button.new()
	btn_up.text = "↑ Up"
	btn_up.tooltip_text = "Move item up"
	btn_up.pressed.connect(_move_up)
	btn_column.add_child(btn_up)
	
	var btn_down = Button.new()
	btn_down.text = "↓ Down"
	btn_down.tooltip_text = "Move item down"
	btn_down.pressed.connect(_move_down)
	btn_column.add_child(btn_down)
	
	btn_column.add_child(HSeparator.new())
	
	var btn_indent = Button.new()
	btn_indent.text = "→ Indent"
	btn_indent.tooltip_text = "Make submenu of previous item"
	btn_indent.pressed.connect(_indent)
	btn_column.add_child(btn_indent)
	
	var btn_outdent = Button.new()
	btn_outdent.text = "← Outdent"
	btn_outdent.tooltip_text = "Move out of submenu"
	btn_outdent.pressed.connect(_outdent)
	btn_column.add_child(btn_outdent)
	
	tree_section.add_child(btn_column)
	
	# Tree
	tree = Tree.new()
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = true
	tree.columns = 1
	tree.item_selected.connect(_on_select)
	tree.item_activated.connect(_on_item_activated)
	root = tree.create_item()
	tree_section.add_child(tree)
	
	# Right side - preview
	var right_panel = VBoxContainer.new()
	main_split.add_child(right_panel)
	
	var preview_header = Label.new()
	preview_header.text = "Menu Preview"
	preview_header.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(preview_header)
	
	var preview_scroll = ScrollContainer.new()
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(preview_scroll)
	
	preview_label = Label.new()
	preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	preview_scroll.add_child(preview_label)
	
	# Bottom buttons
	var bottom_bar = HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_END
	bottom_bar.add_theme_constant_override("separation", 8)
	
	var btn_ok = Button.new()
	btn_ok.text = "OK"
	btn_ok.pressed.connect(_on_ok)
	bottom_bar.add_child(btn_ok)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.pressed.connect(hide)
	bottom_bar.add_child(btn_cancel)
	
	right_panel.add_child(bottom_bar)
	
	# Initialize with sample menu structure
	var file_item = tree.create_item(root)
	file_item.set_text(0, "&File")
	file_item.set_metadata(0, {
		"name": "mnuFile",
		"shortcut": "",
		"checked": false,
		"enabled": true,
		"visible": true
	})
	
	# Add some example subitems under File
	var open_item = tree.create_item(file_item)
	open_item.set_text(0, "&Open...")
	open_item.set_metadata(0, {
		"name": "mnuFileOpen",
		"shortcut": "Ctrl+O",
		"checked": false,
		"enabled": true,
		"visible": true
	})
	
	var save_item = tree.create_item(file_item)
	save_item.set_text(0, "&Save")
	save_item.set_metadata(0, {
		"name": "mnuFileSave",
		"shortcut": "Ctrl+S",
		"checked": false,
		"enabled": true,
		"visible": true
	})
	
	var sep_item = tree.create_item(file_item)
	sep_item.set_text(0, "-")
	sep_item.set_metadata(0, {
		"name": "mnuFileSep1",
		"shortcut": "",
		"checked": false,
		"enabled": true,
		"visible": true
	})
	
	var exit_item = tree.create_item(file_item)
	exit_item.set_text(0, "E&xit")
	exit_item.set_metadata(0, {
		"name": "mnuFileExit",
		"shortcut": "Alt+F4",
		"checked": false,
		"enabled": true,
		"visible": true
	})
	
	file_item.select(0)
	_update_preview()

func _lbl(txt: String) -> Label:
	var l = Label.new()
	l.text = txt
	return l

func _on_add_top_menu():
	"""Add a new top-level menu item"""
	_update_current_item()
	
	# Add directly to root
	var item = tree.create_item(root)
	item.set_text(0, "New Menu")
	item.set_metadata(0, {
		"name": "",
		"shortcut": "",
		"checked": false,
		"enabled": true,
		"visible": true
	})
	item.select(0)
	_update_preview()

func _on_add():
	"""Add new item after selected"""
	_update_current_item()
	var sel = tree.get_selected()
	var parent = root
	var index = -1
	
	if sel:
		parent = sel.get_parent()
		index = sel.get_index() + 1
	
	var item = tree.create_item(parent, index)
	item.set_text(0, "New Item")
	item.set_metadata(0, {
		"name": "",
		"shortcut": "",
		"checked": false,
		"enabled": true,
		"visible": true
	})
	item.select(0)
	_update_preview()

func _on_insert():
	"""Insert new item before selected"""
	_update_current_item()
	var sel = tree.get_selected()
	if !sel:
		_on_add()
		return
	
	var parent = sel.get_parent()
	var index = sel.get_index()
	
	var item = tree.create_item(parent, index)
	item.set_text(0, "New Item")
	item.set_metadata(0, {
		"name": "",
		"shortcut": "",
		"checked": false,
		"enabled": true,
		"visible": true
	})
	item.select(0)
	_update_preview()

func _on_delete():
	"""Delete selected item"""
	var sel = tree.get_selected()
	if sel:
		var next_sel = sel.get_next_visible() if sel.get_next_visible() else sel.get_prev_visible()
		sel.free()
		if next_sel:
			next_sel.select(0)
		_update_preview()

func _move_up():
	"""Move selected item up"""
	var sel = tree.get_selected()
	if !sel:
		return
	
	var prev = sel.get_prev()
	if !prev:
		return
	
	_update_current_item()
	
	# Get data from both items
	var sel_data = _get_item_data(sel)
	var prev_data = _get_item_data(prev)
	
	# Swap the data
	_set_item_data(sel, prev_data)
	_set_item_data(prev, sel_data)
	
	# Reselect the item (now in previous position)
	prev.select(0)
	_update_preview()

func _move_down():
	"""Move selected item down"""
	var sel = tree.get_selected()
	if !sel:
		return
	
	var next = sel.get_next()
	if !next:
		return
	
	_update_current_item()
	
	# Get data from both items
	var sel_data = _get_item_data(sel)
	var next_data = _get_item_data(next)
	
	# Swap the data
	_set_item_data(sel, next_data)
	_set_item_data(next, sel_data)
	
	# Reselect the item (now in next position)
	next.select(0)
	_update_preview()

func _indent():
	"""Make selected item a submenu of previous sibling"""
	var sel = tree.get_selected()
	if !sel:
		return
	
	var prev = sel.get_prev()
	if !prev:
		return
	
	_update_current_item()
	
	# Save item data
	var data = _get_item_data(sel)
	
	# Create new item as child of previous
	var new_item = tree.create_item(prev)
	_set_item_data(new_item, data)
	
	# Delete old item
	sel.free()
	
	# Select new item
	new_item.select(0)
	prev.collapsed = false
	_update_preview()

func _outdent():
	"""Move selected item out of its parent's submenu"""
	var sel = tree.get_selected()
	if !sel:
		return
	
	var parent = sel.get_parent()
	if !parent or parent == root:
		return
	
	_update_current_item()
	
	# Save item data
	var data = _get_item_data(sel)
	
	# Create new item as sibling of parent (after parent)
	var grandparent = parent.get_parent()
	var new_index = parent.get_index() + 1
	var new_item = tree.create_item(grandparent, new_index)
	_set_item_data(new_item, data)
	
	# Delete old item
	sel.free()
	
	# Select new item
	new_item.select(0)
	_update_preview()

func _get_item_data(item: TreeItem) -> Dictionary:
	"""Extract all data from a tree item"""
	return {
		"caption": item.get_text(0),
		"metadata": item.get_metadata(0)
	}

func _set_item_data(item: TreeItem, data: Dictionary):
	"""Set all data to a tree item"""
	item.set_text(0, data.caption)
	item.set_metadata(0, data.metadata)

func _update_current_item():
	"""Save current form values to selected item"""
	if updating_selection:
		return
		
	var sel = tree.get_selected()
	if sel:
		sel.set_text(0, txt_caption.text)
		sel.set_metadata(0, {
			"name": txt_name.text,
			"shortcut": txt_shortcut.text,
			"checked": chk_checked.button_pressed,
			"enabled": chk_enabled.button_pressed,
			"visible": chk_visible.button_pressed
		})

func _on_caption_change(txt: String):
	"""Live update tree as caption changes"""
	var sel = tree.get_selected()
	if sel and not updating_selection:
		sel.set_text(0, txt)
		_update_preview()

func _on_select():
	"""Load selected item properties into form"""
	updating_selection = true
	
	var sel = tree.get_selected()
	if sel:
		txt_caption.text = sel.get_text(0)
		var meta = sel.get_metadata(0)
		if meta:
			txt_name.text = meta.get("name", "")
			txt_shortcut.text = meta.get("shortcut", "")
			chk_checked.button_pressed = meta.get("checked", false)
			chk_enabled.button_pressed = meta.get("enabled", true)
			chk_visible.button_pressed = meta.get("visible", true)
		else:
			txt_name.text = ""
			txt_shortcut.text = ""
			chk_checked.button_pressed = false
			chk_enabled.button_pressed = true
			chk_visible.button_pressed = true
	
	updating_selection = false

func _on_item_activated():
	"""Handle double-click on tree item - focus caption field for quick editing"""
	txt_caption.grab_focus()
	txt_caption.select_all()

func _update_preview():
	"""Update the menu preview display"""
	var preview_text = ""
	preview_text = _build_preview_recursive(root, 0, preview_text)
	preview_label.text = preview_text

func _build_preview_recursive(item: TreeItem, indent: int, preview_text: String) -> String:
	"""Recursively build preview text"""
	var child = item.get_first_child()
	while child:
		var caption = child.get_text(0)
		var meta = child.get_metadata(0)
		
		# Add indentation
		for i in indent:
			preview_text += "    "
		
		# Add menu item
		if caption == "-":
			preview_text += "─────────────────\n"
		else:
			preview_text += caption
			if meta and meta.get("shortcut", "") != "":
				preview_text += "    " + meta.get("shortcut")
			if meta and meta.get("checked", false):
				preview_text += " ✓"
			preview_text += "\n"
		
		# Add children
		if child.get_child_count() > 0:
			preview_text = _build_preview_recursive(child, indent + 1, preview_text)
		
		child = child.get_next()
	
	return preview_text

func _on_ok():
	"""Apply menu and close"""
	_update_current_item()
	var menu_structure = _build_menu_structure()
	hide()
	menu_applied.emit(menu_structure)

func _build_menu_structure() -> Dictionary:
	"""Build final menu structure as Dictionary"""
	var structure = {
		"items": []
	}
	_build_structure_recursive(root, structure.items)
	return structure

func _build_structure_recursive(item: TreeItem, items_array: Array):
	"""Recursively build menu structure"""
	var child = item.get_first_child()
	while child:
		var meta = child.get_metadata(0)
		var item_data = {
			"caption": child.get_text(0),
			"name": meta.get("name", "") if meta else "",
			"shortcut": meta.get("shortcut", "") if meta else "",
			"checked": meta.get("checked", false) if meta else false,
			"enabled": meta.get("enabled", true) if meta else true,
			"visible": meta.get("visible", true) if meta else true,
			"children": []
		}
		
		if child.get_child_count() > 0:
			_build_structure_recursive(child, item_data.children)
		
		items_array.append(item_data)
		child = child.get_next()

func load_menu_structure(structure: Dictionary):
	"""Load existing menu structure into editor"""
	# Clear existing items
	root.clear_children()
	
	# Load items
	if structure.has("items"):
		_load_items_recursive(root, structure.items)
	
	# Select first item
	var first = root.get_first_child()
	if first:
		first.select(0)
	
	_update_preview()

func _load_items_recursive(parent: TreeItem, items: Array):
	"""Recursively load menu items"""
	for item_data in items:
		var item = tree.create_item(parent)
		item.set_text(0, item_data.get("caption", ""))
		item.set_metadata(0, {
			"name": item_data.get("name", ""),
			"shortcut": item_data.get("shortcut", ""),
			"checked": item_data.get("checked", false),
			"enabled": item_data.get("enabled", true),
			"visible": item_data.get("visible", true)
		})
		
		if item_data.has("children") and item_data.children.size() > 0:
			_load_items_recursive(item, item_data.children)
