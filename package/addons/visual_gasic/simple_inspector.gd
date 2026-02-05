@tool
extends VBoxContainer

# VB6-Style Property Inspector for Visual Gasic
# Shows properties similar to VB6's Properties Window

var editor_plugin: EditorPlugin
var property_grid: GridContainer
var current_node: Node

# VB6-like property categories
const CATEGORY_APPEARANCE = "Appearance"
const CATEGORY_BEHAVIOR = "Behavior"
const CATEGORY_FONT = "Font"
const CATEGORY_POSITION = "Position"
const CATEGORY_MISC = "Misc"

func _init():
	name = "Properties"
	size_flags_vertical = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(200, 150)
	
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
	_add_prop_row("(Name)", node.name, "name")
	
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
	lbl.custom_minimum_size.x = 90
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
			current_node.name = value
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
