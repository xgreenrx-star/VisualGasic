@tool
extends VBoxContainer

# VB6-Style Property Inspector for Visual Gasic
# Shows properties similar to VB6's Properties Window
# Features: Object dropdown, Alphabetic/Categorized toggle, Description area

var editor_plugin: EditorPlugin
var property_grid: GridContainer
var current_node: Node
var rename_dialog: ConfirmationDialog
var old_name_for_rename: String = ""
var new_name_for_rename: String = ""

# === VB6 UI: Object dropdown ===
var _object_dropdown: OptionButton
var _all_form_nodes: Array = []

# === VB6 UI: Alphabetic / Categorized toggle ===
var _view_mode: int = 1  # 0 = Alphabetic, 1 = Categorized
var _alpha_btn: Button
var _cat_btn: Button
# Store property data for alphabetic re-sort
var _property_entries: Array = []  # Array of {label, value, prop_key, type, category}

# === VB6 UI: Property description area ===
var _description_label: RichTextLabel
var _selected_prop_key: String = ""

# VB6-like property categories
const CATEGORY_APPEARANCE = "Appearance"
const CATEGORY_BEHAVIOR = "Behavior"
const CATEGORY_FONT = "Font"
const CATEGORY_POSITION = "Position"
const CATEGORY_MISC = "Misc"

# Property help descriptions (VB6-style)
const PROPERTY_DESCRIPTIONS: Dictionary = {
	"name": "Returns the name used in code to identify a control.",
	"text": "Returns/sets the text contained in the control.",
	"visible": "Returns/sets whether the control is visible at runtime.",
	"enabled": "Returns/sets a value that determines whether the control can respond to user-generated events.",
	"left": "Returns/sets the distance between the internal left edge of the control and the left edge of its container.",
	"top": "Returns/sets the distance between the internal top edge of the control and the top edge of its container.",
	"width": "Returns/sets the width of the control.",
	"height": "Returns/sets the height of the control.",
	"backcolor": "Returns/sets the background color used to display text and graphics in a control.",
	"forecolor": "Returns/sets the foreground color used to display text and graphics in a control.",
	"font_size": "Returns/sets the size of the font used in the control.",
	"tooltip_text": "Returns/sets the text displayed when the user pauses the mouse pointer over a control.",
	"tag": "Stores any extra data needed for your program. A general-purpose string.",
	"tabstop": "Returns/sets whether the user can use TAB to give the focus to a control.",
	"flat": "Returns/sets whether a Button appears 3D (raised) or flat.",
	"alignment": "Returns/sets the alignment of text in a Label control (Left, Center, Right).",
	"autosize": "Returns/sets whether a Label automatically resizes to fit its contents.",
	"wordwrap": "Returns/sets whether a Label wraps text to the next line.",
	"locked": "Returns/sets whether the control's content can be edited by the user.",
	"max_length": "Returns/sets the maximum number of characters a user can enter in the TextBox.",
	"secret": "Returns/sets whether the TextBox displays password characters instead of text.",
	"placeholder_text": "Returns/sets the grayed-out text displayed when the TextBox is empty.",
	"button_pressed": "Returns/sets the current state of a CheckBox or OptionButton.",
	"default": "Returns/sets whether a command button is the default button for a form.",
	"cancel": "Returns/sets whether a command button is the Cancel button for a form.",
	"opacity": "Returns/sets the opacity level of the control (0-100%).",
	"rotation": "Returns/sets the rotation angle of the control in degrees.",
	"scale_x": "Returns/sets the horizontal scale factor of the control.",
	"scale_y": "Returns/sets the vertical scale factor of the control.",
	"min_width": "Returns/sets the minimum width constraint for responsive layout.",
	"min_height": "Returns/sets the minimum height constraint for responsive layout.",
	"clip_contents": "Returns/sets whether child controls are clipped to the control boundary.",
	"anchor": "Returns/sets how the control is anchored to its parent for responsive layout.",
	"pivot": "Returns/sets the rotation/scale pivot point of the control.",
	"cursor": "Returns/sets the type of mouse pointer displayed when over the control.",
	"range_value": "Returns/sets the current value of a scrollbar, slider, or progress bar.",
	"range_min": "Returns/sets the minimum value of a scrollbar, slider, or progress bar.",
	"range_max": "Returns/sets the maximum value of a scrollbar, slider, or progress bar.",
	"range_step": "Returns/sets the increment amount for scrollbar or slider changes.",
	"show_percentage": "Returns/sets whether the ProgressBar displays its value as a percentage.",
	"spinbox_prefix": "Returns/sets the text displayed before the SpinBox value.",
	"spinbox_suffix": "Returns/sets the text displayed after the SpinBox value.",
}

func _init():
	name = "Properties"
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(180, 100)  # Reasonable min for dock; Godot handles resize via dock splitters
	
	# === 1. Object Dropdown (VB6-style, at the very top) ===
	_object_dropdown = OptionButton.new()
	_object_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	_object_dropdown.clip_text = true
	_object_dropdown.custom_minimum_size.y = 24
	_object_dropdown.item_selected.connect(_on_object_dropdown_selected)
	add_child(_object_dropdown)
	
	# === 2. Alphabetic / Categorized toggle buttons ===
	var tab_bar = HBoxContainer.new()
	tab_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	
	_alpha_btn = Button.new()
	_alpha_btn.text = "A-Z"
	_alpha_btn.tooltip_text = "Alphabetic"
	_alpha_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_alpha_btn.toggle_mode = true
	_alpha_btn.button_pressed = false
	_alpha_btn.pressed.connect(_on_alphabetic_pressed)
	tab_bar.add_child(_alpha_btn)
	
	_cat_btn = Button.new()
	_cat_btn.text = "≡"
	_cat_btn.tooltip_text = "Categorized"
	_cat_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_cat_btn.toggle_mode = true
	_cat_btn.button_pressed = true
	_cat_btn.pressed.connect(_on_categorized_pressed)
	tab_bar.add_child(_cat_btn)
	
	add_child(tab_bar)
	
	# === 3. Property grid (scrollable) ===
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(scroll)
	
	property_grid = GridContainer.new()
	property_grid.columns = 2
	property_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(property_grid)
	
	# === 4. Description area at the bottom ===
	var desc_sep = HSeparator.new()
	add_child(desc_sep)
	
	_description_label = RichTextLabel.new()
	_description_label.custom_minimum_size = Vector2(0, 48)
	_description_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_description_label.fit_content = false
	_description_label.scroll_active = true
	_description_label.bbcode_enabled = false
	_description_label.text = ""
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.15, 0.15, 0.18)
	desc_style.content_margin_left = 4
	desc_style.content_margin_right = 4
	desc_style.content_margin_top = 2
	desc_style.content_margin_bottom = 2
	_description_label.add_theme_stylebox_override("normal", desc_style)
	_description_label.add_theme_font_size_override("normal_font_size", 11)
	add_child(_description_label)

