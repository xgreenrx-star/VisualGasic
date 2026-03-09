@tool
extends RefCounted
## VisualGasic Theme Manager
##
## Provides VB6-style syntax highlighting themes:
## - Classic VB6 theme (blue background, yellow keywords)
## - Modern Dark theme
## - Modern Light theme
## - Custom theme support

class_name VGThemeManager

# =============================================================================
# THEME DATA
# =============================================================================

## A complete syntax highlighting + IDE chrome theme
class VGTheme:
	var name: String = ""
	var description: String = ""
	var is_builtin: bool = false
	
	# Code editor colors
	var background_color: Color = Color.WHITE
	var text_color: Color = Color.BLACK
	var line_number_color: Color = Color.GRAY
	var current_line_color: Color = Color(1, 1, 0, 0.1)
	var selection_color: Color = Color(0.3, 0.5, 0.8, 0.4)
	var caret_color: Color = Color.BLACK
	
	# Syntax colors
	var keyword_color: Color = Color.BLUE
	var type_color: Color = Color.DARK_CYAN
	var string_color: Color = Color.DARK_RED
	var number_color: Color = Color.DARK_MAGENTA
	var comment_color: Color = Color.DARK_GREEN
	var operator_color: Color = Color.BLACK
	var function_color: Color = Color.DARK_BLUE
	var variable_color: Color = Color.BLACK
	var constant_color: Color = Color.PURPLE
	var property_color: Color = Color.DARK_CYAN
	var builtin_color: Color = Color.BLUE
	var error_color: Color = Color.RED
	var warning_color: Color = Color.ORANGE
	
	# Font settings
	var font_name: String = "Courier New"
	var font_size: int = 12
	var font_bold_keywords: bool = true
	
	# IDE chrome colors — panels, headers, toolbox, etc.
	var ide_panel_bg: Color = Color("#F0EDE8")          # Main panel background
	var ide_panel_border: Color = Color(0.72, 0.71, 0.68) # Panel borders
	var ide_header_bg: Color = Color(0.58, 0.58, 0.62)  # Section header bars
	var ide_header_border: Color = Color(0.4, 0.4, 0.4)
	var ide_header_text: Color = Color.WHITE
	var ide_text_color: Color = Color.BLACK              # Labels, tree text
	var ide_list_bg: Color = Color.WHITE                 # Tree/ItemList/LineEdit bg
	var ide_tab_selected_bg: Color = Color("#F0EDE8")
	var ide_tab_unselected_bg: Color = Color(0.85, 0.84, 0.82)
	var ide_tab_hover_bg: Color = Color(0.95, 0.94, 0.92)
	var ide_btn_hover_bg: Color = Color(0.95, 0.94, 0.92)
	var ide_btn_pressed_bg: Color = Color(0.88, 0.87, 0.85)
	var ide_toolbox_btn_hover: Color = Color(0.91, 0.95, 1.0)
	var ide_toolbox_btn_pressed: Color = Color(0.26, 0.59, 0.98)
	var ide_toolbox_text_pressed: Color = Color.WHITE
	var ide_accent_color: Color = Color(0.0, 0.0, 0.5)  # Selection/title bar accent
	var ide_tooltip_bg: Color = Color(1.0, 1.0, 0.94)   # Tooltip background
	
	func duplicate() -> VGTheme:
		var t = VGTheme.new()
		t.name = name + " (Copy)"
		t.description = description
		t.is_builtin = false
		t.background_color = background_color
		t.text_color = text_color
		t.line_number_color = line_number_color
		t.current_line_color = current_line_color
		t.selection_color = selection_color
		t.caret_color = caret_color
		t.keyword_color = keyword_color
		t.type_color = type_color
		t.string_color = string_color
		t.number_color = number_color
		t.comment_color = comment_color
		t.operator_color = operator_color
		t.function_color = function_color
		t.variable_color = variable_color
		t.constant_color = constant_color
		t.property_color = property_color
		t.builtin_color = builtin_color
		t.error_color = error_color
		t.warning_color = warning_color
		t.font_name = font_name
		t.font_size = font_size
		t.font_bold_keywords = font_bold_keywords
		# IDE chrome
		t.ide_panel_bg = ide_panel_bg
		t.ide_panel_border = ide_panel_border
		t.ide_header_bg = ide_header_bg
		t.ide_header_border = ide_header_border
		t.ide_header_text = ide_header_text
		t.ide_text_color = ide_text_color
		t.ide_list_bg = ide_list_bg
		t.ide_tab_selected_bg = ide_tab_selected_bg
		t.ide_tab_unselected_bg = ide_tab_unselected_bg
		t.ide_tab_hover_bg = ide_tab_hover_bg
		t.ide_btn_hover_bg = ide_btn_hover_bg
		t.ide_btn_pressed_bg = ide_btn_pressed_bg
		t.ide_toolbox_btn_hover = ide_toolbox_btn_hover
		t.ide_toolbox_btn_pressed = ide_toolbox_btn_pressed
		t.ide_toolbox_text_pressed = ide_toolbox_text_pressed
		t.ide_accent_color = ide_accent_color
		t.ide_tooltip_bg = ide_tooltip_bg
		return t

# =============================================================================
# BUILT-IN THEMES
# =============================================================================

static var _themes: Dictionary = {}  # name -> VGTheme
static var _current_theme: String = "VB6 Classic"
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_init_builtin_themes()
	load_user_themes()

