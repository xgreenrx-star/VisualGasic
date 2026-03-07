@tool
extends Window
## VG Theme Picker — Visual dialog for selecting and previewing editor + IDE themes.
## Shows a live preview of both the code editor colors and IDE chrome for each theme.

signal vg_theme_changed(theme_name: String)

var _theme_list: ItemList
var _preview_edit: CodeEdit
var _ide_preview: PanelContainer
var _apply_btn: Button
var _current_theme_name: String = ""
var _desc_label: Label

const PREVIEW_CODE = """' VisualGasic Theme Preview
Dim score As Integer = 0
Dim playerName As String = "Hero"
Const MAX_LEVEL As Integer = 50

Class Enemy
    Inherits Entity
    Public health As Single = 100.0
    
    Sub Attack(target As Variant)
        Dim damage As Integer = Int(health * 0.1)
        target.TakeDamage damage
        Print "Enemy attacks for " & Str(damage)
    End Sub
    
    Property Get IsAlive() As Boolean
        IsAlive = (health > 0)
    End Property
End Class

Sub _Ready()
    ' Initialize game
    score = 0
    Dim Dist As Variant = Lambda(x, y) Sqr(x*x + y*y)
    
    Whenever ScoreHigh
        When score > 1000
        Call CelebrationEffect
    End Whenever
    
    Print $"Welcome, {playerName}! Max level: {MAX_LEVEL}"
End Sub
"""

func _init():
	title = "VisualGasic Theme Picker"
	size = Vector2i(780, 560)
	min_size = Vector2i(580, 420)
	exclusive = false
	transient = true
	visible = false

func _ready():
	theme = _build_vb6_theme()
	
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(root)
	
	# Top: main content
	var main_h = HSplitContainer.new()
	main_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_h.split_offset = 180
	root.add_child(main_h)

	# Left: Theme list
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(175, 0)
	main_h.add_child(left_panel)

	var list_label = Label.new()
	list_label.text = "Themes"
	list_label.add_theme_font_size_override("font_size", 14)
	left_panel.add_child(list_label)

	_theme_list = ItemList.new()
	_theme_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_theme_list.item_selected.connect(_on_theme_selected)
	_theme_list.item_activated.connect(_on_theme_activated)
	left_panel.add_child(_theme_list)

	# Right: Previews stacked vertically
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_h.add_child(right_panel)

	# Code preview section
	var code_label = Label.new()
	code_label.text = "Code Preview"
	code_label.add_theme_font_size_override("font_size", 13)
	right_panel.add_child(code_label)

	_preview_edit = CodeEdit.new()
	_preview_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_edit.editable = false
	_preview_edit.text = PREVIEW_CODE
	_preview_edit.gutters_draw_line_numbers = true
	_preview_edit.set("line_folding_enabled", true)
	_preview_edit.set("gutters_draw_folding", true)
	_preview_edit.custom_minimum_size = Vector2(0, 200)
	right_panel.add_child(_preview_edit)

	# IDE chrome preview section
	var ide_label = Label.new()
	ide_label.text = "IDE Preview"
	ide_label.add_theme_font_size_override("font_size", 13)
	right_panel.add_child(ide_label)

	_ide_preview = PanelContainer.new()
	_ide_preview.custom_minimum_size = Vector2(0, 110)
	right_panel.add_child(_ide_preview)
	
	# Description
	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	right_panel.add_child(_desc_label)

	# Bottom: button row
	var sep = HSeparator.new()
	root.add_child(sep)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)
	
	_apply_btn = Button.new()
	_apply_btn.text = "Apply Theme"
	_apply_btn.custom_minimum_size = Vector2(120, 28)
	_apply_btn.pressed.connect(_on_apply_pressed)
	btn_row.add_child(_apply_btn)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 28)
	close_btn.pressed.connect(hide)
	btn_row.add_child(close_btn)

	# Populate
	_populate_themes()
	close_requested.connect(hide)

func _populate_themes():
	_theme_list.clear()
	var names = VGThemeManager.get_theme_names()
	var current = VGThemeManager.get_current_theme()
	var current_name = current.name if current else "VB6 Classic"
	
	for i in range(names.size()):
		var theme_data = VGThemeManager.get_theme(names[i])
		var icon_text = "● " if names[i] == current_name else "  "
		_theme_list.add_item(icon_text + names[i])
		# Color-code the item with the theme's background color
		if theme_data:
			_theme_list.set_item_custom_bg_color(i, theme_data.background_color.lerp(Color(0.2, 0.2, 0.25), 0.5))
			_theme_list.set_item_custom_fg_color(i, theme_data.text_color)
		
		if names[i] == current_name:
			_theme_list.select(i)
			_current_theme_name = names[i]
			_apply_theme_preview(theme_data)

func _on_theme_selected(index: int):
	var tname = _theme_list.get_item_text(index).strip_edges()
	if tname.begins_with("● "):
		tname = tname.substr(2)
	_current_theme_name = tname
	var theme_data = VGThemeManager.get_theme(tname)
	if theme_data:
		_apply_theme_preview(theme_data)

func _on_theme_activated(index: int):
	_on_apply_pressed()

