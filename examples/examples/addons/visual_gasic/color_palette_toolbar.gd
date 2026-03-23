@tool
extends HBoxContainer
## VB6-style Color Palette Toolbar
##
## Provides a horizontal bar of clickable color swatches for quickly setting
## ForeColor and BackColor on controls, similar to VB6's color palette at
## the bottom of the Properties window.
##
## Usage: Left-click a color → sets ForeColor. Right-click → sets BackColor.

var editor_plugin: EditorPlugin

# VB6's default 16-color palette (matches VB6 IDE exactly)
const VB6_COLORS: Array = [
	Color(0, 0, 0),           # Black
	Color(0.5, 0, 0),         # Maroon
	Color(0, 0.5, 0),         # Green
	Color(0.5, 0.5, 0),       # Olive
	Color(0, 0, 0.5),         # Navy
	Color(0.5, 0, 0.5),       # Purple
	Color(0, 0.5, 0.5),       # Teal
	Color(0.75, 0.75, 0.75),  # Silver
	Color(0.5, 0.5, 0.5),     # Gray
	Color(1, 0, 0),           # Red
	Color(0, 1, 0),           # Lime
	Color(1, 1, 0),           # Yellow
	Color(0, 0, 1),           # Blue
	Color(1, 0, 1),           # Fuchsia
	Color(0, 1, 1),           # Aqua
	Color(1, 1, 1),           # White
]

# Extended palette (extra row, like VB6's full palette)
const VB6_EXTENDED: Array = [
	Color(1.0, 0.75, 0.8),    # Pink
	Color(1.0, 0.65, 0.0),    # Orange
	Color(0.56, 0.93, 0.56),  # Light Green
	Color(0.53, 0.81, 0.98),  # Light Blue
	Color(0.87, 0.63, 0.87),  # Plum
	Color(0.96, 0.87, 0.70),  # Wheat
	Color(0.82, 0.41, 0.12),  # Chocolate
	Color(0.0, 0.39, 0.0),    # Dark Green
	Color(0.10, 0.10, 0.44),  # Midnight Blue
	Color(0.60, 0.20, 0.20),  # Brown
	Color(0.86, 0.86, 0.86),  # Gainsboro
	Color(0.94, 0.90, 0.55),  # Khaki
	Color(0.25, 0.25, 0.25),  # Dark Gray
	Color(0.0, 0.5, 1.0),     # Dodger Blue
	Color(0.72, 0.53, 0.04),  # Dark Goldenrod
	Color(0.93, 0.93, 0.93),  # White Smoke
]

var _fore_preview: ColorRect
var _back_preview: ColorRect
var _current_forecolor: Color = Color.BLACK
var _current_backcolor: Color = Color.WHITE
var _palette_popup: PopupPanel
var _dropdown_btn: Button
var _color_picker_win: Window
var _color_picker: ColorPicker

func _init():
	name = "VG Color Palette"
	custom_minimum_size = Vector2(0, 26)

	# ── Fore / Back color preview — overlapping squares (classic VB6 style) ──
	var preview_container = Control.new()
	preview_container.custom_minimum_size = Vector2(28, 22)

	_back_preview = ColorRect.new()
	_back_preview.color = _current_backcolor
	_back_preview.position = Vector2(8, 6)
	_back_preview.size = Vector2(14, 14)
	_back_preview.tooltip_text = "BackColor"
	preview_container.add_child(_back_preview)

	_fore_preview = ColorRect.new()
	_fore_preview.color = _current_forecolor
	_fore_preview.position = Vector2(0, 0)
	_fore_preview.size = Vector2(14, 14)
	_fore_preview.tooltip_text = "ForeColor"
	preview_container.add_child(_fore_preview)

	add_child(preview_container)

	# ── Dropdown button to open the full palette popup ──
	_dropdown_btn = Button.new()
	_dropdown_btn.text = "▼"
	_dropdown_btn.tooltip_text = "Color Palette — Left=ForeColor  Right=BackColor"
	_dropdown_btn.custom_minimum_size = Vector2(20, 22)
	_dropdown_btn.pressed.connect(_toggle_palette_popup)
	add_child(_dropdown_btn)

	# ── Build the popup (hidden until user clicks ▼) ──
	_palette_popup = PopupPanel.new()
	_palette_popup.transparent_bg = false

	var popup_vbox = VBoxContainer.new()
	popup_vbox.add_theme_constant_override("separation", 4)

	# Palette grid — 16 columns × 2 rows
	var palette_grid = GridContainer.new()
	palette_grid.columns = 16
	palette_grid.add_theme_constant_override("h_separation", 1)
	palette_grid.add_theme_constant_override("v_separation", 1)

	for color in VB6_COLORS:
		palette_grid.add_child(_create_swatch(color))
	for color in VB6_EXTENDED:
		palette_grid.add_child(_create_swatch(color))

	popup_vbox.add_child(palette_grid)

	# Custom color button inside the popup
	var custom_btn = Button.new()
	custom_btn.text = "Custom Color..."
	custom_btn.tooltip_text = "Open full color picker"
	custom_btn.custom_minimum_size = Vector2(0, 24)
	custom_btn.pressed.connect(_on_custom_color)
	popup_vbox.add_child(custom_btn)

	_palette_popup.add_child(popup_vbox)
	add_child(_palette_popup)

	# ── Persistent Color-Picker window (shown by "Custom Color..." button) ──
	_color_picker_win = Window.new()
	_color_picker_win.title = "Custom Color"
	_color_picker_win.size = Vector2i(380, 440)
	_color_picker_win.transient = true
	_color_picker_win.exclusive = true
	_color_picker_win.visible = false
	_color_picker_win.wrap_controls = true
	_color_picker_win.close_requested.connect(func(): _color_picker_win.hide())

	var cp_margin = MarginContainer.new()
	cp_margin.anchor_right = 1.0
	cp_margin.anchor_bottom = 1.0
	cp_margin.add_theme_constant_override("margin_left", 8)
	cp_margin.add_theme_constant_override("margin_right", 8)
	cp_margin.add_theme_constant_override("margin_top", 8)
	cp_margin.add_theme_constant_override("margin_bottom", 8)

	var cp_vbox = VBoxContainer.new()
	cp_vbox.add_theme_constant_override("separation", 8)

	_color_picker = ColorPicker.new()
	_color_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cp_vbox.add_child(_color_picker)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)

	var ok_btn = Button.new()
	ok_btn.text = "OK — Set ForeColor"
	ok_btn.custom_minimum_size = Vector2(130, 28)
	ok_btn.pressed.connect(func():
		_apply_forecolor(_color_picker.color)
		_color_picker_win.hide()
	)
	btn_row.add_child(ok_btn)

	var back_btn = Button.new()
	back_btn.text = "Set BackColor"
	back_btn.custom_minimum_size = Vector2(110, 28)
	back_btn.pressed.connect(func():
		_apply_backcolor(_color_picker.color)
		_color_picker_win.hide()
	)
	btn_row.add_child(back_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 28)
	cancel_btn.pressed.connect(func(): _color_picker_win.hide())
	btn_row.add_child(cancel_btn)

	cp_vbox.add_child(btn_row)
	cp_margin.add_child(cp_vbox)
	_color_picker_win.add_child(cp_margin)
	add_child(_color_picker_win)

