@tool
extends EditorPlugin
## Visual Gasic Editor Plugin
##
## This is the main editor plugin for Visual Gasic, providing a VB6-like development
## experience within the Godot Engine. It integrates seamlessly with the Godot editor
## to offer familiar Visual Basic workflows for game and application development.
##
## [b]Features:[/b]
## - [b]VB6 Project/Form Import:[/b] Import existing .vbp projects and .frm forms
## - [b]Toolbox:[/b] Drag-and-drop control palette (2D/3D widgets)
## - [b]Code Navigator:[/b] Browse Subs, Functions, and variables
## - [b]Property Inspector:[/b] VB6-style property editing
## - [b]Immediate Window:[/b] Interactive debugging console (bottom panel)
## - [b]Rename Refactoring:[/b] Ctrl+R to rename variables (scope-aware)
## - [b]Auto Event Wiring:[/b] Double-click controls to generate event handlers
## - [b]Menu Editor:[/b] Visual menu bar designer
## - [b]Tab Order Editor:[/b] Set control focus order
## - [b]Remote Debugger:[/b] Debug running games with breakpoints
##
## [b]Usage:[/b]
## The plugin activates automatically when enabled. Access features via:
## - Project > Tools menu for VB6 import and editors
## - Left dock for Toolbox and Code Navigator
## - Right dock for Property Inspector
## - Bottom panel for Immediate Window
## - Double-click controls in 2D view to create event handlers
## - Ctrl+R in .vg scripts to rename variables
##
## [b]File Types:[/b]
## - [code].vg[/code] - Visual Gasic script files (VB6-like syntax)
## - [code].frm[/code] - VB6 form files (import only)
## - [code].vbp[/code] - VB6 project files (import only)
##
## @tutorial: See GET_STARTED.md for quick start guide
## @tutorial: See IMPORTING_VB6.md for migration from VB6

# =============================================================================
# PLUGIN STATE VARIABLES
# =============================================================================

## Preloaded VB6-style toolbox icon generator
const _VB6Icons = preload("res://addons/visual_gasic/vb6_toolbox_icons.gd")

## The main toolbox container in the left dock
var toolbox

## Import plugin for handling .frm file imports
var import_plugin

## Immediate Window panel for interactive debugging
var immediate_window

## Debugger plugin for remote debugging support
var debugger_plugin: EditorDebuggerPlugin

## Alignment toolbar for form designer
var alignment_toolbar

## Form preview toolbar for quick testing
var form_preview_toolbar

## Recent projects manager and menu
var _recent_projects_menu: PopupMenu
var _recent_projects_manager

## Context menu for script editor rename refactoring
var _script_context_menu: PopupMenu

## Currently active CodeEdit in the script editor (for .vg files)
var _current_code_edit: CodeEdit

## Timer to periodically check for .vg files in script editor
var _script_editor_check_timer: Timer

## Code Navigator bar (VB6-style Object/Event dropdowns above code editor)
var _code_navigator = null

## The VBoxContainer we injected the navigator into (script editor internal)
var _nav_injected_parent = null

## Tracks if a vg_control drag was in progress (for detecting drag end)
var _vg_drag_active: bool = false

## VB6 Layout Manager — toolbar toggle for VB6/Godot IDE modes
var _layout_manager = null

## VB6 mode toggle button in main toolbar (near 2D/3D/Script)
var _vb6_toggle_button: Button = null

## VB6-style Project Explorer panel (tree of Forms/Modules)
var _project_explorer = null

## VB6-style Properties Inspector (managed by layout manager)
var _properties_inspector = null

## FileSystem browser — shown in place of Properties when Code Editor is active
var _vg_file_browser = null

## Hex Editor window — opened on demand from FileSystem browser or Tools menu
var _hex_editor = null

## VB6-style Color Palette toolbar for quick ForeColor/BackColor picking
var _color_palette = null

## VB6 Main Screen control (registered as editor tab alongside 2D/3D/Script)
var _vb6_main_screen = null

## C++ Form Designer canvas — the custom form editor that bypasses Godot's scene tree
var _form_designer: Control = null

## Live animation preview manager for custom controls in the Form Designer
var _live_preview_mgr: Node = null

## Composite VB6 IDE layout: Toolbox | Canvas | Properties — all in one main screen
var _ide_layout: VBoxContainer = null

## Saved split offsets for IDE panels (persist across restarts)
var _saved_main_split_offset: int = 200       ## Toolbox | rest
var _saved_canvas_right_offset: int = -280    ## Canvas | right panels

## Tracks Godot editor chrome visibility for Form Designer mode.
## Docks are hidden via EditorInterface.set_distraction_free_mode();
## these 3 bars need additional manual hiding in _process().
var _godot_menu_bar: Control = null           ## Godot's top MenuBar (File/Scene/Project/Debug/Editor/Help)
var _godot_status_bar: Control = null         ## Status bar at the very bottom of the editor
var _godot_title_bar_hbox: Control = null     ## Title bar HBox (run buttons, renderer dropdown etc.)
var _godot_bottom_panel: Control = null       ## Bottom panel container (Output/Debugger/Audio/etc.)
var _godot_main_vsplit: SplitContainer = null ## Main vertical SplitContainer (viewport vs bottom panel)
var _godot_main_vsplit_offset: int = 0        ## Saved split offset to restore later
var _godot_docks_hidden: bool = false
var _godot_original_title: String = ""        ## Cached original window title for restore
var _chrome_to_keep_hidden: Array = []        ## Menu/title/status bars that _process() keeps hidden
var _bottom_panel_search_done: bool = false    ## Guard for lazy bottom-panel search in _process()

## VB6-style menu bar above the form designer canvas
var _vb6_menu_bar: MenuBar = null
## VB6-style coordinate/size display label in toolbar
var _coord_label: Label = null
## VB6-style status bar at bottom of the IDE layout
var _status_bar: Label = null

## Cached theme dictionary — loaded once from vg_form_designer_theme.gd with hardcoded fallbacks.
## Access any theme value as _theme["key"].  Edit vg_form_designer_theme.gd to customize.
var _theme: Dictionary = {}

## Tracks whether VG panels are currently in Godot docks
var _vg_panels_docked: bool = false

## Tracks whether VG toolbars are currently in the 2D canvas editor menu
var _vg_toolbars_in_container: bool = false

## VB6-style Data Tips — hover over variables during debugging
var _data_tips = null

## Embedded VB6-style code editor (replaces canvas in-place)
var _embedded_code_editor = null
## Whether the IDE is currently showing the code view (vs form view)
var _showing_code_view: bool = false
## Whether the IDE is currently showing the 3D view (vs form/code view)
var _showing_3d_view: bool = false
## Embedded 3D Scene Editor (replaces canvas in-place)
var _vg_3d_editor = null
## Pending 3D double-click info: stashed when scene needs saving first
var _pending_3d_dblclick: Dictionary = {}  # {node_name, event_suffix, event_params}
## Whether the IDE is currently showing the 2D scene view (vs form/code/3D view)
var _showing_2d_view: bool = false
## Embedded 2D Scene Editor (replaces canvas in-place)
var _vg_2d_editor = null
## Pending 2D double-click info: stashed when scene needs saving first
var _pending_2d_dblclick: Dictionary = {}  # {node_name, event_suffix, event_params}
## Whether the IDE is currently showing the Sprite Editor view
var _showing_sprite_view: bool = false
## Embedded Sprite Editor (Piskel-style pixel art editor)
var _vg_sprite_editor = null

## Whether the IDE is currently showing a plugin view (e.g. AGCK)
var _showing_plugin_view: bool = false
## Plugin Manager — discovers & manages VG IDE plugins from plugins/ directory
var _vg_plugin_manager = null

## Command Palette / Quick Open (Ctrl+P, Ctrl+Shift+P).
## Created lazily on first invocation to keep startup snappy.
var _vg_command_palette = null

## Snippet Browser dialog (v2.4.1)
var _snippet_browser = null

## Theme Picker dialog (v2.4.1)
var _theme_picker = null

## Profiler Panel (v2.6.0) — bottom panel for bytecode profiling
var _profiler_panel = null

## Controls Inspector (v4.3.0) — Visual Form Debugger panel
var _controls_inspector = null

## Exception Assistant — VB6-style error popup
var _exception_assistant = null
var _ai_repair_dialog = null

## Package Browser (v4.3.0) — Package Manager panel
var _package_browser = null

## AI Help Panel (v4.4.0) — local Ollama-powered code assistant
var _ai_help_panel = null

## "↩ Back to VG IDE" button injected into Godot's 3D editor toolbar
var _back_to_vg_3d_btn: Button = null

## Tip of the Day dialog (v3.5)
var _tip_of_day_dialog: Window = null
var _tip_label: Label = null
var _tip_checkbox: CheckBox = null
var _tip_index: int = 0
var _show_tips_on_startup: bool = true
var _tip_shown_this_session: bool = false

# =============================================================================
# PLUGIN LIFECYCLE
# =============================================================================

## Called when the plugin enters the editor tree.
## Initializes all plugin components including:
## - Import plugin for .frm files
## - Debugger plugin for remote debugging
## - Immediate Window (bottom panel)
## - Toolbox with control palette (left dock)
## - Code Navigator and Property Inspector
## - Tool menu items
## - Script editor context menu for rename refactoring
func _enter_tree():
	# Store self for static retrieval
	get_editor_interface().get_base_control().set_meta("visual_gasic_plugin_instance", self)

	# Record this project in the cross-project recent list so the VG
	# launcher can skip Godot's Project Manager and reopen it directly.
	_record_recent_vg_project()

	# If the welcome shell dropped a `launching.flag` while waiting for
	# us to come up, clear it once the IDE UI has finished building so
	# the shell knows we're ready and can drop its loading splash.
	call_deferred("_clear_vg_launching_flag")

	# If the welcome shell dropped a Narcea seed, hand it to the AI panel
	# once everything is constructed (deferred so _ai_panel exists).
	call_deferred("_consume_narcea_seed_if_present")

	# Enable input processing so _input() fires for our keyboard shortcuts
	set_process_input(true)

	# Register VG project settings so they surface in Project Settings UI.
	# vg/default_mode controls which editor opens on project load:
	#   "code"  — open the first .vg module in the code editor (default)
	#   "forms" — open the first form in the Form Designer (legacy / opt-in)
	# Unset is treated as "code".
	_register_project_setting(
		"vg/default_mode",
		"code",
		TYPE_STRING,
		PROPERTY_HINT_ENUM,
		"code,forms"
	)

	# vg/first_run_completed gates the first-run welcome / project-type
	# picker. Set automatically the first time the user makes a choice.
	_register_project_setting(
		"vg/first_run_completed",
		false,
		TYPE_BOOL
	)

	# Import Plugin
	import_plugin = preload("res://addons/visual_gasic/frm_import_plugin.gd").new()
	add_import_plugin(import_plugin)
	
	# Debugger Plugin for remote debugging
	var debugger_script = load("res://addons/visual_gasic/vg_debugger_plugin.gd")
	if debugger_script:
		debugger_plugin = debugger_script.new()
		add_debugger_plugin(debugger_plugin)
	
	# Add autoload for game-side debug handler
	if not ProjectSettings.has_setting("autoload/VGDebugHandler"):
		add_autoload_singleton("VGDebugHandler", "res://addons/visual_gasic/vg_debug_handler.gd")
	
	# Immediate Window - Load dynamically to avoid preload issues
	var immediate_window_script = load("res://addons/visual_gasic/immediate_window.gd")
	if immediate_window_script:
		immediate_window = immediate_window_script.new()
		# Pass the debugger plugin reference
		if immediate_window.has_method("set_debugger_plugin"):
			immediate_window.set_debugger_plugin(debugger_plugin)
		# Don't add to bottom panel — will be embedded in the code editor's
		# tabbed bottom panel via set_immediate_window() once the editor exists.
		add_child(immediate_window)  # Keep in scene tree for _ready()
		immediate_window.visible = false
	else:
		print("Warning: Could not load immediate_window.gd")

	# Create Toolbox container — C++ VisualGasicToolbox will be added inside
	toolbox = VBoxContainer.new()
	toolbox.name = "Toolbox"
	toolbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	setup_toolbox()
	_setup_toolbox_context_menu()
	
	# Create Code Navigator (will be injected above the code editor, VB6-style)
	_code_navigator = loading_code_navigator()
	if _code_navigator:
		_code_navigator.setup(self)
		# Connect debugger plugin for breakpoint navigation
		if debugger_plugin and _code_navigator.has_method("set_debugger_plugin"):
			_code_navigator.set_debugger_plugin(debugger_plugin)
		# Hide until injected into script editor
		_code_navigator.visible = false

	# Create Property Inspector (NOT docked yet — will be docked on VB6 mode toggle)
	_properties_inspector = loading_inspector()
	if _properties_inspector:
		_properties_inspector.setup(self)
		add_child(_properties_inspector)  # Keep in scene tree for _ready()
		_properties_inspector.visible = false
		print("VisualGasic: Properties Inspector created (will dock in VB6 mode)")

	# Create FileSystem Browser (shown instead of Properties in Code Editor view)
	_vg_file_browser = loading_file_browser()
	if _vg_file_browser:
		_vg_file_browser.setup(self)
		add_child(_vg_file_browser)  # Keep in scene tree for _ready()
		_vg_file_browser.visible = false
		print("VisualGasic: FileSystem Browser created")

	# Toolbox NOT docked yet — will be docked on VB6 mode toggle
	add_child(toolbox)  # Keep in scene tree so C++ VisualGasicToolbox builds its UI
	toolbox.visible = false
	print("VisualGasic: Toolbox created (will dock in VB6 mode)")
	
	# Add Alignment Toolbar for form designer
	var alignment_script = load("res://addons/visual_gasic/alignment_toolbar.gd")
	if alignment_script:
		alignment_toolbar = alignment_script.new()
		alignment_toolbar.name = "VG Alignment"
		alignment_toolbar.setup(self)
		add_child(alignment_toolbar)  # NOT in container yet — added on VB6 mode toggle
		alignment_toolbar.visible = false
		print("VisualGasic: Alignment toolbar created (will add to 2D bar in VB6 mode)")
	
	# Add Form Preview Toolbar
	var preview_script = load("res://addons/visual_gasic/form_preview_toolbar.gd")
	if preview_script:
		form_preview_toolbar = preview_script.new()
		form_preview_toolbar.name = "VG Preview"
		form_preview_toolbar.setup(self)
		add_child(form_preview_toolbar)  # NOT in container yet — added on VB6 mode toggle
		form_preview_toolbar.visible = false
		print("VisualGasic: Preview toolbar created (will add to 2D bar in VB6 mode)")
	
	# Add VB6-style Color Palette toolbar
	var color_palette_script = load("res://addons/visual_gasic/color_palette_toolbar.gd")
	if color_palette_script:
		_color_palette = color_palette_script.new()
		_color_palette.name = "VG Color Palette"
		_color_palette.setup(self)
		add_child(_color_palette)  # NOT in container yet — added on VB6 mode toggle
		_color_palette.visible = false
		print("VisualGasic: Color palette created (will add to 2D bar in VB6 mode)")
	
	# Add VB6-style Data Tips (hover variable values during debugging)
	var data_tips_script = load("res://addons/visual_gasic/vg_data_tips.gd")
	if data_tips_script and data_tips_script.can_instantiate():
		_data_tips = data_tips_script.new()
		if is_instance_valid(_data_tips):
			add_child(_data_tips)
			_data_tips.setup(self)
			# Wire Data Tips to debugger signals
			if debugger_plugin:
				debugger_plugin.variables_list_received.connect(_on_data_tips_variables_received)
				debugger_plugin.debug_continued.connect(_on_data_tips_debug_ended)
				debugger_plugin.debug_session_stopped.connect(_on_data_tips_debug_ended)
			print("VisualGasic: Data Tips initialized")
		else:
			push_warning("VisualGasic: Data Tips .new() failed — skipping")
	else:
		push_warning("VisualGasic: Data Tips script failed to load — skipping")
	
	# Create Snippet Browser (v2.4.1)
	var snippet_browser_script = load("res://addons/visual_gasic/vg_snippet_browser.gd")
	if snippet_browser_script:
		_snippet_browser = snippet_browser_script.new()
		add_child(_snippet_browser)
		_snippet_browser.snippet_insert_requested.connect(_on_snippet_insert)
		add_tool_menu_item("VG: Snippet Browser", Callable(self, "_on_open_snippet_browser"))
		print("VisualGasic: Snippet Browser created")
	
	# Create Theme Picker (v2.4.1)
	var theme_picker_script = load("res://addons/visual_gasic/vg_theme_picker.gd")
	if theme_picker_script:
		_theme_picker = theme_picker_script.new()
		add_child(_theme_picker)
		_theme_picker.vg_theme_changed.connect(_on_theme_changed)
		add_tool_menu_item("VG: Theme Picker", Callable(self, "_on_open_theme_picker"))
		print("VisualGasic: Theme Picker created")
	
	# Hex Editor is created in _embed_ide_bottom_panels() once the IDE is ready
	
	# Create Profiler Panel (v2.6.0) — will be embedded in VB6 IDE bottom tabs
	var profiler_script = load("res://addons/visual_gasic/vg_profiler_panel.gd")
	if profiler_script:
		_profiler_panel = profiler_script.new()
		if _profiler_panel.has_method("set_debugger_plugin"):
			_profiler_panel.set_debugger_plugin(debugger_plugin)
		add_child(_profiler_panel)  # Park on plugin until IDE is ready
		_profiler_panel.visible = false
		print("VisualGasic: Profiler Panel created (will embed in IDE)")
	
	# Create Controls Inspector (v4.3.0) — Visual Form Debugger
	var inspector_script = load("res://addons/visual_gasic/vg_controls_inspector.gd")
	if inspector_script:
		_controls_inspector = inspector_script.new()
		_controls_inspector.setup(debugger_plugin)
		if debugger_plugin:
			debugger_plugin.form_controls_received.connect(_on_form_controls_received)
			debugger_plugin.debug_break_hit.connect(_on_debug_break_for_controls_inspector)
			debugger_plugin.debug_break_hit.connect(_on_debug_break_navigate)
			debugger_plugin.debug_break_hit.connect(_on_run_to_cursor_break_hit)
			debugger_plugin.debug_continued.connect(_on_debug_continued_for_controls_inspector)
			debugger_plugin.debug_session_stopped.connect(_on_debug_stopped_for_controls_inspector)
		_controls_inspector.navigate_to_event.connect(_on_controls_navigate_to_event)
		add_child(_controls_inspector)  # Park on plugin until IDE is ready
		_controls_inspector.visible = false
		print("VisualGasic: Controls Inspector created (will embed in IDE)")

	# Create Exception Assistant (VB6-style error popup)
	var exception_script = load("res://addons/visual_gasic/vg_exception_assistant.gd")
	if exception_script:
		_exception_assistant = exception_script.new()
		add_child(_exception_assistant)
		_exception_assistant.debug_requested.connect(_on_exception_debug)
		_exception_assistant.continue_requested.connect(_on_exception_continue)
		_exception_assistant.end_requested.connect(_on_exception_end)
		if _exception_assistant.has_signal("ai_help_requested"):
			_exception_assistant.ai_help_requested.connect(_on_exception_ask_ai)
		if _exception_assistant.has_signal("ai_repair_requested"):
			_exception_assistant.ai_repair_requested.connect(_on_exception_ai_repair)
		if debugger_plugin:
			if debugger_plugin.has_signal("error_break_received"):
				debugger_plugin.error_break_received.connect(_on_error_break_received)
			if debugger_plugin.has_signal("set_next_statement_failed"):
				debugger_plugin.set_next_statement_failed.connect(_on_set_next_statement_failed)
			# Call Stack Navigation — when a frame is inspected, update variables
			if debugger_plugin.has_signal("stack_level_locals_received"):
				debugger_plugin.stack_level_locals_received.connect(_on_stack_level_locals_received)
		print("VisualGasic: Exception Assistant created")

	# Create Package Browser (v4.3.0) — will be embedded in VB6 IDE bottom tabs
	var pkg_browser_script = load("res://addons/visual_gasic/vg_package_browser.gd")
	if pkg_browser_script:
		_package_browser = pkg_browser_script.new()
		_package_browser.setup(EditorInterface.get_editor_paths().get_project_settings_dir().get_base_dir())
		add_child(_package_browser)  # Park on plugin until IDE is ready
		_package_browser.visible = false
		print("VisualGasic: Package Browser created (will embed in IDE)")
	
	# Create AI Help Panel (v4.4.0) — will be embedded in VB6 IDE bottom tabs
	var ai_help_script = load("res://addons/visual_gasic/vg_ai_help.gd")
	if ai_help_script:
		_ai_help_panel = ai_help_script.new()
		add_child(_ai_help_panel)  # Park on plugin until IDE is ready
		_ai_help_panel.visible = false
		print("VisualGasic: AI Help panel created (will embed in IDE)")
	
	# Register custom .vg file icon in the editor theme
	call_deferred("_register_vg_file_icon")
	
	# Inject "↩ Back to VG IDE" button into Godot's 3D editor toolbar
	_back_to_vg_3d_btn = Button.new()
	_back_to_vg_3d_btn.text = "\u21a9 Back to VG IDE"
	_back_to_vg_3d_btn.tooltip_text = "Return to Visual Gasic IDE"
	_back_to_vg_3d_btn.flat = true
	_back_to_vg_3d_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_back_to_vg_3d_btn.add_theme_color_override("font_hover_color", Color(0.4, 0.7, 1.0))
	_back_to_vg_3d_btn.pressed.connect(_on_back_to_vg_from_3d)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _back_to_vg_3d_btn)
	print("VisualGasic: 'Back to VG IDE' button added to 3D editor toolbar")

	# Create VB6 Project Explorer (right-upper dock in VB6 mode)
	var proj_explorer_script = load("res://addons/visual_gasic/vb6_project_explorer.gd")
	if proj_explorer_script:
		_project_explorer = proj_explorer_script.new()
		_project_explorer.setup(self)
		add_child(_project_explorer)  # Keep in scene tree for _ready()
		_project_explorer.visible = false
		print("VisualGasic: Project Explorer created (will dock in VB6 mode)")

	# NOTE: No VB6 main screen tab. The form designer IS the 2D viewport.
	# VB6 mode = 2D viewport + VG dock panels + VG toolbars.
	# Toggled via Project > Tools > Toggle VG IDE Layout.

	# Create VB6 Layout Manager
	var layout_mgr_script = load("res://addons/visual_gasic/vb6_layout_manager.gd")
	if layout_mgr_script:
		_layout_manager = layout_mgr_script.new()
		_layout_manager.setup(self, toolbox, _project_explorer, _properties_inspector, [alignment_toolbar, _color_palette, form_preview_toolbar])
		add_child(_layout_manager)
		add_tool_menu_item("Toggle VG IDE Layout", Callable(self, "_on_toggle_vb6_layout"))
		_layout_manager.layout_changed.connect(_on_vb6_mode_changed)
		print("VisualGasic: Added 'Toggle VG IDE Layout' to Project > Tools menu")
	
	# NOTE: The "Form Designer" button in the main screen bar is created
	# automatically by Godot because _has_main_screen() returns true.
	# No manual button needed — Godot handles pressed-state, visibility,
	# and calls _make_visible() when the user clicks it.

	# =========================================================================
	# BUILD COMPOSITE VB6 IDE LAYOUT
	# Instead of docking panels into Godot docks (which causes cascade issues),
	# embed Toolbox + FormDesigner + Properties into ONE main screen widget.
	# This creates an authentic VB6 IDE experience.
	# =========================================================================
	if ClassDB.class_exists("VisualGasicFormDesigner"):
		# Load theme configuration (safe — falls back to hardcoded defaults)
		_load_theme_config()

		# --- Form Designer Canvas (center) ---
		_form_designer = ClassDB.instantiate("VisualGasicFormDesigner")
		_form_designer.name = "FormDesignerCanvas"
		_form_designer.new_form("Form1")
		# Connect signals
		_form_designer.control_selected.connect(_on_fd_control_selected)
		_form_designer.control_deselected.connect(_on_fd_control_deselected)
		_form_designer.form_modified.connect(_on_fd_form_modified)
		_form_designer.control_double_clicked.connect(_on_fd_control_double_clicked)
		if _form_designer.has_signal("status_changed"):
			_form_designer.status_changed.connect(_on_fd_status_changed)
		if _form_designer.has_signal("form_resized"):
			_form_designer.form_resized.connect(_on_fd_form_resized)
		if _form_designer.has_signal("control_right_clicked"):
			_form_designer.control_right_clicked.connect(_on_fd_control_right_clicked)
		if _form_designer.has_signal("scene_file_dropped"):
			_form_designer.scene_file_dropped.connect(_on_fd_scene_file_dropped)
		if _form_designer.has_signal("game_ui_mode_changed"):
			_form_designer.game_ui_mode_changed.connect(_on_game_ui_mode_changed)
		# Keyboard fallback: catch shortcuts when canvas has focus
		_form_designer.gui_input.connect(_on_canvas_gui_input)

		# --- Live Preview Manager (animated custom controls) ---
		var LivePreviewMgr = load("res://addons/visual_gasic/vg_live_preview_manager.gd")
		if LivePreviewMgr:
			_live_preview_mgr = LivePreviewMgr.new(self, _form_designer)
			add_child(_live_preview_mgr)

		# --- Build the composite layout ---
		# VBoxContainer root: Menu | Toolbar | [Toolbox | Canvas | Properties] | Status
		_ide_layout = VBoxContainer.new()
		_ide_layout.name = "VB6_IDE_Layout"
		_ide_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ide_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Apply VB6 light theme IMMEDIATELY so all children inherit it
		_ide_layout.theme = _build_vb6_theme()

		# ── VB6 Menu Bar row: [MenuBar ←left | spacer | Plugin buttons → right] ──
		_vb6_menu_bar = _create_vb6_menu_bar()
		var menu_row = HBoxContainer.new()
		menu_row.name = "MenuBarRow"
		menu_row.add_child(_vb6_menu_bar)
		var menu_spacer = Control.new()
		menu_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_row.add_child(menu_spacer)
		# Plugin buttons container — right-aligned in the menu bar row
		var plugin_strip = HBoxContainer.new()
		plugin_strip.name = "PluginStrip"
		plugin_strip.add_theme_constant_override("separation", 4)
		menu_row.add_child(plugin_strip)
		_ide_layout.add_child(menu_row)

		# ── Top toolbar row (full width, with VB6 light grey background) ──
		var toolbar_panel = PanelContainer.new()
		toolbar_panel.name = "ToolbarPanel"
		var tb_sb = StyleBoxFlat.new()
		tb_sb.bg_color = _theme.get("panel_background", Color("#F0EDE8"))
		tb_sb.border_color = _theme.get("panel_border", Color(0.72, 0.71, 0.68))
		tb_sb.border_width_bottom = 1
		tb_sb.content_margin_left = 4
		tb_sb.content_margin_right = 4
		tb_sb.content_margin_top = 2
		tb_sb.content_margin_bottom = 2
		toolbar_panel.add_theme_stylebox_override("panel", tb_sb)
		var toolbar_row = HBoxContainer.new()
		toolbar_row.name = "ToolbarRow"
		# Move alignment/preview/color toolbars into the embedded row
		for tb in [alignment_toolbar, form_preview_toolbar, _color_palette]:
			if is_instance_valid(tb):
				if tb.get_parent() == self:
					remove_child(tb)
				tb.visible = true
				toolbar_row.add_child(tb)

		# ── Coordinate/Size display (like VB6's "0, 0  4800 x 3600") ──
		var coord_sep = VSeparator.new()
		toolbar_row.add_child(coord_sep)
		_coord_label = Label.new()
		_coord_label.name = "CoordLabel"
		_coord_label.text = "600 x 400"
		_coord_label.add_theme_font_size_override("font_size", 11)
		_coord_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		_coord_label.custom_minimum_size.x = 80
		toolbar_row.add_child(_coord_label)

		# ── View Code / View Object toggle buttons (like VB6 toolbar) ──
		var view_sep = VSeparator.new()
		toolbar_row.add_child(view_sep)

		var view_code_btn = Button.new()
		view_code_btn.name = "ViewCodeBtn"
		view_code_btn.text = "</> Code"
		view_code_btn.tooltip_text = "View Code (F7)"
		view_code_btn.flat = true
		view_code_btn.add_theme_font_size_override("font_size", 11)
		view_code_btn.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		view_code_btn.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.5))
		view_code_btn.pressed.connect(_on_view_code)
		toolbar_row.add_child(view_code_btn)

		var view_obj_btn = Button.new()
		view_obj_btn.name = "ViewObjectBtn"
		view_obj_btn.text = "\u25a3 Form"
		view_obj_btn.tooltip_text = "View Object (Shift+F7)"
		view_obj_btn.flat = true
		view_obj_btn.add_theme_font_size_override("font_size", 11)
		view_obj_btn.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		view_obj_btn.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.5))
		view_obj_btn.pressed.connect(_on_view_object)
		# Hide when the Form Designer pseudo-plugin is disabled — otherwise
		# the user still sees a "Form" button that takes them back into the
		# designer they just opted out of.
		if ProjectSettings.has_setting("vg/form_designer_enabled") \
				and not bool(ProjectSettings.get_setting("vg/form_designer_enabled", true)):
			view_obj_btn.visible = false
		toolbar_row.add_child(view_obj_btn)

		# ── Show Indexes toggle — displays index badges on control arrays + Game UI controls ──
		var idx_sep = VSeparator.new()
		toolbar_row.add_child(idx_sep)

		var show_idx_btn = CheckButton.new()
		show_idx_btn.name = "ShowIndexesBtn"
		show_idx_btn.text = "Indexes"
		show_idx_btn.tooltip_text = "Show control array indexes and Game UI slot/button indexes on the form"
		show_idx_btn.button_pressed = false
		show_idx_btn.add_theme_font_size_override("font_size", 11)
		show_idx_btn.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		show_idx_btn.toggled.connect(_on_show_indexes_toggled)
		toolbar_row.add_child(show_idx_btn)

		# ── 3D View button — switches to embedded 3D Scene Editor ──
		var view_3d_sep = VSeparator.new()
		toolbar_row.add_child(view_3d_sep)

		var view_3d_btn = Button.new()
		view_3d_btn.name = "View3DBtn"
		view_3d_btn.text = "3D"
		view_3d_btn.tooltip_text = "3D Scene Editor — edit 3D scenes inside the VG IDE"
		view_3d_btn.flat = false
		view_3d_btn.add_theme_font_size_override("font_size", 11)
		view_3d_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		view_3d_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
		var view_3d_style = StyleBoxFlat.new()
		view_3d_style.bg_color = Color(0.2, 0.35, 0.55)
		view_3d_style.set_corner_radius_all(4)
		view_3d_style.content_margin_left = 6
		view_3d_style.content_margin_right = 6
		view_3d_style.content_margin_top = 2
		view_3d_style.content_margin_bottom = 2
		view_3d_btn.add_theme_stylebox_override("normal", view_3d_style)
		var view_3d_hover = view_3d_style.duplicate()
		view_3d_hover.bg_color = Color(0.25, 0.45, 0.7)
		view_3d_btn.add_theme_stylebox_override("hover", view_3d_hover)
		var view_3d_pressed = view_3d_style.duplicate()
		view_3d_pressed.bg_color = Color(0.15, 0.25, 0.45)
		view_3d_btn.add_theme_stylebox_override("pressed", view_3d_pressed)
		view_3d_btn.pressed.connect(_on_3d_view_pressed)
		toolbar_row.add_child(view_3d_btn)

		# ── 2D Scene Editor button — switches to embedded 2D Scene Editor ──
		var view_2d_btn = Button.new()
		view_2d_btn.name = "View2DBtn"
		view_2d_btn.text = "2D"
		view_2d_btn.tooltip_text = "2D Scene Editor — edit 2D game scenes inside the VG IDE"
		view_2d_btn.flat = false
		view_2d_btn.add_theme_font_size_override("font_size", 11)
		view_2d_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		view_2d_btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
		var view_2d_style = StyleBoxFlat.new()
		view_2d_style.bg_color = Color(0.2, 0.45, 0.3)
		view_2d_style.set_corner_radius_all(4)
		view_2d_style.content_margin_left = 6
		view_2d_style.content_margin_right = 6
		view_2d_style.content_margin_top = 2
		view_2d_style.content_margin_bottom = 2
		view_2d_btn.add_theme_stylebox_override("normal", view_2d_style)
		var view_2d_hover = view_2d_style.duplicate()
		view_2d_hover.bg_color = Color(0.25, 0.55, 0.35)
		view_2d_btn.add_theme_stylebox_override("hover", view_2d_hover)
		var view_2d_pressed = view_2d_style.duplicate()
		view_2d_pressed.bg_color = Color(0.15, 0.35, 0.2)
		view_2d_btn.add_theme_stylebox_override("pressed", view_2d_pressed)
		view_2d_btn.pressed.connect(_on_2d_view_pressed)
		toolbar_row.add_child(view_2d_btn)

		# ── Sprite Editor button — switches to embedded Piskel-style pixel art editor ──
		var view_sprite_btn = Button.new()
		view_sprite_btn.name = "ViewSpriteBtn"
		view_sprite_btn.text = "Sprite"
		view_sprite_btn.tooltip_text = "Sprite Editor — Piskel-style pixel art for 8-bit/16-bit game graphics"
		view_sprite_btn.flat = false
		view_sprite_btn.add_theme_font_size_override("font_size", 11)
		view_sprite_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		view_sprite_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.7))
		var view_sprite_style = StyleBoxFlat.new()
		view_sprite_style.bg_color = Color(0.45, 0.25, 0.45)
		view_sprite_style.set_corner_radius_all(4)
		view_sprite_style.content_margin_left = 6
		view_sprite_style.content_margin_right = 6
		view_sprite_style.content_margin_top = 2
		view_sprite_style.content_margin_bottom = 2
		view_sprite_btn.add_theme_stylebox_override("normal", view_sprite_style)
		var view_sprite_hover = view_sprite_style.duplicate()
		view_sprite_hover.bg_color = Color(0.55, 0.30, 0.55)
		view_sprite_btn.add_theme_stylebox_override("hover", view_sprite_hover)
		var view_sprite_pressed = view_sprite_style.duplicate()
		view_sprite_pressed.bg_color = Color(0.35, 0.15, 0.35)
		view_sprite_btn.add_theme_stylebox_override("pressed", view_sprite_pressed)
		view_sprite_btn.pressed.connect(_on_sprite_view_pressed)
		toolbar_row.add_child(view_sprite_btn)

		# ── Freeze Previews toggle — pauses live custom control animation ──
		var freeze_btn = Button.new()
		freeze_btn.name = "FreezePreviewsBtn"
		freeze_btn.text = "▶ Live"
		freeze_btn.tooltip_text = "Toggle live animation for custom control previews (❄ Freeze / ▶ Live)"
		freeze_btn.toggle_mode = true
		freeze_btn.flat = false
		freeze_btn.add_theme_font_size_override("font_size", 11)
		freeze_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		var freeze_style = StyleBoxFlat.new()
		freeze_style.bg_color = Color(0.2, 0.4, 0.6)
		freeze_style.set_corner_radius_all(4)
		freeze_style.content_margin_left = 6
		freeze_style.content_margin_right = 6
		freeze_style.content_margin_top = 2
		freeze_style.content_margin_bottom = 2
		freeze_btn.add_theme_stylebox_override("normal", freeze_style)
		var freeze_pressed = freeze_style.duplicate()
		freeze_pressed.bg_color = Color(0.3, 0.3, 0.5)
		freeze_btn.add_theme_stylebox_override("pressed", freeze_pressed)
		var freeze_hover = freeze_style.duplicate()
		freeze_hover.bg_color = Color(0.3, 0.5, 0.7)
		freeze_btn.add_theme_stylebox_override("hover", freeze_hover)
		freeze_btn.toggled.connect(func(pressed: bool):
			if _live_preview_mgr:
				_live_preview_mgr.set_frozen(pressed)
				freeze_btn.text = "❄ Frozen" if pressed else "▶ Live"
		)
		toolbar_row.add_child(freeze_btn)

		# Wrap toolbar in a horizontal ScrollContainer so it doesn't overflow off-screen
		var toolbar_scroll = ScrollContainer.new()
		toolbar_scroll.name = "ToolbarScroll"
		toolbar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		toolbar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		toolbar_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toolbar_scroll.custom_minimum_size.y = 34
		toolbar_scroll.add_child(toolbar_row)
		toolbar_panel.add_child(toolbar_scroll)
		_ide_layout.add_child(toolbar_panel)

		# ── Main 3-panel workspace: [Toolbox | Canvas | Properties] ──
		var main_hsplit = HSplitContainer.new()
		main_hsplit.name = "MainHSplit"
		main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_hsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
		main_hsplit.add_theme_constant_override("separation", 6)
		main_hsplit.add_theme_constant_override("minimum_grab_thickness", 8)

		# -- LEFT: Toolbox panel --
		var left_panel = PanelContainer.new()
		left_panel.name = "ToolboxPanel"
		left_panel.custom_minimum_size = Vector2(180, 0)
		left_panel.size_flags_horizontal = Control.SIZE_FILL
		left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Re-parent the existing toolbox into the left panel
		if is_instance_valid(toolbox) and toolbox.get_parent() == self:
			remove_child(toolbox)
		if is_instance_valid(toolbox):
			toolbox.visible = true
			left_panel.add_child(toolbox)
		main_hsplit.add_child(left_panel)

		# -- CENTER-RIGHT split: Canvas + Right panels --
		var canvas_right_split = HSplitContainer.new()
		canvas_right_split.name = "CanvasRightSplit"
		canvas_right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		canvas_right_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		canvas_right_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
		canvas_right_split.add_theme_constant_override("separation", 6)
		canvas_right_split.add_theme_constant_override("minimum_grab_thickness", 8)

		# ── Center stack: holds all swappable editors (canvas, code, 2D, 3D, sprite).
		# HSplitContainer only lays out 2 children correctly, so we wrap the
		# editors in a single MarginContainer that expands every child to fill
		# its area. Only one editor is visible at a time; the others sit
		# hidden in the stack.
		var center_stack = MarginContainer.new()
		center_stack.name = "CenterStack"
		center_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		canvas_right_split.add_child(center_stack)

		# ── Scrollable MDI workspace (canvas center) ──
		var canvas_scroll = ScrollContainer.new()
		canvas_scroll.name = "CanvasScroll"
		canvas_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		canvas_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		canvas_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		canvas_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_form_designer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_form_designer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		canvas_scroll.add_child(_form_designer)
		center_stack.add_child(canvas_scroll)

		# ── Embedded Code Editor (hidden by default, replaces canvas on View Code) ──
		var ece_script = load("res://addons/visual_gasic/vg_embedded_code_editor.gd")
		if ece_script:
			_embedded_code_editor = ece_script.new()
			_embedded_code_editor.visible = false
			_embedded_code_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_embedded_code_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_embedded_code_editor.view_object_requested.connect(_show_form_view)
			center_stack.add_child(_embedded_code_editor)
			# Register with VGPluginRegistry so .vg / .gd opens can be routed
			# through registry.open_asset() generically (file-browser dbl-click,
			# command palette, third-party plugins). Low priority so any future
			# fancier code editor can outrank by simply declaring priority>10.
			VGPluginRegistry.get_instance().register_provider(
				"code_editor",
				{
					"name": "VG Code Editor",
					"provides": ["asset_editor.code", "asset_editor.text"],
					"handles_extensions": ["vg", "gd", "txt", "md", "cfg", "ini"],
					"priority": 10,
					"enabled": true,
				},
				_embedded_code_editor
			)
			print("VisualGasic: Embedded Code Editor created")
			# Connect FileSystem browser → open files in code editor
			if is_instance_valid(_vg_file_browser):
				_vg_file_browser.file_open_requested.connect(_on_file_browser_open_requested)
				_vg_file_browser.open_hex_editor_requested.connect(_on_hex_editor_open)
			# Embed the Immediate Window into the code editor's bottom panel.
			# Must be deferred — both nodes need _ready() to run first so their
			# UI children exist (TabContainer, HSplitContainer, etc.).
			if is_instance_valid(immediate_window):
				_embedded_code_editor.set_immediate_window.call_deferred(immediate_window)
				print("VisualGasic: Immediate Window embedding deferred")
			# Wire Output and System Console tabs to live data sources
			_wire_output_tabs.call_deferred()
			# Embed VG panels (Profiler, Controls, Packages, AI Help) into IDE bottom tabs
			_embed_ide_bottom_panels.call_deferred()

		# ── Embedded 3D Scene Editor (hidden by default, replaces canvas on 3D View) ──
		var vg3d_script = load("res://addons/visual_gasic/vg_3d_editor.gd")
		if vg3d_script:
			_vg_3d_editor = vg3d_script.new()
			_vg_3d_editor.visible = false
			_vg_3d_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_vg_3d_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_vg_3d_editor.back_to_form_requested.connect(_show_form_view)
			_vg_3d_editor.node_double_clicked.connect(_on_3d_node_double_clicked)
			_vg_3d_editor.view_code_requested.connect(_on_3d_node_double_clicked)
			_vg_3d_editor.scene_saved.connect(_on_3d_scene_saved)
			# Wire 3D selection → Properties Inspector live update
			_vg_3d_editor.node_selected.connect(_on_3d_node_selected)
			_vg_3d_editor.selection_cleared.connect(_on_3d_selection_cleared)
			center_stack.add_child(_vg_3d_editor)
			VGPluginRegistry.get_instance().register_provider(
				"vg_3d_editor",
				{
					"name": "VG 3D Scene Editor",
					"provides": ["asset_editor.scene.3d"],
					"handles_extensions": ["tscn", "escn"],
					"priority": 8,  # below 2D so 2D wins for plain .tscn (most are 2D)
					"enabled": true,
				},
				_vg_3d_editor
			)
			print("VisualGasic: 3D Scene Editor created")

		# ── Embedded 2D Scene Editor (hidden by default, replaces canvas on 2D View) ──
		var vg2d_script = load("res://addons/visual_gasic/vg_2d_editor.gd")
		if vg2d_script:
			_vg_2d_editor = vg2d_script.new()
			_vg_2d_editor.visible = false
			_vg_2d_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_vg_2d_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_vg_2d_editor.back_to_form_requested.connect(_show_form_view)
			_vg_2d_editor.node_double_clicked.connect(_on_2d_node_double_clicked)
			_vg_2d_editor.view_code_requested.connect(_on_2d_node_double_clicked)
			_vg_2d_editor.scene_saved.connect(_on_2d_scene_saved)
			# Wire 2D selection → Properties Inspector live update
			_vg_2d_editor.node_selected.connect(_on_2d_node_selected)
			_vg_2d_editor.selection_cleared.connect(_on_2d_selection_cleared)
			center_stack.add_child(_vg_2d_editor)
			VGPluginRegistry.get_instance().register_provider(
				"vg_2d_editor",
				{
					"name": "VG 2D Scene Editor",
					"provides": ["asset_editor.scene.2d", "asset_editor.scene"],
					"handles_extensions": ["tscn", "escn"],
					"priority": 10,
					"enabled": true,
				},
				_vg_2d_editor
			)
			print("VisualGasic: 2D Scene Editor created")

		# ── Embedded Sprite Editor (hidden by default, Piskel-style pixel art) ──
		var vgsprite_script = load("res://addons/visual_gasic/vg_sprite_editor.gd")
		if vgsprite_script:
			_vg_sprite_editor = vgsprite_script.new()
			_vg_sprite_editor.visible = false
			_vg_sprite_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_vg_sprite_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_vg_sprite_editor.back_to_form_requested.connect(_show_form_view)
			_vg_sprite_editor.sprite_saved.connect(_on_sprite_saved)
			center_stack.add_child(_vg_sprite_editor)
			# Register this built-in editor with VGPluginRegistry so other
			# code (file browser double-click, command palette, AGCK) can
			# route png/sprite-asset opens through a single API instead of
			# hard-coding a reference to _vg_sprite_editor.
			VGPluginRegistry.get_instance().register_provider(
				"sprite_editor",
				{
					"name": "VG Sprite Editor",
					"provides": ["asset_editor.sprite", "asset_editor.image"],
					"handles_extensions": ["png", "vgsprite"],
					"priority": 10,  # built-in, low priority — third-party plugins can outrank
					"enabled": true,
				},
				_vg_sprite_editor
			)
			print("VisualGasic: Sprite Editor created")

		# ── Plugin Manager — discovers plugins from addons/visual_gasic/plugins/ ──
		var vg_pm_script = load("res://addons/visual_gasic/vg_plugin_manager.gd")
		if vg_pm_script:
			_vg_plugin_manager = vg_pm_script.new()
			_vg_plugin_manager.setup(self, plugin_strip, canvas_right_split)
			_vg_plugin_manager.discover_plugins()
			_vg_plugin_manager.plugin_activated.connect(_on_vg_plugin_activated)
			_vg_plugin_manager.all_plugins_deactivated.connect(_on_vg_plugins_deactivated)
			print("VisualGasic: Plugin Manager initialized")

		# -- RIGHT: Project Explorer + Properties (resizable VSplitContainer) --
		var right_vsplit = VSplitContainer.new()
		right_vsplit.name = "RightPanelSplit"
		right_vsplit.custom_minimum_size = Vector2(120, 0)
		right_vsplit.size_flags_horizontal = Control.SIZE_FILL
		right_vsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_vsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
		right_vsplit.add_theme_constant_override("separation", 4)
		right_vsplit.add_theme_constant_override("minimum_grab_thickness", 8)

		# Project Explorer (top half of right panel)
		if is_instance_valid(_project_explorer):
			if _project_explorer.get_parent() == self:
				remove_child(_project_explorer)
			_project_explorer.visible = true
			_project_explorer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			right_vsplit.add_child(_project_explorer)

		# Bottom slot: stacked Properties Inspector + FileSystem Browser (one visible at a time)
		var right_bottom_stack = VBoxContainer.new()
		right_bottom_stack.name = "RightBottomStack"
		right_bottom_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_bottom_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_vsplit.add_child(right_bottom_stack)

		if is_instance_valid(_properties_inspector):
			if _properties_inspector.get_parent() == self:
				remove_child(_properties_inspector)
			# Form view is the default; Properties starts visible
			_properties_inspector.visible = true
			_properties_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
			right_bottom_stack.add_child(_properties_inspector)

		if is_instance_valid(_vg_file_browser):
			if _vg_file_browser.get_parent() == self:
				remove_child(_vg_file_browser)
			# Hidden by default; shown when code editor is active
			_vg_file_browser.visible = false
			_vg_file_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
			right_bottom_stack.add_child(_vg_file_browser)

		canvas_right_split.add_child(right_vsplit)
		main_hsplit.add_child(canvas_right_split)
		_ide_layout.add_child(main_hsplit)

		# ── Status Bar at bottom ──
		_status_bar = _create_vb6_status_bar()
		_ide_layout.add_child(_status_bar)

		# --- Add composite layout to main screen ---
		EditorInterface.get_editor_main_screen().add_child(_ide_layout)
		_ide_layout.visible = false
		# Set initial split ratios after layout is ready
		call_deferred("_setup_ide_split_ratios")
		call_deferred("_sync_scene_to_form_designer")
		print("VisualGasic: VB6 IDE layout created — Toolbox | Canvas | Properties")
	else:
		push_warning("VisualGasic: VisualGasicFormDesigner class not found in ClassDB")

	_post_init()
	_setup_script_editor_context_menu()
	_setup_recent_projects_menu()

	add_tool_menu_item("Add Form...", Callable(self, "_on_add_form"))
	add_tool_menu_item("New Module...", Callable(self, "_on_new_module"))
	add_tool_menu_item("New VG Project...", Callable(self, "_on_new_project"))
	add_tool_menu_item("Import VB6 Form...", Callable(self, "_on_import_vb6_form"))
	add_tool_menu_item("Import VB6 Project...", Callable(self, "_on_import_vb6_project"))
	add_tool_menu_item("Visual Gasic Menu Editor", Callable(self, "_on_menu_editor"))
	add_tool_menu_item("Visual Gasic Project Properties...", Callable(self, "_on_proj_props"))
	add_tool_menu_item("Visual Gasic Object Browser", Callable(self, "_on_obj_browser"))
	add_tool_menu_item("Visual Gasic Tab Order", Callable(self, "_on_tab_order"))
	add_tool_menu_item("Visual Gasic Components...", Callable(self, "_on_components"))
	add_tool_menu_item("Visual Gasic Hex Editor...", Callable(self, "_on_hex_editor_menu"))

	# Tip of the Day — load preference and create dialog
	_load_tip_config()
	_create_tip_of_day_dialog()

	# On the very first open of a new VG project, Godot otherwise lands on
	# the 2D main screen and the user sees a blank Godot editor instead of
	# the Visual Gasic IDE.  When the project has never completed first-run
	# setup, defer a switch to our main screen so _make_visible(true) fires,
	# the IDE layout becomes active, and (via _auto_open_formless_module)
	# the welcome dialog or starter module is shown.
	call_deferred("_select_vg_main_screen_on_first_run")

