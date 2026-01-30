@tool
extends Control

## Interactive Development Console
## Execute code expressions and statements in real-time during development

var _repl: Object = null
var _history: Array[String] = []
var _history_index: int = -1
var _output_text: RichTextLabel
var _input_field: CodeEdit
var _send_button: Button
var _clear_button: Button
var _variables: Dictionary = {}
var _watch_expressions: Array[Dictionary] = []
var _var_tree: Tree
var _watch_tree: Tree
var _inspector_tree: Tree
var _current_inspected_object: Object = null
var _auto_complete_popup: PopupMenu
var _session_history: Array[String] = []

func _ready():
	_setup_ui()
	_initialize_repl()
	_show_welcome()

func _setup_ui():
	# Main horizontal split: Console (left) + Panels (right)
	var main_split = HSplitContainer.new()
	main_split.anchor_right = 1.0
	main_split.anchor_bottom = 1.0
	add_child(main_split)
	
	# Left side: Console
	var console_vbox = VBoxContainer.new()
	console_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_vbox.custom_minimum_size = Vector2(400, 0)
	main_split.add_child(console_vbox)
	
	# Toolbar
	var toolbar = HBoxContainer.new()
	console_vbox.add_child(toolbar)
	
	var title = Label.new()
	title.text = "Immediate Window"
	title.add_theme_font_size_override("font_size", 14)
	toolbar.add_child(title)
	
	toolbar.add_child(Control.new()) # Spacer
	toolbar.get_child(-1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Quick action buttons
	var repeat_btn = Button.new()
	repeat_btn.text = "↻ Repeat"
	repeat_btn.tooltip_text = "Repeat last command (Ctrl+R)"
	repeat_btn.pressed.connect(_repeat_last)
	toolbar.add_child(repeat_btn)
	
	var save_btn = Button.new()
	save_btn.text = "💾 Save"
	save_btn.tooltip_text = "Save session to file"
	save_btn.pressed.connect(_save_session)
	toolbar.add_child(save_btn)
	
	var load_btn = Button.new()
	load_btn.text = "📂 Load"
	load_btn.tooltip_text = "Load session from file"
	load_btn.pressed.connect(_load_session)
	toolbar.add_child(load_btn)
	
	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.pressed.connect(_on_clear_pressed)
	toolbar.add_child(_clear_button)
	
	var help_button = Button.new()
	help_button.text = "Help"
	help_button.pressed.connect(_show_help)
	toolbar.add_child(help_button)
	
	# Output area
	_output_text = RichTextLabel.new()
	_output_text.bbcode_enabled = true
	_output_text.scroll_following = true
	_output_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output_text.custom_minimum_size = Vector2(0, 200)
	_output_text.context_menu_enabled = true
	_output_text.selection_enabled = true
	console_vbox.add_child(_output_text)
	
	# Input area with multi-line support
	var input_container = VBoxContainer.new()
	console_vbox.add_child(input_container)
	
	var input_label = Label.new()
	input_label.text = "Input (Shift+Enter for new line, Enter to execute):"
	input_container.add_child(input_label)
	
	var input_hbox = HBoxContainer.new()
	input_container.add_child(input_hbox)
	
	_input_field = CodeEdit.new()
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.custom_minimum_size = Vector2(0, 60)
	_input_field.placeholder_text = "Type expression or statement... (Shift+Enter: new line, Enter: execute)"
	_input_field.syntax_highlighter = _create_syntax_highlighter()
	_input_field.gutters_draw_line_numbers = true
	_input_field.auto_brace_completion_enabled = true
	_input_field.code_completion_enabled = true
	_input_field.gui_input.connect(_on_input_gui_input)
	input_hbox.add_child(_input_field)
	
	_send_button = Button.new()
	_send_button.text = "Execute\n(Enter)"
	_send_button.pressed.connect(_on_send_pressed)
	input_hbox.add_child(_send_button)
	
	# Right side: Tabbed panels (Variables, Watch, Inspector)
	var right_tabs = TabContainer.new()
	right_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_tabs.custom_minimum_size = Vector2(300, 0)
	main_split.add_child(right_tabs)
	
	# Variables panel
	var var_panel = VBoxContainer.new()
	var_panel.name = "Variables"
	right_tabs.add_child(var_panel)
	
	var var_toolbar = HBoxContainer.new()
	var_panel.add_child(var_toolbar)
	
	var var_label = Label.new()
	var_label.text = "Session Variables"
	var_toolbar.add_child(var_label)
	
	var var_refresh = Button.new()
	var_refresh.text = "🔄"
	var_refresh.tooltip_text = "Refresh variables"
	var_refresh.pressed.connect(_refresh_variables)
	var_toolbar.add_child(var_refresh)
	
	_var_tree = Tree.new()
	_var_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_var_tree.columns = 3
	_var_tree.set_column_title(0, "Name")
	_var_tree.set_column_title(1, "Type")
	_var_tree.set_column_title(2, "Value")
	_var_tree.column_titles_visible = true
	_var_tree.item_activated.connect(_on_var_item_activated)
	var_panel.add_child(_var_tree)
	
	# Watch panel
	var watch_panel = VBoxContainer.new()
	watch_panel.name = "Watch"
	right_tabs.add_child(watch_panel)
	
	var watch_toolbar = HBoxContainer.new()
	watch_panel.add_child(watch_toolbar)
	
	var watch_label = Label.new()
	watch_label.text = "Watch Expressions"
	watch_toolbar.add_child(watch_label)
	
	var add_watch = Button.new()
	add_watch.text = "➕ Add"
	add_watch.pressed.connect(_add_watch_expression)
	watch_toolbar.add_child(add_watch)
	
	_watch_tree = Tree.new()
	_watch_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_watch_tree.columns = 2
	_watch_tree.set_column_title(0, "Expression")
	_watch_tree.set_column_title(1, "Value")
	_watch_tree.column_titles_visible = true
	_watch_tree.item_activated.connect(_on_watch_item_activated)
	watch_panel.add_child(_watch_tree)
	
	# Inspector panel
	var inspector_panel = VBoxContainer.new()
	inspector_panel.name = "Inspector"
	right_tabs.add_child(inspector_panel)
	
	var inspector_toolbar = HBoxContainer.new()
	inspector_panel.add_child(inspector_toolbar)
	
	var inspector_label = Label.new()
	inspector_label.text = "Object Inspector"
	inspector_toolbar.add_child(inspector_label)
	
	var pin_btn = Button.new()
	pin_btn.text = "📌"
	pin_btn.tooltip_text = "Pin current object"
	pin_btn.toggle_mode = true
	inspector_toolbar.add_child(pin_btn)
	
	var inspector_refresh = Button.new()
	inspector_refresh.text = "🔄"
	inspector_refresh.tooltip_text = "Refresh inspector"
	inspector_refresh.pressed.connect(_refresh_inspector)
	inspector_toolbar.add_child(inspector_refresh)
	
	var inspector_search = LineEdit.new()
	inspector_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_search.placeholder_text = "Filter properties..."
	inspector_search.text_changed.connect(_filter_inspector)
	inspector_toolbar.add_child(inspector_search)
	
	_inspector_tree = Tree.new()
	_inspector_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector_tree.columns = 2
	_inspector_tree.set_column_title(0, "Property")
	_inspector_tree.set_column_title(1, "Value")
	_inspector_tree.column_titles_visible = true
	_inspector_tree.item_activated.connect(_on_inspector_item_activated)
	inspector_panel.add_child(_inspector_tree)

func _initialize_repl():
	# Try to create REPL instance if available
	if ClassDB.class_exists("VisualGasicREPL"):
		# Would need C++ REPL exposed to GDScript
		pass
	_append_output("[color=gray]Interactive console ready[/color]\n")

func _show_welcome():
	_append_output("[b]Interactive Development Console[/b]\n")
	_append_output("[color=gray]Execute expressions and statements in real-time[/color]\n")
	_append_output("[color=gray]Type ':help' for available commands[/color]\n\n")

func _show_help():
	_append_output("\n[b]Available Commands:[/b]\n")
	_append_output("  :help     - Show this help message\n")
	_append_output("  :clear    - Clear output window\n")
	_append_output("  :vars     - List all variables\n")
	_append_output("  :history  - Show command history\n")
	_append_output("  :reset    - Reset console state\n")
	_append_output("  :watch [expr] - Add watch expression\n")
	_append_output("  :save [file] - Save session to file\n")
	_append_output("  :load [file] - Load session from file\n")
	_append_output("\n[b]Examples:[/b]\n")
	_append_output("  Print 2 + 2\n")
	_append_output("  Dim x As Integer = 42\n")
	_append_output("  x * 2\n")
	_append_output("  Len(\"Hello World\")\n")
	_append_output("\n[b]Shortcuts:[/b]\n")
	_append_output("  Shift+Enter - New line without executing\n")
	_append_output("  Enter - Execute code\n")
	_append_output("  Ctrl+R - Repeat last command\n")
	_append_output("  Ctrl+L - Clear output\n")
	_append_output("  Up/Down - Navigate history\n\n")

func _on_input_submitted(text: String):
	_execute_input(text)

func _on_input_gui_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER:
			if event.shift_pressed:
				# Shift+Enter: new line (default behavior)
				return
			else:
				# Enter alone: execute
				_execute_input(_input_field.text)
				accept_event()
		elif event.keycode == KEY_R and event.ctrl_pressed:
			_repeat_last()
			accept_event()
		elif event.keycode == KEY_L and event.ctrl_pressed:
			_on_clear_pressed()
			accept_event()
		elif event.keycode == KEY_SPACE and event.ctrl_pressed:
			# Trigger auto-completion
			_show_completions()
			accept_event()

func _on_send_pressed():
	_execute_input(_input_field.text)

func _execute_input(input: String):
	if input.strip_edges().is_empty():
		return
	
	# Add to history
	_history.append(input)
	_session_history.append(input)
	_history_index = _history.size()
	
	# Show input
	_append_output("[color=yellow]> " + input.replace("\n", "\n  ") + "[/color]\n")
	
	# Process commands
	if input.begins_with(":"):
		_process_command(input)
		_input_field.clear()
		_update_watch_expressions()
		return
	
	# Execute code
	var result = _evaluate_expression(input)
	_append_output(result + "\n")
	
	# Update variables display
	_refresh_variables()
	_update_watch_expressions()
	
	_input_field.clear()

func _process_command(cmd: String):
	var parts = cmd.substr(1).split(" ", false, 1)
	var command = parts[0].to_lower()
	var arg = parts[1] if parts.size() > 1 else ""
	
	match command:
		"help":
			_show_help()
		"clear":
			_output_text.clear()
			_show_welcome()
		"vars":
			_show_variables()
		"history":
			_show_history()
		"reset":
			_reset_console()
		"watch":
			if arg.is_empty():
				_append_output("[color=red]Usage: :watch [expression][/color]\n")
			else:
				_watch_expressions.append({"expr": arg, "value": ""})
				_update_watch_expressions()
				_append_output("[color=green]Added watch: " + arg + "[/color]\n")
		"save":
			_save_session_to_file(arg)
		"load":
			_load_session_from_file(arg)
		_:
			_append_output("[color=red]Unknown command: " + cmd + "[/color]\n")
			_append_output("[color=gray]Type :help for available commands[/color]\n")

func _show_variables():
	_append_output("\n[b]Variables:[/b]\n")
	if _variables.is_empty():
		_append_output("[color=gray]  No variables declared[/color]\n\n")
	else:
		for var_name in _variables.keys():
			var value = _variables[var_name]
			var type_name = _get_type_name(value)
			_append_output("  %s: %s = %s\n" % [var_name, type_name, str(value)])
		_append_output("\n")

func _show_history():
	_append_output("\n[b]Command History:[/b]\n")
	if _history.is_empty():
		_append_output("[color=gray]  No history yet[/color]\n\n")
	else:
		for i in range(_history.size()):
			_append_output("  %d: %s\n" % [i + 1, _history[i]])
		_append_output("\n")

func _reset_console():
	_output_text.clear()
	_history.clear()
	_session_history.clear()
	_history_index = -1
	_variables.clear()
	_watch_expressions.clear()
	_current_inspected_object = null
	_show_welcome()
	_refresh_variables()
	_update_watch_expressions()
	_refresh_inspector()
	_append_output("[color=green]Console reset complete[/color]\n\n")

func _evaluate_expression(expr: String) -> String:
	# Handle Print statements
	if expr.strip_edges().begins_with("Print "):
		var value = expr.substr(6).strip_edges()
		var evaluated = _eval_simple(value)
		return "[color=white]" + str(evaluated) + "[/color]"
	
	# Handle Dim declarations
	if expr.strip_edges().begins_with("Dim "):
		return _handle_dim_statement(expr)
	
	# Handle variable assignment
	if "=" in expr and not ("==" in expr or "<=" in expr or ">=" in expr):
		return _handle_assignment(expr)
	
	# Try to evaluate as expression
	var result = _eval_simple(expr)
	
	# Check if result is an object for inspection
	if result is Object:
		_inspect_object(result)
		return "[color=cyan]Object: " + result.get_class() + " [See Inspector][/color]"
	
	return "[color=cyan]" + str(result) + "[/color]"

func _handle_dim_statement(expr: String) -> String:
	# Parse: Dim varname As Type = value
	var parts = expr.substr(4).strip_edges().split("=", false, 1)
	var declaration = parts[0].strip_edges()
	var value_expr = parts[1].strip_edges() if parts.size() > 1 else "null"
	
	var decl_parts = declaration.split(" As ", false)
	var var_name = decl_parts[0].strip_edges()
	var var_type = decl_parts[1].strip_edges() if decl_parts.size() > 1 else "Variant"
	
	var value = _eval_simple(value_expr)
	_variables[var_name] = value
	
	return "[color=green]✓ " + var_name + ": " + var_type + " = " + str(value) + "[/color]"

func _handle_assignment(expr: String) -> String:
	var parts = expr.split("=", false, 1)
	var var_name = parts[0].strip_edges()
	var value_expr = parts[1].strip_edges()
	
	var value = _eval_simple(value_expr)
	_variables[var_name] = value
	
	return "[color=green]✓ " + var_name + " = " + str(value) + "[/color]"

func _eval_simple(expr: String) -> Variant:
	# Check if it's a variable reference
	if expr in _variables:
		return _variables[expr]
	
	# Try GDScript Expression parser
	var expression = Expression.new()
	var error = expression.parse(expr, _variables.keys())
	if error != OK:
		return "[ERROR] " + expression.get_error_text()
	
	var result = expression.execute(_variables.values())
	if expression.has_execute_failed():
		return "[ERROR] Execution failed"
	
	return result

func _get_type_name(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL: return "Null"
		TYPE_BOOL: return "Boolean"
		TYPE_INT: return "Integer"
		TYPE_FLOAT: return "Float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT: return value.get_class() if value != null else "Object"
		_: return "Variant"

func _append_output(text: String):
	_output_text.append_text(text)

func _on_clear_pressed():
	_output_text.clear()
	_show_welcome()

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if _input_field.has_focus():
			match event.keycode:
				KEY_UP:
					if not event.shift_pressed:
						_history_previous()
						accept_event()
				KEY_DOWN:
					if not event.shift_pressed:
						_history_next()
						accept_event()

func _history_previous():
	if _history.is_empty():
		return
	_history_index = max(0, _history_index - 1)
	_input_field.text = _history[_history_index]
	_input_field.set_caret_line(_input_field.get_line_count() - 1)
	_input_field.set_caret_column(_input_field.get_line(_input_field.get_line_count() - 1).length())

func _history_next():
	if _history.is_empty():
		return
	_history_index = min(_history.size(), _history_index + 1)
	if _history_index < _history.size():
		_input_field.text = _history[_history_index]
	else:
		_input_field.text = ""
	_input_field.set_caret_line(_input_field.get_line_count() - 1)
	_input_field.set_caret_column(_input_field.get_line(_input_field.get_line_count() - 1).length())

# === NEW FEATURES ===

func _create_syntax_highlighter() -> SyntaxHighlighter:
	# Create basic syntax highlighter
	var highlighter = CodeHighlighter.new()
	
	# Keywords
	var keywords = ["Dim", "As", "Integer", "String", "Float", "Boolean", "Array", "Dictionary",
					"If", "Then", "Else", "ElseIf", "End", "For", "To", "Next", "While", "Wend",
					"Sub", "Function", "Return", "Print", "Len", "Left", "Right", "Mid"]
	for keyword in keywords:
		highlighter.add_keyword_color(keyword, Color(1.0, 0.44, 0.52))
	
	# Numbers
	highlighter.number_color = Color(0.6, 0.8, 1.0)
	
	# Strings
	highlighter.add_color_region("\"", "\"", Color(1.0, 0.93, 0.5))
	
	# Comments
	highlighter.add_color_region("'", "", Color(0.4, 0.8, 0.4), true)
	
	return highlighter

func _show_completions():
	# Show auto-completion popup
	var completions = _get_completions(_input_field.text)
	if completions.is_empty():
		return
	
	# For now, just show in output
	_append_output("[color=gray]Suggestions: " + ", ".join(completions) + "[/color]\n")

func _get_completions(text: String) -> Array[String]:
	var completions: Array[String] = []
	var word = _get_current_word(text)
	
	if word.is_empty():
		return completions
	
	# Built-in functions
	var functions = ["Print", "Len", "Left", "Right", "Mid", "UCase", "LCase", "Trim",
					"Chr", "Asc", "Sin", "Cos", "Tan", "Abs", "Int", "Round", "Sqrt"]
	for func in functions:
		if func.to_lower().begins_with(word.to_lower()):
			completions.append(func)
	
	# Keywords
	var keywords = ["Dim", "As", "If", "Then", "Else", "For", "To", "Next", "While"]
	for keyword in keywords:
		if keyword.to_lower().begins_with(word.to_lower()):
			completions.append(keyword)
	
	# Variables
	for var_name in _variables.keys():
		if var_name.to_lower().begins_with(word.to_lower()):
			completions.append(var_name)
	
	return completions

func _get_current_word(text: String) -> String:
	var caret_pos = _input_field.get_caret_column()
	var line = _input_field.get_line(_input_field.get_caret_line())
	
	var start = caret_pos
	while start > 0 and line[start - 1].is_valid_identifier():
		start -= 1
	
	return line.substr(start, caret_pos - start)

func _refresh_variables():
	_var_tree.clear()
	if _variables.is_empty():
		return
	
	var root = _var_tree.create_item()
	for var_name in _variables.keys():
		var item = _var_tree.create_item(root)
		item.set_text(0, var_name)
		item.set_text(1, _get_type_name(_variables[var_name]))
		item.set_text(2, str(_variables[var_name]))
		item.set_metadata(0, var_name)

func _on_var_item_activated():
	var selected = _var_tree.get_selected()
	if selected:
		var var_name = selected.get_metadata(0)
		_input_field.text = var_name
		_input_field.grab_focus()

func _add_watch_expression():
	var dialog = AcceptDialog.new()
	dialog.title = "Add Watch Expression"
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	var label = Label.new()
	label.text = "Enter expression to watch:"
	vbox.add_child(label)
	var input = LineEdit.new()
	input.placeholder_text = "e.g., player.health"
	vbox.add_child(input)
	dialog.confirmed.connect(func():
		if not input.text.is_empty():
			_watch_expressions.append({"expr": input.text, "value": ""})
			_update_watch_expressions()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(300, 100))

func _update_watch_expressions():
	_watch_tree.clear()
	if _watch_expressions.is_empty():
		return
	
	var root = _watch_tree.create_item()
	for watch in _watch_expressions:
		var item = _watch_tree.create_item(root)
		item.set_text(0, watch["expr"])
		var value = _eval_simple(watch["expr"])
		item.set_text(1, str(value))
		watch["value"] = str(value)

func _on_watch_item_activated():
	var selected = _watch_tree.get_selected()
	if selected:
		var expr = selected.get_text(0)
		_input_field.text = expr
		_input_field.grab_focus()

func _inspect_object(obj: Object):
	_current_inspected_object = obj
	_refresh_inspector()

func _refresh_inspector():
	_inspector_tree.clear()
	
	if _current_inspected_object == null:
		return
	
	var obj = _current_inspected_object
	var root = _inspector_tree.create_item()
	root.set_text(0, obj.get_class())
	root.set_text(1, "")
	
	# Properties
	var props_parent = _inspector_tree.create_item(root)
	props_parent.set_text(0, "📝 Properties")
	
	var prop_list = obj.get_property_list()
	for prop in prop_list:
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or prop.usage & PROPERTY_USAGE_DEFAULT:
			var item = _inspector_tree.create_item(props_parent)
			item.set_text(0, prop.name)
			var value = obj.get(prop.name)
			item.set_text(1, str(value))
			item.set_metadata(0, {"obj": obj, "prop": prop.name, "value": value})
			
			# If value is complex, make it expandable
			if value is Object or value is Array or value is Dictionary:
				item.set_text(1, _get_type_name(value))
				_add_expandable_value(item, value)
	
	# Methods
	var methods_parent = _inspector_tree.create_item(root)
	var method_list = obj.get_method_list()
	methods_parent.set_text(0, "🔧 Methods (%d)" % method_list.size())
	
	for method in method_list:
		if not method.name.begins_with("_"): # Skip private methods
			var item = _inspector_tree.create_item(methods_parent)
			var sig = method.name + "("
			var params = []
			if "args" in method:
				for arg in method.args:
					params.append(arg.name if "name" in arg else "arg")
			sig += ", ".join(params) + ")"
			item.set_text(0, sig)
			item.set_metadata(0, {"obj": obj, "method": method.name})
	
	# For Nodes, show children
	if obj is Node:
		var children_parent = _inspector_tree.create_item(root)
		children_parent.set_text(0, "👶 Children (%d)" % obj.get_child_count())
		for child in obj.get_children():
			var item = _inspector_tree.create_item(children_parent)
			item.set_text(0, child.name)
			item.set_text(1, child.get_class())
			item.set_metadata(0, {"obj": child})

func _add_expandable_value(parent: TreeItem, value: Variant):
	if value is Array:
		for i in range(value.size()):
			var item = _inspector_tree.create_item(parent)
			item.set_text(0, "[%d]" % i)
			item.set_text(1, str(value[i]))
	elif value is Dictionary:
		for key in value.keys():
			var item = _inspector_tree.create_item(parent)
			item.set_text(0, str(key))
			item.set_text(1, str(value[key]))

func _on_inspector_item_activated():
	var selected = _inspector_tree.get_selected()
	if selected and selected.get_metadata(0):
		var meta = selected.get_metadata(0)
		if "obj" in meta and "prop" in meta:
			# Copy property access to input
			var obj_name = "obj" # Would need to track variable name
			_input_field.text = obj_name + "." + meta["prop"]
			_input_field.grab_focus()
		elif "obj" in meta and "method" in meta:
			# Insert method call
			var obj_name = "obj"
			_input_field.text = obj_name + "." + meta["method"] + "()"
			_input_field.grab_focus()
		elif "obj" in meta:
			# Inspect nested object
			_inspect_object(meta["obj"])

func _filter_inspector(text: String):
	# TODO: Implement filtering
	pass

func _repeat_last():
	if not _history.is_empty():
		_input_field.text = _history[_history.size() - 1]
		_input_field.grab_focus()

func _save_session():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_USERDATA
	dialog.filters = ["*.vgsession ; VisualGasic Session"]
	dialog.file_selected.connect(_save_session_to_file)
	add_child(dialog)
	dialog.popup_centered_ratio(0.5)

func _save_session_to_file(path: String):
	if path.is_empty():
		path = "user://session_" + str(Time.get_ticks_msec()) + ".vgsession"
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(_session_history)
		file.close()
		_append_output("[color=green]Session saved to: " + path + "[/color]\n")
	else:
		_append_output("[color=red]Failed to save session[/color]\n")

func _load_session():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_USERDATA
	dialog.filters = ["*.vgsession ; VisualGasic Session"]
	dialog.file_selected.connect(_load_session_from_file)
	add_child(dialog)
	dialog.popup_centered_ratio(0.5)

func _load_session_from_file(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var loaded_history = file.get_var()
		file.close()
		
		if loaded_history is Array:
			for command in loaded_history:
				_execute_input(command)
			_append_output("[color=green]Session loaded from: " + path + "[/color]\n")
	else:
		_append_output("[color=red]Failed to load session[/color]\n")
