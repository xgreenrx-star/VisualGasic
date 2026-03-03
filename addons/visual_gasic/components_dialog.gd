# components_dialog.gd
# VB6-style Components dialog for managing toolbox controls
# Allows users to enable/disable components and add custom controls
@tool
extends Window

signal components_changed

const CONFIG_PATH = "res://addons/visual_gasic/custom_components.cfg"

# VB6 theme palette (must match _theme dict in visual_gasic_plugin.gd)
const VB6_PANEL_BG       = Color(0.941, 0.929, 0.910)   # #F0EDE8  cream
const VB6_PANEL_BORDER   = Color(0.72, 0.71, 0.68)
const VB6_HEADER_BG      = Color(0.58, 0.58, 0.62)      # panel-header blue-gray
const VB6_HEADER_BORDER  = Color(0.4, 0.4, 0.4)
const VB6_HEADER_TEXT    = Color(1.0, 1.0, 1.0)
const VB6_TEXT           = Color(0.0, 0.0, 0.0)
const VB6_LIST_BG        = Color(1.0, 1.0, 1.0)
const VB6_BTN_HOVER_BG   = Color(0.95, 0.94, 0.92)
const VB6_BTN_PRESSED_BG = Color(0.88, 0.87, 0.85)
const VB6_ACTIVE_TITLE   = Color(0.0, 0.0, 0.5)         # selection blue

var component_list: ItemList
var add_btn: Button
var remove_btn: Button
var browse_btn: Button
var ok_btn: Button
var cancel_btn: Button
var apply_btn: Button

# All available components (built-in + custom)
var all_components: Array = []

# Built-in VB6-style components (optional ones from Components dialog)
var builtin_components: Array = [
	{"name": "VGComboBox", "scene": "res://addons/visual_gasic/prototypes/VGComboBox.tscn", "icon": "OptionButton", "class": "Control", "builtin": true, "enabled": true, "category": "2D"},
	{"name": "RadioButton", "scene": "res://addons/visual_gasic/prototypes/RadioButton.tscn", "icon": "CheckBox", "class": "CheckBox", "builtin": true, "enabled": true, "category": "2D"},
	{"name": "MenuBar", "scene": "res://addons/visual_gasic/prototypes/MenuBar.tscn", "icon": "PopupMenu", "class": "MenuBar", "builtin": true, "enabled": true, "category": "2D"},
	{"name": "PictureButton", "scene": "res://addons/visual_gasic/prototypes/TextureButton.tscn", "icon": "TextureButton", "class": "TextureButton", "builtin": true, "enabled": true, "category": "2D"},
	{"name": "Line", "scene": "res://addons/visual_gasic/prototypes/Line.tscn", "icon": "ColorRect", "class": "ColorRect", "builtin": true, "enabled": true, "category": "2D"},
	{"name": "DriveListBox", "scene": "res://addons/visual_gasic/prototypes/DriveListBox.tscn", "icon": "OptionButton", "class": "OptionButton", "builtin": true, "enabled": true, "category": "2D"},
	{"name": "StatusBar", "scene": "res://addons/visual_gasic/prototypes/StatusBar.tscn", "icon": "StatusIndicator", "class": "PanelContainer", "builtin": true, "enabled": false, "category": "2D"},
	{"name": "Toolbar", "scene": "res://addons/visual_gasic/prototypes/Toolbar.tscn", "icon": "ToolBar", "class": "PanelContainer", "builtin": true, "enabled": false, "category": "2D"},
	{"name": "Animation", "scene": "res://addons/visual_gasic/prototypes/Animation.tscn", "icon": "AnimatedSprite2D", "class": "AnimatedSprite2D", "builtin": true, "enabled": false, "category": "2D"},
	{"name": "Calendar", "scene": "res://addons/visual_gasic/prototypes/Calendar.tscn", "icon": "PopupMenu", "class": "PanelContainer", "builtin": true, "enabled": false, "category": "2D"},
	{"name": "DatePicker", "scene": "res://addons/visual_gasic/prototypes/DatePicker.tscn", "icon": "Time", "class": "HBoxContainer", "builtin": true, "enabled": false, "category": "2D"},
	{"name": "MaskedEdit", "scene": "res://addons/visual_gasic/prototypes/MaskedEdit.tscn", "icon": "LineEdit", "class": "LineEdit", "builtin": true, "enabled": false, "category": "2D"},
	{"name": "Winsock", "scene": "res://addons/visual_gasic/prototypes/Winsock.tscn", "icon": "HTTPRequest", "class": "HTTPRequest", "builtin": true, "enabled": false, "category": "2D"},
	{"name": "UpDown", "scene": "res://addons/visual_gasic/prototypes/UpDown.tscn", "icon": "SpinBox", "class": "SpinBox", "builtin": true, "enabled": false, "category": "2D"},
	{"name": "ListView", "scene": "res://addons/visual_gasic/prototypes/ListView.tscn", "icon": "ItemList", "class": "ItemList", "builtin": true, "enabled": false, "category": "2D"},
	{"name": "ImageCombo", "scene": "res://addons/visual_gasic/prototypes/ImageCombo.tscn", "icon": "OptionButton", "class": "OptionButton", "builtin": true, "enabled": false, "category": "2D"},
]

