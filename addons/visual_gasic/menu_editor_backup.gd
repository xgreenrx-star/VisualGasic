@tool
extends Window

# VisualGasic Menu Editor
# Allows creating MenuBar hierarchies visually

signal menu_applied(menu_root: MenuBar)

var tree: Tree
var txt_caption: LineEdit
var txt_name: LineEdit
var chk_checked: CheckBox
var chk_enabled: CheckBox
var chk_visible: CheckBox
var root: TreeItem

func _init():
	title = "Menu Editor"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	size = Vector2(500, 400)
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
	txt_caption.text_changed.connect(_on_caption_change)
	grid.add_child(txt_caption)
	
	grid.add_child(_lbl("Name:"))
	txt_name = LineEdit.new()
	grid.add_child(txt_name)
	
	# Options
	var hbox_opts = HBoxContainer.new()
	chk_checked = CheckBox.new(); chk_checked.text = "Checked"
	chk_enabled = CheckBox.new(); chk_enabled.text = "Enabled"; chk_enabled.button_pressed = true
	chk_visible = CheckBox.new(); chk_visible.text = "Visible"; chk_visible.button_pressed = true
	hbox_opts.add_child(chk_checked)
	hbox_opts.add_child(chk_enabled)
	hbox_opts.add_child(chk_visible)
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
	
	var btn_up = Button.new(); btn_up.text = "Up"; btn_up.pressed.connect(_move_up)
	var btn_down = Button.new(); btn_down.text = "Down"; btn_down.pressed.connect(_move_down)
	btns.add_child(btn_up)
	btns.add_child(btn_down)
	
	var btn_indent = Button.new(); btn_indent.text = "->"; btn_indent.pressed.connect(_indent)
	var btn_outdent = Button.new(); btn_outdent.text = "<-"; btn_outdent.pressed.connect(_outdent)
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

func _lbl(txt):
	var l = Label.new()
	l.text = txt
	return l

func _on_next():
	# Update current
	_update_current_item()
	# Add new at end of parent
	var sel = tree.get_selected()
	var parent = root
	if sel: parent = sel.get_parent()
	var item = tree.create_item(parent)
	item.set_text(0, "(New)")
	item.select(0)

func _on_insert():
	_update_current_item()
	var sel = tree.get_selected()
	if !sel: 
		_on_next()
		return
	var item = tree.create_item(sel.get_parent(), sel.get_index())
	item.set_text(0, "(New)")
	item.select(0)

func _on_delete():
	var sel = tree.get_selected()
	if sel: sel.free()

func _update_current_item():
	var sel = tree.get_selected()
	if sel:
		sel.set_text(0, txt_caption.text)
		sel.set_metadata(0, {
			"name": txt_name.text,
			"checked": chk_checked.button_pressed,
			"enabled": chk_enabled.button_pressed,
			"visible": chk_visible.button_pressed
		})

func _on_caption_change(txt):
	var sel = tree.get_selected()
	if sel: sel.set_text(0, txt)

func _on_select():
	var sel = tree.get_selected()
	if sel:
		txt_caption.text = sel.get_text(0)
		var meta = sel.get_metadata(0)
		if meta:
			txt_name.text = meta.get("name", "")
			chk_checked.button_pressed = meta.get("checked", false)
			chk_enabled.button_pressed = meta.get("enabled", true)
			chk_visible.button_pressed = meta.get("visible", true)
		else:
			txt_name.text = ""

func _move_up():
	var sel = tree.get_selected()
	if not sel:
		return
	
	var prev = sel.get_prev_in_tree()
	if not prev or prev == sel.get_parent():
		return # Can't move up further
	
	# Move before previous sibling
	sel.move_before(prev)
	tree.set_selected(sel, 0)

func _move_down():
	var sel = tree.get_selected()
	if not sel:
		return
	
	var next = sel.get_next_in_tree()
	if not next:
		return # Can't move down further
	
	# If next is a sibling, move after it
	if next.get_parent() == sel.get_parent():
		sel.move_after(next)
		tree.set_selected(sel, 0)

func _indent():
	var sel = tree.get_selected()
	if not sel or not sel.get_prev():
		return
	
	var new_parent = sel.get_prev()
	
	# Store menu item data
	var meta = sel.get_metadata(0)
	var text = sel.get_text(0)
	
	# Remove from current parent and add to new parent
	sel.get_parent().remove_child(sel)
	new_parent.add_child(sel)
	
	# Restore data
	sel.set_text(0, text)
	sel.set_metadata(0, meta)
	tree.set_selected(sel, 0)

func _outdent():
	var sel = tree.get_selected()
	if not sel:
		return
	
	var parent = sel.get_parent()
	if not parent or parent == tree.get_root():
		return # Already at root level
	
	var grandparent = parent.get_parent()
	if not grandparent:
		return
	
	# Store menu item data
	var meta = sel.get_metadata(0)
	var text = sel.get_text(0)
	
	# Remove from parent and add to grandparent after parent
	parent.remove_child(sel)
	grandparent.add_child(sel)
	sel.move_after(parent)
	
	# Restore data
	sel.set_text(0, text)
	sel.set_metadata(0, meta)
	tree.set_selected(sel, 0)

func _on_ok():
	_update_current_item()
	# Apply to Editor logic
	# For now, just print
	print("Menu Editor OK. Structure saved.")
	hide()
	menu_applied.emit(null) # Placeholder
