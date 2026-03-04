@tool
extends Window

# VisualGasic Menu Editor
# Allows creating MenuBar hierarchies visually

signal menu_applied(menu_root: MenuBar)

var tree: Tree
var txt_caption: LineEdit
var txt_name: LineEdit
var txt_shortcut: LineEdit
var chk_checked: CheckBox
var chk_enabled: CheckBox
var chk_visible: CheckBox
var chk_separator: CheckBox
var root: TreeItem
var _menu_bar: MenuBar  # The MenuBar being edited

func _init():
	title = "Menu Editor"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	size = Vector2(560, 440)
	exclusive = true
	visible = false
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10; vbox.offset_top = 10; vbox.offset_right = -10; vbox.offset_bottom = -10
	panel.add_child(vbox)
	
	# Inputs
	var grid = GridContainer.new()
	grid.columns = 2
	vbox.add_child(grid)
	
	grid.add_child(_lbl("Caption:"))
	txt_caption = LineEdit.new()
	txt_caption.placeholder_text = "e.g. &File  (use & for hotkey)"
	txt_caption.text_changed.connect(_on_caption_change)
	grid.add_child(txt_caption)
	
	grid.add_child(_lbl("Name:"))
	txt_name = LineEdit.new()
	txt_name.placeholder_text = "e.g. mnuFile"
	grid.add_child(txt_name)

	grid.add_child(_lbl("Shortcut:"))
	txt_shortcut = LineEdit.new()
	txt_shortcut.placeholder_text = "e.g. Ctrl+N"
	grid.add_child(txt_shortcut)
	
	# Options
	var hbox_opts = HBoxContainer.new()
	chk_checked = CheckBox.new(); chk_checked.text = "Checked"
	chk_enabled = CheckBox.new(); chk_enabled.text = "Enabled"; chk_enabled.button_pressed = true
	chk_visible = CheckBox.new(); chk_visible.text = "Visible"; chk_visible.button_pressed = true
	chk_separator = CheckBox.new(); chk_separator.text = "Separator"
	hbox_opts.add_child(chk_checked)
	hbox_opts.add_child(chk_enabled)
	hbox_opts.add_child(chk_visible)
	hbox_opts.add_child(chk_separator)
	vbox.add_child(hbox_opts)
	
	vbox.add_child(HSeparator.new())
	
	# List and Controls
	var mid = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(mid)
	
	# Buttons left
	var btns = VBoxContainer.new()
	var btn_next = Button.new(); btn_next.text = "Next"; btn_next.pressed.connect(_on_next)
	var btn_insert = Button.new(); btn_insert.text = "Insert"; btn_insert.pressed.connect(_on_insert)
	var btn_del = Button.new(); btn_del.text = "Delete"; btn_del.pressed.connect(_on_delete)
	btns.add_child(btn_next)
	btns.add_child(btn_insert)
	btns.add_child(btn_del)
	
	btns.add_child(HSeparator.new())
	
	var btn_up = Button.new(); btn_up.text = "↑ Up"; btn_up.pressed.connect(_move_up)
	var btn_down = Button.new(); btn_down.text = "↓ Down"; btn_down.pressed.connect(_move_down)
	btns.add_child(btn_up)
	btns.add_child(btn_down)
	
	var btn_indent = Button.new(); btn_indent.text = "→ Indent"; btn_indent.pressed.connect(_indent)
	var btn_outdent = Button.new(); btn_outdent.text = "← Outdent"; btn_outdent.pressed.connect(_outdent)
	btns.add_child(btn_indent)
	btns.add_child(btn_outdent)
	
	mid.add_child(btns)
	
	# Tree
	tree = Tree.new()
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.hide_root = true
	tree.columns = 1
	tree.item_selected.connect(_on_select)
	root = tree.create_item()
	mid.add_child(tree)
	
	# Bottom
	var bots = HBoxContainer.new()
	bots.alignment = BoxContainer.ALIGNMENT_END
	var btn_ok = Button.new(); btn_ok.text = "OK"; btn_ok.pressed.connect(_on_ok)
	var btn_cancel = Button.new(); btn_cancel.text = "Cancel"; btn_cancel.pressed.connect(hide)
	bots.add_child(btn_ok)
	bots.add_child(btn_cancel)
	vbox.add_child(bots)

## Sets the MenuBar to edit. Loads existing menus into the tree.
func set_menu_bar(menu_bar: MenuBar) -> void:
	_menu_bar = menu_bar
	if not _menu_bar:
		return
	# Load existing menu structure into the tree
	_load_from_menu_bar()

