@tool
extends VBoxContainer
## VB6-Style Embedded Code Editor

const VGTheme = preload("res://addons/visual_gasic/vg_theme_utils.gd")
const VGCommandHelp = preload("res://addons/visual_gasic/vg_command_help.gd")
##
## Replaces the Form Designer canvas in-place when the user double-clicks a
## control or chooses View → Code.  The Toolbox, Properties panel, and Project
## Explorer all remain visible — exactly like VB6.
##
## Layout (top to bottom):
##   ┌─────────────────────────────────────────────┐
##   │ [Object ▼]  [Event ▼]                       │  ← procedure nav bar
##   ├─────────────────────────────────────────────┤
##   │                                             │
##   │            VGCodeEdit (.vg source)          │  ← full code editor
##   │                                             │
##   └─────────────────────────────────────────────┘

# =============================================================================
# SIGNALS
# =============================================================================

signal view_object_requested          ## user clicked "View Object" or pressed F7
signal code_saved(path: String)       ## code was flushed to disk

# =============================================================================
# STATE
# =============================================================================

## Path to the currently loaded .vg file (e.g. "res://Form1.vg")
var _vg_path: String = ""

## Whether unsaved changes exist
var _dirty: bool = false

## The code editor widget
var _code_edit: CodeEdit = null  # will be VGCodeEdit

## Procedure navigation: Object dropdown
var _object_combo: OptionButton = null

## Procedure navigation: Event/Procedure dropdown
var _proc_combo: OptionButton = null

## Parsed procedure list: Array of { name: String, line: int }
var _procedures: Array = []

## Known control names on the form (for Object dropdown)
var _control_names: Array[String] = []

## Index Map panel — shows live index diagrams for Game UI controls
var _index_map_panel: PanelContainer = null
var _index_map_canvas: Control = null
var _index_map_toggle: Button = null
var _index_map_visible: bool = false
var _current_index_control: Dictionary = {}  # { name, type, properties }

## Left panel content: Command Help + Index Map (shown in Toolbox area during Code view)
var _left_panel_content: VBoxContainer = null  # reparented into ToolboxPanel by plugin
var _help_scroll: ScrollContainer = null
var _help_label: RichTextLabel = null
var _last_help_keyword: String = ""        # avoid redundant redraws

## Main split: code editor (top) / bottom panel (bottom) — resizable like VB6
var _main_split: VSplitContainer = null

## Bottom panel: tabbed — Immediate, Output, System Console
var _bottom_panel: Control = null           # outer container (plain Control — NOT PanelContainer)
var _bottom_tabs: TabContainer = null      # tab switcher
var _immediate_window_ref = null           # reference to the plugin's Immediate Window
var _output_text: RichTextLabel = null     # Output tab: build/runtime messages
var _console_text: RichTextLabel = null    # System Console tab: system log

## System Console: Godot log file tailing (cross-platform)
var _log_file_path: String = ""
var _log_file_pos: int = 0                 # byte offset for incremental reads
var _log_timer: Timer = null               # polls log file every 0.5s
var _log_max_lines: int = 500              # keep console from growing unbounded

# VB6 cream theme colors
const BG_COLOR := Color(0.96, 0.95, 0.92)         # warm cream — easy on the eyes
const TEXT_COLOR := Color(0.1, 0.1, 0.1)           # near-black text
const KEYWORD_COLOR := Color(0.0, 0.0, 0.6)        # dark blue keywords
const COMMENT_COLOR := Color(0.0, 0.5, 0.0)        # green comments
const STRING_COLOR := Color(0.6, 0.0, 0.0)         # dark red strings
const NUMBER_COLOR := Color(0.0, 0.4, 0.4)         # teal numbers
const TOOLBAR_BG := Color(0.92, 0.91, 0.87)        # slightly darker toolbar
const BORDER_COLOR := Color(0.75, 0.74, 0.70)      # subtle border

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	name = "EmbeddedCodeEditor"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_build_ui()

func _build_ui() -> void:
	# ── Procedure navigation bar ──
	var nav_bar := HBoxContainer.new()
	nav_bar.name = "ProcNavBar"
	nav_bar.custom_minimum_size.y = 28
	nav_bar.add_theme_constant_override("separation", 4)

	# Background panel for the nav bar
	var nav_panel := PanelContainer.new()
	nav_panel.name = "NavPanel"
	var nav_sb := StyleBoxFlat.new()
	nav_sb.bg_color = TOOLBAR_BG
	nav_sb.border_color = BORDER_COLOR
	nav_sb.set_border_width_all(1)
	nav_sb.border_width_top = 0
	nav_sb.content_margin_left = 4
	nav_sb.content_margin_right = 4
	nav_sb.content_margin_top = 2
	nav_sb.content_margin_bottom = 2
	nav_panel.add_theme_stylebox_override("panel", nav_sb)

	var nav_hbox := HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 8)

	# Object dropdown (left half)
	_object_combo = OptionButton.new()
	_object_combo.name = "ObjectCombo"
	_object_combo.custom_minimum_size.x = 160
	_object_combo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_object_combo.tooltip_text = "Object"
	_object_combo.add_theme_font_size_override("font_size", 12)
	_object_combo.item_selected.connect(_on_object_selected)
	VGTheme.hook_option_button(_object_combo)
	nav_hbox.add_child(_object_combo)

	# Procedure dropdown (right half)
	_proc_combo = OptionButton.new()
	_proc_combo.name = "ProcCombo"
	_proc_combo.custom_minimum_size.x = 160
	_proc_combo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proc_combo.tooltip_text = "Procedure"
	_proc_combo.add_theme_font_size_override("font_size", 12)
	_proc_combo.item_selected.connect(_on_proc_selected)
	VGTheme.hook_option_button(_proc_combo)
	nav_hbox.add_child(_proc_combo)

	nav_panel.add_child(nav_hbox)
	add_child(nav_panel)

	# ── Code editor ──
	var code_edit_script = load("res://addons/visual_gasic/vg_code_edit.gd")
	if code_edit_script:
		_code_edit = code_edit_script.new()
	else:
		# Fallback to plain CodeEdit
		_code_edit = CodeEdit.new()
		push_warning("VG Embedded Code Editor: vg_code_edit.gd not found, using plain CodeEdit")

	_code_edit.name = "CodeEdit"
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_code_edit.text_changed.connect(_on_code_changed)
	_code_edit.caret_changed.connect(_on_caret_moved)
	VGTheme.hook_text_edit(_code_edit)

	# ── Left-panel content: Command Help + Index Map (reparented by plugin) ──
	_build_left_panel_content()

	# ── Bottom panel: Immediate Window ──
	_build_bottom_panel()

	# ── Main split: code editor (top) + bottom panel (bottom) ──
	# VSplitContainer guarantees the bottom panel gets proper space and
	# the user can drag the splitter to resize — just like VB6.
	_main_split = VSplitContainer.new()
	_main_split.name = "MainSplit"
	_main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_main_split.add_theme_constant_override("separation", 4)
	_main_split.add_theme_constant_override("minimum_grab_thickness", 6)
	_main_split.add_child(_code_edit)
	_main_split.add_child(_bottom_panel)
	add_child(_main_split)

	# Apply theme AFTER add_child so VGCodeEdit._ready() has already run.
	# _ready() creates a CodeHighlighter with dark-background colors;
	# the theme must override those afterwards.
	_apply_vb6_theme()

	# Scrollbar children may not be ready until the node enters the tree,
	# so apply scrollbar styling on a deferred call.
	call_deferred("_apply_scrollbar_theme")

	# Start Godot log file tailing for System Console (cross-platform)
	_start_log_tailing()

func _build_left_panel_content() -> void:
	## Build Command Help + Index Map as a standalone VBoxContainer.
	## The plugin reparents this into the ToolboxPanel when Code view is active.
	_left_panel_content = VBoxContainer.new()
	_left_panel_content.name = "CodeHelpPanel"
	_left_panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_panel_content.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Title label
	var title := Label.new()
	title.text = "  Command Help"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.0, 0.0, 0.4))
	_left_panel_content.add_child(title)

	# Help text
	_build_help_panel()
	_left_panel_content.add_child(_help_scroll)

	# Index Map (below help text)
	_build_index_map_panel()
	_left_panel_content.add_child(_index_map_panel)

	# Don't add to self — the plugin will place it in the ToolboxPanel