static func _init_builtin_themes() -> void:
	# --- VB6 Classic (Authentic VB6 IDE code window) ---
	# Real VB6 had a white code editor with blue keywords, green comments,
	# and red strings — NOT the blue/yellow QuickBasic look.
	var classic = VGTheme.new()
	classic.name = "VB6 Classic"
	classic.description = "Authentic Visual Basic 6 IDE — warm cream editor, blue keywords"
	classic.is_builtin = true
	classic.background_color = Color(0.96, 0.95, 0.92)  # warm cream — easy on the eyes
	classic.text_color = Color.BLACK
	classic.line_number_color = Color(0.5, 0.5, 0.5)
	classic.current_line_color = Color(0.93, 0.92, 0.88)
	classic.selection_color = Color(0.0, 0.0, 0.5, 0.35)
	classic.caret_color = Color.BLACK
	classic.keyword_color = Color(0.0, 0.0, 0.8)         # Blue (VB6 keyword color)
	classic.type_color = Color(0.0, 0.0, 0.8)            # Same blue for types
	classic.string_color = Color(0.6, 0.0, 0.0)          # Dark red (VB6 strings)
	classic.number_color = Color.BLACK                     # Black numbers
	classic.comment_color = Color(0.0, 0.5, 0.0)         # Green (VB6 comments)
	classic.operator_color = Color.BLACK
	classic.function_color = Color.BLACK
	classic.variable_color = Color.BLACK
	classic.constant_color = Color.BLACK
	classic.property_color = Color.BLACK
	classic.builtin_color = Color(0.0, 0.0, 0.8)         # Blue like keywords
	classic.error_color = Color.RED
	classic.warning_color = Color(0.7, 0.5, 0.0)
	classic.font_name = "Courier New"
	classic.font_size = 10
	classic.font_bold_keywords = false
	# IDE chrome — classic VB6 cream/gray panels
	classic.ide_panel_bg = Color("#F0EDE8")
	classic.ide_panel_border = Color(0.72, 0.71, 0.68)
	classic.ide_header_bg = Color(0.58, 0.58, 0.62)
	classic.ide_header_border = Color(0.4, 0.4, 0.4)
	classic.ide_header_text = Color.WHITE
	classic.ide_text_color = Color.BLACK
	classic.ide_list_bg = Color.WHITE
	classic.ide_tab_selected_bg = Color("#F0EDE8")
	classic.ide_tab_unselected_bg = Color(0.85, 0.84, 0.82)
	classic.ide_tab_hover_bg = Color(0.95, 0.94, 0.92)
	classic.ide_btn_hover_bg = Color(0.95, 0.94, 0.92)
	classic.ide_btn_pressed_bg = Color(0.88, 0.87, 0.85)
	classic.ide_toolbox_btn_hover = Color(0.91, 0.95, 1.0)
	classic.ide_toolbox_btn_pressed = Color(0.26, 0.59, 0.98)
	classic.ide_toolbox_text_pressed = Color.WHITE
	classic.ide_accent_color = Color(0.0, 0.0, 0.5)
	classic.ide_tooltip_bg = Color(1.0, 1.0, 0.94)
	_themes["VB6 Classic"] = classic
	
	# --- QuickBasic (the classic blue-screen BASIC look) ---
	var qb = VGTheme.new()
	qb.name = "QuickBasic"
	qb.description = "QBasic / QuickBasic blue screen with yellow text"
	qb.is_builtin = true
	qb.background_color = Color(0.0, 0.0, 0.67)         # QBasic blue
	qb.text_color = Color(1.0, 1.0, 1.0)                 # White
	qb.line_number_color = Color(0.5, 0.5, 0.7)
	qb.current_line_color = Color(0.0, 0.0, 0.8)
	qb.selection_color = Color(0.3, 0.3, 0.9, 0.5)
	qb.caret_color = Color.WHITE
	qb.keyword_color = Color(1.0, 1.0, 1.0)              # Bright white keywords
	qb.type_color = Color(0.5, 1.0, 1.0)                 # Cyan
	qb.string_color = Color(1.0, 0.6, 0.6)               # Light red
	qb.number_color = Color(0.6, 1.0, 0.6)               # Light green
	qb.comment_color = Color(0.5, 0.5, 0.5)              # Gray (QB comments)
	qb.operator_color = Color(1.0, 1.0, 1.0)
	qb.function_color = Color(1.0, 1.0, 1.0)
	qb.variable_color = Color(1.0, 1.0, 0.0)             # Yellow variables
	qb.constant_color = Color(1.0, 0.7, 0.3)             # Orange
	qb.property_color = Color(0.5, 1.0, 1.0)
	qb.builtin_color = Color(1.0, 1.0, 1.0)
	qb.error_color = Color(1.0, 0.3, 0.3)
	qb.warning_color = Color(1.0, 0.8, 0.2)
	qb.font_name = "Courier New"
	qb.font_size = 10
	qb.font_bold_keywords = true
	# IDE chrome — blue-tinted panels to match the code editor
	qb.ide_panel_bg = Color(0.15, 0.15, 0.35)
	qb.ide_panel_border = Color(0.3, 0.3, 0.5)
	qb.ide_header_bg = Color(0.0, 0.0, 0.5)
	qb.ide_header_border = Color(0.2, 0.2, 0.4)
	qb.ide_header_text = Color.WHITE
	qb.ide_text_color = Color(0.9, 0.9, 0.9)
	qb.ide_list_bg = Color(0.0, 0.0, 0.5)
	qb.ide_tab_selected_bg = Color(0.15, 0.15, 0.35)
	qb.ide_tab_unselected_bg = Color(0.1, 0.1, 0.25)
	qb.ide_tab_hover_bg = Color(0.2, 0.2, 0.4)
	qb.ide_btn_hover_bg = Color(0.2, 0.2, 0.45)
	qb.ide_btn_pressed_bg = Color(0.1, 0.1, 0.3)
	qb.ide_toolbox_btn_hover = Color(0.2, 0.2, 0.5)
	qb.ide_toolbox_btn_pressed = Color(0.0, 0.0, 0.7)
	qb.ide_toolbox_text_pressed = Color.WHITE
	qb.ide_accent_color = Color(0.3, 0.3, 0.9)
	qb.ide_tooltip_bg = Color(0.0, 0.0, 0.5)
	_themes["QuickBasic"] = qb
	
	# --- Godot Dark (matches the Godot editor dark theme) ---
	var godot = VGTheme.new()
	godot.name = "Godot Dark"
	godot.description = "Godot editor dark theme"
	godot.is_builtin = true
	godot.background_color = Color(0.15, 0.17, 0.21)     # Godot code bg
	godot.text_color = Color(0.8, 0.81, 0.82)
	godot.line_number_color = Color(0.45, 0.47, 0.5)
	godot.current_line_color = Color(0.19, 0.21, 0.27)
	godot.selection_color = Color(0.24, 0.38, 0.55, 0.5)
	godot.caret_color = Color(0.8, 0.81, 0.82)
	godot.keyword_color = Color(1.0, 0.44, 0.52)         # Godot pink keywords
	godot.type_color = Color(0.53, 0.83, 0.93)           # Light blue types
	godot.string_color = Color(1.0, 0.93, 0.63)          # Yellow strings
	godot.number_color = Color(0.63, 1.0, 0.75)          # Green numbers
	godot.comment_color = Color(0.8, 0.81, 0.82, 0.5)   # Faded gray
	godot.operator_color = Color(0.67, 0.79, 1.0)        # Light blue
	godot.function_color = Color(0.34, 0.70, 1.0)        # Blue functions
	godot.variable_color = Color(0.8, 0.81, 0.82)
	godot.constant_color = Color(0.63, 1.0, 0.75)        # Green
	godot.property_color = Color(0.53, 0.83, 0.93)
	godot.builtin_color = Color(1.0, 0.44, 0.52)
	godot.error_color = Color(1.0, 0.35, 0.35)
	godot.warning_color = Color(1.0, 0.75, 0.25)
	godot.font_name = "Fira Code"
	godot.font_size = 12
	godot.font_bold_keywords = false
	# IDE chrome — Godot dark panels
	godot.ide_panel_bg = Color(0.2, 0.22, 0.27)
	godot.ide_panel_border = Color(0.14, 0.16, 0.2)
	godot.ide_header_bg = Color(0.17, 0.19, 0.23)
	godot.ide_header_border = Color(0.12, 0.13, 0.17)
	godot.ide_header_text = Color(0.85, 0.85, 0.88)
	godot.ide_text_color = Color(0.8, 0.81, 0.82)
	godot.ide_list_bg = Color(0.15, 0.17, 0.21)
	godot.ide_tab_selected_bg = Color(0.2, 0.22, 0.27)
	godot.ide_tab_unselected_bg = Color(0.15, 0.17, 0.21)
	godot.ide_tab_hover_bg = Color(0.25, 0.27, 0.33)
	godot.ide_btn_hover_bg = Color(0.28, 0.30, 0.36)
	godot.ide_btn_pressed_bg = Color(0.22, 0.24, 0.3)
	godot.ide_toolbox_btn_hover = Color(0.28, 0.30, 0.36)
	godot.ide_toolbox_btn_pressed = Color(0.24, 0.38, 0.55)
	godot.ide_toolbox_text_pressed = Color.WHITE
	godot.ide_accent_color = Color(0.34, 0.56, 0.86)
	godot.ide_tooltip_bg = Color(0.18, 0.20, 0.24)
	_themes["Godot Dark"] = godot
	
	# --- Amiga Workbench (classic Amiga OS 1.x / 2.x) ---
	var amiga = VGTheme.new()
	amiga.name = "Amiga Workbench"
	amiga.description = "Retro Amiga Workbench 1.3 colors"
	amiga.is_builtin = true
	amiga.background_color = Color(0.0, 0.33, 0.66)      # Amiga blue
	amiga.text_color = Color(1.0, 1.0, 1.0)               # White
	amiga.line_number_color = Color(0.6, 0.6, 0.8)
	amiga.current_line_color = Color(0.0, 0.4, 0.75)
	amiga.selection_color = Color(1.0, 0.5, 0.0, 0.4)     # Orange selection
	amiga.caret_color = Color(1.0, 0.5, 0.0)              # Orange caret
	amiga.keyword_color = Color(1.0, 0.5, 0.0)            # Amiga orange
	amiga.type_color = Color(1.0, 1.0, 1.0)               # White
	amiga.string_color = Color(0.6, 0.85, 1.0)            # Light blue
	amiga.number_color = Color(1.0, 0.75, 0.4)            # Light orange
	amiga.comment_color = Color(0.5, 0.7, 0.9)            # Muted blue
	amiga.operator_color = Color(1.0, 1.0, 1.0)
	amiga.function_color = Color(1.0, 0.75, 0.0)          # Gold
	amiga.variable_color = Color(1.0, 1.0, 1.0)
	amiga.constant_color = Color(1.0, 0.5, 0.0)
	amiga.property_color = Color(0.7, 0.9, 1.0)
	amiga.builtin_color = Color(1.0, 0.5, 0.0)
	amiga.error_color = Color(1.0, 0.2, 0.2)
	amiga.warning_color = Color(1.0, 0.8, 0.0)
	amiga.font_name = "Courier New"
	amiga.font_size = 11
	amiga.font_bold_keywords = true
	# IDE chrome — Amiga Workbench blue/white/orange
	amiga.ide_panel_bg = Color(0.6, 0.6, 0.6)             # Amiga WB light gray
	amiga.ide_panel_border = Color(0.0, 0.0, 0.0)         # Black borders
	amiga.ide_header_bg = Color(0.0, 0.33, 0.66)          # Amiga blue title bars
	amiga.ide_header_border = Color(0.0, 0.0, 0.0)
	amiga.ide_header_text = Color(1.0, 0.5, 0.0)          # Orange title text
	amiga.ide_text_color = Color.BLACK
	amiga.ide_list_bg = Color(0.73, 0.73, 0.73)           # Light gray lists
	amiga.ide_tab_selected_bg = Color(0.6, 0.6, 0.6)
	amiga.ide_tab_unselected_bg = Color(0.45, 0.45, 0.45)
	amiga.ide_tab_hover_bg = Color(0.7, 0.7, 0.7)
	amiga.ide_btn_hover_bg = Color(0.7, 0.7, 0.7)
	amiga.ide_btn_pressed_bg = Color(0.5, 0.5, 0.5)
	amiga.ide_toolbox_btn_hover = Color(0.7, 0.7, 0.7)
	amiga.ide_toolbox_btn_pressed = Color(1.0, 0.5, 0.0)  # Orange pressed
	amiga.ide_toolbox_text_pressed = Color.BLACK
	amiga.ide_accent_color = Color(1.0, 0.5, 0.0)         # Orange accent
	amiga.ide_tooltip_bg = Color(1.0, 0.9, 0.7)           # Warm tooltip
	_themes["Amiga Workbench"] = amiga
	
	# --- Modern Dark ---
	var dark = VGTheme.new()
	dark.name = "Modern Dark"
	dark.description = "Dark theme inspired by VS Code"
	dark.is_builtin = true
	dark.background_color = Color(0.12, 0.12, 0.12)
	dark.text_color = Color(0.85, 0.85, 0.85)
	dark.line_number_color = Color(0.5, 0.5, 0.5)
	dark.current_line_color = Color(0.18, 0.18, 0.18)
	dark.selection_color = Color(0.26, 0.4, 0.6, 0.5)
	dark.caret_color = Color.WHITE
	dark.keyword_color = Color(0.57, 0.44, 0.86)  # Purple
	dark.type_color = Color(0.3, 0.75, 0.75)  # Teal
	dark.string_color = Color(0.8, 0.55, 0.4)  # Orange-brown
	dark.number_color = Color(0.7, 0.85, 0.55)  # Light green
	dark.comment_color = Color(0.45, 0.55, 0.45)  # Gray-green
	dark.operator_color = Color(0.85, 0.85, 0.85)
	dark.function_color = Color(0.86, 0.86, 0.5)  # Yellow
	dark.variable_color = Color(0.6, 0.8, 0.9)  # Light blue
	dark.constant_color = Color(0.4, 0.75, 0.9)  # Blue
	dark.property_color = Color(0.6, 0.8, 0.9)
	dark.builtin_color = Color(0.57, 0.44, 0.86)
	dark.error_color = Color(0.95, 0.35, 0.35)
	dark.warning_color = Color(0.95, 0.75, 0.25)
	dark.font_name = "Fira Code"
	dark.font_size = 12
	dark.font_bold_keywords = false
	# IDE chrome — VS Code dark style
	dark.ide_panel_bg = Color(0.15, 0.15, 0.15)
	dark.ide_panel_border = Color(0.22, 0.22, 0.22)
	dark.ide_header_bg = Color(0.18, 0.18, 0.18)
	dark.ide_header_border = Color(0.12, 0.12, 0.12)
	dark.ide_header_text = Color(0.88, 0.88, 0.88)
	dark.ide_text_color = Color(0.85, 0.85, 0.85)
	dark.ide_list_bg = Color(0.12, 0.12, 0.12)
	dark.ide_tab_selected_bg = Color(0.15, 0.15, 0.15)
	dark.ide_tab_unselected_bg = Color(0.1, 0.1, 0.1)
	dark.ide_tab_hover_bg = Color(0.2, 0.2, 0.2)
	dark.ide_btn_hover_bg = Color(0.22, 0.22, 0.22)
	dark.ide_btn_pressed_bg = Color(0.18, 0.18, 0.18)
	dark.ide_toolbox_btn_hover = Color(0.22, 0.22, 0.22)
	dark.ide_toolbox_btn_pressed = Color(0.26, 0.4, 0.6)
	dark.ide_toolbox_text_pressed = Color.WHITE
	dark.ide_accent_color = Color(0.26, 0.59, 0.98)
	dark.ide_tooltip_bg = Color(0.2, 0.2, 0.2)
	_themes["Modern Dark"] = dark
	
	# --- Modern Light ---
	var light = VGTheme.new()
	light.name = "Modern Light"
	light.description = "Clean light theme"
	light.is_builtin = true
	light.background_color = Color(0.98, 0.98, 0.98)
	light.text_color = Color(0.15, 0.15, 0.15)
	light.line_number_color = Color(0.6, 0.6, 0.6)
	light.current_line_color = Color(0.95, 0.95, 0.9)
	light.selection_color = Color(0.7, 0.8, 0.95, 0.5)
	light.caret_color = Color.BLACK
	light.keyword_color = Color(0.0, 0.0, 0.7)  # Blue
	light.type_color = Color(0.0, 0.5, 0.5)  # Teal
	light.string_color = Color(0.6, 0.1, 0.1)  # Dark red
	light.number_color = Color(0.0, 0.5, 0.0)  # Green
	light.comment_color = Color(0.4, 0.5, 0.4)  # Gray-green
	light.operator_color = Color(0.2, 0.2, 0.2)
	light.function_color = Color(0.5, 0.3, 0.0)  # Brown
	light.variable_color = Color(0.15, 0.15, 0.15)
	light.constant_color = Color(0.4, 0.0, 0.6)  # Purple
	light.property_color = Color(0.0, 0.4, 0.4)
	light.builtin_color = Color(0.0, 0.0, 0.7)
	light.error_color = Color(0.8, 0.0, 0.0)
	light.warning_color = Color(0.7, 0.5, 0.0)
	light.font_name = "Consolas"
	light.font_size = 12
	light.font_bold_keywords = true
	# IDE chrome — clean white panels
	light.ide_panel_bg = Color(0.96, 0.96, 0.96)
	light.ide_panel_border = Color(0.82, 0.82, 0.82)
	light.ide_header_bg = Color(0.88, 0.88, 0.88)
	light.ide_header_border = Color(0.78, 0.78, 0.78)
	light.ide_header_text = Color(0.2, 0.2, 0.2)
	light.ide_text_color = Color(0.15, 0.15, 0.15)
	light.ide_list_bg = Color.WHITE
	light.ide_tab_selected_bg = Color(0.96, 0.96, 0.96)
	light.ide_tab_unselected_bg = Color(0.9, 0.9, 0.9)
	light.ide_tab_hover_bg = Color(0.98, 0.98, 0.98)
	light.ide_btn_hover_bg = Color(0.92, 0.92, 0.92)
	light.ide_btn_pressed_bg = Color(0.86, 0.86, 0.86)
	light.ide_toolbox_btn_hover = Color(0.88, 0.92, 1.0)
	light.ide_toolbox_btn_pressed = Color(0.26, 0.59, 0.98)
	light.ide_toolbox_text_pressed = Color.WHITE
	light.ide_accent_color = Color(0.0, 0.47, 0.84)
	light.ide_tooltip_bg = Color(1.0, 1.0, 0.94)
	_themes["Modern Light"] = light
	
	# --- High Contrast ---
	var hc = VGTheme.new()
	hc.name = "High Contrast"
	hc.description = "High contrast for accessibility"
	hc.is_builtin = true
	hc.background_color = Color.BLACK
	hc.text_color = Color.WHITE
	hc.line_number_color = Color(0.7, 0.7, 0.7)
	hc.current_line_color = Color(0.15, 0.15, 0.15)
	hc.selection_color = Color(0.4, 0.4, 0.8, 0.6)
	hc.caret_color = Color.YELLOW
	hc.keyword_color = Color(0.0, 1.0, 1.0)  # Bright cyan
	hc.type_color = Color(0.5, 1.0, 0.5)  # Bright green
	hc.string_color = Color(1.0, 0.7, 0.4)  # Orange
	hc.number_color = Color(0.7, 1.0, 0.7)  # Light green
	hc.comment_color = Color(0.6, 0.8, 0.6)  # Muted green
	hc.operator_color = Color.WHITE
	hc.function_color = Color(1.0, 1.0, 0.4)  # Bright yellow
	hc.variable_color = Color.WHITE
	hc.constant_color = Color(1.0, 0.5, 1.0)  # Pink
	hc.property_color = Color(0.7, 1.0, 1.0)
	hc.builtin_color = Color(0.0, 1.0, 1.0)
	hc.error_color = Color(1.0, 0.4, 0.4)
	hc.warning_color = Color(1.0, 1.0, 0.0)
	hc.font_name = "Courier New"
	hc.font_size = 14
	hc.font_bold_keywords = true
	# IDE chrome — high contrast black/white
	hc.ide_panel_bg = Color(0.05, 0.05, 0.05)
	hc.ide_panel_border = Color.WHITE
	hc.ide_header_bg = Color(0.0, 0.0, 0.3)
	hc.ide_header_border = Color.WHITE
	hc.ide_header_text = Color.YELLOW
	hc.ide_text_color = Color.WHITE
	hc.ide_list_bg = Color.BLACK
	hc.ide_tab_selected_bg = Color(0.05, 0.05, 0.05)
	hc.ide_tab_unselected_bg = Color(0.15, 0.15, 0.15)
	hc.ide_tab_hover_bg = Color(0.2, 0.2, 0.2)
	hc.ide_btn_hover_bg = Color(0.2, 0.2, 0.2)
	hc.ide_btn_pressed_bg = Color(0.3, 0.3, 0.3)
	hc.ide_toolbox_btn_hover = Color(0.2, 0.2, 0.2)
	hc.ide_toolbox_btn_pressed = Color(0.0, 0.0, 0.6)
	hc.ide_toolbox_text_pressed = Color.YELLOW
	hc.ide_accent_color = Color.YELLOW
	hc.ide_tooltip_bg = Color(0.1, 0.1, 0.1)
	_themes["High Contrast"] = hc
	
	# --- Solarized Dark ---
	var solar_dark = VGTheme.new()
	solar_dark.name = "Solarized Dark"
	solar_dark.description = "Solarized dark color scheme"
	solar_dark.is_builtin = true
	solar_dark.background_color = Color(0.0, 0.17, 0.21)
	solar_dark.text_color = Color(0.51, 0.58, 0.59)
	solar_dark.line_number_color = Color(0.35, 0.43, 0.46)
	solar_dark.current_line_color = Color(0.03, 0.21, 0.26)
	solar_dark.selection_color = Color(0.07, 0.25, 0.32, 0.5)
	solar_dark.caret_color = Color(0.51, 0.58, 0.59)
	solar_dark.keyword_color = Color(0.52, 0.6, 0.0)  # Green
	solar_dark.type_color = Color(0.15, 0.55, 0.82)  # Blue
	solar_dark.string_color = Color(0.16, 0.63, 0.6)  # Cyan
	solar_dark.number_color = Color(0.8, 0.29, 0.09)  # Orange
	solar_dark.comment_color = Color(0.35, 0.43, 0.46)  # Base01
	solar_dark.operator_color = Color(0.51, 0.58, 0.59)
	solar_dark.function_color = Color(0.15, 0.55, 0.82)
	solar_dark.variable_color = Color(0.51, 0.58, 0.59)
	solar_dark.constant_color = Color(0.71, 0.54, 0.0)  # Yellow
	solar_dark.property_color = Color(0.16, 0.63, 0.6)
	solar_dark.builtin_color = Color(0.52, 0.6, 0.0)
	solar_dark.error_color = Color(0.86, 0.2, 0.18)
	solar_dark.warning_color = Color(0.71, 0.54, 0.0)
	solar_dark.font_name = "Source Code Pro"
	solar_dark.font_size = 12
	solar_dark.font_bold_keywords = false
	# IDE chrome — solarized dark panels
	solar_dark.ide_panel_bg = Color(0.03, 0.21, 0.26)
	solar_dark.ide_panel_border = Color(0.07, 0.25, 0.32)
	solar_dark.ide_header_bg = Color(0.0, 0.17, 0.21)
	solar_dark.ide_header_border = Color(0.07, 0.25, 0.32)
	solar_dark.ide_header_text = Color(0.51, 0.58, 0.59)
	solar_dark.ide_text_color = Color(0.51, 0.58, 0.59)
	solar_dark.ide_list_bg = Color(0.0, 0.17, 0.21)
	solar_dark.ide_tab_selected_bg = Color(0.03, 0.21, 0.26)
	solar_dark.ide_tab_unselected_bg = Color(0.0, 0.15, 0.18)
	solar_dark.ide_tab_hover_bg = Color(0.05, 0.25, 0.3)
	solar_dark.ide_btn_hover_bg = Color(0.05, 0.25, 0.3)
	solar_dark.ide_btn_pressed_bg = Color(0.0, 0.17, 0.21)
	solar_dark.ide_toolbox_btn_hover = Color(0.05, 0.25, 0.3)
	solar_dark.ide_toolbox_btn_pressed = Color(0.15, 0.55, 0.82)
	solar_dark.ide_toolbox_text_pressed = Color.WHITE
	solar_dark.ide_accent_color = Color(0.15, 0.55, 0.82)
	solar_dark.ide_tooltip_bg = Color(0.03, 0.21, 0.26)
	_themes["Solarized Dark"] = solar_dark

