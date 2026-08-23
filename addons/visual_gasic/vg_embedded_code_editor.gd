@tool
extends VBoxContainer
## VB6-Style Embedded Code Editor

const VGTheme = preload("res://addons/visual_gasic/vg_theme_utils.gd")
const VGCommandHelp = preload("res://addons/visual_gasic/vg_command_help.gd")
const FindReferencesPanel = preload("res://addons/visual_gasic/find_references_panel.gd")
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
signal edit_in_working_nodes_requested(wnodes_path: String)  ## user clicked "Edit in WN"
signal file_path_open_hex_requested(path: String)
signal file_path_open_sprite_requested(path: String)
signal file_path_reveal_browser_requested(path: String)
signal file_path_open_external_requested(path: String)
signal dual_editor_refresh_requested()  ## user asked to reload from the other editor
signal stale_banner_dismissed(path: String)
signal buffer_edited(path: String)  ## user edited text (not peer refresh / load)

# =============================================================================
# STATE
# =============================================================================

## Path to the currently loaded .vg file (e.g. "res://Form1.vg")
var _vg_path: String = ""

## Whether unsaved changes exist
var _dirty: bool = false

## Label showing the currently open file name in the nav bar
var _file_label: Label = null

## Out-of-date strip when Godot Script tab has newer text for the same .vg
var _stale_strip: PanelContainer = null
var _stale_label: Label = null
var _applying_peer_buffer: bool = false

## Button shown when a sibling .wnodes file exists for the open .vg
var _edit_in_wn_btn: Button = null

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

var _help_scroll: ScrollContainer = null
var _help_label: RichTextLabel = null
var _last_help_keyword: String = ""        # avoid redundant redraws
var _context_rail: PanelContainer = null  # reparented into ToolboxPanel by plugin

const VGContextRail := preload("res://addons/visual_gasic/vg_context_rail.gd")
const OpenPathResolver := preload("res://addons/visual_gasic/vg_open_path_resolver.gd")

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

## Error reporting state
var _error_list: ItemList = null            # Errors tab: clickable error list
var _errors_container: VBoxContainer = null # Errors tab container
var _error_count_label: Label = null        # Status bar: "3 Errors, 1 Warning"
var _current_errors: Array = []             # Array of {line, column, message}
var _current_warnings: Array = []           # Array of {line, column, message}
var _is_validating: bool = false            # Re-entrancy guard (validate→save→validate)

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

	# File name label (leftmost in nav bar)
	_file_label = Label.new()
	_file_label.name = "FileLabel"
	_file_label.text = "(General)"
	_file_label.add_theme_font_size_override("font_size", 12)
	_file_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	_file_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_file_label.custom_minimum_size.x = 120
	_file_label.clip_text = true
	nav_hbox.add_child(_file_label)

	# "Edit in WN" — appears only when a sibling .wnodes exists.
	_edit_in_wn_btn = Button.new()
	_edit_in_wn_btn.name = "EditInWN"
	_edit_in_wn_btn.text = "→ Edit in WN"
	_edit_in_wn_btn.tooltip_text = "Open the companion .wnodes graph in the Working Nodes editor"
	_edit_in_wn_btn.add_theme_font_size_override("font_size", 11)
	_edit_in_wn_btn.visible = false
	_edit_in_wn_btn.pressed.connect(_on_edit_in_wn_pressed)
	nav_hbox.add_child(_edit_in_wn_btn)

	# Separator between file label and object combo
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 1
	nav_hbox.add_child(sep)

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

	# Error count indicator (right-aligned in nav bar)
	_error_count_label = Label.new()
	_error_count_label.name = "ErrorCountLabel"
	_error_count_label.text = ""
	_error_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_error_count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_error_count_label.add_theme_font_size_override("font_size", 11)
	_error_count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_error_count_label.custom_minimum_size.x = 140
	nav_hbox.add_child(_error_count_label)

	nav_panel.add_child(nav_hbox)
	add_child(nav_panel)

	_build_stale_strip()

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
	if _code_edit.has_signal("find_references_requested"):
		_code_edit.find_references_requested.connect(_show_find_references)
	if _code_edit.has_signal("find_callers_requested"):
		_code_edit.find_callers_requested.connect(_show_call_hierarchy)
	if _code_edit.has_signal("edit_sprite_data_requested"):
		_code_edit.edit_sprite_data_requested.connect(_on_edit_sprite_data_requested)
	if _code_edit.has_signal("file_path_action"):
		_code_edit.file_path_action.connect(_on_file_path_action)
	VGTheme.hook_text_edit(_code_edit)

	# ── Context rail (audit sidecar) — plugin reparents into ToolboxPanel during Code view ──
	_context_rail = VGContextRail.new()
	_context_rail.name = "ContextRail"
	_context_rail.visible = false
	add_child(_context_rail)  # _ready must run before deferred caret updates
	if _code_edit:
		_context_rail.bind_code_edit(_code_edit)
	_context_rail.goto_line_requested.connect(_on_context_rail_goto_line)
	if _context_rail.has_signal("file_action_requested"):
		_context_rail.file_action_requested.connect(_on_file_path_action)
	if _context_rail.has_signal("summary_insert_requested"):
		_context_rail.summary_insert_requested.connect(_on_context_rail_summary_insert)

	# ── Bottom panel: Immediate Window ──
	_build_bottom_panel()

	# ── Main split: code editor (top) + bottom panel (bottom) ──
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

	_apply_context_rail_settings()
	call_deferred("_update_context_rail")

	# Apply theme AFTER add_child so VGCodeEdit._ready() has already run.
	call_deferred("_apply_vb6_theme")
	call_deferred("_apply_scrollbar_theme")
	call_deferred("_start_log_tailing")


func _build_stale_strip() -> void:
	_stale_strip = PanelContainer.new()
	_stale_strip.name = "StaleEditorStrip"
	_stale_strip.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.82, 0.45, 0.95)
	sb.border_color = Color(0.72, 0.52, 0.12)
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_stale_strip.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := Label.new()
	icon.text = "⚠"
	icon.add_theme_font_size_override("font_size", 13)
	row.add_child(icon)
	_stale_label = Label.new()
	_stale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stale_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stale_label.add_theme_font_size_override("font_size", 11)
	_stale_label.add_theme_color_override("font_color", Color(0.25, 0.18, 0.05))
	row.add_child(_stale_label)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.tooltip_text = "Replace this editor's text with the version from the other tab"
	refresh_btn.pressed.connect(func() -> void:
		dual_editor_refresh_requested.emit()
	)
	row.add_child(refresh_btn)
	var dismiss_btn := Button.new()
	dismiss_btn.text = "Dismiss"
	dismiss_btn.pressed.connect(_dismiss_stale_strip)
	row.add_child(dismiss_btn)
	_stale_strip.add_child(row)
	add_child(_stale_strip)


func set_dual_editor_stale(stale: bool, authority_label: String = "") -> void:
	if not is_instance_valid(_stale_strip):
		return
	if not stale:
		_stale_strip.visible = false
		return
	var where := authority_label if not authority_label.is_empty() else "the other editor"
	_stale_label.text = (
		"This copy is out of date — %s has newer unsaved changes. Refresh to match it."
		% where
	)
	_stale_strip.visible = true


func _dismiss_stale_strip() -> void:
	if is_instance_valid(_stale_strip):
		_stale_strip.visible = false
	if not _vg_path.is_empty():
		stale_banner_dismissed.emit(_vg_path)


func apply_peer_buffer(text: String) -> void:
	if not _code_edit:
		return
	_applying_peer_buffer = true
	_code_edit.text = text
	_applying_peer_buffer = false
	_dirty = _buffer_differs_from_disk()
	_rebuild_proc_list()
	validate_code.call_deferred()
	_update_context_rail.call_deferred()
	set_dual_editor_stale(false)
	if is_instance_valid(_stale_strip):
		_stale_strip.visible = false


func get_buffer_text() -> String:
	return _code_edit.text if _code_edit else ""


func _buffer_differs_from_disk() -> bool:
	if _vg_path.is_empty() or not _code_edit:
		return false
	if not FileAccess.file_exists(_vg_path):
		return not _code_edit.text.is_empty()
	return _code_edit.text != FileAccess.get_file_as_string(_vg_path)


func is_applying_peer_buffer() -> bool:
	return _applying_peer_buffer


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
	# Allow many bottom tabs (AI Pair, Hex Editor, …) without losing the last ones off-screen.
	if "clip_tabs" in _bottom_tabs:
		_bottom_tabs.clip_tabs = false
	if "scroll_to_selected" in _bottom_tabs:
		_bottom_tabs.scroll_to_selected = true

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

	# Tab 3: Errors — clickable error list (VB6-style)
	_errors_container = VBoxContainer.new()
	_errors_container.name = "Errors"
	_errors_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_errors_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_error_list = ItemList.new()
	_error_list.name = "ErrorList"
	_error_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_error_list.allow_reselect = true
	_error_list.select_mode = ItemList.SELECT_SINGLE
	var err_sb := StyleBoxFlat.new()
	err_sb.bg_color = Color(0.96, 0.95, 0.92)
	err_sb.content_margin_left = 4
	err_sb.content_margin_right = 4
	err_sb.content_margin_top = 2
	err_sb.content_margin_bottom = 2
	_error_list.add_theme_stylebox_override("panel", err_sb)
	_error_list.add_theme_font_size_override("font_size", 11)
	_error_list.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_error_list.item_selected.connect(_on_error_item_selected)
	_error_list.item_activated.connect(_on_error_item_activated)
	_errors_container.add_child(_error_list)
	_bottom_tabs.add_child(_errors_container)

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

## Add an external panel as a new tab in the IDE's bottom TabContainer.
## Used by the plugin to embed VG Profiler, VG Controls, VG Packages, AI Help, etc.
func add_bottom_tab(title: String, panel: Control) -> void:
	if not _bottom_tabs:
		push_warning("add_bottom_tab: _bottom_tabs not ready yet")
		return
	if panel.get_parent():
		panel.get_parent().remove_child(panel)
	panel.name = title
	panel.visible = true
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_tabs.add_child(panel)

