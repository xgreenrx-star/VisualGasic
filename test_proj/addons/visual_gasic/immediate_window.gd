@tool
extends MarginContainer

## Interactive Development Console
## Execute code expressions and statements in real-time during development
## Supports connecting to running game instances for live debugging

var _repl: Object = null
var _vg_repl: RefCounted = null  # VisualGasicImmediate instance
var _history: Array[String] = []
var _history_index: int = -1
var _output_text: RichTextLabel
var _input_field: CodeEdit
var _send_button: Button
var _clear_button: Button
var _variables: Dictionary = {}
var _watch_expressions: Array[Dictionary] = []
var _watch_previous_values: Dictionary = {}  # Track previous values for change highlighting
var _var_tree: Tree
var _watch_tree: Tree
var _watch_context_menu: PopupMenu  # Right-click menu for watch expressions
var _inspector_tree: Tree
var _whenever_tree: Tree  # Whenever sections tree
var _current_inspected_object: Object = null
var _auto_complete_popup: PopupMenu
var _session_history: Array[String] = []
var _var_context_menu: PopupMenu  # Right-click menu for variables
var _whenever_context_menu: PopupMenu  # Right-click menu for Whenever
var _current_script_path: String = ""  # Path of connected instance's script

# Live debugging - instance connection (local in-process)
var _instance_dropdown: OptionButton
var _refresh_instances_btn: Button
var _connected_instance_ptr: int = 0
var _instance_list: Array = []  # Cached instance list

# Remote debugging via Godot's debugger protocol
var _debugger_plugin: EditorDebuggerPlugin = null
var _remote_instances: Array = []
var _connected_remote_id: int = -1
var _pending_eval_callback: Callable

# Auto-refresh for live variable updates
var _auto_refresh_timer: Timer = null
var _auto_refresh_enabled: bool = true
var _is_editing: bool = false  # Track if user is currently editing a cell
var _whenever_sections: Array = []  # Cached Whenever sections from remote
var _debug_status_label: Label = null  # Shows current debug state (paused at line X)
var _right_tabs: TabContainer = null  # Right panel tabs (Vars, Watch, Props, Whenever)
var _vars_label: Label = null  # Label showing variable count
var _var_sort_column: int = 0  # Current sort column (0=Name, 1=Type, 2=Value)
var _var_sort_ascending: bool = true  # Sort direction
var _var_filter_field: LineEdit = null  # Search/filter field for variables
const AUTO_REFRESH_INTERVAL: float = 0.5  # Update every 500ms

func _ready():
	_setup_ui()
	_initialize_repl()
	_show_welcome()
	_setup_auto_refresh_timer()


func _setup_auto_refresh_timer():
	_auto_refresh_timer = Timer.new()
	_auto_refresh_timer.wait_time = AUTO_REFRESH_INTERVAL
	_auto_refresh_timer.autostart = false
	_auto_refresh_timer.timeout.connect(_on_auto_refresh_timeout)
	add_child(_auto_refresh_timer)

func _on_auto_refresh_timeout():
	# Only auto-refresh when connected to a remote instance and not editing
	if _connected_remote_id >= 0 and _debugger_plugin and _auto_refresh_enabled and not _is_editing:
		_debugger_plugin.request_all_variables(_connected_remote_id)
		_debugger_plugin.request_whenever_sections(_connected_remote_id)
		# Watch expressions will be updated when variables are received

func _on_auto_refresh_toggled(enabled: bool):
	_auto_refresh_enabled = enabled
	if enabled and _connected_remote_id >= 0 and _auto_refresh_timer:
		_auto_refresh_timer.start()
	elif not enabled and _auto_refresh_timer:
		_auto_refresh_timer.stop()

func set_debugger_plugin(plugin: EditorDebuggerPlugin) -> void:
	_debugger_plugin = plugin
	if _debugger_plugin:
		_debugger_plugin.instances_updated.connect(_on_remote_instances_updated)
		_debugger_plugin.variable_received.connect(_on_remote_variable_received)
		_debugger_plugin.variables_list_received.connect(_on_remote_variables_received)
		_debugger_plugin.whenever_sections_received.connect(_on_whenever_sections_received)
		# Connect step debugging signals
		if _debugger_plugin.has_signal("debug_break_hit"):
			_debugger_plugin.debug_break_hit.connect(_on_debug_break_hit)
		if _debugger_plugin.has_signal("debug_state_received"):
			_debugger_plugin.debug_state_received.connect(_on_debug_state_received)
		# Connect Debug.Print output routing
		if _debugger_plugin.has_signal("debug_print_received"):
			_debugger_plugin.debug_print_received.connect(_on_debug_print_received)
		
		# Connect call stack panel to debugger
		if _right_tabs:
			for child in _right_tabs.get_children():
				if child.has_meta("_call_stack_panel"):
					child.set_debugger_plugin(_debugger_plugin)

