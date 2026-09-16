# custom_control_designer.gd
# WYSIWYG editor for designing reusable custom controls (UserControls)
# Users compose child nodes visually, set properties, and save as .tscn
# files that appear in the Toolbox alongside built-in controls.
@tool
extends AcceptDialog

signal control_saved(ctrl_name: String, scene_path: String)

# ─── VB6 palette ───
const VB6_PANEL_BG       = Color(0.941, 0.929, 0.910)
const VB6_PANEL_BORDER   = Color(0.72, 0.71, 0.68)
const VB6_HEADER_BG      = Color(0.58, 0.58, 0.62)
const VB6_HEADER_BORDER  = Color(0.4, 0.4, 0.4)
const VB6_HEADER_TEXT    = Color(1.0, 1.0, 1.0)
const VB6_TEXT           = Color(0.0, 0.0, 0.0)
const VB6_LIST_BG        = Color(1.0, 1.0, 1.0)
const VB6_ACTIVE_TITLE   = Color(0.0, 0.0, 0.5)
const VB6_CANVAS_BG      = Color(0.85, 0.85, 0.85)
const VB6_GRID_COLOR     = Color(0.75, 0.75, 0.75, 0.5)
const VB6_SELECT_COLOR   = Color(0.0, 0.0, 0.8, 0.7)
const VB6_BTN_HOVER_BG   = Color(0.95, 0.94, 0.92)
const VB6_BTN_PRESSED_BG = Color(0.88, 0.87, 0.85)

const GRID_SIZE := 8
const DEFAULT_CONTROL_SIZE := Vector2(100, 30)

# ─── Node types users can add as children ───
const CHILD_TYPES := [
	"Label", "Button", "LineEdit", "TextEdit",
	"CheckBox", "OptionButton", "SpinBox",
	"TextureRect", "ColorRect", "Panel",
	"HSlider", "VSlider", "ProgressBar",
	"HBoxContainer", "VBoxContainer", "HSeparator",
]

# ─── State ───
var ctrl_name: String = "MyCustomControl"
var root_type: String = "Panel"
var scene_path: String = ""                # set if editing existing
var is_editing_existing: bool = false

# Child items: [{type, name, rect, properties, node_ref}]
var child_items: Array = []
var selected_child_idx: int = -1
var dragging: bool = false
var resizing: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var resize_handle_size: float = 8.0

# ─── UI elements ───
var name_edit: LineEdit
var root_option: OptionButton
var canvas: Control          # drawing area
var child_type_list: ItemList # palette of child types
var property_tree: Tree      # property inspector
var child_tree: Tree         # child list (tree view)
var status_label: Label
var live_preview: SubViewportContainer
var live_viewport: SubViewport

func _init():
	title = "Custom Control Designer"
	size = Vector2i(900, 620)
	unresizable = false
	dialog_hide_on_ok = false

func _ready():
	theme = _build_theme()
	get_label().visible = false

	ok_btn_text_set()
	var cancel_btn = add_cancel_button("Cancel")
	cancel_btn.custom_minimum_size.x = 80

	_build_ui()

func ok_btn_text_set():
	var ok = get_ok_button()
	ok.text = "Save && Close"
	ok.custom_minimum_size.x = 110
	confirmed.connect(_on_save_and_close)
	canceled.connect(_on_cancel)

# =====================================================================
# UI CONSTRUCTION
# =====================================================================

