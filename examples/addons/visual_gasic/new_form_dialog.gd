@tool
extends AcceptDialog
## New Form Dialog with Extended Templates
##
## Provides form templates organized by category:
## - VB6 Classic: Traditional VB6 form types
## - Game Forms: Common game UI templates
## - Platform: OS-specific styling (macOS, Linux, Windows)
## - Custom: User-defined templates saved as .vgtemplate.json

# =============================================================================
# CONSTANTS & ENUMS
# =============================================================================

const CUSTOM_TEMPLATE_DIR_USER = "user://form_templates/"
const CUSTOM_TEMPLATE_DIR_PROJECT = "res://form_templates/"

enum Category {
	VB6_CLASSIC,
	GAME_FORMS,
	PLATFORM,
	CUSTOM
}

# =============================================================================
# STATE VARIABLES
# =============================================================================

var selected_template: Dictionary = {}
var form_templates: Dictionary = {}  # category -> Array of templates
var custom_templates: Array = []
var _tab_container: TabContainer
var _description_label: RichTextLabel
var _template_lists: Dictionary = {}  # category -> ItemList

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready():
	title = "New Form"
	size = Vector2(600, 550)
	ok_button_text = "Create"
	
	_setup_ui()
	_init_all_templates()
	_load_custom_templates()
	_populate_lists()

# =============================================================================
# UI SETUP
# =============================================================================

func _setup_ui():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Title label
	var lbl_title = Label.new()
	lbl_title.text = "Select a form template:"
	lbl_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_title)
	
	# Tab container for categories
	_tab_container = TabContainer.new()
	_tab_container.custom_minimum_size = Vector2(0, 280)
	_tab_container.tab_changed.connect(_on_tab_changed)
	vbox.add_child(_tab_container)
	
	# Create tabs for each category
	var categories = [
		["VB6 Classic", Category.VB6_CLASSIC],
		["Game Forms", Category.GAME_FORMS],
		["Platform", Category.PLATFORM],
		["Custom", Category.CUSTOM]
	]
	
	for cat_data in categories:
		var cat_name = cat_data[0]
		var cat_id = cat_data[1]
		
		var cat_vbox = VBoxContainer.new()
		cat_vbox.name = cat_name
		_tab_container.add_child(cat_vbox)
		
		var list = ItemList.new()
		list.name = "List"
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.item_selected.connect(_on_item_selected.bind(cat_id))
		cat_vbox.add_child(list)
		_template_lists[cat_id] = list
		
		# Add "Save Current Form as Template" button to Custom tab
		if cat_id == Category.CUSTOM:
			var btn_hbox = HBoxContainer.new()
			btn_hbox.add_theme_constant_override("separation", 10)
			cat_vbox.add_child(btn_hbox)
			
			var btn_save = Button.new()
			btn_save.text = "Save Current Form as Template..."
			btn_save.pressed.connect(_on_save_template_pressed)
			btn_hbox.add_child(btn_save)
			
			var btn_delete = Button.new()
			btn_delete.text = "Delete Selected"
			btn_delete.pressed.connect(_on_delete_template_pressed)
			btn_hbox.add_child(btn_delete)
			
			var btn_refresh = Button.new()
			btn_refresh.text = "Refresh"
			btn_refresh.pressed.connect(_refresh_custom_templates)
			btn_hbox.add_child(btn_refresh)
	
	# Description section
	var lbl_desc_title = Label.new()
	lbl_desc_title.text = "Description:"
	lbl_desc_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_desc_title)
	
	_description_label = RichTextLabel.new()
	_description_label.custom_minimum_size = Vector2(0, 100)
	_description_label.bbcode_enabled = true
	_description_label.scroll_active = false
	_description_label.fit_content = true
	vbox.add_child(_description_label)

# =============================================================================
# TEMPLATE DEFINITIONS
# =============================================================================

func _init_all_templates():
	_init_vb6_classic_templates()
	_init_game_templates()
	_init_platform_templates()