func _setup_ui():
	# Main horizontal split: Console (left) + Panels (right)
	var main_split = HSplitContainer.new()
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	
	# Instance connection section
	var separator = VSeparator.new()
	toolbar.add_child(separator)
	
	var instance_label = Label.new()
	instance_label.text = "Connect to:"
	toolbar.add_child(instance_label)
	
	_instance_dropdown = OptionButton.new()
	_instance_dropdown.custom_minimum_size = Vector2(200, 0)
	_instance_dropdown.add_item("(Not Connected)", 0)
	_instance_dropdown.item_selected.connect(_on_instance_selected)
	toolbar.add_child(_instance_dropdown)
	
	_refresh_instances_btn = Button.new()
	_refresh_instances_btn.text = "🔄"
	_refresh_instances_btn.tooltip_text = "Refresh running instances"
	_refresh_instances_btn.pressed.connect(_refresh_running_instances)
	toolbar.add_child(_refresh_instances_btn)
	# help_button already added above
	
	# Debug toolbar (Step debugging controls)
	var debug_toolbar = HBoxContainer.new()
	console_vbox.add_child(debug_toolbar)
	
	var debug_label = Label.new()
	debug_label.text = "Debug:"
	debug_toolbar.add_child(debug_label)
	
	var btn_continue = Button.new()
	btn_continue.text = "▶ Continue"
	btn_continue.tooltip_text = "Resume execution (F5)"
	btn_continue.pressed.connect(_on_debug_continue)
	debug_toolbar.add_child(btn_continue)
	
	var btn_step_over = Button.new()
	btn_step_over.text = "⤵ Step Over"
	btn_step_over.tooltip_text = "Step to next line (F10)"
	btn_step_over.pressed.connect(_on_debug_step_over)
	debug_toolbar.add_child(btn_step_over)
	
	var btn_step_into = Button.new()
	btn_step_into.text = "↓ Step Into"
	btn_step_into.tooltip_text = "Step into function (F11)"
	btn_step_into.pressed.connect(_on_debug_step_into)
	debug_toolbar.add_child(btn_step_into)
	
	var btn_step_out = Button.new()
	btn_step_out.text = "↑ Step Out"
	btn_step_out.tooltip_text = "Step out of function (Shift+F11)"
	btn_step_out.pressed.connect(_on_debug_step_out)
	debug_toolbar.add_child(btn_step_out)
	
	# Spacer
	var debug_spacer = Control.new()
	debug_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_toolbar.add_child(debug_spacer)
	
	# Debug status label — wrapped in dark panel for visibility on any theme
	var status_panel = PanelContainer.new()
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)  # Near-black background
	status_style.set_content_margin_all(4)
	status_style.set_corner_radius_all(3)
	status_panel.add_theme_stylebox_override("panel", status_style)
	_debug_status_label = Label.new()
	_debug_status_label.text = ""
	_debug_status_label.add_theme_color_override("font_color", Color.YELLOW)
	status_panel.add_child(_debug_status_label)
	debug_toolbar.add_child(status_panel)
	
	# Output area
	_output_text = RichTextLabel.new()
	_output_text.bbcode_enabled = true
	_output_text.scroll_following = true
	_output_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output_text.custom_minimum_size = Vector2(0, 0)
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
	_input_field.custom_minimum_size = Vector2(0, 0)
	_input_field.placeholder_text = "Type expression or statement... (Shift+Enter: new line, Enter: execute)"
	_input_field.syntax_highlighter = _create_syntax_highlighter()
	_input_field.gutters_draw_line_numbers = true
	_input_field.auto_brace_completion_enabled = true
	# Disable built-in code completion — it hijacks Enter to accept GDScript
	# completions (e.g. replacing 'Prin' with 'print'), corrupting VB6 input.
	# The Immediate Window has its own completion via Ctrl+Space instead.
	_input_field.code_completion_enabled = false
	_input_field.gui_input.connect(_on_input_gui_input)
	input_hbox.add_child(_input_field)
	
	_send_button = Button.new()
	_send_button.text = "Execute\n(Enter)"
	_send_button.pressed.connect(_on_send_pressed)
	input_hbox.add_child(_send_button)
	
	# Right side: Tabbed panels (Variables, Watch, Inspector)
	_right_tabs = TabContainer.new()
	_right_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_tabs.custom_minimum_size = Vector2(300, 0)
	main_split.add_child(_right_tabs)
	
	# Variables panel
	var var_panel = VBoxContainer.new()
	var_panel.name = "Vars"
	_right_tabs.add_child(var_panel)
	
	var var_toolbar = HBoxContainer.new()
	var_panel.add_child(var_toolbar)
	
	_vars_label = Label.new()
	_vars_label.text = "Variables"
	var_toolbar.add_child(_vars_label)
	
	var var_refresh = Button.new()
	var_refresh.text = "🔄"
	var_refresh.tooltip_text = "Refresh variables"
	var_refresh.pressed.connect(_refresh_variables)
	var_toolbar.add_child(var_refresh)
	
	# Auto-refresh toggle button
	var auto_refresh_btn = CheckButton.new()
	auto_refresh_btn.text = "Live"
	auto_refresh_btn.tooltip_text = "Auto-refresh variables every 0.5s when connected"
	auto_refresh_btn.button_pressed = _auto_refresh_enabled
	auto_refresh_btn.toggled.connect(_on_auto_refresh_toggled)
	var_toolbar.add_child(auto_refresh_btn)
	
	# Search/filter field for variables
	_var_filter_field = LineEdit.new()
	_var_filter_field.placeholder_text = "🔍 Filter variables..."
	_var_filter_field.clear_button_enabled = true
	_var_filter_field.text_changed.connect(_on_var_filter_changed)
	# Style: visible border + caret color so focus state is obvious
	var filter_normal = StyleBoxFlat.new()
	filter_normal.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	filter_normal.border_color = Color(0.35, 0.35, 0.4, 1.0)
	filter_normal.set_border_width_all(1)
	filter_normal.set_corner_radius_all(3)
	filter_normal.set_content_margin_all(4)
	var filter_focus = StyleBoxFlat.new()
	filter_focus.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	filter_focus.border_color = Color(0.45, 0.65, 1.0, 1.0)
	filter_focus.set_border_width_all(2)
	filter_focus.set_corner_radius_all(3)
	filter_focus.set_content_margin_all(4)
	_var_filter_field.add_theme_stylebox_override("normal", filter_normal)
	_var_filter_field.add_theme_stylebox_override("focus", filter_focus)
	_var_filter_field.add_theme_color_override("caret_color", Color(1.0, 1.0, 1.0, 1.0))
	_var_filter_field.add_theme_color_override("font_placeholder_color", Color(0.55, 0.55, 0.6, 1.0))
	_var_filter_field.caret_blink = true
	_var_filter_field.caret_blink_interval = 0.5
	var_panel.add_child(_var_filter_field)

	_var_tree = Tree.new()
	_var_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_var_tree.columns = 3
	_var_tree.set_column_title(0, "Name")
	_var_tree.set_column_title(1, "Type")
	_var_tree.set_column_title(2, "Value")
	_var_tree.column_titles_visible = true
	_var_tree.select_mode = Tree.SELECT_ROW
	_var_tree.hide_root = true
	_var_tree.scroll_horizontal_enabled = true
	_var_tree.scroll_vertical_enabled = true
	_var_tree.set_column_clip_content(0, true)
	_var_tree.set_column_clip_content(1, true)
	_var_tree.set_column_clip_content(2, true)
	_var_tree.item_activated.connect(_on_var_item_activated)  # Double-click -> go to definition
	_var_tree.item_edited.connect(_on_var_item_edited)
	_var_tree.item_selected.connect(_on_var_item_selected)
	_var_tree.gui_input.connect(_on_var_tree_gui_input)  # Right-click handling
	_var_tree.column_title_clicked.connect(_on_var_column_title_clicked)
	print("[ImmediateWindow] var_tree item_edited signal connected")
	var_panel.add_child(_var_tree)
	
	# Make the Tree scrollbar grabber more visible
	_style_tree_scrollbar(_var_tree)
	
	# Create context menu for variables
	_var_context_menu = PopupMenu.new()
	_var_context_menu.add_item("Insert in Input", 0)
	_var_context_menu.add_separator()
	_var_context_menu.add_item("Go to Definition", 1)
	_var_context_menu.add_separator()
	_var_context_menu.add_item("Rename in Current Scope...", 2)
	_var_context_menu.add_item("Rename in Entire Script...", 3)
	_var_context_menu.add_item("Rename Everywhere...", 4)
	_var_context_menu.id_pressed.connect(_on_var_context_menu_selected)
	add_child(_var_context_menu)
	
	# Watch panel
	var watch_panel = VBoxContainer.new()
	watch_panel.name = "Watch"
	_right_tabs.add_child(watch_panel)
	
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
	_watch_tree.item_edited.connect(_on_watch_item_edited)
	_watch_tree.gui_input.connect(_on_watch_tree_gui_input)  # Right-click handling
	watch_panel.add_child(_watch_tree)
	
	# Create context menu for watch expressions
	_watch_context_menu = PopupMenu.new()
	_watch_context_menu.add_item("Delete Watch", 0)
	_watch_context_menu.add_item("Delete All Watches", 1)
	_watch_context_menu.add_separator()
	_watch_context_menu.add_item("Copy Value", 2)
	_watch_context_menu.add_item("Copy Expression", 3)
	_watch_context_menu.id_pressed.connect(_on_watch_context_menu_selected)
	add_child(_watch_context_menu)
	
	# Load persisted watch expressions
	_load_watch_expressions()
	
	# Inspector panel
	var inspector_panel = VBoxContainer.new()
	inspector_panel.name = "Props"
	_right_tabs.add_child(inspector_panel)
	
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
	
	# Whenever panel - Monitor reactive Whenever statements
	var whenever_panel = VBoxContainer.new()
	whenever_panel.name = "Whenever"
	_right_tabs.add_child(whenever_panel)
	
	var whenever_toolbar = HBoxContainer.new()
	whenever_panel.add_child(whenever_toolbar)
	
	var whenever_label = Label.new()
	whenever_label.text = "Reactive Statements"
	whenever_toolbar.add_child(whenever_label)
	
	var whenever_refresh = Button.new()
	whenever_refresh.text = "🔄"
	whenever_refresh.tooltip_text = "Refresh Whenever sections"
	whenever_refresh.pressed.connect(_refresh_whenever_sections)
	whenever_toolbar.add_child(whenever_refresh)
	
	_whenever_tree = Tree.new()
	_whenever_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_whenever_tree.columns = 4
	_whenever_tree.set_column_title(0, "Condition")
	_whenever_tree.set_column_title(1, "Status")
	_whenever_tree.set_column_title(2, "Callbacks")
	_whenever_tree.set_column_title(3, "Scope")
	_whenever_tree.column_titles_visible = true
	_whenever_tree.set_column_expand(0, true)
	_whenever_tree.set_column_expand(1, false)
	_whenever_tree.set_column_expand(2, true)
	_whenever_tree.set_column_expand(3, false)
	_whenever_tree.set_column_custom_minimum_width(1, 80)
	_whenever_tree.set_column_custom_minimum_width(3, 60)
	_whenever_tree.gui_input.connect(_on_whenever_tree_gui_input)
	whenever_panel.add_child(_whenever_tree)
	
	# Context menu for Whenever items
	_whenever_context_menu = PopupMenu.new()
	_whenever_context_menu.add_item("Pause", 0)
	_whenever_context_menu.add_item("Resume", 1)
	_whenever_context_menu.add_separator()
	_whenever_context_menu.add_item("Go to Definition", 2)
	_whenever_context_menu.id_pressed.connect(_on_whenever_context_menu_selected)
	add_child(_whenever_context_menu)
	
	# Call Stack panel
	var call_stack_script = load("res://addons/visual_gasic/call_stack_panel.gd")
	if call_stack_script:
		var call_stack_panel = call_stack_script.new()
		call_stack_panel.name = "Stack"
		_right_tabs.add_child(call_stack_panel)
		# Will be connected to debugger plugin in set_debugger_plugin()
		call_stack_panel.set_meta("_call_stack_panel", true)