func _build_ui():
	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root_vbox)

	# ── Top bar: name + root type ──
	var top_bar = HBoxContainer.new()
	root_vbox.add_child(top_bar)

	var name_lbl = Label.new()
	name_lbl.text = "Name:"
	top_bar.add_child(name_lbl)

	name_edit = LineEdit.new()
	name_edit.text = ctrl_name
	name_edit.custom_minimum_size.x = 180
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(name_edit)

	var spacer_top = Control.new()
	spacer_top.custom_minimum_size.x = 16
	top_bar.add_child(spacer_top)

	var root_lbl = Label.new()
	root_lbl.text = "Root Type:"
	top_bar.add_child(root_lbl)

	root_option = OptionButton.new()
	var root_types := ["Control", "Panel", "PanelContainer", "HBoxContainer",
					   "VBoxContainer", "MarginContainer", "CenterContainer",
					   "Button", "TextureRect"]
	for i in range(root_types.size()):
		root_option.add_item(root_types[i], i)
	var idx = root_types.find(root_type)
	if idx >= 0:
		root_option.selected = idx
	root_option.custom_minimum_size.x = 140
	top_bar.add_child(root_option)

	# ── Main area: palette | canvas | properties ──
	var main_hsplit = HSplitContainer.new()
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(main_hsplit)

	# Left panel: child type palette + child tree
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 140
	main_hsplit.add_child(left_vbox)

	var palette_label = Label.new()
	palette_label.text = "Add Child Control:"
	left_vbox.add_child(palette_label)

	child_type_list = ItemList.new()
	child_type_list.custom_minimum_size.y = 180
	child_type_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for t in CHILD_TYPES:
		child_type_list.add_item(t)
	child_type_list.item_activated.connect(_on_palette_item_activated)
	left_vbox.add_child(child_type_list)

	var add_btn = Button.new()
	add_btn.text = "Add Selected"
	add_btn.pressed.connect(_on_add_child_pressed)
	left_vbox.add_child(add_btn)

	var remove_btn = Button.new()
	remove_btn.text = "Remove Selected"
	remove_btn.pressed.connect(_on_remove_child_pressed)
	left_vbox.add_child(remove_btn)

	var sep1 = HSeparator.new()
	left_vbox.add_child(sep1)

	var children_label = Label.new()
	children_label.text = "Children:"
	left_vbox.add_child(children_label)

	child_tree = Tree.new()
	child_tree.hide_root = true
	child_tree.columns = 1
	child_tree.custom_minimum_size.y = 100
	child_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child_tree.item_selected.connect(_on_child_tree_selected)
	left_vbox.add_child(child_tree)

	# Center: canvas drawing area
	var center_vbox = VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.add_child(center_vbox)

	var canvas_label = Label.new()
	canvas_label.text = "Design Surface:"
	center_vbox.add_child(canvas_label)

	var canvas_panel = PanelContainer.new()
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var canvas_sb = StyleBoxFlat.new()
	canvas_sb.bg_color = VB6_CANVAS_BG
	canvas_sb.border_color = VB6_PANEL_BORDER
	canvas_sb.set_border_width_all(2)
	canvas_panel.add_theme_stylebox_override("panel", canvas_sb)
	center_vbox.add_child(canvas_panel)

	canvas = Control.new()
	canvas.clip_contents = true
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.gui_input.connect(_on_canvas_input)
	canvas.draw.connect(_on_canvas_draw)
	canvas_panel.add_child(canvas)

	# Bottom of center: live preview
	var preview_label = Label.new()
	preview_label.text = "Live Preview:"
	center_vbox.add_child(preview_label)

	live_preview = SubViewportContainer.new()
	live_preview.custom_minimum_size = Vector2(0, 100)
	live_preview.stretch = true
	center_vbox.add_child(live_preview)

	live_viewport = SubViewport.new()
	live_viewport.size = Vector2i(400, 100)
	live_viewport.transparent_bg = true
	live_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	live_preview.add_child(live_viewport)

	# Right panel: properties
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size.x = 200
	main_hsplit.add_child(right_vbox)

	var prop_label = Label.new()
	prop_label.text = "Properties:"
	right_vbox.add_child(prop_label)

	property_tree = Tree.new()
	property_tree.columns = 2
	property_tree.column_titles_visible = true
	property_tree.set_column_title(0, "Property")
	property_tree.set_column_title(1, "Value")
	property_tree.set_column_expand(0, true)
	property_tree.set_column_expand(1, true)
	property_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_tree.item_edited.connect(_on_property_edited)
	right_vbox.add_child(property_tree)

	# Status bar
	status_label = Label.new()
	status_label.text = "Ready — add children from the palette on the left."
	status_label.add_theme_font_size_override("font_size", 11)
	root_vbox.add_child(status_label)

