@tool
extends Window
## VG Theme Picker — Visual dialog for selecting and previewing editor themes.
## Shows a live preview of each theme's color scheme.

const VGThemeManager = preload("res://addons/visual_gasic/vg_theme_manager.gd")

signal vg_theme_changed(theme_name: String)

var _theme_list: ItemList
var _preview_edit: TextEdit
var _apply_btn: Button
var _current_theme_name: String = ""

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
	size = Vector2i(680, 480)
	min_size = Vector2i(480, 360)
	exclusive = false
	transient = true

func _ready():
	var root = HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(root)

	# Left: Theme list
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(180, 0)
	root.add_child(left_panel)

	var list_label = Label.new()
	list_label.text = "Themes"
	list_label.add_theme_font_size_override("font_size", 15)
	left_panel.add_child(list_label)

	_theme_list = ItemList.new()
	_theme_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_theme_list.item_selected.connect(_on_theme_selected)
	_theme_list.item_activated.connect(_on_theme_activated)
	left_panel.add_child(_theme_list)

	_apply_btn = Button.new()
	_apply_btn.text = "Apply Theme"
	_apply_btn.pressed.connect(_on_apply_pressed)
	left_panel.add_child(_apply_btn)

	# Right: Preview
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right_panel)

	var preview_label = Label.new()
	preview_label.text = "Preview"
	preview_label.add_theme_font_size_override("font_size", 15)
	right_panel.add_child(preview_label)

	_preview_edit = TextEdit.new()
	_preview_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_edit.editable = false
	_preview_edit.text = PREVIEW_CODE
	right_panel.add_child(_preview_edit)

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
	var name = _theme_list.get_item_text(index).strip_edges()
	if name.begins_with("● "):
		name = name.substr(2)
	_current_theme_name = name
	var theme_data = VGThemeManager.get_theme(name)
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
	
	_preview_edit.add_theme_color_override("background_color", theme_data.background_color)
	_preview_edit.add_theme_color_override("font_color", theme_data.text_color)
	_preview_edit.add_theme_color_override("caret_color", theme_data.caret_color)
	_preview_edit.add_theme_color_override("selection_color", theme_data.selection_color)
	_preview_edit.add_theme_color_override("current_line_color", theme_data.current_line_color)
	_preview_edit.add_theme_color_override("line_number_color", theme_data.line_number_color)