func _build_bottom_panel() -> void:
	# Use a plain Control (NOT PanelContainer) so that child minimum sizes
	# are NOT propagated to the VSplitContainer — this lets the user drag
	# the splitter to collapse the bottom panel as small as they want.
	_bottom_panel = Control.new()
	_bottom_panel.name = "BottomPanel"
	_bottom_panel.clip_contents = true
	_bottom_panel.custom_minimum_size = Vector2(0, 80)
	_bottom_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Draw VB6 cream background via a Panel child
	var bg_panel := Panel.new()
	bg_panel.name = "BG"
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.94, 0.93, 0.90)
	panel_sb.border_color = BORDER_COLOR
	panel_sb.border_width_top = 1
	panel_sb.content_margin_left = 0
	panel_sb.content_margin_right = 0
	panel_sb.content_margin_top = 0
	panel_sb.content_margin_bottom = 0
	bg_panel.add_theme_stylebox_override("panel", panel_sb)
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bottom_panel.add_child(bg_panel)

	# TabContainer with VB6-style tab theming
	_bottom_tabs = TabContainer.new()
	_bottom_tabs.name = "BottomTabs"
	_bottom_tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bottom_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_tabs.clip_contents = true
	# VB6 cream theme for tabs
	var tab_sb := StyleBoxFlat.new()
	tab_sb.bg_color = Color(0.96, 0.95, 0.92)
	tab_sb.border_color = BORDER_COLOR
	tab_sb.set_border_width_all(1)
	tab_sb.border_width_bottom = 0
	tab_sb.content_margin_left = 8
	tab_sb.content_margin_right = 8
	tab_sb.content_margin_top = 3
	tab_sb.content_margin_bottom = 3
	var tab_unsel := StyleBoxFlat.new()
	tab_unsel.bg_color = Color(0.88, 0.87, 0.84)
	tab_unsel.border_color = BORDER_COLOR
	tab_unsel.set_border_width_all(1)
	tab_unsel.content_margin_left = 8
	tab_unsel.content_margin_right = 8
	tab_unsel.content_margin_top = 3
	tab_unsel.content_margin_bottom = 3
	var tab_panel_sb := StyleBoxFlat.new()
	tab_panel_sb.bg_color = Color(0.94, 0.93, 0.90)
	tab_panel_sb.border_color = BORDER_COLOR
	tab_panel_sb.set_border_width_all(1)
	tab_panel_sb.border_width_top = 0
	tab_panel_sb.content_margin_left = 2
	tab_panel_sb.content_margin_right = 2
	tab_panel_sb.content_margin_top = 2
	tab_panel_sb.content_margin_bottom = 2
	_bottom_tabs.add_theme_stylebox_override("tab_selected", tab_sb)
	_bottom_tabs.add_theme_stylebox_override("tab_unselected", tab_unsel)
	_bottom_tabs.add_theme_stylebox_override("tab_hovered", tab_sb)
	_bottom_tabs.add_theme_stylebox_override("panel", tab_panel_sb)
	_bottom_tabs.add_theme_font_size_override("font_size", 11)
	_bottom_tabs.add_theme_color_override("font_selected_color", Color(0.0, 0.0, 0.4))
	_bottom_tabs.add_theme_color_override("font_unselected_color", Color(0.3, 0.3, 0.3))

	# Tab 0: Immediate — placeholder, populated via set_immediate_window()
	var imm_placeholder := Control.new()
	imm_placeholder.name = "Immediate"
	imm_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	imm_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_tabs.add_child(imm_placeholder)

	# Tab 1: Output — build messages, runtime output, Debug.Print
	var output_container := VBoxContainer.new()
	output_container.name = "Output"
	output_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output_text = RichTextLabel.new()
	_output_text.name = "OutputText"
	_output_text.bbcode_enabled = true
	_output_text.scroll_following = true
	_output_text.selection_enabled = true
	_output_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var out_sb := StyleBoxFlat.new()
	out_sb.bg_color = Color(0.96, 0.95, 0.92)
	out_sb.content_margin_left = 6
	out_sb.content_margin_right = 4
	out_sb.content_margin_top = 4
	out_sb.content_margin_bottom = 4
	_output_text.add_theme_stylebox_override("normal", out_sb)
	_output_text.add_theme_font_size_override("normal_font_size", 11)
	_output_text.add_theme_font_size_override("mono_font_size", 11)
	_output_text.add_theme_color_override("default_color", Color(0.1, 0.1, 0.1))
	_output_text.text = ""
	_output_text.append_text("[color=#555555][i]Build and runtime output will appear here.[/i][/color]\n")
	output_container.add_child(_output_text)
	_bottom_tabs.add_child(output_container)

	# Tab 2: System Console — system-level log messages
	var console_container := VBoxContainer.new()
	console_container.name = "System Console"
	console_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_console_text = RichTextLabel.new()
	_console_text.name = "ConsoleText"
	_console_text.bbcode_enabled = true
	_console_text.scroll_following = true
	_console_text.selection_enabled = true
	_console_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_console_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var con_sb := StyleBoxFlat.new()
	con_sb.bg_color = Color(0.12, 0.12, 0.14)  # dark console background
	con_sb.content_margin_left = 6
	con_sb.content_margin_right = 4
	con_sb.content_margin_top = 4
	con_sb.content_margin_bottom = 4
	_console_text.add_theme_stylebox_override("normal", con_sb)
	_console_text.add_theme_font_size_override("normal_font_size", 11)
	_console_text.add_theme_font_size_override("mono_font_size", 11)
	_console_text.add_theme_color_override("default_color", Color(0.8, 0.9, 0.8))  # green-on-dark
	_console_text.text = ""
	_console_text.append_text("[color=#6688aa]System Console ready.[/color]\n")
	console_container.add_child(_console_text)
	_bottom_tabs.add_child(console_container)

	_bottom_panel.add_child(_bottom_tabs)
	# Don't add_child here — _build_ui() adds _bottom_panel to the VSplitContainer

## Receives the existing Immediate Window from the plugin and embeds it here.
func set_immediate_window(window: Control) -> void:
	if not window or not _bottom_tabs:
		push_warning("set_immediate_window: window or _bottom_tabs not ready")
		return
	_immediate_window_ref = window
	# Reparent: remove from old parent
	if window.get_parent():
		window.get_parent().remove_child(window)
	window.visible = true  # Was hidden while parked on the plugin
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Remove the placeholder and insert the real window at index 0 (Immediate tab)
	var placeholder = _bottom_tabs.get_child(0)
	if placeholder and placeholder.name == "Immediate":
		_bottom_tabs.remove_child(placeholder)
		placeholder.queue_free()
	window.name = "Immediate"
	_bottom_tabs.add_child(window)
	_bottom_tabs.move_child(window, 0)
	_bottom_tabs.current_tab = 0

## Returns the Command Help + Index Map panel for the plugin to place
## in the left panel (ToolboxPanel) during Code view.
func get_help_panel() -> Control:
	return _left_panel_content

## Switch to the Immediate tab.
func focus_immediate() -> void:
	if _bottom_tabs:
		_bottom_tabs.current_tab = 0

## Switch to the Output tab.
func focus_output() -> void:
	if _bottom_tabs:
		_bottom_tabs.current_tab = 1

## Append a line to the Output tab.
func append_output(msg: String, color: Color = Color(0.1, 0.1, 0.1)) -> void:
	if _output_text:
		_output_text.append_text("[color=#" + color.to_html(false) + "]" + msg + "[/color]\n")

## Append a line to the System Console tab.
func append_console(msg: String, color: Color = Color(0.8, 0.9, 0.8)) -> void:
	if _console_text:
		_console_text.append_text("[color=#" + color.to_html(false) + "]" + msg + "[/color]\n")

## Switch to the System Console tab.
func focus_console() -> void:
	if _bottom_tabs:
		_bottom_tabs.current_tab = 2

## Clear the Output tab.
func clear_output() -> void:
	if _output_text:
		_output_text.clear()
		_output_text.append_text("[color=#555555][i]Output cleared.[/i][/color]\n")

## Clear the System Console tab.
func clear_console() -> void:
	if _console_text:
		_console_text.clear()
		_console_text.append_text("[color=#6688aa]Console cleared.[/color]\n")

# =============================================================================
# SYSTEM CONSOLE: Godot log file tailing (works on all platforms)
# =============================================================================