# =====================================================================
# CHILD MANAGEMENT
# =====================================================================

func _on_palette_item_activated(index: int):
	_add_child_control(CHILD_TYPES[index])

func _on_add_child_pressed():
	var sel = child_type_list.get_selected_items()
	if sel.is_empty():
		return
	_add_child_control(CHILD_TYPES[sel[0]])

func _add_child_control(type_name: String):
	var count = 0
	for c in child_items:
		if c["type"] == type_name:
			count += 1
	var cname = type_name + str(count + 1) if count > 0 else type_name + "1"

	# Place at a staggered position
	var offset = Vector2(16 + child_items.size() * 12, 16 + child_items.size() * 12)
	var sz = DEFAULT_CONTROL_SIZE
	if type_name in ["TextEdit", "Panel", "TextureRect", "ColorRect"]:
		sz = Vector2(140, 80)
	elif type_name == "Label":
		sz = Vector2(100, 24)
	elif type_name in ["HSlider", "ProgressBar"]:
		sz = Vector2(120, 24)
	elif type_name in ["VSlider"]:
		sz = Vector2(24, 100)
	elif type_name in ["HSeparator"]:
		sz = Vector2(120, 8)

	var item := {
		"type": type_name,
		"name": cname,
		"rect": Rect2(offset, sz),
		"properties": _default_properties_for(type_name, cname),
	}
	child_items.append(item)
	selected_child_idx = child_items.size() - 1

	_refresh_child_tree()
	_refresh_properties()
	_refresh_live_preview()
	canvas.queue_redraw()
	status_label.text = "Added " + type_name + " as '" + cname + "'"

func _on_remove_child_pressed():
	if selected_child_idx < 0 or selected_child_idx >= child_items.size():
		return
	var removed_name = child_items[selected_child_idx]["name"]
	child_items.remove_at(selected_child_idx)
	selected_child_idx = mini(selected_child_idx, child_items.size() - 1)
	_refresh_child_tree()
	_refresh_properties()
	_refresh_live_preview()
	canvas.queue_redraw()
	status_label.text = "Removed '" + removed_name + "'"

func _default_properties_for(type_name: String, cname: String) -> Dictionary:
	var props := {"(Name)": cname}
	match type_name:
		"Label":
			props["Text"] = cname
			props["FontSize"] = "14"
		"Button":
			props["Text"] = cname
			props["FontSize"] = "14"
		"LineEdit":
			props["PlaceholderText"] = ""
			props["FontSize"] = "14"
		"TextEdit":
			props["Text"] = ""
			props["FontSize"] = "14"
		"CheckBox":
			props["Text"] = cname
		"OptionButton":
			props["Text"] = ""
		"SpinBox":
			props["MinValue"] = "0"
			props["MaxValue"] = "100"
			props["Value"] = "0"
		"ColorRect":
			props["Color"] = "#808080"
		"ProgressBar":
			props["MinValue"] = "0"
			props["MaxValue"] = "100"
			props["Value"] = "50"
		"HSlider", "VSlider":
			props["MinValue"] = "0"
			props["MaxValue"] = "100"
			props["Value"] = "50"
	return props

# =====================================================================
# CHILD TREE (left panel list)
# =====================================================================

func _refresh_child_tree():
	child_tree.clear()
	var root = child_tree.create_item()
	for i in range(child_items.size()):
		var c = child_items[i]
		var item = child_tree.create_item(root)
		item.set_text(0, c["name"] + " (" + c["type"] + ")")
		item.set_metadata(0, i)
		if i == selected_child_idx:
			item.select(0)