func _initialize_repl():
	# Try to create VisualGasicImmediate instance for BASIC code execution
	if ClassDB.class_exists("VisualGasicImmediate"):
		_vg_repl = ClassDB.instantiate("VisualGasicImmediate")
		_append_output("[color=green]✓ VisualGasic REPL initialized[/color]\n")
	else:
		_append_output("[color=yellow]⚠ VisualGasicImmediate not available - using basic evaluator[/color]\n")
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
	_append_output("\n[b]Runtime Debugging:[/b]\n")
	_append_output("  :instances  - List running VisualGasic instances\n")
	_append_output("  :connect N  - Connect to instance N for live debugging\n")
	_append_output("  :disconnect - Disconnect from running instance\n")
	_append_output("\n[b]When connected to a running game:[/b]\n")
	_append_output("  Print Ball_x    - Print variable from running game\n")
	_append_output("  ? player_y      - Shortcut for Print\n")
	_append_output("  Ball_x = 100    - Modify variable in running game\n")
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
		"instances":
			_show_running_instances()
		"connect":
			_connect_to_instance_by_index(arg)
		"disconnect":
			_disconnect_from_instance()
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
	# Reset VG REPL if available
	if _vg_repl != null:
		_vg_repl.reset()
	_show_welcome()
	_refresh_variables()
	_update_watch_expressions()
	_refresh_inspector()
	_append_output("[color=green]Console reset complete[/color]\n\n")

func _evaluate_expression(expr: String) -> String:
	# Check for remote instance connection first
	if _is_connected_to_remote():
		return _evaluate_remote(expr)
	
	# Use VisualGasicImmediate if available for true BASIC execution
	if _vg_repl != null:
		# If connected to a running instance, use evaluate_in_context for runtime access
		var result: Dictionary
		if _is_connected_to_instance():
			result = _vg_repl.evaluate_in_context(expr)
			if result.get("from_runtime", false):
				return "[color=lime]" + str(result.get("result", "")) + "[/color] [color=gray](runtime)[/color]"
			if result.get("modified_runtime", false):
				return "[color=lime]" + str(result.get("result", "")) + "[/color] [color=gray](runtime modified)[/color]"
		else:
			# Not connected - check if this is a Print command referencing a game variable
			var upper = expr.strip_edges().to_upper()
			if upper.begins_with("PRINT ") or expr.strip_edges().begins_with("? "):
				var var_name = ""
				if expr.strip_edges().begins_with("? "):
					var_name = expr.strip_edges().substr(2).strip_edges()
				else:
					var_name = expr.strip_edges().substr(6).strip_edges()
				# Check if it's a simple variable name (likely a game variable)
				if var_name.is_valid_identifier():
					return "[color=yellow]'" + var_name + "' not found in session.[/color]\n[color=gray]Tip: Connect to a running game instance to access game variables.[/color]"
			result = _vg_repl.evaluate(expr)
		
		if result.get("continue", false):
			return "[color=gray]...[/color]"
		if result.get("success", false):
			var res_text = result.get("result", "")
			if res_text == "OK":
				return "[color=green]✓[/color]"
			if res_text == "" or res_text == "null":
				return "[color=gray](empty)[/color]"
			return "[color=cyan]" + str(res_text) + "[/color]"
		else:
			return "[color=red]" + result.get("result", "Error") + "[/color]"
	
	# Fallback to basic GDScript-based evaluation
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
		# Debug keyboard shortcuts (only work when debugger is paused)
		if _is_debug_session_paused():
			match event.keycode:
				KEY_F5:
					_on_debug_continue()
					get_viewport().set_input_as_handled()
					return
				KEY_F10:
					_on_debug_step_over()
					get_viewport().set_input_as_handled()
					return
				KEY_F11:
					if event.shift_pressed:
						_on_debug_step_out()
					else:
						_on_debug_step_into()
					get_viewport().set_input_as_handled()
					return
		
		# Input field history navigation
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

func _is_debug_session_paused() -> bool:
	"""Check if the debugger is active and paused at a breakpoint/step."""
	if not _debugger_plugin or not _debugger_plugin.is_session_active():
		return false
	# Check if we're actually paused (status label contains "Paused")
	if _debug_status_label and "Paused" in _debug_status_label.text:
		return true
	return false

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
	
	# Symbols/operators - bright cyan for visibility
	highlighter.symbol_color = Color(0.7, 0.9, 1.0)
	
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
	for fn in functions:
		if fn.to_lower().begins_with(word.to_lower()):
			completions.append(fn)
	
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
	# If connected to remote instance, request variables from it
	if _connected_remote_id >= 0 and _debugger_plugin:
		_debugger_plugin.request_all_variables(_connected_remote_id)
		return
	
	_update_variables_tree()

func _update_variables_tree():
	_var_tree.clear()
	var root = _var_tree.create_item()
	
	# Get the filter text (case-insensitive)
	var filter_text := ""
	if _var_filter_field:
		filter_text = _var_filter_field.text.strip_edges().to_lower()
	
	# Update the label with variable count
	if _vars_label:
		if _variables.is_empty():
			_vars_label.text = "Variables"
		else:
			_vars_label.text = "Variables (%d)" % _variables.size()
	
	if _variables.is_empty():
		# Show helpful message when no variables
		var empty_item = _var_tree.create_item(root)
		empty_item.set_text(0, "(No variables)")
		empty_item.set_custom_color(0, Color.GRAY)
		empty_item.set_selectable(0, false)
		return
	
	# Sort variables by current sort column
	var sorted_names = _variables.keys()
	if _var_sort_column == 0:
		# Sort by Name
		sorted_names.sort()
	elif _var_sort_column == 1:
		# Sort by Type
		sorted_names.sort_custom(func(a, b):
			var ta = _get_type_name(_variables[a]).to_lower()
			var tb = _get_type_name(_variables[b]).to_lower()
			if ta == tb:
				return a.nocasecmp_to(b) < 0
			return ta < tb)
	elif _var_sort_column == 2:
		# Sort by Value (string representation)
		sorted_names.sort_custom(func(a, b):
			var va = str(_variables[a]).to_lower()
			var vb = str(_variables[b]).to_lower()
			if va == vb:
				return a.nocasecmp_to(b) < 0
			return va < vb)
	if not _var_sort_ascending:
		sorted_names.reverse()
	
	var shown_count := 0
	for var_name in sorted_names:
		# Apply filter — match against name, type, or value
		if not filter_text.is_empty():
			var type_name = _get_type_name(_variables[var_name]).to_lower()
			var value_str = str(_variables[var_name]).to_lower()
			if filter_text not in var_name.to_lower() and filter_text not in type_name and filter_text not in value_str:
				continue
		shown_count += 1
		var value = _variables[var_name]
		var item = _var_tree.create_item(root)
		item.set_text(0, var_name)
		
		# Get type name and set type color
		var type_name = _get_type_name(value)
		item.set_text(1, type_name)
		item.set_custom_color(1, _get_type_color(type_name))
		
		# Format value display based on type
		var value_str = _format_value_for_display(value)
		item.set_text(2, value_str)
		item.set_editable(2, true)  # Make Value column editable
		item.set_metadata(0, var_name)
		
		# Color code the value based on type
		item.set_custom_color(2, _get_value_color(value))
	
	# Update label with filtered count when filter is active
	if _vars_label and not filter_text.is_empty() and not _variables.is_empty():
		_vars_label.text = "Variables (%d/%d)" % [shown_count, _variables.size()]

func _get_type_color(type_name: String) -> Color:
	"""Return color for type name display"""
	match type_name.to_lower():
		"integer", "int":
			return Color.CYAN
		"float", "double", "single":
			return Color.CYAN
		"string":
			return Color.ORANGE
		"boolean", "bool":
			return Color.MAGENTA
		"array":
			return Color.YELLOW
		"dictionary":
			return Color.YELLOW
		"null", "nothing":
			return Color.GRAY
		"object":
			return Color.LIME_GREEN
		_:
			return Color.WHITE

func _get_value_color(value) -> Color:
	"""Return color for value display based on actual value"""
	if value == null:
		return Color.GRAY
	elif value is bool:
		return Color.LIGHT_CORAL if not value else Color.LIME_GREEN
	elif value is int or value is float:
		return Color.AQUA
	elif value is String:
		return Color.SANDY_BROWN
	elif value is Array:
		return Color.KHAKI
	elif value is Dictionary:
		return Color.KHAKI
	else:
		return Color.WHITE