## Remove a previously-added bottom tab by reference.
func remove_bottom_tab(panel: Control) -> void:
	if not _bottom_tabs:
		return
	if panel.get_parent() == _bottom_tabs:
		_bottom_tabs.remove_child(panel)

## Returns the outer bottom panel (Immediate, Output, AI Pair, … tabs).
func get_bottom_panel() -> Control:
	return _bottom_panel

## Detach the bottom panel from the code-editor split or a float host.
func detach_bottom_panel() -> void:
	if not _bottom_panel:
		return
	if _bottom_panel.get_parent():
		_bottom_panel.get_parent().remove_child(_bottom_panel)

## Re-attach the bottom panel below the code editor (VG IDE Code view).
func attach_bottom_panel_to_split() -> void:
	if not _bottom_panel or not _main_split:
		return
	if _bottom_panel.get_parent() == _main_split:
		return
	detach_bottom_panel()
	_bottom_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_panel.custom_minimum_size = Vector2(0, 80)
	_main_split.add_child(_bottom_panel)
	if _main_split.get_child_count() >= 2:
		_main_split.move_child(_bottom_panel, 1)

## Re-attach the bottom panel into a floating host (Godot 2D/3D/Script IDE).
func attach_bottom_panel_to(host: Control) -> void:
	if not _bottom_panel or not host:
		return
	if _bottom_panel.get_parent() == host:
		return
	detach_bottom_panel()
	_bottom_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bottom_panel.offset_left = 0
	_bottom_panel.offset_top = 0
	_bottom_panel.offset_right = 0
	_bottom_panel.offset_bottom = 0
	_bottom_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_panel.custom_minimum_size = Vector2(200, 120)
	host.add_child(_bottom_panel)

## Switch to a specific bottom tab by panel reference.
func focus_bottom_tab(panel: Control) -> void:
	if not _bottom_tabs or not panel:
		return
	if panel.get_parent() == _bottom_tabs:
		var idx := panel.get_index()
		if idx >= 0:
			_bottom_tabs.current_tab = idx
			return
	for i in range(_bottom_tabs.get_tab_count()):
		if _bottom_tabs.get_tab_title(i) == "AI Pair" and panel.name == "AI Pair":
			_bottom_tabs.current_tab = i
			return
	var idx := panel.get_index()
	if idx >= 0:
		_bottom_tabs.current_tab = idx

func get_context_rail() -> Control:
	return _context_rail


func get_context_rail_width() -> int:
	return clampi(int(ProjectSettings.get_setting("vg/editor/context_rail_width", 260)), 160, 480)


func is_context_rail_enabled() -> bool:
	return bool(ProjectSettings.get_setting("vg/editor/context_rail_enabled", true))


func _apply_context_rail_settings() -> void:
	var enabled := is_context_rail_enabled()
	var rail_w := get_context_rail_width()
	if is_instance_valid(_context_rail):
		_context_rail.visible = enabled
		_context_rail.custom_minimum_size.x = 160
		_context_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_context_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ToolboxPanel width is updated by the plugin when the rail is mounted.
	if is_instance_valid(_context_rail) and _context_rail.get_parent():
		var host := _context_rail.get_parent()
		if host is PanelContainer and enabled:
			host.custom_minimum_size.x = rail_w

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

## Switch to the Errors tab.
func focus_errors() -> void:
	if _bottom_tabs and _errors_container:
		var idx := _errors_container.get_index()
		if idx >= 0:
			_bottom_tabs.current_tab = idx

# =============================================================================
# ERROR REPORTING: Validate, display, navigate
# =============================================================================

## Validate the current .vg file using the C++ parser.
## Returns true if the code is error-free, false otherwise.
## Automatically updates: error gutter, line backgrounds, Output tab,
## Errors tab, and status bar error count.
func validate_code() -> bool:
	if _is_validating:
		return true  # Prevent re-entrancy (validate → save → validate)
	if not _code_edit or _vg_path.is_empty():
		return true  # Nothing to validate

	_is_validating = true
	var source: String = _code_edit.text

	# Use ClassDB.class_call_static to avoid Godot 4.6 compile-time static method validation
	var result: Dictionary = {}
	if ClassDB.class_exists(&"VisualGasicLanguage"):
		result = ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_validate_code", source, _vg_path)
	else:
		# GDExtension not loaded yet — skip validation silently
		_is_validating = false
		return true

	var errors: Array = result.get("errors", [])
	var warnings: Array = result.get("warnings", [])
	var is_valid: bool = result.get("valid", true)

	_apply_validation_results(errors, warnings)
	_is_validating = false
	return is_valid

## Fallback validation: load the .vg as a script and check reload status.
## NOTE: Does NOT call save_file() to avoid infinite recursion.
func _validate_via_script_resource() -> bool:
	# Only usable if the file already exists on disk
	if not FileAccess.file_exists(_vg_path):
		return true  # Can't validate an unsaved file this way

	var script = ResourceLoader.load(_vg_path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if not script:
		_apply_validation_results([{"line": 1, "column": 0, "message": "Cannot load script: " + _vg_path}], [])
		return false

	# Script.reload() returns an Error enum — non-OK means parse failure
	var err: int = script.reload()
	if err != OK:
		_apply_validation_results([{"line": 1, "column": 0, "message": "Script has parse errors (code %d)" % err}], [])
		return false

	_apply_validation_results([], [])
	return true

## Apply validation results to all UI elements.
func _apply_validation_results(errors: Array, warnings: Array) -> void:
	_current_errors = errors
	_current_warnings = warnings

	# 1. Update code editor error gutter + line backgrounds
	if _code_edit and _code_edit.has_method("set_errors"):
		if errors.is_empty():
			_code_edit.clear_errors()
		else:
			_code_edit.set_errors(errors)

	# 2. Update Errors tab (ItemList)
	_update_errors_tab(errors, warnings)

	# 3. Update Output tab with error messages
	_update_output_with_errors(errors, warnings)

	# 4. Update status bar error count
	_update_error_count_label(errors.size(), warnings.size())

	# 5. If errors exist, switch to Errors tab
	if not errors.is_empty():
		focus_errors()

## Populate the Errors tab ItemList.
func _update_errors_tab(errors: Array, warnings: Array) -> void:
	if not _error_list:
		return
	_error_list.clear()

	for err in errors:
		var line_num: int = err.get("line", 0)
		var msg: String = err.get("message", "Unknown error")
		var display_text: String = "  ✖  Line %d: %s" % [line_num, msg]
		var idx: int = _error_list.add_item(display_text)
		_error_list.set_item_metadata(idx, {"line": line_num, "type": "error"})
		_error_list.set_item_custom_fg_color(idx, Color(0.7, 0.1, 0.1))

	for warn in warnings:
		var line_num: int = warn.get("line", 0)
		var msg: String = warn.get("message", "Unknown warning")
		var display_text: String = "  ⚠  Line %d: %s" % [line_num, msg]
		var idx: int = _error_list.add_item(display_text)
		_error_list.set_item_metadata(idx, {"line": line_num, "type": "warning"})
		_error_list.set_item_custom_fg_color(idx, Color(0.7, 0.5, 0.0))

## Append a runtime error from the running game to the Errors tab.
## Does not clear existing compile errors — runtime entries accumulate
## until the next compile that calls _update_errors_tab (which clears all).
func log_runtime_error(file: String, line: int, message: String, code: int) -> void:
	if not _error_list:
		return
	var short_file: String = file.get_file() if not file.is_empty() else "(unknown)"
	var timestamp: String = Time.get_time_string_from_system()
	var display_text: String = "  🔴  [%s] %s:%d  (Error %d)  %s" % [timestamp, short_file, line, code, message]
	var idx: int = _error_list.add_item(display_text)
	_error_list.set_item_metadata(idx, {"line": line, "type": "runtime", "file": file})
	_error_list.set_item_custom_fg_color(idx, Color(0.9, 0.4, 0.0))
	focus_errors()

## Write errors/warnings to the Output tab.
func _update_output_with_errors(errors: Array, warnings: Array) -> void:
	if not _output_text:
		return

	if errors.is_empty() and warnings.is_empty():
		return

	# Header
	var timestamp: String = Time.get_time_string_from_system()
	append_output("─── Compile Results [%s] ───" % timestamp, Color(0.3, 0.3, 0.5))

	for err in errors:
		var line_num: int = err.get("line", 0)
		var msg: String = err.get("message", "Unknown error")
		append_output("  ✖  Error on line %d: %s" % [line_num, msg], Color(0.8, 0.1, 0.1))

	for warn in warnings:
		var line_num: int = warn.get("line", 0)
		var msg: String = warn.get("message", "")
		append_output("  ⚠  Warning on line %d: %s" % [line_num, msg], Color(0.7, 0.5, 0.0))

	if not errors.is_empty():
		append_output("  %d error(s) found. Fix errors before running." % errors.size(), Color(0.6, 0.1, 0.1))
	elif not warnings.is_empty():
		append_output("  %d warning(s)." % warnings.size(), Color(0.6, 0.5, 0.0))

## Update the error count label in the toolbar.
func _update_error_count_label(error_count: int, warning_count: int) -> void:
	if not _error_count_label:
		return

	if error_count == 0 and warning_count == 0:
		_error_count_label.text = "✓ No Errors"
		_error_count_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.2))
	else:
		var parts: Array[String] = []
		if error_count > 0:
			parts.append("%d Error%s" % [error_count, "s" if error_count != 1 else ""])
		if warning_count > 0:
			parts.append("%d Warning%s" % [warning_count, "s" if warning_count != 1 else ""])
		_error_count_label.text = "✖ " + ", ".join(parts)
		if error_count > 0:
			_error_count_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
		else:
			_error_count_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.0))