func _start_log_tailing() -> void:
	# Godot writes logs to user://logs/godot.log on all platforms
	_log_file_path = ProjectSettings.globalize_path("user://logs/godot.log")
	if not FileAccess.file_exists(_log_file_path):
		# Try alternate path
		var alt = ProjectSettings.globalize_path("user://logs")
		var dir = DirAccess.open(alt)
		if dir:
			dir.list_dir_begin()
			var fname = dir.get_next()
			while fname != "":
				if fname.ends_with(".log"):
					_log_file_path = alt + "/" + fname
					break
				fname = dir.get_next()
			dir.list_dir_end()

	# Seek to end of file (only show new messages)
	if FileAccess.file_exists(_log_file_path):
		var f = FileAccess.open(_log_file_path, FileAccess.READ)
		if f:
			_log_file_pos = f.get_length()
			f.close()
		append_console("Tailing: " + _log_file_path, Color(0.5, 0.6, 0.7))
	else:
		append_console("Log file not found — console shows manually routed messages only.", Color(0.7, 0.6, 0.4))

	# Poll every 0.5s
	_log_timer = Timer.new()
	_log_timer.wait_time = 0.5
	_log_timer.autostart = true
	_log_timer.timeout.connect(_poll_log_file)
	add_child(_log_timer)

func _poll_log_file() -> void:
	if _log_file_path.is_empty() or not FileAccess.file_exists(_log_file_path):
		return
	var f = FileAccess.open(_log_file_path, FileAccess.READ)
	if not f:
		return
	var file_len = f.get_length()
	if file_len <= _log_file_pos:
		f.close()
		return
	# Read new bytes
	f.seek(_log_file_pos)
	var new_text = f.get_buffer(file_len - _log_file_pos).get_string_from_utf8()
	_log_file_pos = file_len
	f.close()

	if new_text.is_empty():
		return

	# Parse each line and colorize by severity
	for line in new_text.split("\n"):
		if line.strip_edges().is_empty():
			continue
		var color := "#88aa88"  # default: muted green
		var line_lower = line.to_lower()
		if line_lower.contains("error") or line_lower.contains("err "):
			color = "#ff6666"  # red for errors
		elif line_lower.contains("warning") or line_lower.contains("warn"):
			color = "#ddaa44"  # amber for warnings
		elif line_lower.contains("visualgasic") or line_lower.contains("[vg"):
			color = "#66ccff"  # cyan for VG messages
		if _console_text:
			_console_text.append_text("[color=" + color + "]" + line + "[/color]\n")

func _build_help_panel() -> void:
	_help_scroll = ScrollContainer.new()
	_help_scroll.name = "HelpScroll"
	_help_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_help_label = RichTextLabel.new()
	_help_label.name = "HelpLabel"
	_help_label.bbcode_enabled = true
	_help_label.fit_content = true
	_help_label.scroll_active = false  # let the ScrollContainer handle scrolling
	_help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Force VB6 cream theme — override the Godot editor dark theme
	_help_label.add_theme_font_size_override("normal_font_size", 11)
	_help_label.add_theme_font_size_override("bold_font_size", 11)
	_help_label.add_theme_font_size_override("italics_font_size", 11)
	_help_label.add_theme_font_size_override("mono_font_size", 10)
	_help_label.add_theme_color_override("default_color", Color(0.1, 0.1, 0.1))
	_help_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))

	# Transparent background so the cream panel shows through
	var help_sb := StyleBoxFlat.new()
	help_sb.bg_color = Color(0.96, 0.95, 0.92)  # cream, matching BG_COLOR
	help_sb.content_margin_left = 6
	help_sb.content_margin_right = 4
	help_sb.content_margin_top = 4
	help_sb.content_margin_bottom = 4
	_help_label.add_theme_stylebox_override("normal", help_sb)

	# Welcome text
	_help_label.text = ""
	_help_label.append_text("[color=#555555][i]Place the cursor on a keyword to see its documentation.[/i][/color]")

	_help_scroll.add_child(_help_label)

func _build_index_map_panel() -> void:
	# Container for the index map: toggle header + drawing area
	_index_map_panel = PanelContainer.new()
	_index_map_panel.name = "IndexMapPanel"
	_index_map_panel.visible = false
	_index_map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index_map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.94, 0.93, 0.90)
	panel_sb.border_color = BORDER_COLOR
	panel_sb.border_width_top = 1
	panel_sb.content_margin_left = 4
	panel_sb.content_margin_right = 4
	panel_sb.content_margin_top = 0
	panel_sb.content_margin_bottom = 4
	_index_map_panel.add_theme_stylebox_override("panel", panel_sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	# Header row with toggle button + title
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)

	_index_map_toggle = Button.new()
	_index_map_toggle.text = "▼ Index Map"
	_index_map_toggle.tooltip_text = "Show/hide indexed signal map for the current Game UI control"
	_index_map_toggle.flat = true
	_index_map_toggle.add_theme_font_size_override("font_size", 11)
	_index_map_toggle.add_theme_color_override("font_color", Color(0.2, 0.2, 0.5))
	_index_map_toggle.pressed.connect(_toggle_index_map)
	header.add_child(_index_map_toggle)

	var hspacer := Control.new()
	hspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hspacer)

	vbox.add_child(header)

	# Drawing canvas for the index diagram
	_index_map_canvas = Control.new()
	_index_map_canvas.name = "IndexMapCanvas"
	_index_map_canvas.custom_minimum_size = Vector2(0, 120)
	_index_map_canvas.draw.connect(_draw_index_map)
	_index_map_canvas.visible = true
	vbox.add_child(_index_map_canvas)

	_index_map_panel.add_child(vbox)
	# Note: _index_map_panel is added to _left_panel_content by _build_left_panel_content()

func _toggle_index_map() -> void:
	_index_map_visible = not _index_map_visible
	if _index_map_canvas:
		_index_map_canvas.visible = _index_map_visible
	if _index_map_toggle:
		_index_map_toggle.text = ("▼ Index Map" if _index_map_visible else "▶ Index Map")
	# Recalculate minimum size if collapsed
	if _index_map_panel:
		if _index_map_visible:
			_index_map_panel.custom_minimum_size.y = 0
		else:
			_index_map_panel.custom_minimum_size.y = 0

func _apply_vb6_theme() -> void:
	if not _code_edit:
		return

	# Try to apply theme from VGThemeManager first
	var theme_mgr_script = load("res://addons/visual_gasic/vg_theme_manager.gd")
	if theme_mgr_script and theme_mgr_script.has_method("apply_to_code_edit"):
		theme_mgr_script.apply_to_code_edit(_code_edit)
		return

	# Fallback: VB6 Classic cream theme
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = BG_COLOR
	bg_sb.border_color = BORDER_COLOR
	bg_sb.set_border_width_all(1)
	_code_edit.add_theme_stylebox_override("normal", bg_sb)

	_code_edit.add_theme_color_override("font_color", TEXT_COLOR)
	_code_edit.add_theme_color_override("caret_color", TEXT_COLOR)
	_code_edit.add_theme_color_override("font_selected_color", Color.WHITE)
	_code_edit.add_theme_color_override("selection_color", Color(0.2, 0.4, 0.8, 0.5))
	_code_edit.add_theme_color_override("current_line_color", Color(0.93, 0.92, 0.88))
	_code_edit.add_theme_color_override("line_number_color", Color(0.5, 0.5, 0.5))

	# Override syntax highlighter colors for VB6 look
	if _code_edit.syntax_highlighter and _code_edit.syntax_highlighter is CodeHighlighter:
		var hl: CodeHighlighter = _code_edit.syntax_highlighter
		# Re-color keywords to dark blue
		for keyword in _get_vb6_keywords():
			hl.add_keyword_color(keyword, KEYWORD_COLOR)
		hl.number_color = NUMBER_COLOR
		hl.symbol_color = Color(0.3, 0.3, 0.3)
		hl.function_color = TEXT_COLOR
		hl.member_variable_color = TEXT_COLOR

func _get_vb6_keywords() -> Array:
	# Minimal set — VGCodeEdit already has these, this is fallback
	return [
		"Dim", "Sub", "Function", "End", "If", "Then", "Else", "ElseIf",
		"Select", "Case", "For", "To", "Step", "Next", "Each", "In",
		"Do", "Loop", "While", "Wend", "Until", "With", "Exit",
		"GoTo", "GoSub", "Call", "Return", "And", "Or", "Not", "Xor",
		"Mod", "Is", "Like", "As", "New", "Set", "Let", "Get",
		"Private", "Public", "Static", "Const", "ReDim", "Preserve",
		"ByVal", "ByRef", "Optional", "Property", "True", "False",
		"Nothing", "Null", "Empty", "Me", "On", "Error", "Resume",
		"Print", "Debug", "Try", "Catch", "Finally", "Throw",
		"Type", "Enum", "Class", "Option", "Explicit",
		"Open", "Close", "Input", "Output", "Append", "Line",
		"Write", "Read", "Integer", "Long", "Single", "Double",
		"String", "Boolean", "Byte", "Date", "Variant", "Object",
	]

