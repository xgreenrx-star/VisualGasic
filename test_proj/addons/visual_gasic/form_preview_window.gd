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

	# ── Apply VB6 Classic Theme so all child controls look correct ──
	var FormEditorHelper = load("res://addons/visual_gasic/form_editor_helper.gd")
	if FormEditorHelper:
		var vb6_theme = FormEditorHelper._build_vb6_classic_theme()
		if vb6_theme:
			self.theme = vb6_theme

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
	var scene_path: String = info.get("scene_path", "")

	if text.is_empty():
		text = ctrl_name

	var ctrl: Control = null

	# --- Custom control: if it has a custom scene_path, instantiate that scene ---
	if not scene_path.is_empty() and not scene_path.begins_with("res://addons/visual_gasic/prototypes/") and not scene_path.begins_with("res://custom_widgets/") and ResourceLoader.exists(scene_path):
		var scene_res = load(scene_path)
		if scene_res is PackedScene:
			var instance = scene_res.instantiate()
			if instance is Control:
				ctrl = instance
				ctrl.name = ctrl_name
				ctrl.position = Vector2(x, y)
				ctrl.size = Vector2(w, h)
				ctrl.visible = is_visible
				_apply_common_props(ctrl, props, default_fore)
				return ctrl
			else:
				instance.queue_free()

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
			rtl.bbcode_enabled = bool(props.get("BbcodeEnabled", true))
			rtl.scroll_active = bool(props.get("ScrollActive", true))
			rtl.selection_enabled = bool(props.get("SelectionEnabled", false))
			rtl.fit_content = bool(props.get("FitContent", false))
			if props.get("WordWrap", true):
				rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			else:
				rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
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

		"TextureButton":
			var tb = TextureButton.new()
			tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			ctrl = tb

		"MenuBar":
			var mb = MenuBar.new()
			# Add default File/Edit menus
			var file_popup = PopupMenu.new()
			file_popup.name = "File"
			file_popup.add_item("New")
			file_popup.add_item("Open")
			file_popup.add_separator()
			file_popup.add_item("Exit")
			mb.add_child(file_popup)
			var edit_popup = PopupMenu.new()
			edit_popup.name = "Edit"
			edit_popup.add_item("Cut")
			edit_popup.add_item("Copy")
			edit_popup.add_item("Paste")
			mb.add_child(edit_popup)
			ctrl = mb

		"RadioButton":
			var rb = CheckBox.new()
			rb.text = text
			ctrl = rb

		"Line":
			var line = ColorRect.new()
			line.color = Color.BLACK
			ctrl = line

		"DriveListBox":
			var dlb = OptionButton.new()
			# Populate with system drives
			dlb.add_item("C:\\")
			dlb.add_item("D:\\")
			ctrl = dlb

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
			# Custom control — try loading its .tscn scene for a live preview
			if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
				var scene_res = load(scene_path)
				if scene_res is PackedScene:
					var instance = scene_res.instantiate()
					if instance is Control:
						ctrl = instance
					else:
						# Scene root is not a Control — wrap it
						instance.queue_free()
						var pnl = PanelContainer.new()
						var lbl = Label.new()
						lbl.text = text
						lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						pnl.add_child(lbl)
						ctrl = pnl
			if ctrl == null:
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
		elif ctrl is RichTextLabel:
			ctrl.add_theme_color_override("default_color", fore)
	
	# BackColor
	var back = props.get("BackColor", null)
	if back is Color:
		if ctrl is Panel:
			var sb = StyleBoxFlat.new()
			sb.bg_color = back
			ctrl.add_theme_stylebox_override("panel", sb)
		elif ctrl is LineEdit:
			var sb = StyleBoxFlat.new()
			sb.bg_color = back
			sb.set_content_margin_all(4)
			ctrl.add_theme_stylebox_override("normal", sb)
		elif ctrl is TextEdit:
			var sb = StyleBoxFlat.new()
			sb.bg_color = back
			sb.set_content_margin_all(4)
			ctrl.add_theme_stylebox_override("normal", sb)
		elif ctrl is RichTextLabel:
			var sb = StyleBoxFlat.new()
			sb.bg_color = back
			sb.set_content_margin_all(4)
			ctrl.add_theme_stylebox_override("normal", sb)
	
	# Font size — convert VB6 points to Godot pixels (same formula as C++ canvas)
	var fsize = props.get("FontSize", null)
	if fsize is int or fsize is float:
		var godot_px := maxi(8, roundi(float(fsize) * 1.5))
		if godot_px != 12:  # Only override when != VB6 default (8pt → 12px)
			ctrl.add_theme_font_size_override("font_size", godot_px)
	
	# Enabled
	var enabled = props.get("Enabled", true)
	if enabled is bool:
		if ctrl.has_method("set_disabled"):
			ctrl.set("disabled", not enabled)
	
	# Tooltip
	var tip = props.get("ToolTipText", "")
	if tip is String and not tip.is_empty():
		ctrl.tooltip_text = tip

	# --- New properties ---

	# Opacity (0-100 → modulate alpha 0.0-1.0)
	var opacity = props.get("Opacity", null)
	if opacity is int or opacity is float:
		ctrl.modulate.a = clampf(float(opacity) / 100.0, 0.0, 1.0)

	# Rotation (degrees)
	var rotation_deg = props.get("Rotation", null)
	if rotation_deg is int or rotation_deg is float:
		ctrl.rotation = deg_to_rad(float(rotation_deg))

	# ScaleX / ScaleY
	var sx = props.get("ScaleX", null)
	var sy = props.get("ScaleY", null)
	if sx is float or sx is int or sy is float or sy is int:
		var scale_x: float = float(sx) if (sx is float or sx is int) else 1.0
		var scale_y: float = float(sy) if (sy is float or sy is int) else 1.0
		ctrl.scale = Vector2(scale_x, scale_y)
		# Set pivot to center for intuitive rotation/scale
		ctrl.pivot_offset = ctrl.size * 0.5

	# ClipContents
	var clip = props.get("ClipContents", null)
	if clip is bool:
		ctrl.clip_contents = clip

	# MinWidth / MinHeight
	var min_w = props.get("MinWidth", null)
	var min_h = props.get("MinHeight", null)
	if (min_w is int or min_w is float) or (min_h is int or min_h is float):
		var mw: float = float(min_w) if (min_w is int or min_w is float) else 0.0
		var mh: float = float(min_h) if (min_h is int or min_h is float) else 0.0
		ctrl.custom_minimum_size = Vector2(mw, mh)

	# Flat (Button)
	var flat = props.get("Flat", null)
	if flat is bool and ctrl is Button:
		ctrl.flat = flat

	# Icon (Button) — load texture from path
	var icon_path = props.get("Icon", null)
	if icon_path is String and not icon_path.is_empty() and ctrl is Button:
		if ResourceLoader.exists(icon_path):
			ctrl.icon = load(icon_path)

	# IconAlignment (Button)
	var icon_align = props.get("IconAlignment", null)
	if (icon_align is int) and ctrl is Button:
		ctrl.icon_alignment = icon_align  # 0=Left, 1=Center, 2=Right

	# VerticalAlignment (Label)
	var valign = props.get("VerticalAlignment", null)
	if (valign is int) and ctrl is Label:
		ctrl.vertical_alignment = valign  # 0=Top, 1=Center, 2=Bottom

	# MaxLinesVisible (Label)
	var max_lines = props.get("MaxLinesVisible", null)
	if (max_lines is int) and ctrl is Label:
		ctrl.max_lines_visible = max_lines

	# ClearButton (LineEdit)
	var clear_btn = props.get("ClearButton", null)
	if clear_btn is bool and ctrl is LineEdit:
		ctrl.clear_button_enabled = clear_btn

	# SelectAllOnFocus (LineEdit)
	var select_all = props.get("SelectAllOnFocus", null)
	if select_all is bool and ctrl is LineEdit:
		ctrl.select_all_on_focus = select_all

	# Editable (TextEdit)
	var editable = props.get("Editable", null)
	if editable is bool and ctrl is TextEdit:
		ctrl.editable = editable

	# ShowPercentage (ProgressBar)
	var show_pct = props.get("ShowPercentage", null)
	if show_pct is bool and ctrl is ProgressBar:
		ctrl.show_percentage = show_pct

	# FillMode (ProgressBar)
	var fill_mode = props.get("FillMode", null)
	if (fill_mode is int) and ctrl is ProgressBar:
		ctrl.fill_mode = fill_mode

	# StretchMode (TextureRect)
	var stretch_mode = props.get("StretchMode", null)
	if (stretch_mode is int) and ctrl is TextureRect:
		ctrl.stretch_mode = stretch_mode

	# FlipH / FlipV (TextureRect)
	var flip_h = props.get("FlipH", null)
	if flip_h is bool and ctrl is TextureRect:
		ctrl.flip_h = flip_h
	var flip_v = props.get("FlipV", null)
	if flip_v is bool and ctrl is TextureRect:
		ctrl.flip_v = flip_v

	# ShapeColor (ColorRect)
	var shape_color = props.get("ShapeColor", null)
	if shape_color is Color and ctrl is ColorRect:
		ctrl.color = shape_color

	# MaxColumns / FixedColumnWidth / IconMode (ItemList)
	if ctrl is ItemList:
		var max_cols = props.get("MaxColumns", null)
		if max_cols is int:
			ctrl.max_columns = max_cols
		var fixed_col_w = props.get("FixedColumnWidth", null)
		if fixed_col_w is int:
			ctrl.fixed_column_width = fixed_col_w
		var icon_mode_val = props.get("IconMode", null)
		if icon_mode_val is int:
			ctrl.icon_mode = icon_mode_val

	# HideRoot / HideFolding (Tree)
	if ctrl is Tree:
		var hide_root = props.get("HideRoot", null)
		if hide_root is bool:
			ctrl.hide_root = hide_root
		var hide_fold = props.get("HideFolding", null)
		if hide_fold is bool:
			ctrl.hide_folding = hide_fold

	# Prefix / Suffix / Wrap (SpinBox)
	if ctrl is SpinBox:
		var prefix = props.get("Prefix", null)
		if prefix is String:
			ctrl.prefix = prefix
		var suffix = props.get("Suffix", null)
		if suffix is String:
			ctrl.suffix = suffix
		var wrap = props.get("Wrap", null)
		if wrap is bool:
			ctrl.allow_greater = not wrap
			ctrl.allow_lesser = not wrap

	# ListItems (OptionButton) — pipe-separated
	var list_items_str = props.get("ListItems", null)
	if list_items_str is String and not list_items_str.is_empty():
		if ctrl is OptionButton:
			ctrl.clear()
			for item_text in list_items_str.split("|"):
				ctrl.add_item(item_text.strip_edges())