func _format_value_for_display(value) -> String:
	"""Format value for display in tree - truncate long strings/arrays"""
	if value == null:
		return "Nothing"
	elif value is String:
		if value.length() > 50:
			return "\"%s...\"" % value.substr(0, 47)
		return "\"%s\"" % value
	elif value is Array:
		if value.size() > 5:
			var preview = str(value.slice(0, 5))
			return "%s... (%d items)" % [preview.substr(0, preview.length()-1), value.size()]
		return str(value)
	elif value is Dictionary:
		var keys = value.keys()
		if keys.size() > 3:
			return "{%d keys: %s...}" % [keys.size(), ", ".join(keys.slice(0, 3))]
		return str(value)
	elif value is bool:
		return "True" if value else "False"
	else:
		return str(value)

func _on_var_column_title_clicked(column: int, mouse_button_index: int) -> void:
	"""Sort variables by clicked column header."""
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	if column == _var_sort_column:
		_var_sort_ascending = not _var_sort_ascending
	else:
		_var_sort_column = column
		_var_sort_ascending = true
	# Update column titles to show sort indicator
	var arrows = ["Name", "Type", "Value"]
	for i in range(3):
		var title = arrows[i]
		if i == _var_sort_column:
			title += " ▲" if _var_sort_ascending else " ▼"
		_var_tree.set_column_title(i, title)
	_update_variables_tree()

func _style_tree_scrollbar(tree: Tree) -> void:
	"""Make the Tree's vertical scrollbar grabber clearly visible."""
	# The scrollbars are *internal* children — must pass true to get_children.
	# Use call_deferred so the internal layout has been created.
	(func():
		for child in tree.get_children(true):  # true = include internal children
			if child is VScrollBar:
				var grabber = StyleBoxFlat.new()
				grabber.bg_color = Color(0.55, 0.55, 0.6, 1.0)
				grabber.set_corner_radius_all(3)
				var grabber_hl = StyleBoxFlat.new()
				grabber_hl.bg_color = Color(0.7, 0.7, 0.75, 1.0)
				grabber_hl.set_corner_radius_all(3)
				var grabber_pressed = StyleBoxFlat.new()
				grabber_pressed.bg_color = Color(0.45, 0.65, 1.0, 1.0)
				grabber_pressed.set_corner_radius_all(3)
				var scroll_bg = StyleBoxFlat.new()
				scroll_bg.bg_color = Color(0.12, 0.12, 0.14, 1.0)
				scroll_bg.set_corner_radius_all(2)
				child.add_theme_stylebox_override("grabber", grabber)
				child.add_theme_stylebox_override("grabber_highlight", grabber_hl)
				child.add_theme_stylebox_override("grabber_pressed", grabber_pressed)
				child.add_theme_stylebox_override("scroll", scroll_bg)
				child.custom_minimum_size.x = 12  # Ensure scrollbar is wide enough
			if child is HScrollBar:
				var grabber = StyleBoxFlat.new()
				grabber.bg_color = Color(0.55, 0.55, 0.6, 1.0)
				grabber.set_corner_radius_all(3)
				var grabber_hl = StyleBoxFlat.new()
				grabber_hl.bg_color = Color(0.7, 0.7, 0.75, 1.0)
				grabber_hl.set_corner_radius_all(3)
				child.add_theme_stylebox_override("grabber", grabber)
				child.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	).call_deferred()

func _on_var_filter_changed(_new_text: String) -> void:
	"""Re-filter the variables tree when the search box text changes."""
	_update_variables_tree()

func _on_var_item_activated():
	"""Double-click: Navigate to variable definition in code"""
	var selected = _var_tree.get_selected()
	if selected:
		var var_name = selected.get_metadata(0)
		_go_to_variable_definition(var_name)

