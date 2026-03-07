@tool
extends Window
## VG Theme Picker + Editor — browse, preview, edit and create custom themes.
## Two tabs: "Browse" to select and preview, "Edit" to adjust every color.

signal vg_theme_changed(theme_name: String)

# ── Browse tab ──
var _theme_list: ItemList
var _preview_edit: CodeEdit
var _ide_preview: PanelContainer
var _desc_label: Label
var _current_theme_name: String = ""

# ── Edit tab ──
var _edit_scroll: ScrollContainer
var _edit_grid: GridContainer
var _name_edit: LineEdit
var _desc_edit: LineEdit
var _editing_theme: VGThemeManager.VGTheme = null
var _color_buttons: Dictionary = {}  # property_name -> ColorPickerButton
var _save_btn: Button
var _delete_btn: Button
var _edit_preview_edit: CodeEdit
var _edit_ide_preview: PanelContainer
var _tab_container: TabContainer

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
    Print $"Welcome, {playerName}! Level: {MAX_LEVEL}"
End Sub
"""

# Color property definitions: [property_name, display_label, category]
const COLOR_PROPS = [
	# Code Editor
	["background_color", "Background", "Code Editor"],
	["text_color", "Text", "Code Editor"],
	["line_number_color", "Line Numbers", "Code Editor"],
	["current_line_color", "Current Line", "Code Editor"],
	["selection_color", "Selection", "Code Editor"],
	["caret_color", "Caret", "Code Editor"],
	# Syntax
	["keyword_color", "Keywords", "Syntax"],
	["type_color", "Types", "Syntax"],
	["string_color", "Strings", "Syntax"],
	["number_color", "Numbers", "Syntax"],
	["comment_color", "Comments", "Syntax"],
	["operator_color", "Operators", "Syntax"],
	["function_color", "Functions", "Syntax"],
	["builtin_color", "Built-ins", "Syntax"],
	["variable_color", "Variables", "Syntax"],
	["constant_color", "Constants", "Syntax"],
	["property_color", "Properties", "Syntax"],
	["error_color", "Errors", "Syntax"],
	["warning_color", "Warnings", "Syntax"],
	# IDE Chrome
	["ide_panel_bg", "Panel Background", "IDE Chrome"],
	["ide_panel_border", "Panel Border", "IDE Chrome"],
	["ide_header_bg", "Header Background", "IDE Chrome"],
	["ide_header_border", "Header Border", "IDE Chrome"],
	["ide_header_text", "Header Text", "IDE Chrome"],
	["ide_text_color", "Text Color", "IDE Chrome"],
	["ide_list_bg", "List Background", "IDE Chrome"],
	["ide_tab_selected_bg", "Tab Selected", "IDE Chrome"],
	["ide_tab_unselected_bg", "Tab Unselected", "IDE Chrome"],
	["ide_tab_hover_bg", "Tab Hover", "IDE Chrome"],
	["ide_btn_hover_bg", "Button Hover", "IDE Chrome"],
	["ide_btn_pressed_bg", "Button Pressed", "IDE Chrome"],
	["ide_toolbox_btn_hover", "Toolbox Btn Hover", "IDE Chrome"],
	["ide_toolbox_btn_pressed", "Toolbox Btn Pressed", "IDE Chrome"],
	["ide_toolbox_text_pressed", "Toolbox Text Pressed", "IDE Chrome"],
	["ide_accent_color", "Accent Color", "IDE Chrome"],
	["ide_tooltip_bg", "Tooltip Background", "IDE Chrome"],
]

func _init():
	title = "VisualGasic Theme Picker"
	size = Vector2i(860, 640)
	min_size = Vector2i(640, 480)
	exclusive = false
	transient = true
	visible = false

func _ready():
	theme = _build_vb6_theme()
	
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(root)
	
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.tab_changed.connect(_on_tab_changed)
	root.add_child(_tab_container)
	
	# ── Tab 1: Browse ──
	var browse_tab = _build_browse_tab()
	browse_tab.name = "Browse"
	_tab_container.add_child(browse_tab)
	
	# ── Tab 2: Edit ──
	var edit_tab = _build_edit_tab()
	edit_tab.name = "Edit Theme"
	_tab_container.add_child(edit_tab)
	
	# Bottom: global buttons
	var sep = HSeparator.new()
	root.add_child(sep)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 28)
	close_btn.pressed.connect(hide)
	btn_row.add_child(close_btn)

	_populate_themes()
	close_requested.connect(hide)

# =============================================================================
# BROWSE TAB
# =============================================================================

func _build_browse_tab() -> Control:
	var vbox = VBoxContainer.new()
	
	var main_h = HSplitContainer.new()
	main_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_h.split_offset = 175
	vbox.add_child(main_h)

	# Left: Theme list + action buttons
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(170, 0)
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
	
	# Action buttons under list
	var list_btns = HBoxContainer.new()
	list_btns.add_theme_constant_override("separation", 4)
	left_panel.add_child(list_btns)
	
	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_btn.pressed.connect(_on_apply_pressed)
	list_btns.add_child(apply_btn)
	
	var new_btn = Button.new()
	new_btn.text = "New..."
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(_on_new_theme)
	list_btns.add_child(new_btn)
	
	var edit_btn = Button.new()
	edit_btn.text = "Edit"
	edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_btn.pressed.connect(_on_edit_theme)
	list_btns.add_child(edit_btn)

	# Right: Previews
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_h.add_child(right_panel)

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
	_preview_edit.custom_minimum_size = Vector2(0, 180)
	right_panel.add_child(_preview_edit)

	var ide_label = Label.new()
	ide_label.text = "IDE Preview"
	ide_label.add_theme_font_size_override("font_size", 13)
	right_panel.add_child(ide_label)

	_ide_preview = PanelContainer.new()
	_ide_preview.custom_minimum_size = Vector2(0, 100)
	right_panel.add_child(_ide_preview)
	
	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	right_panel.add_child(_desc_label)
	
	return vbox

# =============================================================================
# EDIT TAB
# =============================================================================

func _build_edit_tab() -> Control:
	var main_h = HSplitContainer.new()
	main_h.split_offset = 360
	
	# Left: color editor with scroll
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(340, 0)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_h.add_child(left_vbox)
	
	# Name and Description row
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	left_vbox.add_child(name_row)
	
	var name_lbl = Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size = Vector2(45, 0)
	name_row.add_child(name_lbl)
	
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "My Custom Theme"
	name_row.add_child(_name_edit)
	
	var desc_row = HBoxContainer.new()
	desc_row.add_theme_constant_override("separation", 4)
	left_vbox.add_child(desc_row)
	
	var desc_lbl = Label.new()
	desc_lbl.text = "Desc:"
	desc_lbl.custom_minimum_size = Vector2(45, 0)
	desc_row.add_child(desc_lbl)
	
	_desc_edit = LineEdit.new()
	_desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc_edit.placeholder_text = "A description for this theme"
	desc_row.add_child(_desc_edit)
	
	# Scrollable color grid
	_edit_scroll = ScrollContainer.new()
	_edit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(_edit_scroll)
	
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_scroll.add_child(scroll_vbox)
	
	# Build color picker rows organized by category
	var last_category = ""
	for prop in COLOR_PROPS:
		var prop_name = prop[0]
		var display_name = prop[1]
		var category = prop[2]
		
		# Category header
		if category != last_category:
			last_category = category
			var cat_label = Label.new()
			cat_label.text = "── " + category + " ──"
			cat_label.add_theme_font_size_override("font_size", 12)
			cat_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.5))
			scroll_vbox.add_child(cat_label)
		
		# Color picker row
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		scroll_vbox.add_child(row)
		
		var lbl = Label.new()
		lbl.text = display_name
		lbl.custom_minimum_size = Vector2(130, 0)
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)
		
		var cpb = ColorPickerButton.new()
		cpb.custom_minimum_size = Vector2(60, 22)
		cpb.edit_alpha = prop_name in ["selection_color", "current_line_color"]
		cpb.color = Color.WHITE
		cpb.color_changed.connect(_on_edit_color_changed.bind(prop_name))
		row.add_child(cpb)
		
		_color_buttons[prop_name] = cpb
	
	# Action buttons
	var edit_btn_row = HBoxContainer.new()
	edit_btn_row.add_theme_constant_override("separation", 6)
	left_vbox.add_child(edit_btn_row)
	
	_save_btn = Button.new()
	_save_btn.text = "Save Theme"
	_save_btn.custom_minimum_size = Vector2(100, 28)
	_save_btn.pressed.connect(_on_save_theme)
	edit_btn_row.add_child(_save_btn)
	
	var reset_btn = Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(70, 28)
	reset_btn.pressed.connect(_on_reset_editing)
	edit_btn_row.add_child(reset_btn)
	
	_delete_btn = Button.new()
	_delete_btn.text = "Delete"
	_delete_btn.custom_minimum_size = Vector2(70, 28)
	_delete_btn.pressed.connect(_on_delete_theme)
	edit_btn_row.add_child(_delete_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_btn_row.add_child(spacer)
	
	var apply_edit_btn = Button.new()
	apply_edit_btn.text = "Apply"
	apply_edit_btn.custom_minimum_size = Vector2(80, 28)
	apply_edit_btn.pressed.connect(_on_apply_editing_theme)
	edit_btn_row.add_child(apply_edit_btn)
	
	# Right: live preview
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_h.add_child(right_vbox)
	
	var ep_label = Label.new()
	ep_label.text = "Live Preview"
	ep_label.add_theme_font_size_override("font_size", 13)
	right_vbox.add_child(ep_label)
	
	_edit_preview_edit = CodeEdit.new()
	_edit_preview_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit_preview_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_preview_edit.editable = false
	_edit_preview_edit.text = PREVIEW_CODE
	_edit_preview_edit.gutters_draw_line_numbers = true
	_edit_preview_edit.set("line_folding_enabled", true)
	_edit_preview_edit.set("gutters_draw_folding", true)
	_edit_preview_edit.custom_minimum_size = Vector2(0, 180)
	right_vbox.add_child(_edit_preview_edit)
	
	var ei_label = Label.new()
	ei_label.text = "IDE Preview"
	ei_label.add_theme_font_size_override("font_size", 13)
	right_vbox.add_child(ei_label)
	
	_edit_ide_preview = PanelContainer.new()
	_edit_ide_preview.custom_minimum_size = Vector2(0, 100)
	right_vbox.add_child(_edit_ide_preview)
	
	return main_h

# =============================================================================
# BROWSE TAB LOGIC
# =============================================================================

func _populate_themes():
	_theme_list.clear()
	var names = VGThemeManager.get_theme_names()
	var current = VGThemeManager.get_current_theme()
	var current_name = current.name if current else "VB6 Classic"
	
	for i in range(names.size()):
		var theme_data = VGThemeManager.get_theme(names[i])
		var icon_text = "● " if names[i] == current_name else "  "
		_theme_list.add_item(icon_text + names[i])
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
	_populate_themes()

func _on_new_theme():
	# Create a copy of the current theme and switch to edit tab
	var base = VGThemeManager.get_theme(_current_theme_name)
	if not base:
		base = VGThemeManager.get_current_theme()
	_editing_theme = base.duplicate()
	_editing_theme.name = "My Custom Theme"
	_editing_theme.description = "Based on " + base.name
	_editing_theme.is_builtin = false
	_load_editing_theme()
	_tab_container.current_tab = 1  # Switch to Edit tab

func _on_edit_theme():
	# Load the selected theme into the editor
	var td = VGThemeManager.get_theme(_current_theme_name)
	if not td:
		return
	_editing_theme = td.duplicate()
	if td.is_builtin:
		# Can't overwrite builtins, so make it a copy
		_editing_theme.name = td.name + " (Custom)"
		_editing_theme.description = "Based on " + td.name
	else:
		# Editing existing custom theme — keep original name
		_editing_theme.name = td.name
	_editing_theme.is_builtin = false
	_load_editing_theme()
	_tab_container.current_tab = 1

func _on_tab_changed(tab: int):
	if tab == 1 and _editing_theme == null:
		# Auto-load current theme for editing
		_on_edit_theme()

# =============================================================================
# EDIT TAB LOGIC
# =============================================================================

func _load_editing_theme():
	if not _editing_theme:
		return
	
	_name_edit.text = _editing_theme.name
	_desc_edit.text = _editing_theme.description
	
	# Load all color values into color buttons
	for prop in COLOR_PROPS:
		var prop_name = prop[0]
		if _color_buttons.has(prop_name):
			_color_buttons[prop_name].color = _editing_theme.get(prop_name)
	
	# Update delete button state
	var existing = VGThemeManager.get_theme(_editing_theme.name)
	_delete_btn.disabled = (existing == null or existing.is_builtin)
	
	# Show live preview
	_update_edit_preview()

func _on_edit_color_changed(color: Color, prop_name: String):
	if not _editing_theme:
		return
	_editing_theme.set(prop_name, color)
	_update_edit_preview()

func _update_edit_preview():
	if not _editing_theme:
		return
	_apply_theme_to_code_edit(_edit_preview_edit, _editing_theme)
	_build_ide_preview_for(_edit_ide_preview, _editing_theme)

func _on_save_theme():
	if not _editing_theme:
		return
	
	var new_name = _name_edit.text.strip_edges()
	if new_name.is_empty():
		new_name = "Untitled Theme"
	
	_editing_theme.name = new_name
	_editing_theme.description = _desc_edit.text.strip_edges()
	_editing_theme.is_builtin = false
	
	# Check if overwriting a built-in
	var existing = VGThemeManager.get_theme(new_name)
	if existing and existing.is_builtin:
		# Can't overwrite builtin — append suffix
		_editing_theme.name = new_name + " (Custom)"
		_name_edit.text = _editing_theme.name
	
	VGThemeManager.add_custom_theme(_editing_theme)
	_populate_themes()
	
	# Select the saved theme in the list
	_select_theme_in_list(_editing_theme.name)
	
	# Update delete button
	_delete_btn.disabled = false
	
	print("VisualGasic: Saved custom theme '", _editing_theme.name, "'")

func _on_delete_theme():
	if not _editing_theme:
		return
	var tname = _editing_theme.name
	if VGThemeManager.remove_theme(tname):
		print("VisualGasic: Deleted custom theme '", tname, "'")
		_editing_theme = null
		_populate_themes()
		# Switch back to browse
		_tab_container.current_tab = 0

func _on_reset_editing():
	# Reset to the original theme data
	if not _editing_theme:
		return
	var original_name = _editing_theme.name.replace(" (Custom)", "")
	var base = VGThemeManager.get_theme(original_name)
	if not base:
		base = VGThemeManager.get_current_theme()
	_editing_theme = base.duplicate()
	if base.is_builtin:
		_editing_theme.name = base.name + " (Custom)"
	else:
		_editing_theme.name = base.name
	_editing_theme.is_builtin = false
	_load_editing_theme()

func _on_apply_editing_theme():
	# Save then apply in one step
	_on_save_theme()
	if _editing_theme:
		VGThemeManager.set_current_theme(_editing_theme.name)
		vg_theme_changed.emit(_editing_theme.name)
		_populate_themes()

func _select_theme_in_list(tname: String):
	for i in range(_theme_list.item_count):
		var item_text = _theme_list.get_item_text(i).strip_edges()
		if item_text.begins_with("● "):
			item_text = item_text.substr(2)
		if item_text == tname:
			_theme_list.select(i)
			_current_theme_name = tname
			break

# =============================================================================
# PREVIEW RENDERING (shared between Browse & Edit)
# =============================================================================

func _apply_theme_preview(theme_data):
	if not theme_data:
		return
	if _preview_edit:
		_apply_theme_to_code_edit(_preview_edit, theme_data)
	if _ide_preview:
		_build_ide_preview_for(_ide_preview, theme_data)
	if _desc_label:
		_desc_label.text = theme_data.description

func _apply_theme_to_code_edit(ce: CodeEdit, td):
	if not ce or not td:
		return
	
	ce.add_theme_color_override("background_color", td.background_color)
	ce.add_theme_color_override("font_color", td.text_color)
	ce.add_theme_color_override("caret_color", td.caret_color)
	ce.add_theme_color_override("selection_color", td.selection_color)
	ce.add_theme_color_override("current_line_color", td.current_line_color)
	ce.add_theme_color_override("line_number_color", td.line_number_color)
	
	var hl = CodeHighlighter.new()
	
	for kw in VGIntelliSense.VB6_KEYWORDS:
		hl.add_keyword_color(kw, td.keyword_color)
	for tp in VGIntelliSense.VB6_TYPES:
		hl.add_keyword_color(tp, td.type_color)
	for tp in VGIntelliSense.GODOT_TYPES:
		hl.add_keyword_color(tp, td.type_color)
	for func_info in VGIntelliSense.BUILTIN_FUNCTIONS:
		hl.add_keyword_color(func_info["name"], td.builtin_color)
	
	hl.add_color_region('"', '"', td.string_color)
	hl.add_color_region("'", "", td.comment_color, true)
	hl.number_color = td.number_color
	hl.symbol_color = td.operator_color
	hl.function_color = td.function_color
	hl.member_variable_color = td.property_color
	
	ce.syntax_highlighter = hl

func _build_ide_preview_for(container: PanelContainer, td):
	for c in container.get_children():
		c.queue_free()
	
	var container_sb = StyleBoxFlat.new()
	container_sb.bg_color = td.ide_panel_bg
	container_sb.border_color = td.ide_panel_border
	container_sb.set_border_width_all(1)
	container_sb.set_content_margin_all(4)
	container.add_theme_stylebox_override("panel", container_sb)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	container.add_child(vbox)
	
	# Header bar
	var header_panel = PanelContainer.new()
	var header_sb = StyleBoxFlat.new()
	header_sb.bg_color = td.ide_header_bg
	header_sb.border_color = td.ide_header_border
	header_sb.set_border_width_all(1)
	header_sb.content_margin_left = 6
	header_sb.content_margin_top = 2; header_sb.content_margin_bottom = 2
	header_panel.add_theme_stylebox_override("panel", header_sb)
	vbox.add_child(header_panel)
	
	var header_lbl = Label.new()
	header_lbl.text = "Toolbox"
	header_lbl.add_theme_color_override("font_color", td.ide_header_text)
	header_lbl.add_theme_font_size_override("font_size", 11)
	header_panel.add_child(header_lbl)
	
	# Tab row
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	vbox.add_child(tab_row)
	
	for tab_info in [["Properties", true], ["Explorer", false]]:
		var tab_btn = Button.new()
		tab_btn.text = tab_info[0]
		tab_btn.flat = true
		var tsb = StyleBoxFlat.new()
		tsb.bg_color = td.ide_tab_selected_bg if tab_info[1] else td.ide_tab_unselected_bg
		tsb.border_color = td.ide_panel_border
		tsb.set_border_width_all(1)
		if tab_info[1]:
			tsb.border_width_bottom = 0
		tsb.content_margin_left = 6; tsb.content_margin_right = 6
		tsb.content_margin_top = 2; tsb.content_margin_bottom = 2
		tab_btn.add_theme_stylebox_override("normal", tsb)
		tab_btn.add_theme_stylebox_override("hover", tsb)
		var fc = td.ide_text_color if tab_info[1] else td.ide_text_color.lerp(td.ide_panel_bg, 0.3)
		tab_btn.add_theme_color_override("font_color", fc)
		tab_btn.add_theme_font_size_override("font_size", 10)
		tab_row.add_child(tab_btn)
	
	tab_row.add_child(_make_spacer())
	
	# List area
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
	
	var items = ["  Form1  (Form)", "  Label1", "  Button1"]
	for i in range(items.size()):
		var item_lbl = Label.new()
		item_lbl.text = items[i]
		item_lbl.add_theme_font_size_override("font_size", 10)
		if i == 0:
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

func _make_spacer() -> Control:
	var s = Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

# =============================================================================
# DIALOG THEME
# =============================================================================

func _build_vb6_theme() -> Theme:
	var t = Theme.new()
	var bg = Color("#F0EDE8")
	var border = Color(0.72, 0.71, 0.68)
	var text_color = Color.BLACK

	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = bg
	win_sb.set_content_margin_all(4)
	t.set_stylebox("embedded_border", "Window", win_sb)

	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = bg
	panel_sb.border_color = border
	panel_sb.set_border_width_all(1)
	panel_sb.set_content_margin_all(2)
	t.set_stylebox("panel", "PanelContainer", panel_sb)

	t.set_color("font_color", "Label", text_color)
	t.set_font_size("font_size", "Label", 12)

	# TabContainer
	var tc_panel = StyleBoxFlat.new()
	tc_panel.bg_color = bg
	tc_panel.set_content_margin_all(4)
	t.set_stylebox("panel", "TabContainer", tc_panel)
	var tc_sel = StyleBoxFlat.new()
	tc_sel.bg_color = bg
	tc_sel.border_color = border
	tc_sel.border_width_left = 1; tc_sel.border_width_top = 1
	tc_sel.border_width_right = 1; tc_sel.border_width_bottom = 0
	tc_sel.content_margin_left = 10; tc_sel.content_margin_right = 10
	tc_sel.content_margin_top = 4; tc_sel.content_margin_bottom = 4
	t.set_stylebox("tab_selected", "TabContainer", tc_sel)
	var tc_unsel = StyleBoxFlat.new()
	tc_unsel.bg_color = Color(0.85, 0.84, 0.82)
	tc_unsel.border_color = border
	tc_unsel.set_border_width_all(1)
	tc_unsel.content_margin_left = 10; tc_unsel.content_margin_right = 10
	tc_unsel.content_margin_top = 4; tc_unsel.content_margin_bottom = 4
	t.set_stylebox("tab_unselected", "TabContainer", tc_unsel)
	var tc_hov = StyleBoxFlat.new()
	tc_hov.bg_color = Color(0.95, 0.94, 0.92)
	tc_hov.border_color = border
	tc_hov.set_border_width_all(1)
	tc_hov.content_margin_left = 10; tc_hov.content_margin_right = 10
	tc_hov.content_margin_top = 4; tc_hov.content_margin_bottom = 4
	t.set_stylebox("tab_hovered", "TabContainer", tc_hov)
	t.set_color("font_selected_color", "TabContainer", text_color)
	t.set_color("font_unselected_color", "TabContainer", Color(0.35, 0.35, 0.35))
	t.set_color("font_hovered_color", "TabContainer", text_color)

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

	# LineEdit
	var le_sb = StyleBoxFlat.new()
	le_sb.bg_color = Color.WHITE
	le_sb.border_color = border
	le_sb.set_border_width_all(1)
	le_sb.content_margin_left = 4; le_sb.content_margin_right = 4
	le_sb.content_margin_top = 2; le_sb.content_margin_bottom = 2
	t.set_stylebox("normal", "LineEdit", le_sb)
	t.set_color("font_color", "LineEdit", text_color)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.5, 0.5))

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
	var btn_dis = StyleBoxFlat.new()
	btn_dis.bg_color = Color(0.9, 0.89, 0.88)
	btn_dis.border_color = Color(0.8, 0.8, 0.8)
	btn_dis.set_border_width_all(1)
	btn_dis.content_margin_left = 8; btn_dis.content_margin_right = 8
	btn_dis.content_margin_top = 4; btn_dis.content_margin_bottom = 4
	t.set_stylebox("disabled", "Button", btn_dis)
	t.set_color("font_color", "Button", text_color)
	t.set_color("font_hover_color", "Button", text_color)
	t.set_color("font_pressed_color", "Button", text_color)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.6))

	# HSplitContainer
	var split_sb = StyleBoxFlat.new()
	split_sb.bg_color = bg
	t.set_stylebox("panel", "HSplitContainer", split_sb)

	# ScrollContainer
	var sc_sb = StyleBoxFlat.new()
	sc_sb.bg_color = bg
	t.set_stylebox("panel", "ScrollContainer", sc_sb)

	# HSeparator
	var hsep_sb = StyleBoxFlat.new()
	hsep_sb.bg_color = border
	hsep_sb.content_margin_top = 4
	hsep_sb.content_margin_bottom = 4
	t.set_stylebox("separator", "HSeparator", hsep_sb)

	return t