func _init_vb6_classic_templates():
	form_templates[Category.VB6_CLASSIC] = [
		{
			"name": "Blank Form",
			"description": "[b]Blank Form[/b]\nA simple empty form with no controls. Perfect for creating custom layouts from scratch.",
			"size": Vector2(400, 300),
			"controls": [],
			"code": _get_blank_code()
		},
		{
			"name": "Dialog Form",
			"description": "[b]Dialog Form[/b]\nA form pre-configured with OK and Cancel buttons at the bottom right. Ideal for simple input dialogs and confirmations.",
			"size": Vector2(400, 200),
			"controls": [
				{"type": "Button", "name": "btnOK", "text": "OK", "position": Vector2(220, 150), "size": Vector2(80, 30)},
				{"type": "Button", "name": "btnCancel", "text": "Cancel", "position": Vector2(310, 150), "size": Vector2(80, 30)}
			],
			"code": _get_dialog_code()
		},
		{
			"name": "About Box",
			"description": "[b]About Box[/b]\nA standard About dialog with placeholders for application name, version, copyright, and description.",
			"size": Vector2(400, 250),
			"controls": [
				{"type": "Label", "name": "lblAppName", "text": "Application Name", "position": Vector2(20, 20), "size": Vector2(360, 30)},
				{"type": "Label", "name": "lblVersion", "text": "Version 1.0", "position": Vector2(20, 55), "size": Vector2(360, 20)},
				{"type": "Label", "name": "lblCopyright", "text": "Copyright © 2026", "position": Vector2(20, 80), "size": Vector2(360, 20)},
				{"type": "Label", "name": "lblDescription", "text": "Description of your application", "position": Vector2(20, 110), "size": Vector2(360, 80)},
				{"type": "Button", "name": "btnOK", "text": "OK", "position": Vector2(160, 200), "size": Vector2(80, 30)}
			],
			"code": _get_about_code()
		},
		{
			"name": "Splash Screen",
			"description": "[b]Splash Screen[/b]\nA borderless form designed for application startup screens. Typically shows a logo and loading message.",
			"size": Vector2(500, 300),
			"borderless": true,
			"controls": [
				{"type": "Label", "name": "lblTitle", "text": "Application Title", "position": Vector2(150, 100), "size": Vector2(200, 40)},
				{"type": "Label", "name": "lblLoading", "text": "Loading...", "position": Vector2(200, 250), "size": Vector2(100, 20)}
			],
			"code": _get_splash_code()
		},
		{
			"name": "Login Form",
			"description": "[b]Login Form[/b]\nA form with username and password text boxes, and Login/Cancel buttons. Ready for authentication logic.",
			"size": Vector2(350, 200),
			"controls": [
				{"type": "Label", "name": "lblUsername", "text": "Username:", "position": Vector2(20, 30), "size": Vector2(80, 20)},
				{"type": "LineEdit", "name": "txtUsername", "text": "", "position": Vector2(110, 28), "size": Vector2(200, 25)},
				{"type": "Label", "name": "lblPassword", "text": "Password:", "position": Vector2(20, 70), "size": Vector2(80, 20)},
				{"type": "LineEdit", "name": "txtPassword", "text": "", "position": Vector2(110, 68), "size": Vector2(200, 25)},
				{"type": "Button", "name": "btnLogin", "text": "Login", "position": Vector2(140, 140), "size": Vector2(90, 30)},
				{"type": "Button", "name": "btnCancel", "text": "Cancel", "position": Vector2(240, 140), "size": Vector2(90, 30)}
			],
			"code": _get_login_code()
		},
		{
			"name": "Main Form with Menu",
			"description": "[b]Main Form with Menu[/b]\nA form with a menu bar pre-configured with File and Help menus, including common menu items.",
			"size": Vector2(600, 400),
			"has_menu": true,
			"controls": [],
			"code": _get_main_menu_code()
		},
		{
			"name": "Data Entry Form",
			"description": "[b]Data Entry Form[/b]\nA form with common data entry controls laid out in a grid: labels, text boxes, and navigation buttons.",
			"size": Vector2(500, 400),
			"controls": [
				{"type": "Label", "name": "lblName", "text": "Name:", "position": Vector2(20, 30), "size": Vector2(100, 20)},
				{"type": "LineEdit", "name": "txtName", "text": "", "position": Vector2(130, 28), "size": Vector2(300, 25)},
				{"type": "Label", "name": "lblAddress", "text": "Address:", "position": Vector2(20, 70), "size": Vector2(100, 20)},
				{"type": "LineEdit", "name": "txtAddress", "text": "", "position": Vector2(130, 68), "size": Vector2(300, 25)},
				{"type": "Button", "name": "btnFirst", "text": "|<", "position": Vector2(20, 330), "size": Vector2(60, 30)},
				{"type": "Button", "name": "btnPrevious", "text": "<", "position": Vector2(90, 330), "size": Vector2(60, 30)},
				{"type": "Button", "name": "btnNext", "text": ">", "position": Vector2(160, 330), "size": Vector2(60, 30)},
				{"type": "Button", "name": "btnLast", "text": ">|", "position": Vector2(230, 330), "size": Vector2(60, 30)},
				{"type": "Button", "name": "btnSave", "text": "Save", "position": Vector2(350, 330), "size": Vector2(80, 30)}
			],
			"code": _get_data_entry_code()
		},
		{
			"name": "MDI Parent Form",
			"description": "[b]MDI Parent Form[/b]\nA Multiple Document Interface parent form that can contain multiple child forms.",
			"size": Vector2(800, 600),
			"is_mdi_parent": true,
			"has_menu": true,
			"controls": [],
			"code": _get_mdi_parent_code()
		},
		{
			"name": "MDI Child Form",
			"description": "[b]MDI Child Form[/b]\nA child form designed to be displayed within an MDI parent.",
			"size": Vector2(400, 300),
			"is_mdi_child": true,
			"controls": [],
			"code": _get_mdi_child_code()
		}
	]