func _on_var_tree_gui_input(event: InputEvent):
	"""Handle right-click on variable tree"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			var selected = _var_tree.get_selected()
			if selected:
				_var_context_menu.position = _var_tree.get_screen_position() + mouse_event.position
				_var_context_menu.popup()

func _on_var_context_menu_selected(id: int):
	"""Handle context menu selection"""
	var selected = _var_tree.get_selected()
	if not selected:
		return
	
	var var_name = selected.get_metadata(0)
	
	match id:
		0:  # Insert in Input
			_input_field.text = var_name
			_input_field.grab_focus()
		1:  # Go to Definition
			_go_to_variable_definition(var_name)
		2:  # Rename in Current Scope
			_show_rename_dialog(var_name, 0)  # scope only
		3:  # Rename in Entire Script
			_show_rename_dialog(var_name, 1)  # entire file
		4:  # Rename Everywhere
			_show_rename_dialog(var_name, 2)  # all files

func _go_to_variable_definition(var_name: String):
	"""Navigate to where a variable is defined in the source code"""
	# Get the script path from the connected instance
	if _current_script_path.is_empty():
		# Try to get from remote instances
		if not _remote_instances.is_empty() and _connected_remote_id >= 0:
			for info in _remote_instances:
				if info.get("id", -1) == _connected_remote_id:
					_current_script_path = info.get("script_path", "")
					break
	
	if _current_script_path.is_empty():
		_append_output("[color=yellow]Cannot find script path for variable '%s'[/color]\n" % var_name)
		return
	
	# Search for variable definition in the script
	var file = FileAccess.open(_current_script_path, FileAccess.READ)
	if not file:
		_append_output("[color=red]Cannot open script: %s[/color]\n" % _current_script_path)
		return
	
	var line_num = 0
	var found_line = -1
	var definition_patterns = [
		"Dim " + var_name + " ",
		"Dim " + var_name + "\t",
		"Dim " + var_name + "\n",
		"Dim " + var_name + ",",
	]
	
	while not file.eof_reached():
		var line = file.get_line()
		line_num += 1
		for pattern in definition_patterns:
			if line.findn(pattern) >= 0:
				found_line = line_num
				break
		if found_line > 0:
			break
	file.close()
	
	if found_line > 0:
		# Open the file in the editor and go to the line
		var editor_interface = EditorInterface
		editor_interface.edit_script(load(_current_script_path), found_line, 0)
		_append_output("[color=lime]Found '%s' at line %d[/color]\n" % [var_name, found_line])
	else:
		# Variable might be a local in a Sub - just open the file
		var editor_interface = EditorInterface
		editor_interface.edit_script(load(_current_script_path))
		_append_output("[color=yellow]'%s' may be a local variable. Opened script.[/color]\n" % var_name)

func _show_rename_dialog(var_name: String, mode: int):
	"""Show dialog to rename a variable
	   mode: 0 = current scope, 1 = entire script, 2 = everywhere"""
	var mode_names = ["Current Scope", "Entire Script", "Everywhere"]
	var dialog = AcceptDialog.new()
	dialog.title = "Rename Variable (%s)" % mode_names[mode]
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Rename '%s' to:" % var_name
	vbox.add_child(label)
	
	var input = LineEdit.new()
	input.text = var_name
	input.select_all()
	vbox.add_child(input)
	
	if mode == 2:
		var warning = Label.new()
		warning.text = "⚠ This will rename in ALL .vg files!"
		warning.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(warning)
	elif mode == 1:
		var info = Label.new()
		info.text = "ℹ This will rename in the entire script file"
		info.add_theme_color_override("font_color", Color.CYAN)
		vbox.add_child(info)
	else:
		var info = Label.new()
		info.text = "ℹ This will rename only in the current Sub/Function"
		info.add_theme_color_override("font_color", Color.LIME_GREEN)
		vbox.add_child(info)
	
	dialog.confirmed.connect(func():
		var new_name = input.text.strip_edges()
		if new_name.is_empty() or new_name == var_name:
			return
		if not _is_valid_identifier(new_name):
			_append_output("[color=red]'%s' is not a valid identifier[/color]\n" % new_name)
			return
		_perform_rename(var_name, new_name, mode)
	)
	
	add_child(dialog)
	dialog.popup_centered(Vector2(350, 150))
	input.grab_focus()

func _is_valid_identifier(name: String) -> bool:
	"""Check if a name is a valid VB identifier"""
	if name.is_empty():
		return false
	# Must start with letter
	if not name[0].is_valid_identifier():
		return false
	# Rest can be letters, numbers, underscore
	for c in name:
		if not c.is_valid_identifier() and c != "_":
			return false
	return true

func _perform_rename(old_name: String, new_name: String, mode: int):
	"""Perform the actual rename operation
	   mode: 0 = current scope, 1 = entire script, 2 = everywhere"""
	
	if _current_script_path.is_empty():
		_append_output("[color=red]No script connected[/color]\n")
		return
	
	if mode == 2:
		# Find all .vg files in the project
		var files_to_search: Array[String] = _find_all_vg_files("res://")
		var total_replacements = 0
		var files_modified = 0
		
		for file_path in files_to_search:
			var result = _rename_in_file(file_path, old_name, new_name)
			if result > 0:
				total_replacements += result
				files_modified += 1
		
		if total_replacements > 0:
			_append_output("[color=lime]Renamed '%s' → '%s': %d replacements in %d file(s)[/color]\n" % [
				old_name, new_name, total_replacements, files_modified
			])
			_append_output("[color=yellow]⚠ Restart game to apply changes[/color]\n")
		else:
			_append_output("[color=gray]No occurrences of '%s' found[/color]\n" % old_name)
	elif mode == 1:
		# Just the current script - entire file
		var result = _rename_in_file(_current_script_path, old_name, new_name)
		if result > 0:
			_append_output("[color=lime]Renamed '%s' → '%s': %d replacements[/color]\n" % [
				old_name, new_name, result
			])
			_append_output("[color=yellow]⚠ Restart game to apply changes[/color]\n")
		else:
			_append_output("[color=gray]No occurrences of '%s' found in script[/color]\n" % old_name)
	else:
		# Current scope only - find the procedure boundaries
		var result = _rename_in_current_scope(_current_script_path, old_name, new_name)
		if result > 0:
			_append_output("[color=lime]Renamed '%s' → '%s': %d replacements in current scope[/color]\n" % [
				old_name, new_name, result
			])
			_append_output("[color=yellow]⚠ Restart game to apply changes[/color]\n")
		else:
			_append_output("[color=gray]No occurrences of '%s' found in current scope[/color]\n" % old_name)

func _rename_in_current_scope(file_path: String, old_name: String, new_name: String) -> int:
	"""Rename variable only within the current Sub/Function scope."""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 0
	
	var content = file.get_as_text()
	file.close()
	
	# Find the current procedure that contains the caret
	# We need to find the procedure where the variable is used
	# For now, look for the procedure containing the first occurrence of old_name
	
	var lines = content.split("\n")
	var proc_start = -1
	var proc_end = -1
	var found_var_line = -1
	
	# First, find a line with the variable
	var regex = RegEx.new()
	regex.compile("(?<![A-Za-z0-9_])" + old_name + "(?![A-Za-z0-9_])")
	
	for i in range(lines.size()):
		var match_result = regex.search(lines[i])
		if match_result and not _is_inside_string_or_comment(lines[i], match_result.get_start()):
			found_var_line = i
			break
	
	if found_var_line == -1:
		return 0
	
	# Now find the enclosing Sub/Function
	for i in range(found_var_line, -1, -1):
		var line_upper = lines[i].strip_edges().to_upper()
		if line_upper.begins_with("SUB ") or line_upper.begins_with("FUNCTION ") or \
		   line_upper.begins_with("PRIVATE SUB ") or line_upper.begins_with("PUBLIC SUB ") or \
		   line_upper.begins_with("PRIVATE FUNCTION ") or line_upper.begins_with("PUBLIC FUNCTION "):
			proc_start = i
			break
	
	if proc_start == -1:
		# Variable is at module level, rename only module-level occurrences
		# Find where first procedure starts
		for i in range(lines.size()):
			var line_upper = lines[i].strip_edges().to_upper()
			if line_upper.begins_with("SUB ") or line_upper.begins_with("FUNCTION ") or \
			   line_upper.begins_with("PRIVATE SUB ") or line_upper.begins_with("PUBLIC SUB ") or \
			   line_upper.begins_with("PRIVATE FUNCTION ") or line_upper.begins_with("PUBLIC FUNCTION "):
				proc_end = i  # Stop before first procedure
				break
		if proc_end == -1:
			proc_end = lines.size()
		proc_start = 0
	else:
		# Find END SUB or END FUNCTION
		for i in range(found_var_line, lines.size()):
			var line_upper = lines[i].strip_edges().to_upper()
			if line_upper == "END SUB" or line_upper == "END FUNCTION":
				proc_end = i + 1
				break
		if proc_end == -1:
			proc_end = lines.size()
	
	# Now rename only within proc_start to proc_end
	var replacements = 0
	var new_lines = lines.duplicate()
	
	for i in range(proc_start, proc_end):
		var line = new_lines[i]
		var matches = regex.search_all(line)
		if matches.is_empty():
			continue
		
		# Filter and replace (from end to start)
		var new_line = line
		for j in range(matches.size() - 1, -1, -1):
			var m = matches[j]
			if not _is_inside_string_or_comment(line, m.get_start()):
				new_line = new_line.substr(0, m.get_start()) + new_name + new_line.substr(m.get_end())
				replacements += 1
		new_lines[i] = new_line
	
	if replacements > 0:
		var write_file = FileAccess.open(file_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string("\n".join(new_lines))
			write_file.close()
	
	return replacements

func _find_all_vg_files(path: String) -> Array[String]:
	"""Recursively find all .vg files in a directory"""
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				if not file_name.begins_with("."):
					files.append_array(_find_all_vg_files(full_path))
			elif file_name.ends_with(".vg"):
				files.append(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	return files

func _rename_in_file(file_path: String, old_name: String, new_name: String) -> int:
	"""Rename variable in a single file. Returns number of replacements."""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 0
	
	var content = file.get_as_text()
	file.close()
	
	# Use word-boundary aware replacement
	# Match old_name only when surrounded by non-identifier characters
	var regex = RegEx.new()
	# Pattern: word boundary before and after the name
	# VB identifiers can contain letters, numbers, underscore
	regex.compile("(?<![A-Za-z0-9_])" + old_name + "(?![A-Za-z0-9_])")
	
	var matches = regex.search_all(content)
	if matches.is_empty():
		return 0
	
	# Filter out matches inside strings and comments
	var valid_matches: Array = []
	for m in matches:
		if not _is_inside_string_or_comment(content, m.get_start()):
			valid_matches.append(m)
	
	if valid_matches.is_empty():
		return 0
	
	# Replace from end to start to preserve positions
	var new_content = content
	for i in range(valid_matches.size() - 1, -1, -1):
		var m = valid_matches[i]
		new_content = new_content.substr(0, m.get_start()) + new_name + new_content.substr(m.get_end())
	
	# Write back
	var write_file = FileAccess.open(file_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(new_content)
		write_file.close()
		return valid_matches.size()
	return 0

func _is_inside_string_or_comment(content: String, pos: int) -> bool:
	"""Check if a position in the content is inside a string or comment"""
	# Find the start of the current line
	var line_start = content.rfind("\n", pos)
	if line_start == -1:
		line_start = 0
	else:
		line_start += 1
	
	var line_portion = content.substr(line_start, pos - line_start)
	
	# Check if there's a comment before this position on this line
	var comment_pos = line_portion.find("'")
	if comment_pos >= 0:
		# Check if the comment marker is inside a string
		var in_string = false
		for i in range(comment_pos):
			if line_portion[i] == '"':
				in_string = not in_string
		if not in_string:
			return true  # We're in a comment
	
	# Check if we're inside a string (count unescaped quotes before position)
	var quote_count = 0
	for i in range(line_portion.length()):
		if line_portion[i] == '"':
			quote_count += 1
	
	return quote_count % 2 == 1  # Odd number means we're inside a string

func _on_var_item_selected():
	"""Called when user selects a variable - prepare for editing"""
	_is_editing = true
	print("[ImmediateWindow] Item selected, editing mode ON")

func _on_var_item_edited():
	"""Called when user edits a variable value in the tree"""
	_is_editing = false  # Done editing
	print("[ImmediateWindow] _on_var_item_edited called, editing mode OFF")
	var edited = _var_tree.get_edited()
	if not edited:
		print("[ImmediateWindow] No edited item from get_edited()")
		# Try get_selected as fallback
		edited = _var_tree.get_selected()
		if not edited:
			print("[ImmediateWindow] No selected item either")
			return
	
	var edited_column = _var_tree.get_edited_column()
	print("[ImmediateWindow] Edited column: ", edited_column)
	
	var var_name = edited.get_metadata(0)
	var new_value_str = edited.get_text(2)
	print("[ImmediateWindow] Editing var: ", var_name, " = ", new_value_str)
	
	# Send the assignment command
	if _connected_remote_id >= 0 and _debugger_plugin:
		# Remote instance - send via debugger
		print("[ImmediateWindow] Sending to remote instance #", _connected_remote_id)
		_debugger_plugin.set_variable(_connected_remote_id, var_name, new_value_str)
		_append_output("[color=cyan]Set %s = %s[/color]\n" % [var_name, new_value_str])
	else:
		# Local - execute assignment
		var cmd = "%s = %s" % [var_name, new_value_str]
		_process_command(cmd)

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
			_save_watch_expressions()  # Persist
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
		var value
		# Use remote variables if connected to remote instance
		if _connected_remote_id >= 0 and _variables.has(watch["expr"]):
			value = _variables[watch["expr"]]
		else:
			value = _eval_simple(watch["expr"])
		var value_str = str(value)
		item.set_text(1, value_str)
		item.set_editable(1, true)  # Make Value column editable
		item.set_metadata(0, watch["expr"])  # Store expression name for editing
		
		# Color-code based on value changes
		var prev_value = _watch_previous_values.get(watch["expr"], "")
		if prev_value != "" and prev_value != value_str:
			# Value changed - highlight in yellow
			item.set_custom_color(1, Color.YELLOW)
		else:
			# No change or first time - default green
			item.set_custom_color(1, Color.LIME_GREEN)
		
		_watch_previous_values[watch["expr"]] = value_str
		watch["value"] = value_str

func _on_watch_tree_gui_input(event: InputEvent):
	"""Handle right-click on watch tree for context menu"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var selected = _watch_tree.get_selected()
		if selected:
			_watch_context_menu.position = Vector2i(get_global_mouse_position())
			_watch_context_menu.popup()