func _on_apply_pressed():
	if _current_theme_name.is_empty():
		return
	VGThemeManager.set_current_theme(_current_theme_name)
	vg_theme_changed.emit(_current_theme_name)
	_populate_themes()  # Refresh indicators

func _apply_theme_preview(theme_data):
	if not theme_data or not _preview_edit:
		return
	
	# ── Code editor preview ──
	_preview_edit.add_theme_color_override("background_color", theme_data.background_color)
	_preview_edit.add_theme_color_override("font_color", theme_data.text_color)
	_preview_edit.add_theme_color_override("caret_color", theme_data.caret_color)
	_preview_edit.add_theme_color_override("selection_color", theme_data.selection_color)
	_preview_edit.add_theme_color_override("current_line_color", theme_data.current_line_color)
	_preview_edit.add_theme_color_override("line_number_color", theme_data.line_number_color)
	
	# Build a CodeHighlighter with this theme's syntax colors
	var hl = CodeHighlighter.new()
	
	# Keywords
	for kw in VGIntelliSense.VB6_KEYWORDS:
		hl.add_keyword_color(kw, theme_data.keyword_color)
	
	# Types
	for tp in VGIntelliSense.VB6_TYPES:
		hl.add_keyword_color(tp, theme_data.type_color)
	for tp in VGIntelliSense.GODOT_TYPES:
		hl.add_keyword_color(tp, theme_data.type_color)
	
	# Built-in functions
	for func_info in VGIntelliSense.BUILTIN_FUNCTIONS:
		hl.add_keyword_color(func_info["name"], theme_data.builtin_color)
	
	# Strings
	hl.add_color_region('"', '"', theme_data.string_color)
	
	# Comments
	hl.add_color_region("'", "", theme_data.comment_color, true)
	
	# Other token colors
	hl.number_color = theme_data.number_color
	hl.symbol_color = theme_data.operator_color
	hl.function_color = theme_data.function_color
	hl.member_variable_color = theme_data.property_color
	
	_preview_edit.syntax_highlighter = hl
	
	# ── IDE chrome preview ──
	_build_ide_preview(theme_data)
	
	# ── Description ──
	if _desc_label:
		_desc_label.text = theme_data.description

## Builds a mini IDE chrome preview showing header, tabs, and list
func _build_ide_preview(td):
	# Remove old children
	for c in _ide_preview.get_children():
		c.queue_free()
	
	# Style the container itself
	var container_sb = StyleBoxFlat.new()
	container_sb.bg_color = td.ide_panel_bg
	container_sb.border_color = td.ide_panel_border
	container_sb.set_border_width_all(1)
	container_sb.set_content_margin_all(4)
	_ide_preview.add_theme_stylebox_override("panel", container_sb)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_ide_preview.add_child(vbox)
	
	# ── Header bar ──
	var header_panel = PanelContainer.new()
	var header_sb = StyleBoxFlat.new()
	header_sb.bg_color = td.ide_header_bg
	header_sb.border_color = td.ide_header_border
	header_sb.set_border_width_all(1)
	header_sb.content_margin_left = 6
	header_sb.content_margin_top = 2
	header_sb.content_margin_bottom = 2
	header_panel.add_theme_stylebox_override("panel", header_sb)
	vbox.add_child(header_panel)
	
	var header_lbl = Label.new()
	header_lbl.text = "Toolbox"
	header_lbl.add_theme_color_override("font_color", td.ide_header_text)
	header_lbl.add_theme_font_size_override("font_size", 11)
	header_panel.add_child(header_lbl)
	
	# ── Tab bar row ──
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	vbox.add_child(tab_row)
	
	# Selected tab
	var tab_sel = Button.new()
	tab_sel.text = "Properties"
	tab_sel.flat = true
	var tsb = StyleBoxFlat.new()
	tsb.bg_color = td.ide_tab_selected_bg
	tsb.border_color = td.ide_panel_border
	tsb.set_border_width_all(1)
	tsb.border_width_bottom = 0
	tsb.content_margin_left = 6; tsb.content_margin_right = 6
	tsb.content_margin_top = 2; tsb.content_margin_bottom = 2
	tab_sel.add_theme_stylebox_override("normal", tsb)
	tab_sel.add_theme_stylebox_override("hover", tsb)
	tab_sel.add_theme_color_override("font_color", td.ide_text_color)
	tab_sel.add_theme_font_size_override("font_size", 10)
	tab_row.add_child(tab_sel)
	
	# Unselected tab
	var tab_unsel = Button.new()
	tab_unsel.text = "Explorer"
	tab_unsel.flat = true
	var tusb = StyleBoxFlat.new()
	tusb.bg_color = td.ide_tab_unselected_bg
	tusb.border_color = td.ide_panel_border
	tusb.set_border_width_all(1)
	tusb.content_margin_left = 6; tusb.content_margin_right = 6
	tusb.content_margin_top = 2; tusb.content_margin_bottom = 2
	tab_unsel.add_theme_stylebox_override("normal", tusb)
	tab_unsel.add_theme_stylebox_override("hover", tusb)
	tab_unsel.add_theme_color_override("font_color", td.ide_text_color.lerp(td.ide_panel_bg, 0.3))
	tab_unsel.add_theme_font_size_override("font_size", 10)
	tab_row.add_child(tab_unsel)
	
	# Spacer to fill tab bar with panel bg
	var tab_spacer = Control.new()
	tab_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(tab_spacer)
	
	# ── List area ──
	var list_panel = PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list_sb = StyleBoxFlat.new()
	list_sb.bg_color = td.ide_list_bg
	list_sb.border_color = td.ide_panel_border
	list_sb.set_border_width_all(1)
	list_sb.set_content_margin_all(4)
	list_panel.add_theme_stylebox_override("panel", list_sb)
	vbox.add_child(list_panel)
	
	var list_vbox = VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 1)
	list_panel.add_child(list_vbox)
	
	# Items in list
	var items = ["  Form1  (Form)", "  Label1", "  Button1"]
	for i in range(items.size()):
		var item_lbl = Label.new()
		item_lbl.text = items[i]
		item_lbl.add_theme_font_size_override("font_size", 10)
		if i == 0:
			# Simulate selected item
			item_lbl.add_theme_color_override("font_color", Color.WHITE if td.ide_accent_color.get_luminance() < 0.5 else Color.BLACK)
			var sel_panel = PanelContainer.new()
			var sel_sb = StyleBoxFlat.new()
			sel_sb.bg_color = td.ide_accent_color
			sel_sb.set_content_margin_all(1)
			sel_panel.add_theme_stylebox_override("panel", sel_sb)
			sel_panel.add_child(item_lbl)
			list_vbox.add_child(sel_panel)
		else:
			item_lbl.add_theme_color_override("font_color", td.ide_text_color)
			list_vbox.add_child(item_lbl)