func _load_from_menu_bar() -> void:
	if not _menu_bar:
		return
	# Clear existing tree items
	root.free()
	root = tree.create_item()
	
	# Each child PopupMenu of the MenuBar is a top-level menu
	for i in range(_menu_bar.get_child_count()):
		var popup = _menu_bar.get_child(i)
		if popup is PopupMenu:
			var top_item = tree.create_item(root)
			top_item.set_text(0, popup.name)
			top_item.set_metadata(0, {
				"name": popup.name,
				"checked": false,
				"enabled": true,
				"visible": true,
				"separator": false,
				"shortcut": ""
			})
			# Add sub-items
			for j in range(popup.item_count):
				var sub_item = tree.create_item(top_item)
				var item_text = popup.get_item_text(j)
				var is_sep = popup.is_item_separator(j)
				if is_sep:
					sub_item.set_text(0, "----")
				else:
					sub_item.set_text(0, item_text)
				sub_item.set_metadata(0, {
					"name": "mnu" + item_text.replace(" ", "").replace("&", ""),
					"checked": popup.is_item_checked(j),
					"enabled": !popup.is_item_disabled(j),
					"visible": true,
					"separator": is_sep,
					"shortcut": ""
				})

func _lbl(txt):
	var l = Label.new()
	l.text = txt
	return l

func _on_next():
	_update_current_item()
	var sel = tree.get_selected()
	var parent = root
	if sel: parent = sel.get_parent()
	var item = tree.create_item(parent)
	item.set_text(0, "(New)")
	item.set_metadata(0, {
		"name": "",
		"checked": false,
		"enabled": true,
		"visible": true,
		"separator": false,
		"shortcut": ""
	})
	item.select(0)

func _on_insert():
	_update_current_item()
	var sel = tree.get_selected()
	if !sel: 
		_on_next()
		return
	var item = tree.create_item(sel.get_parent(), sel.get_index())
	item.set_text(0, "(New)")
	item.set_metadata(0, {
		"name": "",
		"checked": false,
		"enabled": true,
		"visible": true,
		"separator": false,
		"shortcut": ""
	})
	item.select(0)

func _on_delete():
	var sel = tree.get_selected()
	if sel: sel.free()

func _update_current_item():
	var sel = tree.get_selected()
	if sel:
		if chk_separator.button_pressed:
			sel.set_text(0, "----")
		else:
			sel.set_text(0, txt_caption.text)
		sel.set_metadata(0, {
			"name": txt_name.text,
			"checked": chk_checked.button_pressed,
			"enabled": chk_enabled.button_pressed,
			"visible": chk_visible.button_pressed,
			"separator": chk_separator.button_pressed,
			"shortcut": txt_shortcut.text if txt_shortcut else ""
		})

func _on_caption_change(txt):
	var sel = tree.get_selected()
	if sel and not chk_separator.button_pressed:
		sel.set_text(0, txt)

func _on_select():
	var sel = tree.get_selected()
	if sel:
		txt_caption.text = sel.get_text(0) if sel.get_text(0) != "----" else ""
		var meta = sel.get_metadata(0)
		if meta:
			txt_name.text = meta.get("name", "")
			chk_checked.button_pressed = meta.get("checked", false)
			chk_enabled.button_pressed = meta.get("enabled", true)
			chk_visible.button_pressed = meta.get("visible", true)
			chk_separator.button_pressed = meta.get("separator", false)
			if txt_shortcut:
				txt_shortcut.text = meta.get("shortcut", "")
		else:
			txt_name.text = ""
			if txt_shortcut:
				txt_shortcut.text = ""

func _move_up():
	var sel = tree.get_selected()
	if not sel:
		return
	var parent = sel.get_parent()
	if not parent:
		return
	var idx = sel.get_index()
	if idx <= 0:
		return
	# Collect data, remove, re-insert at idx-1
	var data = _collect_item_data(sel)
	var children_data = _collect_children_data(sel)
	sel.free()
	var new_item = tree.create_item(parent, idx - 1)
	_apply_item_data(new_item, data)
	_rebuild_children(new_item, children_data)
	new_item.select(0)

func _move_down():
	var sel = tree.get_selected()
	if not sel:
		return
	var parent = sel.get_parent()
	if not parent:
		return
	var idx = sel.get_index()
	var sibling_count = parent.get_child_count()
	if idx >= sibling_count - 1:
		return
	var data = _collect_item_data(sel)
	var children_data = _collect_children_data(sel)
	sel.free()
	# Insert at idx+1 (after removal, positions shift)
	var new_item = tree.create_item(parent, idx + 1)
	_apply_item_data(new_item, data)
	_rebuild_children(new_item, children_data)
	new_item.select(0)

