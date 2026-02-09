@tool
extends VBoxContainer

# VB6-Style Property Inspector for Visual Gasic
# Shows properties similar to VB6's Properties Window

var editor_plugin: EditorPlugin
var property_grid: GridContainer
var current_node: Node
var rename_dialog: ConfirmationDialog
var old_name_for_rename: String = ""
var new_name_for_rename: String = ""

# VB6-like property categories
const CATEGORY_APPEARANCE = "Appearance"
const CATEGORY_BEHAVIOR = "Behavior"
const CATEGORY_FONT = "Font"
const CATEGORY_POSITION = "Position"
const CATEGORY_MISC = "Misc"

func _init():
	name = "Properties"
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(150, 100)  # Reduced for better dock resizing
	
	var title = Label.new()
	title.text = "Properties"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.4) # VB6 Title Bar Blue
	title.add_theme_stylebox_override("normal", style)
	add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(scroll)
	
	property_grid = GridContainer.new()
	property_grid.columns = 2
	property_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(property_grid)

func setup(plugin: EditorPlugin):
	editor_plugin = plugin
	editor_plugin.get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

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
	for c in property_grid.get_children():
		c.queue_free()

func update_properties(node: Node):
	clear_properties()
	current_node = node
	
	# ===== (Name) - Always first, like VB6 =====
	# Convert StringName to String for proper LineEdit handling
	_add_prop_row("(Name)", String(node.name), "name")
	
	# ===== Appearance Properties =====
	_add_section_header("Appearance")
	
	if "text" in node:
		_add_prop_row("Caption", node.text, "text")
	
	if node is Control:
		# BackColor - use theme stylebox override for actual background color
		var back_color = _get_back_color(node)
		_add_color_row("BackColor", back_color, "backcolor")
		# ForeColor - use theme color override for text color
		var fore_color = _get_fore_color(node)
		_add_color_row("ForeColor", fore_color, "forecolor")
	
	if node is BaseButton:
		# Flat - like VB6's Style property (0=Standard, 1=Graphical)
		if "flat" in node:
			_add_prop_row("Flat", node.flat, "flat")
	
	if node is Label:
		# Alignment - like VB6's Alignment property
		_add_alignment_row("Alignment", node.horizontal_alignment)
		# AutoSize equivalent
		_add_prop_row("AutoSize", node.autowrap_mode == TextServer.AUTOWRAP_OFF, "autosize")
		# WordWrap
		_add_prop_row("WordWrap", node.autowrap_mode != TextServer.AUTOWRAP_OFF, "wordwrap")
	
	if node is LineEdit:
		# Text property
		_add_prop_row("Text", node.text, "text")
		# MaxLength - like VB6's MaxLength
		_add_prop_row("MaxLength", node.max_length, "max_length")
		# PasswordChar equivalent
		_add_prop_row("PasswordMode", node.secret, "secret")
		# ReadOnly - like VB6's Locked
		_add_prop_row("Locked", !node.editable, "locked")
		# PlaceholderText (not in VB6, but useful)
		_add_prop_row("PlaceholderText", node.placeholder_text, "placeholder_text")
	
	# ProgressBar/Slider specific
	if node is ProgressBar:
		_add_prop_row("Value", node.value, "range_value")
		_add_prop_row("Min", node.min_value, "range_min")
		_add_prop_row("Max", node.max_value, "range_max")
		_add_prop_row("ShowPercent", node.show_percentage, "show_percentage")
	
	if node is Slider:
		_add_prop_row("Value", node.value, "range_value")
		_add_prop_row("Min", node.min_value, "range_min")
		_add_prop_row("Max", node.max_value, "range_max")
		_add_prop_row("Step", node.step, "range_step")
	
	if node is SpinBox:
		_add_prop_row("Value", node.value, "range_value")
		_add_prop_row("Min", node.min_value, "range_min")
		_add_prop_row("Max", node.max_value, "range_max")
		_add_prop_row("Step", node.step, "range_step")
		_add_prop_row("Prefix", node.prefix, "spinbox_prefix")
		_add_prop_row("Suffix", node.suffix, "spinbox_suffix")
	
	# ===== Behavior Properties =====
	_add_section_header("Behavior")
	
	if node is Control:
		_add_prop_row("Enabled", _get_enabled(node), "enabled")
		_add_prop_row("Visible", node.visible, "visible")
		_add_prop_row("TabStop", node.focus_mode != Control.FOCUS_NONE, "tabstop")
	
	if node is BaseButton:
		# Default - like VB6's Default property (Enter key activates)
		if "shortcut_in_tooltip" in node:
			# Check if it's set as default button
			var is_default = node.has_meta("vb_default") and node.get_meta("vb_default")
			_add_prop_row("Default", is_default, "default")
		# Cancel - like VB6's Cancel property (Escape key activates)
		var is_cancel = node.has_meta("vb_cancel") and node.get_meta("vb_cancel")
		_add_prop_row("Cancel", is_cancel, "cancel")
	
	if node is CheckBox or node is CheckButton:
		_add_prop_row("Value", node.button_pressed, "button_pressed")
	
	# ===== Font Properties =====
	_add_section_header("Font")
	
	if node is Control:
		var font_size = node.get_theme_font_size("font_size") if node.has_theme_font_size("font_size") else 14
		_add_prop_row("FontSize", font_size, "font_size")
	
	# ===== Position Properties =====
	_add_section_header("Position")
	
	if node is Control or node is Node2D:
		_add_prop_row("Left", int(node.position.x), "left")
		_add_prop_row("Top", int(node.position.y), "top")
		
	if node is Control:
		_add_prop_row("Width", int(node.size.x), "width")
		_add_prop_row("Height", int(node.size.y), "height")
	
	# ===== Modern/Layout Properties =====
	_add_section_header("Layout")
	
	if node is Control:
		# Anchors for responsive design
		_add_anchor_row("Anchor", node)
		# Size constraints
		_add_prop_row("MinWidth", int(node.custom_minimum_size.x), "min_width")
		_add_prop_row("MinHeight", int(node.custom_minimum_size.y), "min_height")
		# Clip content
		_add_prop_row("ClipContent", node.clip_contents, "clip_contents")
	
	# ===== Effects Properties =====
	_add_section_header("Effects")
	
	if node is Control or node is Node2D:
		# Opacity - modern transparency control
		_add_slider_row("Opacity", int(node.modulate.a * 100), "opacity")
		# Rotation in degrees
		_add_prop_row("Rotation", int(rad_to_deg(node.rotation)), "rotation")
		# Scale
		_add_prop_row("ScaleX", node.scale.x, "scale_x")
		_add_prop_row("ScaleY", node.scale.y, "scale_y")
	
	if node is Control:
		# Pivot point for rotation/scale
		_add_pivot_row("Pivot", node.pivot_offset, node.size)
	
	# ===== Misc Properties =====
	_add_section_header("Misc")
	
	if node is Control:
		# ToolTipText - like VB6's ToolTipText
		_add_prop_row("ToolTipText", node.tooltip_text, "tooltip_text")
		# MousePointer equivalent
		_add_cursor_row("MousePointer", node.mouse_default_cursor_shape)
	
	# Tag - custom user data (VB6's Tag property)
	var tag_value = node.get_meta("vb_tag", "") if node.has_meta("vb_tag") else ""
	_add_prop_row("Tag", str(tag_value), "tag")

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
	property_grid.add_child(lbl)
	
	if value is bool:
		var chk = CheckBox.new()
		chk.button_pressed = value
		chk.toggled.connect(func(v): _apply_prop(prop_key, v))
		property_grid.add_child(chk)
	elif value is String:
		var txt = LineEdit.new()
		txt.text = value
		txt.size_flags_horizontal = SIZE_EXPAND_FILL
		txt.text_submitted.connect(func(v): _apply_prop(prop_key, v))
		txt.focus_exited.connect(func(): _apply_prop(prop_key, txt.text))
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