func setup(plugin: EditorPlugin):
	editor_plugin = plugin
	editor_plugin.get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

# === Object Dropdown Management ===

func _refresh_object_dropdown():
	"""Rebuild the object dropdown with all controls in the current form."""
	_object_dropdown.clear()
	_all_form_nodes.clear()
	
	if not editor_plugin or not is_instance_valid(editor_plugin):
		return
	
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		_object_dropdown.add_item("(No Form)")
		return
	
	_collect_nodes_recursive(root)
	
	for i in _all_form_nodes.size():
		var node = _all_form_nodes[i]
		if not is_instance_valid(node):
			continue
		var label = str(node.name) + "  " + str(node.get_class())
		_object_dropdown.add_item(label)
		_object_dropdown.set_item_metadata(_object_dropdown.item_count - 1, node)
	
	# Select the current_node in the dropdown
	_select_current_in_dropdown()

func _collect_nodes_recursive(node: Node):
	_all_form_nodes.append(node)
	for child in node.get_children():
		# Skip internal children like _FormBackground
		if not String(child.name).begins_with("_"):
			_collect_nodes_recursive(child)

func _select_current_in_dropdown():
	if not current_node:
		return
	for i in _all_form_nodes.size():
		if _all_form_nodes[i] == current_node:
			_object_dropdown.select(i)
			return

func _on_object_dropdown_selected(idx: int):
	if idx < 0 or idx >= _all_form_nodes.size():
		return
	var node = _all_form_nodes[idx]
	if not is_instance_valid(node):
		return
	# Select it in the editor
	if editor_plugin and is_instance_valid(editor_plugin):
		var selection = editor_plugin.get_editor_interface().get_selection()
		selection.clear()
		selection.add_node(node)

# === Alphabetic / Categorized Toggle ===

func _on_alphabetic_pressed():
	_view_mode = 0
	_alpha_btn.button_pressed = true
	_cat_btn.button_pressed = false
	if current_node:
		update_properties(current_node)

func _on_categorized_pressed():
	_view_mode = 1
	_alpha_btn.button_pressed = false
	_cat_btn.button_pressed = true
	if current_node:
		update_properties(current_node)

# === Selection Changed ===

func _on_selection_changed():
	if not is_instance_valid(editor_plugin):
		return
	var sel = editor_plugin.get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() == 1:
		update_properties(sel[0])
	else:
		clear_properties()

func clear_properties():
	current_node = null
	_property_entries.clear()
	for c in property_grid.get_children():
		c.queue_free()
	_description_label.text = ""
	_refresh_object_dropdown()

# === Description Area ===

func _show_description(prop_key: String):
	_selected_prop_key = prop_key
	var desc = PROPERTY_DESCRIPTIONS.get(prop_key, "")
	if desc.is_empty():
		_description_label.text = prop_key
	else:
		_description_label.text = desc

func update_properties(node: Node):
	_property_entries.clear()
	for c in property_grid.get_children():
		c.queue_free()
	current_node = node
	_refresh_object_dropdown()
	_description_label.text = ""
	
	# Collect all property entries first
	_collect_properties(node)
	
	# Render based on view mode
	if _view_mode == 0:
		_render_alphabetic()
	else:
		_render_categorized()