func _indent():
	var sel = tree.get_selected()
	if not sel:
		return
	var parent = sel.get_parent()
	if not parent:
		return
	# Find previous sibling to become the new parent
	var idx = sel.get_index()
	if idx <= 0:
		return
	var prev_sibling = parent.get_child(idx - 1)
	if not prev_sibling:
		return
	var data = _collect_item_data(sel)
	var children_data = _collect_children_data(sel)
	sel.free()
	var new_item = tree.create_item(prev_sibling)
	_apply_item_data(new_item, data)
	_rebuild_children(new_item, children_data)
	new_item.select(0)

func _outdent():
	var sel = tree.get_selected()
	if not sel:
		return
	var parent = sel.get_parent()
	if not parent or parent == root:
		return  # Already top-level, can't outdent further
	var grandparent = parent.get_parent()
	if not grandparent:
		return
	var parent_idx = parent.get_index()
	var data = _collect_item_data(sel)
	var children_data = _collect_children_data(sel)
	sel.free()
	# Insert after the parent in the grandparent
	var new_item = tree.create_item(grandparent, parent_idx + 1)
	_apply_item_data(new_item, data)
	_rebuild_children(new_item, children_data)
	new_item.select(0)

# --- Helpers for move/indent/outdent ---
func _collect_item_data(item: TreeItem) -> Dictionary:
	return {
		"text": item.get_text(0),
		"metadata": item.get_metadata(0)
	}

func _collect_children_data(item: TreeItem) -> Array:
	var result = []
	var child = item.get_first_child()
	while child:
		result.append({
			"data": _collect_item_data(child),
			"children": _collect_children_data(child)
		})
		child = child.get_next()
	return result

func _apply_item_data(item: TreeItem, data: Dictionary):
	item.set_text(0, data.get("text", ""))
	item.set_metadata(0, data.get("metadata", {}))

func _rebuild_children(parent: TreeItem, children_data: Array):
	for cd in children_data:
		var child = tree.create_item(parent)
		_apply_item_data(child, cd["data"])
		_rebuild_children(child, cd["children"])

func _on_ok():
	_update_current_item()
	
	if _menu_bar:
		_apply_to_menu_bar()
	
	print("Menu Editor OK. Structure saved.")
	hide()
	menu_applied.emit(_menu_bar)

## Applies the tree structure back to the actual MenuBar node.
## Top-level items become PopupMenus, their children become menu items.
func _apply_to_menu_bar() -> void:
	if not _menu_bar:
		return
	
	# Remove all existing PopupMenu children
	for i in range(_menu_bar.get_child_count() - 1, -1, -1):
		var child = _menu_bar.get_child(i)
		if child is PopupMenu:
			_menu_bar.remove_child(child)
			child.queue_free()
	
	# Rebuild from tree
	var top_item = root.get_first_child()
	while top_item:
		var meta = top_item.get_metadata(0)
		if not meta:
			meta = {}
		
		var popup = PopupMenu.new()
		var caption = top_item.get_text(0)
		# Use Name from metadata, or derive from caption
		var menu_name = meta.get("name", "")
		if menu_name.is_empty():
			menu_name = caption.replace("&", "").replace(" ", "")
		popup.name = menu_name
		
		# Add sub-items
		_add_popup_items(popup, top_item)
		
		_menu_bar.add_child(popup)
		# Set the owner so it's saved with the scene
		popup.owner = _menu_bar.owner if _menu_bar.owner else _menu_bar
		
		top_item = top_item.get_next()
	
	print("Menu Editor: Applied ", _menu_bar.get_child_count(), " menus to MenuBar")

func _add_popup_items(popup: PopupMenu, parent_item: TreeItem) -> void:
	var child = parent_item.get_first_child()
	var idx = 0
	while child:
		var meta = child.get_metadata(0)
		if not meta:
			meta = {}
		
		if meta.get("separator", false):
			popup.add_separator()
		else:
			var text = child.get_text(0)
			popup.add_item(text, idx)
			
			# Apply properties
			if meta.get("checked", false):
				popup.set_item_checked(popup.item_count - 1, true)
			if not meta.get("enabled", true):
				popup.set_item_disabled(popup.item_count - 1, true)
			
			# If this item has children, create a submenu
			if child.get_first_child():
				var submenu = PopupMenu.new()
				var sub_name = meta.get("name", text.replace(" ", "").replace("&", ""))
				submenu.name = sub_name
				_add_popup_items(submenu, child)
				popup.add_child(submenu)
				popup.set_item_submenu(popup.item_count - 1, sub_name)
		
		idx += 1
		child = child.get_next()
