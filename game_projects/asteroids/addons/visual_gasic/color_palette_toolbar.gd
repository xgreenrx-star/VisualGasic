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

func _init():
	name = "VG Color Palette"
	custom_minimum_size = Vector2(0, 28)
	
	# Fore/Back color preview squares (overlapping, like VB6)
	var preview_container = Control.new()
	preview_container.custom_minimum_size = Vector2(36, 24)
	
	_back_preview = ColorRect.new()
	_back_preview.color = _current_backcolor
	_back_preview.position = Vector2(8, 4)
	_back_preview.size = Vector2(16, 16)
	_back_preview.tooltip_text = "BackColor"
	preview_container.add_child(_back_preview)
	
	_fore_preview = ColorRect.new()
	_fore_preview.color = _current_forecolor
	_fore_preview.position = Vector2(0, 0)
	_fore_preview.size = Vector2(16, 16)
	_fore_preview.tooltip_text = "ForeColor"
	preview_container.add_child(_fore_preview)
	
	add_child(preview_container)
	
	# Separator
	var sep = VSeparator.new()
	add_child(sep)
	
	# Palette grid (2 rows × 16 columns)
	var palette_grid = GridContainer.new()
	palette_grid.columns = 16
	
	# Row 1: Standard VB6 colors
	for color in VB6_COLORS:
		var swatch = _create_swatch(color)
		palette_grid.add_child(swatch)
	
	# Row 2: Extended colors
	for color in VB6_EXTENDED:
		var swatch = _create_swatch(color)
		palette_grid.add_child(swatch)
	
	add_child(palette_grid)
	
	# Custom color picker button
	var sep2 = VSeparator.new()
	add_child(sep2)
	
	var custom_btn = Button.new()
	custom_btn.text = "..."
	custom_btn.tooltip_text = "Custom Color"
	custom_btn.custom_minimum_size = Vector2(24, 24)
	custom_btn.pressed.connect(_on_custom_color)
	add_child(custom_btn)

func _create_swatch(color: Color) -> Button:
	"""Create a tiny clickable color swatch."""
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(14, 10)
	btn.size = Vector2(14, 10)
	btn.flat = true
	btn.tooltip_text = "Left=ForeColor  Right=BackColor\n#" + color.to_html(false).to_upper()
	
	# Use a StyleBoxFlat for the button's normal state
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	style.set_content_margin_all(0)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.15)
	hover_style.set_border_width_all(1)
	hover_style.border_color = Color.WHITE
	hover_style.set_content_margin_all(0)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = color.darkened(0.15)
	pressed_style.set_border_width_all(1)
	pressed_style.border_color = Color.WHITE
	pressed_style.set_content_margin_all(0)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	# Left click = ForeColor, Right click = BackColor
	btn.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_apply_forecolor(color)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_apply_backcolor(color)
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
	var dialog = ColorPicker.new()
	var popup = PopupPanel.new()
	popup.add_child(dialog)
	
	dialog.color = _current_forecolor
	dialog.color_changed.connect(func(c):
		_apply_forecolor(c)
	)
	
	if editor_plugin and is_instance_valid(editor_plugin):
		editor_plugin.get_editor_interface().get_base_control().add_child(popup)
		popup.popup_centered(Vector2(350, 380))