# =============================================================================
# PUBLIC API
# =============================================================================

## Get all available theme names
static func get_theme_names() -> Array[String]:
	_ensure_initialized()
	var names: Array[String] = []
	for n in _themes:
		names.append(n)
	names.sort()
	return names

## Get a theme by name
static func get_theme(name: String) -> VGTheme:
	_ensure_initialized()
	if _themes.has(name):
		return _themes[name]
	return null

## Get the current theme
static func get_current_theme() -> VGTheme:
	_ensure_initialized()
	if _themes.has(_current_theme):
		return _themes[_current_theme]
	return _themes["VB6 Classic"]

## Set the current theme
static func set_current_theme(name: String) -> bool:
	_ensure_initialized()
	if _themes.has(name):
		_current_theme = name
		save_settings()
		return true
	return false

## Add a custom theme
static func add_custom_theme(theme: VGTheme) -> void:
	_ensure_initialized()
	theme.is_builtin = false
	_themes[theme.name] = theme
	save_user_themes()

## Remove a custom theme
static func remove_theme(name: String) -> bool:
	_ensure_initialized()
	if _themes.has(name) and not _themes[name].is_builtin:
		_themes.erase(name)
		if _current_theme == name:
			_current_theme = "VB6 Classic"
		save_user_themes()
		return true
	return false