# =============================================================================
# DOCK MANAGEMENT — called by layout manager on mode toggle
# =============================================================================

## Moves VG panels from plugin children into Godot dock slots.
## Called when entering VB6 mode.
func dock_vg_panels():
	# Panels are embedded in the IDE layout — no docking needed
	if is_instance_valid(_ide_layout):
		return
	if _vg_panels_docked:
		return
	# Remove from plugin children first
	if is_instance_valid(toolbox) and toolbox.get_parent() == self:
		remove_child(toolbox)
	if is_instance_valid(_project_explorer) and _project_explorer.get_parent() == self:
		remove_child(_project_explorer)
	if is_instance_valid(_properties_inspector) and _properties_inspector.get_parent() == self:
		remove_child(_properties_inspector)
	# Add to Godot docks
	if is_instance_valid(toolbox):
		add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, toolbox)
		toolbox.visible = true
	if is_instance_valid(_project_explorer):
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _project_explorer)
		_project_explorer.visible = true
	if is_instance_valid(_properties_inspector):
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, _properties_inspector)
		_properties_inspector.visible = true
	_vg_panels_docked = true
	print("VisualGasic: VG panels added to docks")

## Detach the right panel (Project Explorer + Properties) from the
## center HSplitContainer so the embedded 2D/3D/Sprite editor gets
## the full center width. The detached panel is parked invisibly on
## the plugin so it stays alive across mode switches.
func _detach_right_panel() -> void:
	var right_split = _ide_layout.get_node_or_null("MainHSplit/CanvasRightSplit/RightPanelSplit") if is_instance_valid(_ide_layout) else null
	if right_split and right_split.get_parent():
		right_split.get_parent().remove_child(right_split)
		right_split.visible = false
		add_child(right_split)

## Re-attach the right panel into the center HSplitContainer for Form view.
func _attach_right_panel() -> void:
	if not is_instance_valid(_ide_layout):
		return
	var canvas_right = _ide_layout.get_node_or_null("MainHSplit/CanvasRightSplit")
	if not canvas_right:
		return
	# Find the parked panel (either still parented under canvas_right, or under self)
	var right_split = canvas_right.get_node_or_null("RightPanelSplit")
	if right_split == null:
		# Look for it among plugin's own children
		for c in get_children():
			if c.name == "RightPanelSplit":
				right_split = c
				break
	if right_split and right_split.get_parent() != canvas_right:
		if right_split.get_parent():
			right_split.get_parent().remove_child(right_split)
		canvas_right.add_child(right_split)
	if right_split:
		right_split.visible = true

## Removes VG panels from Godot docks back to plugin children.
## Called when exiting VB6 mode. Docks return to clean Godot state.
func undock_vg_panels():
	if not _vg_panels_docked:
		return
	# NOTE: Do NOT early-return if _ide_layout exists. Panels may have been
	# docked before _ide_layout was ready; we must clean them up regardless.
	if is_instance_valid(toolbox):
		remove_control_from_docks(toolbox)
		if not is_instance_valid(toolbox.get_parent()):
			add_child(toolbox)
		toolbox.visible = false
	if is_instance_valid(_project_explorer):
		remove_control_from_docks(_project_explorer)
		if not is_instance_valid(_project_explorer.get_parent()):
			add_child(_project_explorer)
		_project_explorer.visible = false
	if is_instance_valid(_properties_inspector):
		remove_control_from_docks(_properties_inspector)
		if not is_instance_valid(_properties_inspector.get_parent()):
			add_child(_properties_inspector)
		_properties_inspector.visible = false
	_vg_panels_docked = false
	print("VisualGasic: VG panels removed from docks (Godot mode)")

## Moves VG toolbars from plugin children into 2D canvas editor menu bar.
## Called when entering VB6 mode.
func dock_vg_toolbars():
	# Toolbars are embedded in the IDE layout — no container add needed
	if is_instance_valid(_ide_layout):
		return
	if _vg_toolbars_in_container:
		return
	for tb in [alignment_toolbar, form_preview_toolbar, _color_palette]:
		if is_instance_valid(tb):
			if tb.get_parent() == self:
				remove_child(tb)
			add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, tb)
			tb.visible = true
	_vg_toolbars_in_container = true
	print("VisualGasic: VG toolbars added to 2D canvas bar")

## Removes VG toolbars from 2D canvas editor menu bar back to plugin children.
## Called when exiting VB6 mode. 2D toolbar returns to clean Godot state.
func undock_vg_toolbars():
	# Toolbars are embedded in the IDE layout — no container remove needed
	if is_instance_valid(_ide_layout):
		return
	if not _vg_toolbars_in_container:
		return
	for tb in [alignment_toolbar, form_preview_toolbar, _color_palette]:
		if is_instance_valid(tb):
			remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, tb)
			add_child(tb)
			tb.visible = false
	_vg_toolbars_in_container = false
	print("VisualGasic: VG toolbars removed from 2D canvas bar (Godot mode)")

# =============================================================================
# MAIN SCREEN PLUGIN OVERRIDES
# =============================================================================

## The C++ Form Designer is a proper main screen tab (alongside 2D/3D/Script).
## Clicking it shows our custom canvas; clicking 2D/3D/Script hides it.
## NOTE: Godot calls _has_main_screen() BEFORE _enter_tree(), so we cannot
## rely on _form_designer being set.  Use a ClassDB check instead.
func _has_main_screen() -> bool:
	return ClassDB.class_exists(&"VisualGasicFormDesigner")

func _get_plugin_name() -> String:
	return "Visual Gasic IDE"

## Force the VG IDE main screen on the very first open of a brand-new
## VG project (i.e. one created by the bootstrap installer or "New Project").
## Without this, Godot defaults to the 2D screen and the user sees a stock
## Godot editor instead of the Visual Gasic IDE.  Subsequent launches respect
## whatever main screen the user last had active (Godot persists this in
## editor_layout.cfg → selected_main_editor_idx).
func _select_vg_main_screen_on_first_run() -> void:
	if not _has_main_screen():
		return  # C++ FormDesigner unavailable — nothing to switch to.
	var first_run_completed := false
	if ProjectSettings.has_setting("vg/first_run_completed"):
		first_run_completed = bool(ProjectSettings.get_setting("vg/first_run_completed", false))
	if first_run_completed:
		return
	# Defer once more so EditorNode finishes wiring its main-screen tabs
	# before we ask it to switch.  Calling set_main_screen_editor too early
	# (inside _enter_tree's deferred slot) is silently ignored by Godot.
	if not is_inside_tree():
		return
	get_tree().process_frame.connect(_do_select_vg_main_screen, CONNECT_ONE_SHOT)

func _do_select_vg_main_screen() -> void:
	if not _has_main_screen():
		return
	EditorInterface.set_main_screen_editor(_get_plugin_name())

func _get_plugin_icon() -> Texture2D:
	var theme = get_editor_interface().get_base_control().get_theme()
	if theme:
		var icon = theme.get_icon("Window", "EditorIcons")
		if icon:
			return icon
		icon = theme.get_icon("Control", "EditorIcons")
		if icon:
			return icon
	return null

func _make_visible(p_visible: bool) -> void:
	# Clear external scene editing flag when Form Designer is explicitly activated
	if p_visible:
		_editing_external_scene = false
	# Show/hide the entire VB6 IDE layout (Toolbox + Canvas + Properties)
	if _ide_layout:
		_ide_layout.visible = p_visible
	elif _form_designer:
		_form_designer.visible = p_visible
	# Hide Godot's own docks & bottom panel to maximize VB6 IDE experience
	if p_visible:
		_hide_godot_panels()
		# --- Auto-detect formless projects ---
		# If no form is currently loaded and the embedded editor has no file,
		# scan the project for standalone .vg modules and open the first one
		# so the user immediately has a code editor instead of a blank canvas.
		call_deferred("_auto_open_formless_module")
	else:
		_show_godot_panels()
		# Leaving Form Designer → save embedded code editor if dirty
		if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.is_dirty():
			_embedded_code_editor.save_file()
		# If we were showing code/3D/2D view, switch back to form view state
		# (so next time Form Designer opens it shows the form canvas)
		if _showing_code_view or _showing_3d_view or _showing_2d_view or _showing_sprite_view or _showing_plugin_view:
			# If a plugin was active, clear its active state so the toolbar
			# button won't early-return on the next click (the plugin manager
			# still thinks it's active even though we've hidden its view).
			if _showing_plugin_view and _vg_plugin_manager:
				_vg_plugin_manager.deactivate_all()
			_show_form_view()
		# Leaving Form Designer → patch in-memory tree so Godot's own saver
		# writes correct data.  Do NOT write to disk here — writing via C++
		# FileAccess bypasses Godot's resource system, causing the
		# "files modified outside Godot" prompt on every focus cycle.
		# The user's changes are safe in C++ memory and the patched tree;
		# they'll be flushed to disk on the next explicit save (Ctrl+S,
		# Build, Run, or editor shutdown).
		if is_instance_valid(_form_designer):
			_sync_form_state_to_scene_tree()
		# Always clear the flag here (even when form_path was empty and
		# the save block above was skipped — the previous code never
		# reached the clear in that case, leaving the flag stuck true).
		_switching_to_code_editor = false
	# Auto-load the currently edited scene into the C++ Form Designer —
	# but NOT when we're in the middle of a double-click → code-editor
	# flow.  Godot may fire a spurious _make_visible(true) during the
	# screen transition (edit_resource → set_main_screen_editor), and
	# calling _sync_scene at that point would re-parse the .tscn from
	# disk and wipe the in-memory controls.
	if p_visible and _form_designer and not _switching_to_code_editor:
		_sync_scene_to_form_designer()
	# Show Tip of the Day on first visit to Form Designer this session
	if p_visible and not _tip_shown_this_session:
		_tip_shown_this_session = true
		# Re-read config right before showing to avoid any race with _enter_tree
		_load_tip_config()
		print("[VG-TIP] _make_visible: show_tips_on_startup=", _show_tips_on_startup)
		if _show_tips_on_startup:
			call_deferred("_show_tip_of_day")

## Called when user clicks the "↩ Godot Editor" button.
## Switches from Form Designer back to the 2D editor, restoring all Godot panels.
func _on_back_to_godot_pressed() -> void:
	EditorInterface.set_main_screen_editor("2D")


## File > Exit to VG Welcome — saves unsaved work, then spawns the
## VG Welcome shell pointed at the cross-project recent list and quits
## the current editor instance.
func _on_exit_to_welcome() -> void:
	print("[VisualGasic] Exit to Welcome requested")
	# Best-effort save so the user doesn't lose work on the way out.
	if _form_dirty:
		_do_save_form()
	if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("save_file"):
		_embedded_code_editor.save_file()
	# Defer the actual spawn+quit so the popup-menu callback can return
	# cleanly first. Calling get_tree().quit() synchronously from inside
	# a PopupMenu.id_pressed handler in Godot 4.6 leaves the editor in a
	# half-shutdown state where leftover input events get re-dispatched
	# to the toolbar and can trigger an unintended Run.
	call_deferred("_do_exit_to_welcome")

func _do_exit_to_welcome() -> void:
	# Locate the welcome shell project. Order:
	#   1. $VG_WELCOME_DIR override
	#   2. Sibling / bundled to the current project
	#   3. Same directory as the running Godot binary (source-tree case:
	#      `Godot_vX.Y_*` lives next to `welcome_shell/` in the repo)
	#   4. /opt and ~/.local/share install layouts
	var candidates: Array = []
	var env_dir := OS.get_environment("VG_WELCOME_DIR")
	if not env_dir.is_empty():
		candidates.append(env_dir)
	var here_proj: String = ProjectSettings.globalize_path("res://").rstrip("/")
	if not here_proj.is_empty():
		candidates.append(here_proj.get_base_dir() + "/welcome_shell")  # sibling
		candidates.append(here_proj + "/welcome_shell")                 # bundled
		candidates.append(here_proj.get_base_dir().get_base_dir() + "/welcome_shell")
	# Godot binary's own directory — in source-tree dev the binary
	# (`Godot_v4.6.1-stable_linux.x86_64`) sits in the repo root next
	# to `welcome_shell/`.
	var bin_dir := OS.get_executable_path().get_base_dir()
	if not bin_dir.is_empty():
		candidates.append(bin_dir + "/welcome_shell")
		# macOS: executable is at <Godot.app>/Contents/MacOS/Godot, so
		# walk up out of the .app bundle to find a sibling welcome_shell.
		if OS.get_name() == "macOS":
			var app_parent := bin_dir.get_base_dir().get_base_dir().get_base_dir()
			if not app_parent.is_empty():
				candidates.append(app_parent + "/welcome_shell")
	candidates.append("/opt/visual_gasic/welcome_shell")
	var home := OS.get_environment("HOME")
	if not home.is_empty():
		candidates.append(home + "/.local/share/visual_gasic/welcome_shell")
		candidates.append(home + "/Documents/VisualGasic/welcome_shell")

	var welcome_dir: String = ""
	for c in candidates:
		if c is String and not c.is_empty() and FileAccess.file_exists(c + "/project.godot"):
			welcome_dir = c
			break

	var godot_bin := OS.get_executable_path()
	if welcome_dir.is_empty():
		push_warning("[VisualGasic] Welcome shell not found. Checked: %s" % str(candidates))
		# Don't fall back to bare PM — that's exactly what triggers the
		# 'no main scene' alert on the current project. Show our own
		# error instead and stay put.
		var err := AcceptDialog.new()
		err.title = "Welcome Shell Not Found"
		err.dialog_text = "Could not locate the VG Welcome shell.\nSet VG_WELCOME_DIR to point at the welcome_shell directory, or install VisualGasic to /opt/visual_gasic.\n\nSearched:\n  - " + "\n  - ".join(candidates)
		EditorInterface.get_base_control().add_child(err)
		err.popup_centered(Vector2i(640, 320))
		return

	# Launch the welcome shell as a regular running app (NOT --editor),
	# so the user sees the picker UI, not Godot's scene editor for it.
	# welcome_shell/project.godot has run/main_scene set to welcome.tscn.
	print("[VisualGasic] Spawning welcome shell at: ", welcome_dir)
	OS.create_process(godot_bin, ["--path", welcome_dir])

	# Hand off to the new instance, then quit ours.
	get_tree().quit()

## Called when user clicks the "🎲 3D View" button in the VG toolbar.
## Switches to the embedded 3D Scene Editor within the VG IDE.
func _on_3d_view_pressed() -> void:
	_show_3d_view()

## Called when user clicks the "🎮 2D Scene Editor" button in the VG toolbar.
## Switches to the embedded 2D Scene Editor within the VG IDE.
func _on_2d_view_pressed() -> void:
	_show_2d_view()

## Called when user clicks the "🎨 Sprite Editor" button in the VG toolbar.
## Switches to the embedded Piskel-style pixel art Sprite Editor.
func _on_sprite_view_pressed() -> void:
	_show_sprite_view()

## Called when the sprite editor saves a file.
func _on_sprite_saved(path: String) -> void:
	print("VisualGasic: Sprite saved to ", path)
	if is_instance_valid(_status_bar):
		_status_bar.text = "  Sprite saved: " + path.get_file()

## Called when a VG plugin is activated (e.g. AGCK button clicked).
## Hides all built-in views and shows the plugin's view.
func _on_vg_plugin_activated(plugin_id: String) -> void:
	# Save any unsaved code first
	if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.is_dirty():
		_embedded_code_editor.save_file()

	_showing_code_view = false
	_showing_3d_view = false
	_showing_2d_view = false
	_showing_sprite_view = false
	_showing_plugin_view = true

	# Hide all built-in editors
	# CenterStack itself must be hidden too. It's the FIRST child of
	# CanvasRightSplit (HSplitContainer); the plugin view is the second.
	# Hiding only its children leaves CenterStack as a visible-but-empty
	# Control that still claims its half of the HSplit, producing a black
	# void to the left of the plugin's UI on every restart/activation.
	var center_stack = _ide_layout.get_node_or_null("MainHSplit/CanvasRightSplit/CenterStack")
	if center_stack:
		center_stack.visible = false
	var canvas_scroll = _ide_layout.get_node_or_null("MainHSplit/CanvasRightSplit/CenterStack/CanvasScroll")
	if canvas_scroll:
		canvas_scroll.visible = false
	if is_instance_valid(_embedded_code_editor):
		_embedded_code_editor.visible = false
	if is_instance_valid(_vg_3d_editor):
		_vg_3d_editor.visible = false
	if is_instance_valid(_vg_2d_editor):
		_vg_2d_editor.visible = false
	if is_instance_valid(_vg_sprite_editor):
		_vg_sprite_editor.visible = false

	# Hide left toolbox panel — plugin has its own UI
	var toolbox_panel = _ide_layout.get_node_or_null("MainHSplit/ToolboxPanel")
	if toolbox_panel:
		var wrapper = toolbox_panel.get_node_or_null("ToolboxWrapper")
		if wrapper:
			wrapper.visible = false
		elif is_instance_valid(toolbox):
			toolbox.visible = false
		if is_instance_valid(_embedded_code_editor):
			var help_panel = _embedded_code_editor.get_help_panel()
			if help_panel:
				help_panel.visible = false
		toolbox_panel.visible = false

	# Hide right panel (Project Explorer + Properties) — plugin has its own
	# navigation/inspector UI, so this is wasted space in plugin view. The
	# Form view path restores it via _show_form_view().
	var right_panel_plugin = _ide_layout.get_node_or_null("MainHSplit/CanvasRightSplit/RightPanelSplit")
	if right_panel_plugin:
		right_panel_plugin.visible = false

	# Update status bar
	if is_instance_valid(_status_bar):
		_status_bar.text = "  Plugin: " + plugin_id.to_upper()

	print("VisualGasic: Switched to plugin view: ", plugin_id)

## Called when all VG plugins are deactivated (back-to-form request from a plugin).
func _on_vg_plugins_deactivated() -> void:
	_showing_plugin_view = false
	_show_form_view()

## Called when user clicks "↩ Back to VG IDE" in the 3D editor toolbar.
## Returns to the Visual Gasic IDE main screen.
func _on_back_to_vg_from_3d() -> void:
	EditorInterface.set_main_screen_editor(_get_plugin_name())

## Called by the editor after restoring saved window layout.
func _set_window_layout(config: ConfigFile):
	if is_instance_valid(_layout_manager):
		_layout_manager.on_window_layout_restored(config)
	# Restore saved split offsets (panel sizes)
	_saved_main_split_offset = config.get_value("VisualGasic", "main_split_offset", 200)
	_saved_canvas_right_offset = config.get_value("VisualGasic", "canvas_right_split_offset", -280)
	# Apply restored offsets to live split containers
	if is_instance_valid(_ide_layout):
		var main_split = _ide_layout.get_node_or_null("MainHSplit")
		if main_split and main_split is HSplitContainer:
			main_split.split_offset = _saved_main_split_offset
			var canvas_right = main_split.get_node_or_null("CanvasRightSplit")
			if canvas_right and canvas_right is HSplitContainer:
				canvas_right.split_offset = _saved_canvas_right_offset
	# Restore the form path from last session so the designer isn't blank
	var saved_form_path = config.get_value("VisualGasic", "form_path", "")
	if not saved_form_path.is_empty() and is_instance_valid(_form_designer):
		if FileAccess.file_exists(saved_form_path):
			_form_designer.open_form(saved_form_path)
			_fixup_form_size_from_tscn(saved_form_path)
			print("[VisualGasic] Restored form from layout config: ", saved_form_path)
			# Ensure the form is also open as a Godot scene tab so
			# _sync_form_state_to_scene_tree() can patch the in-memory
			# tree during save operations.
			if not saved_form_path in EditorInterface.get_open_scenes():
				call_deferred("_deferred_open_scene_tab", saved_form_path)
			# Apply VB6 theme to the live scene tree (deferred — scene root
			# may not be fully set up yet during layout restoration).
			call_deferred("_apply_vb6_theme_to_scene_root")
			# Populate Properties panel with form props on restore
			call_deferred("_populate_properties_for_form")

## Called by the editor when saving window layout (fires on focus loss and
## editor close).  We persist the current form path to survive editor restarts
## and patch the in-memory tree.  No disk writes — see _save_external_data().
func _get_window_layout(config: ConfigFile):
	if is_instance_valid(_layout_manager):
		_layout_manager.on_window_layout_saving(config)
	# Persist split offsets so the user's panel sizes survive editor restart
	config.set_value("VisualGasic", "main_split_offset", _saved_main_split_offset)
	config.set_value("VisualGasic", "canvas_right_split_offset", _saved_canvas_right_offset)
	# Persist the current form path so it survives editor restart
	if is_instance_valid(_form_designer):
		var fpath = _form_designer.get_form_path()
		if not fpath.is_empty():
			config.set_value("VisualGasic", "form_path", fpath)
			# Patch in-memory tree so Godot's own saver writes correct data.
			# Do NOT write to disk here — C++ FileAccess writes bypass Godot's
			# resource system and trigger 'modified outside Godot' dialogs.
			_sync_form_state_to_scene_tree()