## Apply scrollbar styling so grabbers are visible against the light background.
## Uses EVERY available mechanism to force dark grabber appearance:
## 1. Per-node stylebox overrides on the actual scrollbar nodes (priority 1)
## 2. Theme on the CodeEdit with VScrollBar/HScrollBar entries (priority 2)
## 3. custom_minimum_size to make scrollbar wider
func _apply_scrollbar_theme() -> void:
	if not _code_edit:
		return

	var scroll_grabber := StyleBoxFlat.new()
	scroll_grabber.bg_color = Color(0.25, 0.25, 0.22)
	scroll_grabber.border_color = Color(0.15, 0.15, 0.12)
	scroll_grabber.set_border_width_all(1)
	scroll_grabber.set_corner_radius_all(2)
	scroll_grabber.content_margin_left = 3
	scroll_grabber.content_margin_right = 3
	scroll_grabber.content_margin_top = 3
	scroll_grabber.content_margin_bottom = 3

	var scroll_grabber_hl := scroll_grabber.duplicate()
	scroll_grabber_hl.bg_color = Color(0.18, 0.18, 0.16)

	var scroll_grabber_pr := scroll_grabber.duplicate()
	scroll_grabber_pr.bg_color = Color(0.10, 0.10, 0.08)

	var scroll_track := StyleBoxFlat.new()
	scroll_track.bg_color = Color(0.88, 0.87, 0.84)

	# ── Method 1: Theme on the CodeEdit ──
	var t := Theme.new()
	for sb_type in ["VScrollBar", "HScrollBar", "ScrollBar"]:
		t.set_stylebox("grabber", sb_type, scroll_grabber)
		t.set_stylebox("grabber_highlight", sb_type, scroll_grabber_hl)
		t.set_stylebox("grabber_pressed", sb_type, scroll_grabber_pr)
		t.set_stylebox("scroll", sb_type, scroll_track)
	_code_edit.theme = t

	# ── Method 2: Per-node overrides on the actual scrollbar nodes ──
	var vbar = _code_edit.get_v_scroll_bar()
	var hbar = _code_edit.get_h_scroll_bar()
	for bar in [vbar, hbar]:
		if bar:
			bar.add_theme_stylebox_override("grabber", scroll_grabber)
			bar.add_theme_stylebox_override("grabber_highlight", scroll_grabber_hl)
			bar.add_theme_stylebox_override("grabber_pressed", scroll_grabber_pr)
			bar.add_theme_stylebox_override("scroll", scroll_track)
			bar.custom_minimum_size = Vector2(14, 14)

# =============================================================================
# INDEX MAP PANEL — Live index diagram for Game UI controls
# =============================================================================

## Game UI control types that have indexed signals
const INDEXED_CONTROL_TYPES := {
	"InventoryGrid": { "signal": "slot_clicked(row, col)", "layout": "grid" },
	"GameMenu": { "signal": "button_clicked(index)", "layout": "list" },
	"RadialMenu": { "signal": "item_clicked(index)", "layout": "radial" },
}

## Called from the plugin to provide control info from the form designer
func set_index_map_control(info: Dictionary) -> void:
	_current_index_control = info
	_update_index_map_visibility()
	if _index_map_canvas and _index_map_canvas.visible:
		_index_map_canvas.queue_redraw()

## Update the index map when the selected object changes
func _update_index_map_visibility() -> void:
	# The bottom panel (help + index map) is always visible
	if _bottom_panel:
		_bottom_panel.visible = true
	if not _index_map_panel:
		return
	var ctrl_type: String = _current_index_control.get("type", "")
	if ctrl_type in INDEXED_CONTROL_TYPES:
		_index_map_panel.visible = true
		_index_map_visible = true
		if _index_map_toggle:
			_index_map_toggle.text = "▼ Index Map — " + _current_index_control.get("name", "") + " (" + ctrl_type + ")"
		if _index_map_canvas:
			_index_map_canvas.visible = true
	else:
		_index_map_panel.visible = false

## Custom draw callback for the index map canvas
func _draw_index_map() -> void:
	if not _index_map_canvas or _current_index_control.is_empty():
		return
	var ctrl_type: String = _current_index_control.get("type", "")
	var ctrl_name: String = _current_index_control.get("name", "")
	var props: Dictionary = _current_index_control.get("properties", {})
	var size: Vector2 = _index_map_canvas.size
	var font: Font = _index_map_canvas.get_theme_default_font()
	if not font:
		return
	var fs := 10

	# Background
	_index_map_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.96, 0.96, 0.94))

	# Colors
	var cell_bg := Color(0.18, 0.22, 0.30, 0.85)
	var cell_border := Color(0.35, 0.45, 0.60, 0.7)
	var label_color := Color(0.85, 0.9, 1.0)
	var sig_color := Color(0.2, 0.2, 0.5)
	var header_color := Color(0.1, 0.1, 0.3)

	if ctrl_type == "InventoryGrid":
		_draw_inventory_grid_map(size, font, fs, props, cell_bg, cell_border, label_color, sig_color, header_color)
	elif ctrl_type == "GameMenu":
		_draw_game_menu_map(size, font, fs, props, cell_bg, cell_border, label_color, sig_color, header_color)
	elif ctrl_type == "RadialMenu":
		_draw_radial_menu_map(size, font, fs, props, cell_bg, cell_border, label_color, sig_color, header_color)

func _draw_inventory_grid_map(size: Vector2, font: Font, fs: int, props: Dictionary,
		cell_bg: Color, cell_border: Color, label_color: Color, sig_color: Color, header_color: Color) -> void:
	var rows: int = int(props.get("Rows", 4))
	var cols: int = int(props.get("Columns", 4))
	rows = max(rows, 1)
	cols = max(cols, 1)

	# Signal info header
	_index_map_canvas.draw_string(font, Vector2(8, 14),
		"Signal: slot_clicked(row, col)    Rows: " + str(rows) + "  Cols: " + str(cols),
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, fs, sig_color)

	# Grid diagram
	var grid_top := 24.0
	var avail_w := size.x - 20.0
	var avail_h := size.y - grid_top - 8.0
	var cell_w: float = min(avail_w / cols, 40.0)
	var cell_h: float = min(avail_h / rows, 28.0)
	cell_w = max(cell_w, 18.0)
	cell_h = max(cell_h, 16.0)
	var grid_w: float = cols * cell_w
	var grid_h: float = rows * cell_h
	var ox: float = (size.x - grid_w) * 0.5
	var oy: float = grid_top + (avail_h - grid_h) * 0.5
	oy = max(oy, grid_top)

	var small_fs: int = max(7, fs - 1)
	for row in range(rows):
		for col in range(cols):
			var cx: float = ox + col * cell_w
			var cy: float = oy + row * cell_h
			var cell_rect := Rect2(cx + 1, cy + 1, cell_w - 2, cell_h - 2)
			_index_map_canvas.draw_rect(cell_rect, cell_bg)
			_index_map_canvas.draw_rect(cell_rect, cell_border, false, 1.0)
			# Label: "r,c"
			var lbl := str(row) + "," + str(col)
			var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs).x
			_index_map_canvas.draw_string(font,
				Vector2(cx + (cell_w - lw) * 0.5, cy + (cell_h + small_fs * 0.7) * 0.5),
				lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, label_color)

