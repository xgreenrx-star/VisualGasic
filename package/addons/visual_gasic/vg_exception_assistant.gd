@tool
extends AcceptDialog
## VB6-Style Exception Assistant
##
## Shows a professional error popup when an unhandled runtime error occurs.
## Provides Debug (pause at error), End (stop game), and Help buttons,
## along with the error message, code, file/line, and crash-site variables.

signal debug_requested()   ## User chose to stay paused and inspect
signal end_requested()     ## User chose to stop the game
signal continue_requested()  ## User chose to continue past the error
signal ai_help_requested(file: String, line: int, message: String, code: int, variables: Dictionary)  ## User wants AI to explain

var _error_label: RichTextLabel
var _vars_tree: Tree
var _file_label: Label
var _line_label: Label
var _code_label: Label
var _debug_btn: Button
var _end_btn: Button
var _continue_btn: Button
var _ai_btn: Button
var _last_file := ""
var _last_line := 0
var _last_message := ""
var _last_code := 0
var _last_variables := {}

func _init() -> void:
	title = "⚠️ VisualGasic Runtime Error"
	exclusive = true
	min_size = Vector2i(550, 400)
	# Remove the default OK button — we'll add our own
	get_ok_button().visible = false

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	var main_vbox := VBoxContainer.new()
	add_child(main_vbox)
	
	# ── Error icon + title row ──
	var header := HBoxContainer.new()
	main_vbox.add_child(header)
	
	var icon_label := Label.new()
	icon_label.text = "🛑"
	icon_label.add_theme_font_size_override("font_size", 32)
	header.add_child(icon_label)
	
	var header_text := Label.new()
	header_text.text = "  An unhandled runtime error has occurred."
	header_text.add_theme_font_size_override("font_size", 14)
	header.add_child(header_text)
	
	main_vbox.add_child(HSeparator.new())
	
	# ── Error details ──
	var details := GridContainer.new()
	details.columns = 2
	main_vbox.add_child(details)
	
	var lbl_err := Label.new()
	lbl_err.text = "Error Code:"
	lbl_err.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	details.add_child(lbl_err)
	_code_label = Label.new()
	_code_label.text = "0"
	details.add_child(_code_label)
	
	var lbl_file := Label.new()
	lbl_file.text = "File:"
	lbl_file.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	details.add_child(lbl_file)
	_file_label = Label.new()
	_file_label.text = ""
	details.add_child(_file_label)
	
	var lbl_line := Label.new()
	lbl_line.text = "Line:"
	lbl_line.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	details.add_child(lbl_line)
	_line_label = Label.new()
	_line_label.text = "0"
	details.add_child(_line_label)
	
	# ── Error message ──
	_error_label = RichTextLabel.new()
	_error_label.bbcode_enabled = true
	_error_label.fit_content = true
	_error_label.custom_minimum_size = Vector2(0, 60)
	_error_label.scroll_active = false
	main_vbox.add_child(_error_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# ── Variables at crash site ──
	var vars_header := Label.new()
	vars_header.text = "Variables at error site:"
	vars_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	main_vbox.add_child(vars_header)
	
	_vars_tree = Tree.new()
	_vars_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vars_tree.columns = 2
	_vars_tree.set_column_title(0, "Variable")
	_vars_tree.set_column_title(1, "Value")
	_vars_tree.column_titles_visible = true
	_vars_tree.custom_minimum_size = Vector2(0, 120)
	main_vbox.add_child(_vars_tree)
	
	main_vbox.add_child(HSeparator.new())
	
	# ── Action buttons (VB6 style: Debug, Continue, End) ──
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(btn_row)
	
	_debug_btn = Button.new()
	_debug_btn.text = "🔍 Debug"
	_debug_btn.tooltip_text = "Stay paused at the error to inspect state"
	_debug_btn.custom_minimum_size = Vector2(120, 36)
	_debug_btn.pressed.connect(_on_debug)
	btn_row.add_child(_debug_btn)
	
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(20, 0)
	btn_row.add_child(spacer1)
	
	_continue_btn = Button.new()
	_continue_btn.text = "▶ Continue"
	_continue_btn.tooltip_text = "Continue execution past the error"
	_continue_btn.custom_minimum_size = Vector2(120, 36)
	_continue_btn.pressed.connect(_on_continue)
	btn_row.add_child(_continue_btn)
	
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(20, 0)
	btn_row.add_child(spacer2)
	
	_end_btn = Button.new()
	_end_btn.text = "⏹ End"
	_end_btn.tooltip_text = "Stop the running game"
	_end_btn.custom_minimum_size = Vector2(120, 36)
	_end_btn.pressed.connect(_on_end)
	btn_row.add_child(_end_btn)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(20, 0)
	btn_row.add_child(spacer3)

	_ai_btn = Button.new()
	_ai_btn.text = "🤖 Ask AI"
	_ai_btn.tooltip_text = "Ask AI to explain this error and suggest a fix"
	_ai_btn.custom_minimum_size = Vector2(120, 36)
	_ai_btn.pressed.connect(_on_ask_ai)
	btn_row.add_child(_ai_btn)

func show_error(file: String, line: int, message: String, code: int, variables: Dictionary = {}) -> void:
	## Show the exception assistant with error details.
	_last_file = file
	_last_line = line
	_last_message = message
	_last_code = code
	_last_variables = variables.duplicate()
	_file_label.text = file.get_file() if not file.is_empty() else "(unknown)"
	_line_label.text = str(line)
	_code_label.text = str(code)
	_error_label.text = "[color=red][b]Runtime Error %d:[/b][/color]\n[color=white]%s[/color]" % [code, message]
	
	# Populate variables tree
	_vars_tree.clear()
	var root = _vars_tree.create_item()
	for var_name in variables:
		# Skip internal VB constants
		if str(var_name).begins_with("vb"):
			continue
		var item = _vars_tree.create_item(root)
		item.set_text(0, str(var_name))
		item.set_text(1, str(variables[var_name]))
		item.set_custom_color(0, Color(0.8, 0.9, 1.0))
		item.set_custom_color(1, Color(0.6, 1.0, 0.6))
	
	popup_centered()
	move_to_foreground()
	_debug_btn.grab_focus()

func _on_debug() -> void:
	hide()
	debug_requested.emit()

func _on_continue() -> void:
	hide()
	continue_requested.emit()

func _on_end() -> void:
	hide()
	end_requested.emit()

func _on_ask_ai() -> void:
	hide()
	ai_help_requested.emit(_last_file, _last_line, _last_message, _last_code, _last_variables)