func _on_watch_context_menu_selected(id: int):
	"""Handle watch context menu selection"""
	var selected = _watch_tree.get_selected()
	match id:
		0:  # Delete Watch
			if selected:
				var expr = selected.get_text(0)
				_watch_expressions = _watch_expressions.filter(func(w): return w["expr"] != expr)
				_watch_previous_values.erase(expr)
				_save_watch_expressions()
				_update_watch_expressions()
		1:  # Delete All Watches
			_watch_expressions.clear()
			_watch_previous_values.clear()
			_save_watch_expressions()
			_update_watch_expressions()
		2:  # Copy Value
			if selected:
				DisplayServer.clipboard_set(selected.get_text(1))
		3:  # Copy Expression
			if selected:
				DisplayServer.clipboard_set(selected.get_text(0))

func _save_watch_expressions():
	"""Persist watch expressions to user data"""
	var config = ConfigFile.new()
	var expressions: Array[String] = []
	for watch in _watch_expressions:
		expressions.append(watch["expr"])
	config.set_value("watch", "expressions", expressions)
	config.save("user://vg_watch_expressions.cfg")

func _load_watch_expressions():
	"""Load persisted watch expressions"""
	var config = ConfigFile.new()
	if config.load("user://vg_watch_expressions.cfg") == OK:
		var expressions = config.get_value("watch", "expressions", [])
		for expr in expressions:
			_watch_expressions.append({"expr": expr, "value": ""})
		if not _watch_expressions.is_empty():
			_update_watch_expressions()

func _on_watch_item_activated():
	var selected = _watch_tree.get_selected()
	if selected:
		var expr = selected.get_text(0)
		_input_field.text = expr
		_input_field.grab_focus()

func _on_watch_item_edited():
	"""Called when user edits a watch value in the tree"""
	var selected = _watch_tree.get_selected()
	if not selected:
		return
	
	var var_name = selected.get_metadata(0)
	var new_value_str = selected.get_text(1)
	
	# Send the assignment command
	if _connected_remote_id >= 0 and _debugger_plugin:
		# Remote instance - send via debugger
		_debugger_plugin.set_variable(_connected_remote_id, var_name, new_value_str)
		_append_output("[color=cyan]Set %s = %s[/color]\n" % [var_name, new_value_str])
	else:
		# Local - execute assignment
		var cmd = "%s = %s" % [var_name, new_value_str]
		_process_command(cmd)

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


# === RUNTIME DEBUGGING - INSTANCE CONNECTION ===

func _refresh_running_instances():
	"""Refresh the list of running VisualGasic instances"""
	_instance_dropdown.clear()
	_instance_dropdown.add_item("(Not Connected)", 0)
	_instance_list.clear()
	_remote_instances.clear()
	
	# First, try remote debugging via debugger plugin
	if _debugger_plugin and _debugger_plugin.is_session_active():
		_debugger_plugin.request_instances()
		_append_output("[color=cyan]Querying remote game process...[/color]\n")
		return  # Results will come via callback
	
	# Fallback to in-process instances (for @tool scripts)
	if _vg_repl != null:
		_instance_list = _vg_repl.get_running_instances()
		
		for i in range(_instance_list.size()):
			var info: Dictionary = _instance_list[i]
			var label = _format_instance_label(info, i)
			_instance_dropdown.add_item(label, i + 1)
			
			if info.get("instance_ptr", 0) == _connected_instance_ptr:
				_instance_dropdown.select(i + 1)
	
	if _instance_list.is_empty():
		_append_output("[color=yellow]No running VisualGasic instances found.[/color]\n")
		if _debugger_plugin == null or not _debugger_plugin.is_session_active():
			_append_output("[color=gray]Tip: Start the game with F5 or F6, then click refresh.[/color]\n")
	else:
		_append_output("[color=cyan]Found %d in-process instance(s)[/color]\n" % _instance_list.size())

func _format_instance_label(info: Dictionary, index: int) -> String:
	var label = ""
	if info.has("node_name"):
		label = str(info["node_name"])
	elif info.has("script_path"):
		label = info["script_path"].get_file()
	else:
		label = "Instance %d" % index
	
	if info.has("script_path"):
		label += " (" + info["script_path"].get_file() + ")"
	return label

func _on_remote_instances_updated(instances: Array) -> void:
	"""Called when debugger receives instance list from running game"""
	_remote_instances = instances
	_instance_dropdown.clear()
	_instance_dropdown.add_item("(Not Connected)", 0)
	
	var found_connected := false
	for i in range(instances.size()):
		var info = instances[i]
		var label = _format_instance_label(info, i)
		_instance_dropdown.add_item("[Remote] " + label, i + 1)
		
		if info.get("id", -1) == _connected_remote_id:
			_instance_dropdown.select(i + 1)
			found_connected = true
	
	if instances.is_empty():
		_append_output("[color=yellow]No VisualGasic instances in running game.[/color]\n")
	else:
		_append_output("[color=lime]Found %d remote instance(s) in game![/color]\n" % instances.size())
		
		# Auto-connect if there's exactly one instance and we're not already connected
		if instances.size() == 1 and _connected_remote_id < 0 and not found_connected:
			var info = instances[0]
			var remote_id = info.get("id", -1)
			if remote_id >= 0:
				_instance_dropdown.select(1)  # Select the first (and only) instance
				_connect_to_remote_instance(remote_id)
				_append_output("[color=aqua]Auto-connected to single instance.[/color]\n")

func _on_remote_variable_received(var_name: String, value: Variant) -> void:
	"""Called when debugger receives a variable value"""
	if value == null:
		_append_output("[color=yellow]'" + var_name + "' = null[/color]\n")
	else:
		_append_output("[color=lime]" + var_name + " = " + str(value) + "[/color] [color=gray](remote)[/color]\n")

func _on_remote_variables_received(variables: Dictionary) -> void:
	"""Called when debugger receives all variables from an instance"""
	# Update the session variables dictionary with remote variables
	_variables = variables.duplicate()
	
	# Only print to output if not auto-refreshing (to avoid spam)
	if not _auto_refresh_timer or not _auto_refresh_timer.time_left > 0 or not _auto_refresh_enabled:
		if variables.is_empty():
			_append_output("[color=gray]No variables found in instance[/color]\n")
		else:
			_append_output("[b]Remote Instance Variables:[/b]\n")
			for key in variables.keys():
				_append_output("  [color=lime]%s[/color] = %s\n" % [key, str(variables[key])])
	
	# Refresh the Variables panel tree
	_update_variables_tree()
	
	# Also update watch expressions with the new variable values
	_update_watch_expressions()