## Create a theme from current + modifications
static func create_from_current(new_name: String) -> VGTheme:
	var current = get_current_theme()
	var new_theme = current.duplicate()
	new_theme.name = new_name
	new_theme.is_builtin = false
	return new_theme

# =============================================================================
# SYNTAX HIGHLIGHTER INTEGRATION
# =============================================================================

## Generate syntax colors dictionary for editor
static func get_syntax_colors() -> Dictionary:
	var theme = get_current_theme()
	return {
		"background": theme.background_color,
		"text": theme.text_color,
		"keyword": theme.keyword_color,
		"type": theme.type_color,
		"string": theme.string_color,
		"number": theme.number_color,
		"comment": theme.comment_color,
		"operator": theme.operator_color,
		"function": theme.function_color,
		"variable": theme.variable_color,
		"constant": theme.constant_color,
		"property": theme.property_color,
		"builtin": theme.builtin_color,
		"error": theme.error_color,
		"warning": theme.warning_color
	}

## Apply theme to a CodeEdit node
static func apply_to_code_edit(code_edit: CodeEdit) -> void:
	var theme = get_current_theme()
	
	# Ensure line numbers and code folding are enabled
	code_edit.gutters_draw_line_numbers = true
	code_edit.set("line_folding_enabled", true)
	code_edit.set("gutters_draw_folding", true)
	
	# Background and text
	code_edit.add_theme_color_override("background_color", theme.background_color)
	code_edit.add_theme_color_override("font_color", theme.text_color)
	code_edit.add_theme_color_override("line_number_color", theme.line_number_color)
	code_edit.add_theme_color_override("current_line_color", theme.current_line_color)
	code_edit.add_theme_color_override("selection_color", theme.selection_color)
	code_edit.add_theme_color_override("caret_color", theme.caret_color)

	# ── Re-color the syntax highlighter to match the theme ──
	# VGCodeEdit sets up a CodeHighlighter with dark-background colors by
	# default.  We must override those whenever a theme is applied so that
	# keywords, comments, strings, etc. are legible on the actual background.
	if code_edit.syntax_highlighter and code_edit.syntax_highlighter is CodeHighlighter:
		var hl: CodeHighlighter = code_edit.syntax_highlighter
		# Bulk-recolor every registered keyword to the theme keyword color
		var kw_dict: Dictionary = hl.keyword_colors
		for kw_key in kw_dict.keys():
			hl.add_keyword_color(kw_key, theme.keyword_color)
		hl.number_color = theme.number_color
		hl.symbol_color = theme.operator_color
		hl.function_color = theme.function_color
		hl.member_variable_color = theme.variable_color
		# Re-apply color regions (comments + strings) — clear and rebuild
		hl.clear_color_regions()
		hl.add_color_region("'", "", theme.comment_color, true)
		hl.add_color_region("REM ", "", theme.comment_color, true)
		hl.add_color_region('"', '"', theme.string_color)

	# ── Scrollbar styling ──
	# Godot inherits scrollbar colors from the editor theme which can make
	# the grabber invisible on light code-editor backgrounds.  Explicitly
	# style the vertical and horizontal scrollbars so they are always visible.
	var is_light_bg: bool = theme.background_color.get_luminance() > 0.5
	if is_light_bg:
		var scroll_grabber := StyleBoxFlat.new()
		scroll_grabber.bg_color = Color(0.48, 0.47, 0.44)  # solid gray — clearly visible
		scroll_grabber.corner_radius_top_left = 3
		scroll_grabber.corner_radius_top_right = 3
		scroll_grabber.corner_radius_bottom_left = 3
		scroll_grabber.corner_radius_bottom_right = 3
		var scroll_grabber_hl := StyleBoxFlat.new()
		scroll_grabber_hl.bg_color = Color(0.38, 0.37, 0.35)  # darker on hover
		scroll_grabber_hl.corner_radius_top_left = 3
		scroll_grabber_hl.corner_radius_top_right = 3
		scroll_grabber_hl.corner_radius_bottom_left = 3
		scroll_grabber_hl.corner_radius_bottom_right = 3
		var scroll_grabber_pressed := StyleBoxFlat.new()
		scroll_grabber_pressed.bg_color = Color(0.28, 0.28, 0.26)  # darkest when pressed
		scroll_grabber_pressed.corner_radius_top_left = 3
		scroll_grabber_pressed.corner_radius_top_right = 3
		scroll_grabber_pressed.corner_radius_bottom_left = 3
		scroll_grabber_pressed.corner_radius_bottom_right = 3
		var scroll_track := StyleBoxFlat.new()
		scroll_track.bg_color = Color(0.86, 0.85, 0.82)  # warm track
		for bar_node in code_edit.get_children():
			if bar_node is VScrollBar or bar_node is HScrollBar:
				bar_node.add_theme_stylebox_override("grabber", scroll_grabber)
				bar_node.add_theme_stylebox_override("grabber_highlight", scroll_grabber_hl)
				bar_node.add_theme_stylebox_override("grabber_pressed", scroll_grabber_pressed)
				bar_node.add_theme_stylebox_override("scroll", scroll_track)