func _on_child_tree_selected():
	var sel = child_tree.get_selected()
	if sel:
		selected_child_idx = sel.get_metadata(0)
		_refresh_properties()
		canvas.queue_redraw()

# =====================================================================
# PROPERTY INSPECTOR
# =====================================================================

func _refresh_properties():
	property_tree.clear()
	if selected_child_idx < 0 or selected_child_idx >= child_items.size():
		return

	var root = property_tree.create_item()
	var c = child_items[selected_child_idx]

	# Position / Size (always shown)
	var pos_item = property_tree.create_item(root)
	pos_item.set_text(0, "X")
	pos_item.set_text(1, str(int(c["rect"].position.x)))
	pos_item.set_editable(1, true)
	pos_item.set_metadata(0, "X")

	var pos_y = property_tree.create_item(root)
	pos_y.set_text(0, "Y")
	pos_y.set_text(1, str(int(c["rect"].position.y)))
	pos_y.set_editable(1, true)
	pos_y.set_metadata(0, "Y")

	var sz_w = property_tree.create_item(root)
	sz_w.set_text(0, "Width")
	sz_w.set_text(1, str(int(c["rect"].size.x)))
	sz_w.set_editable(1, true)
	sz_w.set_metadata(0, "Width")

	var sz_h = property_tree.create_item(root)
	sz_h.set_text(0, "Height")
	sz_h.set_text(1, str(int(c["rect"].size.y)))
	sz_h.set_editable(1, true)
	sz_h.set_metadata(0, "Height")

	# Type-specific properties
	for key in c["properties"].keys():
		var prop = property_tree.create_item(root)
		prop.set_text(0, key)
		prop.set_text(1, str(c["properties"][key]))
		prop.set_editable(1, true)
		prop.set_metadata(0, key)

func _on_property_edited():
	if selected_child_idx < 0 or selected_child_idx >= child_items.size():
		return

	var edited = property_tree.get_edited()
	if not edited:
		return

	var key = edited.get_metadata(0)
	var val = edited.get_text(1)
	var c = child_items[selected_child_idx]

	match key:
		"X": c["rect"].position.x = val.to_float()
		"Y": c["rect"].position.y = val.to_float()
		"Width": c["rect"].size.x = maxf(val.to_float(), 8)
		"Height": c["rect"].size.y = maxf(val.to_float(), 8)
		"(Name)":
			c["name"] = val
			c["properties"]["(Name)"] = val
			_refresh_child_tree()
		_:
			c["properties"][key] = val

	canvas.queue_redraw()
	_refresh_live_preview()

# =====================================================================
# CANVAS DRAWING
# =====================================================================