## Called by the editor before saving any external data (scenes, resources).
## Godot calls this on EVERY auto-save, including when the window loses focus
## AND on Ctrl+S.  We NEVER write the .tscn from C++ here — writing via C++
## FileAccess bypasses Godot's ResourceSaver and causes the "files have been
## modified outside Godot" dialog every time the window regains focus.
##
## Instead we only patch the in-memory scene tree so that if Godot's own
## saver writes the scene (e.g. on Ctrl+S), it produces correct data.
## Actual C++ saves only happen via explicit user actions: _do_save_form()
## (Ctrl+S intercepted by our plugin), Build, Run, or editor shutdown.
func _save_external_data() -> void:
	if _saving_external:
		return  # reentrancy guard
	_saving_external = true
	if is_instance_valid(_form_designer):
		# Patch Godot's in-memory scene tree so its own saver writes
		# correct data (positions, sizes, text).  No disk writes here.
		_sync_form_state_to_scene_tree()
	_saving_external = false

## Called when the plugin exits the editor tree.
## Cleans up all plugin components and disconnects signals.
func _exit_tree():
	# Auto-save the form before cleanup so Godot doesn't lose our work
	if is_instance_valid(_form_designer):
		var fp = _form_designer.get_form_path()
		if fp.is_empty() and _form_designer.get_control_count() > 0:
			fp = "res://" + _form_designer.get_form_name() + ".tscn"
			_form_designer.save_form_as(fp)
			_strip_empty_menubar_from_tscn(fp)
		elif not fp.is_empty():
			_form_designer.save_form()
			_strip_empty_menubar_from_tscn(fp)
		if not _form_designer.get_form_path().is_empty():
			EditorInterface.get_resource_filesystem().update_file(_form_designer.get_form_path())
			# Patch in-memory tree so Godot's shutdown save doesn't overwrite
			_sync_form_state_to_scene_tree()
			print("[VisualGasic] _exit_tree → form auto-saved")
	# Restore any hidden Godot docks before cleanup
	_show_godot_panels()

	# Cleanup plugin manager
	if _vg_plugin_manager:
		_vg_plugin_manager.cleanup()
		_vg_plugin_manager = null
	
	get_editor_interface().get_base_control().remove_meta("visual_gasic_plugin_instance")
	
	remove_import_plugin(import_plugin)
	import_plugin = null
	
	if debugger_plugin:
		remove_debugger_plugin(debugger_plugin)
		debugger_plugin = null
	
	# Cleanup C++ Form Designer and IDE layout
	# Panels are children of _ide_layout, so free them first to avoid double-free
	if is_instance_valid(_ide_layout):
		# Reparent panels out of layout before freeing them individually
		for panel in [toolbox, _project_explorer, _properties_inspector, alignment_toolbar, form_preview_toolbar, _color_palette]:
			if is_instance_valid(panel) and panel.get_parent() and panel.get_parent() != self:
				panel.get_parent().remove_child(panel)
		_ide_layout.queue_free()
		_ide_layout = null
	if is_instance_valid(_form_designer):
		if _form_designer.get_parent():
			_form_designer.get_parent().remove_child(_form_designer)
		_form_designer.queue_free()
		_form_designer = null
	
	remove_tool_menu_item("Toggle VG IDE Layout")
	remove_tool_menu_item("Add Form...")
	remove_tool_menu_item("New Module...")
	remove_tool_menu_item("New VG Project...")
	remove_tool_menu_item("Import VB6 Form...")
	remove_tool_menu_item("Import VB6 Project...")
	remove_tool_menu_item("Visual Gasic Menu Editor")
	remove_tool_menu_item("Visual Gasic Project Properties...")
	remove_tool_menu_item("Visual Gasic Object Browser")
	remove_tool_menu_item("Visual Gasic Tab Order")
	remove_tool_menu_item("Visual Gasic Components...")
	remove_tool_menu_item("VG: Snippet Browser")
	remove_tool_menu_item("VG: Theme Picker")
	remove_tool_menu_item("Visual Gasic Hex Editor...")

	if is_instance_valid(_hex_editor):
		if is_instance_valid(_embedded_code_editor):
			_embedded_code_editor.remove_bottom_tab(_hex_editor)
		_hex_editor.queue_free()
		_hex_editor = null
	
	if is_instance_valid(immediate_window):
		# Immediate window is embedded in the code editor's bottom panel;
		# just free it (its parent will release it automatically)
		immediate_window.queue_free()
		immediate_window = null
	
	# Cleanup Profiler Panel (embedded in IDE bottom tabs)
	if is_instance_valid(_profiler_panel):
		if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("remove_bottom_tab"):
			_embedded_code_editor.remove_bottom_tab(_profiler_panel)
		elif _profiler_panel.get_parent():
			_profiler_panel.get_parent().remove_child(_profiler_panel)
		_profiler_panel.queue_free()
		_profiler_panel = null
	
	# Cleanup Controls Inspector (embedded in IDE bottom tabs)
	if is_instance_valid(_controls_inspector):
		if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("remove_bottom_tab"):
			_embedded_code_editor.remove_bottom_tab(_controls_inspector)
		elif _controls_inspector.get_parent():
			_controls_inspector.get_parent().remove_child(_controls_inspector)
		_controls_inspector.queue_free()
		_controls_inspector = null

	# Cleanup Package Browser (embedded in IDE bottom tabs)
	if is_instance_valid(_package_browser):
		_package_browser.cleanup()
		if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("remove_bottom_tab"):
			_embedded_code_editor.remove_bottom_tab(_package_browser)
		elif _package_browser.get_parent():
			_package_browser.get_parent().remove_child(_package_browser)
		_package_browser.queue_free()
		_package_browser = null

	# Cleanup AI Help Panel (embedded in IDE bottom tabs)
	if is_instance_valid(_ai_help_panel):
		if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("remove_bottom_tab"):
			_embedded_code_editor.remove_bottom_tab(_ai_help_panel)
		elif _ai_help_panel.get_parent():
			_ai_help_panel.get_parent().remove_child(_ai_help_panel)
		_ai_help_panel.queue_free()
		_ai_help_panel = null
	
	# Cleanup Code Navigator (injected above code editor)
	if is_instance_valid(_code_navigator):
		if _code_navigator.get_parent():
			_code_navigator.get_parent().remove_child(_code_navigator)
		_code_navigator.queue_free()
		_code_navigator = null
	_nav_injected_parent = null
	
	# Cleanup "Back to VG IDE" button from 3D editor toolbar
	if is_instance_valid(_back_to_vg_3d_btn):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _back_to_vg_3d_btn)
		_back_to_vg_3d_btn.queue_free()
		_back_to_vg_3d_btn = null
	
	# Cleanup alignment toolbar
	if is_instance_valid(alignment_toolbar):
		if alignment_toolbar.get_parent():
			alignment_toolbar.get_parent().remove_child(alignment_toolbar)
		alignment_toolbar.queue_free()
		alignment_toolbar = null
	
	# Cleanup form preview toolbar
	if is_instance_valid(form_preview_toolbar):
		if form_preview_toolbar.get_parent():
			form_preview_toolbar.get_parent().remove_child(form_preview_toolbar)
		form_preview_toolbar.queue_free()
		form_preview_toolbar = null
	
	# Cleanup Color Palette toolbar
	if is_instance_valid(_color_palette):
		if _color_palette.get_parent():
			_color_palette.get_parent().remove_child(_color_palette)
		_color_palette.queue_free()
		_color_palette = null
	
	# Cleanup Data Tips
	if is_instance_valid(_data_tips):
		_data_tips.cleanup()
		_data_tips.queue_free()
		_data_tips = null
	
	# Cleanup VB6 Layout Manager (detaches panels from main screen)
	if is_instance_valid(_layout_manager):
		_layout_manager.cleanup()
		remove_child(_layout_manager)
		_layout_manager.queue_free()
		_layout_manager = null

	# Cleanup VG panels — now embedded in IDE layout (already reparented above)
	if is_instance_valid(toolbox):
		if toolbox.get_parent():
			toolbox.get_parent().remove_child(toolbox)
		toolbox.queue_free()
		toolbox = null
	if is_instance_valid(_project_explorer):
		if _project_explorer.get_parent():
			_project_explorer.get_parent().remove_child(_project_explorer)
		_project_explorer.queue_free()
		_project_explorer = null
	if is_instance_valid(_properties_inspector):
		if _properties_inspector.get_parent():
			_properties_inspector.get_parent().remove_child(_properties_inspector)
		_properties_inspector.queue_free()
		_properties_inspector = null

	# (No VB6 main screen tab to clean up — form designer is the 2D viewport)

	# Cleanup recent projects menu
	if is_instance_valid(_recent_projects_menu):
		remove_tool_menu_item("Recent Projects")
		# Note: remove_tool_menu_item frees the popup internally
		_recent_projects_menu = null
	_recent_projects_manager = null
	
	# Cleanup script editor context menu
	if is_instance_valid(_script_editor_check_timer):
		_script_editor_check_timer.stop()
		_script_editor_check_timer.queue_free()
		_script_editor_check_timer = null
	
	if is_instance_valid(_script_context_menu):
		_script_context_menu.queue_free()
		_script_context_menu = null
		
	if get_editor_interface().get_selection().selection_changed.is_connected(_on_selection_changed):
		get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)
	
	# Disconnect node_added handler
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

# =============================================================================
# DEBUGGER BREAKPOINTS — called by form_preview_toolbar to persist breakpoints
# =============================================================================

## Returns the current breakpoint dictionary from ALL sources:
## 1. The embedded VG code editor (primary — where users actually set breakpoints)
## 2. The debugger plugin (ScriptEditor polling — fallback)
## Key: script_path (String), Value: Array of line numbers (int, 1-based).
func get_debugger_breakpoints() -> Dictionary:
	var result: Dictionary = {}

	# Source 1: Embedded VG code editor (0-based → 1-based conversion)
	if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("get_file_path") and _embedded_code_editor.has_method("get_code_edit"):
		var vg_path: String = _embedded_code_editor.get_file_path()
		var code_edit = _embedded_code_editor.get_code_edit()
		if not vg_path.is_empty() and code_edit:
			var bp_lines = code_edit.get_breakpointed_lines()
			if not bp_lines.is_empty():
				var lines_array: Array = []
				for line_idx in bp_lines:
					lines_array.append(line_idx + 1)  # 0-based → 1-based
				result[vg_path] = lines_array

	# Source 2: Debugger plugin (ScriptEditor polling)
	if debugger_plugin and is_instance_valid(debugger_plugin):
		if "_breakpoints" in debugger_plugin:
			for path in debugger_plugin._breakpoints:
				if not result.has(path):
					result[path] = debugger_plugin._breakpoints[path]
				else:
					for l in debugger_plugin._breakpoints[path]:
						if l not in result[path]:
							result[path].append(l)

	return result

## Intercept keyboard shortcuts BEFORE Godot's editor consumes them.
## Uses _input() — the FIRST callback in Godot's input chain — so our
## plugin sees key events before any GUI Control or built-in handler.
## This is critical because _shortcut_input() fires too late: by that
## point Godot's editor has already consumed Ctrl+S, Delete, etc.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	# Only intercept when our Form Designer main screen is visible
	if not is_instance_valid(_ide_layout) or not _ide_layout.visible:
		return

	# ── Ctrl+Shift+S  →  Save All ──
	if event.keycode == KEY_S and event.ctrl_pressed and event.shift_pressed and not event.alt_pressed:
		_do_save_all()
		get_viewport().set_input_as_handled()
		return

	# ── Ctrl+Shift+P  →  Command Palette ──
	# Ctrl+P    →  Quick Open (file finder)
	# Both surface the same VGCommandPalette popup; the prefix '>' on
	# the query line is what selects "command mode" vs file mode.
	if event.keycode == KEY_P and event.ctrl_pressed and not event.alt_pressed:
		var initial: String = "> " if event.shift_pressed else ""
		_open_command_palette(initial)
		get_viewport().set_input_as_handled()
		return

	# ── Ctrl+S  →  Save Form + Code ──
	if event.keycode == KEY_S and event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed:
		_do_save_form()
		if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("save_file"):
			_embedded_code_editor.save_file()
		_flash_status_message("Form saved")
		get_viewport().set_input_as_handled()
		return

	# ── Delete  →  Remove selected control (not root) ──
	# Skip if a text-editing control has focus (user might be typing)
	if event.keycode == KEY_DELETE and not event.ctrl_pressed and not event.alt_pressed:
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit or focused is CodeEdit:
			return  # let the text field handle Delete normally
		if is_instance_valid(_form_designer):
			_form_designer.remove_selected()
			_flash_status_message("Deleted control")
		get_viewport().set_input_as_handled()

## Fallback keyboard handler connected to the Form Designer canvas's gui_input.
## If _input() somehow misses an event (e.g., Godot processes the canvas
## control's gui_input before _input fires on our plugin node), this catches it.
func _on_canvas_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	# Ctrl+Shift+S → Save All
	if event.keycode == KEY_S and event.ctrl_pressed and event.shift_pressed and not event.alt_pressed:
		_do_save_all()
		_form_designer.accept_event()
		return
	# Ctrl+S → Save Form + Code
	if event.keycode == KEY_S and event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed:
		_do_save_form()
		if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("save_file"):
			_embedded_code_editor.save_file()
		_flash_status_message("Form saved")
		_form_designer.accept_event()
		return
	# Delete → Remove selected control
	if event.keycode == KEY_DELETE and not event.ctrl_pressed and not event.alt_pressed:
		if is_instance_valid(_form_designer):
			_form_designer.remove_selected()
			_flash_status_message("Deleted control")
		_form_designer.accept_event()

## Called every frame. Detects vg_control drag end and handles drop.
## When the C++ Form Designer is active and visible, it handles drops directly
## via _can_drop_data/_drop_data — skip the old GDScript drop path entirely.
func _process(_delta: float) -> void:
	# ── Persistently hide Godot menu/title/status bars ──
	if _godot_docks_hidden:
		for ctrl in _chrome_to_keep_hidden:
			if is_instance_valid(ctrl) and ctrl.visible:
				ctrl.visible = false
		# Keep the main VSplit collapsed each frame (Godot may restore it)
		if is_instance_valid(_godot_main_vsplit):
			var target_offset = int(_godot_main_vsplit.size.y)
			if _godot_main_vsplit.split_offset != target_offset:
				_godot_main_vsplit.split_offset = target_offset
			if _godot_main_vsplit.get_child_count() >= 2:
				var bc = _godot_main_vsplit.get_child(1)
				if bc is Control and bc.visible:
					bc.visible = false
		# Lazy-find the bottom panel if it wasn't found during initial hide
		# (the editor may not have fully built its UI when we first looked)
		if not is_instance_valid(_godot_bottom_panel) and not _bottom_panel_search_done:
			var base = get_editor_interface().get_base_control()
			_godot_bottom_panel = _find_bottom_panel(base)
			if is_instance_valid(_godot_bottom_panel):
				_chrome_to_keep_hidden.append(_godot_bottom_panel)
				_godot_bottom_panel.visible = false
				_bottom_panel_search_done = true
			# We'll keep retrying each frame until found (editor UI loads asynchronously)

	# C++ Form Designer handles its own drops — skip old code path
	if _form_designer and _form_designer.visible:
		if _vg_drag_active and not get_viewport().gui_is_dragging():
			_vg_drag_active = false  # Reset flag, C++ consumed the meta
		return

	# Check if we have an active vg_control drag
	var has_vg_drag = Engine.has_meta("_vg_active_drag")
	
	# Check if system is still dragging
	var viewport = get_viewport()
	var is_dragging = viewport and viewport.gui_is_dragging()
	
	# Detect drag start
	if has_vg_drag and not _vg_drag_active:
		_vg_drag_active = true
	
	# Detect drag end: was dragging, now stopped, still have drag data
	if _vg_drag_active and not is_dragging and has_vg_drag:
		_vg_drag_active = false
		
		var drag_data = Engine.get_meta("_vg_active_drag")
		Engine.remove_meta("_vg_active_drag")
		
		# Capture mouse position NOW before the delay (so position is accurate)
		if drag_data is Dictionary and drag_data.get("type") == "vg_control":
			var editor_viewport = get_editor_interface().get_editor_viewport_2d()
			var scene_root = get_editor_interface().get_edited_scene_root()
			if editor_viewport and scene_root:
				var mouse_pos = editor_viewport.get_mouse_position()
				var canvas_xform = editor_viewport.get_canvas_transform()
				var world_pos = canvas_xform.affine_inverse() * mouse_pos
				
				# Adjust for form's position on canvas (for Window nodes)
				var form_offset = Vector2.ZERO
				if scene_root is Window:
					form_offset = Vector2(scene_root.position)
				elif scene_root is Control:
					form_offset = scene_root.position
				
				var local_pos = world_pos - form_offset
				drag_data["drop_position"] = local_pos.snapped(Vector2(8, 8))
			
			# Use a timer to give Godot time to fully process the drag end
			var timer = get_tree().create_timer(0.05)  # 50ms delay
			timer.timeout.connect(_handle_vg_drop_delayed.bind(drag_data))
	
	# Safety reset: if drag was active but meta was consumed by _drop_data()
	# (form_editor_helper handled it), just reset the flag
	if _vg_drag_active and not is_dragging and not has_vg_drag:
		_vg_drag_active = false

## Handles vg_control drop after a short delay for editor stability.
## Modifies the .tscn file on disk and reloads — the ONLY approach that
## correctly registers ownership in the Godot editor scene tree.
## Improved over the original: uses proper UIDs, max-based ext_resource IDs,
## and reuses existing ext_resource entries to prevent scene corruption.
func _handle_vg_drop_delayed(drag_data: Dictionary) -> void:
	var scene_path = drag_data.get("scene_path", "")
	if scene_path.is_empty():
		printerr("VisualGasic: Empty scene_path in drag data")
		return
	
	# Get fresh reference to scene root
	var root = get_editor_interface().get_edited_scene_root()
	if not root or not is_instance_valid(root):
		printerr("VisualGasic: No valid scene root for drop")
		return
	
	# Scene must be saved to disk for text manipulation
	var edited_scene_path = root.scene_file_path
	if edited_scene_path.is_empty():
		printerr("VisualGasic: Scene has no file path")
		return
	
	# Use the pre-captured drop position (captured at moment of drop, not after delay)
	var drop_pos: Vector2 = drag_data.get("drop_position", Vector2.ZERO)
	if drop_pos == Vector2.ZERO:
		# Fallback to current mouse position if not captured
		var editor_viewport = get_editor_interface().get_editor_viewport_2d()
		if editor_viewport:
			var mouse_pos = editor_viewport.get_mouse_position()
			var canvas_xform = editor_viewport.get_canvas_transform()
			var world_pos = canvas_xform.affine_inverse() * mouse_pos
			drop_pos = world_pos.snapped(Vector2(8, 8))
	
	var control_name = scene_path.get_file().get_basename()
	
	# Save any pending editor changes before modifying the file on disk
	get_editor_interface().save_scene()
	
	# Read the current scene file
	var file = FileAccess.open(edited_scene_path, FileAccess.READ)
	if not file:
		printerr("VisualGasic: Could not open scene file: ", edited_scene_path)
		return
	var scene_text = file.get_as_text()
	file.close()
	
	# Check if this scene_path already has an ext_resource entry (reuse it)
	var ext_id_str := ""
	var lines = scene_text.split("\n")
	for line in lines:
		if line.begins_with("[ext_resource") and line.find('path="' + scene_path + '"') >= 0:
			var id_start = line.find('id="') + 4
			var id_end = line.find('"', id_start)
			if id_start > 3 and id_end > id_start:
				ext_id_str = line.substr(id_start, id_end - id_start)
			break
	
	if ext_id_str.is_empty():
		# Need a new ext_resource — find the maximum existing numeric ID
		var max_num := 0
		for line in lines:
			if line.begins_with("[ext_resource"):
				var id_start = line.find('id="') + 4
				var id_end = line.find('"', id_start)
				if id_start > 3 and id_end > id_start:
					var id_val = line.substr(id_start, id_end - id_start)
					# Handle Godot 4 "3_abc" style IDs — extract numeric prefix
					var num_part = id_val.split("_")[0]
					if num_part.is_valid_int() and int(num_part) > max_num:
						max_num = int(num_part)
		ext_id_str = str(max_num + 1)
		
		# Get proper UID for the prototype scene
		var uid_str := ""
		var uid_val = ResourceLoader.get_resource_uid(scene_path)
		if uid_val >= 0:
			uid_str = ResourceUID.id_to_text(uid_val)
		
		# Build the new ext_resource line
		var ext_line := '[ext_resource type="PackedScene"'
		if not uid_str.is_empty():
			ext_line += ' uid="' + uid_str + '"'
		ext_line += ' path="' + scene_path + '" id="' + ext_id_str + '"]\n'
		
		# Insert after the last ext_resource line
		var last_ext_pos = scene_text.rfind("[ext_resource")
		if last_ext_pos >= 0:
			var end_of_line = scene_text.find("\n", last_ext_pos)
			scene_text = scene_text.insert(end_of_line + 1, ext_line)
		else:
			# No ext_resources yet — insert before first [node
			var first_node_pos = scene_text.find("\n[node ")
			if first_node_pos >= 0:
				scene_text = scene_text.insert(first_node_pos, "\n" + ext_line)
	
	# Generate unique node name (always numbered)
	var existing_count = scene_text.count('[node name="' + control_name)
	var node_name = control_name + str(existing_count + 1)
	
	# Build the new node entry
	var node_line = '\n[node name="' + node_name + '" parent="." instance=ExtResource("' + ext_id_str + '")]\n'
	node_line += "offset_left = " + str(int(drop_pos.x)) + ".0\n"
	node_line += "offset_top = " + str(int(drop_pos.y)) + ".0\n"
	if control_name in ["Button", "Label", "CheckBox", "OptionButton"]:
		node_line += 'text = "' + node_name + '"\n'
	
	# Append node at the end
	scene_text += node_line
	
	# Write back
	file = FileAccess.open(edited_scene_path, FileAccess.WRITE)
	if not file:
		printerr("VisualGasic: Could not write scene file: ", edited_scene_path)
		return
	file.store_string(scene_text)
	file.close()
	
	# Reload the scene in the editor (evict stale cache first)
	_force_godot_scene_reload(edited_scene_path)
	
	# Select the new node after a short delay (to let the scene fully reload)
	var select_timer = get_tree().create_timer(0.1)
	select_timer.timeout.connect(_select_node_by_name.bind(node_name))
	
	print("VisualGasic: Dropped ", node_name, " at ", drop_pos)

## Selects a node by name after scene reload
func _select_node_by_name(node_name: String) -> void:
	var root = get_editor_interface().get_edited_scene_root()
	if not root:
		return
	
	var node = root.find_child(node_name, true, false)
	if node:
		get_editor_interface().get_selection().clear()
		get_editor_interface().get_selection().add_node(node)
		# Force the editor to focus on this node - this updates the Scene Tree display
		get_editor_interface().edit_node(node)

## Selects a node instance after it was dropped via toolbox drag.
## Called deferred to avoid conflicts with UndoRedo action processing.
func _select_dropped_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if not node.is_inside_tree():
		return
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)
	get_editor_interface().edit_node(node)

## Deferred handler for vg_control drop - runs on next frame for cleaner context
func _handle_vg_drag_end_deferred():
	_handle_vg_drag_end()
	Engine.remove_meta("_vg_active_drag")

## Handles the end of a vg_control drag operation.
## Computes drop position and delegates to _handle_vg_drop_delayed.
func _handle_vg_drag_end():
	if not Engine.has_meta("_vg_active_drag"):
		return
	
	var drag_data = Engine.get_meta("_vg_active_drag")
	if not drag_data is Dictionary:
		return
	
	# Compute drop position if not already set
	if not drag_data.has("drop_position"):
		var root = get_editor_interface().get_edited_scene_root()
		var viewport = get_editor_interface().get_editor_viewport_2d()
		if root and viewport:
			var mouse_pos = viewport.get_mouse_position()
			var canvas_xform = viewport.get_canvas_transform()
			var world_pos = canvas_xform.affine_inverse() * mouse_pos
			var form_offset = Vector2.ZERO
			if root is Window:
				form_offset = Vector2(root.position)
			elif root is Control:
				form_offset = root.position
			drag_data["drop_position"] = (world_pos - form_offset).snapped(Vector2(8, 8))
	
	_handle_vg_drop_delayed(drag_data)

# =============================================================================
# VB6 IMPORT FUNCTIONS
# =============================================================================

## Opens a file dialog to select and import a VB6 project (.vbp) file.
## The project will be converted to Godot scenes and .vg script files.
func _on_import_vb6_project():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.vbp ; VB6 Project Files"])
	fd.connect("file_selected", Callable(self, "_do_import_vbp"))
	fd.connect("canceled", fd.queue_free)
	fd.connect("file_selected", func(_p): fd.queue_free())
	get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.6)

## Performs the actual VB6 project import.
## @param path: Full filesystem path to the .vbp file
func _do_import_vbp(path):
	var importer = load("res://addons/visual_gasic/vb6_importer.gd")
	if !importer:
		push_error("VB6 Import: Could not load vb6_importer.gd")
		return

	var result = importer.import_project(path)
	get_editor_interface().get_resource_filesystem().scan()
	_add_to_recent_projects(path)

	# Generate and save import report
	var report_text = importer.generate_import_report(result)
	var proj_name = path.get_file().get_basename()
	importer.save_import_report(report_text, proj_name)

	# Open the first imported form in the VG Form Designer
	var forms = result.get("forms", [])
	if forms.size() > 0:
		var first_scene = forms[0].get("scene_path", "")
		if first_scene != "":
			call_deferred("open_form_in_designer", first_scene)

	# Show import results dialog
	_show_import_results_dialog(result, path)

## Opens a file dialog to select and import a single VB6 form (.frm) file.
## The form will be converted to a Godot scene with an attached .vg script.
func _on_import_vb6_form():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.frm ; VB6 Form Files"])
	fd.connect("file_selected", Callable(self, "_do_import_frm"))
	fd.connect("canceled", fd.queue_free)
	fd.connect("file_selected", func(_p): fd.queue_free())
	get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.6)

## Performs the actual VB6 form import.
## Creates a scene in res://start_forms/ and code in res://mixed/
## @param path: Full filesystem path to the .frm file
func _do_import_frm(path):
	var importer = load("res://addons/visual_gasic/vb6_importer.gd")
	if !importer:
		push_error("VB6 Import: Could not load vb6_importer.gd")
		return

	var result = importer.import_form_file(path)
	if result.get("success", false):
		var scene_path = result.get("scene_path", "")
		var code_path = result.get("code_path", "")
		print("VB6 Import OK: scene=%s  code=%s" % [scene_path, code_path])
		if code_path != "":
			_add_to_recent_projects(code_path)
		get_editor_interface().get_resource_filesystem().scan()
		# Open in the VG Form Designer (not just as a Godot scene)
		if scene_path != "":
			call_deferred("open_form_in_designer", scene_path)
	else:
		var errors = result.get("errors", [])
		for e in errors:
			push_error("VB6 Import: " + e)

	# Show import results dialog (even on failure)
	var wrapper = {"success": result.get("success", false), "forms": [result] if result.get("success", false) else [], "modules": [], "errors": result.get("errors", []), "warnings": result.get("warnings", [])}
	_show_import_results_dialog(wrapper, path)

## Shows a VB6-themed import results popup after a VBP or FRM import.
func _show_import_results_dialog(result: Dictionary, source_path: String) -> void:
	var dlg = AcceptDialog.new()
	dlg.title = "VB6 Import Results"
	dlg.min_size = Vector2i(520, 400)

	var vbox = VBoxContainer.new()

	# Header
	var header = Label.new()
	var forms_ok = result.get("forms", []).size()
	var mods_ok = result.get("modules", []).size()
	var errs = result.get("errors", []).size()
	var warns = result.get("warnings", []).size()
	var success = result.get("success", false)
	header.text = ("✅  Import Successful" if success else "❌  Import Failed") + \
		"\nSource: " + source_path.get_file() + \
		"\nForms: %d   Modules: %d   Errors: %d   Warnings: %d" % [forms_ok, mods_ok, errs, warns]
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	# Scrollable details
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Forms
	for form in result.get("forms", []):
		var lbl = Label.new()
		lbl.text = "  ✔ Form: %s → %s" % [form.get("name", "?"), form.get("scene_path", "?")]
		lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
		details.add_child(lbl)
		var ca = form.get("control_arrays", {})
		if ca.size() > 0:
			var ca_lbl = Label.new()
			ca_lbl.text = "      Control arrays: %s" % str(ca.keys())
			ca_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
			details.add_child(ca_lbl)
		for w in form.get("warnings", []):
			var wl = Label.new()
			wl.text = "      ⚠ " + w
			wl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details.add_child(wl)

	# Modules
	for mod in result.get("modules", []):
		var lbl = Label.new()
		lbl.text = "  ✔ Module: %s → %s" % [mod.get("name", "?"), mod.get("path", "?")]
		lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
		details.add_child(lbl)

	# Errors
	for err in result.get("errors", []):
		var lbl = Label.new()
		lbl.text = "  ✖ " + err
		lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(lbl)

	# Top-level warnings
	for w in result.get("warnings", []):
		var lbl = Label.new()
		lbl.text = "  ⚠ " + w
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(lbl)

	# Manual steps note
	if success:
		details.add_child(HSeparator.new())
		var note = Label.new()
		note.text = "Note: Review generated .vg code in res://mixed/ for TODO items.\nForms saved to res://start_forms/."
		note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(note)

	scroll.add_child(details)
	vbox.add_child(scroll)

	dlg.add_child(vbox)
	dlg.connect("confirmed", dlg.queue_free)
	dlg.connect("canceled", dlg.queue_free)
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

# =============================================================================
# FORM CREATION
# =============================================================================

## Opens the New Form dialog to create a new Visual Gasic form.
## Supports multiple templates (Standard, Dialog, MDI, etc.)
func _on_new_form():
	var dlg = load("res://addons/visual_gasic/new_form_dialog.gd").new()
	get_editor_interface().get_base_control().add_child(dlg)
	
	# Use signal callbacks instead of await for stability
	dlg.confirmed.connect(func():
		var template = dlg.get_selected_template()
		dlg.queue_free()
		if not template.is_empty():
			# Use call_deferred to ensure dialog is cleaned up first
			call_deferred("_create_form_from_template", template)
	)
	
	dlg.canceled.connect(func():
		dlg.queue_free()
	)
	
	dlg.popup_centered()

## Deferred script attachment helper (called after scene is ready).
## @param scene_path: Path to the scene file
## @param script_path: Path to the .vg script file
func _attach_script_deferred(scene_path, script_path):
	var root = get_editor_interface().get_edited_scene_root()
	if root and root.scene_file_path == scene_path:
		pass # Logic to attach script handled by inspector or manual attach for now. 
		# We need a proper resource loader for bas to set it effectively.

## Creates a new form from the selected template.
## Generates both the .tscn scene file and .vg script file.
## The form uses VGFormBase for WinForms-style lifecycle events.
## @param template: Dictionary containing form configuration:
##   - size: Vector2 for form dimensions
##   - has_menu: bool to add a MenuBar
##   - controls: Array of control definitions to add
func _create_form_from_template(template: Dictionary):
	# Generate unique filename first
	var path = "res://Form1.tscn"
	var form_name = "Form1"
	var idx = 1
	while FileAccess.file_exists(path):
		idx += 1
		form_name = "Form" + str(idx)
		path = "res://" + form_name + ".tscn"
	
	# Create the .vg script file FIRST
	var vg_path = path.replace(".tscn", ".vg")
	_create_vg_form_code(vg_path, form_name, template)
	
	# Force reimport so the script is available
	get_editor_interface().get_resource_filesystem().scan()
	
	# Make a deep copy of template to avoid closure issues
	var template_copy = template.duplicate(true)
	
	# Use a Timer node instead of get_tree().create_timer() for stability in editor plugins
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.one_shot = true
	timer.timeout.connect(func():
		timer.queue_free()
		_finish_form_creation(path, form_name, vg_path, template_copy)
	)
	get_editor_interface().get_base_control().add_child(timer)
	timer.start()

## Completes form creation after filesystem scan.
## @param path: Scene file path
## @param form_name: Name of the form
## @param vg_path: Path to the .vg script file
## @param template: Template dictionary
func _finish_form_creation(path: String, form_name: String, vg_path: String, template: Dictionary):
	# Check if this is a Game UI (HUD) form — uses CanvasLayer root instead of Window
	var is_hud: bool = template.get("is_hud", false)

	var root: Node
	if is_hud:
		# Game UI mode: CanvasLayer root (rendered above game world)
		root = CanvasLayer.new()
		root.name = form_name
		root.layer = 10
		# Notify the C++ form designer
		if _form_designer and _form_designer.has_method("set_game_ui_mode"):
			_form_designer.set_game_ui_mode(true)
	else:
		# VB6 Classic: Window root
		root = Window.new()
		root.name = form_name
		root.title = form_name
		root.position = Vector2i(10,36)  # Align with canvas origin in editor
		root.size = template.get("size", Vector2(800, 600))
		if _form_designer and _form_designer.has_method("set_game_ui_mode"):
			_form_designer.set_game_ui_mode(false)
	
	# Add MenuBar FIRST if specified - so _FormBackground comes AFTER and intercepts drops
	if template.get("has_menu", false):
		var menu_bar = MenuBar.new()
		menu_bar.name = "MainMenu"
		menu_bar.anchor_left = 0.0
		menu_bar.anchor_top = 0.0
		menu_bar.anchor_right = 1.0
		menu_bar.anchor_bottom = 0.0
		menu_bar.offset_bottom = 30
		# Set mouse_filter to IGNORE in editor so MenuBar doesn't intercept drops
		# The helper script will restore STOP at runtime for normal menu interaction
		menu_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Also attach the menu bar helper script to restore mouse_filter at runtime
		var menu_helper_script = load("res://addons/visual_gasic/menu_bar_helper.gd")
		if menu_helper_script:
			menu_bar.set_script(menu_helper_script)
		
		root.add_child(menu_bar)
		menu_bar.owner = root
		
		# Add default menus
		var file_menu = PopupMenu.new()
		file_menu.name = "mnuFile"
		file_menu.add_item("New", 0)
		file_menu.add_item("Open", 1)
		file_menu.add_item("Save", 2)
		file_menu.add_separator()
		file_menu.add_item("Exit", 3)
		menu_bar.add_child(file_menu)
		file_menu.owner = root
		menu_bar.set_menu_title(0, "File")
		
		var help_menu = PopupMenu.new()
		help_menu.name = "mnuHelp"
		help_menu.add_item("About", 0)
		menu_bar.add_child(help_menu)
		help_menu.owner = root
		menu_bar.set_menu_title(1, "Help")
	
	# Add a background panel AFTER MenuBar for visual boundaries and to intercept editor drops
	var bg_panel = Panel.new()
	bg_panel.name = "_FormBackground"
	# Don't use PRESET_FULL_RECT - let the panel have its own size for editor resize
	bg_panel.size = root.size
	# Use MOUSE_FILTER_PASS so the panel receives drop data but lets clicks through
	# to sibling controls (Buttons, ComboBoxes, etc.) for selection and deletion
	bg_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	# Attach the form editor helper script for drag-resize support
	var helper_script = load("res://addons/visual_gasic/form_editor_helper.gd")
	if helper_script:
		bg_panel.set_script(helper_script)
	root.add_child(bg_panel)
	bg_panel.owner = root
	
	# The form will handle its own lifecycle and window management
	# User can override Form_Load(), Form_Shown(), etc. in their .vg file
	
	# Add controls from template
	for control_data in template.get("controls", []):
		var control = null
		var ctrl_type = control_data.get("type", "Button")
		
		match ctrl_type:
			"Button":
				control = Button.new()
			"Label":
				control = Label.new()
			"TextEdit":
				control = TextEdit.new()
			"LineEdit":
				control = LineEdit.new()
			"CheckBox":
				control = CheckBox.new()
			"CheckButton":
				control = CheckButton.new()
			"ProgressBar":
				control = ProgressBar.new()
			"SpinBox":
				control = SpinBox.new()
			"HSlider":
				control = HSlider.new()
			_:
				# Default to Button for unknown types
				control = Button.new()
		
		if control:
			control.name = control_data.get("name", "Control")
			# Use 'text' property if available (works for Button, Label, LineEdit, etc.)
			if "text" in control:
				control.text = control_data.get("text", "")
			control.position = control_data.get("position", Vector2.ZERO)
			control.size = control_data.get("size", Vector2(100, 30))
			root.add_child(control)
			control.owner = root
	
	# Now attach the VG script AFTER all children are added and owners set
	# This prevents the script from interfering with owner assignment
	var vg_script = load(vg_path)
	if vg_script:
		root.set_script(vg_script)
		print("VisualGasic: Attached VG script to form: ", vg_path)
	else:
		# Fallback to GDScript base if VG script couldn't load
		var vg_form_base = load("res://addons/visual_gasic/VGFormBase.gd")
		root.set_script(vg_form_base)
		print("VisualGasic: Warning - VG script not found, using VGFormBase.gd")
	
	# Save scene
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, path)
	print("VisualGasic: Created form at ", path)
	
	# Open the scene
	get_editor_interface().open_scene_from_path(path)