func _init():
	title = "Components"
	size = Vector2(450, 400)
	unresizable = false
	exclusive = true
	
func _ready():
	theme = _build_vb6_dialog_theme()
	_build_ui()
	_load_config()
	_populate_list()

## Builds a VB6-style Theme so the dialog matches the form designer panels.
func _build_vb6_dialog_theme() -> Theme:
	var t = Theme.new()

	# ── Window chrome  (embedded title-bar = header blue-gray, white title) ──
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = VB6_HEADER_BG
	win_sb.border_color = VB6_HEADER_BORDER
	win_sb.set_border_width_all(2)
	win_sb.content_margin_left = 4; win_sb.content_margin_right = 4
	win_sb.content_margin_top = 4; win_sb.content_margin_bottom = 4
	t.set_stylebox("embedded_border", "Window", win_sb)
	var win_unfocus = win_sb.duplicate()
	win_unfocus.bg_color = Color(0.50, 0.50, 0.50)
	t.set_stylebox("embedded_unfocused_border", "Window", win_unfocus)
	t.set_color("title_color", "Window", VB6_HEADER_TEXT)
	t.set_color("title_outline_modulate", "Window", Color.TRANSPARENT)

	# ── PanelContainer ──
	var pc_sb = StyleBoxFlat.new()
	pc_sb.bg_color = VB6_PANEL_BG
	pc_sb.border_color = VB6_PANEL_BORDER
	pc_sb.set_border_width_all(1)
	pc_sb.set_content_margin_all(2)
	t.set_stylebox("panel", "PanelContainer", pc_sb)

	# ── ItemList (white bg, black text, blue selection) ──
	var il_sb = StyleBoxFlat.new()
	il_sb.bg_color = VB6_LIST_BG
	il_sb.border_color = VB6_PANEL_BORDER
	il_sb.set_border_width_all(1)
	t.set_stylebox("panel", "ItemList", il_sb)
	t.set_color("font_color", "ItemList", VB6_TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	var il_sel = StyleBoxFlat.new()
	il_sel.bg_color = VB6_ACTIVE_TITLE
	t.set_stylebox("selected", "ItemList", il_sel)
	t.set_stylebox("selected_focus", "ItemList", il_sel)

	# ── Label ──
	t.set_color("font_color", "Label", VB6_TEXT)

	# ── Button (raised VB6 look) ──
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = VB6_PANEL_BG
	btn_sb.border_color = VB6_PANEL_BORDER
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 8; btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 3; btn_sb.content_margin_bottom = 3
	t.set_stylebox("normal", "Button", btn_sb)
	var btn_hov = StyleBoxFlat.new()
	btn_hov.bg_color = VB6_BTN_HOVER_BG
	btn_hov.border_color = VB6_PANEL_BORDER
	btn_hov.set_border_width_all(1)
	btn_hov.content_margin_left = 8; btn_hov.content_margin_right = 8
	btn_hov.content_margin_top = 3; btn_hov.content_margin_bottom = 3
	t.set_stylebox("hover", "Button", btn_hov)
	var btn_pre = StyleBoxFlat.new()
	btn_pre.bg_color = VB6_BTN_PRESSED_BG
	btn_pre.border_color = VB6_PANEL_BORDER
	btn_pre.set_border_width_all(1)
	btn_pre.content_margin_left = 8; btn_pre.content_margin_right = 8
	btn_pre.content_margin_top = 3; btn_pre.content_margin_bottom = 3
	t.set_stylebox("pressed", "Button", btn_pre)
	var btn_dis = StyleBoxFlat.new()
	btn_dis.bg_color = Color(0.90, 0.89, 0.87)
	btn_dis.border_color = VB6_PANEL_BORDER
	btn_dis.set_border_width_all(1)
	btn_dis.content_margin_left = 8; btn_dis.content_margin_right = 8
	btn_dis.content_margin_top = 3; btn_dis.content_margin_bottom = 3
	t.set_stylebox("disabled", "Button", btn_dis)
	t.set_color("font_color", "Button", VB6_TEXT)
	t.set_color("font_hover_color", "Button", VB6_TEXT)
	t.set_color("font_pressed_color", "Button", VB6_TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))

	# ── HSeparator ──
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = VB6_PANEL_BORDER
	sep_sb.content_margin_top = 4; sep_sb.content_margin_bottom = 4
	t.set_stylebox("separator", "HSeparator", sep_sb)

	return t