func _on_whenever_sections_received(sections: Array) -> void:
	"""Called when debugger receives Whenever sections from an instance"""
	_whenever_sections = sections
	_update_whenever_tree()

func _refresh_whenever_sections():
	"""Request Whenever sections from the connected remote instance"""
	if _connected_remote_id >= 0 and _debugger_plugin:
		_debugger_plugin.request_whenever_sections(_connected_remote_id)
	else:
		_append_output("[color=yellow]Not connected to a remote instance[/color]\n")

func _update_whenever_tree():
	"""Update the Whenever tree with current sections data"""
	if not _whenever_tree:
		return
	
	_whenever_tree.clear()
	var root = _whenever_tree.create_item()
	
	if _whenever_sections.is_empty():
		var item = _whenever_tree.create_item(root)
		item.set_text(0, "(No Whenever statements)")
		item.set_custom_color(0, Color.GRAY)
		return
	
	for section in _whenever_sections:
		var item = _whenever_tree.create_item(root)
		
		# Build condition string: "SectionName: Variable Operator [Value]"
		var section_name: String = section.get("name", "")
		var var_name: String = section.get("variable", "")
		var op: String = section.get("operator", "")
		var val = section.get("value", "")
		var val2 = section.get("value2", "")
		
		# Format: "SectionName: Variable Operator Value"
		var condition = section_name
		if not var_name.is_empty():
			condition += ": " + var_name
			if not op.is_empty():
				condition += " " + op.capitalize()
				if op.to_upper() == "BETWEEN":
					condition += " " + str(val) + " And " + str(val2)
				elif op.to_upper() != "CHANGES":
					condition += " " + str(val)
		
		item.set_text(0, condition)
		item.set_tooltip_text(0, "Section: " + section_name + "\nVariable: " + var_name + "\nOperator: " + op)
		
		# Status
		var is_active: bool = section.get("is_active", true)
		if is_active:
			item.set_text(1, "✓ Active")
			item.set_custom_color(1, Color.LIME_GREEN)
		else:
			item.set_text(1, "⏸ Paused")
			item.set_custom_color(1, Color.YELLOW)
		
		# Callbacks
		var callback_names: String = section.get("callback_names", "")
		if callback_names.is_empty():
			callback_names = "(none)"
		item.set_text(2, callback_names)
		
		# Scope
		var scope: String = section.get("scope_type", "global")
		item.set_text(3, scope)
		if scope == "local":
			item.set_custom_color(3, Color.CYAN)
		
		# Store section name for context menu
		item.set_meta("section_name", section.get("name", ""))
		item.set_meta("is_active", is_active)