## Returns the current error count.
func get_error_count() -> int:
	return _current_errors.size()

## Returns the current errors array.
func get_current_errors() -> Array:
	return _current_errors

## Returns the current warnings array.
func get_current_warnings() -> Array:
	return _current_warnings

# ── Error navigation callbacks ──

## Single-click in error list: navigate to that line.
func _on_error_item_selected(index: int) -> void:
	_navigate_to_error(index)

## Double-click in error list: navigate and focus the code editor.
func _on_error_item_activated(index: int) -> void:
	_navigate_to_error(index)
	if _code_edit:
		_code_edit.grab_focus()

## Navigate to the error's line in the code editor.
func _navigate_to_error(index: int) -> void:
	if not _error_list or not _code_edit:
		return
	if index < 0 or index >= _error_list.item_count:
		return
	var meta = _error_list.get_item_metadata(index)
	if meta is Dictionary:
		var line_1based: int = meta.get("line", 0)
		if line_1based > 0:
			var line_0based: int = line_1based - 1
			_code_edit.set_caret_line(line_0based)
			_code_edit.set_caret_column(0)
			_code_edit.center_viewport_to_caret()
			# Also select the line briefly for visibility
			_code_edit.select(line_0based, 0, line_0based, _code_edit.get_line(line_0based).length())

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
	# Allow the user to highlight and copy help text (Ctrl+C).
	_help_label.selection_enabled = true
	_help_label.context_menu_enabled = true
	_help_label.shortcut_keys_enabled = true
	_help_label.focus_mode = Control.FOCUS_CLICK

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

	# Enable clickable links (for "Used on lines" / "Modified on lines" etc.)
	_help_label.meta_underlined = true
	_help_label.meta_clicked.connect(_on_help_meta_clicked)

	# Welcome text
	_help_label.text = ""
	_help_label.append_text("[color=#555555][i]Place the cursor on a keyword to see its documentation.[/i][/color]")

	_help_scroll.add_child(_help_label)

## Handles clickable links in the Command Help panel (e.g. "Used on lines: 27, 34").
## Links use the format [url=goto:LINE_NUMBER]LINE_NUMBER[/url].
func _on_help_meta_clicked(meta: Variant) -> void:
	var s := str(meta)
	if s.begins_with("goto:"):
		var line_str := s.substr(5)
		if line_str.is_valid_int():
			var target_line := line_str.to_int() - 1  # CodeEdit is 0-based
			if _code_edit and target_line >= 0 and target_line < _code_edit.get_line_count():
				_code_edit.set_caret_line(target_line)
				_code_edit.set_caret_column(0)
				_code_edit.center_viewport_to_caret()
				_code_edit.grab_focus()
	elif s.begins_with("ref:"):
		var line_str := s.substr(4)
		if line_str.is_valid_int():
			VGCommandHelp.open_programmer_reference(line_str.to_int())
	elif s.begins_with("web:"):
		# Open URL in the default browser
		var url := s.substr(4)
		OS.shell_open(url)

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
	_code_edit.add_theme_color_override("code_folding_color", Color(0.4, 0.4, 0.4, 0.85))

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

	# ── Code completion popup styles ──
	# Without these the popup inherits the minimal Theme and may be invisible.
	var popup_bg := StyleBoxFlat.new()
	popup_bg.bg_color = Color(1.0, 1.0, 0.94)   # warm cream
	popup_bg.border_color = Color(0.55, 0.55, 0.5)
	popup_bg.set_border_width_all(1)
	popup_bg.set_corner_radius_all(2)
	popup_bg.content_margin_left = 4
	popup_bg.content_margin_right = 4
	popup_bg.content_margin_top = 4
	popup_bg.content_margin_bottom = 4
	for popup_type in ["PopupPanel", "PopupMenu", "Panel"]:
		t.set_stylebox("panel", popup_type, popup_bg)
	t.set_color("font_color", "PopupMenu", Color(0.1, 0.1, 0.1))
	t.set_color("font_hovered_color", "PopupMenu", Color(1, 1, 1))
	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color(0.2, 0.4, 0.8)
	hover_sb.set_corner_radius_all(2)
	t.set_stylebox("hover", "PopupMenu", hover_sb)
	t.set_stylebox("selected", "PopupMenu", hover_sb)

	# ── Code completion specific colors on CodeEdit ──
	_code_edit.add_theme_color_override("code_completion_background_color", Color(1.0, 1.0, 0.94))
	_code_edit.add_theme_color_override("code_completion_selected_color", Color(0.2, 0.4, 0.8, 0.4))
	_code_edit.add_theme_color_override("code_completion_existing_color", Color(0.2, 0.4, 0.8, 0.3))
	_code_edit.add_theme_color_override("code_completion_scroll_color", Color(0.55, 0.55, 0.5))
	_code_edit.add_theme_color_override("code_completion_scroll_hovered_color", Color(0.3, 0.3, 0.28))

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
##
## Linux's filesystem is case-sensitive, but Visual Gasic itself treats
## `Module1.vg` and `module1.vg` as the same module (matching the VB6/Win32
## tradition). Before creating a new stub on disk we therefore look for a
## case-insensitive match in the same directory and reuse that file if one
## exists. This prevents accidental ghost duplicates when one caller passes
## the canonical-cased path and another passes a lowercased variant.
func load_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		var canonical := _find_case_insensitive_match(path)
		if not canonical.is_empty():
			path = canonical

	_vg_path = path

	# Update the file label in the nav bar
	if is_instance_valid(_file_label):
		_file_label.text = path.get_file()
		_file_label.tooltip_text = path

	# Show the Edit-in-WN button if a sibling .wnodes exists.
	if is_instance_valid(_edit_in_wn_btn):
		var sibling := path.get_basename() + ".wnodes"
		_edit_in_wn_btn.visible = FileAccess.file_exists(sibling)
		_edit_in_wn_btn.set_meta("wnodes_path", sibling)

	# Create the file if it doesn't exist (now in canonical casing)
	if not FileAccess.file_exists(path):
		var dir_path := ProjectSettings.globalize_path(path.get_base_dir())
		DirAccess.make_dir_recursive_absolute(dir_path)
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string("' Visual Gasic Form Script\nOption Explicit\n\n")
			f.close()

	# Read file contents
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var content := f.get_as_text()
		f.close()
		if not _code_edit:
			push_warning("VG Code Editor: _code_edit not yet initialized, deferring load")
			return
		_code_edit.text = content
		_dirty = false
		set_dual_editor_stale(false)
		_rebuild_proc_list()
		_rebuild_object_combo()
		# Load bookmarks for this file
		if _code_edit.has_method("load_bookmarks"):
			_code_edit.load_bookmarks(path)
		# Validate code and display any errors
		call_deferred("validate_code")
		call_deferred("_update_context_rail")
		# Update status
		print("VG Code Editor: Loaded ", path)
	else:
		push_warning("VG Code Editor: Cannot open " + path)


## Look for an existing file in the same directory whose name matches `path`
## case-insensitively. Returns the actual on-disk path if found, otherwise "".
func _find_case_insensitive_match(path: String) -> String:
	var dir_part := path.get_base_dir()
	var file_part := path.get_file()
	if file_part.is_empty():
		return ""
	var dir := DirAccess.open(dir_part)
	if dir == null:
		return ""
	var target := file_part.to_lower()
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != ".." and entry.to_lower() == target:
			dir.list_dir_end()
			# Reuse the same separator style as the input path
			if dir_part.is_empty():
				return entry
			return dir_part + "/" + entry
		entry = dir.get_next()
	dir.list_dir_end()
	return ""

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
		# Save bookmarks alongside the file
		if _code_edit.has_method("save_bookmarks"):
			_code_edit.save_bookmarks(_vg_path)
		# Notify Godot's filesystem so it doesn't treat this as an
		# external modification and prompt "reload from disk?" on focus.
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().update_file(_vg_path)
		code_saved.emit(_vg_path)
		# Announce on the bus so anything observing this .vg (file browser,
		# bytecode profiler, AGCK "reload script slot") can refresh.
		preload("res://addons/visual_gasic/vg_asset_bus.gd").get_instance().emit_saved(_vg_path, "vg_code_editor")
		# Re-validate after save
		validate_code()
		print("VG Code Editor: Saved ", _vg_path)

## Returns the currently loaded file path.
func get_file_path() -> String:
	return _vg_path

## Handler for the "Edit in WN" nav-bar button. Emits a signal carrying the
## sibling .wnodes path so the plugin can switch tabs / open it.
func _on_edit_in_wn_pressed() -> void:
	if not is_instance_valid(_edit_in_wn_btn):
		return
	var wp := str(_edit_in_wn_btn.get_meta("wnodes_path", ""))
	if wp.is_empty() or not FileAccess.file_exists(wp):
		return
	edit_in_working_nodes_requested.emit(wp)

## Flush the current buffer to disk for a transient Run, WITHOUT marking the
## file as formally saved. The editor keeps its dirty indicator so the user
## knows their changes are still uncommitted (only Ctrl+S / File→Save clears
## that). The runtime always reads .vg from disk, so this lets the running
## game see the latest in-memory edits while preserving normal editor
## save semantics.
func flush_for_run() -> void:
	if _vg_path.is_empty():
		return
	var disk_text := ""
	if FileAccess.file_exists(_vg_path):
		disk_text = FileAccess.get_file_as_string(_vg_path)
	if _code_edit.text == disk_text:
		return  # buffer already matches disk
	var f := FileAccess.open(_vg_path, FileAccess.WRITE)
	if f:
		f.store_string(_code_edit.text)
		f.close()
		# Deliberately do NOT clear _dirty — the user has not formally saved.
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().update_file(_vg_path)
		preload("res://addons/visual_gasic/vg_asset_bus.gd").get_instance().emit_saved(_vg_path, "vg_code_editor")
		print("VG Code Editor: Flushed buffer to disk for Run (still unsaved): ", _vg_path)

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
## Explicitly select an object in the Object dropdown and show its event list,
## then highlight the specified event. Called from the 3D editor after double-click.
func select_object_and_event(obj_name: String, event_name: String) -> void:
	if not _object_combo:
		return
	# Find and select the object
	for i in _object_combo.item_count:
		if _object_combo.get_item_text(i) == obj_name:
			_object_combo.select(i)
			_rebuild_event_list_for_object(obj_name)
			# Now highlight the specific event in the proc dropdown
			for j in _proc_combo.item_count:
				var meta = _proc_combo.get_item_metadata(j)
				if meta is Dictionary and meta.get("event_name", "") == event_name:
					_proc_combo.select(j)
					break
			_update_index_map_for_current_object()
			return