## Get the current theme's IDE chrome colors as a Dictionary
## (compatible with the plugin's _theme dictionary format)
static func get_ide_colors() -> Dictionary:
	var t = get_current_theme()
	return {
		"panel_background": t.ide_panel_bg,
		"panel_border": t.ide_panel_border,
		"header_background": t.ide_header_bg,
		"header_border": t.ide_header_border,
		"header_text": t.ide_header_text,
		"ide_text_color": t.ide_text_color,
		"ide_list_bg": t.ide_list_bg,
		"ide_tab_selected_bg": t.ide_tab_selected_bg,
		"ide_tab_unselected_bg": t.ide_tab_unselected_bg,
		"ide_tab_hover_bg": t.ide_tab_hover_bg,
		"ide_btn_hover_bg": t.ide_btn_hover_bg,
		"ide_btn_pressed_bg": t.ide_btn_pressed_bg,
		"toolbox_btn_normal": t.ide_panel_bg,
		"toolbox_btn_hover": t.ide_toolbox_btn_hover,
		"toolbox_btn_pressed": t.ide_toolbox_btn_pressed,
		"toolbox_text": t.ide_text_color,
		"toolbox_text_pressed": t.ide_toolbox_text_pressed,
		"ide_accent_color": t.ide_accent_color,
		"ide_tooltip_bg": t.ide_tooltip_bg,
	}

