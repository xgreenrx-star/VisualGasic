@tool
extends Window
# VisualGasic Tab Order Editor
# Provides a visual list to reorder children

var tree: ItemList
var root_node: Node

func _init():
	title = "Tab Order"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	size = Vector2(300, 400)
	visible = false

	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Padding
	var m = MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	m.add_child(vbox)
	panel.add_child(m)
	
	tree = ItemList.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tree)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_up = Button.new()
	btn_up.text = "Move Up"
	btn_up.pressed.connect(_move_up)
	var btn_down = Button.new()
	btn_down.text = "Move Down"
	btn_down.pressed.connect(_move_down)
	hbox.add_child(btn_up)
	hbox.add_child(btn_down)
	vbox.add_child(hbox)
	
	var btn_close = Button.new()
	btn_close.text = "Close"
	btn_close.pressed.connect(queue_free)
	vbox.add_child(btn_close)

func set_root(node: Node):
	root_node = node
	_refresh()

func _refresh():
	tree.clear()
	if not root_node: return
	
	for i in root_node.get_child_count():
		var c = root_node.get_child(i)
		tree.add_item(c.name + " (" + c.get_class() + ")")
		tree.set_item_metadata(i, c)

func _move_up():
	var sel = tree.get_selected_items()
	if sel.size() == 0: return
	var idx = sel[0]
	if idx > 0:
		var node = tree.get_item_metadata(idx)
		root_node.move_child(node, idx - 1)
		_refresh()
		tree.select(idx - 1)

func _move_down():
	var sel = tree.get_selected_items()
	if sel.size() == 0: return
	var idx = sel[0]
	if idx < tree.item_count - 1:
		var node = tree.get_item_metadata(idx)
		root_node.move_child(node, idx + 1)
		_refresh()
		tree.select(idx + 1)