## Creates the initial .vg script file for a new form.
## Uses template-specific code if available, otherwise generates default boilerplate.
## @param path: Output path for the .vg file
## @param form_name: Name of the form (used in comments and default text)
## @param template: Template dictionary containing optional "code" key with template-specific code
func _create_vg_form_code(path: String, form_name: String, template: Dictionary):
	var f = FileAccess.open(path, FileAccess.WRITE)
	
	# Use template-specific code if available
	var template_code = template.get("code", "")
	var code: String
	
	if not template_code.is_empty():
		# Use the template's custom code
		code = "' " + form_name + ".vg - " + template.get("name", "Form") + "\n"
		code += "' Generated from Visual Gasic template\n"
		code += "Option Explicit\n\n"
		code += template_code
	else:
		# Fallback to generic form code
		code = """' """ + form_name + """.vg - WinForms-style Form
' Extends VGFormBase which provides proper Form lifecycle
Option Explicit

' Form-level variables
Dim btnOK As Button
Dim btnCancel As Button
Dim lblTitle As Label

' InitializeComponent - Called by designer (like WinForms)
Sub InitializeComponent()
    ' Set form properties
    Me.Text = \"""" + form_name + """\"
    Me.FormBorderStyle = FormBorderStyleEnum.Sizable
    Me.StartPosition = FormStartPositionEnum.CenterScreen
    Me.size = Vector2(400, 300)
    
    ' Create a title label
    Set lblTitle = Label.new()
    lblTitle.name = "lblTitle"
    lblTitle.text = "Welcome to " + \"""" + form_name + """\"
    lblTitle.position = Vector2(100, 50)
    lblTitle.size = Vector2(200, 30)
    Me.add_child(lblTitle)
    
    ' Create OK button
    Set btnOK = Button.new()
    btnOK.name = "btnOK"
    btnOK.text = "OK"
    btnOK.position = Vector2(200, 220)
    btnOK.size = Vector2(80, 30)
    Me.add_child(btnOK)
    ' Note: Events are auto-wired! VGFormBase will automatically connect
    ' btnOK.pressed to btnOK_Click() if that method exists
    
    ' Create Cancel button
    Set btnCancel = Button.new()
    btnCancel.name = "btnCancel"
    btnCancel.text = "Cancel"
    btnCancel.position = Vector2(290, 220)
    btnCancel.size = Vector2(80, 30)
    Me.add_child(btnCancel)
    ' Events are auto-wired! No need to call .connect()
End Sub

' Form_Load - Called before form is displayed (like WinForms Load event)
Sub Form_Load()
    Print "Form loading..."
    InitializeComponent()
    ' Initialize your data, load settings, etc.
End Sub

' Form_Shown - Called after form becomes visible
Sub Form_Shown()
    Print "Form is now visible"
End Sub

' Form_Closing - Called when form is about to close (can cancel)
Sub Form_Closing(evt)
    ' evt.Cancel = True  ' Uncomment to prevent closing
    Print "Form closing"
End Sub

' Form_Closed - Called after form is closed
Sub Form_Closed()
    Print "Form closed"
End Sub

' Form_Resize - Called when form is resized
Sub Form_Resize()
    ' Reposition controls if needed
End Sub

' ====== Event Handlers ======
' These are automatically wired by VGFormBase based on naming pattern:
' ControlName_EventType (e.g. btnOK_Click, txtName_Change)

Sub btnOK_Click()
    Print "OK button clicked!"
    ' Close the form with OK result
    Me.DialogResult = DialogResultEnum.OK
    Me.Close()
End Sub

Sub btnCancel_Click()
    Print "Cancel button clicked!"
    ' Close the form with Cancel result
    Me.DialogResult = DialogResultEnum.Cancel
    Me.Close()
End Sub
"""
	f.store_string(code)
	f.close()

# =============================================================================
# VB6 LAYOUT TOGGLE
# =============================================================================

## Called when the user clicks the "Form Designer" button in the main screen bar.
## Activates VB6 mode (just like clicking 2D/3D/Script activates that screen).
## With toggle_mode=true, the button toggles its own pressed state before this fires.
func _on_form_designer_pressed():
	# Switch to our main screen tab (C++ Form Designer)
	if _form_designer:
		EditorInterface.set_main_screen_editor("Visual Gasic IDE")
	else:
		push_warning("VisualGasic: C++ FormDesigner not available — rebuild the editor library with 'scons target=editor platform=linux'")
		EditorInterface.set_main_screen_editor("2D")
		return
	# Also activate VB6 layout if available
	if is_instance_valid(_layout_manager):
		if not _layout_manager.is_vb6_mode():
			_layout_manager.toggle()

## Opens a .tscn form file in the C++ Form Designer.
## Called from Project Explorer or when double-clicking a .tscn in FileSystem.
func open_form_in_designer(tscn_path: String) -> void:
	if not _form_designer:
		push_warning("VisualGasic: Form Designer not available")
		return
	# Open as a Godot scene tab FIRST so _sync_form_state_to_scene_tree()
	# can patch Godot's in-memory tree when saving.
	if not tscn_path in EditorInterface.get_open_scenes():
		EditorInterface.open_scene_from_path(tscn_path)
	_form_designer.open_form(tscn_path)
	_fixup_form_size_from_tscn(tscn_path)
	EditorInterface.set_main_screen_editor("Visual Gasic IDE")
	print("VisualGasic: Opened '", tscn_path, "' in Visual Gasic IDE")
	# Apply VB6 theme to the live scene tree immediately
	_apply_vb6_theme_to_scene_root()
	# Populate Properties panel with form-level properties (VB6 behaviour)
	_populate_properties_for_form()
	# Also force a scene reload so the 2D viewport picks up any C++ changes.
	get_tree().create_timer(0.3).timeout.connect(_force_godot_scene_reload.bind(tscn_path))

## Sets initial split positions for the embedded VB6 IDE layout.
## Called deferred after the layout is added to the scene tree.
func _setup_ide_split_ratios() -> void:
	if not is_instance_valid(_ide_layout):
		return
	# Main horizontal split: Toolbox panel width
	var main_split = _ide_layout.get_node_or_null("MainHSplit")
	if main_split and main_split is HSplitContainer:
		main_split.split_offset = _saved_main_split_offset
		if not main_split.dragged.is_connected(_on_main_split_dragged):
			main_split.dragged.connect(_on_main_split_dragged)
		# Canvas-Right split: right panel width
		var canvas_right = main_split.get_node_or_null("CanvasRightSplit")
		if canvas_right and canvas_right is HSplitContainer:
			canvas_right.split_offset = _saved_canvas_right_offset
			if not canvas_right.dragged.is_connected(_on_canvas_right_split_dragged):
				canvas_right.dragged.connect(_on_canvas_right_split_dragged)
	# Apply VB6 visual styling
	_apply_vb6_theme()
	_restyle_toolbox_buttons()
	_apply_designer_theme()

func _on_main_split_dragged(offset: int) -> void:
	_saved_main_split_offset = offset

func _on_canvas_right_split_dragged(offset: int) -> void:
	_saved_canvas_right_offset = offset

# =============================================================================
# VB6 IDE STYLING — Hide Godot panels, VB6 colors, panel headers
# =============================================================================

## Creates a VB6-style section header label (like "Properties - Form1")
func _create_vb6_header(title: String, closeable: bool = true) -> PanelContainer:
	var header = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = _theme.get("header_background", Color(0.58, 0.58, 0.62))
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = _theme.get("header_border", Color(0.4, 0.4, 0.4))
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	header.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", _theme.get("header_font_size", 12))
	lbl.add_theme_color_override("font_color", _theme.get("header_text", Color(1.0, 1.0, 1.0)))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	if closeable:
		var close_btn = Button.new()
		close_btn.text = "×"
		close_btn.flat = true
		close_btn.custom_minimum_size = Vector2(18, 18)
		close_btn.add_theme_font_size_override("font_size", _theme.get("header_font_size", 12) + 2)
		close_btn.add_theme_color_override("font_color", _theme.get("header_text", Color(1.0, 1.0, 1.0)))
		hbox.add_child(close_btn)

	header.add_child(hbox)
	header.custom_minimum_size.y = 22
	return header

## Loads the theme configuration with safe fallbacks.
## Populates _theme with hardcoded defaults first, then overlays values from
## vg_form_designer_theme.gd if the file exists and parses correctly.
## This means editing the theme file can NEVER break the IDE — bad values
## or a missing file simply leave the defaults in place.
func _load_theme_config() -> void:
	# ── Hardcoded defaults (the known-good VB6 palette) ──
	_theme = {
		# Form canvas
		"form_background": Color(0.753, 0.753, 0.753),
		"grid_dots": Color(0.0, 0.0, 0.0, 0.3),
		"selection_border": Color(0.0, 0.0, 0.6),
		"selection_handle": Color(0.0, 0.0, 0.0),
		"rubber_band": Color(0.0, 0.0, 0.6, 0.3),
		"form_border": Color(0.4, 0.4, 0.4),
		# Win32 system colors
		"sys_button_face": Color(0.831, 0.816, 0.784),
		"sys_button_highlight": Color(1.0, 1.0, 1.0),
		"sys_button_shadow": Color(0.51, 0.51, 0.51),
		"sys_3d_dark_shadow": Color(0.25, 0.25, 0.25),
		"sys_3d_light": Color(0.93, 0.93, 0.89),
		"sys_window": Color(1.0, 1.0, 1.0),
		"sys_window_text": Color(0.0, 0.0, 0.0),
		"sys_active_title": Color(0.0, 0.0, 0.5),
		"sys_title_text": Color(1.0, 1.0, 1.0),
		"sys_scrollbar": Color(0.87, 0.87, 0.87),
		"sys_glyph": Color(0.0, 0.0, 0.0),
		"sys_progress_fill": Color(0.0, 0.5, 0.0),
		"design_time_outline": Color(0.0, 0.0, 0.0, 0.35),
		"nonvisual_bg": Color(0.9, 0.85, 0.72),
		"nonvisual_border": Color(0.6, 0.55, 0.45),
		"placeholder_color": Color(0.6, 0.6, 0.6),
		"mdi_background": Color(0.64, 0.64, 0.64),
		"form_handle_color": Color(0.0, 0.0, 0.0),
		"sys_inactive_title": Color(0.5, 0.5, 0.5),
		# IDE panels
		"panel_background": Color("#F0EDE8"),
		"panel_border": Color(0.72, 0.71, 0.68),
		"toolbox_btn_normal": Color("#F0EDE8"),
		"toolbox_btn_hover": Color(0.91, 0.95, 1.0),
		"toolbox_btn_pressed": Color(0.26, 0.59, 0.98),
		"toolbox_btn_hover_border": Color(0.55, 0.73, 0.95),
		"toolbox_text": Color.BLACK,
		"toolbox_text_pressed": Color.WHITE,
		"project_explorer_text": Color.BLACK,
		# Headers
		"header_background": Color(0.58, 0.58, 0.62),
		"header_border": Color(0.4, 0.4, 0.4),
		"header_text": Color(1.0, 1.0, 1.0),
		"header_font_size": 12,
		# Toolbar buttons
		"godot_button_text": Color(0.85, 0.85, 0.85),
		"godot_button_hover_text": Color(1.0, 1.0, 1.0),
		"toggle_button_text": Color(0.95, 0.82, 0.2),
		"toggle_button_hover": Color(1.0, 0.9, 0.3),
		"toggle_button_pressed": Color(1.0, 1.0, 0.5),
		# Window title
		"window_title_prefix": "Visual Gasic",
	}

	# Overlay VGThemeManager IDE-chrome values so the active theme
	# (QBasic, Godot Dark, etc.) is honoured from the very first frame.
	var td = VGThemeManager.get_current_theme()
	if td:
		_theme["panel_background"] = td.ide_panel_bg
		_theme["panel_border"] = td.ide_panel_border
		_theme["header_background"] = td.ide_header_bg
		_theme["header_border"] = td.ide_header_border
		_theme["header_text"] = td.ide_header_text
		_theme["toolbox_btn_normal"] = td.ide_panel_bg
		_theme["toolbox_btn_hover"] = td.ide_toolbox_btn_hover
		_theme["toolbox_btn_pressed"] = td.ide_toolbox_btn_pressed
		_theme["toolbox_text"] = td.ide_text_color
		_theme["toolbox_text_pressed"] = td.ide_toolbox_text_pressed
	print("VisualGasic: Theme loaded (%d values, VGThemeManager overlay: %s)" % [_theme.size(), "yes" if td else "no"])

## Builds a VB6-style light Theme resource for the entire IDE layout.
## When applied to _ide_layout, this propagates to ALL children — including
## the C++ VisualGasicToolbox (PanelContainer) that would otherwise use
## Godot's dark editor theme.
func _build_vb6_theme() -> Theme:
	var t = Theme.new()
	# Read IDE chrome colors from the active theme in VGThemeManager
	var td = VGThemeManager.get_current_theme()
	var bg: Color = td.ide_panel_bg if td else _theme.get("panel_background", Color("#F0EDE8"))
	var border: Color = td.ide_panel_border if td else _theme.get("panel_border", Color(0.72, 0.71, 0.68))
	var text_color: Color = td.ide_text_color if td else Color.BLACK
	var list_bg: Color = td.ide_list_bg if td else Color.WHITE
	var tab_sel_bg: Color = td.ide_tab_selected_bg if td else bg
	var tab_unsel_bg: Color = td.ide_tab_unselected_bg if td else Color(0.85, 0.84, 0.82)
	var tab_hover_bg: Color = td.ide_tab_hover_bg if td else Color(0.95, 0.94, 0.92)
	var btn_hover_bg: Color = td.ide_btn_hover_bg if td else Color(0.95, 0.94, 0.92)
	var btn_pressed_bg: Color = td.ide_btn_pressed_bg if td else Color(0.88, 0.87, 0.85)
	var tooltip_bg: Color = td.ide_tooltip_bg if td else Color(1.0, 1.0, 0.94)
	var tab_unsel_text: Color = text_color.lerp(bg, 0.35)

	# ── PanelContainer (fixes C++ VisualGasicToolbox dark bg) ──
	var pc_sb = StyleBoxFlat.new()
	pc_sb.bg_color = bg
	pc_sb.border_color = border
	pc_sb.set_border_width_all(1)
	pc_sb.set_content_margin_all(2)
	t.set_stylebox("panel", "PanelContainer", pc_sb)

	# ── TabContainer panel + tab bar ──
	var tc_panel = StyleBoxFlat.new()
	tc_panel.bg_color = bg
	tc_panel.set_content_margin_all(4)
	t.set_stylebox("panel", "TabContainer", tc_panel)

	var tab_sel = StyleBoxFlat.new()
	tab_sel.bg_color = tab_sel_bg
	tab_sel.border_color = border
	tab_sel.border_width_left = 1; tab_sel.border_width_top = 1
	tab_sel.border_width_right = 1; tab_sel.border_width_bottom = 0
	tab_sel.content_margin_left = 8; tab_sel.content_margin_right = 8
	tab_sel.content_margin_top = 4; tab_sel.content_margin_bottom = 4
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_selected", "TabBar", tab_sel)

	var tab_unsel = StyleBoxFlat.new()
	tab_unsel.bg_color = tab_unsel_bg
	tab_unsel.border_color = border
	tab_unsel.set_border_width_all(1)
	tab_unsel.content_margin_left = 8; tab_unsel.content_margin_right = 8
	tab_unsel.content_margin_top = 4; tab_unsel.content_margin_bottom = 4
	t.set_stylebox("tab_unselected", "TabContainer", tab_unsel)
	t.set_stylebox("tab_unselected", "TabBar", tab_unsel)

	var tab_hover = StyleBoxFlat.new()
	tab_hover.bg_color = tab_hover_bg
	tab_hover.border_color = border
	tab_hover.border_width_left = 1; tab_hover.border_width_top = 1
	tab_hover.border_width_right = 1; tab_hover.border_width_bottom = 0
	tab_hover.content_margin_left = 8; tab_hover.content_margin_right = 8
	tab_hover.content_margin_top = 4; tab_hover.content_margin_bottom = 4
	t.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	t.set_stylebox("tab_hovered", "TabBar", tab_hover)

	# Tab font colors
	t.set_color("font_selected_color", "TabContainer", text_color)
	t.set_color("font_unselected_color", "TabContainer", tab_unsel_text)
	t.set_color("font_hovered_color", "TabContainer", text_color)
	t.set_color("font_selected_color", "TabBar", text_color)
	t.set_color("font_unselected_color", "TabBar", tab_unsel_text)
	t.set_color("font_hovered_color", "TabBar", text_color)

	# ── Tree (Project Explorer, Properties Inspector) ──
	var tree_sb = StyleBoxFlat.new()
	tree_sb.bg_color = list_bg
	tree_sb.border_color = border
	tree_sb.set_border_width_all(1)
	t.set_stylebox("panel", "Tree", tree_sb)
	t.set_color("font_color", "Tree", text_color)
	t.set_color("font_selected_color", "Tree", Color.WHITE if text_color.get_luminance() < 0.5 else Color.BLACK)

	# ── ItemList ──
	var il_sb = StyleBoxFlat.new()
	il_sb.bg_color = list_bg
	il_sb.border_color = border
	il_sb.set_border_width_all(1)
	t.set_stylebox("panel", "ItemList", il_sb)
	t.set_color("font_color", "ItemList", text_color)

	# ── Label ──
	t.set_color("font_color", "Label", text_color)

	# ── LineEdit (property fields) ──
	var le_sb = StyleBoxFlat.new()
	le_sb.bg_color = list_bg
	le_sb.border_color = border
	le_sb.set_border_width_all(1)
	le_sb.content_margin_left = 4; le_sb.content_margin_right = 4
	le_sb.content_margin_top = 2; le_sb.content_margin_bottom = 2
	t.set_stylebox("normal", "LineEdit", le_sb)
	t.set_color("font_color", "LineEdit", text_color)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.5, 0.5))

	# ── Button (neutral light style — toolbox buttons override individually) ──
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = bg
	btn_sb.border_color = border
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 4; btn_sb.content_margin_right = 4
	btn_sb.content_margin_top = 2; btn_sb.content_margin_bottom = 2
	t.set_stylebox("normal", "Button", btn_sb)
	var btn_hov = StyleBoxFlat.new()
	btn_hov.bg_color = btn_hover_bg
	btn_hov.border_color = border
	btn_hov.set_border_width_all(1)
	btn_hov.content_margin_left = 4; btn_hov.content_margin_right = 4
	btn_hov.content_margin_top = 2; btn_hov.content_margin_bottom = 2
	t.set_stylebox("hover", "Button", btn_hov)
	var btn_prs = StyleBoxFlat.new()
	btn_prs.bg_color = btn_pressed_bg
	btn_prs.border_color = border
	btn_prs.set_border_width_all(1)
	btn_prs.content_margin_left = 4; btn_prs.content_margin_right = 4
	btn_prs.content_margin_top = 2; btn_prs.content_margin_bottom = 2
	t.set_stylebox("pressed", "Button", btn_prs)
	t.set_color("font_color", "Button", text_color)
	t.set_color("font_hover_color", "Button", text_color)
	t.set_color("font_pressed_color", "Button", text_color)

	# ── OptionButton ──
	var ob_sb = StyleBoxFlat.new()
	ob_sb.bg_color = bg
	ob_sb.border_color = border
	ob_sb.set_border_width_all(1)
	ob_sb.content_margin_left = 4; ob_sb.content_margin_right = 16
	ob_sb.content_margin_top = 2; ob_sb.content_margin_bottom = 2
	t.set_stylebox("normal", "OptionButton", ob_sb)
	t.set_color("font_color", "OptionButton", text_color)

	# ── ScrollContainer ──
	var sc_sb = StyleBoxFlat.new()
	sc_sb.bg_color = bg
	t.set_stylebox("panel", "ScrollContainer", sc_sb)

	# ── Tooltip (classic light-yellow tooltip) ──
	var tooltip_sb = StyleBoxFlat.new()
	tooltip_sb.bg_color = tooltip_bg
	tooltip_sb.border_color = Color(0.0, 0.0, 0.0)
	tooltip_sb.set_border_width_all(1)
	tooltip_sb.set_content_margin_all(4)
	t.set_stylebox("panel", "TooltipPanel", tooltip_sb)
	t.set_color("font_color", "TooltipLabel", Color.BLACK if tooltip_bg.get_luminance() > 0.5 else Color.WHITE)

	return t

## Builds a VB6 Classic (Win98) Theme for form SCENES.
## Unlike _build_vb6_theme() which styles the IDE panels, this theme styles
## the controls that appear in the Godot 2D viewport and at runtime (F5).
## It uses the authentic Win32 system color palette from the C++ header.
func _build_vb6_scene_theme() -> Theme:
	var t = Theme.new()

	# ── Win32 system color palette (matches C++ header exactly) ──
	var btn_face     := Color(0.831, 0.816, 0.784)  # SystemButtonFace #D4D0C8
	var btn_highlight:= Color(1.0, 1.0, 1.0)        # 3D highlight
	var btn_shadow   := Color(0.51, 0.51, 0.51)     # 3D shadow
	var dark_shadow  := Color(0.25, 0.25, 0.25)     # Dark shadow edge
	var light_3d     := Color(0.93, 0.93, 0.89)     # Inner highlight
	var win_bg       := Color(1.0, 1.0, 1.0)        # Window/textbox bg
	var win_text     := Color(0.0, 0.0, 0.0)        # Text in windows
	var form_bg      := Color(0.753, 0.753, 0.753)  # Classic form gray #C0C0C0
	var scrollbar_bg := Color(0.87, 0.87, 0.87)     # Scrollbar track
	var progress_fill:= Color(0.0, 0.5, 0.0)        # Progress bar green
	var placeholder  := Color(0.6, 0.6, 0.6)        # Placeholder text
	var title_bg     := Color(0.0, 0.0, 0.5)        # Title bar blue
	var title_text   := Color(1.0, 1.0, 1.0)        # Title bar text
	var disabled_text:= Color(0.51, 0.51, 0.51)     # Disabled/grayed text

	# ── Helper: create a Win98-style raised StyleBoxFlat ──
	# Outer: dark_shadow bottom-right, btn_highlight top-left
	# Inner: btn_shadow bottom-right, light_3d top-left
	# VB6 buttons have a distinctive 2px raised-edge look
	var _make_raised = func(bg: Color) -> StyleBoxFlat:
		var sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = btn_highlight
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_color = btn_shadow  # Godot uses one border_color, approximate with shadow
		sb.border_width_bottom = 2
		sb.border_width_right = 2
		# Approximate the 3D look: top/left = highlight, bottom/right = shadow
		# Godot 4 doesn't support per-edge colors, so we use a compromise
		sb.border_color = Color(0.6, 0.6, 0.6)  # Mid-gray border
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		return sb

	var _make_sunken = func(bg: Color) -> StyleBoxFlat:
		var sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = btn_shadow
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_bottom = 2
		sb.border_width_right = 2
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		return sb

	# ── Window ──
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = form_bg
	win_sb.set_content_margin_all(0)
	t.set_stylebox("embedded_border", "Window", win_sb)
	t.set_stylebox("embedded_unfocused_border", "Window", win_sb)

	# ── Panel / PanelContainer — form background ──
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = form_bg
	panel_sb.set_content_margin_all(0)
	t.set_stylebox("panel", "Panel", panel_sb)
	var pc_sb = StyleBoxFlat.new()
	pc_sb.bg_color = form_bg
	pc_sb.set_content_margin_all(0)
	t.set_stylebox("panel", "PanelContainer", pc_sb)

	# ── Button ──
	var btn_normal = _make_raised.call(btn_face)
	t.set_stylebox("normal", "Button", btn_normal)

	var btn_hover = _make_raised.call(Color(0.87, 0.855, 0.824))  # Slightly lighter
	t.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = btn_face
	btn_pressed.border_color = dark_shadow
	btn_pressed.set_border_width_all(2)
	btn_pressed.content_margin_left = 5  # Shift text down-right on press
	btn_pressed.content_margin_right = 3
	btn_pressed.content_margin_top = 3
	btn_pressed.content_margin_bottom = 1
	t.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled = _make_raised.call(btn_face)
	t.set_stylebox("disabled", "Button", btn_disabled)

	var btn_focus = StyleBoxFlat.new()
	btn_focus.bg_color = btn_face
	btn_focus.border_color = Color(0.0, 0.0, 0.0)
	btn_focus.set_border_width_all(1)
	btn_focus.content_margin_left = 4
	btn_focus.content_margin_right = 4
	btn_focus.content_margin_top = 2
	btn_focus.content_margin_bottom = 2
	t.set_stylebox("focus", "Button", btn_focus)

	t.set_color("font_color",          "Button", win_text)
	t.set_color("font_hover_color",    "Button", win_text)
	t.set_color("font_pressed_color",  "Button", win_text)
	t.set_color("font_disabled_color", "Button", disabled_text)
	t.set_color("font_focus_color",    "Button", win_text)

	# ── LineEdit ──
	var le_normal = _make_sunken.call(win_bg)
	t.set_stylebox("normal", "LineEdit", le_normal)

	var le_focus = _make_sunken.call(win_bg)
	le_focus.border_color = Color(0.0, 0.0, 0.0)
	t.set_stylebox("focus", "LineEdit", le_focus)

	var le_read_only = _make_sunken.call(btn_face)
	t.set_stylebox("read_only", "LineEdit", le_read_only)

	t.set_color("font_color",             "LineEdit", win_text)
	t.set_color("font_selected_color",    "LineEdit", title_text)
	t.set_color("font_uneditable_color",  "LineEdit", disabled_text)
	t.set_color("font_placeholder_color", "LineEdit", placeholder)
	t.set_color("selection_color",        "LineEdit", title_bg)
	t.set_color("caret_color",            "LineEdit", win_text)

	# ── TextEdit ──
	var te_normal = _make_sunken.call(win_bg)
	t.set_stylebox("normal", "TextEdit", te_normal)

	var te_focus = _make_sunken.call(win_bg)
	te_focus.border_color = Color(0.0, 0.0, 0.0)
	t.set_stylebox("focus", "TextEdit", te_focus)

	var te_read_only = _make_sunken.call(btn_face)
	t.set_stylebox("read_only", "TextEdit", te_read_only)

	t.set_color("font_color",             "TextEdit", win_text)
	t.set_color("font_selected_color",    "TextEdit", title_text)
	t.set_color("font_readonly_color",    "TextEdit", disabled_text)
	t.set_color("font_placeholder_color", "TextEdit", placeholder)
	t.set_color("selection_color",        "TextEdit", title_bg)
	t.set_color("caret_color",            "TextEdit", win_text)

	# ── Label ──
	t.set_color("font_color",        "Label", win_text)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))  # No shadow

	# ── CheckBox ──
	var cb_normal = StyleBoxFlat.new()
	cb_normal.bg_color = Color(0, 0, 0, 0)  # Transparent — label background
	cb_normal.set_content_margin_all(2)
	t.set_stylebox("normal",  "CheckBox", cb_normal)
	t.set_stylebox("hover",   "CheckBox", cb_normal)
	t.set_stylebox("pressed", "CheckBox", cb_normal)
	t.set_color("font_color",         "CheckBox", win_text)
	t.set_color("font_hover_color",   "CheckBox", win_text)
	t.set_color("font_pressed_color", "CheckBox", win_text)

	# ── CheckButton (toggle switch style → VB6 check appearance) ──
	t.set_stylebox("normal",  "CheckButton", cb_normal)
	t.set_stylebox("hover",   "CheckButton", cb_normal)
	t.set_stylebox("pressed", "CheckButton", cb_normal)
	t.set_color("font_color",         "CheckButton", win_text)
	t.set_color("font_hover_color",   "CheckButton", win_text)
	t.set_color("font_pressed_color", "CheckButton", win_text)

	# ── OptionButton (ComboBox) ──
	var ob_normal = _make_raised.call(btn_face)
	ob_normal.content_margin_right = 20  # Room for dropdown arrow
	t.set_stylebox("normal",   "OptionButton", ob_normal)
	t.set_stylebox("hover",    "OptionButton", ob_normal)
	t.set_stylebox("pressed",  "OptionButton", ob_normal)
	t.set_stylebox("disabled", "OptionButton", ob_normal)
	t.set_color("font_color",         "OptionButton", win_text)
	t.set_color("font_hover_color",   "OptionButton", win_text)
	t.set_color("font_pressed_color", "OptionButton", win_text)

	# ── ItemList (ListBox) ──
	var il_sb = _make_sunken.call(win_bg)
	t.set_stylebox("panel", "ItemList", il_sb)
	t.set_color("font_color",          "ItemList", win_text)
	t.set_color("font_selected_color", "ItemList", title_text)

	var il_sel = StyleBoxFlat.new()
	il_sel.bg_color = title_bg
	il_sel.set_content_margin_all(2)
	t.set_stylebox("selected",       "ItemList", il_sel)
	t.set_stylebox("selected_focus", "ItemList", il_sel)

	# ── Tree (TreeView) ──
	var tree_sb = _make_sunken.call(win_bg)
	t.set_stylebox("panel", "Tree", tree_sb)
	t.set_color("font_color",          "Tree", win_text)
	t.set_color("font_selected_color", "Tree", title_text)

	var tree_sel = StyleBoxFlat.new()
	tree_sel.bg_color = title_bg
	tree_sel.set_content_margin_all(2)
	t.set_stylebox("selected",       "Tree", tree_sel)
	t.set_stylebox("selected_focus", "Tree", tree_sel)

	# ── TabContainer ──
	var tc_panel = StyleBoxFlat.new()
	tc_panel.bg_color = btn_face
	tc_panel.border_color = btn_shadow
	tc_panel.set_border_width_all(1)
	tc_panel.set_content_margin_all(4)
	t.set_stylebox("panel", "TabContainer", tc_panel)

	var tab_sel = StyleBoxFlat.new()
	tab_sel.bg_color = btn_face
	tab_sel.border_color = btn_shadow
	tab_sel.border_width_left = 1; tab_sel.border_width_top = 1
	tab_sel.border_width_right = 1; tab_sel.border_width_bottom = 0
	tab_sel.content_margin_left = 8; tab_sel.content_margin_right = 8
	tab_sel.content_margin_top = 4; tab_sel.content_margin_bottom = 4
	t.set_stylebox("tab_selected",   "TabContainer", tab_sel)
	t.set_stylebox("tab_selected",   "TabBar",       tab_sel)

	var tab_unsel = StyleBoxFlat.new()
	tab_unsel.bg_color = Color(0.75, 0.74, 0.72)  # Slightly darker than face
	tab_unsel.border_color = btn_shadow
	tab_unsel.set_border_width_all(1)
	tab_unsel.content_margin_left = 8; tab_unsel.content_margin_right = 8
	tab_unsel.content_margin_top = 4; tab_unsel.content_margin_bottom = 4
	t.set_stylebox("tab_unselected", "TabContainer", tab_unsel)
	t.set_stylebox("tab_unselected", "TabBar",       tab_unsel)

	t.set_color("font_selected_color",   "TabContainer", win_text)
	t.set_color("font_unselected_color", "TabContainer", disabled_text)
	t.set_color("font_selected_color",   "TabBar",       win_text)
	t.set_color("font_unselected_color", "TabBar",       disabled_text)

	# ── ProgressBar ──
	var pb_bg = _make_sunken.call(btn_face)
	t.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = progress_fill
	pb_fill.set_content_margin_all(0)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# ── HScrollBar / VScrollBar ──
	# Make the grabber dark so it is clearly visible against both the light
	# IDE panels and the code editor's cream background.  The default Win98
	# btn_face (0.83) is almost invisible against scrollbar_bg (0.87).
	for sb_type in ["HScrollBar", "VScrollBar"]:
		var scroll_sb = StyleBoxFlat.new()
		scroll_sb.bg_color = scrollbar_bg
		scroll_sb.set_content_margin_all(0)
		t.set_stylebox("scroll", sb_type, scroll_sb)

		var grabber_sb = StyleBoxFlat.new()
		grabber_sb.bg_color = Color(0.45, 0.44, 0.42)   # dark gray grabber
		grabber_sb.border_color = Color(0.30, 0.30, 0.28)
		grabber_sb.set_border_width_all(1)
		grabber_sb.set_corner_radius_all(2)
		grabber_sb.content_margin_left = 2
		grabber_sb.content_margin_right = 2
		grabber_sb.content_margin_top = 2
		grabber_sb.content_margin_bottom = 2
		t.set_stylebox("grabber", sb_type, grabber_sb)

		var grabber_hl_sb = StyleBoxFlat.new()
		grabber_hl_sb.bg_color = Color(0.35, 0.34, 0.32)  # darker on hover
		grabber_hl_sb.border_color = Color(0.20, 0.20, 0.18)
		grabber_hl_sb.set_border_width_all(1)
		grabber_hl_sb.set_corner_radius_all(2)
		grabber_hl_sb.content_margin_left = 2
		grabber_hl_sb.content_margin_right = 2
		grabber_hl_sb.content_margin_top = 2
		grabber_hl_sb.content_margin_bottom = 2
		t.set_stylebox("grabber_highlight", sb_type, grabber_hl_sb)

		var grabber_pr_sb = StyleBoxFlat.new()
		grabber_pr_sb.bg_color = Color(0.25, 0.24, 0.22)  # near-black pressed
		grabber_pr_sb.border_color = Color(0.12, 0.12, 0.10)
		grabber_pr_sb.set_border_width_all(1)
		grabber_pr_sb.set_corner_radius_all(2)
		grabber_pr_sb.content_margin_left = 2
		grabber_pr_sb.content_margin_right = 2
		grabber_pr_sb.content_margin_top = 2
		grabber_pr_sb.content_margin_bottom = 2
		t.set_stylebox("grabber_pressed", sb_type, grabber_pr_sb)

	# Make scrollbars wider so the grabber is easy to click
	t.set_constant("minimum_grab_thickness", "VScrollBar", 12)
	t.set_constant("minimum_grab_thickness", "HScrollBar", 12)

	# ── HSlider / VSlider ──
	for sl_type in ["HSlider", "VSlider"]:
		var slider_sb = StyleBoxFlat.new()
		slider_sb.bg_color = scrollbar_bg
		slider_sb.border_color = btn_shadow
		slider_sb.set_border_width_all(1)
		slider_sb.set_content_margin_all(0)
		t.set_stylebox("slider", sl_type, slider_sb)

		var sl_grabber = _make_raised.call(btn_face)
		t.set_stylebox("grabber_area",            sl_type, sl_grabber)
		t.set_stylebox("grabber_area_highlight",  sl_type, sl_grabber)

	# ── HSeparator / VSeparator ──
	# VB6 separators: etched line (dark on top/left, highlight on bottom/right)
	var hsep_sb = StyleBoxFlat.new()
	hsep_sb.bg_color = Color(0, 0, 0, 0)  # Transparent background
	hsep_sb.border_color = btn_shadow
	hsep_sb.border_width_top = 1
	hsep_sb.border_width_bottom = 0
	hsep_sb.border_width_left = 0
	hsep_sb.border_width_right = 0
	hsep_sb.set_content_margin_all(0)
	hsep_sb.content_margin_top = 2
	hsep_sb.content_margin_bottom = 2
	t.set_stylebox("separator", "HSeparator", hsep_sb)
	t.set_constant("separation", "HSeparator", 4)

	var vsep_sb = StyleBoxFlat.new()
	vsep_sb.bg_color = Color(0, 0, 0, 0)
	vsep_sb.border_color = btn_shadow
	vsep_sb.border_width_left = 1
	vsep_sb.border_width_right = 0
	vsep_sb.border_width_top = 0
	vsep_sb.border_width_bottom = 0
	vsep_sb.set_content_margin_all(0)
	vsep_sb.content_margin_left = 2
	vsep_sb.content_margin_right = 2
	t.set_stylebox("separator", "VSeparator", vsep_sb)
	t.set_constant("separation", "VSeparator", 4)

	# ── MenuBar ──
	var menu_sb = StyleBoxFlat.new()
	menu_sb.bg_color = btn_face
	menu_sb.set_content_margin_all(2)
	t.set_stylebox("normal",  "MenuBar", menu_sb)
	t.set_stylebox("hover",   "MenuBar", menu_sb)
	t.set_stylebox("pressed", "MenuBar", menu_sb)
	t.set_color("font_color",         "MenuBar", win_text)
	t.set_color("font_hover_color",   "MenuBar", win_text)
	t.set_color("font_pressed_color", "MenuBar", win_text)

	# ── PopupMenu ──
	var popup_sb = StyleBoxFlat.new()
	popup_sb.bg_color = btn_face
	popup_sb.border_color = btn_shadow
	popup_sb.set_border_width_all(1)
	popup_sb.set_content_margin_all(2)
	t.set_stylebox("panel",  "PopupMenu", popup_sb)
	t.set_stylebox("hover",  "PopupMenu", StyleBoxFlat.new())
	t.get_stylebox("hover", "PopupMenu").bg_color = title_bg
	t.get_stylebox("hover", "PopupMenu").set_content_margin_all(2)
	t.set_color("font_color",       "PopupMenu", win_text)
	t.set_color("font_hover_color", "PopupMenu", title_text)

	# ── RichTextLabel ──
	var rtl_sb = _make_sunken.call(win_bg)
	t.set_stylebox("normal", "RichTextLabel", rtl_sb)
	t.set_color("default_color",    "RichTextLabel", win_text)
	t.set_color("font_selected_color","RichTextLabel", title_text)
	t.set_color("selection_color",  "RichTextLabel", title_bg)

	# ── SpinBox (uses LineEdit internally) ──
	# SpinBox inherits LineEdit styles, but also needs its own
	t.set_color("font_color", "SpinBox", win_text)

	# ── Tooltip ──
	var tooltip_sb = StyleBoxFlat.new()
	tooltip_sb.bg_color = Color(1.0, 1.0, 0.94)  # Light-yellow
	tooltip_sb.border_color = Color(0.0, 0.0, 0.0)
	tooltip_sb.set_border_width_all(1)
	tooltip_sb.set_content_margin_all(4)
	t.set_stylebox("panel", "TooltipPanel", tooltip_sb)
	t.set_color("font_color", "TooltipLabel", win_text)

	return t