func _on_canvas_draw():
	# Grid dots
	var csize = canvas.size
	for x in range(0, int(csize.x), GRID_SIZE):
		for y in range(0, int(csize.y), GRID_SIZE):
			canvas.draw_rect(Rect2(x, y, 1, 1), VB6_GRID_COLOR)

	# Draw each child control
	for i in range(child_items.size()):
		var c = child_items[i]
		var r: Rect2 = c["rect"]
		var is_selected = (i == selected_child_idx)

		# Background
		var bg_color = Color.WHITE
		match c["type"]:
			"Panel", "PanelContainer": bg_color = Color(0.94, 0.93, 0.91)
			"ColorRect":
				var hex = c["properties"].get("Color", "#808080")
				bg_color = Color.from_string(hex, Color(0.5, 0.5, 0.5))
			"ProgressBar": bg_color = Color(0.9, 0.95, 0.9)
			"TextEdit": bg_color = Color(1.0, 1.0, 1.0)
			"TextureRect": bg_color = Color(0.8, 0.8, 0.8)

		canvas.draw_rect(r, bg_color)
		canvas.draw_rect(r, VB6_PANEL_BORDER, false, 1.0)

		# Text label inside the control
		var display_text = c["properties"].get("Text", c["name"])
		if display_text.is_empty():
			display_text = c["name"]
		var font = ThemeDB.fallback_font
		var font_size = c["properties"].get("FontSize", "12").to_int()
		if font_size < 8:
			font_size = 12
		var text_pos = r.position + Vector2(4, font_size + 2)
		# Clip text to fit
		var max_text_width = r.size.x - 8
		if max_text_width > 0:
			canvas.draw_string(font, text_pos, display_text, HORIZONTAL_ALIGNMENT_LEFT, max_text_width, font_size, VB6_TEXT)

		# Type badge (small, top-right)
		var badge_text = c["type"]
		var badge_pos = r.position + Vector2(r.size.x - 4, 10)
		canvas.draw_string(font, badge_pos, badge_text, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8, 9, Color(0.5, 0.5, 0.5, 0.6))

		# Selection handles
		if is_selected:
			canvas.draw_rect(r.grow(1), VB6_SELECT_COLOR, false, 2.0)
			# Corner handles
			var hs = resize_handle_size
			var corners = [
				Rect2(r.end.x - hs/2, r.end.y - hs/2, hs, hs),  # bottom-right
				Rect2(r.position.x - hs/2, r.end.y - hs/2, hs, hs),  # bottom-left
				Rect2(r.end.x - hs/2, r.position.y - hs/2, hs, hs),  # top-right
				Rect2(r.position.x - hs/2, r.position.y - hs/2, hs, hs),  # top-left
			]
			for corner in corners:
				canvas.draw_rect(corner, VB6_SELECT_COLOR)

# =====================================================================
# CANVAS INPUT (drag / resize / select)
# =====================================================================

func _on_canvas_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_canvas_mouse_down(event.position)
			else:
				_canvas_mouse_up()
	elif event is InputEventMouseMotion:
		if dragging or resizing:
			_canvas_mouse_move(event.position)

func _canvas_mouse_down(pos: Vector2):
	# Check resize handles first (on selected item)
	if selected_child_idx >= 0 and selected_child_idx < child_items.size():
		var r = child_items[selected_child_idx]["rect"]
		var hs = resize_handle_size
		var br_handle = Rect2(r.end.x - hs/2, r.end.y - hs/2, hs, hs)
		if br_handle.has_point(pos):
			resizing = true
			drag_offset = pos - r.end
			return

	# Check if clicking on a child
	# Search in reverse (topmost first)
	for i in range(child_items.size() - 1, -1, -1):
		if child_items[i]["rect"].has_point(pos):
			selected_child_idx = i
			dragging = true
			drag_offset = pos - child_items[i]["rect"].position
			_refresh_child_tree()
			_refresh_properties()
			canvas.queue_redraw()
			return

	# Clicked on empty space — deselect
	selected_child_idx = -1
	dragging = false
	_refresh_child_tree()
	_refresh_properties()
	canvas.queue_redraw()

func _canvas_mouse_up():
	if dragging or resizing:
		dragging = false
		resizing = false
		_refresh_properties()
		_refresh_live_preview()

func _canvas_mouse_move(pos: Vector2):
	if selected_child_idx < 0 or selected_child_idx >= child_items.size():
		return

	var c = child_items[selected_child_idx]
	if dragging:
		var new_pos = pos - drag_offset
		# Snap to grid
		new_pos.x = snapped(new_pos.x, GRID_SIZE)
		new_pos.y = snapped(new_pos.y, GRID_SIZE)
		new_pos.x = maxf(new_pos.x, 0)
		new_pos.y = maxf(new_pos.y, 0)
		c["rect"].position = new_pos
		canvas.queue_redraw()
	elif resizing:
		var new_end = pos - drag_offset
		new_end.x = snapped(new_end.x, GRID_SIZE)
		new_end.y = snapped(new_end.y, GRID_SIZE)
		var new_size = new_end - c["rect"].position
		new_size.x = maxf(new_size.x, 16)
		new_size.y = maxf(new_size.y, 16)
		c["rect"].size = new_size
		canvas.queue_redraw()