func _toggle_palette_popup():
	if _palette_popup.visible:
		_palette_popup.hide()
		return
	# Position just below the dropdown button
	var btn_rect = _dropdown_btn.get_global_rect()
	_palette_popup.popup(Rect2i(
		Vector2i(int(btn_rect.position.x), int(btn_rect.position.y + btn_rect.size.y + 2)),
		Vector2i(0, 0)  # auto-size
	))

func _create_swatch(color: Color) -> Button:
	"""Create a clickable color swatch for the popup palette."""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(16, 16)
	btn.size = Vector2(16, 16)
	# NOTE: Do NOT set btn.flat = true — flat buttons skip drawing the
	# "normal" StyleBox, so the color wouldn't be visible at rest.
	btn.tooltip_text = "Left=ForeColor  Right=BackColor\n#" + color.to_html(false).to_upper()

	# Override every button state so the swatch color is always visible
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb = StyleBoxFlat.new()
		sb.set_content_margin_all(0)
		sb.set_border_width_all(1)
		if state_name == "hover":
			sb.bg_color = color.lightened(0.2)
			sb.border_color = Color.WHITE
		elif state_name == "pressed":
			sb.bg_color = color.darkened(0.2)
			sb.border_color = Color.WHITE
		elif state_name == "focus":
			sb.bg_color = color
			sb.border_color = Color.WHITE
		else:
			sb.bg_color = color
			sb.border_color = Color(0.3, 0.3, 0.3, 0.5)
		btn.add_theme_stylebox_override(state_name, sb)
	
	# Left click = ForeColor, Right click = BackColor
	btn.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_apply_forecolor(color)
				_palette_popup.hide()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_apply_backcolor(color)
				_palette_popup.hide()
	)
	
	return btn

func setup(plugin: EditorPlugin):
	editor_plugin = plugin

func _apply_forecolor(color: Color):
	_current_forecolor = color
	_fore_preview.color = color
	
	var node = _get_selected_control()
	if node and node is Control:
		node.set_meta("vb_forecolor", color)
		node.add_theme_color_override("font_color", color)
		if node is BaseButton:
			node.add_theme_color_override("font_hover_color", color)
			node.add_theme_color_override("font_pressed_color", color)
		print("VisualGasic: ForeColor → #", color.to_html(false).to_upper(), " on ", node.name)

func _apply_backcolor(color: Color):
	_current_backcolor = color
	_back_preview.color = color
	
	var node = _get_selected_control()
	if node and node is Control:
		node.set_meta("vb_backcolor", color)
		var style = StyleBoxFlat.new()
		style.bg_color = color
		if node is BaseButton:
			style.set_corner_radius_all(3)
			style.set_border_width_all(1)
			style.border_color = color.darkened(0.2)
			style.set_content_margin_all(4)
		elif node is LineEdit:
			style.set_border_width_all(1)
			style.border_color = Color(0.3, 0.3, 0.3)
			style.content_margin_left = 4
			style.content_margin_right = 4
		node.add_theme_stylebox_override("normal", style)
		print("VisualGasic: BackColor → #", color.to_html(false).to_upper(), " on ", node.name)

func _get_selected_control() -> Node:
	if not editor_plugin or not is_instance_valid(editor_plugin):
		return null
	var sel = editor_plugin.get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() == 1:
		return sel[0]
	return null

func _on_custom_color():
	"""Open a full ColorPicker dialog."""
	_palette_popup.hide()
	_color_picker.color = _current_forecolor
	_color_picker_win.popup_centered()