func _draw_game_menu_map(size: Vector2, font: Font, fs: int, props: Dictionary,
		cell_bg: Color, cell_border: Color, label_color: Color, sig_color: Color, header_color: Color) -> void:
	var labels: PackedStringArray = []
	var _btn_raw := ""
	if props.has("Buttons"):
		_btn_raw = str(props["Buttons"])
	elif props.has("ButtonLabels"):
		_btn_raw = str(props["ButtonLabels"])
	if not _btn_raw.is_empty():
		# Strip PackedStringArray(...) wrapper if present
		if _btn_raw.begins_with("PackedStringArray(") and _btn_raw.ends_with(")"):
			_btn_raw = _btn_raw.substr(18, _btn_raw.length() - 19)
			_btn_raw = _btn_raw.replace('"', '')
		labels = _btn_raw.split(",", false)
		for i in labels.size():
			labels[i] = labels[i].strip_edges()
	if labels.is_empty():
		labels = PackedStringArray(["Resume", "Settings", "Quit"])
	var btn_count := labels.size()

	_index_map_canvas.draw_string(font, Vector2(8, 14),
		"Signal: button_clicked(index)    Buttons: " + str(btn_count),
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, fs, sig_color)

	var list_top := 24.0
	var btn_h := 22.0
	var btn_w: float = min(size.x * 0.6, 200.0)
	var ox: float = (size.x - btn_w) * 0.5
	var badge_w := 24.0

	for i in range(btn_count):
		var by := list_top + i * (btn_h + 4)
		if by + btn_h > size.y:
			break
		# Index badge
		var badge_rect := Rect2(ox - badge_w - 6, by, badge_w, btn_h)
		_index_map_canvas.draw_rect(badge_rect, Color(0.1, 0.3, 0.6, 0.85))
		var idx_str := str(i)
		var idx_w := font.get_string_size(idx_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_index_map_canvas.draw_string(font,
			Vector2(badge_rect.position.x + (badge_w - idx_w) * 0.5, by + (btn_h + fs * 0.7) * 0.5),
			idx_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, label_color)
		# Button
		var btn_rect := Rect2(ox, by, btn_w, btn_h)
		_index_map_canvas.draw_rect(btn_rect, cell_bg)
		_index_map_canvas.draw_rect(btn_rect, cell_border, false, 1.0)
		_index_map_canvas.draw_string(font,
			Vector2(ox + 8, by + (btn_h + fs * 0.7) * 0.5),
			labels[i] if i < labels.size() else "",
			HORIZONTAL_ALIGNMENT_LEFT, btn_w - 16, fs, label_color)

func _draw_radial_menu_map(size: Vector2, font: Font, fs: int, props: Dictionary,
		cell_bg: Color, cell_border: Color, label_color: Color, sig_color: Color, header_color: Color) -> void:
	var item_count: int = int(props.get("ItemCount", 6))
	item_count = maxi(item_count, 1)

	_index_map_canvas.draw_string(font, Vector2(8, 14),
		"Signal: item_clicked(index)    Items: " + str(item_count),
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, fs, sig_color)

	var diagram_top := 24.0
	var avail_h := size.y - diagram_top - 8.0
	var avail_w := size.x - 16.0
	var radius: float = min(avail_w, avail_h) * 0.35
	radius = max(radius, 20.0)
	var cx: float = size.x * 0.5
	var cy: float = diagram_top + avail_h * 0.5

	# Draw wedge indicators
	for i in range(item_count):
		var angle := float(i) / float(item_count) * TAU - PI * 0.5
		var wx: float = cx + cos(angle) * radius
		var wy: float = cy + sin(angle) * radius
		# Circle
		var circle_r := 12.0
		var cr := Rect2(wx - circle_r, wy - circle_r, circle_r * 2, circle_r * 2)
		_index_map_canvas.draw_rect(cr, cell_bg)
		_index_map_canvas.draw_rect(cr, cell_border, false, 1.0)
		# Index label
		var idx_str := str(i)
		var lw := font.get_string_size(idx_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_index_map_canvas.draw_string(font,
			Vector2(wx - lw * 0.5, wy + fs * 0.35),
			idx_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, label_color)
		# Line from center to wedge
		_index_map_canvas.draw_line(Vector2(cx, cy), Vector2(wx, wy),
			Color(0.4, 0.5, 0.7, 0.3), 1.0)
	# Center dot
	_index_map_canvas.draw_rect(Rect2(cx - 3, cy - 3, 6, 6), Color(0.3, 0.3, 0.5, 0.6))

# =============================================================================
# FILE I/O
# =============================================================================

## Load a .vg file into the editor. If the file doesn't exist, creates a stub.
func load_file(path: String) -> void:
	_vg_path = path

	# Create the file if it doesn't exist
	if not FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string("' Visual Gasic Form Script\nOption Explicit\n\n")
			f.close()

	# Read file contents
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var content := f.get_as_text()
		f.close()
		_code_edit.text = content
		_dirty = false
		_rebuild_proc_list()
		_rebuild_object_combo()
		# Update status
		print("VG Code Editor: Loaded ", path)
	else:
		push_warning("VG Code Editor: Cannot open " + path)

## Save the current buffer back to disk.
func save_file() -> void:
	if _vg_path.is_empty():
		return
	# Apply VB6 "Pretty Listing" formatting before saving
	_apply_pretty_listing()
	var f := FileAccess.open(_vg_path, FileAccess.WRITE)
	if f:
		f.store_string(_code_edit.text)
		f.close()
		_dirty = false
		# Notify Godot's filesystem so it doesn't treat this as an
		# external modification and prompt "reload from disk?" on focus.
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().update_file(_vg_path)
		code_saved.emit(_vg_path)
		print("VG Code Editor: Saved ", _vg_path)

## Returns the currently loaded file path.
func get_file_path() -> String:
	return _vg_path

## Returns true if the buffer has unsaved changes.
func is_dirty() -> bool:
	return _dirty

## Returns the underlying CodeEdit node.
func get_code_edit() -> CodeEdit:
	return _code_edit

# =============================================================================
# EVENT HANDLER INJECTION
# =============================================================================

## Ensure a Sub stub exists for the given event, and navigate the caret to it.
## If it already exists, just jump to it.
func ensure_event_handler(sub_name: String, params: String = "") -> void:
	if not _code_edit:
		return

	var param_str := "(" + params + ")" if not params.is_empty() else "()"
	var full_sub := "Sub " + sub_name + param_str
	# For searching, match just the Sub name (ignore params — user may have edited them)
	var search_key := "Sub " + sub_name + "("
	var text := _code_edit.text

	# Check if sub already exists (case-insensitive)
	if text.to_lower().find(search_key.to_lower()) == -1:
		# Append the stub
		if not text.ends_with("\n"):
			text += "\n"
		text += "\n" + full_sub + "\n    \nEnd Sub\n"
		_code_edit.text = text
		_dirty = true
		_rebuild_proc_list()

	# Navigate to the body line (the blank line inside the Sub)
	var lines := _code_edit.text.split("\n")
	for i in lines.size():
		if lines[i].strip_edges().to_lower().begins_with(search_key.to_lower()):
			var body_line := i + 1
			_code_edit.set_caret_line(body_line)
			_code_edit.set_caret_column(4)
			# Deferred scroll
			_deferred_center_caret.call_deferred()
			break

	_code_edit.grab_focus()

func _deferred_center_caret() -> void:
	if is_instance_valid(_code_edit):
		_code_edit.center_viewport_to_caret()

# =============================================================================
# PROCEDURE NAVIGATION
# =============================================================================

func _rebuild_proc_list() -> void:
	_procedures.clear()
	if not _code_edit:
		return

	var lines := _code_edit.text.split("\n")
	var rx := RegEx.new()
	rx.compile("^\\s*(?:(?:Public|Private|Static)\\s+)?(?:Sub|Function|Property\\s+(?:Get|Let|Set))\\s+(\\w+)")

	for i in lines.size():
		var m := rx.search(lines[i])
		if m:
			_procedures.append({ "name": m.get_string(1), "line": i, "full": lines[i].strip_edges() })

	# Populate the procedure combo
	_proc_combo.clear()
	_proc_combo.add_item("(Declarations)", 0)
	for idx in _procedures.size():
		var p = _procedures[idx]
		_proc_combo.add_item(p["name"], idx + 1)

	# Select current procedure based on caret position
	_update_proc_selection()

func _rebuild_object_combo() -> void:
	_object_combo.clear()
	_object_combo.add_item("(General)")

	# Add form controls
	for ctrl_name in _control_names:
		_object_combo.add_item(ctrl_name)

	# If file has Form_ events, add "Form" as an object
	if _code_edit and _code_edit.text.find("Form_") != -1:
		# Check it's not already listed
		var has_form := false
		for i in _object_combo.item_count:
			if _object_combo.get_item_text(i) == "Form":
				has_form = true
				break
		if not has_form:
			_object_combo.add_item("Form")

## Sets the list of form control names for the Object dropdown.
func set_control_names(names: Array[String]) -> void:
	_control_names = names
	_rebuild_object_combo()

## Full control info list from the form designer (for Index Map panel)
var _control_info_list: Array[Dictionary] = []

## Called from the plugin to store the complete control metadata.
func set_control_info_list(info_list: Array[Dictionary]) -> void:
	_control_info_list = info_list
	# Update the index map if it's currently showing
	_update_index_map_for_current_object()

## Looks up control info by name from the cached list.
func _find_control_info(ctrl_name: String) -> Dictionary:
	for info in _control_info_list:
		if info.get("name", "") == ctrl_name:
			return info
	return {}

## Updates the index map panel based on the currently selected object in the dropdown.
func _update_index_map_for_current_object() -> void:
	if not _object_combo or _object_combo.get_selected_id() < 0:
		return
	var obj_name: String = _object_combo.get_item_text(_object_combo.selected)
	if obj_name == "(General)":
		set_index_map_control({})
		return
	var info := _find_control_info(obj_name)
	if not info.is_empty():
		set_index_map_control(info)
	else:
		set_index_map_control({})

func _update_proc_selection() -> void:
	if not _code_edit or _procedures.is_empty():
		# Select (Declarations)
		if _proc_combo.item_count > 0:
			_proc_combo.select(0)
		return

	var caret_line := _code_edit.get_caret_line()

	# Find which procedure the caret is inside
	var best_idx := -1
	for i in _procedures.size():
		if _procedures[i]["line"] <= caret_line:
			best_idx = i

	if best_idx >= 0:
		# +1 because item 0 is "(Declarations)"
		_proc_combo.select(best_idx + 1)

		# Also update object combo to match
		var proc_name: String = _procedures[best_idx]["name"]
		if "_" in proc_name:
			var obj_name := proc_name.get_slice("_", 0)
			for i in _object_combo.item_count:
				if _object_combo.get_item_text(i) == obj_name:
					_object_combo.select(i)
					break
		# Update Index Map for the current object
		_update_index_map_for_current_object()
	else:
		_proc_combo.select(0)
		_update_index_map_for_current_object()

func _on_proc_selected(index: int) -> void:
	if index == 0:
		# (Declarations) — go to top of file
		_code_edit.set_caret_line(0)
		_code_edit.set_caret_column(0)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()
		return

	var proc_idx := index - 1
	if proc_idx >= 0 and proc_idx < _procedures.size():
		var line: int = _procedures[proc_idx]["line"]
		_code_edit.set_caret_line(line + 1)  # body line
		_code_edit.set_caret_column(4)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()

func _on_object_selected(index: int) -> void:
	var obj_name := _object_combo.get_item_text(index)
	if obj_name == "(General)":
		# Jump to declarations area (top)
		_code_edit.set_caret_line(0)
		_code_edit.set_caret_column(0)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()
		_update_index_map_for_current_object()
		return

	# Filter procedures for this object and update proc combo
	var filtered: Array = []
	for p in _procedures:
		if p["name"].begins_with(obj_name + "_"):
			filtered.append(p)

	if filtered.size() > 0:
		# Jump to first event for this object
		_code_edit.set_caret_line(filtered[0]["line"] + 1)
		_code_edit.set_caret_column(4)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()

	# Update Index Map for the selected object
	_update_index_map_for_current_object()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_code_changed() -> void:
	_dirty = true
	# Rebuild procedure list (debounced via call_deferred to avoid per-keystroke cost)
	_rebuild_proc_list.call_deferred()
	_update_procedure_separators.call_deferred()

func _on_caret_moved() -> void:
	_update_proc_selection()
	_check_param_info()
	_update_command_help()

# =============================================================================
# COMMAND HELP PANEL
# =============================================================================

## Returns the VB6 keyword at (or near) the caret, handling multi-word
## keywords like "Select Case", "End If", "For Each", "On Error", etc.
func _get_keyword_at_cursor() -> String:
	if not _code_edit:
		return ""
	var line_idx := _code_edit.get_caret_line()
	var col := _code_edit.get_caret_column()
	var line_text := _code_edit.get_line(line_idx)
	if line_text.is_empty():
		return ""

	# Find word boundaries around the caret
	var word_start := col
	var word_end := col
	while word_start > 0 and (line_text[word_start - 1].is_valid_identifier() or line_text[word_start - 1] == "_"):
		word_start -= 1
	while word_end < line_text.length() and (line_text[word_end].is_valid_identifier() or line_text[word_end] == "_"):
		word_end += 1
	if word_start >= word_end:
		return ""
	var word := line_text.substr(word_start, word_end - word_start).strip_edges()

	# Check for compound keywords — look at the word before/after
	var compound_pairs := {
		# "first second" compounds
		"select": "Select Case",
		"for": "For Each",
		"on": "On Error",
		"line": "Line Input",
		"option": "Option Explicit",
		# "End Xxx" compounds
		"end": "",  # handled specially below
	}

	var lower := word.to_lower()

	# If cursor is on "End", look at the next word
	if lower == "end":
		var rest := line_text.substr(word_end).strip_edges()
		for suffix in ["If", "Sub", "Function", "Select", "Class", "With", "Type", "Enum"]:
			if rest.begins_with(suffix):
				return "End " + suffix
		return "End"

	# If cursor is on a word after "End", check backwards
	if word_start > 0:
		var before := line_text.substr(0, word_start).strip_edges()
		if before.to_lower().ends_with("end"):
			var kw := "End " + word
			if VGCommandHelp.lookup(kw).size() > 0:
				return kw

	# Compound keywords where the cursor is on the first word
	if lower == "select":
		var rest := line_text.substr(word_end).strip_edges()
		if rest.to_lower().begins_with("case"):
			return "Select Case"
	if lower == "for":
		var rest := line_text.substr(word_end).strip_edges()
		if rest.to_lower().begins_with("each"):
			return "For Each"
	if lower == "on":
		var rest := line_text.substr(word_end).strip_edges()
		if rest.to_lower().begins_with("error"):
			return "On Error"
	if lower == "line":
		var rest := line_text.substr(word_end).strip_edges()
		if rest.to_lower().begins_with("input"):
			return "Line Input"
	if lower == "option":
		var rest := line_text.substr(word_end).strip_edges()
		if rest.to_lower().begins_with("explicit"):
			return "Option Explicit"

	# Compound keywords where the cursor is on the second word
	if lower == "case":
		var before := line_text.substr(0, word_start).strip_edges()
		if before.to_lower().ends_with("select"):
			return "Select Case"
	if lower == "each":
		var before := line_text.substr(0, word_start).strip_edges()
		if before.to_lower().ends_with("for"):
			return "For Each"
	if lower == "error":
		var before := line_text.substr(0, word_start).strip_edges()
		if before.to_lower().ends_with("on"):
			return "On Error"

	return word

## Updates the Command Help panel with documentation for the keyword at cursor.
func _update_command_help() -> void:
	if not _help_label:
		return
	var keyword := _get_keyword_at_cursor()
	if keyword == _last_help_keyword:
		return  # No change
	_last_help_keyword = keyword

	if keyword.is_empty():
		_help_label.text = ""
		_help_label.append_text("[color=#555555][i]Place the cursor on a keyword to see its documentation.[/i][/color]")
		return

	var entry := VGCommandHelp.lookup(keyword)
	if entry.is_empty():
		# ── Fallback: scan current script for user-declared symbols ──
		var user_entry := _lookup_user_symbol(keyword)
		if not user_entry.is_empty():
			entry = user_entry
		else:
			_help_label.text = ""
			_help_label.append_text("[color=#555555][i]No documentation for \"" + keyword + "\"[/i][/color]")
			return

	# Reset the scroll position
	if _help_scroll:
		_help_scroll.scroll_vertical = 0

	_help_label.text = ""

	# ── Keyword title ──
	_help_label.append_text("[b][color=#00006B][font_size=12]" + entry.get("keyword", keyword) + "[/font_size][/color][/b]\n\n")

	# ── Syntax ──
	_help_label.append_text("[b][color=#00006B]Syntax[/color][/b]\n")
	_help_label.append_text("[color=#333333][code]" + entry.get("syntax", "") + "[/code][/color]\n\n")

	# ── Description ──
	_help_label.append_text("[b][color=#00006B]Description[/color][/b]\n")
	_help_label.append_text("[color=#222222]" + entry.get("desc", "") + "[/color]\n\n")

	# ── Code Example ──
	var code_text: String = entry.get("code", "")
	if not code_text.is_empty():
		_help_label.append_text("[b][color=#00006B]Example[/color][/b]\n")
		_help_label.append_text("[color=#333333][code]" + code_text + "[/code][/color]\n\n")

	# ── Reference link ──
	var ref_line: int = entry.get("ref_line", 0)
	if ref_line > 0:
		_help_label.append_text("[color=#555555][i]📖 Programmer's Reference, line " + str(ref_line) + "[/i][/color]")

## Scans the current script for user-declared variables, constants, and
## Sub/Function definitions matching the given keyword.
## Returns a Dictionary in the same format as VGCommandHelp entries, or empty.
func _lookup_user_symbol(keyword: String) -> Dictionary:
	if not _code_edit or keyword.is_empty():
		return {}
	var kw_lower := keyword.to_lower()
	var lines := _code_edit.text.split("\n")

	# ── Pass 1: Variable declarations (Dim / Private / Public / Static / Global) ──
	for i in lines.size():
		var sline := lines[i].strip_edges()
		var sl := sline.to_lower()

		# Determine declaration keyword and offset
		var decl_kw := ""
		var offset := 0
		if sl.begins_with("dim "):
			decl_kw = "Dim"; offset = 4
		elif sl.begins_with("private ") and not sl.begins_with("private sub ") and not sl.begins_with("private function ") and not sl.begins_with("private const "):
			decl_kw = "Private"; offset = 8
		elif sl.begins_with("public ") and not sl.begins_with("public sub ") and not sl.begins_with("public function ") and not sl.begins_with("public const "):
			decl_kw = "Public"; offset = 7
		elif sl.begins_with("static "):
			decl_kw = "Static"; offset = 7
		elif sl.begins_with("global "):
			decl_kw = "Global"; offset = 7
		else:
			# Not a variable declaration — check next patterns below
			pass

		if not decl_kw.is_empty():
			var rest := sline.substr(offset).strip_edges()
			# Extract variable name
			var vname := ""
			var ci := 0
			while ci < rest.length() and (rest[ci].is_valid_identifier() or rest[ci] == "_"):
				vname += rest[ci]
				ci += 1
			if vname.to_lower() == kw_lower:
				# Extract type
				var vtype := "Variant"
				var after := rest.substr(ci).strip_edges()
				# Handle array parens: Dim arr(10) As Integer
				if after.begins_with("("):
					var close := after.find(")")
					if close >= 0:
						after = after.substr(close + 1).strip_edges()
						vtype = "Array"
				if after.to_lower().begins_with("as "):
					var tpart := after.substr(3).strip_edges()
					if tpart.to_lower().begins_with("new "):
						tpart = tpart.substr(4).strip_edges()
					# Extract type name (may include * N for fixed-length strings)
					var tname := ""
					for ti in tpart.length():
						var tc := tpart[ti]
						if tc.is_valid_identifier() or tc == "_" or tc == "*" or tc == " ":
							tname += tc
						else:
							break
					tname = tname.strip_edges()
					if not tname.is_empty():
						vtype = tname
				# Check for initial value: = something
				var init_val := ""
				var eq_pos := rest.find("=")
				if eq_pos >= 0:
					init_val = rest.substr(eq_pos).strip_edges()
					# Remove trailing comment
					var cmt := init_val.find("'")
					if cmt >= 0:
						init_val = init_val.substr(0, cmt).strip_edges()
				var scope := decl_kw
				if decl_kw == "Dim":
					scope = "Local variable"
				elif decl_kw == "Private":
					scope = "Private variable"
				elif decl_kw == "Public":
					scope = "Public variable"
				elif decl_kw == "Global":
					scope = "Global variable"
				elif decl_kw == "Static":
					scope = "Static variable"
				var syntax_str := decl_kw + " " + vname + " As " + vtype
				if not init_val.is_empty():
					syntax_str += " " + init_val
				var desc_str := scope + " declared on line " + str(i + 1) + ".\nType: " + vtype
				if not init_val.is_empty():
					desc_str += "\nInitial value: " + init_val.substr(2).strip_edges() if init_val.begins_with("= ") else "\nInitial value: " + init_val.substr(1).strip_edges()
				return {
					"keyword": vname + "  As " + vtype,
					"syntax": syntax_str,
					"desc": desc_str,
					"code": "",
					"ref_line": 0,
				}

	# ── Pass 2: Const declarations ──
	for i in lines.size():
		var sline := lines[i].strip_edges()
		var sl := sline.to_lower()

		var const_offset := -1
		var const_scope := ""
		if sl.begins_with("const "):
			const_offset = 6; const_scope = "Const"
		elif sl.begins_with("public const "):
			const_offset = 14; const_scope = "Public Const"
		elif sl.begins_with("private const "):
			const_offset = 15; const_scope = "Private Const"

		if const_offset >= 0:
			var rest := sline.substr(const_offset).strip_edges()
			var cname := ""
			var ci := 0
			while ci < rest.length() and (rest[ci].is_valid_identifier() or rest[ci] == "_"):
				cname += rest[ci]
				ci += 1
			if cname.to_lower() == kw_lower:
				var after := rest.substr(ci).strip_edges()
				# Remove trailing comment
				var cmt := after.find("'")
				if cmt >= 0:
					after = after.substr(0, cmt).strip_edges()
				return {
					"keyword": cname + "  (Const)",
					"syntax": const_scope + " " + cname + " " + after,
					"desc": "Constant declared on line " + str(i + 1) + ".\nValue cannot be changed at runtime.",
					"code": "",
					"ref_line": 0,
				}

	# ── Pass 3: Sub / Function definitions ──
	var rx := RegEx.new()
	rx.compile("(?i)^\\s*(?:(Public|Private|Static)\\s+)?(?:(Sub|Function))\\s+" + keyword.replace("(", "\\(") + "\\s*\\(([^)]*)\\)(.*)")
	for i in lines.size():
		var m := rx.search(lines[i])
		if m:
			var scope := m.get_string(1) if not m.get_string(1).is_empty() else "Public"
			var kind := m.get_string(2)  # Sub or Function
			var params := m.get_string(3).strip_edges()
			var trailer := m.get_string(4).strip_edges()
			# Extract return type for Functions
			var ret_type := ""
			if kind.to_lower() == "function":
				var tl := trailer.to_lower()
				var as_pos := tl.find("as ")
				if as_pos >= 0:
					ret_type = trailer.substr(as_pos + 3).strip_edges()
					# Remove trailing comment
					var cmt := ret_type.find("'")
					if cmt >= 0:
						ret_type = ret_type.substr(0, cmt).strip_edges()
			var syntax_str := scope + " " + kind + " " + keyword + "(" + params + ")"
			if not ret_type.is_empty():
				syntax_str += " As " + ret_type
			var param_desc := ""
			if not params.is_empty():
				param_desc = "\nParameters: " + params
			else:
				param_desc = "\nParameters: (none)"
			var desc_str := scope + " " + kind + " defined on line " + str(i + 1) + "." + param_desc
			if not ret_type.is_empty():
				desc_str += "\nReturns: " + ret_type
			var title := keyword + "(" + params + ")"
			if not ret_type.is_empty():
				title += " As " + ret_type
			return {
				"keyword": title,
				"syntax": syntax_str,
				"desc": desc_str,
				"code": "",
				"ref_line": 0,
			}

	return {}

# =============================================================================
# PROCEDURE SEPARATOR LINES
# =============================================================================

## Draws horizontal separator lines between Sub/Function/Property blocks.
## Uses CodeEdit's executing line gutter to mark lines just before each
## procedure header (the classic VB6 blue separator line).
func _update_procedure_separators() -> void:
	if not _code_edit:
		return
	# Clear old separator lines (we use line_background_color for this)
	for i in _code_edit.get_line_count():
		_code_edit.set_line_background_color(i, Color(0, 0, 0, 0))
	
	# Draw separator lines: color the line BEFORE each procedure declaration
	var lines := _code_edit.text.split("\n")
	var rx := RegEx.new()
	rx.compile("^\\s*(?:(?:Public|Private|Static)\\s+)?(?:Sub|Function|Property\\s+(?:Get|Let|Set))\\s+")
	for i in lines.size():
		if i == 0:
			continue
		var m := rx.search(lines[i])
		if m:
			# Color the line above the procedure header as a separator
			# Use a subtle dark blue/gray line
			_code_edit.set_line_background_color(i - 1, Color(0.72, 0.72, 0.78, 0.3))

# =============================================================================
# PARAMETER INFO POPUP (Signature Help)
# =============================================================================

## Shows parameter info when typing inside function call parentheses.
var _param_popup: PopupPanel = null
var _param_label: RichTextLabel = null

## VB6 built-in function signatures for parameter help.
var _builtin_signatures: Dictionary = {
	"msgbox": "MsgBox(Prompt, [Buttons], [Title])",
	"inputbox": "InputBox(Prompt, [Title], [Default])",
	"mid": "Mid(String, Start, [Length])",
	"left": "Left(String, Length)",
	"right": "Right(String, Length)",
	"instr": "InStr([Start], String1, String2)",
	"len": "Len(Expression)",
	"val": "Val(String)",
	"str": "Str(Number)",
	"cint": "CInt(Expression)",
	"clng": "CLng(Expression)",
	"cdbl": "CDbl(Expression)",
	"csng": "CSng(Expression)",
	"cstr": "CStr(Expression)",
	"trim": "Trim(String)",
	"ltrim": "LTrim(String)",
	"rtrim": "RTrim(String)",
	"ucase": "UCase(String)",
	"lcase": "LCase(String)",
	"replace": "Replace(Expression, Find, Replace, [Start], [Count])",
	"split": "Split(Expression, [Delimiter], [Limit])",
	"join": "Join(SourceArray, [Delimiter])",
	"format": "Format(Expression, [Format])",
	"iif": "IIf(Expression, TruePart, FalsePart)",
	"array": "Array(ArgList)",
	"ubound": "UBound(ArrayName, [Dimension])",
	"lbound": "LBound(ArrayName, [Dimension])",
	"rgb": "RGB(Red, Green, Blue)",
	"int": "Int(Number)",
	"fix": "Fix(Number)",
	"abs": "Abs(Number)",
	"sgn": "Sgn(Number)",
	"sqr": "Sqr(Number)",
	"rnd": "Rnd([Number])",
	"timer": "Timer()",
	"chr": "Chr(CharCode)",
	"asc": "Asc(String)",
	"space": "Space(Number)",
	"string": "String(Number, Character)",
	"open": "Open PathName For Mode As #FileNumber",
	"close": "Close #FileNumber",
	"print": "Print #FileNumber, OutputList",
	"write": "Write #FileNumber, OutputList",
	"input": "Input #FileNumber, VarList",
	"doevents": "DoEvents()",
}

func _check_param_info() -> void:
	if not _code_edit:
		return
	var line_idx = _code_edit.get_caret_line()
	var col = _code_edit.get_caret_column()
	var line_text = _code_edit.get_line(line_idx)
	if col <= 0 or col > line_text.length():
		_hide_param_popup()
		return
	
	# Walk backwards from caret to find an unmatched '('
	var paren_depth = 0
	var func_name = ""
	var arg_index = 0
	for i in range(col - 1, -1, -1):
		var ch = line_text[i]
		if ch == ")":
			paren_depth += 1
		elif ch == "(":
			if paren_depth > 0:
				paren_depth -= 1
			else:
				# Found the opening paren — extract function name
				var name_end = i
				var name_start = i - 1
				while name_start >= 0 and (line_text[name_start].is_valid_identifier() or line_text[name_start] == "_"):
					name_start -= 1
				name_start += 1
				if name_start < name_end:
					func_name = line_text.substr(name_start, name_end - name_start).strip_edges()
				break
		elif ch == "," and paren_depth == 0:
			arg_index += 1
	
	if func_name.is_empty():
		_hide_param_popup()
		return
	
	var sig = _builtin_signatures.get(func_name.to_lower(), "")
	if sig.is_empty():
		# Check user-defined procedures
		sig = _find_user_proc_signature(func_name)
	if sig.is_empty():
		_hide_param_popup()
		return
	
	_show_param_popup(sig, arg_index)

func _find_user_proc_signature(func_name: String) -> String:
	if not _code_edit:
		return ""
	var lines = _code_edit.text.split("\n")
	var rx = RegEx.new()
	rx.compile("(?i)^\\s*(?:(?:Public|Private|Static)\\s+)?(?:Sub|Function)\\s+" + func_name.replace("(", "\\(") + "\\s*\\(([^)]*)\\)")
	for line in lines:
		var m = rx.search(line)
		if m:
			return func_name + "(" + m.get_string(1) + ")"
	return ""

func _show_param_popup(signature: String, arg_index: int) -> void:
	if not _param_popup:
		_param_popup = PopupPanel.new()
		_param_popup.transparent_bg = false
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 1.0, 0.88)  # Light yellow tooltip
		sb.border_color = Color(0.0, 0.0, 0.0)
		sb.set_border_width_all(1)
		sb.content_margin_all = 4
		_param_popup.add_theme_stylebox_override("panel", sb)
		_param_label = RichTextLabel.new()
		_param_label.bbcode_enabled = true
		_param_label.fit_content = true
		_param_label.scroll_active = false
		_param_label.custom_minimum_size = Vector2(200, 20)
		_param_label.add_theme_color_override("default_color", Color.BLACK)
		_param_popup.add_child(_param_label)
		add_child(_param_popup)
	
	# Bold the current parameter
	var bbcode = _highlight_param_in_sig(signature, arg_index)
	_param_label.text = ""
	_param_label.append_text(bbcode)
	
	# Position below the caret
	if _code_edit:
		var caret_pos = _code_edit.get_caret_draw_pos()
		var global_pos = _code_edit.global_position + caret_pos + Vector2(0, 20)
		_param_popup.position = Vector2i(int(global_pos.x), int(global_pos.y))
		_param_popup.reset_size()
		_param_popup.show()

func _highlight_param_in_sig(sig: String, arg_index: int) -> String:
	# Find the parameter list inside parentheses
	var open_paren = sig.find("(")
	var close_paren = sig.rfind(")")
	if open_paren < 0 or close_paren < 0:
		return sig
	var prefix = sig.substr(0, open_paren + 1)
	var params_str = sig.substr(open_paren + 1, close_paren - open_paren - 1)
	var suffix = sig.substr(close_paren)
	var params = params_str.split(",")
	var result = prefix
	for i in params.size():
		if i > 0:
			result += ", "
		var p = params[i].strip_edges()
		if i == arg_index:
			result += "[b]" + p + "[/b]"
		else:
			result += p
	result += suffix
	return result

func _hide_param_popup() -> void:
	if _param_popup and _param_popup.visible:
		_param_popup.hide()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible or not _code_edit or not _code_edit.has_focus():
		return

	if event is InputEventKey and event.pressed:
		# Ctrl+S → save
		if event.ctrl_pressed and event.keycode == KEY_S:
			save_file()
			get_viewport().set_input_as_handled()
		# Shift+F7 → View Object (back to form)
		elif event.keycode == KEY_F7 and event.shift_pressed:
			view_object_requested.emit()
			get_viewport().set_input_as_handled()
		# F7 alone also goes back to object view (VB6 toggle behavior)
		elif event.keycode == KEY_F7 and not event.ctrl_pressed and not event.alt_pressed:
			view_object_requested.emit()
			get_viewport().set_input_as_handled()

# =============================================================================
# PRETTY LISTING (VB6 Auto-Format on Save)
# =============================================================================

## Applies VB6-style "Pretty Listing" — keyword capitalization, operator
## spacing, and auto-indent on save. Uses VGFormatter if available.
func _apply_pretty_listing() -> void:
	if not _code_edit:
		return
	# Try to load and use the VGFormatter class
	var script_class = _try_load_formatter()
	if not script_class:
		return  # No formatter available
	var formatted: String = script_class.format_text(_code_edit.text)
	if formatted != _code_edit.text and not formatted.is_empty():
		# Preserve caret position as best we can
		var caret_line = _code_edit.get_caret_line()
		var caret_col = _code_edit.get_caret_column()
		_code_edit.text = formatted
		# Restore caret (clamp to valid range)
		caret_line = mini(caret_line, _code_edit.get_line_count() - 1)
		caret_col = mini(caret_col, _code_edit.get_line(caret_line).length())
		_code_edit.set_caret_line(caret_line)
		_code_edit.set_caret_column(caret_col)

func _try_load_formatter():
	# Try to load VGFormatter as a script resource
	var script = load("res://addons/visual_gasic/vg_formatter.gd")
	if script:
		return script
	return null