# =====================================================================
# LIVE PREVIEW
# =====================================================================

func _refresh_live_preview():
	# Clear existing children
	for child in live_viewport.get_children():
		child.queue_free()

	# Wait a frame for cleanup
	if not is_inside_tree():
		return
	await get_tree().process_frame

	# Build the root node
	var root_types_map := {
		"Control": "Control", "Panel": "Panel",
		"PanelContainer": "PanelContainer", "HBoxContainer": "HBoxContainer",
		"VBoxContainer": "VBoxContainer", "MarginContainer": "MarginContainer",
		"CenterContainer": "CenterContainer", "Button": "Button",
		"TextureRect": "TextureRect"
	}
	var root_types_list := ["Control", "Panel", "PanelContainer", "HBoxContainer",
						   "VBoxContainer", "MarginContainer", "CenterContainer",
						   "Button", "TextureRect"]
	var selected_root = root_types_list[root_option.selected] if root_option.selected < root_types_list.size() else "Panel"
	var root_node = ClassDB.instantiate(selected_root)
	if not root_node:
		return
	if root_node is Control:
		root_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	live_viewport.add_child(root_node)

	# Add child controls
	for c in child_items:
		var node = _instantiate_child_node(c)
		if node:
			root_node.add_child(node)

func _instantiate_child_node(c: Dictionary) -> Control:
	var type_name = c["type"]
	if not ClassDB.class_exists(type_name):
		return null
	var node = ClassDB.instantiate(type_name)
	if not node or not node is Control:
		if node:
			node.free()
		return null

	node.position = c["rect"].position
	node.size = c["rect"].size

	# Apply properties
	var props = c["properties"]
	if props.has("Text"):
		if node.has_method("set_text"):
			node.set("text", props["Text"])
	if props.has("PlaceholderText") and node is LineEdit:
		node.placeholder_text = props["PlaceholderText"]
	if props.has("Color") and node is ColorRect:
		node.color = Color.from_string(props["Color"], Color.GRAY)
	if props.has("MinValue") and node.has_method("set_min"):
		node.set("min_value", props["MinValue"].to_float())
	if props.has("MaxValue") and node.has_method("set_max"):
		node.set("max_value", props["MaxValue"].to_float())
	if props.has("Value") and node.has_method("set_value"):
		node.set("value", props["Value"].to_float())
	if props.has("FontSize"):
		var fs = props["FontSize"].to_int()
		if fs > 0:
			node.add_theme_font_size_override("font_size", fs)

	return node

# =====================================================================
# LOAD EXISTING SCENE
# =====================================================================

## Populates the designer from an existing .tscn file for editing.
func load_from_scene(path: String) -> void:
	scene_path = path
	is_editing_existing = true

	if not FileAccess.file_exists(path):
		push_warning("Custom Control Designer: Scene not found: " + path)
		return

	var packed = load(path)
	if not packed or not packed is PackedScene:
		return

	var instance = packed.instantiate()
	if not instance:
		return

	# Set name and root type from the root node
	ctrl_name = instance.name
	if name_edit:
		name_edit.text = ctrl_name

	var root_class = instance.get_class()
	var root_types_list := ["Control", "Panel", "PanelContainer", "HBoxContainer",
						   "VBoxContainer", "MarginContainer", "CenterContainer",
						   "Button", "TextureRect"]
	var idx = root_types_list.find(root_class)
	if idx >= 0 and root_option:
		root_option.selected = idx
		root_type = root_class

	# Load children
	child_items.clear()
	for child in instance.get_children():
		if child is Control:
			var props := {"(Name)": child.name}
			if child.has_method("get_text"):
				props["Text"] = str(child.get("text"))
			if child is ColorRect:
				props["Color"] = "#" + child.color.to_html(false)
			if child is Range:
				props["MinValue"] = str(child.min_value)
				props["MaxValue"] = str(child.max_value)
				props["Value"] = str(child.value)

			child_items.append({
				"type": child.get_class(),
				"name": str(child.name),
				"rect": Rect2(child.position, child.size),
				"properties": props,
			})

	instance.queue_free()

	_refresh_child_tree()
	_refresh_properties()
	_refresh_live_preview()
	canvas.queue_redraw()
	status_label.text = "Editing existing control: " + ctrl_name