func _collect_properties(node: Node):
	"""Collect all property entries into _property_entries array."""
	# ===== (Name) - Always first, like VB6 =====
	_property_entries.append({"label": "(Name)", "value": String(node.name), "prop_key": "name", "type": "string", "category": ""})
	
	# ===== Appearance Properties =====
	if "text" in node:
		_property_entries.append({"label": "Caption", "value": node.text, "prop_key": "text", "type": "string", "category": CATEGORY_APPEARANCE})
	
	if node is Control:
		var back_color = _get_back_color(node)
		_property_entries.append({"label": "BackColor", "value": back_color, "prop_key": "backcolor", "type": "color", "category": CATEGORY_APPEARANCE})
		var fore_color = _get_fore_color(node)
		_property_entries.append({"label": "ForeColor", "value": fore_color, "prop_key": "forecolor", "type": "color", "category": CATEGORY_APPEARANCE})
	
	if node is BaseButton:
		if "flat" in node:
			_property_entries.append({"label": "Flat", "value": node.flat, "prop_key": "flat", "type": "bool", "category": CATEGORY_APPEARANCE})
	
	if node is Label:
		_property_entries.append({"label": "Alignment", "value": node.horizontal_alignment, "prop_key": "alignment", "type": "alignment", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "AutoSize", "value": node.autowrap_mode == TextServer.AUTOWRAP_OFF, "prop_key": "autosize", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "WordWrap", "value": node.autowrap_mode != TextServer.AUTOWRAP_OFF, "prop_key": "wordwrap", "type": "bool", "category": CATEGORY_APPEARANCE})
	
	if node is LineEdit:
		_property_entries.append({"label": "Text", "value": node.text, "prop_key": "text", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "MaxLength", "value": node.max_length, "prop_key": "max_length", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "PasswordMode", "value": node.secret, "prop_key": "secret", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Locked", "value": !node.editable, "prop_key": "locked", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "PlaceholderText", "value": node.placeholder_text, "prop_key": "placeholder_text", "type": "string", "category": CATEGORY_APPEARANCE})
	
	if node is ProgressBar:
		_property_entries.append({"label": "Value", "value": node.value, "prop_key": "range_value", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Min", "value": node.min_value, "prop_key": "range_min", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Max", "value": node.max_value, "prop_key": "range_max", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ShowPercent", "value": node.show_percentage, "prop_key": "show_percentage", "type": "bool", "category": CATEGORY_APPEARANCE})
	
	if node is Slider:
		_property_entries.append({"label": "Value", "value": node.value, "prop_key": "range_value", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Min", "value": node.min_value, "prop_key": "range_min", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Max", "value": node.max_value, "prop_key": "range_max", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Step", "value": node.step, "prop_key": "range_step", "type": "number", "category": CATEGORY_APPEARANCE})
	
	if node is SpinBox:
		_property_entries.append({"label": "Value", "value": node.value, "prop_key": "range_value", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Min", "value": node.min_value, "prop_key": "range_min", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Max", "value": node.max_value, "prop_key": "range_max", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Step", "value": node.step, "prop_key": "range_step", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Prefix", "value": node.prefix, "prop_key": "spinbox_prefix", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Suffix", "value": node.suffix, "prop_key": "spinbox_suffix", "type": "string", "category": CATEGORY_APPEARANCE})
	
	# ===== Behavior Properties =====
	if node is Control:
		_property_entries.append({"label": "Enabled", "value": _get_enabled(node), "prop_key": "enabled", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "Visible", "value": node.visible, "prop_key": "visible", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "TabStop", "value": node.focus_mode != Control.FOCUS_NONE, "prop_key": "tabstop", "type": "bool", "category": CATEGORY_BEHAVIOR})
	
	if node is BaseButton:
		var is_default = node.has_meta("vb_default") and node.get_meta("vb_default")
		_property_entries.append({"label": "Default", "value": is_default, "prop_key": "default", "type": "bool", "category": CATEGORY_BEHAVIOR})
		var is_cancel = node.has_meta("vb_cancel") and node.get_meta("vb_cancel")
		_property_entries.append({"label": "Cancel", "value": is_cancel, "prop_key": "cancel", "type": "bool", "category": CATEGORY_BEHAVIOR})
	
	if node is CheckBox or node is CheckButton:
		_property_entries.append({"label": "Value", "value": node.button_pressed, "prop_key": "button_pressed", "type": "bool", "category": CATEGORY_BEHAVIOR})
	
	# ===== Font Properties =====
	if node is Control:
		var font_size = node.get_theme_font_size("font_size") if node.has_theme_font_size("font_size") else 14
		_property_entries.append({"label": "FontSize", "value": font_size, "prop_key": "font_size", "type": "number", "category": CATEGORY_FONT})
	
	# ===== Position Properties =====
	if node is Control or node is Node2D:
		_property_entries.append({"label": "Left", "value": int(node.position.x), "prop_key": "left", "type": "number", "category": CATEGORY_POSITION})
		_property_entries.append({"label": "Top", "value": int(node.position.y), "prop_key": "top", "type": "number", "category": CATEGORY_POSITION})
		
	if node is Control:
		_property_entries.append({"label": "Width", "value": int(node.size.x), "prop_key": "width", "type": "number", "category": CATEGORY_POSITION})
		_property_entries.append({"label": "Height", "value": int(node.size.y), "prop_key": "height", "type": "number", "category": CATEGORY_POSITION})
	
	# ===== Layout Properties =====
	if node is Control:
		_property_entries.append({"label": "Anchor", "value": node, "prop_key": "anchor", "type": "anchor", "category": "Layout"})
		_property_entries.append({"label": "MinWidth", "value": int(node.custom_minimum_size.x), "prop_key": "min_width", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "MinHeight", "value": int(node.custom_minimum_size.y), "prop_key": "min_height", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "ClipContent", "value": node.clip_contents, "prop_key": "clip_contents", "type": "bool", "category": "Layout"})
	
	# ===== Effects Properties =====
	if node is Control or node is Node2D:
		_property_entries.append({"label": "Opacity", "value": int(node.modulate.a * 100), "prop_key": "opacity", "type": "slider", "category": "Effects"})
		_property_entries.append({"label": "Rotation", "value": int(rad_to_deg(node.rotation)), "prop_key": "rotation", "type": "number", "category": "Effects"})
		_property_entries.append({"label": "ScaleX", "value": node.scale.x, "prop_key": "scale_x", "type": "number", "category": "Effects"})
		_property_entries.append({"label": "ScaleY", "value": node.scale.y, "prop_key": "scale_y", "type": "number", "category": "Effects"})
	
	if node is Control:
		_property_entries.append({"label": "Pivot", "value": {"pivot": node.pivot_offset, "size": node.size}, "prop_key": "pivot", "type": "pivot", "category": "Effects"})
	
	# ===== Misc Properties =====
	if node is Control:
		_property_entries.append({"label": "ToolTipText", "value": node.tooltip_text, "prop_key": "tooltip_text", "type": "string", "category": CATEGORY_MISC})
		_property_entries.append({"label": "MousePointer", "value": node.mouse_default_cursor_shape, "prop_key": "cursor", "type": "cursor", "category": CATEGORY_MISC})
	
	var tag_value = node.get_meta("vb_tag", "") if node.has_meta("vb_tag") else ""
	_property_entries.append({"label": "Tag", "value": str(tag_value), "prop_key": "tag", "type": "string", "category": CATEGORY_MISC})

func _render_categorized():
	"""Render properties grouped by category with section headers."""
	# (Name) is always first
	for entry in _property_entries:
		if entry["category"] == "":
			_render_property_entry(entry)
	
	# Group by category
	var categories_order = [CATEGORY_APPEARANCE, CATEGORY_BEHAVIOR, CATEGORY_FONT, CATEGORY_POSITION, "Layout", "Effects", CATEGORY_MISC]
	for cat in categories_order:
		var cat_entries = _property_entries.filter(func(e): return e["category"] == cat)
		if cat_entries.size() > 0:
			_add_section_header(cat)
			for entry in cat_entries:
				_render_property_entry(entry)

func _render_alphabetic():
	"""Render all properties sorted alphabetically (no section headers)."""
	# (Name) is always first
	for entry in _property_entries:
		if entry["category"] == "":
			_render_property_entry(entry)
	
	# Sort remaining entries alphabetically
	var sorted_entries = _property_entries.filter(func(e): return e["category"] != "")
	sorted_entries.sort_custom(func(a, b): return a["label"].to_lower() < b["label"].to_lower())
	for entry in sorted_entries:
		_render_property_entry(entry)

func _render_property_entry(entry: Dictionary):
	"""Render a single property entry to the grid."""
	var prop_key = entry["prop_key"]
	var label_text = entry["label"]
	var value = entry["value"]
	var type = entry["type"]
	
	match type:
		"color":
			_add_color_row(label_text, value, prop_key)
		"alignment":
			_add_alignment_row(label_text, value)
		"cursor":
			_add_cursor_row(label_text, value)
		"slider":
			_add_slider_row(label_text, value, prop_key)
		"anchor":
			_add_anchor_row(label_text, value)
		"pivot":
			_add_pivot_row(label_text, value["pivot"], value["size"])
		_:
			_add_prop_row(label_text, value, prop_key)

func _add_section_header(title: String):
	var sep = HSeparator.new()
	sep.custom_minimum_size.y = 4
	property_grid.add_child(sep)
	
	var lbl = Label.new()
	lbl.text = "── " + title + " ──"
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	property_grid.add_child(lbl)

func _add_prop_row(label_text: String, value, prop_key: String):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 70  # Reduced for narrower panels
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_show_description(prop_key)
	)
	property_grid.add_child(lbl)
	
	if value is bool:
		var chk = CheckBox.new()
		chk.button_pressed = value
		chk.toggled.connect(func(v): _apply_prop(prop_key, v))
		chk.focus_entered.connect(func(): _show_description(prop_key))
		property_grid.add_child(chk)
	elif value is String:
		var txt = LineEdit.new()
		txt.text = value
		txt.size_flags_horizontal = SIZE_EXPAND_FILL
		txt.text_submitted.connect(func(v): _apply_prop(prop_key, v))
		txt.focus_exited.connect(func(): _apply_prop(prop_key, txt.text))
		txt.focus_entered.connect(func(): _show_description(prop_key))
		property_grid.add_child(txt)
	elif value is float or value is int:
		var spin = SpinBox.new()
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.value = value
		spin.max_value = 10000
		spin.min_value = -10000
		spin.size_flags_horizontal = SIZE_EXPAND_FILL
		spin.value_changed.connect(func(v): _apply_prop(prop_key, v))
		spin.get_line_edit().focus_entered.connect(func(): _show_description(prop_key))
		property_grid.add_child(spin)
	else:
		var placeholder = Label.new()
		placeholder.text = str(value)
		property_grid.add_child(placeholder)

func _add_color_row(label_text: String, color: Color, prop_key: String):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	property_grid.add_child(lbl)
	
	var color_btn = ColorPickerButton.new()
	color_btn.color = color
	color_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	color_btn.custom_minimum_size.y = 24
	color_btn.color_changed.connect(func(c): _apply_prop(prop_key, c))
	property_grid.add_child(color_btn)

func _add_alignment_row(label_text: String, alignment: int):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	property_grid.add_child(lbl)
	
	var opt = OptionButton.new()
	opt.add_item("Left", 0)    # HORIZONTAL_ALIGNMENT_LEFT
	opt.add_item("Center", 1)  # HORIZONTAL_ALIGNMENT_CENTER
	opt.add_item("Right", 2)   # HORIZONTAL_ALIGNMENT_RIGHT
	opt.select(alignment)
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	opt.item_selected.connect(func(idx): _apply_prop("alignment", idx))
	property_grid.add_child(opt)

func _add_cursor_row(label_text: String, cursor: int):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	property_grid.add_child(lbl)
	
	var opt = OptionButton.new()
	opt.add_item("Default", Control.CURSOR_ARROW)
	opt.add_item("IBeam", Control.CURSOR_IBEAM)
	opt.add_item("Pointing Hand", Control.CURSOR_POINTING_HAND)
	opt.add_item("Cross", Control.CURSOR_CROSS)
	opt.add_item("Wait", Control.CURSOR_WAIT)
	opt.add_item("Busy", Control.CURSOR_BUSY)
	opt.add_item("Move", Control.CURSOR_MOVE)
	opt.add_item("SizeNS", Control.CURSOR_VSIZE)
	opt.add_item("SizeWE", Control.CURSOR_HSIZE)
	# Select current
	for i in opt.item_count:
		if opt.get_item_id(i) == cursor:
			opt.select(i)
			break
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	opt.item_selected.connect(func(idx): _apply_prop("cursor", opt.get_item_id(idx)))
	property_grid.add_child(opt)

func _add_slider_row(label_text: String, value: int, prop_key: String):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	property_grid.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = value
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 60
	
	var spin = SpinBox.new()
	spin.min_value = 0
	spin.max_value = 100
	spin.value = value
	spin.suffix = "%"
	spin.custom_minimum_size.x = 60
	
	slider.value_changed.connect(func(v): 
		spin.value = v
		_apply_prop(prop_key, v)
	)
	spin.value_changed.connect(func(v): 
		slider.value = v
		_apply_prop(prop_key, v)
	)
	
	hbox.add_child(slider)
	hbox.add_child(spin)
	property_grid.add_child(hbox)

func _add_anchor_row(label_text: String, node: Control):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	property_grid.add_child(lbl)
	
	var opt = OptionButton.new()
	opt.add_item("None", 0)
	opt.add_item("Full Rect", 1)
	opt.add_item("Left Wide", 2)
	opt.add_item("Top Wide", 3)
	opt.add_item("Right Wide", 4)
	opt.add_item("Bottom Wide", 5)
	opt.add_item("Center", 6)
	opt.add_item("VCenter Wide", 7)
	opt.add_item("HCenter Wide", 8)
	
	# Detect current anchor preset
	var preset = _detect_anchor_preset(node)
	opt.select(preset)
	
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	opt.item_selected.connect(func(idx): _apply_prop("anchor", idx))
	property_grid.add_child(opt)

func _add_pivot_row(label_text: String, pivot: Vector2, size: Vector2):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	property_grid.add_child(lbl)
	
	var opt = OptionButton.new()
	opt.add_item("Top-Left", 0)
	opt.add_item("Top-Center", 1)
	opt.add_item("Top-Right", 2)
	opt.add_item("Center-Left", 3)
	opt.add_item("Center", 4)
	opt.add_item("Center-Right", 5)
	opt.add_item("Bottom-Left", 6)
	opt.add_item("Bottom-Center", 7)
	opt.add_item("Bottom-Right", 8)
	
	# Detect current pivot
	var preset = _detect_pivot_preset(pivot, size)
	opt.select(preset)
	
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	opt.item_selected.connect(func(idx): _apply_prop("pivot", idx))
	property_grid.add_child(opt)

func _detect_anchor_preset(node: Control) -> int:
	# Simple detection based on anchor values
	if node.anchor_left == 0 and node.anchor_top == 0 and node.anchor_right == 0 and node.anchor_bottom == 0:
		return 0  # None (top-left)
	elif node.anchor_left == 0 and node.anchor_top == 0 and node.anchor_right == 1 and node.anchor_bottom == 1:
		return 1  # Full Rect
	elif node.anchor_left == 0 and node.anchor_right == 0:
		return 2  # Left Wide
	elif node.anchor_top == 0 and node.anchor_bottom == 0:
		return 3  # Top Wide
	elif node.anchor_left == 0.5 and node.anchor_right == 0.5:
		return 6  # Center
	return 0

func _detect_pivot_preset(pivot: Vector2, size: Vector2) -> int:
	if size.x <= 0 or size.y <= 0:
		return 0
	var px = pivot.x / size.x if size.x > 0 else 0
	var py = pivot.y / size.y if size.y > 0 else 0
	
	if px < 0.25 and py < 0.25:
		return 0  # Top-Left
	elif px > 0.75 and py < 0.25:
		return 2  # Top-Right
	elif px < 0.25 and py > 0.75:
		return 6  # Bottom-Left
	elif px > 0.75 and py > 0.75:
		return 8  # Bottom-Right
	elif py < 0.25:
		return 1  # Top-Center
	elif py > 0.75:
		return 7  # Bottom-Center
	elif px < 0.25:
		return 3  # Center-Left
	elif px > 0.75:
		return 5  # Center-Right
	return 4  # Center

func _get_enabled(node: Node) -> bool:
	if node is BaseButton:
		return !node.disabled
	elif node is LineEdit:
		return node.editable
	elif node is Control:
		return node.mouse_filter != Control.MOUSE_FILTER_IGNORE
	return true

func _apply_prop(prop_key: String, value):
	if not current_node:
		return
	
	match prop_key:
		"name":
			_handle_rename(String(current_node.name), str(value))
		"text":
			if "text" in current_node:
				current_node.text = value
		"visible":
			current_node.visible = value
		"enabled":
			if current_node is BaseButton:
				current_node.disabled = !value
			elif current_node is LineEdit:
				current_node.editable = value
		"tabstop":
			if current_node is Control:
				current_node.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
		"left":
			current_node.position.x = value
		"top":
			current_node.position.y = value
		"width":
			if current_node is Control:
				current_node.size.x = value
		"height":
			if current_node is Control:
				current_node.size.y = value
		"tooltip_text":
			if current_node is Control:
				current_node.tooltip_text = str(value)
				print("VisualGasic: Set tooltip to '", value, "' on ", current_node.name)
		"tag":
			current_node.set_meta("vb_tag", value)
		"default":
			current_node.set_meta("vb_default", value)
			# Could also set up shortcut for Enter key
		"cancel":
			current_node.set_meta("vb_cancel", value)
			# Could also set up shortcut for Escape key
		"flat":
			if "flat" in current_node:
				current_node.flat = value
		"backcolor":
			_apply_back_color(value)
		"forecolor":
			_apply_fore_color(value)
		"alignment":
			if current_node is Label:
				current_node.horizontal_alignment = value
		"cursor":
			if current_node is Control:
				current_node.mouse_default_cursor_shape = value
		"max_length":
			if current_node is LineEdit:
				current_node.max_length = int(value)
		"secret":
			if current_node is LineEdit:
				current_node.secret = value
		"locked":
			if current_node is LineEdit:
				current_node.editable = !value
		"placeholder_text":
			if current_node is LineEdit:
				current_node.placeholder_text = value
		"button_pressed":
			if current_node is BaseButton:
				current_node.button_pressed = value
		"autosize":
			if current_node is Label:
				current_node.autowrap_mode = TextServer.AUTOWRAP_OFF if value else TextServer.AUTOWRAP_WORD_SMART
		"wordwrap":
			if current_node is Label:
				current_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if value else TextServer.AUTOWRAP_OFF
		"font_size":
			if current_node is Control:
				current_node.add_theme_font_size_override("font_size", int(value))
		# Modern properties
		"opacity":
			var mod = current_node.modulate
			mod.a = value / 100.0
			current_node.modulate = mod
		"rotation":
			current_node.rotation = deg_to_rad(value)
		"scale_x":
			current_node.scale.x = value
		"scale_y":
			current_node.scale.y = value
		"min_width":
			if current_node is Control:
				current_node.custom_minimum_size.x = value
		"min_height":
			if current_node is Control:
				current_node.custom_minimum_size.y = value
		"clip_contents":
			if current_node is Control:
				current_node.clip_contents = value
		"anchor":
			_apply_anchor_preset(int(value))
		"pivot":
			_apply_pivot_preset(int(value))
		# Range controls (ProgressBar, Slider, SpinBox)
		"range_value":
			if current_node is Range:
				current_node.value = value
		"range_min":
			if current_node is Range:
				current_node.min_value = value
		"range_max":
			if current_node is Range:
				current_node.max_value = value
		"range_step":
			if current_node is Range:
				current_node.step = value
		"show_percentage":
			if current_node is ProgressBar:
				current_node.show_percentage = value
		"spinbox_prefix":
			if current_node is SpinBox:
				current_node.prefix = value
		"spinbox_suffix":
			if current_node is SpinBox:
				current_node.suffix = value

## Get the current background color of a control
func _get_back_color(node: Control) -> Color:
	# Check for stored meta color first
	if node.has_meta("vb_backcolor"):
		return node.get_meta("vb_backcolor")
	# Try to get from theme stylebox
	if node.has_theme_stylebox_override("normal"):
		var style = node.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			return style.bg_color
	# Default gray
	return Color(0.8, 0.8, 0.8, 1.0)

## Get the current foreground (text) color of a control
func _get_fore_color(node: Control) -> Color:
	# Check for stored meta color first
	if node.has_meta("vb_forecolor"):
		return node.get_meta("vb_forecolor")
	# Try to get from theme color override
	if node.has_theme_color_override("font_color"):
		return node.get_theme_color("font_color")
	# Default black
	return Color(0.0, 0.0, 0.0, 1.0)

## Apply background color to a control using theme stylebox
func _apply_back_color(color: Color):
	if not current_node or not current_node is Control:
		return
	
	# Store for later retrieval
	current_node.set_meta("vb_backcolor", color)
	
	# For buttons (Button, CheckBox, etc.)
	if current_node is BaseButton:
		# Create styleboxes for all button states
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = color
		style_normal.set_corner_radius_all(3)
		style_normal.set_border_width_all(1)
		style_normal.border_color = color.darkened(0.2)
		style_normal.content_margin_left = 8
		style_normal.content_margin_right = 8
		style_normal.content_margin_top = 4
		style_normal.content_margin_bottom = 4
		
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = color.lightened(0.1)
		style_hover.set_corner_radius_all(3)
		style_hover.set_border_width_all(1)
		style_hover.border_color = color.darkened(0.1)
		style_hover.content_margin_left = 8
		style_hover.content_margin_right = 8
		style_hover.content_margin_top = 4
		style_hover.content_margin_bottom = 4
		
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = color.darkened(0.15)
		style_pressed.set_corner_radius_all(3)
		style_pressed.set_border_width_all(1)
		style_pressed.border_color = color.darkened(0.3)
		style_pressed.content_margin_left = 8
		style_pressed.content_margin_right = 8
		style_pressed.content_margin_top = 4
		style_pressed.content_margin_bottom = 4
		
		var style_disabled = StyleBoxFlat.new()
		style_disabled.bg_color = color.darkened(0.3)
		style_disabled.set_corner_radius_all(3)
		style_disabled.set_border_width_all(1)
		style_disabled.border_color = color.darkened(0.4)
		style_disabled.content_margin_left = 8
		style_disabled.content_margin_right = 8
		style_disabled.content_margin_top = 4
		style_disabled.content_margin_bottom = 4
		
		current_node.add_theme_stylebox_override("normal", style_normal)
		current_node.add_theme_stylebox_override("hover", style_hover)
		current_node.add_theme_stylebox_override("pressed", style_pressed)
		current_node.add_theme_stylebox_override("focus", style_hover)
		current_node.add_theme_stylebox_override("disabled", style_disabled)
		print("VisualGasic: Applied BackColor ", color, " to ", current_node.name)
	
	elif current_node is Panel:
		var style = StyleBoxFlat.new()
		style.bg_color = color
		current_node.add_theme_stylebox_override("panel", style)
	
	elif current_node is LineEdit:
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_border_width_all(1)
		style.border_color = Color(0.3, 0.3, 0.3)
		style.content_margin_left = 4
		style.content_margin_right = 4
		current_node.add_theme_stylebox_override("normal", style)
	
	elif current_node is Label:
		# Labels use a panel stylebox for background
		var style = StyleBoxFlat.new()
		style.bg_color = color
		current_node.add_theme_stylebox_override("normal", style)

## Apply foreground (text) color to a control
func _apply_fore_color(color: Color):
	if not current_node or not current_node is Control:
		return
	
	# Store for later retrieval
	current_node.set_meta("vb_forecolor", color)
	
	# Apply font color override
	current_node.add_theme_color_override("font_color", color)
	
	# For buttons, also set hover/pressed colors
	if current_node is BaseButton:
		current_node.add_theme_color_override("font_hover_color", color)
		current_node.add_theme_color_override("font_pressed_color", color)
		current_node.add_theme_color_override("font_focus_color", color)
		current_node.add_theme_color_override("font_disabled_color", color.darkened(0.3))
	
	# For LineEdit, set text color
	if current_node is LineEdit:
		current_node.add_theme_color_override("font_color", color)
		current_node.add_theme_color_override("font_placeholder_color", color.darkened(0.3))

## Apply anchor preset to control
func _apply_anchor_preset(preset: int):
	if not current_node or not current_node is Control:
		return
	
	match preset:
		0:  # None (top-left)
			current_node.anchor_left = 0
			current_node.anchor_top = 0
			current_node.anchor_right = 0
			current_node.anchor_bottom = 0
		1:  # Full Rect
			current_node.anchor_left = 0
			current_node.anchor_top = 0
			current_node.anchor_right = 1
			current_node.anchor_bottom = 1
			current_node.offset_left = 0
			current_node.offset_top = 0
			current_node.offset_right = 0
			current_node.offset_bottom = 0
		2:  # Left Wide
			current_node.anchor_left = 0
			current_node.anchor_top = 0
			current_node.anchor_right = 0
			current_node.anchor_bottom = 1
			current_node.offset_bottom = 0
		3:  # Top Wide
			current_node.anchor_left = 0
			current_node.anchor_top = 0
			current_node.anchor_right = 1
			current_node.anchor_bottom = 0
			current_node.offset_right = 0
		4:  # Right Wide
			current_node.anchor_left = 1
			current_node.anchor_top = 0
			current_node.anchor_right = 1
			current_node.anchor_bottom = 1
			current_node.offset_left = -current_node.size.x
			current_node.offset_bottom = 0
		5:  # Bottom Wide
			current_node.anchor_left = 0
			current_node.anchor_top = 1
			current_node.anchor_right = 1
			current_node.anchor_bottom = 1
			current_node.offset_top = -current_node.size.y
			current_node.offset_right = 0
		6:  # Center
			current_node.anchor_left = 0.5
			current_node.anchor_top = 0.5
			current_node.anchor_right = 0.5
			current_node.anchor_bottom = 0.5
			current_node.offset_left = -current_node.size.x / 2
			current_node.offset_top = -current_node.size.y / 2
			current_node.offset_right = current_node.size.x / 2
			current_node.offset_bottom = current_node.size.y / 2
		7:  # VCenter Wide
			current_node.anchor_left = 0
			current_node.anchor_top = 0.5
			current_node.anchor_right = 1
			current_node.anchor_bottom = 0.5
			current_node.offset_top = -current_node.size.y / 2
			current_node.offset_right = 0
			current_node.offset_bottom = current_node.size.y / 2
		8:  # HCenter Wide
			current_node.anchor_left = 0.5
			current_node.anchor_top = 0
			current_node.anchor_right = 0.5
			current_node.anchor_bottom = 1
			current_node.offset_left = -current_node.size.x / 2
			current_node.offset_right = current_node.size.x / 2
			current_node.offset_bottom = 0

## Apply pivot preset to control
func _apply_pivot_preset(preset: int):
	if not current_node or not current_node is Control:
		return
	
	var size = current_node.size
	match preset:
		0:  # Top-Left
			current_node.pivot_offset = Vector2(0, 0)
		1:  # Top-Center
			current_node.pivot_offset = Vector2(size.x / 2, 0)
		2:  # Top-Right
			current_node.pivot_offset = Vector2(size.x, 0)
		3:  # Center-Left
			current_node.pivot_offset = Vector2(0, size.y / 2)
		4:  # Center
			current_node.pivot_offset = Vector2(size.x / 2, size.y / 2)
		5:  # Center-Right
			current_node.pivot_offset = Vector2(size.x, size.y / 2)
		6:  # Bottom-Left
			current_node.pivot_offset = Vector2(0, size.y)
		7:  # Bottom-Center
			current_node.pivot_offset = Vector2(size.x / 2, size.y)
		8:  # Bottom-Right
			current_node.pivot_offset = Vector2(size.x, size.y)

## Handle control rename with optional script refactoring
func _handle_rename(old_name: String, new_name: String):
	if not current_node or old_name == new_name or new_name.is_empty():
		return
	
	# Validate the new name is not already in use
	var duplicate_node = _find_control_by_name(new_name)
	if duplicate_node and duplicate_node != current_node:
		_show_duplicate_name_error(new_name)
		# Refresh to restore original name in inspector
		update_properties(current_node)
		return
	
	# Validate the name is a valid identifier
	if not _is_valid_control_name(new_name):
		_show_invalid_name_error(new_name)
		update_properties(current_node)
		return
	
	# Store names for potential refactoring
	old_name_for_rename = old_name
	new_name_for_rename = new_name
	
	# Find associated .vg scripts that might reference this control
	var scripts_with_refs = _find_scripts_referencing_control(old_name)
	
	if scripts_with_refs.size() > 0:
		# Show dialog asking if user wants to update scripts
		_show_rename_refactor_dialog(old_name, new_name, scripts_with_refs)
	else:
		# No scripts reference this control, just rename directly
		current_node.name = new_name
		print("VisualGasic: Renamed '", old_name, "' to '", new_name, "'")

## Find a control by name in the current form
func _find_control_by_name(control_name: String) -> Node:
	if not editor_plugin or not is_instance_valid(editor_plugin):
		return null
	
	var edited_scene = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not edited_scene:
		return null
	
	# Check the root itself
	if edited_scene.name == control_name:
		return edited_scene
	
	# Search all descendants (case-insensitive like VB6)
	return _find_node_by_name_recursive(edited_scene, control_name)

func _find_node_by_name_recursive(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name.nocasecmp_to(target_name) == 0:
			return child
		var found = _find_node_by_name_recursive(child, target_name)
		if found:
			return found
	return null

## Validate that a control name is a valid VB identifier
func _is_valid_control_name(name: String) -> bool:
	if name.is_empty():
		return false
	
	# Must start with a letter
	var first_char = name[0]
	if not (first_char >= 'A' and first_char <= 'Z') and not (first_char >= 'a' and first_char <= 'z'):
		return false
	
	# Rest must be letters, digits, or underscores
	for i in range(1, name.length()):
		var c = name[i]
		var is_letter = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z')
		var is_digit = c >= '0' and c <= '9'
		var is_underscore = c == '_'
		if not is_letter and not is_digit and not is_underscore:
			return false
	
	# Check for reserved VB keywords
	var reserved = ["Sub", "Function", "Dim", "If", "Then", "Else", "End", "For", "Next", 
		"Do", "Loop", "While", "Wend", "Select", "Case", "Me", "True", "False", "Nothing",
		"And", "Or", "Not", "Mod", "New", "As", "ByRef", "ByVal", "Private", "Public"]
	for keyword in reserved:
		if name.nocasecmp_to(keyword) == 0:
			return false
	
	return true

## Show error dialog for duplicate name
func _show_duplicate_name_error(name: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Duplicate Name"
	dialog.dialog_text = "A control named '" + name + "' already exists on this form.\n\nPlease choose a different name."
	dialog.ok_button_text = "OK"
	
	editor_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2(350, 120))
	
	# Auto cleanup
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

## Show error dialog for invalid name
func _show_invalid_name_error(name: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Invalid Name"
	dialog.dialog_text = "'" + name + "' is not a valid control name.\n\nControl names must:\n• Start with a letter (A-Z)\n• Contain only letters, numbers, and underscores\n• Not be a reserved keyword"
	dialog.ok_button_text = "OK"
	
	editor_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2(380, 160))
	
	# Auto cleanup
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

## Find all .vg scripts that reference a control name
func _find_scripts_referencing_control(control_name: String) -> Array:
	var scripts_found: Array = []
	
	if not editor_plugin or not is_instance_valid(editor_plugin):
		return scripts_found
	
	# Get the root of the current scene
	var edited_scene = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not edited_scene:
		return scripts_found
	
	# Cache of open editor buffers: script_path -> source text
	var open_editor_sources: Dictionary = {}
	
	# FIRST: Check ALL open scripts in the script editor (may have unsaved changes!)
	var script_editor = editor_plugin.get_editor_interface().get_script_editor()
	if script_editor:
		# Get list of open scripts
		var open_scripts = script_editor.get_open_scripts()
		var open_editors = script_editor.get_open_script_editors()
		
		# Match scripts to their editors by index
		for i in range(min(open_scripts.size(), open_editors.size())):
			var script = open_scripts[i]
			var editor_base = open_editors[i]
			
			if script and script.resource_path.ends_with(".vg"):
				var code_edit = _find_code_edit(editor_base)
				if code_edit:
					var source = code_edit.text
					var script_path = script.resource_path
					open_editor_sources[script_path] = source
					if _source_references_control(source, control_name):
						if not script_path in scripts_found:
							scripts_found.append(script_path)
							print("VisualGasic: Found reference in open editor: ", script_path.get_file())
	
	# Search for .vg scripts in the scene's directory
	var scene_path = edited_scene.scene_file_path
	if not scene_path.is_empty():
		var base_dir = scene_path.get_base_dir()
		var dir = DirAccess.open(base_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".vg"):
					var full_path = base_dir.path_join(file_name)
					if not full_path in scripts_found:
						# Check if we already have this in open editors
						if full_path in open_editor_sources:
							# Already checked above
							pass
						else:
							# Read from disk
							var f = FileAccess.open(full_path, FileAccess.READ)
							if f:
								var source = f.get_as_text()
								f.close()
								if _source_references_control(source, control_name):
									scripts_found.append(full_path)
				file_name = dir.get_next()
			dir.list_dir_end()
	
	print("VisualGasic: Total scripts with references: ", scripts_found.size())
	return scripts_found

## Find CodeEdit widget inside a script editor base
func _find_code_edit(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for child in node.get_children():
		var found = _find_code_edit(child)
		if found:
			return found
	return null

## Check if source code references a control name
func _source_references_control(source: String, control_name: String) -> bool:
	if source.is_empty():
		return false
	
	# Check for common VB patterns that reference controls:
	# - ControlName.Property
	# - ControlName_Event()
	# - Me.ControlName
	# - Controls("ControlName")
	
	var patterns = [
		control_name + ".",          # Property access
		control_name + "_",          # Event handler (e.g., Button1_Click)
		"Me." + control_name,        # Me.ControlName
		"\"" + control_name + "\"",  # String literal reference
	]
	
	for pattern in patterns:
		var pos = source.findn(pattern)
		if pos >= 0:  # Case-insensitive search
			return true
	
	return false

## Show confirmation dialog for rename refactoring
func _show_rename_refactor_dialog(old_name: String, new_name: String, scripts: Array):
	if rename_dialog and is_instance_valid(rename_dialog):
		rename_dialog.queue_free()
	
	rename_dialog = ConfirmationDialog.new()
	rename_dialog.title = "Rename Control"
	rename_dialog.dialog_text = "The following scripts reference '" + old_name + "':\n\n"
	
	for script_path in scripts:
		rename_dialog.dialog_text += "  • " + script_path.get_file() + "\n"
	
	rename_dialog.dialog_text += "\nRename '" + old_name + "' to '" + new_name + "'?"
	
	rename_dialog.ok_button_text = "Rename + Update Scripts"
	rename_dialog.cancel_button_text = "Cancel"
	
	# Add a third button for "Rename Only"
	rename_dialog.add_button("Rename Only", true, "rename_only")
	
	rename_dialog.confirmed.connect(_on_refactor_confirmed.bind(scripts))
	rename_dialog.canceled.connect(_on_refactor_cancelled)
	rename_dialog.custom_action.connect(_on_rename_only)
	
	# Add to editor
	editor_plugin.get_editor_interface().get_base_control().add_child(rename_dialog)
	rename_dialog.popup_centered(Vector2(400, 200))

## User confirmed: rename AND update scripts
func _on_refactor_confirmed(scripts: Array):
	if not current_node:
		return
	
	var old_name = old_name_for_rename
	var new_name = new_name_for_rename
	
	# Update all scripts
	var updated_count = 0
	for script_path in scripts:
		if _update_script_references(script_path, old_name, new_name):
			updated_count += 1
	
	# Now rename the control
	current_node.name = new_name
	
	print("VisualGasic: Renamed '", old_name, "' to '", new_name, "' and updated ", updated_count, " script(s)")
	
	# Refresh properties display
	update_properties(current_node)
	
	_cleanup_rename_dialog()

## User chose "Rename Only" - rename without updating scripts
func _on_rename_only(action: String):
	if action == "rename_only" and current_node:
		current_node.name = new_name_for_rename
		print("VisualGasic: Renamed '", old_name_for_rename, "' to '", new_name_for_rename, "' (scripts not updated)")
		update_properties(current_node)
	_cleanup_rename_dialog()

## User cancelled - don't rename at all
func _on_refactor_cancelled():
	print("VisualGasic: Rename cancelled")
	if current_node:
		update_properties(current_node)
	_cleanup_rename_dialog()

func _cleanup_rename_dialog():
	if rename_dialog and is_instance_valid(rename_dialog):
		rename_dialog.queue_free()
		rename_dialog = null
	old_name_for_rename = ""
	new_name_for_rename = ""

## Update references in a script file (or open editor buffer)
func _update_script_references(script_path: String, old_name: String, new_name: String) -> bool:
	# First, check if this script is currently open in the editor
	var script_editor = editor_plugin.get_editor_interface().get_script_editor() if editor_plugin else null
	var code_edit: CodeEdit = null
	var source: String = ""
	var is_open_in_editor := false
	
	if script_editor:
		# Get parallel arrays of scripts and editors
		var open_scripts = script_editor.get_open_scripts()
		var open_editors = script_editor.get_open_script_editors()
		
		for i in range(min(open_scripts.size(), open_editors.size())):
			var script = open_scripts[i]
			var editor_base = open_editors[i]
			if script and script.resource_path == script_path:
				# Found it - get the CodeEdit
				code_edit = _find_code_edit(editor_base)
				if code_edit:
					source = code_edit.text
					is_open_in_editor = true
					break
	
	# If not open in editor, read from disk
	if not is_open_in_editor:
		var f = FileAccess.open(script_path, FileAccess.READ)
		if not f:
			push_error("VisualGasic: Could not open " + script_path + " for reading")
			return false
		source = f.get_as_text()
		f.close()
	
	var original_source = source
	
	# Replace patterns using regex for proper word boundary matching
	var regex = RegEx.new()
	
	# Pattern 1: ControlName. (property access)
	regex.compile("(?i)\\b" + old_name + "\\.")
	source = regex.sub(source, new_name + ".", true)
	
	# Pattern 2: ControlName_ (event handlers like Button1_Click)
	regex.compile("(?i)\\b" + old_name + "_")
	source = regex.sub(source, new_name + "_", true)
	
	# Pattern 3: Me.ControlName (but not Me.ControlNameOther)
	regex.compile("(?i)Me\\." + old_name + "\\b")
	source = regex.sub(source, "Me." + new_name, true)
	
	# Pattern 4: "ControlName" string literals
	regex.compile("(?i)\"" + old_name + "\"")
	source = regex.sub(source, "\"" + new_name + "\"", true)
	
	if source == original_source:
		print("VisualGasic: No changes needed in ", script_path.get_file())
		return false  # No changes made
	
	# Apply the changes
	if is_open_in_editor and code_edit:
		# Update the editor buffer directly
		code_edit.text = source
		print("VisualGasic: Updated editor buffer for ", script_path.get_file())
	else:
		# Write to disk
		var f = FileAccess.open(script_path, FileAccess.WRITE)
		if not f:
			push_error("VisualGasic: Could not open " + script_path + " for writing")
			return false
		f.store_string(source)
		f.close()
		print("VisualGasic: Updated file on disk: ", script_path.get_file())
		
		# Signal editor to reload
		if editor_plugin and is_instance_valid(editor_plugin):
			editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	
	return true
