@tool
extends Window
## Form Preview Window
##
## Creates a live preview of the current form design by instantiating
## real Godot Control nodes that match the form designer's data.
## Shows what the form would look like at runtime.

var _form_panel: Panel  # Client area panel (holds all controls)

func build_from_designer(designer) -> void:
	"""Read form properties and controls from the FormDesigner and build a real window."""
	if not designer:
		push_error("FormPreviewWindow: No designer provided")
		return

	# --- Form-level properties ---
	var form_props: Dictionary = {}
	if designer.has_method("get_form_properties"):
		form_props = designer.get_form_properties()

	var form_name_str: String = designer.get_form_name() if designer.has_method("get_form_name") else "Form1"
	var form_sz: Vector2i = designer.get_form_size() if designer.has_method("get_form_size") else Vector2i(600, 400)

	var caption: String = form_props.get("Caption", form_name_str)
	var back_color: Color = form_props.get("BackColor", Color(0.753, 0.753, 0.753, 1.0))
	var fore_color: Color = form_props.get("ForeColor", Color.BLACK)
	var border_style: int = form_props.get("BorderStyle", 2)  # 2 = Sizable
	var control_box: bool = form_props.get("ControlBox", true)
	var min_button: bool = form_props.get("MinButton", true)
	var max_button: bool = form_props.get("MaxButton", true)
	var start_pos: int = form_props.get("StartUpPosition", 2)  # 2 = CenterScreen

	# Configure the Window
	title = caption
	size = form_sz
	min_size = Vector2i(200, 150)

	# Border style → window flags
	match border_style:
		0:  # None — borderless
			borderless = true
			unresizable = true
		1:  # Fixed Single
			borderless = false
			unresizable = true
		2:  # Sizable (default)
			borderless = false
			unresizable = false
		3:  # Fixed Dialog
			borderless = false
			unresizable = true
		4:  # Fixed ToolWindow
			borderless = false
			unresizable = true
		5:  # Sizable ToolWindow
			borderless = false
			unresizable = false

	# Exclusive popup-ish behavior — don't steal entire focus
	exclusive = false
	transient = true
	always_on_top = true
	wrap_controls = true

	# Client area panel (form background)
	_form_panel = Panel.new()
	_form_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = back_color
	_form_panel.add_theme_stylebox_override("panel", panel_sb)
	add_child(_form_panel)

	# --- Build all controls ---
	var ctrl_count: int = designer.get_control_count()
	for i in range(ctrl_count):
		var info: Dictionary = designer.get_control_info(i)
		var ctrl = _create_control(info, fore_color, back_color)
		if ctrl:
			_form_panel.add_child(ctrl)

	# Position the window
	if start_pos == 2:
		# CenterScreen — need to defer so size is applied
		call_deferred("_center_on_screen")

	# Connect close
	close_requested.connect(_on_close_requested)

func _center_on_screen() -> void:
	var screen_size = DisplayServer.screen_get_size()
	position = Vector2i((screen_size.x - size.x) / 2, (screen_size.y - size.y) / 2)

func _on_close_requested() -> void:
	hide()
	queue_free()

# =============================================================================
# CONTROL FACTORY — Maps form designer types to real Godot controls
# =============================================================================