func ensure_event_handler(sub_name: String, params: String = "") -> void:
	if not _code_edit:
		return

	# Defensive: if the buffer hasn't been modified by the user (_dirty is
	# false) and the on-disk content differs from what we have in memory,
	# re-read from disk before mutating the text.
	# This handles two cases:
	#   a) load_file was called before the .vg file existed — the file was
	#      created with a boilerplate stub, then the AI overwrote it via
	#      write_file AFTER load_file ran.  Buffer = stale boilerplate.
	#   b) Buffer is empty because load_file hasn't been called yet.
	# We only re-read when NOT dirty so we never discard the user's own edits.
	if not _dirty and not _vg_path.is_empty() and FileAccess.file_exists(_vg_path):
		var _df := FileAccess.open(_vg_path, FileAccess.READ)
		if _df:
			var _disk := _df.get_as_text()
			_df.close()
			if not _disk.strip_edges().is_empty() and _disk != _code_edit.text:
				_code_edit.text = _disk
				_dirty = false
				_rebuild_proc_list()
				_rebuild_object_combo()

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
			# Double-deferred scroll: first hop gets past grab_focus and layout
			# settle after a file load + view switch; second hop ensures the
			# CodeEdit has fully laid out before centering.
			_deferred_center_caret.call_deferred()
			_deferred_center_caret.call_deferred()
			break

	_code_edit.grab_focus()

func _deferred_center_caret() -> void:
	if is_instance_valid(_code_edit):
		_code_edit.set_caret_line(_code_edit.get_caret_line())  # re-assert position
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

	# Check which object is selected — show event-aware proc list if applicable
	var selected_obj := ""
	if _object_combo and _object_combo.selected >= 0:
		selected_obj = _object_combo.get_item_text(_object_combo.selected)

	if selected_obj != "" and selected_obj != "(General)":
		_rebuild_event_list_for_object(selected_obj)
	else:
		# (General) — show all procedures, same as before
		_proc_combo.clear()
		_proc_combo.add_item("(Declarations)", 0)
		for idx in _procedures.size():
			var p = _procedures[idx]
			_proc_combo.add_item(p["name"], idx + 1)
		_update_proc_selection()

## Rebuilds the procedure dropdown to show ALL available events for the given
## control, with existing (implemented) events shown in bold.  Events that
## don't have code yet are shown in normal weight — selecting them creates a
## stub and navigates there (VB6/TwinBasic/RADBasic behaviour).
func _rebuild_event_list_for_object(obj_name: String) -> void:
	_proc_combo.clear()

	# Determine the control's Godot type
	var godot_type := "Control"
	var is_array_member := false
	if obj_name == "Form":
		godot_type = "Form"
	else:
		var info := _find_control_info(obj_name)
		if not info.is_empty():
			var vb6_type: String = info.get("type", "")
			if not vb6_type.is_empty():
				godot_type = VGIntelliSense.resolve_control_type(vb6_type)
			if int(info.get("control_array_index", -1)) >= 0:
				is_array_member = true

	# Get all available events for this type
	var events: Array = VGIntelliSense.get_control_events(godot_type)

	# Build a set of existing procedures for this object
	var existing_events: Dictionary = {}  # event_name → proc index
	for idx in _procedures.size():
		var p_name: String = _procedures[idx]["name"]
		if p_name.begins_with(obj_name + "_"):
			var event_part: String = p_name.substr(obj_name.length() + 1)
			existing_events[event_part] = idx

	# Suffix applied to every event label when the object is a control-array
	# member, signalling to the developer that VB6 will inject `Index As Integer`
	# as the first parameter of the generated handler.
	var array_suffix: String = "  [array]" if is_array_member else ""

	# Populate the dropdown — existing events shown bold, others normal
	for event_name in events:
		var ev_str: String = str(event_name)
		var full_proc_name: String = obj_name + "_" + ev_str
		var is_implemented: bool = existing_events.has(ev_str)
		if is_implemented:
			_proc_combo.add_item("● " + ev_str + array_suffix)
		else:
			_proc_combo.add_item("  " + ev_str + array_suffix)
		var item_idx: int = _proc_combo.item_count - 1
		# Store the event name and implemented flag as metadata
		_proc_combo.set_item_metadata(item_idx, {
			"obj_name": obj_name,
			"event_name": ev_str,
			"full_name": full_proc_name,
			"implemented": is_implemented
		})
		# Bold implemented events by using a different font style
		if is_implemented:
			_proc_combo.set_item_disabled(item_idx, false)

	# Also add any object procedures that aren't in the standard event list
	# (user-created Subs like CmdInput_CustomHandler)
	for extra_event in existing_events:
		var extra_str: String = str(extra_event)
		if extra_str not in events:
			_proc_combo.add_item("● " + extra_str + array_suffix)
			var item_idx2: int = _proc_combo.item_count - 1
			_proc_combo.set_item_metadata(item_idx2, {
				"obj_name": obj_name,
				"event_name": extra_str,
				"full_name": obj_name + "_" + extra_str,
				"implemented": true
			})

	# Try to select the event matching current caret position
	_update_proc_selection_for_object(obj_name)

func _rebuild_object_combo() -> void:
	if not _object_combo:
		return
	_object_combo.clear()
	_object_combo.add_item("(General)")

	# Always add Form as an option (it's the form itself)
	_object_combo.add_item("Form")

	# Add form controls
	for ctrl_name in _control_names:
		_object_combo.add_item(ctrl_name)

## Sets the list of form control names for the Object dropdown.
func set_control_names(names: Array) -> void:
	var typed_names: Array[String] = []
	for n in names:
		typed_names.append(str(n))
	_control_names = typed_names
	_rebuild_object_combo()
	# Forward to VGCodeEdit so auto-complete can suggest control names
	if _code_edit and _code_edit.has_method("set_known_controls"):
		_code_edit.set_known_controls(typed_names)

## Sets the form name so Form1. works like Me. in IntelliSense.
func set_form_name(form_name: String) -> void:
	if _code_edit and _code_edit.has_method("set_form_name"):
		_code_edit.set_form_name(form_name)

## Full control info list from the form designer (for Index Map panel)
var _control_info_list: Array[Dictionary] = []

## Called from the plugin to store the complete control metadata.
func set_control_info_list(info_list: Array[Dictionary]) -> void:
	_control_info_list = info_list
	# Forward to VGCodeEdit so dot-completion knows each control's type
	if _code_edit and _code_edit.has_method("set_control_info"):
		_code_edit.set_control_info(info_list)
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
		var proc_name: String = _procedures[best_idx]["name"]

		# Also update object combo to match
		if "_" in proc_name:
			var obj_name := proc_name.get_slice("_", 0)
			var obj_found := false
			for i in _object_combo.item_count:
				if _object_combo.get_item_text(i) == obj_name:
					if _object_combo.selected != i:
						_object_combo.select(i)
						# Rebuild event list for this object
						_rebuild_event_list_for_object(obj_name)
					obj_found = true
					break
			if not obj_found:
				# Not a control event — stay on (General)
				if _object_combo.selected != 0:
					_object_combo.select(0)
					_rebuild_general_proc_list()

		# If we're in event-aware mode, find matching event
		var selected_obj := _object_combo.get_item_text(_object_combo.selected)
		if selected_obj != "(General)":
			_update_proc_selection_for_object(selected_obj)
		else:
			# General mode — +1 because item 0 is "(Declarations)".
			# Guard against an empty/stale combo (race when loading a
			# formless module before the proc list is rebuilt).
			var target_idx := best_idx + 1
			if _proc_combo.item_count > target_idx:
				_proc_combo.select(target_idx)
			elif _proc_combo.item_count > 0:
				_proc_combo.select(0)

		# Update Index Map for the current object
		_update_index_map_for_current_object()
	else:
		# Guard select(0) against an empty OptionButton popup — in formless
		# code-mode projects the object combo can be unpopulated when this
		# fires during the initial load_file() pass, and OptionButton.select()
		# triggers a noisy "Index out of bounds" error on an empty popup.
		if _object_combo.item_count > 0 and _object_combo.selected != 0:
			_object_combo.select(0)
			_rebuild_general_proc_list()
		elif _proc_combo.item_count > 0:
			_proc_combo.select(0)
		_update_index_map_for_current_object()

## Rebuilds the proc combo for (General) — shows all procedures.
func _rebuild_general_proc_list() -> void:
	_proc_combo.clear()
	_proc_combo.add_item("(Declarations)", 0)
	for idx in _procedures.size():
		var p = _procedures[idx]
		_proc_combo.add_item(p["name"], idx + 1)