## Generate CSS-like style string for export
static func export_theme_css(theme: VGTheme) -> String:
	return """/* VisualGasic Theme: %s */
.vg-editor {
    background-color: %s;
    color: %s;
    font-family: '%s', monospace;
    font-size: %dpx;
}
.vg-keyword { color: %s; font-weight: %s; }
.vg-type { color: %s; }
.vg-string { color: %s; }
.vg-number { color: %s; }
.vg-comment { color: %s; font-style: italic; }
.vg-function { color: %s; }
.vg-variable { color: %s; }
.vg-constant { color: %s; }
.vg-error { color: %s; text-decoration: wavy underline; }
""" % [
		theme.name,
		theme.background_color.to_html(),
		theme.text_color.to_html(),
		theme.font_name,
		theme.font_size,
		theme.keyword_color.to_html(),
		"bold" if theme.font_bold_keywords else "normal",
		theme.type_color.to_html(),
		theme.string_color.to_html(),
		theme.number_color.to_html(),
		theme.comment_color.to_html(),
		theme.function_color.to_html(),
		theme.variable_color.to_html(),
		theme.constant_color.to_html(),
		theme.error_color.to_html()
	]

# =============================================================================
# PERSISTENCE
# =============================================================================

const SETTINGS_PATH = "user://vg_theme_settings.cfg"
const USER_THEMES_PATH = "user://vg_custom_themes.cfg"