# =====================================================================
# SAVE TO .TSCN
# =====================================================================

func _on_save_and_close():
	var final_name = name_edit.text.strip_edges().replace(" ", "")
	if final_name.is_empty():
		status_label.text = "Error: Name cannot be empty."
		return

	var root_types_list := ["Control", "Panel", "PanelContainer", "HBoxContainer",
						   "VBoxContainer", "MarginContainer", "CenterContainer",
						   "Button", "TextureRect"]
	var selected_root = root_types_list[root_option.selected] if root_option.selected < root_types_list.size() else "Panel"

	# Determine save path
	var save_path = scene_path
	if save_path.is_empty():
		var dir_path = "res://custom_controls"
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		save_path = dir_path + "/" + final_name + ".tscn"

	# Build the scene tree in memory and save via PackedScene
	var root_node = ClassDB.instantiate(selected_root)
	if not root_node:
		status_label.text = "Error: Could not create root node type: " + selected_root
		return

	root_node.name = final_name
	if root_node is Control:
		# Calculate bounding box of all children to set custom_minimum_size
		var max_x: float = 100
		var max_y: float = 60
		for c in child_items:
			var end = c["rect"].position + c["rect"].size
			max_x = maxf(max_x, end.x + 8)
			max_y = maxf(max_y, end.y + 8)
		root_node.custom_minimum_size = Vector2(max_x, max_y)

	# Add child nodes
	for c in child_items:
		var node = _instantiate_child_node(c)
		if node:
			node.name = c["name"]
			root_node.add_child(node)
			# Required for PackedScene to include the child
			node.owner = root_node

	# Save as PackedScene
	var packed = PackedScene.new()
	var err = packed.pack(root_node)
	if err != OK:
		status_label.text = "Error: Failed to pack scene (error " + str(err) + ")"
		root_node.queue_free()
		return

	err = ResourceSaver.save(packed, save_path)
	root_node.queue_free()

	if err != OK:
		status_label.text = "Error: Failed to save " + save_path + " (error " + str(err) + ")"
		return

	print("VisualGasic: Saved custom control '", final_name, "' to ", save_path)
	control_saved.emit(final_name, save_path)

	# Tell editor to rescan
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

	hide()
	queue_free()

func _on_cancel():
	queue_free()

# =====================================================================
# THEME
# =====================================================================