## Selects the matching event in the proc dropdown when in event-aware mode.
func _update_proc_selection_for_object(obj_name: String) -> void:
	if not _code_edit or _proc_combo.item_count == 0:
		return
	var caret_line := _code_edit.get_caret_line()

	# Find the procedure we're currently inside
	var current_proc := ""
	for i in _procedures.size():
		if _procedures[i]["line"] <= caret_line:
			current_proc = _procedures[i]["name"]

	if current_proc.is_empty():
		# Not inside any proc — select first item
		if _proc_combo.item_count > 0:
			_proc_combo.select(0)
		return

	# If current proc belongs to this object, find its event
	if current_proc.begins_with(obj_name + "_"):
		var event_part := current_proc.substr(obj_name.length() + 1)
		for i in _proc_combo.item_count:
			var meta = _proc_combo.get_item_metadata(i)
			if meta is Dictionary and meta.get("event_name", "") == event_part:
				_proc_combo.select(i)
				return

	# Current proc doesn't belong to this object — select first implemented event
	for i in _proc_combo.item_count:
		var meta = _proc_combo.get_item_metadata(i)
		if meta is Dictionary and meta.get("implemented", false):
			_proc_combo.select(i)
			return

	# No implemented events — just select first
	if _proc_combo.item_count > 0:
		_proc_combo.select(0)

func _on_proc_selected(index: int) -> void:
	# Check if this is an event-aware item (has metadata)
	var meta = _proc_combo.get_item_metadata(index) if index >= 0 and index < _proc_combo.item_count else null
	if meta is Dictionary:
		# Event-aware mode
		var full_name: String = meta.get("full_name", "")
		var event_name: String = meta.get("event_name", "")
		var is_implemented: bool = meta.get("implemented", false)

		if is_implemented:
			# Jump to existing handler
			for p in _procedures:
				if p["name"] == full_name:
					_code_edit.set_caret_line(p["line"] + 1)
					_code_edit.set_caret_column(4)
					_code_edit.center_viewport_to_caret()
					_code_edit.grab_focus()
					return
		else:
			# Create a stub for this event and navigate to it
			var params := _get_event_params(event_name)
			# VB6 control-array convention: if this control has Index ≥ 0, every
			# event handler receives `Index As Integer` first.
			var obj_part: String = full_name.get_slice("_", 0)
			var ci := _find_control_info(obj_part)
			if int(ci.get("control_array_index", -1)) >= 0:
				params = "Index As Integer" + ("" if params.is_empty() else ", " + params)
			ensure_event_handler(full_name, params)
			# Rebuild to update the implemented status
			_rebuild_proc_list()
		return

	# Legacy mode (General view)
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

## Returns the VB6-style parameter string for a given event name.
## Used when generating Sub stubs for unimplemented events.
static func _get_event_params(event_name: String) -> String:
	match event_name:
		"KeyPress":
			return "KeyAscii As Integer"
		"KeyDown", "KeyUp":
			return "KeyCode As Integer, Shift As Integer"
		"MouseDown", "MouseUp":
			return "Button As Integer, Shift As Integer, X As Single, Y As Single"
		"MouseMove":
			return "Button As Integer, Shift As Integer, X As Single, Y As Single"
		"Validate":
			return "Cancel As Boolean"
		"Unload", "QueryUnload":
			return "Cancel As Integer"
		"Scroll", "Change":
			return ""
		"Timer":
			return ""
		"Resize":
			return ""
		"Paint":
			return ""
		"Expand", "Collapse":
			return ""
		"NodeClick":
			return ""
		"SelChange":
			return ""
		# ── 3D events ──
		"Process", "PhysicsProcess":
			return "Delta As Single"
		"Ready", "EnterTree", "ExitTree":
			return ""
		"Input", "UnhandledInput":
			return "Event As InputEvent"
		"BodyEntered":
			return "Body As Node"
		"BodyExited":
			return "Body As Node"
		"AreaEntered":
			return "Area As Area3D"
		"AreaExited":
			return "Area As Area3D"
		"SleepingStateChanged":
			return ""
		"BodyShapeEntered":
			return "BodyRID As RID, Body As Node, BodyShapeIndex As Integer, LocalShapeIndex As Integer"
		"BodyShapeExited":
			return "BodyRID As RID, Body As Node, BodyShapeIndex As Integer, LocalShapeIndex As Integer"
		"AreaShapeEntered":
			return "AreaRID As RID, Area As Area3D, AreaShapeIndex As Integer, LocalShapeIndex As Integer"
		"AreaShapeExited":
			return "AreaRID As RID, Area As Area3D, AreaShapeIndex As Integer, LocalShapeIndex As Integer"
		"VisibilityChanged":
			return ""
		"Renamed":
			return ""
		"ChildEnteredTree":
			return "Node As Node"
		"ChildExitingTree":
			return "Node As Node"
		"AnimationFinished":
			return ""
		"FrameChanged":
			return ""
		"Finished":
			return ""
		"NavigationFinished":
			return ""
		"WaypointReached":
			return "Details As Dictionary"
		"TargetReached":
			return ""
		"PathChanged":
			return ""
		"VelocityComputed":
			return "SafeVelocity As Vector3"
		_:
			return ""

func _on_object_selected(index: int) -> void:
	var obj_name := _object_combo.get_item_text(index)
	if obj_name == "(General)":
		# Switch to general mode — show all procedures
		_rebuild_general_proc_list()
		_code_edit.set_caret_line(0)
		_code_edit.set_caret_column(0)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()
		_update_index_map_for_current_object()
		return

	# Switch to event-aware mode for this object
	_rebuild_event_list_for_object(obj_name)

	# Jump to the first implemented event for this object, if any
	for i in _proc_combo.item_count:
		var meta = _proc_combo.get_item_metadata(i)
		if meta is Dictionary and meta.get("implemented", false):
			_proc_combo.select(i)
			# Navigate to that handler
			var full_name: String = meta.get("full_name", "")
			for p in _procedures:
				if p["name"] == full_name:
					_code_edit.set_caret_line(p["line"] + 1)
					_code_edit.set_caret_column(4)
					_code_edit.center_viewport_to_caret()
					_code_edit.grab_focus()
					break
			_update_index_map_for_current_object()
			return

	# No implemented events — just select the first event
	if _proc_combo.item_count > 0:
		_proc_combo.select(0)

	# Update Index Map for the selected object
	_update_index_map_for_current_object()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_code_changed() -> void:
	if not _applying_peer_buffer:
		_dirty = true
		if not _vg_path.is_empty():
			buffer_edited.emit(_vg_path)
	if is_instance_valid(_context_rail) and _context_rail.has_method("notify_source_changed"):
		_context_rail.notify_source_changed()
	# Rebuild procedure list (debounced via call_deferred to avoid per-keystroke cost)
	_rebuild_proc_list.call_deferred()
	_update_context_rail.call_deferred()

func _on_caret_moved() -> void:
	_update_proc_selection()
	_check_param_info()
	_update_context_rail()

func _update_context_rail() -> void:
	if not is_instance_valid(_context_rail) or not _code_edit:
		return
	if _context_rail.has_method("update_from_caret"):
		_context_rail.update_from_caret()


func _on_context_rail_goto_line(line: int) -> void:
	if not _code_edit:
		return
	var zero := maxi(0, line - 1)
	_code_edit.set_caret_line(zero)
	_code_edit.set_caret_column(0)
	if _code_edit.has_method("center_viewport_to_caret"):
		_code_edit.center_viewport_to_caret()
	_update_context_rail()


func _on_context_rail_summary_insert(proc_line: int, text: String) -> void:
	if not _code_edit or proc_line < 0:
		return
	_code_edit.insert_line_at(proc_line, text)
	_code_edit.set_caret_line(proc_line)
	_code_edit.set_caret_column(text.length())
	if is_instance_valid(_context_rail) and _context_rail.has_method("notify_source_changed"):
		_context_rail.notify_source_changed()
	_update_context_rail()


func _on_edit_sprite_data_requested() -> void:
	_update_context_rail()
	if is_instance_valid(_context_rail):
		_context_rail.grab_focus()


func _on_file_path_action(action: int, ref: Dictionary) -> void:
	if ref.is_empty():
		return
	var path: String = str(ref.get("res_path", ""))
	match action:
		OpenPathResolver.FileMenuAction.SELECT_FILE:
			_pick_replacement_file(ref)
		OpenPathResolver.FileMenuAction.PREVIEW:
			_preview_file_in_rail(ref, str(ref.get("kind", "text")))
		OpenPathResolver.FileMenuAction.PLAY_AUDIO:
			_preview_file_in_rail(ref, "audio")
		OpenPathResolver.FileMenuAction.OPEN_HEX:
			file_path_open_hex_requested.emit(path)
		OpenPathResolver.FileMenuAction.OPEN_SPRITE:
			file_path_open_sprite_requested.emit(path)
		OpenPathResolver.FileMenuAction.REVEAL_BROWSER:
			file_path_reveal_browser_requested.emit(path)
		OpenPathResolver.FileMenuAction.SHOW_IN_FOLDER:
			if FileAccess.file_exists(path):
				OS.shell_open(OpenPathResolver.globalize(path).get_base_dir())
		OpenPathResolver.FileMenuAction.COPY_PATH:
			DisplayServer.clipboard_set(path)
		OpenPathResolver.FileMenuAction.OPEN_EXTERNAL:
			if FileAccess.file_exists(path):
				file_path_open_external_requested.emit(path)
		OpenPathResolver.FileMenuAction.FIND_USAGES:
			var needle := '"' + str(ref.get("path", "")) + '"'
			_show_find_references(needle)
		OpenPathResolver.FileMenuAction.CREATE_IF_MISSING:
			_create_missing_file(path)
	_update_context_rail()


func _preview_file_in_rail(ref: Dictionary, kind: String) -> void:
	if not is_instance_valid(_context_rail):
		return
	if _context_rail.has_method("show_file_preview"):
		var mode := "info"
		if kind == "audio":
			mode = "audio"
		elif kind == "image":
			mode = "image"
		elif kind == "text":
			mode = "text"
		_context_rail.show_file_preview(ref, mode)
		if kind == "audio" and _context_rail.has_method("preview_file_kind"):
			_context_rail.preview_file_kind("audio")