## Builds a VB6-style Theme for popup dialogs created inline (AcceptDialog, etc.).
## This is the same palette used by components_dialog.gd, menu_editor.gd, etc.
func _build_vb6_dialog_theme() -> Theme:
	var t = Theme.new()
	var panel_bg     := Color(0.941, 0.929, 0.910)   # #F0EDE8 cream
	var panel_border := Color(0.72, 0.71, 0.68)
	var header_bg    := Color(0.58, 0.58, 0.62)
	var header_border:= Color(0.4, 0.4, 0.4)
	var text_color   := Color(0.0, 0.0, 0.0)
	var list_bg      := Color(1.0, 1.0, 1.0)
	var btn_hover    := Color(0.95, 0.94, 0.92)
	var btn_pressed  := Color(0.88, 0.87, 0.85)
	var active_title := Color(0.0, 0.0, 0.5)

	# ── Window chrome ──
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = header_bg
	win_sb.border_color = header_border
	win_sb.set_border_width_all(2)
	win_sb.set_content_margin_all(4)
	t.set_stylebox("embedded_border", "Window", win_sb)
	var win_unfocus = win_sb.duplicate()
	win_unfocus.bg_color = Color(0.50, 0.50, 0.50)
	t.set_stylebox("embedded_unfocused_border", "Window", win_unfocus)
	t.set_color("title_color", "Window", Color.WHITE)
	t.set_color("title_outline_modulate", "Window", Color.TRANSPARENT)

	# ── AcceptDialog panel ──
	var dlg_sb = StyleBoxFlat.new()
	dlg_sb.bg_color = panel_bg
	dlg_sb.border_color = panel_border
	dlg_sb.set_border_width_all(1)
	dlg_sb.set_content_margin_all(10)
	t.set_stylebox("panel", "AcceptDialog", dlg_sb)

	# ── Label ──
	t.set_color("font_color", "Label", text_color)

	# ── LineEdit ──
	var le_sb = StyleBoxFlat.new()
	le_sb.bg_color = list_bg
	le_sb.border_color = panel_border
	le_sb.set_border_width_all(1)
	le_sb.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", le_sb)
	t.set_stylebox("focus", "LineEdit", le_sb.duplicate())
	t.set_color("font_color", "LineEdit", text_color)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.5, 0.5))

	# ── OptionButton ──
	var ob_sb = StyleBoxFlat.new()
	ob_sb.bg_color = panel_bg
	ob_sb.border_color = panel_border
	ob_sb.set_border_width_all(1)
	ob_sb.content_margin_left = 6; ob_sb.content_margin_right = 6
	ob_sb.content_margin_top = 3; ob_sb.content_margin_bottom = 3
	t.set_stylebox("normal", "OptionButton", ob_sb)
	var ob_hov = ob_sb.duplicate()
	ob_hov.bg_color = btn_hover
	t.set_stylebox("hover", "OptionButton", ob_hov)
	var ob_pre = ob_sb.duplicate()
	ob_pre.bg_color = btn_pressed
	t.set_stylebox("pressed", "OptionButton", ob_pre)
	t.set_color("font_color", "OptionButton", text_color)
	t.set_color("font_hover_color", "OptionButton", text_color)
	t.set_color("font_pressed_color", "OptionButton", text_color)

	# ── PopupMenu (OptionButton dropdown) ──
	var pm_sb = StyleBoxFlat.new()
	pm_sb.bg_color = list_bg
	pm_sb.border_color = panel_border
	pm_sb.set_border_width_all(1)
	pm_sb.set_content_margin_all(4)
	t.set_stylebox("panel", "PopupMenu", pm_sb)
	t.set_color("font_color", "PopupMenu", text_color)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	var pm_hov = StyleBoxFlat.new()
	pm_hov.bg_color = active_title
	t.set_stylebox("hover", "PopupMenu", pm_hov)

	# ── Button ──
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = panel_bg
	btn_sb.border_color = panel_border
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 8; btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 3; btn_sb.content_margin_bottom = 3
	t.set_stylebox("normal", "Button", btn_sb)
	var bh = btn_sb.duplicate()
	bh.bg_color = btn_hover
	t.set_stylebox("hover", "Button", bh)
	var bp = btn_sb.duplicate()
	bp.bg_color = btn_pressed
	t.set_stylebox("pressed", "Button", bp)
	t.set_color("font_color", "Button", text_color)
	t.set_color("font_hover_color", "Button", text_color)
	t.set_color("font_pressed_color", "Button", text_color)

	# ── HSeparator ──
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = panel_border
	sep_sb.content_margin_top = 4; sep_sb.content_margin_bottom = 4
	t.set_stylebox("separator", "HSeparator", sep_sb)

	return t

## Applies the VB6 Classic Theme to the currently edited scene root.
## This modifies the LIVE in-memory scene tree so Godot's editor preview
## (2D viewport) and runtime (F5) both show the VB6 look.
## Because this sets scene_root.theme directly, Godot's own scene serializer
## will persist it into the .tscn automatically — no disk patching needed.
func _apply_vb6_theme_to_scene_root() -> void:
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	# Only apply to VG forms: root is a Window with a _FormBackground child
	if not (scene_root is Window and scene_root.has_node("_FormBackground")):
		return
	# Avoid re-building if the theme is already applied (check for a marker)
	if scene_root.has_meta("_vb6_scene_theme_applied"):
		return
	scene_root.theme = _build_vb6_scene_theme()
	scene_root.set_meta("_vb6_scene_theme_applied", true)
	print("[VG-THEME] Applied VB6 Classic Theme to scene root: ", scene_root.name)

## Force-applies VB6 theme, ignoring the "already applied" marker.
## Use this after a scene reload (which destroys the old scene root).
func _force_apply_vb6_theme_to_scene_root() -> void:
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	if not (scene_root is Window and scene_root.has_node("_FormBackground")):
		return
	scene_root.theme = _build_vb6_scene_theme()
	scene_root.set_meta("_vb6_scene_theme_applied", true)
	print("[VG-THEME] Force-applied VB6 Classic Theme to scene root: ", scene_root.name)

## Applies VB6 SystemButtonFace gray theme to the embedded IDE panels.
func _apply_vb6_theme() -> void:
	if not is_instance_valid(_ide_layout):
		return

	# Re-apply comprehensive light Theme (belt-and-suspenders with inline apply)
	_ide_layout.theme = _build_vb6_theme()

	var panel_bg = _theme.get("panel_background", Color("#F0EDE8"))
	var panel_border = _theme.get("panel_border", Color(0.72, 0.71, 0.68))

	# Style the left Toolbox panel
	var toolbox_panel = _ide_layout.get_node_or_null("MainHSplit/ToolboxPanel")
	if toolbox_panel and toolbox_panel is PanelContainer:
		var sb = StyleBoxFlat.new()
		sb.bg_color = panel_bg
		sb.border_width_top = 1; sb.border_width_left = 1
		sb.border_width_bottom = 1; sb.border_width_right = 1
		sb.border_color = panel_border
		sb.content_margin_left = 2; sb.content_margin_right = 2
		sb.content_margin_top = 2; sb.content_margin_bottom = 2
		toolbox_panel.add_theme_stylebox_override("panel", sb)

		# Add VB6 header above toolbox content
		var header = _create_vb6_header("Toolbox", false)
		if is_instance_valid(toolbox) and toolbox.get_parent() == toolbox_panel:
			toolbox_panel.remove_child(toolbox)
			var wrapper = VBoxContainer.new()
			wrapper.name = "ToolboxWrapper"
			wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
			wrapper.add_child(header)
			toolbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			wrapper.add_child(toolbox)
			toolbox_panel.add_child(wrapper)

	# Style the right panel area with headers
	var right_area = _ide_layout.get_node_or_null("MainHSplit/CanvasRightSplit/RightPanelSplit")
	if right_area:
		# Wrap Project Explorer with header
		if is_instance_valid(_project_explorer) and _project_explorer.get_parent() == right_area:
			var proj_name = ProjectSettings.get_setting("application/config/name", "Project")
			var pe_header = _create_vb6_header("Project - " + proj_name)
			var pe_wrapper = VBoxContainer.new()
			pe_wrapper.name = "ProjectExplorerWrapper"
			pe_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
			right_area.remove_child(_project_explorer)
			pe_wrapper.add_child(pe_header)
			_project_explorer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			pe_wrapper.add_child(_project_explorer)
			# Add background — matches toolbox panel
			var pe_panel = PanelContainer.new()
			var pe_sb = StyleBoxFlat.new()
			pe_sb.bg_color = panel_bg
			pe_sb.border_width_top = 1; pe_sb.border_width_left = 1
			pe_sb.border_width_bottom = 1; pe_sb.border_width_right = 1
			pe_sb.border_color = panel_border
			pe_panel.add_theme_stylebox_override("panel", pe_sb)
			pe_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			pe_panel.add_child(pe_wrapper)
			right_area.add_child(pe_panel)
			right_area.move_child(pe_panel, 0)

		# Wrap Properties Inspector with header
		if is_instance_valid(_properties_inspector) and _properties_inspector.get_parent() == right_area:
			var pi_header = _create_vb6_header("Properties")
			var pi_wrapper = VBoxContainer.new()
			pi_wrapper.name = "PropertiesWrapper"
			pi_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
			right_area.remove_child(_properties_inspector)
			pi_wrapper.add_child(pi_header)
			_properties_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
			pi_wrapper.add_child(_properties_inspector)
			# Add background — matches toolbox panel
			var pi_panel = PanelContainer.new()
			var pi_sb = StyleBoxFlat.new()
			pi_sb.bg_color = panel_bg
			pi_sb.border_width_top = 1; pi_sb.border_width_left = 1
			pi_sb.border_width_bottom = 1; pi_sb.border_width_right = 1
			pi_sb.border_color = panel_border
			pi_panel.add_theme_stylebox_override("panel", pi_sb)
			pi_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			pi_panel.add_child(pi_wrapper)
			right_area.add_child(pi_panel)

	print("VisualGasic: VB6 theme applied to IDE panels")

## Applies theme colors to the C++ Form Designer canvas.
## Reads from the cached _theme dict (safe fallback to C++ built-in defaults).
func _apply_designer_theme() -> void:
	if not is_instance_valid(_form_designer):
		return
	# Build the designer color dict from _theme — only include keys the C++ side expects
	var designer_keys := [
		"form_background", "grid_dots", "selection_border", "selection_handle",
		"rubber_band", "form_border", "sys_button_face", "sys_button_highlight",
		"sys_button_shadow", "sys_3d_dark_shadow", "sys_3d_light", "sys_window",
		"sys_window_text", "sys_active_title", "sys_title_text", "sys_scrollbar",
		"sys_glyph", "sys_progress_fill", "design_time_outline", "nonvisual_bg",
		"nonvisual_border", "placeholder_color", "mdi_background",
		"form_handle_color", "sys_inactive_title",
	]
	var colors := {}
	for key in designer_keys:
		if _theme.has(key):
			colors[key] = _theme[key]
	if colors.size() > 0:
		_form_designer.set_theme_colors(colors)
		print("VisualGasic: Designer theme applied (%d colors)" % colors.size())

## Restyles the C++ Toolbox buttons to TwinBasic-style list layout.
## Single-column list: [icon] [label text] on white background.
## Icons show their true SVG colors (no Godot editor green tint).
func _restyle_toolbox_buttons() -> void:
	var cpp_toolbox = _get_toolbox_instance()
	if not cpp_toolbox:
		return

	# ── Apply the FULL VB6 theme to the C++ toolbox ──
	# Setting cpp_toolbox.theme creates a new "theme owner" boundary, which
	# BLOCKS inheritance from _ide_layout's theme.  Previously this was a
	# minimal tooltip-only Theme, so TabBar/TabContainer/Label/Button styles
	# fell through to Godot's dark editor theme — making text unreadable.
	# Fix: use the complete VB6 theme and add tooltip overrides on top.
	var toolbox_theme := _build_vb6_theme()
	# Add VB6-style tooltip overrides (light-yellow, black border/text)
	var tooltip_sb := StyleBoxFlat.new()
	tooltip_sb.bg_color = Color(1.0, 1.0, 0.94)   # Classic light-yellow
	tooltip_sb.border_color = Color(0.0, 0.0, 0.0)
	tooltip_sb.set_border_width_all(1)
	tooltip_sb.set_content_margin_all(4)
	toolbox_theme.set_stylebox("panel", "TooltipPanel", tooltip_sb)
	toolbox_theme.set_color("font_color", "TooltipLabel", Color.BLACK)
	cpp_toolbox.theme = toolbox_theme

	# ── CRITICAL: Override C++ VisualGasicToolbox (PanelContainer) panel style ──
	# Without this, Godot's dark editor theme draws over our light background.
	var toolbox_panel_sb := StyleBoxFlat.new()
	toolbox_panel_sb.bg_color = _theme.get("panel_background", Color("#F0EDE8"))
	toolbox_panel_sb.set_content_margin_all(0)
	cpp_toolbox.add_theme_stylebox_override("panel", toolbox_panel_sb)

	# Find the TabContainer inside the C++ toolbox
	var tabs: TabContainer = null
	for c in cpp_toolbox.get_children():
		if c is TabContainer:
			tabs = c
			break
	if not tabs:
		return

	# Style the TabContainer itself for off-white background
	var tab_panel_sb := StyleBoxFlat.new()
	tab_panel_sb.bg_color = _theme.get("panel_background", Color("#F0EDE8"))
	tab_panel_sb.content_margin_left = 2
	tab_panel_sb.content_margin_right = 2
	tab_panel_sb.content_margin_top = 2
	tab_panel_sb.content_margin_bottom = 2
	tabs.add_theme_stylebox_override("panel", tab_panel_sb)

	# Generate VB6-style icons at 20×20 (matching the 20×20 viewBox exactly)
	var vb6_icons: Dictionary = _VB6Icons.create_all(20)

	# TwinBasic-style display names for each tool
	var display_names := {
		"Pointer": "Pointer",
		"Picture": "PictureBox",
		"Label": "Label",
		"TextBox": "TextBox",
		"Button": "CommandButton",
		"CheckBox": "CheckBox",
		"ComboBox": "ComboBox",
		"Frame": "Frame",
		"GroupBox": "GroupBox",
		"ListBox": "ListBox",
		"TreeView": "TreeView",
		"HScroll": "HScrollBar",
		"VScroll": "VScrollBar",
		"ProgressBar": "ProgressBar",
		"HSlider": "HSlider",
		"VSlider": "VSlider",
		"SpinBox": "SpinBox",
		"Shape": "Shape",
		"HLine": "Line",
		"VLine": "Line",
		"RichText": "RichTextBox",
		"TextArea": "TextArea",
		"TabStrip": "TabStrip",
		"Timer": "Timer",
		"Files": "FileDialog",
		# Extended / Components-dialog tools
		"VGComboBox": "VGComboBox",
		"RadioButton": "RadioButton",
		"MenuBar": "MenuBar",
		"PictureButton": "PictureButton",
		"Line": "Line",
		"DriveListBox": "DriveListBox",
		"FlexGrid": "FlexGrid",
		"Form": "Form",
		"Option": "Option",
		"CommonDialog": "CommonDialog",
		"ColorBtn": "ColorBtn",
		"Video": "Video",
		"Viewport": "Viewport",
	}

	# Map button node names → VB6 icon dict keys (where they differ)
	var icon_key_map := {
		"DriveListBox": "DriveList",
	}

	# Brief tooltip descriptions for each tool (shown on hover)
	var tool_tips := {
		# ── Built-in 2D tools (C++ defaults) ──
		"Pointer": "Select and move controls on the form",
		"Picture": "Display an image or texture",
		"Label": "Static text that the user cannot edit",
		"TextBox": "Single-line text input field",
		"Button": "Clickable button that triggers an action",
		"CheckBox": "Toggle option on or off",
		"ComboBox": "Drop-down list of choices",
		"Frame": "Container panel to group controls",
		"GroupBox": "Bordered panel with a title for grouping",
		"ListBox": "Scrollable list of selectable items",
		"TreeView": "Hierarchical tree of expandable items",
		"HScroll": "Horizontal scroll bar",
		"VScroll": "Vertical scroll bar",
		"ProgressBar": "Shows completion progress of a task",
		"HSlider": "Horizontal slider for picking a value",
		"VSlider": "Vertical slider for picking a value",
		"SpinBox": "Numeric input with up/down arrows",
		"Shape": "Filled rectangle (ColorRect)",
		"HLine": "Horizontal separator line",
		"VLine": "Vertical separator line",
		"RichText": "Formatted text with BBCode support",
		"TextArea": "Multi-line text editing area",
		"TabStrip": "Tabbed container with multiple pages",
		"Timer": "Fires an event at a set interval",
		"Files": "Open/save file dialog",
		# ── Extended 2D tools ──
		"VGComboBox": "Enhanced combo box control",
		"RadioButton": "Mutually exclusive option in a group",
		"MenuBar": "Top-level menu bar with drop-down menus",
		"PictureButton": "Button that displays an image",
		"Line": "Straight line between two points",
		"DriveListBox": "Lists available disk drives",
		"FlexGrid": "Resizable grid of rows and columns",
		"Form": "Top-level window or dialog",
		"Option": "Option button (radio style)",
		"CommonDialog": "Standard system dialog (color, font, etc.)",
		"ColorBtn": "Button that opens a color picker",
		"Video": "Plays video or animation files",
		"Viewport": "Embedded rendering viewport",
		# ── Components dialog extras ──
		"StatusBar": "Status bar panel at bottom of a form",
		"Toolbar": "Toolbar panel with action buttons",
		"Animation": "Animated sprite with frame sequences",
		"Calendar": "Month calendar date selector",
		"DatePicker": "Pick a date from a pop-up calendar",
		"MaskedEdit": "Text input with an input mask format",
		"Winsock": "HTTP / network request component",
		"UpDown": "Numeric spinner (up/down buttons)",
		"ListView": "Multi-column list with icons",
		"ImageCombo": "Drop-down list with icon items",
		# ── 3D tools ──
		"Box": "3D box mesh primitive",
		"Sphere": "3D sphere mesh primitive",
		"Capsule": "3D capsule mesh primitive",
		"Cylinder": "3D cylinder mesh primitive",
		"Light": "Omni-directional 3D light source",
		"Camera": "3D camera viewpoint",
		"Text3D": "3D text label in world space",
		"Sprite3D": "2D sprite rendered in 3D space",
		"Sound3D": "Positional 3D audio player",
	}

	# Load user-defined descriptions from custom_components.cfg
	var _comp_descriptions := {}
	var ComponentsDialog = load("res://addons/visual_gasic/components_dialog.gd")
	if ComponentsDialog:
		var all_enabled = ComponentsDialog.load_enabled_components()
		for comp in all_enabled:
			var desc: String = comp.get("description", "")
			if not desc.is_empty():
				_comp_descriptions[comp["name"]] = desc

	var white := Color(1, 1, 1, 1)
	var btn_bg: Color = _theme.get("toolbox_btn_normal", Color("#F0EDE8"))
	var hover_bg: Color = _theme.get("toolbox_btn_hover", Color(0.91, 0.95, 1.0))
	var pressed_bg: Color = _theme.get("toolbox_btn_pressed", Color(0.26, 0.59, 0.98))

	# Style each tab's grid as a 2-column icon+text list (scrollable via parent)
	for tab_idx in range(tabs.get_tab_count()):
		var grid = tabs.get_child(tab_idx)
		if grid is GridContainer:
			grid.set_columns(2)  # 2 columns to fit more tools
			grid.add_theme_constant_override("h_separation", 2)
			grid.add_theme_constant_override("v_separation", 1)

			for btn_idx in range(grid.get_child_count()):
				var btn = grid.get_child(btn_idx)
				if btn is Button:
					var tool_name: String = btn.name

					# Show icon + text label (like TwinBasic toolbox)
					btn.text = display_names.get(tool_name, tool_name)
					# Tooltip priority: user description > built-in tips > auto-generated
					if _comp_descriptions.has(tool_name):
						btn.tooltip_text = _comp_descriptions[tool_name]
					elif tool_tips.has(tool_name):
						btn.tooltip_text = tool_tips[tool_name]
					elif btn.has_method("get_create_class") and not btn.get_create_class().is_empty():
						btn.tooltip_text = "Custom control (%s)" % btn.get_create_class()
					else:
						btn.tooltip_text = tool_name
					btn.custom_minimum_size = Vector2(0, 26)
					btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
					btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
					btn.expand_icon = false

					# ── Apply ALL theme overrides FIRST ──
					# Each add_theme_*_override triggers NOTIFICATION_THEME_CHANGED
					# in the C++ button, so we must finish these before setting
					# the SVG icon (which we want to be the final icon value).

					# Override icon colors to prevent green editor tint
					btn.add_theme_color_override("icon_normal_color", white)
					btn.add_theme_color_override("icon_hover_color", white)
					btn.add_theme_color_override("icon_pressed_color", white)
					btn.add_theme_color_override("icon_focus_color", white)
					btn.add_theme_color_override("icon_disabled_color", white)

					# Black text labels on white background
					btn.add_theme_color_override("font_color", _theme.get("toolbox_text", Color.BLACK))
					btn.add_theme_color_override("font_hover_color", _theme.get("toolbox_text", Color.BLACK))
					btn.add_theme_color_override("font_pressed_color", _theme.get("toolbox_text_pressed", Color.WHITE))
					btn.add_theme_color_override("font_focus_color", _theme.get("toolbox_text", Color.BLACK))

					# ── Normal: off-white, no border ──
					var normal_sb := StyleBoxFlat.new()
					normal_sb.bg_color = btn_bg
					normal_sb.content_margin_left = 6
					normal_sb.content_margin_right = 4
					normal_sb.content_margin_top = 2
					normal_sb.content_margin_bottom = 2
					btn.add_theme_stylebox_override("normal", normal_sb)

					# ── Hover: light blue tint ──
					var hover_sb := StyleBoxFlat.new()
					hover_sb.bg_color = hover_bg
					hover_sb.border_width_top = 1
					hover_sb.border_width_left = 1
					hover_sb.border_width_bottom = 1
					hover_sb.border_width_right = 1
					hover_sb.border_color = _theme.get("toolbox_btn_hover_border", Color(0.55, 0.73, 0.95))
					hover_sb.content_margin_left = 5
					hover_sb.content_margin_right = 3
					hover_sb.content_margin_top = 1
					hover_sb.content_margin_bottom = 1
					btn.add_theme_stylebox_override("hover", hover_sb)

					# ── Pressed / selected tool: blue highlight ──
					var pressed_sb := StyleBoxFlat.new()
					pressed_sb.bg_color = pressed_bg
					pressed_sb.content_margin_left = 6
					pressed_sb.content_margin_right = 4
					pressed_sb.content_margin_top = 2
					pressed_sb.content_margin_bottom = 2
					btn.add_theme_stylebox_override("pressed", pressed_sb)

					# ── LAST: Apply custom SVG icon AFTER all theme overrides ──
					# This ensures no NOTIFICATION_THEME_CHANGED can overwrite
					# the icon after we set it.
					var icon_key: String = icon_key_map.get(tool_name, tool_name)
					if vb6_icons.has(icon_key):
						btn.icon = vb6_icons[icon_key]
					elif vb6_icons.has("_CustomControl"):
						btn.icon = vb6_icons["_CustomControl"]
					# Clear C++ icon_name so any future theme propagation skips
					if btn.has_method("set_icon_name"):
						btn.set_icon_name("")

	print("VisualGasic: Toolbox restyled to TwinBasic list layout (%d icons)" % vb6_icons.size())

# =============================================================================
# VB6 MENU BAR — File/Edit/View/Project/Format/Debug/Run/Tools/Window/Help
# =============================================================================

## Creates a VB6-style menu bar with all classic menus.
func _create_vb6_menu_bar() -> MenuBar:
	var mb = MenuBar.new()
	mb.name = "VB6MenuBar"
	mb.flat = true

	# Style the menu bar background
	var mb_sb = StyleBoxFlat.new()
	mb_sb.bg_color = _theme.get("panel_background", Color("#F0EDE8"))
	mb_sb.content_margin_left = 4
	mb_sb.content_margin_right = 4
	mb_sb.content_margin_top = 1
	mb_sb.content_margin_bottom = 1
	mb.add_theme_stylebox_override("panel", mb_sb)

	# ── File ──
	var file_menu = PopupMenu.new()
	file_menu.name = "File"
	_style_popup_menu(file_menu)
	file_menu.add_item("New Form", 0)
	file_menu.add_item("New Module", 1)
	file_menu.add_item("New Project...", 3)
	file_menu.add_separator()
	file_menu.add_item("Open Project...", 2)
	file_menu.add_separator()
	file_menu.add_item("Save Form", 10)
	file_menu.set_item_shortcut(file_menu.get_item_index(10), _make_shortcut(KEY_S, true))
	file_menu.add_item("Save Form As...", 11)
	file_menu.add_item("Save All", 12)
	var save_all_ev = InputEventKey.new()
	save_all_ev.keycode = KEY_S
	save_all_ev.ctrl_pressed = true
	save_all_ev.shift_pressed = true
	var save_all_sc = Shortcut.new()
	save_all_sc.events = [save_all_ev]
	file_menu.set_item_shortcut(file_menu.get_item_index(12), save_all_sc)
	file_menu.add_separator()
	file_menu.add_item("Import VB6 Form...", 20)
	file_menu.add_item("Import VB6 Project...", 21)
	file_menu.add_separator()
	file_menu.add_item("Make EXE...", 30)
	file_menu.add_separator()
	file_menu.add_item("Exit to VG Welcome", 98)
	file_menu.add_item("Exit to Godot Editor", 99)
	file_menu.id_pressed.connect(_on_vb6_file_menu)
	mb.add_child(file_menu)

	# ── Edit ──
	var edit_menu = PopupMenu.new()
	edit_menu.name = "Edit"
	_style_popup_menu(edit_menu)
	edit_menu.add_item("Undo", 0)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(0), _make_shortcut(KEY_Z, true))
	edit_menu.add_item("Redo", 1)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(1), _make_shortcut(KEY_Y, true))
	edit_menu.add_separator()
	edit_menu.add_item("Cut", 10)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(10), _make_shortcut(KEY_X, true))
	edit_menu.add_item("Copy", 11)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(11), _make_shortcut(KEY_C, true))
	edit_menu.add_item("Paste", 12)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(12), _make_shortcut(KEY_V, true))
	edit_menu.add_item("Delete", 13)
	edit_menu.add_separator()
	edit_menu.add_item("Select All", 20)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(20), _make_shortcut(KEY_A, true))
	edit_menu.add_separator()
	edit_menu.add_item("Find...", 30)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(30), _make_shortcut(KEY_F, true))
	edit_menu.add_item("Replace...", 31)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(31), _make_shortcut(KEY_H, true))
	edit_menu.add_separator()
	edit_menu.add_item("Comment Block", 32)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(32), _make_shortcut(KEY_APOSTROPHE, true))
	edit_menu.add_item("Uncomment Block", 33)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(33), _make_shortcut(KEY_APOSTROPHE, true, true))
	edit_menu.add_separator()
	edit_menu.add_item("Indent", 40)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(40), _make_shortcut(KEY_BRACKETRIGHT, true))
	edit_menu.add_item("Outdent", 41)
	edit_menu.set_item_shortcut(edit_menu.get_item_index(41), _make_shortcut(KEY_BRACKETLEFT, true))
	edit_menu.add_separator()
	# Bookmarks submenu
	var bookmarks_menu = PopupMenu.new()
	bookmarks_menu.name = "Bookmarks"
	_style_popup_menu(bookmarks_menu)
	bookmarks_menu.add_item("Toggle Bookmark", 50)
	bookmarks_menu.set_item_shortcut(bookmarks_menu.get_item_index(50), _make_shortcut(KEY_F2, true))
	bookmarks_menu.add_item("Next Bookmark", 51)
	bookmarks_menu.set_item_shortcut(bookmarks_menu.get_item_index(51), _make_shortcut(KEY_F2))
	bookmarks_menu.add_item("Previous Bookmark", 52)
	bookmarks_menu.set_item_shortcut(bookmarks_menu.get_item_index(52), _make_shortcut(KEY_F2, false, true))
	bookmarks_menu.add_separator()
	bookmarks_menu.add_item("Clear All Bookmarks", 53)
	bookmarks_menu.id_pressed.connect(_on_vb6_edit_menu)
	edit_menu.add_child(bookmarks_menu)
	edit_menu.add_submenu_item("Bookmarks", "Bookmarks")
	edit_menu.id_pressed.connect(_on_vb6_edit_menu)
	mb.add_child(edit_menu)

	# ── View ──
	var view_menu = PopupMenu.new()
	view_menu.name = "View"
	_style_popup_menu(view_menu)
	view_menu.add_item("Code", 0)
	view_menu.set_item_shortcut(view_menu.get_item_index(0), _make_shortcut(KEY_F7))
	view_menu.add_item("Object", 1)
	view_menu.set_item_shortcut(view_menu.get_item_index(1), _make_shortcut(KEY_F7, false))  # Shift+F7 handled via embedded editor
	view_menu.add_separator()
	view_menu.add_item("Toolbox", 10)
	view_menu.add_item("Project Explorer", 11)
	view_menu.add_item("Properties Window", 12)
	view_menu.add_item("Immediate Window", 13)
	view_menu.add_separator()
	view_menu.add_item("3D Scene Editor", 20)
	view_menu.add_item("2D Scene Editor", 21)
	view_menu.add_item("Sprite Editor", 22)
	view_menu.add_separator()
	view_menu.add_item("Plugins...", 30)
	view_menu.id_pressed.connect(_on_vb6_view_menu)
	mb.add_child(view_menu)

	# ── Project ──
	var project_menu = PopupMenu.new()
	project_menu.name = "Project"
	_style_popup_menu(project_menu)
	project_menu.add_item("Add Form...", 0)
	project_menu.add_item("Add Module...", 1)
	project_menu.add_separator()
	project_menu.add_item("Project Properties...", 10)
	project_menu.add_item("Components...", 11)
	project_menu.id_pressed.connect(_on_vb6_project_menu)
	# Hide form-designer-only items (Add Form, Add Module, Components)
	# when the Form Designer is disabled. Re-evaluated each time the
	# menu opens so the toggle takes effect without reloading the IDE.
	project_menu.about_to_popup.connect(_refresh_vb6_project_menu.bind(project_menu))
	mb.add_child(project_menu)

	# ── Format ──
	var format_menu = PopupMenu.new()
	format_menu.name = "Format"
	_style_popup_menu(format_menu)
	format_menu.add_item("Align Lefts", 0)
	format_menu.add_item("Align Rights", 1)
	format_menu.add_item("Align Tops", 2)
	format_menu.add_item("Align Bottoms", 3)
	format_menu.add_separator()
	format_menu.add_item("Center Horizontally", 10)
	format_menu.add_item("Center Vertically", 11)
	format_menu.add_separator()
	format_menu.add_item("Make Same Width", 20)
	format_menu.add_item("Make Same Height", 21)
	format_menu.add_item("Make Same Size", 22)
	format_menu.add_separator()
	format_menu.add_item("Space Equally Horizontal", 50)
	format_menu.add_item("Space Equally Vertical", 51)
	format_menu.add_item("Size to Grid", 52)
	format_menu.add_item("Center in Form Horizontal", 53)
	format_menu.add_item("Center in Form Vertical", 54)
	format_menu.add_separator()
	format_menu.add_item("Bring to Front", 30)
	format_menu.add_item("Send to Back", 31)
	format_menu.add_separator()
	format_menu.add_item("Lock Controls", 40)
	format_menu.id_pressed.connect(_on_vb6_format_menu)
	mb.add_child(format_menu)

	# ── Debug ──
	var debug_menu = PopupMenu.new()
	debug_menu.name = "Debug"
	_style_popup_menu(debug_menu)
	debug_menu.add_item("Run Project", 0)
	debug_menu.set_item_shortcut(debug_menu.get_item_index(0), _make_shortcut(KEY_F5))
	debug_menu.add_item("Run Current Scene", 1)
	debug_menu.set_item_shortcut(debug_menu.get_item_index(1), _make_shortcut(KEY_F6))
	debug_menu.add_separator()
	debug_menu.add_item("Break", 2)
	debug_menu.set_item_shortcut(debug_menu.get_item_index(2), _make_shortcut(KEY_PAUSE))
	debug_menu.add_item("Stop", 10)
	debug_menu.id_pressed.connect(_on_vb6_debug_menu)
	mb.add_child(debug_menu)

	# ── Run ──
	var run_menu = PopupMenu.new()
	run_menu.name = "Run"
	_style_popup_menu(run_menu)
	run_menu.add_item("Preview Form", 0)
	run_menu.add_item("Preview + Debug", 1)
	run_menu.add_separator()
	run_menu.add_item("Build Project", 10)
	run_menu.add_item("Run Project", 11)
	run_menu.id_pressed.connect(_on_vb6_run_menu)
	mb.add_child(run_menu)

	# ── Tools ──
	var tools_menu = PopupMenu.new()
	tools_menu.name = "Tools"
	_style_popup_menu(tools_menu)
	tools_menu.add_item("Menu Editor...", 0)
	tools_menu.add_item("Tab Order...", 1)
	tools_menu.add_item("Object Browser...", 2)
	tools_menu.add_separator()
	tools_menu.add_item("New Custom Control...", 20)
	tools_menu.add_item("Edit Custom Control...", 21)
	tools_menu.add_separator()
	tools_menu.add_item("Snippet Browser...", 10)
	tools_menu.add_item("Theme Picker...", 11)
	tools_menu.add_separator()
	tools_menu.add_item("Generate Documentation...", 12)
	tools_menu.add_separator()
	tools_menu.add_item("Input Map Editor...", 30)
	tools_menu.add_item("Animation Editor...", 31)
	tools_menu.add_separator()
	tools_menu.add_item("Hex Editor...", 40)
	tools_menu.id_pressed.connect(_on_vb6_tools_menu)
	mb.add_child(tools_menu)

	# ── Window ──
	var window_menu = PopupMenu.new()
	window_menu.name = "Window"
	_style_popup_menu(window_menu)
	window_menu.add_item("Tile Horizontally", 0)
	window_menu.add_item("Tile Vertically", 1)
	window_menu.add_separator()
	window_menu.add_item("Toggle VG IDE Layout", 10)
	window_menu.id_pressed.connect(_on_vb6_window_menu)
	mb.add_child(window_menu)

	# ── Help ──
	var help_menu = PopupMenu.new()
	help_menu.name = "Help"
	_style_popup_menu(help_menu)
	help_menu.add_item("Visual Gasic Documentation", 0)
	help_menu.add_item("About Visual Gasic...", 1)
	help_menu.add_separator()
	help_menu.add_item("Tip of the Day...", 2)
	help_menu.id_pressed.connect(_on_vb6_help_menu)
	mb.add_child(help_menu)

	return mb