# =============================================================================
# DIALOG THEME
# =============================================================================

func _build_vb6_theme() -> Theme:
	var t = Theme.new()
	var bg = Color("#F0EDE8")
	var border = Color(0.72, 0.71, 0.68)
	var text_color = Color.BLACK

	# Window
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = bg
	win_sb.set_content_margin_all(4)
	t.set_stylebox("embedded_border", "Window", win_sb)

	# Panel
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = bg
	panel_sb.border_color = border
	panel_sb.set_border_width_all(1)
	panel_sb.set_content_margin_all(2)
	t.set_stylebox("panel", "PanelContainer", panel_sb)

	# Labels
	t.set_color("font_color", "Label", text_color)
	t.set_font_size("font_size", "Label", 12)

	# ItemList
	var il_sb = StyleBoxFlat.new()
	il_sb.bg_color = Color.WHITE
	il_sb.border_color = border
	il_sb.set_border_width_all(1)
	t.set_stylebox("panel", "ItemList", il_sb)
	t.set_color("font_color", "ItemList", text_color)
	var il_sel = StyleBoxFlat.new()
	il_sel.bg_color = Color(0.0, 0.0, 0.5)
	il_sel.set_content_margin_all(2)
	t.set_stylebox("selected", "ItemList", il_sel)
	t.set_stylebox("selected_focus", "ItemList", il_sel)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)

	# CodeEdit
	var ce_sb = StyleBoxFlat.new()
	ce_sb.bg_color = Color.WHITE
	ce_sb.border_color = border
	ce_sb.set_border_width_all(1)
	t.set_stylebox("normal", "CodeEdit", ce_sb)
	t.set_color("font_color", "CodeEdit", text_color)

	# Button
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = Color("#D4D0C8")
	btn_sb.border_color = border
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 8; btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 4; btn_sb.content_margin_bottom = 4
	t.set_stylebox("normal", "Button", btn_sb)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.88, 0.87, 0.85)
	btn_hover.border_color = Color(0.5, 0.5, 0.5)
	btn_hover.set_border_width_all(1)
	btn_hover.content_margin_left = 8; btn_hover.content_margin_right = 8
	btn_hover.content_margin_top = 4; btn_hover.content_margin_bottom = 4
	t.set_stylebox("hover", "Button", btn_hover)
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.78, 0.77, 0.75)
	btn_pressed.border_color = Color(0.4, 0.4, 0.4)
	btn_pressed.set_border_width_all(1)
	btn_pressed.content_margin_left = 8; btn_pressed.content_margin_right = 8
	btn_pressed.content_margin_top = 4; btn_pressed.content_margin_bottom = 4
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_color("font_color", "Button", text_color)
	t.set_color("font_hover_color", "Button", text_color)
	t.set_color("font_pressed_color", "Button", text_color)

	# HSplitContainer
	var split_sb = StyleBoxFlat.new()
	split_sb.bg_color = bg
	t.set_stylebox("panel", "HSplitContainer", split_sb)

	# HSeparator
	var hsep_sb = StyleBoxFlat.new()
	hsep_sb.bg_color = border
	hsep_sb.content_margin_top = 4
	hsep_sb.content_margin_bottom = 4
	t.set_stylebox("separator", "HSeparator", hsep_sb)

	# ScrollBar
	t.set_color("font_color", "HScrollBar", text_color)
	t.set_color("font_color", "VScrollBar", text_color)

	return t