func _init_game_templates():
	form_templates[Category.GAME_FORMS] = [
		{
			"name": "2D Game HUD",
			"description": "[b]2D Game HUD[/b]\nA heads-up display for 2D games with health bar, score display, and lives counter. Uses CanvasLayer for overlay.",
			"size": Vector2(1280, 720),
			"is_hud": true,
			"controls": [
				{"type": "Label", "name": "lblScore", "text": "Score: 0", "position": Vector2(20, 20), "size": Vector2(200, 30)},
				{"type": "Label", "name": "lblLives", "text": "Lives: 3", "position": Vector2(20, 60), "size": Vector2(200, 30)},
				{"type": "ProgressBar", "name": "barHealth", "position": Vector2(20, 100), "size": Vector2(200, 25), "value": 100}
			],
			"code": _get_2d_hud_code()
		},
		{
			"name": "3D Game HUD",
			"description": "[b]3D Game HUD[/b]\nA heads-up display for 3D games with crosshair, ammo counter, health/armor bars, and minimap placeholder.",
			"size": Vector2(1920, 1080),
			"is_hud": true,
			"controls": [
				{"type": "Label", "name": "lblAmmo", "text": "30 / 120", "position": Vector2(1700, 980), "size": Vector2(200, 40)},
				{"type": "ProgressBar", "name": "barHealth", "position": Vector2(20, 1000), "size": Vector2(300, 30), "value": 100},
				{"type": "ProgressBar", "name": "barArmor", "position": Vector2(20, 1040), "size": Vector2(300, 20), "value": 50},
				{"type": "TextureRect", "name": "imgCrosshair", "position": Vector2(944, 524), "size": Vector2(32, 32)}
			],
			"code": _get_3d_hud_code()
		},
		{
			"name": "Main Menu (Game)",
			"description": "[b]Main Menu (Game)[/b]\nA game-style main menu with Play, Options, Credits, and Quit buttons. Includes background and title placeholders.",
			"size": Vector2(1280, 720),
			"controls": [
				{"type": "Label", "name": "lblTitle", "text": "GAME TITLE", "position": Vector2(440, 100), "size": Vector2(400, 80)},
				{"type": "Button", "name": "btnPlay", "text": "Play", "position": Vector2(540, 280), "size": Vector2(200, 50)},
				{"type": "Button", "name": "btnOptions", "text": "Options", "position": Vector2(540, 350), "size": Vector2(200, 50)},
				{"type": "Button", "name": "btnCredits", "text": "Credits", "position": Vector2(540, 420), "size": Vector2(200, 50)},
				{"type": "Button", "name": "btnQuit", "text": "Quit", "position": Vector2(540, 490), "size": Vector2(200, 50)}
			],
			"code": _get_game_main_menu_code()
		},
		{
			"name": "Pause Menu",
			"description": "[b]Pause Menu[/b]\nAn overlay pause menu with Resume, Options, Main Menu, and Quit buttons. Semi-transparent background.",
			"size": Vector2(1280, 720),
			"is_overlay": true,
			"controls": [
				{"type": "Label", "name": "lblPaused", "text": "PAUSED", "position": Vector2(540, 150), "size": Vector2(200, 60)},
				{"type": "Button", "name": "btnResume", "text": "Resume", "position": Vector2(540, 280), "size": Vector2(200, 50)},
				{"type": "Button", "name": "btnOptions", "text": "Options", "position": Vector2(540, 350), "size": Vector2(200, 50)},
				{"type": "Button", "name": "btnMainMenu", "text": "Main Menu", "position": Vector2(540, 420), "size": Vector2(200, 50)},
				{"type": "Button", "name": "btnQuit", "text": "Quit Game", "position": Vector2(540, 490), "size": Vector2(200, 50)}
			],
			"code": _get_pause_menu_code()
		},
		{
			"name": "Game Over Screen",
			"description": "[b]Game Over Screen[/b]\nA game over overlay with final score display and Retry/Main Menu buttons.",
			"size": Vector2(1280, 720),
			"is_overlay": true,
			"controls": [
				{"type": "Label", "name": "lblGameOver", "text": "GAME OVER", "position": Vector2(440, 150), "size": Vector2(400, 80)},
				{"type": "Label", "name": "lblFinalScore", "text": "Final Score: 0", "position": Vector2(490, 280), "size": Vector2(300, 40)},
				{"type": "Label", "name": "lblHighScore", "text": "High Score: 0", "position": Vector2(490, 330), "size": Vector2(300, 40)},
				{"type": "Button", "name": "btnRetry", "text": "Try Again", "position": Vector2(440, 420), "size": Vector2(180, 50)},
				{"type": "Button", "name": "btnMainMenu", "text": "Main Menu", "position": Vector2(660, 420), "size": Vector2(180, 50)}
			],
			"code": _get_game_over_code()
		},
		{
			"name": "Inventory Screen",
			"description": "[b]Inventory Screen[/b]\nA grid-based inventory UI with item slots, description panel, and action buttons (Use, Drop, Equip).",
			"size": Vector2(800, 600),
			"controls": [
				{"type": "Label", "name": "lblTitle", "text": "Inventory", "position": Vector2(20, 20), "size": Vector2(200, 30)},
				{"type": "Label", "name": "lblItemName", "text": "Select an item", "position": Vector2(540, 60), "size": Vector2(240, 30)},
				{"type": "Label", "name": "lblItemDesc", "text": "", "position": Vector2(540, 100), "size": Vector2(240, 200)},
				{"type": "Button", "name": "btnUse", "text": "Use", "position": Vector2(540, 320), "size": Vector2(110, 40)},
				{"type": "Button", "name": "btnDrop", "text": "Drop", "position": Vector2(670, 320), "size": Vector2(110, 40)},
				{"type": "Button", "name": "btnClose", "text": "Close", "position": Vector2(600, 540), "size": Vector2(120, 40)}
			],
			"code": _get_inventory_code()
		},
		{
			"name": "Settings Menu",
			"description": "[b]Settings Menu[/b]\nA comprehensive settings screen with Audio, Video, and Controls tabs. Includes common game settings.",
			"size": Vector2(700, 500),
			"controls": [
				{"type": "Label", "name": "lblTitle", "text": "Settings", "position": Vector2(20, 20), "size": Vector2(200, 30)},
				{"type": "Button", "name": "btnApply", "text": "Apply", "position": Vector2(450, 440), "size": Vector2(100, 40)},
				{"type": "Button", "name": "btnCancel", "text": "Cancel", "position": Vector2(570, 440), "size": Vector2(100, 40)}
			],
			"code": _get_settings_code()
		},
		{
			"name": "Dialog Box (RPG)",
			"description": "[b]Dialog Box (RPG)[/b]\nAn RPG-style dialog box with character portrait, name label, and typewriter text effect support.",
			"size": Vector2(1280, 200),
			"is_dialog_box": true,
			"controls": [
				{"type": "TextureRect", "name": "imgPortrait", "position": Vector2(20, 20), "size": Vector2(160, 160)},
				{"type": "Label", "name": "lblSpeaker", "text": "Character Name", "position": Vector2(200, 20), "size": Vector2(300, 30)}
			],
			"code": _get_rpg_dialog_code()
		}
	]

func _init_platform_templates():
	form_templates[Category.PLATFORM] = [
		{
			"name": "macOS Style",
			"description": "[b]macOS Style Form[/b]\nA form styled for macOS with:\n• Global menu bar (menus appear in macOS menu bar)\n• Traffic light buttons placeholder\n• Native macOS fonts and spacing\n• Follows Apple Human Interface Guidelines",
			"size": Vector2(600, 400),
			"platform": "macos",
			"has_global_menu": true,
			"controls": [],
			"code": _get_macos_code()
		},
		{
			"name": "Linux/GTK Style",
			"description": "[b]Linux/GTK Style Form[/b]\nA form styled for Linux desktop with:\n• Header bar with integrated title and controls\n• GTK-style button placement (destructive actions on left)\n• Adwaita-inspired styling\n• Client-side decorations support",
			"size": Vector2(600, 400),
			"platform": "linux",
			"has_header_bar": true,
			"controls": [],
			"code": _get_linux_code()
		},
		{
			"name": "Windows Classic",
			"description": "[b]Windows Classic Form[/b]\nA traditional Windows-style form with:\n• Standard title bar\n• Menu bar below title\n• Status bar at bottom\n• Classic Windows button placement",
			"size": Vector2(600, 400),
			"platform": "windows",
			"has_menu": true,
			"has_status_bar": true,
			"controls": [],
			"code": _get_windows_code()
		},
		{
			"name": "Cross-Platform Adaptive",
			"description": "[b]Cross-Platform Adaptive[/b]\nA form that automatically adapts to the current OS:\n• Uses native menu style per platform\n• Adjusts button order for OS conventions\n• Detects and applies platform-appropriate styling at runtime",
			"size": Vector2(600, 400),
			"platform": "adaptive",
			"controls": [
				{"type": "Button", "name": "btnPrimary", "text": "OK", "position": Vector2(400, 350), "size": Vector2(80, 30)},
				{"type": "Button", "name": "btnSecondary", "text": "Cancel", "position": Vector2(500, 350), "size": Vector2(80, 30)}
			],
			"code": _get_adaptive_code()
		},
		{
			"name": "Mobile Portrait",
			"description": "[b]Mobile Portrait Form[/b]\nA form optimized for mobile devices in portrait orientation:\n• Touch-friendly button sizes (minimum 44px)\n• Bottom navigation bar\n• Top app bar with back button\n• Responsive to different screen densities",
			"size": Vector2(390, 844),
			"platform": "mobile",
			"orientation": "portrait",
			"controls": [
				{"type": "Button", "name": "btnBack", "text": "<", "position": Vector2(10, 10), "size": Vector2(50, 50)},
				{"type": "Label", "name": "lblTitle", "text": "Screen Title", "position": Vector2(70, 20), "size": Vector2(250, 30)}
			],
			"code": _get_mobile_code()
		},
		{
			"name": "Mobile Landscape",
			"description": "[b]Mobile Landscape Form[/b]\nA form optimized for mobile devices in landscape orientation:\n• Split view support\n• Side navigation drawer\n• Landscape-optimized controls",
			"size": Vector2(844, 390),
			"platform": "mobile",
			"orientation": "landscape",
			"controls": [],
			"code": _get_mobile_landscape_code()
		}
	]