## Creates a Shortcut for use in menu items.
func _make_shortcut(key: Key, ctrl: bool = false, shift: bool = false) -> Shortcut:
	var ev = InputEventKey.new()
	ev.keycode = key
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	var sc = Shortcut.new()
	sc.events = [ev]
	return sc

## Applies VB6/Win95-style contrast styling to a PopupMenu and its sub-menus.
func _style_popup_menu(popup: PopupMenu) -> void:
	if not popup:
		return
	_apply_vb6_popup_theme(popup)
	# Recursively style existing child sub-menus
	for c in popup.get_children():
		if c is PopupMenu:
			_apply_vb6_popup_theme(c)
	# Catch lazily-created sub-menus on first popup show
	if not popup.has_meta("_vg_popup_styled"):
		popup.set_meta("_vg_popup_styled", true)
		popup.about_to_popup.connect(func():
			for c2 in popup.get_children():
				if c2 is PopupMenu:
					_apply_vb6_popup_theme(c2)
		)

func _apply_vb6_popup_theme(popup: PopupMenu) -> void:
	# Light background panel — matches Project Explorer right-click menu
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.96, 0.95, 0.93)
	panel_sb.border_width_top = 1
	panel_sb.border_width_bottom = 1
	panel_sb.border_width_left = 1
	panel_sb.border_width_right = 1
	panel_sb.border_color = Color(0.55, 0.54, 0.52)
	panel_sb.content_margin_left = 4
	panel_sb.content_margin_right = 4
	panel_sb.content_margin_top = 4
	panel_sb.content_margin_bottom = 4
	popup.add_theme_stylebox_override("panel", panel_sb)

	# Hover / selection highlight — blue, matching Project Explorer context menu
	var hover_sb = StyleBoxFlat.new()
	hover_sb.bg_color = Color(0.0, 0.47, 0.84)
	hover_sb.corner_radius_top_left = 2
	hover_sb.corner_radius_top_right = 2
	hover_sb.corner_radius_bottom_left = 2
	hover_sb.corner_radius_bottom_right = 2
	popup.add_theme_stylebox_override("hover", hover_sb)

	# Separator style
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = Color(0.55, 0.54, 0.52)
	sep_sb.content_margin_top = 0
	sep_sb.content_margin_bottom = 0
	popup.add_theme_stylebox_override("separator", sep_sb)

	# Font colors — matching Project Explorer context menu
	popup.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	popup.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	popup.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	popup.add_theme_color_override("font_separator_color", Color(0.4, 0.4, 0.4))
	popup.add_theme_color_override("font_accelerator_color", Color(0.4, 0.4, 0.4))

# ── VB6 Menu Bar Handlers ──

func _on_vb6_file_menu(id: int) -> void:
	match id:
		0: _on_add_form()
		1: _on_new_module()
		2: _on_open_project()
		3: _on_new_project()
		10: _do_save_form()
		11: _do_save_form_as()
		12: _do_save_all()
		20: _on_import_vb6_form()
		21: _on_import_vb6_project()
		30: _on_make_exe()
		98: _on_exit_to_welcome()
		99: _on_back_to_godot_pressed()

## Save all open forms and code files.
func _do_save_all() -> void:
	_do_save_form()
	if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("save_file"):
		_embedded_code_editor.save_file()
		# Also save bookmarks for the current file
		_save_bookmarks_for_current_file()
	_form_dirty = false
	_update_dirty_indicator()
	_flash_status_message("All files saved")

## Save the current form. If no path is set, falls through to Save As.
func _do_save_form() -> void:
	if not _form_designer:
		return
	var path = _form_designer.get_form_path()
	if path.is_empty():
		# No path yet — behave like Save As, auto-generating a default name
		var form_name = _form_designer.get_form_name() if _form_designer.has_method("get_form_name") else "Form1"
		var default_path = "res://" + form_name + ".tscn"
		print("[VisualGasic] Save Form: no path set — saving to ", default_path)
		_form_designer.save_form_as(default_path)
	else:
		_form_designer.save_form()
	var saved_path = _form_designer.get_form_path()
	print("[VisualGasic] Form saved: ", saved_path)
	_form_dirty = false
	_track_recent_form(saved_path)
	_update_dirty_indicator()
	# Notify Godot's filesystem so it doesn't treat this as external change
	if not saved_path.is_empty():
		EditorInterface.get_resource_filesystem().update_file(saved_path)
	# Patch Godot's in-memory scene tree so its scene saver won't overwrite
	# our .tscn with stale values when the editor closes.
	_sync_form_state_to_scene_tree()
	# CRITICAL: Reload the scene in Godot's editor so its in-memory scene tree
	# matches what we just wrote to disk.  Without this, Godot overwrites our
	# .tscn with its stale scene tree version when the editor closes.
	_reload_scene_after_form_save(saved_path)

## Show a FileDialog so the user can choose where to save the form .tscn.
func _do_save_form_as() -> void:
	if not _form_designer:
		return
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.add_filter("*.tscn ; Godot Scene")
	fd.title = "Save Form As..."
	fd.min_size = Vector2i(600, 400)
	# Pre-fill with current path or a default
	var current_path = _form_designer.get_form_path()
	if not current_path.is_empty():
		fd.current_path = current_path
	else:
		var form_name = _form_designer.get_form_name() if _form_designer.has_method("get_form_name") else "Form1"
		fd.current_file = form_name + ".tscn"
		fd.current_dir = "res://"
	fd.file_selected.connect(func(path: String):
		_form_designer.save_form_as(path)
		print("[VisualGasic] Form saved as: ", path)
		EditorInterface.get_resource_filesystem().update_file(path)
		_sync_form_state_to_scene_tree()
		_reload_scene_after_form_save(path)
		fd.queue_free()
	)
	fd.canceled.connect(fd.queue_free)
	get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered()

## Show a FileDialog so the user can open an existing form (.tscn) in the
## Form Designer.  This is the File > Open Project handler.
func _on_open_project() -> void:
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.add_filter("*.tscn ; Godot Scene")
	fd.title = "Open Project..."
	fd.min_size = Vector2i(600, 400)
	fd.current_dir = "res://"
	fd.file_selected.connect(func(path: String):
		open_form_in_designer(path)
		fd.queue_free()
	)
	fd.canceled.connect(fd.queue_free)
	get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered()

# =============================================================================
# NEW PROJECT DIALOG
# =============================================================================

## File > New Project...  —  creates a brand-new Godot project with VG
## pre-installed, then opens it in a new Godot instance.
func _on_new_project() -> void:
	var dlg = AcceptDialog.new()
	dlg.title = "New VisualGasic Project"
	dlg.ok_button_text = "Create"
	dlg.min_size = Vector2i(500, 260)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# ── Project Name ──
	var name_label = Label.new()
	name_label.text = "Project Name:"
	vbox.add_child(name_label)

	var name_edit = LineEdit.new()
	name_edit.text = "MyGame"
	name_edit.placeholder_text = "MyGame"
	name_edit.select_all_on_focus = true
	name_edit.caret_blink = true
	vbox.add_child(name_edit)

	# ── Location ──
	var loc_label = Label.new()
	loc_label.text = "Location:"
	vbox.add_child(loc_label)

	var loc_hbox = HBoxContainer.new()
	loc_hbox.add_theme_constant_override("separation", 4)

	var loc_edit = LineEdit.new()
	loc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Default to user's home/Documents or home directory
	var default_dir = OS.get_environment("HOME")
	var docs_dir = default_dir + "/Documents"
	if DirAccess.dir_exists_absolute(docs_dir):
		default_dir = docs_dir
	loc_edit.text = default_dir
	loc_edit.caret_blink = true
	loc_hbox.add_child(loc_edit)

	var browse_btn = Button.new()
	browse_btn.text = "Browse..."
	browse_btn.pressed.connect(func():
		var fd2 = FileDialog.new()
		fd2.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		fd2.access = FileDialog.ACCESS_FILESYSTEM
		fd2.title = "Select Project Location"
		fd2.min_size = Vector2i(600, 400)
		fd2.current_dir = loc_edit.text
		fd2.dir_selected.connect(func(path: String):
			loc_edit.text = path
			fd2.queue_free()
		)
		fd2.canceled.connect(fd2.queue_free)
		get_editor_interface().get_base_control().add_child(fd2)
		fd2.popup_centered()
	)
	loc_hbox.add_child(browse_btn)
	vbox.add_child(loc_hbox)

	# ── Full path preview ──
	var preview_label = Label.new()
	preview_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	preview_label.text = loc_edit.text + "/" + name_edit.text
	vbox.add_child(preview_label)

	# Update preview as user types
	var update_preview = func():
		preview_label.text = loc_edit.text.path_join(name_edit.text)
	name_edit.text_changed.connect(func(_t): update_preview.call())
	loc_edit.text_changed.connect(func(_t): update_preview.call())

	# ── Info label ──
	var info = Label.new()
	info.text = "Creates a new Godot project with VG pre-installed and enabled."
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(info)

	dlg.add_child(vbox)

	# ── Create handler ──
	dlg.confirmed.connect(func():
		var proj_name = name_edit.text.strip_edges()
		var proj_dir = loc_edit.text.strip_edges().path_join(proj_name)

		# Validate
		if proj_name.is_empty():
			push_warning("[VisualGasic] New Project: name cannot be empty")
			_flash_status_message("Project name cannot be empty")
			return
		if DirAccess.dir_exists_absolute(proj_dir):
			push_warning("[VisualGasic] New Project: directory already exists: " + proj_dir)
			_flash_status_message("Directory already exists: " + proj_dir)
			return

		_create_new_vg_project(proj_name, proj_dir)
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)

	# Allow Enter to confirm from the name field
	name_edit.text_submitted.connect(func(_t): dlg.confirmed.emit())

	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()
	name_edit.grab_focus()
	name_edit.select_all()


## Creates a new VG-ready Godot project on disk and opens it.
func _create_new_vg_project(proj_name: String, proj_dir: String) -> void:
	# ── Create directory structure ──
	var da = DirAccess.open("res://")
	var err = DirAccess.make_dir_recursive_absolute(proj_dir)
	if err != OK:
		push_error("[VisualGasic] Failed to create project directory: " + proj_dir + " (error " + str(err) + ")")
		_flash_status_message("Failed to create directory")
		return

	err = DirAccess.make_dir_recursive_absolute(proj_dir + "/addons")
	if err != OK:
		push_error("[VisualGasic] Failed to create addons directory")
		_flash_status_message("Failed to create addons directory")
		return

	# ── Copy addon ──
	# Prefer the canonical addon shipped with the VG install, so a brand-new
	# project never inherits a stale copy from whichever project happened to
	# be open. Fall back to res://addons/visual_gasic (the running project's
	# own copy) only if no canonical install can be located.
	var src_addon: String = _resolve_canonical_addon_dir()
	if src_addon.is_empty():
		src_addon = ProjectSettings.globalize_path("res://addons/visual_gasic")
		print("[VisualGasic] New project: using local addon copy at ", src_addon)
	else:
		print("[VisualGasic] New project: copying canonical addon from ", src_addon)
	var dst_addon: String = proj_dir + "/addons/visual_gasic"

	err = _copy_dir_recursive(src_addon, dst_addon)
	if err != OK:
		push_error("[VisualGasic] Failed to copy addon: " + str(err))
		_flash_status_message("Failed to copy addon files")
		return

	# ── Create project.godot ──
	var display_name = proj_name.replace("_", " ").replace("-", " ")
	var project_godot = ""
	project_godot += "; Engine configuration file.\n"
	project_godot += "; It's best edited using the editor UI and not directly,\n"
	project_godot += "; since the parameters that go here are not all obvious.\n"
	project_godot += ";\n"
	project_godot += "; Format:\n"
	project_godot += ";   [section] ; section goes between []\n"
	project_godot += ";   param=value ; assign values to parameters\n\n"
	project_godot += "config_version=5\n\n"
	project_godot += "[application]\n\n"
	project_godot += "config/name=\"%s\"\n" % display_name
	project_godot += "config/features=PackedStringArray(\"4.6\", \"Forward Plus\")\n"
	project_godot += "config/icon=\"res://icon.svg\"\n\n"
	project_godot += "[audio]\n\n"
	project_godot += "driver/enable_input=true\n\n"
	project_godot += "[autoload]\n\n"
	project_godot += "VGDebugHandler=\"*res://addons/visual_gasic/vg_debug_handler.gd\"\n\n"
	project_godot += "[editor_plugins]\n\n"
	project_godot += "enabled=PackedStringArray(\"res://addons/visual_gasic/plugin.cfg\")\n"

	var f = FileAccess.open(proj_dir + "/project.godot", FileAccess.WRITE)
	if f:
		f.store_string(project_godot)
		f.close()
	else:
		push_error("[VisualGasic] Failed to create project.godot")
		return

	# ── Create starter Form1.vg ──
	var form_code = "' Form1.vg — Your first VisualGasic form\n"
	form_code += "' Double-click this file in the Godot editor to open the Form Designer\n\n"
	form_code += "Option Explicit\n\n"
	form_code += "Private Sub Form_Load()\n"
	form_code += "    Me.Caption = \"Hello World\"\n"
	form_code += "    Me.Width = 800\n"
	form_code += "    Me.Height = 600\n"
	form_code += "    Print \"Welcome to VisualGasic!\"\n"
	form_code += "End Sub\n\n"
	form_code += "Private Sub Form_Click()\n"
	form_code += "    Print \"You clicked the form!\"\n"
	form_code += "End Sub\n"

	f = FileAccess.open(proj_dir + "/Form1.vg", FileAccess.WRITE)
	if f:
		f.store_string(form_code)
		f.close()

	# ── Copy icon ──
	var icon_src = ProjectSettings.globalize_path("res://addons/visual_gasic/icon.svg")
	if FileAccess.file_exists(icon_src):
		_copy_file(icon_src, proj_dir + "/icon.svg")
	elif FileAccess.file_exists(ProjectSettings.globalize_path("res://icon.svg")):
		_copy_file(ProjectSettings.globalize_path("res://icon.svg"), proj_dir + "/icon.svg")

	# ── Create .gitignore ──
	f = FileAccess.open(proj_dir + "/.gitignore", FileAccess.WRITE)
	if f:
		f.store_string("# Godot\n.godot/\n*.import\nexport_presets.cfg\n\n# OS\n.DS_Store\nThumbs.db\n")
		f.close()

	# ── Copy AI keys (vg_ai_keys.cfg) into the new project's user:// dir ──
	# Godot resolves user:// per-project from config/name; we mirror the
	# host-OS path conventions Godot uses internally.
	_copy_ai_keys_to_new_project(display_name)

	print("[VisualGasic] New project created at: " + proj_dir)
	_flash_status_message("Project created: " + proj_name)

	# ── Open the new project in a new Godot instance ──
	var godot_path = OS.get_executable_path()
	var args = ["--path", proj_dir, "--editor"]
	print("[VisualGasic] Launching: " + godot_path + " " + " ".join(args))
	OS.create_process(godot_path, args)

	_flash_status_message("Opened " + proj_name + " in new Godot window")


## Recursively copy a directory from src to dst (absolute paths).
## Resolve the canonical, up-to-date `addons/visual_gasic/` source dir.
## Used when creating new projects so they don't inherit a stale addon
## from whatever project happened to be open. We try, in order:
##   1. $VG_ADDON_SOURCE  (explicit override)
##   2. <repo>/addons/visual_gasic   where <repo> is the dir containing
##      the welcome_shell sibling — i.e. a source-tree checkout
##   3. /opt/visual_gasic/addons/visual_gasic
##   4. ~/.local/share/visual_gasic/addons/visual_gasic
## Returns "" if nothing newer than the running project's copy is found.
func _resolve_canonical_addon_dir() -> String:
	var candidates: Array[String] = []
	var override: String = OS.get_environment("VG_ADDON_SOURCE")
	if not override.is_empty():
		candidates.append(override)
	var here: String = ProjectSettings.globalize_path("res://").rstrip("/")
	if not here.is_empty():
		# Source-tree layout: <repo>/welcome_shell + <repo>/addons/visual_gasic
		var parent: String = here.get_base_dir()
		if FileAccess.file_exists(parent + "/welcome_shell/project.godot"):
			candidates.append(parent + "/addons/visual_gasic")
		var grand: String = parent.get_base_dir()
		if FileAccess.file_exists(grand + "/welcome_shell/project.godot"):
			candidates.append(grand + "/addons/visual_gasic")
	candidates.append("/opt/visual_gasic/addons/visual_gasic")
	var home: String = OS.get_environment("HOME")
	if not home.is_empty():
		candidates.append(home + "/.local/share/visual_gasic/addons/visual_gasic")
	for c in candidates:
		if c.is_empty():
			continue
		if FileAccess.file_exists(c + "/plugin.cfg"):
			return c
	return ""


func _copy_dir_recursive(src: String, dst: String) -> Error:
	var err = DirAccess.make_dir_recursive_absolute(dst)
	if err != OK:
		return err

	var dir = DirAccess.open(src)
	if not dir:
		return ERR_CANT_OPEN

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var src_path = src + "/" + entry
		var dst_path = dst + "/" + entry
		if dir.current_is_dir():
			err = _copy_dir_recursive(src_path, dst_path)
			if err != OK:
				dir.list_dir_end()
				return err
		else:
			# Skip .uid files — they get regenerated per-project
			if entry.ends_with(".uid"):
				entry = dir.get_next()
				continue
			err = DirAccess.copy_absolute(src_path, dst_path)
			if err != OK:
				push_warning("[VisualGasic] Failed to copy: " + src_path + " -> " + dst_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return OK


## Copy a single file (absolute paths).
func _copy_file(src: String, dst: String) -> Error:
	return DirAccess.copy_absolute(src, dst)


## Path to the cross-project recent-projects ini used by the `vg-ide`
## launcher to skip Godot's Project Manager.
func _vg_recent_projects_path() -> String:
	match OS.get_name():
		"Windows", "UWP":
			var appdata := OS.get_environment("APPDATA")
			if appdata.is_empty():
				return ""
			return appdata + "/VisualGasic/recent_projects.cfg"
		"macOS":
			var home_mac := OS.get_environment("HOME")
			if home_mac.is_empty():
				return ""
			return home_mac + "/Library/Application Support/VisualGasic/recent_projects.cfg"
		_:  # Linux / *BSD
			var xdg := OS.get_environment("XDG_CONFIG_HOME")
			if xdg.is_empty():
				var home := OS.get_environment("HOME")
				if home.is_empty():
					return ""
				xdg = home + "/.config"
			return xdg + "/visual_gasic/recent_projects.cfg"


## Append the current project to the cross-project recent list (or move
## it to the front if already present).  No-op if the project is the
## bundled "welcome shell" or path resolution fails.
func _record_recent_vg_project() -> void:
	var path: String = ProjectSettings.globalize_path("res://")
	if path.is_empty():
		return
	if path.ends_with("/"):
		path = path.substr(0, path.length() - 1)
	# Skip the bundled welcome shell — it's not a "real" user project.
	if path.ends_with("/welcome_shell"):
		return
	var name: String = ProjectSettings.get_setting("application/config/name", "")
	if typeof(name) != TYPE_STRING:
		name = ""
	if name.is_empty():
		name = path.get_file()

	var ini: String = _vg_recent_projects_path()
	if ini.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ini.get_base_dir())

	var cfg := ConfigFile.new()
	cfg.load(ini)  # ok if missing
	var recent: Array = cfg.get_value("recent", "projects", [])
	if typeof(recent) != TYPE_ARRAY:
		recent = []
	# Move-to-front semantics, dedup on path.
	var pruned: Array = [{"path": path, "name": name, "ts": int(Time.get_unix_time_from_system())}]
	for entry in recent:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("path", "")) == path:
			continue
		pruned.append(entry)
	# Cap at 16 entries to keep the welcome window snappy.
	if pruned.size() > 16:
		pruned.resize(16)
	cfg.set_value("recent", "projects", pruned)
	cfg.save(ini)


## Path to the welcome-shell handoff marker. Welcome shell creates this
## just before forking Godot; the spawned IDE deletes it from its
## `_enter_tree` so the shell knows when to drop its loading splash.
func _vg_launching_flag_path() -> String:
	var recent := _vg_recent_projects_path()
	if recent.is_empty():
		return ""
	return recent.get_base_dir() + "/launching.flag"


func _clear_vg_launching_flag() -> void:
	var p := _vg_launching_flag_path()
	if p.is_empty() or not FileAccess.file_exists(p):
		return
	DirAccess.remove_absolute(p)
	# Make sure we're foregrounded once the welcome shell drops its
	# fullscreen cover splash — otherwise some window managers leave
	# focus on the (now-quitting) welcome window for a beat.
	DisplayServer.window_move_to_foreground()