func _build_ui():
	# ── Cream content panel (covers the header-blue window background) ──
	var bg_panel = PanelContainer.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = VB6_PANEL_BG
	bg_sb.set_content_margin_all(10)
	bg_panel.add_theme_stylebox_override("panel", bg_sb)
	add_child(bg_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg_panel.add_child(main_vbox)

	# Header label
	var header = Label.new()
	header.text = "Available Components:"
	main_vbox.add_child(header)
	
	# List container with buttons on the side
	var list_hbox = HBoxContainer.new()
	list_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(list_hbox)
	
	# Component list with checkboxes
	component_list = ItemList.new()
	component_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	component_list.select_mode = ItemList.SELECT_SINGLE
	component_list.item_selected.connect(_on_item_selected)
	list_hbox.add_child(component_list)
	
	# Side buttons
	var side_vbox = VBoxContainer.new()
	side_vbox.custom_minimum_size.x = 100
	list_hbox.add_child(side_vbox)
	
	browse_btn = Button.new()
	browse_btn.text = "Browse..."
	browse_btn.pressed.connect(_on_browse)
	side_vbox.add_child(browse_btn)
	
	remove_btn = Button.new()
	remove_btn.text = "Remove"
	remove_btn.disabled = true
	remove_btn.pressed.connect(_on_remove)
	side_vbox.add_child(remove_btn)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(spacer)
	
	# Info label
	var info_label = Label.new()
	info_label.text = "✓ = Added to Toolbox\nDouble-click to toggle"
	info_label.add_theme_font_size_override("font_size", 11)
	side_vbox.add_child(info_label)
	
	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)
	
	# Bottom buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(btn_hbox)
	
	ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size.x = 80
	ok_btn.pressed.connect(_on_ok)
	btn_hbox.add_child(ok_btn)
	
	cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size.x = 80
	cancel_btn.pressed.connect(_on_cancel)
	btn_hbox.add_child(cancel_btn)
	
	apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size.x = 80
	apply_btn.pressed.connect(_on_apply)
	btn_hbox.add_child(apply_btn)
	
	# Connect double-click to toggle
	component_list.item_activated.connect(_on_item_activated)
	
	# Close button handling
	close_requested.connect(_on_cancel)