# =============================================================================
# CUSTOM TEMPLATES
# =============================================================================

func _load_custom_templates():
	custom_templates.clear()
	
	# Load from user:// directory first
	_load_templates_from_dir(CUSTOM_TEMPLATE_DIR_USER)
	# Then from project res:// directory
	_load_templates_from_dir(CUSTOM_TEMPLATE_DIR_PROJECT)

func _load_templates_from_dir(dir_path: String):
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".vgtemplate.json"):
			var full_path = dir_path.path_join(file_name)
			var template = _load_template_file(full_path)
			if template:
				template["_file_path"] = full_path
				custom_templates.append(template)
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_template_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_warning("Failed to parse template: " + path)
		return {}
	
	var data = json.data
	if not data is Dictionary:
		return {}
	
	# Convert Vector2 strings back to Vector2
	if data.has("size") and data["size"] is String:
		data["size"] = _parse_vector2(data["size"])
	
	if data.has("controls"):
		for ctrl in data["controls"]:
			if ctrl.has("position") and ctrl["position"] is String:
				ctrl["position"] = _parse_vector2(ctrl["position"])
			if ctrl.has("size") and ctrl["size"] is String:
				ctrl["size"] = _parse_vector2(ctrl["size"])
	
	return data

func _parse_vector2(s: String) -> Vector2:
	# Parse "Vector2(x, y)" or "(x, y)"
	var regex = RegEx.new()
	regex.compile("\\(?([\\d.]+)\\s*,\\s*([\\d.]+)\\)?")
	var result = regex.search(s)
	if result:
		return Vector2(float(result.get_string(1)), float(result.get_string(2)))
	return Vector2.ZERO

func _save_template_to_file(template: Dictionary, path: String) -> bool:
	# Ensure directory exists
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Convert Vector2 to string for JSON
	var save_data = template.duplicate(true)
	if save_data.has("size") and save_data["size"] is Vector2:
		var v = save_data["size"]
		save_data["size"] = "Vector2(%d, %d)" % [int(v.x), int(v.y)]
	
	if save_data.has("controls"):
		for ctrl in save_data["controls"]:
			if ctrl.has("position") and ctrl["position"] is Vector2:
				var v = ctrl["position"]
				ctrl["position"] = "Vector2(%d, %d)" % [int(v.x), int(v.y)]
			if ctrl.has("size") and ctrl["size"] is Vector2:
				var v = ctrl["size"]
				ctrl["size"] = "Vector2(%d, %d)" % [int(v.x), int(v.y)]
	
	var json_text = JSON.stringify(save_data, "\t")
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save template: " + path)
		return false
	
	file.store_string(json_text)
	file.close()
	return true