## describing what the user wants Narcea to build, prefill the AI panel's
## prompt input with it and surface a status message. The seed file is
## renamed to `.narcea_seed.consumed` so this fires only once.
func _consume_narcea_seed_if_present() -> void:
	var seed_path := "res://narcea_seed.txt"
	if not FileAccess.file_exists(seed_path):
		return
	var f := FileAccess.open(seed_path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	if text.strip_edges().is_empty():
		return
	# Hand the text to the AI panel's input field if it's available, else
	# defer once more on the next idle frame to allow it to construct.
	var panel: Object = null
	if "_ai_panel" in self:
		panel = get("_ai_panel")
	if panel != null and is_instance_valid(panel) and "_input" in panel:
		var input_field: Object = panel.get("_input")
		if is_instance_valid(input_field) and input_field.has_method("set"):
			input_field.set("text", text)
			print("[VisualGasic] Narcea seed loaded into AI panel (%d chars)." % text.length())
			_flash_status_message("🌿 Narcea seed loaded — open AI panel to review")
	else:
		# AI panel not built yet — try again in 500ms.
		var t := get_tree().create_timer(0.5)
		t.timeout.connect(_consume_narcea_seed_if_present, CONNECT_ONE_SHOT)
		return
	# Move aside so we don't re-consume on subsequent opens.
	var consumed := "res://.narcea_seed.consumed"
	DirAccess.rename_absolute(ProjectSettings.globalize_path(seed_path), ProjectSettings.globalize_path(consumed))


## Compute the absolute path to Godot's `app_userdata/<project>/` directory
## for an arbitrary project name, mirroring Godot's own conventions per OS.
func _godot_user_data_dir_for(project_display_name: String) -> String:
	var name := project_display_name.strip_edges()
	if name.is_empty():
		return ""
	match OS.get_name():
		"Windows", "UWP":
			var appdata := OS.get_environment("APPDATA")
			if appdata.is_empty():
				return ""
			return appdata + "/Godot/app_userdata/" + name
		"macOS":
			var home_mac := OS.get_environment("HOME")
			if home_mac.is_empty():
				return ""
			return home_mac + "/Library/Application Support/Godot/app_userdata/" + name
		_:  # Linux / *BSD
			var xdg := OS.get_environment("XDG_DATA_HOME")
			if xdg.is_empty():
				var home := OS.get_environment("HOME")
				if home.is_empty():
					return ""
				xdg = home + "/.local/share"
			return xdg + "/godot/app_userdata/" + name


## Copy this project's vg_ai_keys.cfg into the brand-new project's
## user:// dir so the user doesn't have to re-paste API keys.  No-op
## when the source has no keys yet.
func _copy_ai_keys_to_new_project(new_project_display_name: String) -> void:
	var src_keys: String = OS.get_user_data_dir() + "/vg_ai_keys.cfg"
	if not FileAccess.file_exists(src_keys):
		return
	var dst_dir: String = _godot_user_data_dir_for(new_project_display_name)
	if dst_dir.is_empty():
		push_warning("[VisualGasic] Could not resolve user-data dir for '%s' — AI keys not copied" % new_project_display_name)
		return
	var mk_err: int = DirAccess.make_dir_recursive_absolute(dst_dir)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		push_warning("[VisualGasic] Could not create '%s' (err %d) — AI keys not copied" % [dst_dir, mk_err])
		return
	var dst_keys: String = dst_dir + "/vg_ai_keys.cfg"
	var cp_err: int = DirAccess.copy_absolute(src_keys, dst_keys)
	if cp_err != OK:
		push_warning("[VisualGasic] Failed to copy AI keys to %s (err %d)" % [dst_keys, cp_err])
		return
	# Tighten perms on POSIX (best-effort; chmod isn't exposed via DirAccess
	# so we shell out only if available).
	if OS.get_name() in ["Linux", "FreeBSD", "macOS"]:
		var rc: int = OS.execute("chmod", ["600", dst_keys])
		if rc != 0:
			pass  # Non-fatal — file is still copied.
	print("[VisualGasic] Copied AI keys to: " + dst_keys)


## Handle renaming a form: rename .tscn, .vg, .vg.uid files on disk,
## update form_path in C++, close old scene tab, and reload from new path.
## Called by simple_inspector.gd when the user edits the form (Name)/Caption.
func handle_form_rename(old_name: String, new_name: String) -> bool:
	if not is_instance_valid(_form_designer):
		push_warning("[VisualGasic] handle_form_rename: no FormDesigner")
		return false
	var old_path: String = _form_designer.get_form_path()
	if old_path.is_empty():
		# No file on disk yet — nothing to rename; just let the name change happen
		return true
	var dir_prefix: String = old_path.get_base_dir()
	if not dir_prefix.ends_with("/"):
		dir_prefix += "/"
	var new_tscn: String = dir_prefix + new_name + ".tscn"
	var old_vg: String = old_path.get_basename() + ".vg"
	var new_vg: String = dir_prefix + new_name + ".vg"
	var old_uid: String = old_vg + ".uid"
	var new_uid: String = new_vg + ".uid"

	# Prevent overwriting an existing different form
	if old_path != new_tscn and FileAccess.file_exists(new_tscn):
		push_warning("[VisualGasic] Cannot rename — '", new_tscn, "' already exists")
		return false

	print("[VisualGasic] Renaming form: ", old_path, " → ", new_tscn)
	var da := DirAccess.open(dir_prefix)
	if not da:
		push_warning("[VisualGasic] Cannot access directory: ", dir_prefix)
		return false

	# Close the old scene in the editor before renaming
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root and scene_root.scene_file_path == old_path:
		# We'll reopen at the new path after rename
		pass

	# Rename .vg first (so the .tscn can reference it)
	if FileAccess.file_exists(old_vg) and old_vg != new_vg:
		var err = da.rename(old_vg, new_vg)
		if err != OK:
			push_warning("[VisualGasic] Failed to rename .vg: ", old_vg, " → ", new_vg, " (error ", err, ")")
	# Rename .vg.uid
	if FileAccess.file_exists(old_uid) and old_uid != new_uid:
		da.rename(old_uid, new_uid)

	# Tell Godot's filesystem to rescan so the UID cache picks up the renamed .vg
	EditorInterface.get_resource_filesystem().scan()

	# Now save the form to the NEW .tscn path (this updates form_path in C++,
	# writes the new .tscn with correct VG script reference + UID, and creates
	# the .vg file if it doesn't exist yet).
	_form_designer.set_form_name(new_name)
	_form_designer.save_form_as(new_tscn)
	_strip_empty_menubar_from_tscn(new_tscn)

	# Safety: ensure the .tscn has the VG script UID.  The C++ serializer uses
	# ResourceLoader.get_resource_uid() which may miss newly-renamed files.
	# If the .uid file exists, patch the .tscn so Godot can always resolve it.
	_ensure_tscn_script_uid(new_tscn, new_vg, new_uid)

	# Remove the old .tscn if it's different from the new one
	if old_path != new_tscn and FileAccess.file_exists(old_path):
		da.remove(old_path)
		print("[VisualGasic] Removed old .tscn: ", old_path)
	# Remove the old .vg if still lingering (save_form_as may have recreated it)
	if old_vg != new_vg and FileAccess.file_exists(old_vg):
		da.remove(old_vg)

	# Tell Godot's editor to close the old scene tab and open the new one
	if scene_root and scene_root.scene_file_path == old_path:
		# Reload will fail on old path, so open the new file instead
		EditorInterface.open_scene_from_path(new_tscn)
	elif FileAccess.file_exists(new_tscn):
		EditorInterface.open_scene_from_path(new_tscn)

	# Re-sync the form designer from the new path
	_form_designer.open_form(new_tscn)
	_fixup_form_size_from_tscn(new_tscn)

	# Update the editor layout config so next restart opens the right file
	var config = get_editor_interface().get_editor_settings()
	# Also update our plugin-level cached path
	print("[VisualGasic] Form renamed successfully: ", old_name, " → ", new_name, " (", new_tscn, ")")
	return true

## Ensure the .tscn file's first ext_resource (the VG script) has a uid="..." attribute.
## The C++ serializer uses ResourceLoader.get_resource_uid() which may return -1 for
## freshly-renamed files.  We read the UID from the .uid sidecar and patch the .tscn.
func _ensure_tscn_script_uid(tscn_path: String, vg_path: String, uid_path: String) -> void:
	if not FileAccess.file_exists(uid_path):
		return  # No .uid file — nothing we can do
	var uid_text: String = FileAccess.get_file_as_string(uid_path).strip_edges()
	if uid_text.is_empty() or not uid_text.begins_with("uid://"):
		return

	if not FileAccess.file_exists(tscn_path):
		return
	var tscn_text: String = FileAccess.get_file_as_string(tscn_path)
	# Check if the first ext_resource already has a uid
	# Pattern: [ext_resource type="Script" path="res://Foo.vg" id="1"]  (no uid)
	var vg_basename: String = vg_path.get_file()
	var needle: String = 'type="Script" path="' + vg_path + '" id="1"'
	var needle_with_uid: String = 'uid="' + uid_text + '" path="' + vg_path + '"'
	if needle_with_uid in tscn_text:
		return  # Already has the correct UID

	# Missing UID — patch it in
	var patched: String = tscn_text.replace(needle, 'type="Script" uid="' + uid_text + '" path="' + vg_path + '" id="1"')
	if patched != tscn_text:
		var f = FileAccess.open(tscn_path, FileAccess.WRITE)
		if f:
			f.store_string(patched)
			f = null  # close
			print("[VisualGasic] Patched UID into .tscn: ", uid_text)

## Strip the auto-generated empty MenuBar from a .tscn file on disk.
## The old C++ _serialize_to_tscn() unconditionally adds a MainMenu MenuBar
## with empty mnuFile/mnuEdit PopupMenus to every form.  This function reads
## the .tscn, detects those nodes, removes them (and the menu_bar_helper.gd
## ext_resource if it's only used for that), and writes the file back.
## This is a COMPATIBILITY FIX — once the user restarts Godot with the new
## .so, this function will be a harmless no-op because the C++ code no longer
## emits MenuBar for blank forms.
static func _strip_empty_menubar_from_tscn(tscn_path: String) -> void:
	var fa = FileAccess.open(tscn_path, FileAccess.READ)
	if not fa:
		return
	var text = fa.get_as_text()
	fa = null
	
	# Quick check: if there's no MainMenu node, nothing to do
	if text.find("[node name=\"MainMenu\"") < 0:
		return
	
	# Check if there are any real menu items (populated PopupMenus)
	# A PopupMenu child of MainMenu is any node with parent="MainMenu"
	# We only strip if ALL such children have zero content (no properties beyond the header)
	var has_menu_items := false
	var lines = text.split("\n")
	var in_menu_child := false
	for line in lines:
		var stripped = line.strip_edges()
		# Detect any PopupMenu node that is a child of MainMenu
		if stripped.begins_with("[node ") and "parent=\"MainMenu\"" in stripped and "type=\"PopupMenu\"" in stripped:
			in_menu_child = true
			continue
		if in_menu_child and stripped.begins_with("["):
			in_menu_child = false  # hit next node section
		if in_menu_child and not stripped.is_empty() and not stripped.begins_with("["):
			# PopupMenu has actual properties = user added items
			has_menu_items = true
			break
	
	if has_menu_items:
		return  # Real menu content, keep it
	
	# Strip the MainMenu and ALL its child nodes, plus the menu_bar_helper ext_resource
	var result_lines: PackedStringArray = []
	var menu_helper_id := ""
	var skip_until_next_node := false
	
	for line in lines:
		var stripped = line.strip_edges()
		
		# Detect and remove menu_bar_helper.gd ext_resource
		if stripped.begins_with("[ext_resource") and "menu_bar_helper.gd" in stripped:
			# Extract the id for later reference
			var id_pos = stripped.find("id=\"")
			if id_pos >= 0:
				var id_start = id_pos + 4
				var id_end = stripped.find("\"", id_start)
				if id_end >= 0:
					menu_helper_id = stripped.substr(id_start, id_end - id_start)
			continue  # Skip this line
		
		# Skip MainMenu node block
		if stripped.begins_with("[node name=\"MainMenu\""):
			skip_until_next_node = true
			continue
		# Skip any child node of MainMenu (PopupMenu children)
		if stripped.begins_with("[node ") and "parent=\"MainMenu\"" in stripped:
			skip_until_next_node = true
			continue
		
		if skip_until_next_node:
			if stripped.begins_with("[node ") or stripped.begins_with("[connection "):
				# Check if THIS node is also a MainMenu child before stopping skip
				if "parent=\"MainMenu\"" in stripped:
					continue  # Still a MainMenu child, keep skipping
				skip_until_next_node = false
				result_lines.append(line)
			# else skip this line (part of the menu node block)
			continue
		
		result_lines.append(line)
	
	var new_text = "\n".join(result_lines)
	
	# Fix load_steps count (we removed 1 ext_resource)
	if not menu_helper_id.is_empty():
		var re_steps = RegEx.new()
		re_steps.compile("load_steps=(\\d+)")
		var m = re_steps.search(new_text)
		if m:
			var old_count = m.get_string(1).to_int()
			new_text = new_text.replace("load_steps=" + m.get_string(1), "load_steps=" + str(old_count - 1))
	
	var fw = FileAccess.open(tscn_path, FileAccess.WRITE)
	if fw:
		fw.store_string(new_text)
		fw = null
		print("[VG-SYNC] Stripped empty MenuBar from '", tscn_path, "'")

## After the C++ Form Designer writes a .tscn, force Godot to reload it.
## This ensures Godot's in-memory scene tree matches our save, preventing
## Godot from overwriting our .tscn with its stale version on editor close.
func _reload_scene_after_form_save(tscn_path: String) -> void:
	# Strip empty MenuBars that the old C++ serializer may have added
	_strip_empty_menubar_from_tscn(tscn_path)
	print("[VG-SYNC] _reload_scene_after_form_save('", tscn_path, "')")
	if tscn_path.is_empty():
		return
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	# Only reload if this is the currently edited scene
	print("[VG-SYNC]   scene_root.path='", scene_root.scene_file_path, "'  match=", scene_root.scene_file_path == tscn_path)
	if scene_root.scene_file_path != tscn_path:
		return
	# Godot's reload_scene_from_path() silently bails out when
	# EditorNode::is_changing_scene() is true (see editor_interface.cpp).
	# During _make_visible(false) Godot IS mid-scene-change, so both
	# direct calls and call_deferred() run too early.  Use a short
	# SceneTreeTimer so the transition completes before we reload.
	print("[VG-SYNC]   -> scheduling timer reload (0.3s)")
	get_tree().create_timer(0.3).timeout.connect(_force_godot_scene_reload.bind(tscn_path))

func _deferred_reload_scene(tscn_path: String) -> void:
	# Legacy entry point (kept for compatibility).
	_force_godot_scene_reload(tscn_path)

## Deferred helper: opens a form .tscn as a Godot scene tab.
## Used by _set_window_layout() during session restore to ensure the form
## is available for in-memory tree patching by _sync_form_state_to_scene_tree().
func _deferred_open_scene_tab(tscn_path: String) -> void:
	if FileAccess.file_exists(tscn_path):
		if not tscn_path in EditorInterface.get_open_scenes():
			EditorInterface.open_scene_from_path(tscn_path)
			print("[VG-SYNC] Deferred open scene tab: ", tscn_path)

## GDScript safety net: reads the root Window's size from a .tscn text file
## and applies it to the C++ FormDesigner.  This works around a C++ parser bug
## where _parse_tscn() skipped root-node properties (in_node was set false
## before property lines were reached).  The C++ is now fixed, but this
## remains as belt-and-suspenders.
func _fixup_form_size_from_tscn(tscn_path: String) -> void:
	if not is_instance_valid(_form_designer):
		return
	if not FileAccess.file_exists(tscn_path):
		return
	var f = FileAccess.open(tscn_path, FileAccess.READ)
	if not f:
		return
	var in_root_node := false
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line.begins_with("[node "):
			# Root node has no parent= attribute
			if not "parent=" in line:
				in_root_node = true
			else:
				if in_root_node:
					break  # Left root node section
				in_root_node = false
		elif in_root_node and line.begins_with("size = Vector2i("):
			# Parse: size = Vector2i(424, 352)
			var paren_start = line.find("(")
			var paren_end = line.find(")")
			if paren_start >= 0 and paren_end > paren_start:
				var inner = line.substr(paren_start + 1, paren_end - paren_start - 1)
				var parts = inner.split(",")
				if parts.size() >= 2:
					var sz = Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
					var current = _form_designer.get_form_size()
					if current != sz:
						_form_designer.set_form_size(sz)
						print("[VG-SYNC] _fixup_form_size_from_tscn: patched form_size ", current, " → ", sz)
					break
		elif in_root_node and line.begins_with("["):
			break  # Next section
	f.close()

## Forces Godot to re-read a .tscn from disk and update its open scene tab.
## The C++ Form Designer writes .tscn files via FileAccess which bypasses
## Godot’s ResourceLoader cache.  A plain reload_scene_from_path() would
## just re-instantiate the stale cached PackedScene.  We must:
##   1. Tell EditorFileSystem the file changed  (update_file)
##   2. Evict the stale PackedScene from the resource cache  (CACHE_MODE_REPLACE)
##   3. Then reload the scene tab  (reload_scene_from_path)
func _force_godot_scene_reload(tscn_path: String) -> void:
	print("[VG-SYNC] _force_godot_scene_reload('", tscn_path, "')")
	# Strip empty MenuBars the old C++ serializer may have injected
	_strip_empty_menubar_from_tscn(tscn_path)
	EditorInterface.get_resource_filesystem().update_file(tscn_path)
	# Evict the stale cached PackedScene — forces ResourceLoader to
	# re-read the file from disk on the next load.
	if ResourceLoader.exists(tscn_path):
		ResourceLoader.load(tscn_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	EditorInterface.reload_scene_from_path(tscn_path)
	print("[VG-SYNC]   reload_scene_from_path returned")
	var _sr2 = EditorInterface.get_edited_scene_root()
	if _sr2:
		print("[VG-SYNC]   scene now has ", _sr2.get_child_count(), " children  path='", _sr2.scene_file_path, "'")
		for _ci in _sr2.get_child_count():
			print("[VG-SYNC]     child[", _ci, "] = ", _sr2.get_child(_ci).name, " (", _sr2.get_child(_ci).get_class(), ")")
	# Apply VB6 Classic Theme to the freshly-reloaded scene root.
	# The reload destroys the old tree and recreates from disk, so any
	# previously-applied theme is lost.  Force-apply unconditionally.
	_force_apply_vb6_theme_to_scene_root()

## Patches Godot's in-memory scene tree to match the C++ FormDesigner state.
## This is CRITICAL because Godot's own scene saver writes the in-memory tree
## to disk when the editor closes.  If the tree is stale (e.g. because
## reload_scene_from_path() silently failed during a save cycle), Godot
## overwrites our correct .tscn with old values.
##
## By directly setting Window.size, _FormBackground offsets, and each child
## control's offsets, we guarantee the in-memory tree always matches C++.
func _sync_form_state_to_scene_tree() -> void:
	if not is_instance_valid(_form_designer):
		return
	var fp = _form_designer.get_form_path()
	if fp.is_empty():
		return
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	if scene_root.scene_file_path != fp:
		# The form is not the active scene tab — we can only patch the active
		# tab's tree.  Changes are safe in C++ memory and will be written on
		# the next explicit save.
		return

	# ── Sync form size ──
	var fd_size: Vector2i = _form_designer.get_form_size()
	if scene_root is Window:
		if scene_root.size != fd_size:
			scene_root.size = fd_size
			print("[VG-SYNC] Patched Window.size → ", fd_size)
	# Also patch the _FormBackground Panel offsets (only if changed)
	var bg = scene_root.get_node_or_null("_FormBackground")
	if bg:
		var new_right := float(fd_size.x)
		var new_bottom := float(fd_size.y)
		if not is_equal_approx(bg.offset_right, new_right) or not is_equal_approx(bg.offset_bottom, new_bottom):
			bg.offset_right = new_right
			bg.offset_bottom = new_bottom

	# ── Ensure root Control anchors are explicit (prevents null serialization) ──
	# When Godot's ResourceSaver writes the scene, uninitialized anchor/offset
	# properties serialize as "null" in .tscn, which resets floats to 0 and
	# breaks full-rect layouts.  Explicitly setting them prevents this.
	if scene_root is Control and not scene_root is Window:
		if scene_root.anchors_preset == Control.PRESET_FULL_RECT or \
		   (is_equal_approx(scene_root.anchor_right, 1.0) and is_equal_approx(scene_root.anchor_bottom, 1.0)):
			scene_root.anchor_left = 0.0
			scene_root.anchor_top = 0.0
			scene_root.anchor_right = 1.0
			scene_root.anchor_bottom = 1.0
			scene_root.offset_left = 0.0
			scene_root.offset_top = 0.0
			scene_root.offset_right = 0.0
			scene_root.offset_bottom = 0.0

	# ── Sync each child control's position + size (only if changed) ──
	var ctrl_count = _form_designer.get_control_count()
	for i in ctrl_count:
		var info: Dictionary = _form_designer.get_control_info(i)
		var ctrl_name: String = info.get("name", "")
		if ctrl_name.is_empty():
			continue
		var child = scene_root.get_node_or_null(ctrl_name)
		if not child or not child is Control:
			continue
		var r: Rect2 = info.get("rect", Rect2())
		var new_left   := r.position.x
		var new_top    := r.position.y
		var new_right  := r.position.x + r.size.x
		var new_bottom := r.position.y + r.size.y
		if not is_equal_approx(child.offset_left, new_left) or \
		   not is_equal_approx(child.offset_top, new_top) or \
		   not is_equal_approx(child.offset_right, new_right) or \
		   not is_equal_approx(child.offset_bottom, new_bottom):
			child.offset_left   = new_left
			child.offset_top    = new_top
			child.offset_right  = new_right
			child.offset_bottom = new_bottom
		# Sync text/caption (only if changed)
		var text_val = info.get("text", "")
		if child.has_method("set_text") and not text_val.is_empty():
			if child.get("text") != text_val:
				child.set("text", text_val)

func _on_vb6_edit_menu(id: int) -> void:
	# Code editor actions (Find, Replace, Comment, Bookmarks, Indent)
	if id >= 30:
		var ce: CodeEdit = _get_active_code_edit()
		if not ce:
			return
		match id:
			30: # Find
				_show_find_replace_bar(false)
			31: # Replace
				_show_find_replace_bar(true)
			32: # Comment Block
				_comment_selected_lines(ce)
			33: # Uncomment Block
				_uncomment_selected_lines(ce)
			40: # Indent
				_indent_selected_lines(ce)
			41: # Outdent
				_outdent_selected_lines(ce)
			50: # Toggle Bookmark
				_toggle_bookmark(ce)
			51: # Next Bookmark
				_goto_next_bookmark(ce)
			52: # Previous Bookmark
				_goto_prev_bookmark(ce)
			53: # Clear All Bookmarks
				_clear_all_bookmarks(ce)
		return
	# Form Designer actions
	if not _form_designer:
		return
	match id:
		0:
			_form_designer.undo()
			_flash_status_message("Undo")
		1:
			_form_designer.redo()
			_flash_status_message("Redo")
		10: _form_designer.cut()
		11: _form_designer.copy()
		12: _form_designer.paste()
		13: _form_designer.remove_selected()
		20: _form_designer.select_all()

func _on_vb6_view_menu(id: int) -> void:
	match id:
		0: # Code view — open embedded code editor (VB6 style)
			_on_view_code()
		1: # Object view — switch back to Form Designer canvas
			_on_view_object()
		10: pass # Toolbox — already visible
		11: pass # Project Explorer — already visible
		12: pass # Properties — already visible
		13: # Immediate Window — switch to code view and focus Immediate tab
			if is_instance_valid(_embedded_code_editor):
				if not _embedded_code_editor.visible:
					_on_view_code()
				if _embedded_code_editor.has_method("focus_immediate"):
					_embedded_code_editor.focus_immediate()
		20: # 3D Scene Editor
			_on_3d_view_pressed()
		21: # 2D Scene Editor
			_on_2d_view_pressed()
		22: # Sprite Editor
			_on_sprite_view_pressed()
		30: # Plugins — activate AGCK (or first available plugin)
			if _vg_plugin_manager:
				var ids = _vg_plugin_manager.get_plugin_ids()
				if ids.size() > 0:
					_vg_plugin_manager.activate_plugin(ids[0])
				else:
					_flash_status_message("No plugins installed. Add plugins to addons/visual_gasic/plugins/")

func _on_vb6_project_menu(id: int) -> void:
	match id:
		0: _on_add_form()
		1: _on_new_module()
		10: _on_proj_props()
		11: _on_components()


## Re-evaluates the Project menu just before it opens, disabling items
## that only make sense when the Form Designer is enabled (Add Form,
## Add Module, Components). Project Properties is always available.
## Greying out (rather than hiding) keeps the menu layout stable and
## hints at the toggle without surprising users.
func _refresh_vb6_project_menu(project_menu: PopupMenu) -> void:
	if not is_instance_valid(project_menu):
		return
	var enabled := true
	if ProjectSettings.has_setting("vg/form_designer_enabled"):
		enabled = bool(ProjectSettings.get_setting("vg/form_designer_enabled", true))
	# IDs assigned in _build_vb6_menubar above.
	for item_id in [0, 1, 11]:
		var idx := project_menu.get_item_index(item_id)
		if idx >= 0:
			project_menu.set_item_disabled(idx, not enabled)

func _on_vb6_format_menu(id: int) -> void:
	if not _form_designer:
		return
	match id:
		0: _form_designer.align_left()
		1: _form_designer.align_right()
		2: _form_designer.align_top()
		3: _form_designer.align_bottom()
		10: _form_designer.align_center_h()
		11: _form_designer.align_center_v()
		20: _form_designer.make_same_width()
		21: _form_designer.make_same_height()
		22:
			_form_designer.make_same_width()
			_form_designer.make_same_height()
		30: # Bring to Front
			if _form_designer.has_method("bring_to_front"):
				_form_designer.bring_to_front()
		31: # Send to Back
			if _form_designer.has_method("send_to_back"):
				_form_designer.send_to_back()
		40: # Lock Controls toggle
			_flash_status_message("Use right-click → Lock Position on individual controls")
		50: # Space Equally Horizontal
			_format_space_equally_h()
		51: # Space Equally Vertical
			_format_space_equally_v()
		52: # Size to Grid
			_format_size_to_grid()
		53: # Center in Form Horizontal
			_format_center_in_form_h()
		54: # Center in Form Vertical
			_format_center_in_form_v()

func _on_vb6_debug_menu(id: int) -> void:
	match id:
		0:
			_log_output("▶ Running main scene...", Color(0.0, 0.4, 0.0))
			# Flush code buffer to disk so running game uses latest edits.
			if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("flush_for_run"):
				_embedded_code_editor.flush_for_run()
			EditorInterface.play_main_scene()
			if is_instance_valid(immediate_window) and immediate_window.has_method("set_debug_active"):
				immediate_window.set_debug_active(true, false)
		1:
			_log_output("▶ Running current scene...", Color(0.0, 0.4, 0.0))
			if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("flush_for_run"):
				_embedded_code_editor.flush_for_run()
			EditorInterface.play_current_scene()
			if is_instance_valid(immediate_window) and immediate_window.has_method("set_debug_active"):
				immediate_window.set_debug_active(true, false)
		2:
			# VB6-style Break — pause at next statement
			_log_output("⏸ Break requested...", Color(0.8, 0.6, 0.0))
			if is_instance_valid(debugger_plugin) and debugger_plugin.has_method("debug_break"):
				debugger_plugin.debug_break()
		10:
			_log_output("■ Stopped.", Color(0.5, 0.0, 0.0))
			EditorInterface.stop_playing_scene()
			if is_instance_valid(immediate_window) and immediate_window.has_method("set_debug_active"):
				immediate_window.set_debug_active(false, false)

func _on_vb6_run_menu(id: int) -> void:
	match id:
		0: # Preview Form
			_log_output("▶ Preview Form...", Color(0.0, 0.3, 0.5))
			if is_instance_valid(form_preview_toolbar) and form_preview_toolbar.has_method("_on_preview"):
				form_preview_toolbar._on_preview()
		1: # Preview + Debug
			_log_output("▶ Preview + Debug...", Color(0.0, 0.3, 0.5))
			if is_instance_valid(form_preview_toolbar) and form_preview_toolbar.has_method("_on_preview_debug"):
				form_preview_toolbar._on_preview_debug()
		10: # Build
			_do_save_form()
			if is_instance_valid(form_preview_toolbar) and form_preview_toolbar.has_method("_on_build_pressed"):
				form_preview_toolbar._on_build_pressed()
		11:
			# Save form to disk before running so the game sees latest changes
			_do_save_form()
			# Flush code buffer to disk so running game uses latest edits,
			# but keep dirty flag so editor still shows "unsaved" until Ctrl+S.
			if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.has_method("flush_for_run"):
				_embedded_code_editor.flush_for_run()
			_log_output("▶ Run Project...", Color(0.0, 0.4, 0.0))
			EditorInterface.play_main_scene()
			if is_instance_valid(immediate_window) and immediate_window.has_method("set_debug_active"):
				immediate_window.set_debug_active(true, false)

func _on_vb6_tools_menu(id: int) -> void:
	match id:
		0: _on_menu_editor()
		1: _on_tab_order()
		2: _on_obj_browser()
		10: _on_open_snippet_browser()
		11: _on_open_theme_picker()
		12: _on_generate_docs()
		20: _on_new_custom_control()
		21: _on_edit_custom_control()
		30: _on_open_input_map_editor()
		31: _on_open_animation_editor()
		40: _on_hex_editor_menu()

func _on_vb6_window_menu(id: int) -> void:
	match id:
		10: _on_toggle_vb6_layout()

func _on_vb6_help_menu(id: int) -> void:
	match id:
		0: OS.shell_open("https://github.com/nickshouse/VisualGasic")
		1: pass # About dialog
		2: _show_tip_of_day()

# =============================================================================
# INPUT MAP EDITOR
# =============================================================================
func _on_open_input_map_editor() -> void:
	var InputMapEditor = load("res://addons/visual_gasic/vg_input_map_editor.gd")
	var dialog = InputMapEditor.new()
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()

# =============================================================================
# ANIMATION EDITOR
# =============================================================================
func _on_open_animation_editor() -> void:
	var AnimEditor = load("res://addons/visual_gasic/vg_animation_editor.gd")
	var dialog = AnimEditor.new()

	# If 3D editor is active and has a selected node, use it
	if is_instance_valid(_vg_3d_editor) and _vg_3d_editor.visible:
		var sel = _vg_3d_editor.get_selected_node() if _vg_3d_editor.has_method("get_selected_node") else null
		if is_instance_valid(sel):
			dialog.set_target(sel)
	# If 2D editor is active and has a selected node, use it
	elif is_instance_valid(_vg_2d_editor) and _vg_2d_editor.visible:
		var sel = _vg_2d_editor.get_selected_node() if _vg_2d_editor.has_method("get_selected_node") else null
		if is_instance_valid(sel):
			dialog.set_target(sel)

	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()

# =============================================================================
# MAKE EXE — One-click export
# =============================================================================
var _export_dialog: FileDialog = null

func _on_make_exe() -> void:
	# Save everything first
	_do_save_all()

	if not is_instance_valid(_export_dialog):
		_export_dialog = FileDialog.new()
		_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_export_dialog.title = "Make EXE — Choose Output Location"
		_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		# Determine platform-specific defaults
		var platform := OS.get_name()
		if platform == "Windows":
			_export_dialog.filters = PackedStringArray(["*.exe ; Windows Executable"])
			_export_dialog.current_file = ProjectSettings.get_setting("application/config/name", "Game") + ".exe"
		elif platform == "macOS":
			_export_dialog.filters = PackedStringArray(["*.app ; macOS Application", "*.zip ; macOS Archive"])
			_export_dialog.current_file = ProjectSettings.get_setting("application/config/name", "Game") + ".app"
		else:
			_export_dialog.filters = PackedStringArray(["*.x86_64 ; Linux Executable", "* ; All Files"])
			_export_dialog.current_file = ProjectSettings.get_setting("application/config/name", "Game") + ".x86_64"
		_export_dialog.size = Vector2i(700, 500)
		_export_dialog.file_selected.connect(_on_export_path_selected)
		EditorInterface.get_base_control().add_child(_export_dialog)

	_export_dialog.popup_centered()

func _on_export_path_selected(path: String) -> void:
	if path.is_empty():
		return

	_log_output("📦 Building export to: " + path, Color(0.0, 0.4, 0.0))

	# Find or create an export preset
	var export_plugin := EditorInterface.get_editor_settings()
	var platform := OS.get_name()

	# Determine the export preset name based on platform
	var preset_name := ""
	if platform == "Windows" or path.ends_with(".exe"):
		preset_name = "Windows Desktop"
	elif platform == "macOS" or path.ends_with(".app"):
		preset_name = "macOS"
	else:
		preset_name = "Linux"

	# Use the EditorExportPlatform API if available
	# For now, use Godot's command-line export as a reliable fallback
	var godot_path := OS.get_executable_path()
	var args := PackedStringArray([
		"--headless",
		"--export-release",
		preset_name,
		path,
	])

	_log_output("Running: " + godot_path + " " + " ".join(args), Color(0.5, 0.5, 0.5))

	# Check if the export preset exists
	var presets_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(presets_path):
		# Create a minimal export_presets.cfg
		_create_default_export_preset(preset_name, path)

	var output := []
	var exit_code := OS.execute(godot_path, args, output, true, false)

	if exit_code == 0:
		_log_output("✅ Export complete: " + path, Color(0.0, 0.5, 0.0))
		# Open the output folder
		OS.shell_show_in_file_manager(path)
	else:
		var error_text := "\n".join(output) if output.size() > 0 else "Unknown error"
		_log_output("❌ Export failed (code %d): %s" % [exit_code, error_text], Color(0.8, 0.0, 0.0))
		push_error("[VG] Export failed: " + error_text)

func _create_default_export_preset(preset_name: String, output_path: String) -> void:
	var content := ""
	match preset_name:
		"Windows Desktop":
			content = """[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""

[preset.0.options]

"""
		"Linux":
			content = """[preset.0]

name="Linux"
platform="Linux"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""

[preset.0.options]

"""
		"macOS":
			content = """[preset.0]

name="macOS"
platform="macOS"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""

[preset.0.options]

"""

	var file := FileAccess.open("res://export_presets.cfg", FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("[VG] Created default export preset: ", preset_name)

# =============================================================================
# EDIT MENU HELPERS — Code editor operations
# =============================================================================

## Returns the active CodeEdit from the embedded code editor, or null.
func _get_active_code_edit() -> CodeEdit:
	if is_instance_valid(_embedded_code_editor) and _embedded_code_editor.visible:
		return _embedded_code_editor.get_code_edit()
	return null

## The Find/Replace bar widget (created once, reused)
var _find_replace_bar: VBoxContainer = null
var _find_input: LineEdit = null
var _replace_input: LineEdit = null

## Show the Find/Replace bar in the embedded code editor.
func _show_find_replace_bar(show_replace: bool) -> void:
	var ce: CodeEdit = _get_active_code_edit()
	if not ce:
		return
	if not is_instance_valid(_find_replace_bar):
		_create_find_replace_bar()
	if not _find_replace_bar.get_parent():
		# Insert above the main split (between nav bar and code area)
		if is_instance_valid(_embedded_code_editor):
			var split_idx = _embedded_code_editor.get_child_count()
			for i in _embedded_code_editor.get_child_count():
				var child = _embedded_code_editor.get_child(i)
				if child is VSplitContainer or child.name == "MainSplit":
					split_idx = i
					break
			_embedded_code_editor.add_child(_find_replace_bar)
			_embedded_code_editor.move_child(_find_replace_bar, split_idx)
	_find_replace_bar.visible = true
	_replace_input.visible = show_replace
	if _replace_input.get_parent() and _replace_input.get_parent().has_method("get_child"):
		# Show/hide the replace row (the parent HBox)
		for child in _find_replace_bar.get_children():
			if child is HBoxContainer:
				var has_replace = false
				for sub in child.get_children():
					if sub == _replace_input:
						has_replace = true
				if has_replace:
					child.visible = show_replace
	# Pre-fill with selected text
	if ce.has_selection():
		var sel_text = ce.get_selected_text()
		if "\n" not in sel_text:
			_find_input.text = sel_text
	_find_input.grab_focus()
	_find_input.select_all()

func _create_find_replace_bar() -> void:
	_find_replace_bar = VBoxContainer.new()
	_find_replace_bar.name = "FindReplaceBar"
	_find_replace_bar.custom_minimum_size.y = 0
	
	# Find row
	var find_row = HBoxContainer.new()
	find_row.add_theme_constant_override("separation", 4)
	var find_label = Label.new()
	find_label.text = "Find:"
	find_label.custom_minimum_size.x = 60
	find_row.add_child(find_label)
	_find_input = LineEdit.new()
	_find_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_find_input.placeholder_text = "Search..."
	_find_input.tree_entered.connect(func(): _style_popup_menu(_find_input.get_menu()))
	find_row.add_child(_find_input)
	var find_next_btn = Button.new()
	find_next_btn.text = "Next"
	find_next_btn.pressed.connect(_on_find_next)
	find_row.add_child(find_next_btn)
	var find_prev_btn = Button.new()
	find_prev_btn.text = "Prev"
	find_prev_btn.pressed.connect(_on_find_prev)
	find_row.add_child(find_prev_btn)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(func(): _find_replace_bar.visible = false)
	find_row.add_child(close_btn)
	_find_replace_bar.add_child(find_row)
	
	# Replace row
	var replace_row = HBoxContainer.new()
	replace_row.name = "ReplaceRow"
	replace_row.add_theme_constant_override("separation", 4)
	var replace_label = Label.new()
	replace_label.text = "Replace:"
	replace_label.custom_minimum_size.x = 60
	replace_row.add_child(replace_label)
	_replace_input = LineEdit.new()
	_replace_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replace_input.placeholder_text = "Replace with..."
	_replace_input.tree_entered.connect(func(): _style_popup_menu(_replace_input.get_menu()))
	replace_row.add_child(_replace_input)
	var replace_btn = Button.new()
	replace_btn.text = "Replace"
	replace_btn.pressed.connect(_on_replace_one)
	replace_row.add_child(replace_btn)
	var replace_all_btn = Button.new()
	replace_all_btn.text = "All"
	replace_all_btn.pressed.connect(_on_replace_all)
	replace_row.add_child(replace_all_btn)
	_find_replace_bar.add_child(replace_row)
	
	# Enter key triggers find next
	_find_input.text_submitted.connect(func(_t): _on_find_next())

func _on_find_next() -> void:
	var ce = _get_active_code_edit()
	if not ce or _find_input.text.is_empty():
		return
	var text = ce.text
	var search_str = _find_input.text
	var caret_line = ce.get_caret_line()
	var caret_col = ce.get_caret_column()
	# Search forward from caret
	var start_offset = 0
	var lines = text.split("\n")
	for i in caret_line:
		start_offset += lines[i].length() + 1
	start_offset += caret_col
	var pos = text.findn(search_str, start_offset + 1)
	if pos == -1:
		pos = text.findn(search_str, 0)  # Wrap around
	if pos >= 0:
		_navigate_to_offset(ce, pos, search_str.length())

func _on_find_prev() -> void:
	var ce = _get_active_code_edit()
	if not ce or _find_input.text.is_empty():
		return
	var text = ce.text
	var search_str = _find_input.text
	var caret_line = ce.get_caret_line()
	var caret_col = ce.get_caret_column()
	var start_offset = 0
	var lines = text.split("\n")
	for i in caret_line:
		start_offset += lines[i].length() + 1
	start_offset += caret_col
	# Search backward
	var search_from = start_offset - 1
	if search_from < 0:
		search_from = text.length() - 1
	var lower_text = text.to_lower()
	var lower_search = search_str.to_lower()
	var pos = lower_text.rfind(lower_search, search_from)
	if pos == -1:
		pos = lower_text.rfind(lower_search)  # Wrap
	if pos >= 0:
		_navigate_to_offset(ce, pos, search_str.length())

func _navigate_to_offset(ce: CodeEdit, offset: int, sel_length: int) -> void:
	var lines = ce.text.split("\n")
	var current_offset = 0
	for i in lines.size():
		var line_len = lines[i].length() + 1
		if current_offset + line_len > offset:
			var col = offset - current_offset
			ce.set_caret_line(i)
			ce.set_caret_column(col)
			ce.select(i, col, i, col + sel_length)
			ce.center_viewport_to_caret()
			return
		current_offset += line_len

func _on_replace_one() -> void:
	var ce = _get_active_code_edit()
	if not ce or _find_input.text.is_empty():
		return
	if ce.has_selection() and ce.get_selected_text().to_lower() == _find_input.text.to_lower():
		ce.insert_text_at_caret(_replace_input.text)
	_on_find_next()

func _on_replace_all() -> void:
	var ce = _get_active_code_edit()
	if not ce or _find_input.text.is_empty():
		return
	var old_text = ce.text
	# Case-insensitive replace
	var new_text = ""
	var search_lower = _find_input.text.to_lower()
	var search_len = _find_input.text.length()
	var i = 0
	var count = 0
	var lower_old = old_text.to_lower()
	while i < old_text.length():
		var pos = lower_old.find(search_lower, i)
		if pos == -1:
			new_text += old_text.substr(i)
			break
		new_text += old_text.substr(i, pos - i) + _replace_input.text
		i = pos + search_len
		count += 1
	if count > 0:
		ce.text = new_text
		_flash_status_message(str(count) + " replacement(s) made")

## Comment selected lines by prepending '
func _comment_selected_lines(ce: CodeEdit) -> void:
	if not ce.has_selection():
		# Comment current line
		var line = ce.get_caret_line()
		var text = ce.get_line(line)
		ce.set_line(line, "'" + text)
		return
	var from_line = ce.get_selection_from_line()
	var to_line = ce.get_selection_to_line()
	ce.begin_complex_operation()
	for i in range(from_line, to_line + 1):
		var text = ce.get_line(i)
		ce.set_line(i, "'" + text)
	ce.end_complex_operation()

## Uncomment selected lines by removing leading '
func _uncomment_selected_lines(ce: CodeEdit) -> void:
	if not ce.has_selection():
		var line = ce.get_caret_line()
		var text = ce.get_line(line)
		if text.begins_with("'"):
			ce.set_line(line, text.substr(1))
		elif text.strip_edges().begins_with("'"):
			var idx = text.find("'")
			ce.set_line(line, text.substr(0, idx) + text.substr(idx + 1))
		return
	var from_line = ce.get_selection_from_line()
	var to_line = ce.get_selection_to_line()
	ce.begin_complex_operation()
	for i in range(from_line, to_line + 1):
		var text = ce.get_line(i)
		if text.begins_with("'"):
			ce.set_line(i, text.substr(1))
		elif text.strip_edges().begins_with("'"):
			var idx = text.find("'")
			ce.set_line(i, text.substr(0, idx) + text.substr(idx + 1))
	ce.end_complex_operation()

## Indent selected lines by adding 4 spaces
func _indent_selected_lines(ce: CodeEdit) -> void:
	var from_line = ce.get_caret_line()
	var to_line = from_line
	if ce.has_selection():
		from_line = ce.get_selection_from_line()
		to_line = ce.get_selection_to_line()
	ce.begin_complex_operation()
	for i in range(from_line, to_line + 1):
		ce.set_line(i, "    " + ce.get_line(i))
	ce.end_complex_operation()

## Outdent selected lines by removing up to 4 leading spaces
func _outdent_selected_lines(ce: CodeEdit) -> void:
	var from_line = ce.get_caret_line()
	var to_line = from_line
	if ce.has_selection():
		from_line = ce.get_selection_from_line()
		to_line = ce.get_selection_to_line()
	ce.begin_complex_operation()
	for i in range(from_line, to_line + 1):
		var text = ce.get_line(i)
		var spaces_to_remove = 0
		for j in range(mini(4, text.length())):
			if text[j] == " ":
				spaces_to_remove += 1
			elif text[j] == "\t":
				spaces_to_remove += 1
				break
			else:
				break
		if spaces_to_remove > 0:
			ce.set_line(i, text.substr(spaces_to_remove))
	ce.end_complex_operation()

## Toggle bookmark on current line
func _toggle_bookmark(ce: CodeEdit) -> void:
	var line = ce.get_caret_line()
	if ce.is_line_bookmarked(line):
		ce.set_line_as_bookmarked(line, false)
	else:
		ce.set_line_as_bookmarked(line, true)

## Jump to next bookmark
func _goto_next_bookmark(ce: CodeEdit) -> void:
	var bookmarks = ce.get_bookmarked_lines()
	if bookmarks.is_empty():
		_flash_status_message("No bookmarks set")
		return
	var caret_line = ce.get_caret_line()
	for bm in bookmarks:
		if bm > caret_line:
			ce.set_caret_line(bm)
			ce.center_viewport_to_caret()
			return
	# Wrap around to first bookmark
	ce.set_caret_line(bookmarks[0])
	ce.center_viewport_to_caret()

## Jump to previous bookmark
func _goto_prev_bookmark(ce: CodeEdit) -> void:
	var bookmarks = ce.get_bookmarked_lines()
	if bookmarks.is_empty():
		_flash_status_message("No bookmarks set")
		return
	var caret_line = ce.get_caret_line()
	var i = bookmarks.size() - 1
	while i >= 0:
		if bookmarks[i] < caret_line:
			ce.set_caret_line(bookmarks[i])
			ce.center_viewport_to_caret()
			return
		i -= 1
	# Wrap around to last bookmark
	ce.set_caret_line(bookmarks[bookmarks.size() - 1])
	ce.center_viewport_to_caret()

## Clear all bookmarks
func _clear_all_bookmarks(ce: CodeEdit) -> void:
	var bookmarks = ce.get_bookmarked_lines()
	for bm in bookmarks:
		ce.set_line_as_bookmarked(bm, false)
	_flash_status_message("All bookmarks cleared")

# =============================================================================
# FORMAT MENU HELPERS — Form Designer layout operations
# =============================================================================

## Space selected controls equally in horizontal direction.
func _format_space_equally_h() -> void:
	if not _form_designer or not _form_designer.has_method("get_selected_controls"):
		return
	var selected = _form_designer.get_selected_controls()
	if selected.size() < 3:
		_flash_status_message("Select at least 3 controls for Space Equally")
		return
	# Sort by X position
	selected.sort_custom(func(a, b): return a.position.x < b.position.x)
	var first_x = selected[0].position.x
	var last_right = selected[selected.size() - 1].position.x + selected[selected.size() - 1].size.x
	var total_width = 0.0
	for ctrl in selected:
		total_width += ctrl.size.x
	var gap = (last_right - first_x - total_width) / (selected.size() - 1)
	var x_pos = first_x
	for ctrl in selected:
		ctrl.position.x = x_pos
		x_pos += ctrl.size.x + gap
	_flash_status_message("Spaced equally horizontal")

## Space selected controls equally in vertical direction.
func _format_space_equally_v() -> void:
	if not _form_designer or not _form_designer.has_method("get_selected_controls"):
		return
	var selected = _form_designer.get_selected_controls()
	if selected.size() < 3:
		_flash_status_message("Select at least 3 controls for Space Equally")
		return
	selected.sort_custom(func(a, b): return a.position.y < b.position.y)
	var first_y = selected[0].position.y
	var last_bottom = selected[selected.size() - 1].position.y + selected[selected.size() - 1].size.y
	var total_height = 0.0
	for ctrl in selected:
		total_height += ctrl.size.y
	var gap = (last_bottom - first_y - total_height) / (selected.size() - 1)
	var y_pos = first_y
	for ctrl in selected:
		ctrl.position.y = y_pos
		y_pos += ctrl.size.y + gap
	_flash_status_message("Spaced equally vertical")

## Snap all selected controls to the grid.
func _format_size_to_grid() -> void:
	if not _form_designer or not _form_designer.has_method("get_selected_controls"):
		return
	var selected = _form_designer.get_selected_controls()
	var grid_size = 8.0  # Default grid snap
	if _form_designer.has_method("get_grid_size"):
		grid_size = _form_designer.get_grid_size()
	for ctrl in selected:
		ctrl.position.x = round(ctrl.position.x / grid_size) * grid_size
		ctrl.position.y = round(ctrl.position.y / grid_size) * grid_size
		ctrl.size.x = max(grid_size, round(ctrl.size.x / grid_size) * grid_size)
		ctrl.size.y = max(grid_size, round(ctrl.size.y / grid_size) * grid_size)
	_flash_status_message("Sized to grid")

## Center selected controls horizontally within the form.
func _format_center_in_form_h() -> void:
	if not _form_designer or not _form_designer.has_method("get_selected_controls"):
		return
	var selected = _form_designer.get_selected_controls()
	var form_width = 640.0
	if _form_designer.has_method("get_form_size"):
		form_width = _form_designer.get_form_size().x
	for ctrl in selected:
		ctrl.position.x = (form_width - ctrl.size.x) / 2.0
	_flash_status_message("Centered horizontally")

## Center selected controls vertically within the form.
func _format_center_in_form_v() -> void:
	if not _form_designer or not _form_designer.has_method("get_selected_controls"):
		return
	var selected = _form_designer.get_selected_controls()
	var form_height = 480.0
	if _form_designer.has_method("get_form_size"):
		form_height = _form_designer.get_form_size().y
	for ctrl in selected:
		ctrl.position.y = (form_height - ctrl.size.y) / 2.0
	_flash_status_message("Centered vertically")

# =============================================================================
# TIP OF THE DAY
# =============================================================================

## Returns the array of tips shown in the Tip of the Day dialog.
func _get_tips() -> PackedStringArray:
	return PackedStringArray([
		"Press Ctrl+Arrow keys to nudge selected controls by 1 pixel for precise positioning.",
		"Use Ctrl+Mouse Wheel to zoom the form canvas in and out.",
		"Press Ctrl+G in the Code Editor to jump to a specific line number.",
		"Ctrl+Shift+S saves all open forms and modules at once.",
		"Type in the Property Filter box (at the top of the Properties panel) to quickly find any property by name.",
		"Hover over any property label in the Properties panel to see a description tooltip.",
		"Press Shift+Up or Shift+Down on a numeric property field to step the value by ±1.",
		"Use Edit > Bring to Front / Send to Back to change control Z-order on the form.",
		"Right-click a control and choose Lock Position to prevent accidental moves.",
		"Double-click any control on the form to jump straight to its event handler code.",
		"The form canvas supports snap-to-grid — change the grid size in the Format menu.",
		"An asterisk (*) in the title bar means you have unsaved changes.",
		"Ctrl+A selects all controls on the current form.",
		"Ctrl+Z and Ctrl+Y provide full undo and redo for form editing.",
		"Right-click in the Project Explorer to add, rename, or delete forms and modules.",
		"Press F7 to switch to Code View, and Shift+F7 to switch back to Form View.",
		"Click a control type in the Toolbox, then click on the form to place it.",
		"The Immediate Window (bottom panel) lets you evaluate expressions at runtime.",
		"Use the Alignment toolbar to align, size, and distribute multiple selected controls.",
		"Ctrl+S saves the current form. Forms are also auto-saved when you switch views.",
		"Resize the form itself by dragging the resize handles on its edges and corners.",
		"The Code Navigator dropdowns above the code editor let you jump between Subs and Functions.",
		"Use the Color Palette toolbar for quick ForeColor and BackColor changes.",
		"Import existing VB6 forms (.frm) and projects (.vbp) from Project > Tools.",
		"The Snippet Browser (Project > Tools > VG: Snippet Browser) provides ready-made code templates.",
		"Use the Theme Picker (Project > Tools > VG: Theme Picker) to customize IDE colors.",
		"Right-click a control on the form to access context menu options like Cut, Copy, Paste, and Delete.",
		"Hold Shift and click to select multiple controls for group operations.",
		"The Menu Editor (Project > Tools) lets you build VB6-style menu bars visually.",
		"Check the documentation at Help > Visual Gasic Documentation for guides and tutorials.",
	])

## Builds the Tip of the Day Window dialog with VB6/Win95 styling.
func _create_tip_of_day_dialog() -> void:
	var dialog = Window.new()
	dialog.name = "TipOfTheDay"
	dialog.title = "Tip of the Day"
	dialog.size = Vector2i(520, 310)
	dialog.exclusive = true
	dialog.unresizable = true
	dialog.wrap_controls = true
	dialog.transient = true
	dialog.close_requested.connect(dialog.hide)

	# Background panel — dark theme matching the Godot editor
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color("#2B2B2B")
	panel_sb.border_color = Color("#555555")
	panel_sb.border_width_top = 1
	panel_sb.border_width_bottom = 1
	panel_sb.border_width_left = 1
	panel_sb.border_width_right = 1
	panel.add_theme_stylebox_override("panel", panel_sb)
	dialog.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# ── Header: light-bulb + title ──
	var header = Label.new()
	header.text = "\ud83d\udca1  Did you know?"
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color("#FFD866"))
	vbox.add_child(header)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# ── Tip text ──
	_tip_label = Label.new()
	_tip_label.name = "TipText"
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(460, 80)
	_tip_label.add_theme_font_size_override("font_size", 14)
	_tip_label.add_theme_color_override("font_color", Color("#E0E0E0"))
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_tip_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tip_label)

	# ── Checkbox: "Show tips at startup" ──
	_tip_checkbox = CheckBox.new()
	_tip_checkbox.name = "ShowTipsCheckBox"
	_tip_checkbox.text = "  Show tips at startup"
	_tip_checkbox.button_pressed = _show_tips_on_startup
	_tip_checkbox.add_theme_font_size_override("font_size", 12)
	_tip_checkbox.add_theme_color_override("font_color", Color("#C0C0C0"))
	_tip_checkbox.toggled.connect(_on_tip_checkbox_toggled)
	vbox.add_child(_tip_checkbox)

	# ── Button row: [spacer] [Next Tip] [Close] ──
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)

	var next_btn = Button.new()
	next_btn.text = "Next Tip"
	next_btn.custom_minimum_size = Vector2(100, 30)
	next_btn.add_theme_font_size_override("font_size", 12)
	next_btn.pressed.connect(_on_next_tip)
	btn_row.add_child(next_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 30)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(dialog.hide)
	btn_row.add_child(close_btn)

	vbox.add_child(btn_row)

	_tip_of_day_dialog = dialog
	dialog.visible = false          # Don't auto-show; _show_tip_of_day() will popup_centered() when wanted
	add_child(dialog)