func _pick_replacement_file(ref: Dictionary) -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.title = "Select file for Open path"
	var cur := str(ref.get("res_path", "res://"))
	if cur.begins_with("user://"):
		fd.access = FileDialog.ACCESS_USERDATA
	elif cur.begins_with("res://"):
		fd.access = FileDialog.ACCESS_RESOURCES
	var kind := str(ref.get("kind", ""))
	match kind:
		"audio":
			fd.filters = PackedStringArray(["*.wav, *.ogg, *.mp3 ; Audio"])
		"image":
			fd.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp ; Images"])
		_:
			fd.filters = PackedStringArray(["*.* ; All Files"])
	if FileAccess.file_exists(cur):
		fd.current_path = OpenPathResolver.globalize(cur)
	elif cur.begins_with("res://"):
		fd.current_dir = ProjectSettings.globalize_path("res://")
	fd.file_selected.connect(func(selected: String) -> void:
		_apply_selected_file_to_ref(ref, selected)
		fd.queue_free()
	)
	fd.canceled.connect(fd.queue_free)
	EditorInterface.get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.55)


func _apply_selected_file_to_ref(ref: Dictionary, selected_abs: String) -> void:
	if not _code_edit:
		return
	var new_path := _abs_to_project_path(selected_abs)
	var line: int = int(ref.get("line", 0))
	var start: int = int(ref.get("literal_start", 0))
	var end: int = int(ref.get("literal_end", 0))
	var quote: String = str(ref.get("quote", "\""))
	var line_text := _code_edit.get_line(line)
	var new_lit := quote + new_path + quote
	_code_edit.set_line(line, line_text.substr(0, start) + new_lit + line_text.substr(end + 1))
	_on_code_changed()


func _abs_to_project_path(abs_path: String) -> String:
	var res_base := ProjectSettings.globalize_path("res://")
	var user_base := ProjectSettings.globalize_path("user://")
	if abs_path.begins_with(res_base):
		return "res://" + abs_path.substr(res_base.length())
	if abs_path.begins_with(user_base):
		return "user://" + abs_path.substr(user_base.length())
	return abs_path


func _create_missing_file(res_path: String) -> void:
	if res_path.is_empty() or FileAccess.file_exists(res_path):
		return
	var dir_path := res_path.get_base_dir()
	if res_path.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	elif res_path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var f := FileAccess.open(res_path, FileAccess.WRITE)
	if f:
		f.store_string("")
		f.close()
		EditorInterface.get_resource_filesystem().update_file(res_path)

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
	var is_builtin := not entry.is_empty()
	if entry.is_empty():
		# ── Fallback 1: scan current script for user-declared symbols ──
		var user_entry := _lookup_user_symbol(keyword)
		if not user_entry.is_empty():
			entry = user_entry
		else:
			# ── Fallback 2: control/widget name (#2) ──
			var ctrl := _find_control_info(keyword)
			if not ctrl.is_empty():
				entry = _build_control_help_entry(ctrl)
			else:
				# ── Fallback 3: Godot ClassDB API ──
				var godot_entry := _lookup_godot_api(keyword)
				if not godot_entry.is_empty():
					entry = godot_entry
					is_builtin = true
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
	var syntax_text: String = entry.get("syntax", "")
	if not syntax_text.is_empty():
		_help_label.append_text("[b][color=#00006B]Syntax[/color][/b]\n")
		_help_label.append_text("[color=#333333][code]" + syntax_text + "[/code][/color]\n\n")

	# ── Description ──
	_help_label.append_text("[b][color=#00006B]Description[/color][/b]\n")
	_help_label.append_text("[color=#222222]" + VGCommandHelp.linkify_cross_references(str(entry.get("desc", ""))) + "[/color]\n\n")

	# ── User-defined symbol badge + Go to Definition link ──
	var symbol_kind: String = entry.get("symbol_kind", "")
	if not symbol_kind.is_empty():
		var kind_labels := {
			"sub": "Subroutine",
			"function": "Function",
			"variable": "Variable",
			"const": "Constant",
			"type": "Type",
		}
		var kind_label: String = kind_labels.get(symbol_kind, symbol_kind.capitalize())
		_help_label.append_text("[color=#555555]🏷️ User-Defined " + kind_label + "[/color]\n")
		var def_line: int = entry.get("defined_on_line", 0)
		if def_line > 0:
			_help_label.append_text("[color=#555555]📍 [/color][url=goto:" + str(def_line) + "][color=#0000CC][b]Go to Definition (line " + str(def_line) + ")[/b][/color][/url]\n")
		_help_label.append_text("\n")

	# ── Developer Note — inline comment (#1) ──
	var comment: String = entry.get("comment", "")
	if not comment.is_empty():
		_help_label.append_text("[b][color=#00006B]Developer Note[/color][/b]\n")
		_help_label.append_text("[color=#336633]💬 " + comment + "[/color]\n\n")

	# ── Scope indicator (#7) ──
	var scope_info: String = entry.get("scope_info", "")
	if not scope_info.is_empty():
		_help_label.append_text("[color=#555555]📌 Scope: [b]" + scope_info + "[/b][/color]\n\n")

	# ── Type Members (#3) ──
	var type_members: Array = entry.get("type_members", [])
	if not type_members.is_empty():
		_help_label.append_text("[b][color=#00006B]Members[/color][/b]\n")
		for member in type_members:
			_help_label.append_text("[color=#333333]  • [code]" + str(member) + "[/code][/color]\n")
		_help_label.append_text("\n")

	# ── Code Example ──
	var code_text: String = entry.get("code", "")
	if not code_text.is_empty():
		_help_label.append_text("[b][color=#00006B]Example[/color][/b]\n")
		_help_label.append_text("[color=#333333][code]" + code_text + "[/code][/color]\n\n")

	# ── Used on lines (#4) — clickable links ──
	var used_on: Array = entry.get("used_on_lines", [])
	if not used_on.is_empty():
		_help_label.append_text("[color=#555555]🔍 Used on lines: ")
		for ui in used_on.size():
			if ui > 0:
				_help_label.append_text(", ")
			var ln: int = used_on[ui]
			_help_label.append_text("[url=goto:" + str(ln) + "][color=#0000CC]" + str(ln) + "[/color][/url]")
		_help_label.append_text("[/color]\n\n")

	# ── Modified on lines (#8) — clickable links ──
	var modified_on: Array = entry.get("modified_on_lines", [])
	if not modified_on.is_empty():
		_help_label.append_text("[color=#555555]✏️ Modified on lines: ")
		for mi in modified_on.size():
			if mi > 0:
				_help_label.append_text(", ")
			var ln: int = modified_on[mi]
			_help_label.append_text("[url=goto:" + str(ln) + "][color=#CC6600]" + str(ln) + "[/color][/url]")
		_help_label.append_text("[/color]\n\n")

	# ── Called from (#5) — clickable links ──
	var called_from: Array = entry.get("called_from_lines", [])
	if not called_from.is_empty():
		_help_label.append_text("[color=#555555]📞 Called from lines: ")
		for ci in called_from.size():
			if ci > 0:
				_help_label.append_text(", ")
			var ln: int = called_from[ci]
			_help_label.append_text("[url=goto:" + str(ln) + "][color=#0000CC]" + str(ln) + "[/color][/url]")
		_help_label.append_text("[/color]\n\n")

	# ── See Also (#6) ──
	if is_builtin:
		var see_also: Array = VGCommandHelp.get_see_also(keyword)
		if not see_also.is_empty():
			_help_label.append_text("[b][color=#00006B]See Also[/color][/b]\n")
			_help_label.append_text("[color=#333333]👉 " + ", ".join(see_also) + "[/color]\n\n")

	# ── Reference link ──
	var ref_line: int = entry.get("ref_line", 0)
	if ref_line > 0:
		_help_label.append_text("[url=ref:" + str(ref_line) + "][color=#0000CC][i]📖 Programmer's Reference, line " + str(ref_line) + "[/i][/color][/url]\n")

	# ── Godot documentation link ──
	var godot_class: String = entry.get("godot_class", "")
	if not godot_class.is_empty():
		var godot_method: String = entry.get("godot_method", "")
		var url := "https://docs.godotengine.org/en/stable/classes/class_" + godot_class.to_lower() + ".html"
		if not godot_method.is_empty():
			url += "#class-" + godot_class.to_lower() + "-method-" + godot_method.to_lower()
		_help_label.append_text("[url=web:" + url + "][color=#0000CC][i]🌐 Godot Docs: " + godot_class
			+ (("." + godot_method + "()") if not godot_method.is_empty() else "")
			+ "[/i][/color][/url]\n")


## Builds a help entry for a form control/widget (#2).
func _build_control_help_entry(ctrl: Dictionary) -> Dictionary:
	var ctrl_name: String = ctrl.get("name", "")
	var ctrl_type: String = ctrl.get("type", "Unknown")
	var x: float = ctrl.get("x", 0)
	var y: float = ctrl.get("y", 0)
	var w: float = ctrl.get("width", 0)
	var h: float = ctrl.get("height", 0)
	var text_val: String = ctrl.get("text", "")
	var vis: bool = ctrl.get("visible", true)

	var desc := "Form control of type [b]" + ctrl_type + "[/b].\n"
	desc += "Position: (" + str(int(x)) + ", " + str(int(y)) + ")  Size: " + str(int(w)) + " × " + str(int(h)) + "\n"
	if not text_val.is_empty():
		desc += "Text: \"" + text_val + "\"\n"
	desc += "Visible: " + ("Yes" if vis else "No")

	# Show custom properties
	var props: Dictionary = ctrl.get("properties", {})
	var prop_lines := ""
	for key in props.keys():
		prop_lines += "\n  • " + str(key) + " = " + str(props[key])

	if not prop_lines.is_empty():
		desc += "\n\nProperties:" + prop_lines

	return {
		"keyword": ctrl_name + "  (" + ctrl_type + ")",
		"syntax": ctrl_type + " " + ctrl_name,
		"desc": desc,
		"code": "",
		"ref_line": 0,
		"symbol_kind": "control",
	}