static func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("theme", "current", _current_theme)
	config.save(SETTINGS_PATH)

static func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_current_theme = config.get_value("theme", "current", "VB6 Classic")

static func save_user_themes() -> void:
	var config = ConfigFile.new()
	
	for name in _themes:
		var theme = _themes[name]
		if theme.is_builtin:
			continue
		
		var section = name
		config.set_value(section, "description", theme.description)
		config.set_value(section, "background_color", theme.background_color.to_html())
		config.set_value(section, "text_color", theme.text_color.to_html())
		config.set_value(section, "line_number_color", theme.line_number_color.to_html())
		config.set_value(section, "current_line_color", theme.current_line_color.to_html())
		config.set_value(section, "selection_color", theme.selection_color.to_html())
		config.set_value(section, "caret_color", theme.caret_color.to_html())
		config.set_value(section, "keyword_color", theme.keyword_color.to_html())
		config.set_value(section, "type_color", theme.type_color.to_html())
		config.set_value(section, "string_color", theme.string_color.to_html())
		config.set_value(section, "number_color", theme.number_color.to_html())
		config.set_value(section, "comment_color", theme.comment_color.to_html())
		config.set_value(section, "operator_color", theme.operator_color.to_html())
		config.set_value(section, "function_color", theme.function_color.to_html())
		config.set_value(section, "variable_color", theme.variable_color.to_html())
		config.set_value(section, "constant_color", theme.constant_color.to_html())
		config.set_value(section, "property_color", theme.property_color.to_html())
		config.set_value(section, "builtin_color", theme.builtin_color.to_html())
		config.set_value(section, "error_color", theme.error_color.to_html())
		config.set_value(section, "warning_color", theme.warning_color.to_html())
		config.set_value(section, "font_name", theme.font_name)
		config.set_value(section, "font_size", theme.font_size)
		config.set_value(section, "font_bold_keywords", theme.font_bold_keywords)
		# IDE chrome colors
		config.set_value(section, "ide_panel_bg", theme.ide_panel_bg.to_html())
		config.set_value(section, "ide_panel_border", theme.ide_panel_border.to_html())
		config.set_value(section, "ide_header_bg", theme.ide_header_bg.to_html())
		config.set_value(section, "ide_header_border", theme.ide_header_border.to_html())
		config.set_value(section, "ide_header_text", theme.ide_header_text.to_html())
		config.set_value(section, "ide_text_color", theme.ide_text_color.to_html())
		config.set_value(section, "ide_list_bg", theme.ide_list_bg.to_html())
		config.set_value(section, "ide_accent_color", theme.ide_accent_color.to_html())
	
	config.save(USER_THEMES_PATH)