## Shows the Tip of the Day dialog, advancing to the current tip index.
func _show_tip_of_day() -> void:
	print("[VG-TIP] _show_tip_of_day called, _show_tips_on_startup=", _show_tips_on_startup)
	if not _show_tips_on_startup:
		return
	if not is_instance_valid(_tip_of_day_dialog):
		_create_tip_of_day_dialog()
	var tips := _get_tips()
	if tips.is_empty():
		return
	_tip_index = _tip_index % tips.size()
	_tip_label.text = tips[_tip_index]
	if is_instance_valid(_tip_checkbox):
		_tip_checkbox.button_pressed = _show_tips_on_startup
	_tip_of_day_dialog.popup_centered()

## "Next Tip" button handler — advance and display the next tip.
func _on_next_tip() -> void:
	var tips := _get_tips()
	if tips.is_empty():
		return
	_tip_index = (_tip_index + 1) % tips.size()
	_tip_label.text = tips[_tip_index]
	_save_tip_config()

## Checkbox toggled — update preference and persist immediately.
func _on_tip_checkbox_toggled(pressed: bool) -> void:
	print("[VG-TIP] Checkbox toggled: pressed=", pressed)
	_show_tips_on_startup = pressed
	_save_tip_config()

## Loads Tip of the Day preferences from a per-project config file.
func _load_tip_config() -> void:
	var config := ConfigFile.new()
	var path := "user://vg_tip_config.cfg"
	var err := config.load(path)
	print("[VG-TIP] _load_tip_config: path=", path, " err=", err)
	if err == OK:
		_show_tips_on_startup = config.get_value("tip_of_day", "show_on_startup", true)
		_tip_index = config.get_value("tip_of_day", "last_index", 0)
		print("[VG-TIP] Loaded: show_on_startup=", _show_tips_on_startup, " tip_index=", _tip_index)
	else:
		# First run — default is true, will be saved when user toggles checkbox
		_show_tips_on_startup = true
		_tip_index = 0
		print("[VG-TIP] Config not found, using defaults")

## Saves Tip of the Day preferences to a per-project config file.
func _save_tip_config() -> void:
	var config := ConfigFile.new()
	config.set_value("tip_of_day", "show_on_startup", _show_tips_on_startup)
	config.set_value("tip_of_day", "last_index", _tip_index)
	config.save("user://vg_tip_config.cfg")

# =============================================================================
# VB6 STATUS BAR
# =============================================================================

## Creates a VB6-style status bar at the bottom of the center panel.
func _create_vb6_status_bar() -> Label:
	var lbl = Label.new()
	lbl.name = "StatusBar"
	lbl.text = "  Form1  |  600 x 400  |  Grid: 8 px"
	lbl.custom_minimum_size.y = 22
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	# Sunken 3D look
	var sb = StyleBoxFlat.new()
	sb.bg_color = _theme.get("panel_background", Color("#F0EDE8"))
	sb.border_color = Color(0.55, 0.55, 0.55)
	sb.border_width_top = 1
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl

## Updates the status bar text based on form designer state.
func _update_status_bar() -> void:
	if not is_instance_valid(_status_bar) or not is_instance_valid(_form_designer):
		return
	var form_name = _form_designer.get_form_name() if _form_designer.has_method("get_form_name") else "Form1"
	var dirty_mark = " *" if _form_dirty else ""
	var status_text = _form_designer.get_status_text() if _form_designer.has_method("get_status_text") else ""
	var grid_size = _form_designer.get_grid_size() if _form_designer.has_method("get_grid_size") else 8
	_status_bar.text = "  %s%s  |  %s  |  Grid: %d px  |  Zoom: %d%%" % [form_name, dirty_mark, status_text, grid_size, int(_canvas_zoom * 100)]

## Track a form path in the recent forms list.
func _track_recent_form(path: String) -> void:
	if path.is_empty():
		return
	_recent_forms.erase(path)
	_recent_forms.push_front(path)
	while _recent_forms.size() > MAX_RECENT_FORMS:
		_recent_forms.pop_back()

## Called by C++ when control position/size changes or selection changes.
func _on_fd_status_changed(text: String) -> void:
	if is_instance_valid(_coord_label):
		_coord_label.text = text
	_update_status_bar()

## Called by C++ when form is resized via drag handles.
func _on_fd_form_resized(size: Vector2i) -> void:
	if is_instance_valid(_coord_label):
		_coord_label.text = "%d x %d" % [size.x, size.y]
	_update_status_bar()

## Finds Godot editor chrome that needs manual hiding (menu bar, title bar, status bar, bottom panel).
## Docks (left/right/bottom) are handled by EditorInterface.set_distraction_free_mode().
func _find_godot_chrome() -> void:
	var base = get_editor_interface().get_base_control()

	# ── Menu bar (File/Scene/Project/Debug/Editor/Help) ──
	if not is_instance_valid(_godot_menu_bar):
		_godot_menu_bar = _find_node_by_class_recursive(base, "MenuBar", 4)

	# ── Title bar HBox (run/pause/stop buttons, renderer dropdown, etc.) ──
	if not is_instance_valid(_godot_title_bar_hbox):
		_godot_title_bar_hbox = _find_title_bar_hbox(base)

	# ── Status bar at the very bottom ──
	if not is_instance_valid(_godot_status_bar):
		_godot_status_bar = _find_status_bar(base)

	# ── Bottom panel (Output/Debugger/Audio/Animation/etc.) ──
	if not is_instance_valid(_godot_bottom_panel):
		_godot_bottom_panel = _find_bottom_panel(base)

	# ── Main VSplitContainer (viewport vs bottom panel) ──
	# In Godot 4.5+, the container is a DockSplitContainer (inherits SplitContainer).
	# Walk UP from the found bottom panel to locate it.
	if not is_instance_valid(_godot_main_vsplit) and is_instance_valid(_godot_bottom_panel):
		var node = _godot_bottom_panel
		for i in range(12):
			var parent = node.get_parent()
			if not parent:
				break
			# Check for DockSplitContainer or VSplitContainer by class name
			var cls = parent.get_class()
			if cls == "DockSplitContainer" or parent is VSplitContainer:
				# Verify it's the vertical one (DockVSplitCenter)
				if parent is SplitContainer and (parent as SplitContainer).vertical:
					_godot_main_vsplit = parent as SplitContainer
					print("[VG] Main VSplit found: ", cls, "(", parent.name, ") at depth ", i + 1)
					break
			node = parent
	# Fallback: breadth-first search from root
	if not is_instance_valid(_godot_main_vsplit):
		_godot_main_vsplit = _find_main_vsplit(base, 0)
		if is_instance_valid(_godot_main_vsplit):
			print("[VG] Main VSplit found via root search")

## Recursively find a node with a given class name, limited by depth.
func _find_node_by_class_recursive(node: Node, cls: String, max_depth: int) -> Control:
	if max_depth <= 0:
		return null
	if node.get_class() == cls:
		return node as Control
	for child in node.get_children():
		var result = _find_node_by_class_recursive(child, cls, max_depth - 1)
		if result:
			return result
	return null

## Finds the title bar HBox that contains run/stop buttons and renderer dropdown.
## This is typically the first HBoxContainer child of the root VBoxContainer.
func _find_title_bar_hbox(base: Control) -> Control:
	# Walk the root of the editor: EditorNode → VBoxContainer → first HBox is the title bar
	var root_vbox = _find_node_by_class_recursive(base, "VBoxContainer", 3)
	if not root_vbox:
		return null
	# The title bar is typically a child HBox that contains buttons like "Run"/"Pause"/"Stop"
	for child in root_vbox.get_children():
		if child is HBoxContainer:
			# Check if it has run/play buttons (identifying mark of the title bar)
			for gc in child.get_children():
				if gc is Button:
					var btn := gc as Button
					if btn.tooltip_text.to_lower().contains("run") or btn.tooltip_text.to_lower().contains("play"):
						return child
				# Also check nested HBoxContainers (title bar can be split)
				if gc is HBoxContainer:
					for ggc in gc.get_children():
						if ggc is Button:
							var btn2 := ggc as Button
							if btn2.tooltip_text.to_lower().contains("run") or btn2.tooltip_text.to_lower().contains("play"):
								return child
	return null

## Finds the status bar at the very bottom of the editor.
func _find_status_bar(base: Control) -> Control:
	# The editor root is typically a VBoxContainer; the last child is the status bar.
	var root_vbox = _find_node_by_class_recursive(base, "VBoxContainer", 3)
	if not root_vbox:
		return null
	var count = root_vbox.get_child_count()
	if count == 0:
		return null
	# Walk from the bottom up to find a small HBox or Panel that looks like a status bar
	for i in range(count - 1, max(count - 4, -1), -1):
		var child = root_vbox.get_child(i)
		if child is HBoxContainer:
			# Status bar is usually a small HBox with labels/version info
			if child.custom_minimum_size.y < 40 or child.size.y < 40:
				return child
		if child is MarginContainer or child is PanelContainer:
			if child.size.y < 40:
				return child
	return null

## Finds the Godot editor's bottom panel (Output/Debugger/Audio/Animation tabs).
## In Godot 4.5+ this is an EditorBottomPanel node inside a DockSplitContainer.
func _find_bottom_panel(base: Control) -> Control:
	# Strategy 1: Find EditorBottomPanel by class name directly
	var ebp = _find_node_by_class_recursive(base, "EditorBottomPanel", 12)
	if ebp:
		print("[VG] Bottom panel found via EditorBottomPanel class")
		return ebp

	# Strategy 2: Find a Button with text "Output", walk up to EditorBottomPanel
	var output_btn = _find_button_by_text_recursive(base, "Output", 0)
	if output_btn:
		var node = output_btn
		for i in range(8):
			var parent = node.get_parent()
			if not parent:
				break
			if parent.get_class() == "EditorBottomPanel":
				print("[VG] Bottom panel found via Output button → EditorBottomPanel")
				return parent as Control
			if parent is SplitContainer and node is Control:
				# Found the split; the node is the bottom panel side
				print("[VG] Bottom panel found via Output button → SplitContainer child")
				return node as Control
			node = parent
		# Fallback: return the button's grandparent
		var hbox = output_btn.get_parent()
		if hbox:
			var vbox = hbox.get_parent()
			if vbox is Control:
				print("[VG] Bottom panel found via Output button → grandparent")
				return vbox as Control

	# Strategy 3: Find node containing "Filter Messages" text (visible in output panel)
	var filter_node = _find_node_with_text_recursive(base, "Filter Messages", 0)
	if filter_node:
		# Walk up to find a sizeable container
		var node = filter_node
		for i in range(5):
			var parent = node.get_parent()
			if not parent:
				break
			if parent is VSplitContainer:
				print("[VG] Bottom panel found via Filter Messages → parent of VSplit child")
				return node as Control
			node = parent

	print("[VG] Bottom panel: NOT found with any strategy")
	return null

## Find the main editor VSplitContainer (the one splitting viewport from bottom panel).
func _find_main_vsplit(node: Node, depth: int) -> VSplitContainer:
	if depth > 10:
		return null
	if node is VSplitContainer:
		# Check if this VSplit has at least 2 children and is tall (main editor area)
		if node.get_child_count() >= 2:
			var ctrl = node as Control
			if ctrl.size.y > 300:
				return node as VSplitContainer
	for child in node.get_children():
		var result = _find_main_vsplit(child, depth + 1)
		if result:
			return result
	return null

## Recursively find a node that has a property or child Label/Button with given text.
func _find_node_with_text_recursive(node: Node, txt: String, depth: int) -> Control:
	if depth > 16:
		return null
	if node is Label and (node as Label).text.strip_edges().begins_with(txt):
		return node as Control
	if node is Button and (node as Button).text.strip_edges().begins_with(txt):
		return node as Control
	for child in node.get_children():
		var result = _find_node_with_text_recursive(child, txt, depth + 1)
		if result:
			return result
	return null

## Recursively find a Button whose .text matches the given string.
func _find_button_by_text_recursive(node: Node, txt: String, depth: int) -> Button:
	if depth > 16:
		return null
	if node is Button:
		var btn_text: String = (node as Button).text.strip_edges()
		if btn_text == txt:
			return node as Button
	for child in node.get_children():
		var result = _find_button_by_text_recursive(child, txt, depth + 1)
		if result:
			return result
	return null

## Recursive helper to locate the bottom panel button bar.
func _search_bottom_panel_recursive(node: Node, depth: int) -> Control:
	if depth > 14:
		return null
	if node is HBoxContainer:
		var has_output := false
		var has_debugger := false
		for child in node.get_children():
			if child is Button:
				var btn_txt: String = (child as Button).text.strip_edges()
				if btn_txt == "Output":
					has_output = true
				elif btn_txt == "Debugger":
					has_debugger = true
		if has_output and has_debugger:
			var parent = node.get_parent()
			if parent is Control:
				return parent as Control
			return node as Control
	for child in node.get_children():
		var result = _search_bottom_panel_recursive(child, depth + 1)
		if result:
			return result
	return null

## Hides ALL Godot editor chrome for a clean VB6 experience.
## Uses EditorInterface.set_distraction_free_mode() for docks (left/right/bottom)
## and additionally hides menu bar, title bar, status bar, and bottom panel via _process().
func _hide_godot_panels() -> void:
	if _godot_docks_hidden:
		return

	# Use Godot's built-in distraction-free mode to hide all docks properly
	if not EditorInterface.is_distraction_free_mode_enabled():
		EditorInterface.set_distraction_free_mode(true)

	# Find and hide the additional chrome (menu bar, title bar, status bar, bottom panel)
	_find_godot_chrome()
	_chrome_to_keep_hidden = []
	if is_instance_valid(_godot_menu_bar):
		_chrome_to_keep_hidden.append(_godot_menu_bar)
	if is_instance_valid(_godot_title_bar_hbox):
		_chrome_to_keep_hidden.append(_godot_title_bar_hbox)
	if is_instance_valid(_godot_status_bar):
		_chrome_to_keep_hidden.append(_godot_status_bar)
	if is_instance_valid(_godot_bottom_panel):
		_chrome_to_keep_hidden.append(_godot_bottom_panel)
	else:
		print("[VG] WARNING: Bottom panel NOT found — Output window will remain visible")
	for ctrl in _chrome_to_keep_hidden:
		ctrl.visible = false

	# Collapse the main VSplitContainer to push the bottom panel out of view
	if is_instance_valid(_godot_main_vsplit):
		_godot_main_vsplit_offset = _godot_main_vsplit.split_offset
		_godot_main_vsplit.split_offset = int(_godot_main_vsplit.size.y)
		# Also hide the second child directly
		if _godot_main_vsplit.get_child_count() >= 2:
			var bottom_child = _godot_main_vsplit.get_child(1)
			if bottom_child is Control:
				bottom_child.visible = false
		print("[VG] Main VSplit collapsed (offset ", _godot_main_vsplit_offset, " → ", _godot_main_vsplit.split_offset, ")")

	print("[VG] Chrome to keep hidden: ", _chrome_to_keep_hidden.size(), " (bottom_panel=", is_instance_valid(_godot_bottom_panel), ")")

	# ── Window title ──
	if _godot_original_title.is_empty():
		var pname = ProjectSettings.get_setting("application/config/name", "")
		_godot_original_title = "Godot Engine" + (" - " + pname if not pname.is_empty() else "")
	var proj_name = ProjectSettings.get_setting("application/config/name", "Project1")
	var title_prefix: String = _theme.get("window_title_prefix", "Visual Gasic")
	DisplayServer.window_set_title(title_prefix + " - " + proj_name)

	_godot_docks_hidden = true

## Restores ALL Godot editor chrome when leaving Form Designer.
func _show_godot_panels() -> void:
	if not _godot_docks_hidden:
		return

	# Stop persistent hiding FIRST (so _process doesn't re-hide)
	_godot_docks_hidden = false

	# Restore distraction-free mode (brings back all docks)
	if EditorInterface.is_distraction_free_mode_enabled():
		EditorInterface.set_distraction_free_mode(false)

	# Restore menu/title/status bars
	for ctrl in _chrome_to_keep_hidden:
		if is_instance_valid(ctrl):
			ctrl.visible = true
	_chrome_to_keep_hidden = []

	# Restore the main VSplitContainer
	if is_instance_valid(_godot_main_vsplit):
		if _godot_main_vsplit.get_child_count() >= 2:
			var bottom_child = _godot_main_vsplit.get_child(1)
			if bottom_child is Control:
				bottom_child.visible = true
		_godot_main_vsplit.split_offset = _godot_main_vsplit_offset
		_godot_main_vsplit = null

	# ── Restore window title ──
	if not _godot_original_title.is_empty():
		DisplayServer.window_set_title(_godot_original_title)

	# Clear cached chrome references so they're re-discovered fresh next time
	_godot_menu_bar = null
	_godot_title_bar_hbox = null
	_godot_status_bar = null
	_godot_bottom_panel = null
	_bottom_panel_search_done = false

## Ensures a .tscn file on disk has the VB6 Classic Theme.
## If the file predates the theme feature (no "vb6_theme" marker),
## re-saves it through the C++ serializer which injects all StyleBoxes.
## This is a GDScript-side fallback that works even when the .so hasn't
## been reloaded (GDScript is hot-reloaded by the editor).
func _ensure_vb6_theme(tscn_path: String) -> void:
	if not FileAccess.file_exists(tscn_path):
		return
	var file = FileAccess.open(tscn_path, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	file.close()
	if "vb6_theme" in text:
		return  # Already themed
	# The file is pre-theme — re-save through C++ serializer to inject it.
	# open_form() already loaded the controls; save_form_as() writes them
	# back with the full VB6 theme sub_resources.
	print("[VisualGasic] Auto-injecting VB6 Classic Theme into: ", tscn_path)
	_form_designer.save_form_as(tscn_path)
	# Force Godot to reload the scene from disk so the 2D viewport
	# picks up the new theme resources.
	EditorInterface.get_resource_filesystem().update_file(tscn_path)
	get_tree().create_timer(0.3).timeout.connect(_force_godot_scene_reload.bind(tscn_path))

## Syncs the currently edited scene into the C++ Form Designer canvas.
## Called by _make_visible(true) when user switches to Form Designer tab.
## Reads the scene root's .tscn path and loads it into the designer.
func _sync_scene_to_form_designer() -> void:
	if not _form_designer:
		return
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	# Only sync Window or CanvasLayer roots — never Node2D game scenes
	if not (scene_root is Window) and not (scene_root is CanvasLayer):
		return
	var scene_path = scene_root.scene_file_path
	if scene_path.is_empty():
		scene_path = scene_root.get_meta("_edit_scene_file_path", "") if scene_root.has_meta("_edit_scene_file_path") else ""
	if scene_path.is_empty():
		return
	if not scene_path.ends_with(".tscn") and not scene_path.ends_with(".scn"):
		return
	var form_path = _form_designer.get_form_path()
	# Only reload if the path changed (avoid re-parsing the same scene)
	if form_path == scene_path:
		# Safety fallback: if the C++ controls vector was somehow emptied
		# (e.g. by a stale reload race) but the .tscn exists on disk,
		# force a re-read so we recover the user's controls.
		if _form_designer.get_control_count() == 0 and FileAccess.file_exists(scene_path):
			print("VisualGasic: Controls lost — recovering from disk: ", scene_path)
			_form_designer.open_form(scene_path)
			_fixup_form_size_from_tscn(scene_path)
		return

	# Path mismatch — but if the designer already has controls in memory and
	# the form_path was simply lost (cleared to ""), we must NOT call
	# open_form() because that starts with controls.clear() and re-parses
	# the .tscn from disk (which may have 0 user controls).
	# Instead, re-establish the path by saving the current state to disk.
	if form_path.is_empty() and _form_designer.get_control_count() > 0:
		print("VisualGasic: form_path lost — re-establishing via save_form_as('", scene_path, "')  controls=", _form_designer.get_control_count())
		_form_designer.save_form_as(scene_path)
		return

	_form_designer.open_form(scene_path)
	_fixup_form_size_from_tscn(scene_path)
	print("VisualGasic: Synced scene '", scene_path, "' into Form Designer")
	# Apply VB6 Classic Theme directly to the live scene tree.
	# This ensures Godot's 2D viewport shows VB6 styling and Godot's own
	# save serializer will persist the theme into the .tscn.
	_apply_vb6_theme_to_scene_root()
	# Auto-populate the Properties panel with form-level properties so it
	# isn't empty on initial load (VB6 always shows the form's props).
	_populate_properties_for_form()

## Helper: populate the Properties panel with form-level properties.
## Called after a form is loaded into the C++ designer so the user
## immediately sees the form's props (like VB6) instead of an empty grid.
func _populate_properties_for_form() -> void:
	if is_instance_valid(_properties_inspector) and is_instance_valid(_form_designer):
		if _properties_inspector.has_method("show_form_properties"):
			_properties_inspector.show_form_properties(_form_designer)

## Signal: A control was selected in the C++ Form Designer canvas.
func _on_fd_control_selected(index: int) -> void:
	if not _form_designer:
		return
	var info = _form_designer.get_control_info(index)
	print("FormDesigner: Selected ", info.get("name", "?"), " (", info.get("type", "?"), ")")
	# Update properties inspector if available — pass designer ref + index
	if is_instance_valid(_properties_inspector) and _properties_inspector.has_method("show_control_properties"):
		_properties_inspector.show_control_properties(info, _form_designer, index)
	# Reset toolbox to pointer after a control is placed
	var cpp_toolbox = _get_toolbox_instance()
	if cpp_toolbox and cpp_toolbox.has_method("reset_to_pointer"):
		cpp_toolbox.reset_to_pointer()

## Signal: All controls deselected in the C++ Form Designer.
## Show form-level properties (VB6-style) instead of clearing.
func _on_fd_control_deselected() -> void:
	if is_instance_valid(_properties_inspector) and _properties_inspector.has_method("show_form_properties") and is_instance_valid(_form_designer):
		_properties_inspector.show_form_properties(_form_designer)
	elif is_instance_valid(_properties_inspector) and _properties_inspector.has_method("clear_properties"):
		_properties_inspector.clear_properties()

## Signal: Form was modified (dirty flag set) in the C++ Form Designer.
func _on_fd_form_modified() -> void:
	_form_dirty = true
	_update_dirty_indicator()

## Called when the form designer's game_ui_mode changes.
## Switches the toolbox tab to "Game UI" (index 2) or back to "2D Tools" (index 0).
## @param enabled: Whether Game UI mode is now active
func _on_game_ui_mode_changed(enabled: bool) -> void:
	var real_toolbox = _get_toolbox_instance()
	if real_toolbox:
		for c in real_toolbox.get_children():
			if c is TabContainer:
				if enabled:
					c.current_tab = 2  # Game UI
				else:
					c.current_tab = 0  # 2D Tools
				break

## Update the title/status with a * dirty indicator when unsaved changes exist.
func _update_dirty_indicator() -> void:
	if not is_instance_valid(_status_bar) or not is_instance_valid(_form_designer):
		return
	var form_name = _form_designer.get_form_name() if _form_designer.has_method("get_form_name") else "Form1"
	var dirty_mark = " *" if _form_dirty else ""
	var status_text = _form_designer.get_status_text() if _form_designer.has_method("get_status_text") else ""
	var grid_size = _form_designer.get_grid_size() if _form_designer.has_method("get_grid_size") else 8
	_status_bar.text = "  %s%s  |  %s  |  Grid: %d px  |  Zoom: %d%%" % [form_name, dirty_mark, status_text, grid_size, int(_canvas_zoom * 100)]

## Flash a temporary message in the status bar, then restore after 2 seconds.
func _flash_status_message(msg: String) -> void:
	if not is_instance_valid(_status_bar):
		return
	var prev_text = _status_bar.text
	_status_bar.text = "  " + msg
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(_status_bar):
			_update_status_bar()
	)

## Signal: Right-click on the form designer canvas.
## Shows a context menu with type-specific actions.
## @param index: Control index (-1 if right-clicked empty form area)
## @param position: Global screen position for popup placement
var _fd_context_menu: PopupMenu = null
var _fd_context_ctrl_index: int = -1
var _editing_external_scene: bool = false
var _saving_external: bool = false  ## reentrancy guard for _save_external_data
var _switching_to_code_editor: bool = false  ## suppress reload in _make_visible(false) during double-click
var _pending_reload_path: String = ""  ## path to reload after main_screen_changed

func _on_fd_control_right_clicked(index: int, position: Vector2) -> void:
	# Clean up previous context menu if any
	if is_instance_valid(_fd_context_menu):
		_fd_context_menu.queue_free()
	
	_fd_context_ctrl_index = index
	_fd_context_menu = PopupMenu.new()
	_fd_context_menu.name = "FDContextMenu"
	
	if index >= 0:
		var info = _form_designer.get_control_info(index)
		var ctrl_type: String = info.get("type", "")
		var ctrl_name: String = info.get("name", "")
		var scene_path: String = info.get("scene_path", "")
		
		# Type-specific actions
		if ctrl_type == "MenuBar":
			_fd_context_menu.add_item("Edit Menus...", 100)
			_fd_context_menu.add_separator()
		
		# Common actions
		_fd_context_menu.add_item("View Code (" + ctrl_name + "_Click)", 