## Looks up a Godot API method, property, signal, or class via ClassDB.
## Returns a help entry dict with godot_class / godot_method fields, or empty.
func _lookup_godot_api(keyword: String) -> Dictionary:
	# Check if keyword is a Godot class name
	if ClassDB.class_exists(keyword):
		var parent: String = ClassDB.get_parent_class(keyword)
		var desc := "Godot engine class."
		if not parent.is_empty():
			desc += " Inherits from [b]" + parent + "[/b]."
		return {
			"keyword": keyword,
			"syntax": keyword,
			"desc": desc,
			"code": "Dim obj As " + keyword + " = New " + keyword,
			"ref_line": 0,
			"godot_class": keyword,
			"godot_method": "",
		}

	# Search common game-dev classes for the keyword as a method or property
	var search_classes: Array[String] = [
		"Node", "Node2D", "Node3D", "Control",
		"CharacterBody2D", "CharacterBody3D",
		"RigidBody2D", "RigidBody3D",
		"Area2D", "Area3D",
		"Sprite2D", "Sprite3D", "AnimatedSprite2D",
		"Camera2D", "Camera3D",
		"Timer", "AnimationPlayer", "Tween",
		"AudioStreamPlayer", "AudioStreamPlayer2D",
		"CollisionShape2D", "CollisionShape3D",
		"TileMapLayer",
		"CanvasItem", "Viewport",
		"Input", "OS", "Engine", "ProjectSettings",
	]
	for cls in search_classes:
		if not ClassDB.class_exists(cls):
			continue
		# Check methods
		var methods := ClassDB.class_get_method_list(cls, false)
		for method in methods:
			var mname: String = method["name"]
			if mname == keyword or mname == keyword.to_snake_case():
				var args := VGIntelliSense._format_method_args(method)
				var ret: Dictionary = method.get("return", {})
				var ret_type := VGIntelliSense._type_id_to_name(ret.get("type", 0), ret.get("class_name", ""))
				var syntax := mname + "(" + args + ")"
				if ret_type != "void":
					syntax += " → " + ret_type
				return {
					"keyword": mname + "  (" + cls + ")",
					"syntax": syntax,
					"desc": "Method of Godot's [b]" + cls + "[/b] class.",
					"code": "",
					"ref_line": 0,
					"godot_class": cls,
					"godot_method": mname,
				}
		# Check properties
		var props := ClassDB.class_get_property_list(cls, false)
		for prop in props:
			var pname: String = prop.get("name", "")
			if pname == keyword or pname == keyword.to_snake_case():
				var ptype := VGIntelliSense._type_id_to_name(prop.get("type", 0), prop.get("class_name", ""))
				return {
					"keyword": pname + "  (" + cls + ")",
					"syntax": pname + " As " + ptype,
					"desc": "Property of Godot's [b]" + cls + "[/b] class. Type: " + ptype + ".",
					"code": "",
					"ref_line": 0,
					"godot_class": cls,
					"godot_method": "",
				}
		# Check signals
		var signals := ClassDB.class_get_signal_list(cls, false)
		for sig in signals:
			var sname: String = sig["name"]
			if sname == keyword or sname == keyword.to_snake_case():
				return {
					"keyword": sname + "  (" + cls + " signal)",
					"syntax": "Signal " + sname,
					"desc": "Signal emitted by Godot's [b]" + cls + "[/b] class.",
					"code": "",
					"ref_line": 0,
					"godot_class": cls,
					"godot_method": "",
				}
	return {}

## Scans the current script for user-declared variables, constants, and
## Sub/Function definitions matching the given keyword.
## Returns a Dictionary in the same format as VGCommandHelp entries, or empty.
## Enhanced fields: comment, scope_info, used_on_lines, modified_on_lines,
## called_from_lines, type_members, symbol_kind.
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
					var cmt := init_val.find("'")
					if cmt >= 0:
						init_val = init_val.substr(0, cmt).strip_edges()
				# ── NEW: Extract trailing comment (#1) ──
				var comment := _extract_trailing_comment(sline)
				# ── NEW: Scope indicator (#7) ──
				var scope_info := _find_scope_for_line(lines, i)
				# ── NEW: Usage scanning (#4) ──
				var used_on := _scan_usages(lines, vname, i)
				# ── NEW: Assignment tracking (#8) ──
				var modified_on := _scan_assignments(lines, vname, i)

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
					"symbol_kind": "variable",
					"defined_on_line": i + 1,
					"comment": comment,
					"scope_info": scope_info,
					"used_on_lines": used_on,
					"modified_on_lines": modified_on,
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
				var cmt := after.find("'")
				if cmt >= 0:
					after = after.substr(0, cmt).strip_edges()
				var comment := _extract_trailing_comment(sline)
				var scope_info := _find_scope_for_line(lines, i)
				var used_on := _scan_usages(lines, cname, i)
				return {
					"keyword": cname + "  (Const)",
					"syntax": const_scope + " " + cname + " " + after,
					"desc": "Constant declared on line " + str(i + 1) + ".\nValue cannot be changed at runtime.",
					"code": "",
					"ref_line": 0,
					"symbol_kind": "const",
					"defined_on_line": i + 1,
					"comment": comment,
					"scope_info": scope_info,
					"used_on_lines": used_on,
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
			var ret_type := ""
			if kind.to_lower() == "function":
				var tl := trailer.to_lower()
				var as_pos := tl.find("as ")
				if as_pos >= 0:
					ret_type = trailer.substr(as_pos + 3).strip_edges()
					var cmt := ret_type.find("'")
					if cmt >= 0:
						ret_type = ret_type.substr(0, cmt).strip_edges()
			var comment := _extract_trailing_comment(lines[i])
			var called_from := _scan_callers(lines, keyword, i)
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
				"symbol_kind": kind.to_lower(),
				"defined_on_line": i + 1,
				"comment": comment,
				"called_from_lines": called_from,
			}

	# ── Pass 4: Type definitions ──
	var type_rx := RegEx.new()
	type_rx.compile("(?i)^\\s*(?:Public\\s+|Private\\s+)?Type\\s+" + keyword.replace("(", "\\(") + "\\s*$")
	for i in lines.size():
		if type_rx.search(lines[i]):
			var comment := _extract_trailing_comment(lines[i])
			var members := _scan_type_members(lines, i)
			var used_on := _scan_usages(lines, keyword, i)
			var scope_kw := "Public"
			var sl := lines[i].strip_edges().to_lower()
			if sl.begins_with("private"):
				scope_kw = "Private"
			return {
				"keyword": keyword + "  (Type)",
				"syntax": scope_kw + " Type " + keyword,
				"desc": "User-defined Type declared on line " + str(i + 1) + ".",
				"code": "",
				"ref_line": 0,
				"symbol_kind": "type",
				"defined_on_line": i + 1,
				"comment": comment,
				"scope_info": "Module-level",
				"used_on_lines": used_on,
				"type_members": members,
			}

	return {}

# =============================================================================
# COMMAND HELP — HELPER FUNCTIONS
# =============================================================================

## Extracts the trailing comment from a line of code.
## e.g. "Dim score As Integer  ' keeps track of points" → "keeps track of points"
func _extract_trailing_comment(line: String) -> String:
	# Skip lines that are purely comments (start with ')
	var stripped := line.strip_edges()
	if stripped.begins_with("'") or stripped.to_lower().begins_with("rem "):
		return ""
	# Find the comment marker — be careful to skip ' inside string literals
	var in_string := false
	for ci in line.length():
		var ch := line[ci]
		if ch == '"':
			in_string = not in_string
		elif ch == "'" and not in_string:
			var comment := line.substr(ci + 1).strip_edges()
			if not comment.is_empty():
				return comment
			return ""
	return ""

## Determines the scope (module-level or local) for a given line.
## Returns e.g. "Module-level", "Local to Sub UpdateScore", "Local to Function CalcTotal".
func _find_scope_for_line(lines: PackedStringArray, line_idx: int) -> String:
	var proc_rx := RegEx.new()
	proc_rx.compile("(?i)^\\s*(?:(?:Public|Private|Static)\\s+)?(?:Sub|Function)\\s+(\\w+)")
	var end_rx := RegEx.new()
	end_rx.compile("(?i)^\\s*End\\s+(?:Sub|Function)")
	# Walk backward to find enclosing Sub/Function
	var inside_proc := ""
	var depth := 0
	for j in range(line_idx - 1, -1, -1):
		var em := end_rx.search(lines[j])
		if em:
			depth += 1  # entering a closed procedure (going backward)
		var pm := proc_rx.search(lines[j])
		if pm:
			if depth > 0:
				depth -= 1  # this End matched a prior proc header
			else:
				inside_proc = pm.get_string(1)
				# Determine Sub or Function
				var kind_rx := RegEx.new()
				kind_rx.compile("(?i)\\b(Sub|Function)\\b")
				var km := kind_rx.search(lines[j])
				if km:
					return "Local to " + km.get_string(1) + " " + inside_proc
				return "Local to " + inside_proc
	return "Module-level"

## Scans all lines for usage of a symbol (case-insensitive, word boundary).
## Excludes the declaration line itself and pure comment lines.
## Returns an Array of 1-based line numbers.
func _scan_usages(lines: PackedStringArray, symbol: String, decl_line: int) -> Array:
	var result: Array = []
	var rx := RegEx.new()
	rx.compile("(?i)\\b" + symbol.replace("(", "\\(").replace(")", "\\)") + "\\b")
	for i in lines.size():
		if i == decl_line:
			continue
		var stripped := lines[i].strip_edges()
		if stripped.begins_with("'") or stripped.to_lower().begins_with("rem "):
			continue
		# Skip the declaration's own Sub/Function header and End Sub/Function
		if rx.search(lines[i]):
			result.append(i + 1)  # 1-based
	return result