func _create_control(info: Dictionary, default_fore: Color, default_back: Color) -> Control:
	var type: String = info.get("type", "")
	var ctrl_name: String = info.get("name", "Control")
	var x: float = info.get("x", 0)
	var y: float = info.get("y", 0)
	var w: float = info.get("width", 80)
	var h: float = info.get("height", 24)
	var text: String = info.get("text", "")
	var props: Dictionary = info.get("properties", {})
	var is_visible: bool = info.get("visible", true)

	if text.is_empty():
		text = ctrl_name

	var ctrl: Control = null

	match type:
		"Button":
			var btn = Button.new()
			btn.text = text
			ctrl = btn

		"Label":
			var lbl = Label.new()
			lbl.text = text
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ctrl = lbl

		"LineEdit":
			var le = LineEdit.new()
			le.text = text if text != ctrl_name else ""
			le.placeholder_text = ctrl_name
			ctrl = le

		"TextEdit":
			var te = TextEdit.new()
			te.text = text if text != ctrl_name else ""
			te.placeholder_text = ctrl_name
			ctrl = te

		"CheckBox":
			var cb = CheckBox.new()
			cb.text = text
			var checked = props.get("Checked", false)
			if checked is bool:
				cb.button_pressed = checked
			elif checked is String:
				cb.button_pressed = (checked.to_lower() == "true")
			ctrl = cb

		"OptionButton":
			var ob = OptionButton.new()
			# Add any list items from properties
			var items = props.get("ListItems", "")
			if items is String and not items.is_empty():
				for item_text in items.split("|"):
					ob.add_item(item_text.strip_edges())
			else:
				ob.add_item(text)
			ctrl = ob

		"ItemList":
			var il = ItemList.new()
			var items = props.get("ListItems", "")
			if items is String and not items.is_empty():
				for item_text in items.split("|"):
					il.add_item(item_text.strip_edges())
			ctrl = il

		"Panel":
			var pnl = Panel.new()
			ctrl = pnl

		"ProgressBar":
			var pb = ProgressBar.new()
			var val = props.get("Value", 0)
			if val is float or val is int:
				pb.value = val
			ctrl = pb

		"HScrollBar":
			var sb = HScrollBar.new()
			ctrl = sb

		"VScrollBar":
			var sb = VScrollBar.new()
			ctrl = sb

		"HSlider":
			var sl = HSlider.new()
			ctrl = sl

		"VSlider":
			var sl = VSlider.new()
			ctrl = sl

		"SpinBox":
			var sp = SpinBox.new()
			ctrl = sp

		"TextureRect":
			var tr = TextureRect.new()
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Try to load image from properties
			var img_path = props.get("Picture", "")
			if img_path is String and not img_path.is_empty() and ResourceLoader.exists(img_path):
				tr.texture = load(img_path)
			ctrl = tr

		"Tree":
			var tree = Tree.new()
			tree.create_item()  # root
			ctrl = tree

		"RichTextLabel":
			var rtl = RichTextLabel.new()
			rtl.text = text if text != ctrl_name else ""
			ctrl = rtl

		"TabContainer":
			var tc = TabContainer.new()
			# Add a default tab
			var tab_page = Control.new()
			tab_page.name = "Tab1"
			tc.add_child(tab_page)
			ctrl = tc

		"ColorRect":
			var cr = ColorRect.new()
			var shape_color = props.get("BackColor", Color(0.3, 0.3, 0.8))
			if shape_color is Color:
				cr.color = shape_color
			ctrl = cr

		"HSeparator":
			var sep = HSeparator.new()
			ctrl = sep

		"VSeparator":
			var sep = VSeparator.new()
			ctrl = sep

		"ColorPickerButton":
			var cpb = ColorPickerButton.new()
			ctrl = cpb

		"HBoxContainer":
			var hb = HBoxContainer.new()
			ctrl = hb

		"VBoxContainer":
			var vb = VBoxContainer.new()
			ctrl = vb

		"GridContainer":
			var gc = GridContainer.new()
			ctrl = gc

		"Timer":
			# Timers are invisible at runtime — skip visual
			return null

		_:
			# Fallback: generic panel with a label
			var pnl = PanelContainer.new()
			var lbl = Label.new()
			lbl.text = text
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pnl.add_child(lbl)
			ctrl = pnl

	if ctrl == null:
		return null

	# Position and size (absolute positioning via anchors)
	ctrl.name = ctrl_name
	ctrl.position = Vector2(x, y)
	ctrl.size = Vector2(w, h)
	ctrl.visible = is_visible

	# Apply common properties from the property bag
	_apply_common_props(ctrl, props, default_fore)

	return ctrl

func _apply_common_props(ctrl: Control, props: Dictionary, default_fore: Color) -> void:
	# ForeColor
	var fore = props.get("ForeColor", null)
	if fore is Color:
		if ctrl is Button or ctrl is Label or ctrl is CheckBox:
			ctrl.add_theme_color_override("font_color", fore)
		elif ctrl is LineEdit or ctrl is TextEdit:
			ctrl.add_theme_color_override("font_color", fore)
	
	# BackColor
	var back = props.get("BackColor", null)
	if back is Color:
		if ctrl is Panel:
			var sb = StyleBoxFlat.new()
			sb.bg_color = back
			ctrl.add_theme_stylebox_override("panel", sb)
	
	# Font size
	var fsize = props.get("FontSize", null)
	if fsize is int or fsize is float:
		ctrl.add_theme_font_size_override("font_size", int(fsize))
	
	# Enabled
	var enabled = props.get("Enabled", true)
	if enabled is bool:
		if ctrl.has_method("set_disabled"):
			ctrl.set("disabled", not enabled)
	
	# Tooltip
	var tip = props.get("ToolTipText", "")
	if tip is String and not tip.is_empty():
		ctrl.tooltip_text = tip