func _load_config():
	all_components = builtin_components.duplicate(true)
	
	# Load custom components from config
	if FileAccess.file_exists(CONFIG_PATH):
		var config = ConfigFile.new()
		if config.load(CONFIG_PATH) == OK:
			# Load enabled states for built-in components
			for comp in all_components:
				var key = comp["name"]
				if config.has_section_key("enabled", key):
					comp["enabled"] = config.get_value("enabled", key, false)
			
			# Load custom components
			if config.has_section("custom"):
				for key in config.get_section_keys("custom"):
					var data = config.get_value("custom", key)
					if data is Dictionary:
						data["builtin"] = false
						all_components.append(data)

func _save_config():
	var config = ConfigFile.new()
	
	# Save enabled states for built-in components
	for comp in all_components:
		if comp.get("builtin", false):
			config.set_value("enabled", comp["name"], comp["enabled"])
		else:
			# Save custom components
			var data = comp.duplicate()
			data.erase("builtin")
			config.set_value("custom", comp["name"], data)
	
	config.save(CONFIG_PATH)

func _populate_list():
	component_list.clear()
	
	for i in range(all_components.size()):
		var comp = all_components[i]
		var display_name = comp["name"]
		if comp.get("builtin", false):
			display_name += " (Built-in)"
		else:
			display_name += " (Custom)"
		
		component_list.add_item(display_name)
		
		# Show checkmark if enabled
		if comp.get("enabled", false):
			component_list.set_item_text(i, "✓ " + display_name)
		
		# Try to load icon
		var icon_name = comp.get("icon", "")
		if not icon_name.is_empty():
			var icon = _get_editor_icon(icon_name)
			if icon:
				component_list.set_item_icon(i, icon)

func _get_editor_icon(icon_name: String) -> Texture2D:
	if Engine.is_editor_hint():
		var base = EditorInterface.get_base_control()
		if base:
			return base.get_theme_icon(icon_name, "EditorIcons")
	return null

func _on_item_selected(index: int):
	var comp = all_components[index]
	# Only allow removing custom components
	remove_btn.disabled = comp.get("builtin", false)

func _on_item_activated(index: int):
	# Toggle enabled state
	all_components[index]["enabled"] = not all_components[index].get("enabled", false)
	_populate_list()

func _on_browse():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.tscn ; Scene Files"]
	file_dialog.title = "Select Custom Component Scene"
	file_dialog.size = Vector2(600, 400)
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	file_dialog.popup_centered()

func _on_file_selected(path: String):
	# Extract component name from filename
	var name = path.get_file().get_basename()
	
	# Check if already exists
	for comp in all_components:
		if comp["name"] == name or comp["scene"] == path:
			push_warning("Component already exists: " + name)
			return
	
	# Prompt for display name
	var name_dialog = AcceptDialog.new()
	name_dialog.title = "Add Custom Component"
	name_dialog.dialog_text = "Component Name:"
	name_dialog.ok_button_text = "Add"
	
	var name_edit = LineEdit.new()
	name_edit.text = name
	name_edit.custom_minimum_size.x = 200
	name_dialog.add_child(name_edit)
	
	name_dialog.confirmed.connect(func():
		var comp_name = name_edit.text.strip_edges()
		if comp_name.is_empty():
			comp_name = name
		
		# Add to list
		all_components.append({
			"name": comp_name,
			"scene": path,
			"icon": "Control",
			"class": "Control",
			"builtin": false,
			"enabled": true,
			"category": "2D"
		})
		_populate_list()
		name_dialog.queue_free()
	)
	
	name_dialog.canceled.connect(func():
		name_dialog.queue_free()
	)
	
	add_child(name_dialog)
	name_dialog.popup_centered()

func _on_remove():
	var selected = component_list.get_selected_items()
	if selected.is_empty():
		return
	
	var index = selected[0]
	var comp = all_components[index]
	
	# Don't allow removing built-in components
	if comp.get("builtin", false):
		return
	
	all_components.remove_at(index)
	_populate_list()

func _on_ok():
	_save_config()
	components_changed.emit()
	hide()
	queue_free()