## Scans for lines where a variable is assigned (appears on left side of =).
## Excludes the declaration line, comments, and comparison contexts.
## Returns an Array of 1-based line numbers.
func _scan_assignments(lines: PackedStringArray, symbol: String, decl_line: int) -> Array:
	var result: Array = []
	var sym_lower := symbol.to_lower()
	var assign_rx := RegEx.new()
	# Match: symbol =, symbol(...)  =, symbol.member = (but not ==, <=, >=, <>)
	assign_rx.compile("(?i)^[^']*\\b" + symbol.replace("(", "\\(").replace(")", "\\)") + "\\b[^=<>!]*=[^=]")
	for i in lines.size():
		if i == decl_line:
			continue
		var stripped := lines[i].strip_edges()
		if stripped.begins_with("'") or stripped.to_lower().begins_with("rem "):
			continue
		# Also skip If/ElseIf/While/Until/Case lines (comparisons, not assignments)
		var sl := stripped.to_lower()
		if sl.begins_with("if ") or sl.begins_with("elseif ") or sl.begins_with("while ") \
			or sl.begins_with("until ") or sl.begins_with("case ") or sl.begins_with("select ") \
			or sl.begins_with("debug.print") or sl.begins_with("print ") \
			or sl.begins_with("msgbox") or sl.begins_with("call "):
			continue
		# Skip Sub/Function/End lines
		if sl.begins_with("sub ") or sl.begins_with("function ") or sl.begins_with("end ") \
			or sl.begins_with("public sub") or sl.begins_with("private sub") \
			or sl.begins_with("public function") or sl.begins_with("private function"):
			continue
		if assign_rx.search(lines[i]):
			result.append(i + 1)  # 1-based
	return result

## Scans for lines that call a Sub or Function (excluding its own definition).
## Returns an Array of 1-based line numbers.
func _scan_callers(lines: PackedStringArray, proc_name: String, def_line: int) -> Array:
	var result: Array = []
	var call_rx := RegEx.new()
	# Match the proc name followed by ( or space (for Sub calls without parens)
	call_rx.compile("(?i)\\b" + proc_name.replace("(", "\\(").replace(")", "\\)") + "\\b")
	var def_rx := RegEx.new()
	def_rx.compile("(?i)^\\s*(?:(?:Public|Private|Static)\\s+)?(?:Sub|Function)\\s+" + proc_name.replace("(", "\\(") + "\\b")
	var end_rx := RegEx.new()
	end_rx.compile("(?i)^\\s*End\\s+(?:Sub|Function)")
	for i in lines.size():
		if i == def_line:
			continue
		var stripped := lines[i].strip_edges()
		if stripped.begins_with("'") or stripped.to_lower().begins_with("rem "):
			continue
		# Skip the definition header and end lines
		if def_rx.search(lines[i]):
			continue
		if call_rx.search(lines[i]):
			result.append(i + 1)  # 1-based
	return result

## Scans a Type...End Type block starting at the given line for member fields.
## Returns an Array of strings like "name As String", "age As Integer".
func _scan_type_members(lines: PackedStringArray, type_line: int) -> Array:
	var result: Array = []
	var end_rx := RegEx.new()
	end_rx.compile("(?i)^\\s*End\\s+Type")
	for i in range(type_line + 1, lines.size()):
		if end_rx.search(lines[i]):
			break
		var stripped := lines[i].strip_edges()
		if stripped.is_empty() or stripped.begins_with("'"):
			continue
		result.append(stripped)
	return result

# =============================================================================
# PROCEDURE SEPARATOR LINES
# =============================================================================
# NOTE: Procedure separator lines are now drawn by vg_code_edit.gd's
# _features_overlay (via _draw_procedure_separators).  The old approach
# using set_line_background_color was invisible because the text
# background painted over it; the overlay draws ON TOP of the text.

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
	"stringformat": "StringFormat(Format, Arg0, [Arg1, ...])",
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
		# Ctrl+G → Go To Line
		elif event.ctrl_pressed and event.keycode == KEY_G and not event.alt_pressed and not event.shift_pressed:
			_show_goto_line_dialog()
			get_viewport().set_input_as_handled()
		# Ctrl+Shift+F → Find All References (selection or symbol under caret)
		elif event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_F and not event.alt_pressed:
			var fr_symbol := ""
			if _code_edit.has_selection():
				fr_symbol = _code_edit.get_selected_text().strip_edges()
			elif _code_edit.has_method("get_symbol_under_caret"):
				fr_symbol = _code_edit.get_symbol_under_caret()
			_show_find_references(fr_symbol)
			get_viewport().set_input_as_handled()
		# Ctrl+Shift+H → Call Hierarchy (who calls the proc under the caret)
		elif event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_H and not event.alt_pressed:
			var ch_symbol := ""
			if _code_edit.has_selection():
				ch_symbol = _code_edit.get_selected_text().strip_edges()
			elif _code_edit.has_method("get_symbol_under_caret"):
				ch_symbol = _code_edit.get_symbol_under_caret()
			_show_call_hierarchy(ch_symbol)
			get_viewport().set_input_as_handled()

# =============================================================================
# GO TO LINE DIALOG (Ctrl+G)
# =============================================================================

var _goto_dialog: AcceptDialog = null
var _goto_line_edit: LineEdit = null

## Shows a small dialog asking for a line number, then jumps to it.
func _show_goto_line_dialog() -> void:
	if not _code_edit:
		return
	# Create dialog if it doesn't exist yet
	if not _goto_dialog:
		_goto_dialog = AcceptDialog.new()
		_goto_dialog.title = "Go To Line"
		_goto_dialog.ok_button_text = "Go"
		_goto_dialog.min_size = Vector2i(280, 0)
		add_child(_goto_dialog)
		var vb := VBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "Line number (1 – " + str(_code_edit.get_line_count()) + "):"
		lbl.add_theme_font_size_override("font_size", 12)
		vb.add_child(lbl)
		_goto_line_edit = LineEdit.new()
		_goto_line_edit.placeholder_text = "e.g. 42"
		_goto_line_edit.add_theme_font_size_override("font_size", 12)
		vb.add_child(_goto_line_edit)
		_goto_dialog.add_child(vb)
		_goto_dialog.confirmed.connect(_on_goto_confirmed)
		_goto_line_edit.text_submitted.connect(func(_t): _goto_dialog.hide(); _on_goto_confirmed())
	# Update max line in label
	var lbl_node = _goto_dialog.get_child(1)  # VBoxContainer
	if lbl_node and lbl_node.get_child_count() > 0:
		var lbl := lbl_node.get_child(0) as Label
		if lbl:
			lbl.text = "Line number (1 – " + str(_code_edit.get_line_count()) + "):"
	# Pre-fill with current line
	_goto_line_edit.text = str(_code_edit.get_caret_line() + 1)
	_goto_dialog.popup_centered()
	_goto_line_edit.select_all()
	_goto_line_edit.grab_focus()

func _on_goto_confirmed() -> void:
	if not _code_edit or not _goto_line_edit:
		return
	var txt := _goto_line_edit.text.strip_edges()
	if txt.is_valid_int():
		var target := txt.to_int() - 1  # 0-based
		target = clampi(target, 0, _code_edit.get_line_count() - 1)
		_code_edit.set_caret_line(target)
		_code_edit.set_caret_column(0)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()

# =============================================================================
# FIND ALL REFERENCES (Ctrl+Shift+F / context menu)
# =============================================================================

## Workspace-wide "Find All References" panel (lazily created on first use).
var _find_refs_panel: Window = null

## Opens the Find All References panel for the given symbol. Searches every
## .vg file under res://. Triggered by Ctrl+Shift+F or the editor context menu.
func _show_find_references(symbol: String) -> void:
	var sym := symbol.strip_edges()
	if sym.is_empty():
		return
	# Flush pending edits so on-disk results reflect the current buffer.
	if _dirty and not _vg_path.is_empty():
		save_file()
	if _find_refs_panel == null or not is_instance_valid(_find_refs_panel):
		_find_refs_panel = FindReferencesPanel.new()
		add_child(_find_refs_panel)
		_find_refs_panel.reference_selected.connect(_on_reference_selected)
	_find_refs_panel.find_references(sym, "res://")

## Opens the Call Hierarchy panel for the given symbol (Ctrl+Shift+H).
## Re-uses the Find All References panel pre-filtered to Call sites.
func _show_call_hierarchy(symbol: String) -> void:
	var sym := symbol.strip_edges()
	if sym.is_empty():
		return
	if _dirty and not _vg_path.is_empty():
		save_file()
	if _find_refs_panel == null or not is_instance_valid(_find_refs_panel):
		_find_refs_panel = FindReferencesPanel.new()
		add_child(_find_refs_panel)
		_find_refs_panel.reference_selected.connect(_on_reference_selected)
	_find_refs_panel.find_callers(sym, "res://")

## Navigates to a reference chosen in the Find All References panel. Loads the
## target .vg file first if it differs from the one currently open. `line` is
## 1-based and `column` is 0-based (as emitted by the panel).
func _on_reference_selected(file_path: String, line: int, column: int) -> void:
	if file_path != _vg_path and FileAccess.file_exists(file_path):
		if _dirty and not _vg_path.is_empty():
			save_file()
		load_file(file_path)
	if not _code_edit:
		return
	var target := clampi(line - 1, 0, maxi(_code_edit.get_line_count() - 1, 0))
	_code_edit.set_caret_line(target)
	_code_edit.set_caret_column(maxi(column, 0))
	_code_edit.center_viewport_to_caret()
	_code_edit.grab_focus()

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


# ─── VGPluginRegistry contract ──────────────────────────────
## Called by VGPluginRegistry.open_asset(). Returns true if the editor
## accepted the file. Existing internal callers should keep using their
## native open methods; this is the registry-friendly alias only.
func open_asset(path: String) -> bool:
	load_file(path)
	preload("res://addons/visual_gasic/vg_asset_bus.gd").get_instance().emit_opened(path, "vg_code_editor")
	preload("res://addons/visual_gasic/vg_context_broker.gd").get_instance().set_current_asset(path, "vg_code_editor")
	return true
