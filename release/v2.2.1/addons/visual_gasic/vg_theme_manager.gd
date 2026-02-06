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

## A complete syntax highlighting theme
class VGTheme:
	var name: String = ""
	var description: String = ""
	var is_builtin: bool = false
	
	# Editor colors
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
	# --- VB6 Classic (Authentic) ---
	var classic = VGTheme.new()
	classic.name = "VB6 Classic"
	classic.description = "Authentic Visual Basic 6 IDE colors"
	classic.is_builtin = true
	classic.background_color = Color(0.0, 0.0, 0.5)  # Dark blue
	classic.text_color = Color(1.0, 1.0, 0.0)  # Yellow
	classic.line_number_color = Color(0.6, 0.6, 0.6)
	classic.current_line_color = Color(0.1, 0.1, 0.6)
	classic.selection_color = Color(0.3, 0.3, 0.8, 0.5)
	classic.caret_color = Color.WHITE
	classic.keyword_color = Color(0.0, 1.0, 1.0)  # Cyan
	classic.type_color = Color(0.6, 1.0, 0.6)  # Light green
	classic.string_color = Color(1.0, 0.6, 0.6)  # Light red
	classic.number_color = Color(1.0, 0.5, 1.0)  # Pink
	classic.comment_color = Color(0.5, 1.0, 0.5)  # Green
	classic.operator_color = Color(1.0, 1.0, 0.0)  # Yellow
	classic.function_color = Color(0.8, 0.8, 1.0)  # Light blue
	classic.variable_color = Color(1.0, 1.0, 0.0)  # Yellow
	classic.constant_color = Color(1.0, 0.7, 0.3)  # Orange
	classic.property_color = Color(0.8, 1.0, 0.8)
	classic.builtin_color = Color(0.0, 1.0, 1.0)  # Cyan
	classic.error_color = Color(1.0, 0.3, 0.3)
	classic.warning_color = Color(1.0, 0.8, 0.2)
	classic.font_name = "Courier New"
	classic.font_size = 10
	classic.font_bold_keywords = true
	_themes["VB6 Classic"] = classic
	
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
	
	# Background and text
	code_edit.add_theme_color_override("background_color", theme.background_color)
	code_edit.add_theme_color_override("font_color", theme.text_color)
	code_edit.add_theme_color_override("line_number_color", theme.line_number_color)
	code_edit.add_theme_color_override("current_line_color", theme.current_line_color)
	code_edit.add_theme_color_override("selection_color", theme.selection_color)
	code_edit.add_theme_color_override("caret_color", theme.caret_color)

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
		
		_themes[section] = theme