func _on_whenever_tree_gui_input(event: InputEvent):
	"""Handle right-click on Whenever tree"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var item = _whenever_tree.get_item_at_position(event.position)
		if item and item.has_meta("section_name"):
			_whenever_tree.set_selected(item, 0)
			var is_active: bool = item.get_meta("is_active", true)
			# Update menu items based on state
			_whenever_context_menu.set_item_disabled(0, not is_active)  # Pause disabled if already paused
			_whenever_context_menu.set_item_disabled(1, is_active)      # Resume disabled if already active
			_whenever_context_menu.position = Vector2i(get_screen_position()) + Vector2i(event.position)
			_whenever_context_menu.popup()

func _on_whenever_context_menu_selected(id: int):
	"""Handle Whenever context menu selection"""
	var selected = _whenever_tree.get_selected()
	if not selected or not selected.has_meta("section_name"):
		return
	
	var section_name: String = selected.get_meta("section_name")
	
	match id:
		0:  # Pause
			if _connected_remote_id >= 0 and _debugger_plugin:
				_debugger_plugin.set_whenever_active(_connected_remote_id, section_name, false)
				_append_output("[color=yellow]Paused Whenever: %s[/color]\n" % section_name)
		1:  # Resume
			if _connected_remote_id >= 0 and _debugger_plugin:
				_debugger_plugin.set_whenever_active(_connected_remote_id, section_name, true)
				_append_output("[color=lime]Resumed Whenever: %s[/color]\n" % section_name)
		2:  # Go to Definition
			_go_to_whenever_definition(section_name)

func _go_to_whenever_definition(section_name: String):
	"""Navigate to Whenever statement in script"""
	if _current_script_path.is_empty():
		_append_output("[color=yellow]No script path available[/color]\n")
		return
	
	# Search for the Whenever statement
	var file = FileAccess.open(_current_script_path, FileAccess.READ)
	if not file:
		_append_output("[color=red]Could not open script: %s[/color]\n" % _current_script_path)
		return
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	var target_line = -1
	
	# Search for Whenever with this section name or matching condition
	for i in range(lines.size()):
		var line_upper = lines[i].strip_edges().to_upper()
		if line_upper.begins_with("WHENEVER "):
			# Check if this line contains the section name or matches the condition
			if lines[i].containsn(section_name):
				target_line = i
				break
	
	if target_line >= 0:
		# Open the script and go to line
		var script = load(_current_script_path)
		if script:
			EditorInterface.edit_resource(script)
			await get_tree().process_frame
			var script_editor = EditorInterface.get_script_editor()
			var current = script_editor.get_current_editor()
			if current:
				var code_edit = current.get_base_editor()
				if code_edit:
					code_edit.set_caret_line(target_line)
					code_edit.center_viewport_to_caret()
					_append_output("[color=lime]Jumped to Whenever at line %d[/color]\n" % (target_line + 1))
	else:
		_append_output("[color=yellow]Whenever '%s' not found in script[/color]\n" % section_name)

func _on_instance_selected(index: int):
	"""Handle instance dropdown selection"""
	if index == 0:
		_disconnect_from_instance()
	else:
		var list_index = index - 1
		
		# Check if we have remote instances first
		if not _remote_instances.is_empty() and list_index < _remote_instances.size():
			var info = _remote_instances[list_index]
			var remote_id = info.get("id", -1)
			if remote_id >= 0:
				_connect_to_remote_instance(remote_id)
				return
		
		# Fallback to local instances
		if list_index >= 0 and list_index < _instance_list.size():
			var info = _instance_list[list_index]
			var ptr = info.get("instance_ptr", 0)
			if ptr != 0:
				_connect_to_instance(ptr)

func _connect_to_instance(instance_ptr: int):
	"""Connect to a specific in-process instance by pointer"""
	if _vg_repl == null:
		return
	
	if _vg_repl.connect_to_instance(instance_ptr):
		_connected_instance_ptr = instance_ptr
		_connected_remote_id = -1
		_append_output("[color=green]✓ Connected to local instance[/color]\n")
		_show_connected_variables()
	else:
		_append_output("[color=red]Failed to connect to instance[/color]\n")

func _connect_to_remote_instance(instance_id: int):
	"""Connect to a remote game instance via debugger"""
	_connected_remote_id = instance_id
	_connected_instance_ptr = 0
	_append_output("[color=lime]✓ Connected to remote instance #%d[/color]\n" % instance_id)
	
	# Get the script path for this instance
	for info in _remote_instances:
		if info.get("id", -1) == instance_id:
			_current_script_path = info.get("script_path", "")
			break
	
	# Start auto-refresh timer for live updates
	if _auto_refresh_timer:
		_auto_refresh_timer.start()
	
	# Request variables and Whenever sections from the remote instance
	if _debugger_plugin:
		_debugger_plugin.request_all_variables(instance_id)
		_debugger_plugin.request_whenever_sections(instance_id)

func _disconnect_from_instance():
	"""Disconnect from the current instance"""
	if _vg_repl != null:
		_vg_repl.disconnect_instance()
	_connected_instance_ptr = 0
	_connected_remote_id = -1
	_current_script_path = ""
	_whenever_sections = []
	_instance_dropdown.select(0)
	
	# Stop auto-refresh timer
	if _auto_refresh_timer:
		_auto_refresh_timer.stop()
	
	# Clear the Whenever tree
	_update_whenever_tree()
	
	_append_output("[color=gray]Disconnected from instance[/color]\n")

func _is_connected_to_remote() -> bool:
	return _connected_remote_id >= 0

func _show_running_instances():
	"""Show list of running instances (for :instances command)"""
	_refresh_running_instances()
	
	if _instance_list.is_empty():
		return
	
	_append_output("\n[b]Running VisualGasic Instances:[/b]\n")
	for i in range(_instance_list.size()):
		var info = _instance_list[i]
		var label = "  %d: " % i
		if info.has("node_name"):
			label += str(info["node_name"])
		if info.has("script_path"):
			label += " [" + info["script_path"].get_file() + "]"
		if info.has("node_path"):
			label += " @ " + str(info["node_path"])
		_append_output(label + "\n")
	_append_output("[color=gray]Use ':connect N' to connect to instance N[/color]\n\n")

func _connect_to_instance_by_index(arg: String):
	"""Connect to instance by index (for :connect N command)"""
	if arg.is_empty():
		_append_output("[color=red]Usage: :connect N (where N is instance index)[/color]\n")
		return
	
	var index = arg.to_int()
	
	# Refresh instance list if empty
	if _instance_list.is_empty():
		_refresh_running_instances()
	
	if index < 0 or index >= _instance_list.size():
		_append_output("[color=red]Invalid instance index. Use :instances to see available.[/color]\n")
		return
	
	var info = _instance_list[index]
	var ptr = info.get("instance_ptr", 0)
	if ptr != 0:
		_connect_to_instance(ptr)
		_instance_dropdown.select(index + 1)

func _show_connected_variables():
	"""Show variables from the connected instance"""
	if _vg_repl == null or not _vg_repl.is_instance_connected():
		return
	
	var vars = _vg_repl.get_connected_instance_variables()
	if vars.is_empty():
		_append_output("[color=gray]No accessible variables found[/color]\n")
	else:
		_append_output("[b]Instance Variables:[/b]\n")
		for key in vars.keys():
			var val = vars[key]
			_append_output("  %s = %s\n" % [key, str(val)])
		_append_output("\n")

func _is_connected_to_instance() -> bool:
	"""Check if currently connected to a running instance"""
	return _vg_repl != null and _vg_repl.is_instance_connected()

func _evaluate_remote(expr: String) -> String:
	"""Evaluate an expression on the remote game instance"""
	if not _debugger_plugin or _connected_remote_id < 0:
		return "[color=red]Not connected to remote instance[/color]"
	
	var upper = expr.strip_edges().to_upper()
	
	# Handle Print/? queries
	if upper.begins_with("PRINT ") or expr.strip_edges().begins_with("? "):
		var var_name = ""
		if expr.strip_edges().begins_with("? "):
			var_name = expr.strip_edges().substr(2).strip_edges()
		else:
			var_name = expr.strip_edges().substr(6).strip_edges()
		
		# If it's a string literal (quoted), evaluate as code
		if var_name.begins_with("\"") or var_name.begins_with("'"):
			_debugger_plugin.evaluate_code(_connected_remote_id, expr.strip_edges(), func(result):
				if result == null:
					_append_output("[color=gray](no return value)[/color]\n")
				else:
					_append_output("[color=lime]" + str(result) + "[/color] [color=gray](remote)[/color]\n")
			)
			return "[color=gray]Evaluating...[/color]"
		
		# Simple variable name — request its value from remote
		_debugger_plugin.request_variable(_connected_remote_id, var_name)
		return "[color=gray]Requesting " + var_name + "...[/color]"
	
	# Handle assignment
	if "=" in expr and not "==" in expr:
		var parts = expr.split("=", true, 1)
		var var_name = parts[0].strip_edges()
		var value_str = parts[1].strip_edges() if parts.size() > 1 else ""
		
		# Parse simple values
		var value: Variant
		if value_str.is_valid_int():
			value = value_str.to_int()
		elif value_str.is_valid_float():
			value = value_str.to_float()
		else:
			value = value_str
		
		_debugger_plugin.set_variable(_connected_remote_id, var_name, value)
		return "[color=lime]Set " + var_name + " = " + str(value) + "[/color] [color=gray](remote)[/color]"
	
	# Generic evaluation — execute as VB6 code on the remote instance
	_debugger_plugin.evaluate_code(_connected_remote_id, expr.strip_edges(), func(result):
		if result == null:
			_append_output("[color=gray](no return value)[/color]\n")
		else:
			_append_output("[color=lime]" + str(result) + "[/color] [color=gray](remote)[/color]\n")
	)
	return "[color=gray]Evaluating...[/color]"

# ============================================================================
# STEP DEBUGGING UI HANDLERS
# ============================================================================

func _on_debug_continue() -> void:
	"""Resume execution after a breakpoint or step."""
	if _debugger_plugin and _debugger_plugin.is_session_active():
		_debugger_plugin.debug_continue()
		_update_debug_status("Running...")
		_append_output("[color=lime]▶ Continuing execution...[/color]\n")
	else:
		_append_output("[color=yellow]No active debug session[/color]\n")

func _on_debug_step_over() -> void:
	"""Step to the next line, stepping over function calls."""
	if _debugger_plugin and _debugger_plugin.is_session_active():
		_debugger_plugin.debug_step_over()
		_update_debug_status("Stepping over...")
		_append_output("[color=cyan]⤵ Step over[/color]\n")
	else:
		_append_output("[color=yellow]No active debug session[/color]\n")

func _on_debug_step_into() -> void:
	"""Step to the next line, entering function calls."""
	if _debugger_plugin and _debugger_plugin.is_session_active():
		_debugger_plugin.debug_step_into()
		_update_debug_status("Stepping into...")
		_append_output("[color=cyan]↓ Step into[/color]\n")
	else:
		_append_output("[color=yellow]No active debug session[/color]\n")

func _on_debug_step_out() -> void:
	"""Step out of the current function."""
	if _debugger_plugin and _debugger_plugin.is_session_active():
		_debugger_plugin.debug_step_out()
		_update_debug_status("Stepping out...")
		_append_output("[color=cyan]↑ Step out[/color]\n")
	else:
		_append_output("[color=yellow]No active debug session[/color]\n")

func _update_debug_status(status: String) -> void:
	"""Update the debug status label."""
	if _debug_status_label:
		_debug_status_label.text = status

func _on_debug_break_hit(file: String, line: int) -> void:
	"""Called when a breakpoint or step is hit."""
	_update_debug_status("⏸ Paused at %s:%d" % [file.get_file(), line])
	_append_output("[color=yellow]⏸ Paused at %s line %d[/color]\n" % [file.get_file(), line])
	# Switch to Variables tab to show current state
	if _right_tabs:
		_right_tabs.current_tab = 0  # Vars tab
	# Auto-connect to the remote debug session if not already connected
	if not _is_connected_to_remote() and _debugger_plugin and _debugger_plugin.is_session_active():
		_refresh_running_instances()
	# Navigate to the line in the script editor
	_go_to_script_line(file, line)

func _on_debug_print_received(text: String) -> void:
	"""Called when a Debug.Print statement is executed in the running game."""
	_append_output("[color=cyan][Debug] " + text + "[/color]\n")

func _on_debug_state_received(state: Dictionary) -> void:
	"""Called when debug state is received from game."""
	var step_mode = state.get("step_mode", 0)
	var current_line = state.get("current_line", 0)
	var current_file = state.get("current_file", "")
	
	if step_mode == 0 and current_line > 0:
		_update_debug_status("⏸ Line %d" % current_line)
	elif step_mode == 0:
		_update_debug_status("")

func _go_to_script_line(file_path: String, line: int) -> void:
	"""Navigate to a specific line in a script file in the editor."""
	print("[VG Immediate] _go_to_script_line: ", file_path, " line ", line)
	if file_path.is_empty() or line <= 0:
		print("[VG Immediate] Invalid file_path or line")
		return
	
	# .vg files are handled by the main plugin's _on_debug_break_navigate handler
	# which opens them in the embedded VG code editor. Skip Godot's Script editor.
	if file_path.ends_with(".vg"):
		return
	
	# Load the script resource
	if not ResourceLoader.exists(file_path):
		print("[VG Immediate] Script not found: ", file_path)
		return
	
	var script = load(file_path)
	if script:
		print("[VG Immediate] Opening script and navigating to line ", line)
		# Switch to Script editor first
		EditorInterface.set_main_screen_editor("Script")
		# Open script and navigate to line
		EditorInterface.edit_script(script, line, 0)
		# Center on line after a short delay
		call_deferred("_center_editor_on_line", line)

func _center_editor_on_line(line: int) -> void:
	"""Center the script editor viewport on the specified line."""
	var script_editor = EditorInterface.get_script_editor()
	if not script_editor:
		return
	
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
	
	var code_edit = current_editor.get_base_editor() as CodeEdit
	if code_edit:
		# Line numbers in CodeEdit are 0-based
		code_edit.set_caret_line(line - 1)
		code_edit.set_caret_column(0)
		code_edit.center_viewport_to_caret()
		code_edit.grab_focus()