static func load_user_themes() -> void:
	load_settings()
	
	var config = ConfigFile.new()
	if config.load(USER_THEMES_PATH) != OK:
		return
	
	for section in config.get_sections():
		var theme = VGTheme.new()
		theme.name = section
		theme.description = config.get_value(section, "description", "")
		theme.is_builtin = false
		
		theme.background_color = Color.from_string(config.get_value(section, "background_color", "#000000"), Color.BLACK)
		theme.text_color = Color.from_string(config.get_value(section, "text_color", "#FFFFFF"), Color.WHITE)
		theme.line_number_color = Color.from_string(config.get_value(section, "line_number_color", "#808080"), Color.GRAY)
		theme.current_line_color = Color.from_string(config.get_value(section, "current_line_color", "#1A1A1A"), Color.DIM_GRAY)
		theme.selection_color = Color.from_string(config.get_value(section, "selection_color", "#4080C080"), Color(0.25, 0.5, 0.75, 0.5))
		theme.caret_color = Color.from_string(config.get_value(section, "caret_color", "#FFFFFF"), Color.WHITE)
		theme.keyword_color = Color.from_string(config.get_value(section, "keyword_color", "#00FFFF"), Color.CYAN)
		theme.type_color = Color.from_string(config.get_value(section, "type_color", "#00AAAA"), Color.DARK_CYAN)
		theme.string_color = Color.from_string(config.get_value(section, "string_color", "#FF8080"), Color.INDIAN_RED)
		theme.number_color = Color.from_string(config.get_value(section, "number_color", "#80FF80"), Color.PALE_GREEN)
		theme.comment_color = Color.from_string(config.get_value(section, "comment_color", "#80FF80"), Color.GREEN)
		theme.operator_color = Color.from_string(config.get_value(section, "operator_color", "#FFFFFF"), Color.WHITE)
		theme.function_color = Color.from_string(config.get_value(section, "function_color", "#8080FF"), Color.CORNFLOWER_BLUE)
		theme.variable_color = Color.from_string(config.get_value(section, "variable_color", "#FFFFFF"), Color.WHITE)
		theme.constant_color = Color.from_string(config.get_value(section, "constant_color", "#FFA500"), Color.ORANGE)
		theme.property_color = Color.from_string(config.get_value(section, "property_color", "#80FFFF"), Color.AQUA)
		theme.builtin_color = Color.from_string(config.get_value(section, "builtin_color", "#00FFFF"), Color.CYAN)
		theme.error_color = Color.from_string(config.get_value(section, "error_color", "#FF4040"), Color.RED)
		theme.warning_color = Color.from_string(config.get_value(section, "warning_color", "#FFCC00"), Color.GOLD)
		theme.font_name = config.get_value(section, "font_name", "Courier New")
		theme.font_size = config.get_value(section, "font_size", 12)
		theme.font_bold_keywords = config.get_value(section, "font_bold_keywords", true)
		# IDE chrome colors
		theme.ide_panel_bg = Color.from_string(config.get_value(section, "ide_panel_bg", "#F0EDE8"), Color("#F0EDE8"))
		theme.ide_panel_border = Color.from_string(config.get_value(section, "ide_panel_border", "#B8B5AD"), Color(0.72, 0.71, 0.68))
		theme.ide_header_bg = Color.from_string(config.get_value(section, "ide_header_bg", "#94949E"), Color(0.58, 0.58, 0.62))
		theme.ide_header_border = Color.from_string(config.get_value(section, "ide_header_border", "#666666"), Color(0.4, 0.4, 0.4))
		theme.ide_header_text = Color.from_string(config.get_value(section, "ide_header_text", "#FFFFFF"), Color.WHITE)
		theme.ide_text_color = Color.from_string(config.get_value(section, "ide_text_color", "#000000"), Color.BLACK)
		theme.ide_list_bg = Color.from_string(config.get_value(section, "ide_list_bg", "#FFFFFF"), Color.WHITE)
		theme.ide_accent_color = Color.from_string(config.get_value(section, "ide_accent_color", "#000080"), Color(0.0, 0.0, 0.5))
		
		_themes[section] = theme