func _on_cancel():
	hide()
	queue_free()

func _on_apply():
	_save_config()
	components_changed.emit()

## Returns list of enabled components for the toolbox
func get_enabled_components() -> Array:
	var enabled = []
	for comp in all_components:
		if comp.get("enabled", false):
			enabled.append(comp)
	return enabled

## Static method to load enabled components from config
static func load_enabled_components() -> Array:
	var enabled = []
	
	if FileAccess.file_exists(CONFIG_PATH):
		var config = ConfigFile.new()
		if config.load(CONFIG_PATH) == OK:
			# Check built-in components
			var builtins = [
				{"name": "VGComboBox", "scene": "res://addons/visual_gasic/prototypes/VGComboBox.tscn", "icon": "OptionButton", "class": "Control", "category": "2D"},
				{"name": "RadioButton", "scene": "res://addons/visual_gasic/prototypes/RadioButton.tscn", "icon": "CheckBox", "class": "CheckBox", "category": "2D"},
				{"name": "MenuBar", "scene": "res://addons/visual_gasic/prototypes/MenuBar.tscn", "icon": "PopupMenu", "class": "MenuBar", "category": "2D"},
				{"name": "PictureButton", "scene": "res://addons/visual_gasic/prototypes/TextureButton.tscn", "icon": "TextureButton", "class": "TextureButton", "category": "2D"},
				{"name": "Line", "scene": "res://addons/visual_gasic/prototypes/Line.tscn", "icon": "ColorRect", "class": "ColorRect", "category": "2D"},
				{"name": "DriveListBox", "scene": "res://addons/visual_gasic/prototypes/DriveListBox.tscn", "icon": "OptionButton", "class": "OptionButton", "category": "2D"},
				{"name": "StatusBar", "scene": "res://addons/visual_gasic/prototypes/StatusBar.tscn", "icon": "StatusIndicator", "class": "PanelContainer", "category": "2D"},
				{"name": "Toolbar", "scene": "res://addons/visual_gasic/prototypes/Toolbar.tscn", "icon": "ToolBar", "class": "PanelContainer", "category": "2D"},
				{"name": "Animation", "scene": "res://addons/visual_gasic/prototypes/Animation.tscn", "icon": "AnimatedSprite2D", "class": "AnimatedSprite2D", "category": "2D"},
				{"name": "Calendar", "scene": "res://addons/visual_gasic/prototypes/Calendar.tscn", "icon": "PopupMenu", "class": "PanelContainer", "category": "2D"},
				{"name": "DatePicker", "scene": "res://addons/visual_gasic/prototypes/DatePicker.tscn", "icon": "Time", "class": "HBoxContainer", "category": "2D"},
				{"name": "MaskedEdit", "scene": "res://addons/visual_gasic/prototypes/MaskedEdit.tscn", "icon": "LineEdit", "class": "LineEdit", "category": "2D"},
				{"name": "Winsock", "scene": "res://addons/visual_gasic/prototypes/Winsock.tscn", "icon": "HTTPRequest", "class": "HTTPRequest", "category": "2D"},
				{"name": "UpDown", "scene": "res://addons/visual_gasic/prototypes/UpDown.tscn", "icon": "SpinBox", "class": "SpinBox", "category": "2D"},
				{"name": "ListView", "scene": "res://addons/visual_gasic/prototypes/ListView.tscn", "icon": "ItemList", "class": "ItemList", "category": "2D"},
				{"name": "ImageCombo", "scene": "res://addons/visual_gasic/prototypes/ImageCombo.tscn", "icon": "OptionButton", "class": "OptionButton", "category": "2D"},
			]
			
			for comp in builtins:
				if config.get_value("enabled", comp["name"], false):
					enabled.append(comp)
			
			# Load custom components
			if config.has_section("custom"):
				for key in config.get_section_keys("custom"):
					var data = config.get_value("custom", key)
					if data is Dictionary and data.get("enabled", false):
						enabled.append(data)
	
	return enabled