func _build_theme() -> Theme:
	var t = Theme.new()

	# Window chrome
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = VB6_HEADER_BG
	win_sb.border_color = VB6_HEADER_BORDER
	win_sb.set_border_width_all(2)
	win_sb.set_content_margin_all(4)
	t.set_stylebox("embedded_border", "Window", win_sb)
	var win_unfocus = win_sb.duplicate()
	win_unfocus.bg_color = Color(0.50, 0.50, 0.50)
	t.set_stylebox("embedded_unfocused_border", "Window", win_unfocus)
	t.set_color("title_color", "Window", VB6_HEADER_TEXT)

	# Dialog panel
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = VB6_PANEL_BG
	panel_sb.border_color = VB6_PANEL_BORDER
	panel_sb.set_border_width_all(1)
	panel_sb.set_content_margin_all(8)
	t.set_stylebox("panel", "AcceptDialog", panel_sb)

	# Tree (property inspector + child tree)
	var tree_sb = StyleBoxFlat.new()
	tree_sb.bg_color = VB6_LIST_BG
	tree_sb.border_color = VB6_PANEL_BORDER
	tree_sb.set_border_width_all(1)
	t.set_stylebox("panel", "Tree", tree_sb)
	t.set_color("font_color", "Tree", VB6_TEXT)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	var tree_sel = StyleBoxFlat.new()
	tree_sel.bg_color = VB6_ACTIVE_TITLE
	t.set_stylebox("selected", "Tree", tree_sel)
	t.set_stylebox("selected_focus", "Tree", tree_sel)

	# ItemList (palette)
	var list_sb = StyleBoxFlat.new()
	list_sb.bg_color = VB6_LIST_BG
	list_sb.border_color = VB6_PANEL_BORDER
	list_sb.set_border_width_all(1)
	t.set_stylebox("panel", "ItemList", list_sb)
	t.set_color("font_color", "ItemList", VB6_TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	var list_sel = StyleBoxFlat.new()
	list_sel.bg_color = VB6_ACTIVE_TITLE
	t.set_stylebox("selected", "ItemList", list_sel)
	t.set_stylebox("selected_focus", "ItemList", list_sel)

	# Label
	t.set_color("font_color", "Label", VB6_TEXT)

	# LineEdit
	var le_sb = StyleBoxFlat.new()
	le_sb.bg_color = VB6_LIST_BG
	le_sb.border_color = VB6_PANEL_BORDER
	le_sb.set_border_width_all(1)
	le_sb.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", le_sb)
	t.set_color("font_color", "LineEdit", VB6_TEXT)

	# Button
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = VB6_PANEL_BG
	btn_sb.border_color = VB6_PANEL_BORDER
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 8; btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 3; btn_sb.content_margin_bottom = 3
	t.set_stylebox("normal", "Button", btn_sb)
	var btn_hov = btn_sb.duplicate()
	btn_hov.bg_color = VB6_BTN_HOVER_BG
	t.set_stylebox("hover", "Button", btn_hov)
	var btn_pre = btn_sb.duplicate()
	btn_pre.bg_color = VB6_BTN_PRESSED_BG
	t.set_stylebox("pressed", "Button", btn_pre)
	t.set_color("font_color", "Button", VB6_TEXT)
	t.set_color("font_hover_color", "Button", VB6_TEXT)
	t.set_color("font_pressed_color", "Button", VB6_TEXT)

	# OptionButton
	t.set_stylebox("normal", "OptionButton", btn_sb)
	t.set_stylebox("hover", "OptionButton", btn_hov)
	t.set_stylebox("pressed", "OptionButton", btn_pre)
	t.set_color("font_color", "OptionButton", VB6_TEXT)

	# Scrollbar
	var scroll_bg = StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.92, 0.91, 0.89)
	scroll_bg.set_content_margin_all(2)
	var grabber_sb = StyleBoxFlat.new()
	grabber_sb.bg_color = Color(0.72, 0.71, 0.68)
	grabber_sb.set_content_margin_all(2)
	var grabber_hl = StyleBoxFlat.new()
	grabber_hl.bg_color = Color(0.60, 0.59, 0.56)
	grabber_hl.set_content_margin_all(2)
	for sbar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sbar, scroll_bg)
		t.set_stylebox("grabber", sbar, grabber_sb)
		t.set_stylebox("grabber_highlight", sbar, grabber_hl)

	# Tooltip
	var tip_sb = StyleBoxFlat.new()
	tip_sb.bg_color = Color(1.0, 1.0, 0.88)
	tip_sb.border_color = Color(0.0, 0.0, 0.0)
	tip_sb.set_border_width_all(1)
	tip_sb.set_content_margin_all(4)
	t.set_stylebox("panel", "TooltipPanel", tip_sb)
	t.set_color("font_color", "TooltipLabel", Color(0.0, 0.0, 0.0))

	# HSplitContainer
	t.set_constant("separation", "HSplitContainer", 8)

	return t