func _on_save_template_pressed():
	# Show save dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Save as Template"
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = "Template Name:"
	vbox.add_child(lbl)
	
	var input = LineEdit.new()
	input.text = "My Custom Template"
	input.select_all()
	vbox.add_child(input)
	
	var lbl_desc = Label.new()
	lbl_desc.text = "Description:"
	vbox.add_child(lbl_desc)
	
	var desc_input = TextEdit.new()
	desc_input.custom_minimum_size = Vector2(300, 80)
	desc_input.text = "A custom form template."
	vbox.add_child(desc_input)
	
	var lbl_loc = Label.new()
	lbl_loc.text = "Save Location:"
	vbox.add_child(lbl_loc)
	
	var loc_option = OptionButton.new()
	loc_option.add_item("User Directory (user://form_templates/)")
	loc_option.add_item("Project Directory (res://form_templates/)")
	vbox.add_child(loc_option)
	
	dialog.confirmed.connect(func():
		var template_name = input.text.strip_edges()
		if template_name.is_empty():
			return
		
		var template = {
			"name": template_name,
			"description": "[b]" + template_name + "[/b]\n" + desc_input.text,
			"size": Vector2(400, 300),
			"controls": [],
			"code": _get_blank_code()
		}
		
		var safe_name = template_name.to_lower().replace(" ", "_").replace("/", "_")
		var dir = CUSTOM_TEMPLATE_DIR_USER if loc_option.selected == 0 else CUSTOM_TEMPLATE_DIR_PROJECT
		var save_path = dir.path_join(safe_name + ".vgtemplate.json")
		
		if _save_template_to_file(template, save_path):
			print("Saved template: " + save_path)
			_refresh_custom_templates()
		
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered(Vector2(400, 300))
	input.grab_focus()

func _on_delete_template_pressed():
	var list = _template_lists[Category.CUSTOM]
	var selected_items = list.get_selected_items()
	if selected_items.is_empty():
		return
	
	var idx = selected_items[0]
	if idx >= custom_templates.size():
		return
	
	var template = custom_templates[idx]
	var path = template.get("_file_path", "")
	if path.is_empty():
		return
	
	# Confirm deletion
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Delete template '%s'?\n\nThis cannot be undone." % template.get("name", "Unknown")
	confirm.confirmed.connect(func():
		DirAccess.remove_absolute(path)
		_refresh_custom_templates()
		confirm.queue_free()
	)
	add_child(confirm)
	confirm.popup_centered()

func _refresh_custom_templates():
	_load_custom_templates()
	_populate_custom_list()

func _populate_custom_list():
	var list = _template_lists[Category.CUSTOM]
	list.clear()
	
	if custom_templates.is_empty():
		list.add_item("(No custom templates - click 'Save Current Form as Template' to create one)")
	else:
		for template in custom_templates:
			list.add_item(template.get("name", "Untitled"))
	
	list.select(0)

# =============================================================================
# UI POPULATION
# =============================================================================

func _populate_lists():
	# Populate VB6 Classic
	var list = _template_lists[Category.VB6_CLASSIC]
	for template in form_templates[Category.VB6_CLASSIC]:
		list.add_item(template["name"])
	list.select(0)
	
	# Populate Game Forms
	list = _template_lists[Category.GAME_FORMS]
	for template in form_templates[Category.GAME_FORMS]:
		list.add_item(template["name"])
	list.select(0)
	
	# Populate Platform
	list = _template_lists[Category.PLATFORM]
	for template in form_templates[Category.PLATFORM]:
		list.add_item(template["name"])
	list.select(0)
	
	# Populate Custom
	_populate_custom_list()
	
	# Set initial selection
	_on_item_selected(0, Category.VB6_CLASSIC)

func _on_tab_changed(tab_index: int):
	var category = tab_index as Category
	var list = _template_lists.get(category)
	if list and list.get_selected_items().size() > 0:
		_on_item_selected(list.get_selected_items()[0], category)

func _on_item_selected(index: int, category: Category):
	var templates_array: Array
	
	if category == Category.CUSTOM:
		templates_array = custom_templates
	else:
		templates_array = form_templates.get(category, [])
	
	if index >= 0 and index < templates_array.size():
		selected_template = templates_array[index]
		_description_label.text = selected_template.get("description", "No description available.")
	else:
		selected_template = {}
		_description_label.text = "No template selected."

func get_selected_template() -> Dictionary:
	if selected_template.is_empty():
		return form_templates[Category.VB6_CLASSIC][0]  # Default to blank
	return selected_template

# =============================================================================
# CODE GENERATORS - VB6 CLASSIC
# =============================================================================

func _get_blank_code() -> String:
	return """' Form_Load event
Sub Form_Load()
	' Initialize form
End Sub
"""

func _get_dialog_code() -> String:
	return """' Form_Load event
Sub Form_Load()
	' Initialize dialog
End Sub

Sub btnOK_Click()
	' Handle OK button
	Me.DialogResult = DialogResultEnum.OK
	Me.Close()
End Sub

Sub btnCancel_Click()
	' Handle Cancel button
	Me.DialogResult = DialogResultEnum.Cancel
	Me.Close()
End Sub
"""

func _get_about_code() -> String:
	return """' Form_Load event
Sub Form_Load()
	lblAppName.Text = "My Application"
	lblVersion.Text = "Version 1.0.0"
	lblCopyright.Text = "Copyright © 2026 Your Company"
	lblDescription.Text = "This is a sample application."
End Sub

Sub btnOK_Click()
	Me.Close()
End Sub
"""

func _get_splash_code() -> String:
	return """' Splash screen - shows briefly then loads main form
Dim tmrClose As Timer

Sub Form_Load()
	' Center the form on screen
	Me.StartPosition = FormStartPositionEnum.CenterScreen
	
	' Create timer to close after 3 seconds
	Set tmrClose = Timer.new()
	tmrClose.wait_time = 3.0
	tmrClose.one_shot = True
	tmrClose.timeout.connect(AddressOf SplashComplete)
	Me.add_child(tmrClose)
	tmrClose.start()
End Sub

Sub SplashComplete()
	' Load main form and close splash
	' TODO: Load your main form here
	Me.Close()
End Sub
"""

func _get_login_code() -> String:
	return """' Form_Load event
Sub Form_Load()
	' Set password field to hide characters
	txtPassword.secret = True
End Sub

Sub btnLogin_Click()
	Dim username As String
	Dim password As String
	
	username = txtUsername.Text
	password = txtPassword.Text
	
	If username = "" Then
		MsgBox "Please enter a username", vbExclamation, "Login"
		txtUsername.grab_focus()
		Exit Sub
	End If
	
	' TODO: Validate credentials
	If ValidateLogin(username, password) Then
		Me.DialogResult = DialogResultEnum.OK
		Me.Close()
	Else
		MsgBox "Invalid username or password", vbExclamation, "Login Failed"
		txtPassword.Text = ""
		txtPassword.grab_focus()
	End If
End Sub

Function ValidateLogin(user As String, pass As String) As Boolean
	' TODO: Implement your authentication logic
	ValidateLogin = (user = "admin" And pass = "password")
End Function

Sub btnCancel_Click()
	Me.DialogResult = DialogResultEnum.Cancel
	Me.Close()
End Sub
"""

func _get_main_menu_code() -> String:
	return """' Main form with menu bar
Sub Form_Load()
	' Initialize main form
End Sub

' File menu handlers
Sub mnuFile_New_Click()
	Print "New file"
End Sub

Sub mnuFile_Open_Click()
	Print "Open file"
End Sub

Sub mnuFile_Save_Click()
	Print "Save file"
End Sub

Sub mnuFile_Exit_Click()
	Me.Close()
End Sub

' Help menu handlers
Sub mnuHelp_About_Click()
	MsgBox "My Application v1.0", vbInformation, "About"
End Sub
"""

func _get_data_entry_code() -> String:
	return """' Data Entry Form
Dim currentRecord As Integer
Dim totalRecords As Integer

Sub Form_Load()
	currentRecord = 0
	totalRecords = 0
	LoadData()
	ShowRecord(0)
End Sub

Sub LoadData()
	' TODO: Load your data from file/database
	totalRecords = 10 ' Example
End Sub

Sub ShowRecord(index As Integer)
	If index < 0 Or index >= totalRecords Then Exit Sub
	currentRecord = index
	' TODO: Display record data in text fields
	UpdateNavButtons()
End Sub

Sub UpdateNavButtons()
	btnFirst.disabled = (currentRecord <= 0)
	btnPrevious.disabled = (currentRecord <= 0)
	btnNext.disabled = (currentRecord >= totalRecords - 1)
	btnLast.disabled = (currentRecord >= totalRecords - 1)
End Sub

Sub btnFirst_Click()
	ShowRecord(0)
End Sub

Sub btnPrevious_Click()
	ShowRecord(currentRecord - 1)
End Sub

Sub btnNext_Click()
	ShowRecord(currentRecord + 1)
End Sub

Sub btnLast_Click()
	ShowRecord(totalRecords - 1)
End Sub

Sub btnSave_Click()
	' TODO: Save current record
	Print "Saving record " & currentRecord
End Sub
"""

func _get_mdi_parent_code() -> String:
	return """' MDI Parent Form
Sub Form_Load()
	' Initialize MDI container
End Sub

Sub mnuWindow_Cascade_Click()
	' Cascade child windows
End Sub

Sub mnuWindow_TileH_Click()
	' Tile windows horizontally
End Sub

Sub mnuWindow_TileV_Click()
	' Tile windows vertically
End Sub

Sub mnuWindow_CloseAll_Click()
	' Close all child windows
End Sub
"""

func _get_mdi_child_code() -> String:
	return """' MDI Child Form
Sub Form_Load()
	' Initialize MDI child
End Sub

Sub Form_Resize()
	' Handle resize within MDI parent
End Sub
"""

# =============================================================================
# CODE GENERATORS - GAME FORMS
# =============================================================================

func _get_2d_hud_code() -> String:
	return """' 2D Game HUD
Dim score As Integer
Dim lives As Integer
Dim maxHealth As Integer
Dim currentHealth As Integer

Sub Form_Load()
	score = 0
	lives = 3
	maxHealth = 100
	currentHealth = 100
	UpdateDisplay()
End Sub

Sub UpdateDisplay()
	lblScore.Text = "Score: " & score
	lblLives.Text = "Lives: " & lives
	barHealth.value = (currentHealth * 100) / maxHealth
End Sub

Sub AddScore(points As Integer)
	score = score + points
	UpdateDisplay()
End Sub

Sub TakeDamage(amount As Integer)
	currentHealth = currentHealth - amount
	If currentHealth <= 0 Then
		currentHealth = 0
		LoseLife()
	End If
	UpdateDisplay()
End Sub

Sub LoseLife()
	lives = lives - 1
	If lives <= 0 Then
		' Game Over
		GetTree().change_scene_to_file("res://GameOver.tscn")
	Else
		' Reset health
		currentHealth = maxHealth
	End If
End Sub

Sub Heal(amount As Integer)
	currentHealth = currentHealth + amount
	If currentHealth > maxHealth Then
		currentHealth = maxHealth
	End If
	UpdateDisplay()
End Sub
"""

func _get_3d_hud_code() -> String:
	return """' 3D Game HUD
Dim currentAmmo As Integer
Dim maxAmmo As Integer
Dim reserveAmmo As Integer
Dim health As Integer
Dim armor As Integer

Sub Form_Load()
	currentAmmo = 30
	maxAmmo = 30
	reserveAmmo = 120
	health = 100
	armor = 50
	UpdateDisplay()
End Sub

Sub UpdateDisplay()
	lblAmmo.Text = currentAmmo & " / " & reserveAmmo
	barHealth.value = health
	barArmor.value = armor
End Sub

Sub FireWeapon()
	If currentAmmo > 0 Then
		currentAmmo = currentAmmo - 1
		UpdateDisplay()
	Else
		' Play empty click sound
		Reload()
	End If
End Sub

Sub Reload()
	Dim needed As Integer
	needed = maxAmmo - currentAmmo
	If needed > reserveAmmo Then needed = reserveAmmo
	
	currentAmmo = currentAmmo + needed
	reserveAmmo = reserveAmmo - needed
	UpdateDisplay()
End Sub

Sub TakeDamage(amount As Integer)
	' Armor absorbs damage first
	If armor > 0 Then
		Dim absorbed As Integer
		absorbed = amount / 2
		If absorbed > armor Then absorbed = armor
		armor = armor - absorbed
		amount = amount - absorbed
	End If
	
	health = health - amount
	If health <= 0 Then
		health = 0
		PlayerDied()
	End If
	UpdateDisplay()
End Sub

Sub PlayerDied()
	GetTree().change_scene_to_file("res://GameOver.tscn")
End Sub
"""

func _get_game_main_menu_code() -> String:
	return """' Game Main Menu
Sub Form_Load()
	' Play menu music, animate background, etc.
End Sub

Sub btnPlay_Click()
	' Start the game
	GetTree().change_scene_to_file("res://Game.tscn")
End Sub

Sub btnOptions_Click()
	' Show options menu
	Dim options As Control
	Set options = load("res://Options.tscn").instantiate()
	add_child(options)
End Sub

Sub btnCredits_Click()
	' Show credits
	GetTree().change_scene_to_file("res://Credits.tscn")
End Sub

Sub btnQuit_Click()
	' Exit the game
	GetTree().quit()
End Sub
"""

func _get_pause_menu_code() -> String:
	return """' Pause Menu
Sub Form_Load()
	' Pause the game
	GetTree().paused = True
	
	' Make this menu process while paused
	process_mode = Node.PROCESS_MODE_ALWAYS
End Sub

Sub btnResume_Click()
	' Unpause and close menu
	GetTree().paused = False
	queue_free()
End Sub

Sub btnOptions_Click()
	' Show options (still paused)
	Dim options As Control
	Set options = load("res://Options.tscn").instantiate()
	add_child(options)
End Sub

Sub btnMainMenu_Click()
	' Unpause before changing scene
	GetTree().paused = False
	GetTree().change_scene_to_file("res://MainMenu.tscn")
End Sub

Sub btnQuit_Click()
	GetTree().quit()
End Sub
"""

func _get_game_over_code() -> String:
	return """' Game Over Screen
Dim finalScore As Integer

Sub Form_Load()
	' Get final score (passed via autoload or global)
	finalScore = GameState.score ' Assuming GameState autoload
	
	lblFinalScore.Text = "Final Score: " & finalScore
	
	' Check/update high score
	Dim highScore As Integer
	highScore = LoadHighScore()
	If finalScore > highScore Then
		SaveHighScore(finalScore)
		highScore = finalScore
		lblHighScore.Text = "NEW HIGH SCORE!"
	Else
		lblHighScore.Text = "High Score: " & highScore
	End If
End Sub

Function LoadHighScore() As Integer
	' Load from save file
	LoadHighScore = 0
	Dim f As FileAccess
	Set f = FileAccess.open("user://highscore.dat", FileAccess.READ)
	If Not f Is Nothing Then
		LoadHighScore = f.get_32()
		f.close()
	End If
End Function

Sub SaveHighScore(score As Integer)
	Dim f As FileAccess
	Set f = FileAccess.open("user://highscore.dat", FileAccess.WRITE)
	f.store_32(score)
	f.close()
End Sub

Sub btnRetry_Click()
	GetTree().change_scene_to_file("res://Game.tscn")
End Sub

Sub btnMainMenu_Click()
	GetTree().change_scene_to_file("res://MainMenu.tscn")
End Sub
"""

func _get_inventory_code() -> String:
	return """' Inventory Screen
Dim inventory As Array
Dim selectedSlot As Integer

Sub Form_Load()
	selectedSlot = -1
	LoadInventory()
	PopulateGrid()
End Sub

Sub LoadInventory()
	' TODO: Load from player data
	inventory = []
End Sub

Sub PopulateGrid()
	' Create inventory slots
	Dim i As Integer
	For i = 0 To 19
		Dim slot As Button
		Set slot = Button.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.name = "Slot" & i
		slot.pressed.connect(AddressOf OnSlotClick, [i])
		' Add to a grid container (you'll need to create one)
		
		If i < inventory.size() Then
			slot.text = inventory[i].name
		End If
	Next i
End Sub

Sub OnSlotClick(slotIndex As Integer)
	selectedSlot = slotIndex
	If slotIndex < inventory.size() Then
		Dim item As Dictionary
		item = inventory[slotIndex]
		lblItemName.Text = item.name
		lblItemDesc.Text = item.description
	Else
		lblItemName.Text = "Empty Slot"
		lblItemDesc.Text = ""
	End If
End Sub

Sub btnUse_Click()
	If selectedSlot < 0 Or selectedSlot >= inventory.size() Then Exit Sub
	
	Dim item As Dictionary
	item = inventory[selectedSlot]
	' TODO: Use item logic
	Print "Using " & item.name
End Sub

Sub btnDrop_Click()
	If selectedSlot < 0 Or selectedSlot >= inventory.size() Then Exit Sub
	
	inventory.remove_at(selectedSlot)
	PopulateGrid()
	lblItemName.Text = "Select an item"
	lblItemDesc.Text = ""
End Sub

Sub btnClose_Click()
	queue_free()
End Sub
"""

func _get_settings_code() -> String:
	return """' Settings Menu
Dim settings As Dictionary

Sub Form_Load()
	LoadSettings()
	ApplyToUI()
End Sub

Sub LoadSettings()
	settings = {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"fullscreen": False,
		"vsync": True,
		"resolution_index": 0
	}
	
	' Load from file if exists
	If FileAccess.file_exists("user://settings.cfg") Then
		Dim cfg As ConfigFile
		Set cfg = ConfigFile.new()
		cfg.load("user://settings.cfg")
		
		settings["master_volume"] = cfg.get_value("audio", "master", 1.0)
		settings["music_volume"] = cfg.get_value("audio", "music", 0.8)
		settings["sfx_volume"] = cfg.get_value("audio", "sfx", 1.0)
		settings["fullscreen"] = cfg.get_value("video", "fullscreen", False)
		settings["vsync"] = cfg.get_value("video", "vsync", True)
	End If
End Sub

Sub ApplyToUI()
	' TODO: Set slider/checkbox values from settings
End Sub

Sub btnApply_Click()
	SaveSettings()
	ApplySettings()
	Me.Close()
End Sub

Sub SaveSettings()
	Dim cfg As ConfigFile
	Set cfg = ConfigFile.new()
	
	cfg.set_value("audio", "master", settings["master_volume"])
	cfg.set_value("audio", "music", settings["music_volume"])
	cfg.set_value("audio", "sfx", settings["sfx_volume"])
	cfg.set_value("video", "fullscreen", settings["fullscreen"])
	cfg.set_value("video", "vsync", settings["vsync"])
	
	cfg.save("user://settings.cfg")
End Sub

Sub ApplySettings()
	' Apply audio
	AudioServer.set_bus_volume_db(0, linear_to_db(settings["master_volume"]))
	
	' Apply video
	If settings["fullscreen"] Then
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Else
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	End If
	
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED If settings["vsync"] Else DisplayServer.VSYNC_DISABLED)
End Sub

Sub btnCancel_Click()
	Me.Close()
End Sub
"""

func _get_rpg_dialog_code() -> String:
	return """' RPG Dialog Box
Dim dialogQueue As Array
Dim currentText As String
Dim displayedChars As Integer
Dim isTyping As Boolean
Dim typeTimer As Timer

Const CHARS_PER_SECOND = 30

Sub Form_Load()
	dialogQueue = []
	isTyping = False
	
	' Create typewriter timer
	Set typeTimer = Timer.new()
	typeTimer.wait_time = 1.0 / CHARS_PER_SECOND
	typeTimer.timeout.connect(AddressOf TypeNextChar)
	add_child(typeTimer)
End Sub

Sub ShowDialog(speaker As String, portrait As Texture2D, text As String)
	lblSpeaker.Text = speaker
	imgPortrait.texture = portrait
	currentText = text
	displayedChars = 0
	txtDialog.text = ""
	isTyping = True
	typeTimer.start()
	visible = True
End Sub

Sub TypeNextChar()
	displayedChars = displayedChars + 1
	txtDialog.text = currentText.substr(0, displayedChars)
	
	If displayedChars >= currentText.length() Then
		isTyping = False
		typeTimer.stop()
	End If
End Sub

Sub _input(event As InputEvent)
	If event.is_action_pressed("ui_accept") Then
		If isTyping Then
			' Skip to end
			isTyping = False
			typeTimer.stop()
			txtDialog.text = currentText
		Else
			' Advance dialog
			If dialogQueue.size() > 0 Then
				Dim nextDialog As Dictionary
				nextDialog = dialogQueue.pop_front()
				ShowDialog(nextDialog.speaker, nextDialog.portrait, nextDialog.text)
			Else
				' Close dialog
				visible = False
			End If
		End If
	End If
End Sub

Sub QueueDialog(speaker As String, portrait As Texture2D, text As String)
	dialogQueue.append({
		"speaker": speaker,
		"portrait": portrait,
		"text": text
	})
End Sub
"""

# =============================================================================
# CODE GENERATORS - PLATFORM
# =============================================================================

func _get_macos_code() -> String:
	return """' macOS Style Form
' Uses global menu bar when running on macOS

Sub Form_Load()
	' Check if running on macOS
	If OS.get_name() = "macOS" Then
		SetupMacMenu()
	End If
End Sub

Sub SetupMacMenu()
	' On macOS, menus appear in the system menu bar
	' Use DisplayServer.global_menu_* methods
	
	' Add App menu items
	DisplayServer.global_menu_add_item("_main", "About My App", AddressOf OnAbout)
	DisplayServer.global_menu_add_separator("_main")
	DisplayServer.global_menu_add_item("_main", "Preferences...", AddressOf OnPreferences, KEY_MASK_CMD | KEY_COMMA)
	
	' File menu
	DisplayServer.global_menu_add_submenu_item("_main", "File", "_file")
	DisplayServer.global_menu_add_item("_file", "New", AddressOf OnNew, KEY_MASK_CMD | KEY_N)
	DisplayServer.global_menu_add_item("_file", "Open...", AddressOf OnOpen, KEY_MASK_CMD | KEY_O)
	DisplayServer.global_menu_add_item("_file", "Save", AddressOf OnSave, KEY_MASK_CMD | KEY_S)
End Sub

Sub OnAbout()
	' Show about dialog
End Sub

Sub OnPreferences()
	' Show preferences (macOS convention)
End Sub

Sub OnNew()
	Print "New"
End Sub

Sub OnOpen()
	Print "Open"
End Sub

Sub OnSave()
	Print "Save"
End Sub
"""

func _get_linux_code() -> String:
	return """' Linux/GTK Style Form
' Uses header bar with integrated title and controls

Sub Form_Load()
	' GTK-style: OK/Apply on right, Cancel/destructive on left
	' This follows GNOME HIG (Human Interface Guidelines)
	
	' Set borderless with custom header bar
	' DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
	SetupHeaderBar()
End Sub

Sub SetupHeaderBar()
	' Create a custom header bar (like GTK HeaderBar)
	Dim header As HBoxContainer
	Set header = HBoxContainer.new()
	header.name = "HeaderBar"
	header.add_theme_constant_override("separation", 6)
	
	' Left side - destructive/cancel actions (GTK convention)
	Dim btnCancel As Button
	Set btnCancel = Button.new()
	btnCancel.text = "Cancel"
	btnCancel.flat = True
	header.add_child(btnCancel)
	
	' Spacer
	Dim spacer As Control
	Set spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	' Title in center
	Dim lblTitle As Label
	Set lblTitle = Label.new()
	lblTitle.text = Me.title
	lblTitle.add_theme_font_size_override("font_size", 14)
	header.add_child(lblTitle)
	
	' Another spacer
	Set spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	' Right side - primary/confirm actions
	Dim btnApply As Button
	Set btnApply = Button.new()
	btnApply.text = "Apply"
	header.add_child(btnApply)
End Sub
"""

func _get_windows_code() -> String:
	return """' Windows Classic Style Form
' Traditional Windows application layout

Sub Form_Load()
	' Standard Windows layout:
	' - Title bar (handled by OS)
	' - Menu bar
	' - Toolbar (optional)
	' - Content area
	' - Status bar
	
	SetupStatusBar()
End Sub

Sub SetupStatusBar()
	' Create status bar at bottom
	Dim statusBar As Panel
	Set statusBar = Panel.new()
	statusBar.name = "StatusBar"
	statusBar.anchor_top = 1.0
	statusBar.anchor_bottom = 1.0
	statusBar.anchor_left = 0.0
	statusBar.anchor_right = 1.0
	statusBar.offset_top = -24
	statusBar.offset_bottom = 0
	Me.add_child(statusBar)
	
	Dim lblStatus As Label
	Set lblStatus = Label.new()
	lblStatus.name = "lblStatus"
	lblStatus.text = "Ready"
	lblStatus.position = Vector2(5, 2)
	statusBar.add_child(lblStatus)
End Sub

Sub SetStatus(text As String)
	Dim lbl As Label
	Set lbl = FindChild("lblStatus")
	If Not lbl Is Nothing Then
		lbl.text = text
	End If
End Sub
"""

func _get_adaptive_code() -> String:
	return """' Cross-Platform Adaptive Form
' Automatically adapts to the current operating system

Sub Form_Load()
	AdaptToPlatform()
End Sub

Sub AdaptToPlatform()
	Dim os As String
	os = OS.get_name()
	
	Select Case os
		Case "macOS"
			SetupForMac()
		Case "Linux", "FreeBSD"
			SetupForLinux()
		Case "Windows"
			SetupForWindows()
		Case "Android", "iOS"
			SetupForMobile()
	End Select
End Sub

Sub SetupForMac()
	' macOS: OK on right, Cancel on left (but we swap the visual order)
	' Button order in code: Cancel, then OK (left to right)
	btnSecondary.position = Vector2(400, 350)  ' Cancel on left
	btnPrimary.position = Vector2(500, 350)    ' OK on right
End Sub

Sub SetupForLinux()
	' Linux/GTK: Similar to macOS
	' Destructive actions on left, primary on right
	btnSecondary.position = Vector2(400, 350)
	btnPrimary.position = Vector2(500, 350)
End Sub

Sub SetupForWindows()
	' Windows: OK on left, Cancel on right (traditional)
	btnPrimary.position = Vector2(400, 350)    ' OK on left
	btnSecondary.position = Vector2(500, 350)  ' Cancel on right
End Sub

Sub SetupForMobile()
	' Mobile: Make buttons larger, touch-friendly
	btnPrimary.custom_minimum_size = Vector2(120, 50)
	btnSecondary.custom_minimum_size = Vector2(120, 50)
End Sub
"""

func _get_mobile_code() -> String:
	return """' Mobile Portrait Form
' Optimized for touch devices in portrait orientation

Const MIN_TOUCH_SIZE = 44

Sub Form_Load()
	SetupMobileUI()
End Sub

Sub SetupMobileUI()
	' Ensure all interactive elements are touch-friendly
	EnsureTouchSize(btnBack)
	
	' Setup gesture handling
	' TODO: Add swipe gestures for navigation
End Sub

Sub EnsureTouchSize(ctrl As Control)
	If ctrl.size.x < MIN_TOUCH_SIZE Then
		ctrl.custom_minimum_size.x = MIN_TOUCH_SIZE
	End If
	If ctrl.size.y < MIN_TOUCH_SIZE Then
		ctrl.custom_minimum_size.y = MIN_TOUCH_SIZE
	End If
End Sub

Sub btnBack_Click()
	' Navigate back
	' Could use navigation stack pattern
	GetTree().change_scene_to_file("res://PreviousScreen.tscn")
End Sub

Sub _notification(what As Integer)
	If what = NOTIFICATION_WM_GO_BACK_REQUEST Then
		' Android back button pressed
		btnBack_Click()
	End If
End Sub
"""

func _get_mobile_landscape_code() -> String:
	return """' Mobile Landscape Form
' Optimized for tablets and landscape phone orientation

Sub Form_Load()
	SetupSplitView()
End Sub

Sub SetupSplitView()
	' Create master-detail split view (common on tablets)
	Dim split As HSplitContainer
	Set split = HSplitContainer.new()
	split.anchor_right = 1.0
	split.anchor_bottom = 1.0
	split.split_offset = 300
	Me.add_child(split)
	
	' Left panel (navigation/list)
	Dim leftPanel As Panel
	Set leftPanel = Panel.new()
	leftPanel.custom_minimum_size = Vector2(250, 0)
	split.add_child(leftPanel)
	
	' Right panel (detail view)
	Dim rightPanel As Panel
	Set rightPanel = Panel.new()
	split.add_child(rightPanel)
End Sub

Sub _notification(what As Integer)
	If what = NOTIFICATION_WM_SIZE_CHANGED Then
		' Handle orientation changes
		Dim viewSize As Vector2
		viewSize = get_viewport().get_visible_rect().size
		
		If viewSize.x < viewSize.y Then
			' Switched to portrait - consider showing navigation drawer instead
			Print "Portrait mode"
		Else
			' Landscape - keep split view
			Print "Landscape mode"
		End If
	End If
End Sub
"""
