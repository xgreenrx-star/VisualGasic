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

## VB6-style Color Palette toolbar for quick ForeColor/BackColor picking
var _color_palette = null

## VB6 Main Screen control (registered as editor tab alongside 2D/3D/Script)
var _vb6_main_screen = null

## C++ Form Designer canvas — the custom form editor that bypasses Godot's scene tree
var _form_designer: Control = null

## Composite VB6 IDE layout: Toolbox | Canvas | Properties — all in one main screen
var _ide_layout: VBoxContainer = null

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

## Snippet Browser dialog (v2.4.1)
var _snippet_browser = null

## Theme Picker dialog (v2.4.1)
var _theme_picker = null

## Profiler Panel (v2.6.0) — bottom panel for bytecode profiling
var _profiler_panel = null

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
		add_control_to_bottom_panel(immediate_window, "Immediate")
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
	if data_tips_script:
		_data_tips = data_tips_script.new()
		add_child(_data_tips)
		_data_tips.setup(self)
		print("VisualGasic: Data Tips initialized")
	
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
	
	# Create Profiler Panel (v2.6.0) — bottom panel for bytecode profiling
	var profiler_script = load("res://addons/visual_gasic/vg_profiler_panel.gd")
	if profiler_script:
		_profiler_panel = profiler_script.new()
		if _profiler_panel.has_method("set_debugger_plugin"):
			_profiler_panel.set_debugger_plugin(debugger_plugin)
		add_control_to_bottom_panel(_profiler_panel, "VG Profiler")
		print("VisualGasic: Profiler Panel created (bottom panel)")
	
	# Register custom .vg file icon in the editor theme
	call_deferred("_register_vg_file_icon")
	
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

		# --- Build the composite layout ---
		# VBoxContainer root: Menu | Toolbar | [Toolbox | Canvas | Properties] | Status
		_ide_layout = VBoxContainer.new()
		_ide_layout.name = "VB6_IDE_Layout"
		_ide_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ide_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Apply VB6 light theme IMMEDIATELY so all children inherit it
		_ide_layout.theme = _build_vb6_theme()

		# ── VB6 Menu Bar (full width, like real VB6) ──
		_vb6_menu_bar = _create_vb6_menu_bar()
		_ide_layout.add_child(_vb6_menu_bar)

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
		_coord_label.custom_minimum_size.x = 120
		toolbar_row.add_child(_coord_label)

		# Spacer to push "Godot Editor" button to the right
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toolbar_row.add_child(spacer)

		# "↩ Godot Editor" button — exits Form Designer, restores all Godot panels
		var godot_btn = Button.new()
		godot_btn.name = "BackToGodotBtn"
		godot_btn.text = "\u21a9 Godot Editor"
		godot_btn.tooltip_text = "Exit Form Designer and return to Godot Editor"
		godot_btn.flat = true
		godot_btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		godot_btn.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.5))
		godot_btn.pressed.connect(_on_back_to_godot_pressed)
		toolbar_row.add_child(godot_btn)
		toolbar_panel.add_child(toolbar_row)
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
		canvas_right_split.add_child(canvas_scroll)

		# -- RIGHT: Project Explorer + Properties (resizable VSplitContainer) --
		var right_vsplit = VSplitContainer.new()
		right_vsplit.name = "RightPanelSplit"
		right_vsplit.custom_minimum_size = Vector2(220, 0)
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

		# Properties Inspector (bottom half of right panel)
		if is_instance_valid(_properties_inspector):
			if _properties_inspector.get_parent() == self:
				remove_child(_properties_inspector)
			_properties_inspector.visible = true
			_properties_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
			right_vsplit.add_child(_properties_inspector)

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
	add_tool_menu_item("Import VB6 Form...", Callable(self, "_on_import_vb6_form"))
	add_tool_menu_item("Import VB6 Project...", Callable(self, "_on_import_vb6_project"))
	add_tool_menu_item("Visual Gasic Menu Editor", Callable(self, "_on_menu_editor"))
	add_tool_menu_item("Visual Gasic Project Properties...", Callable(self, "_on_proj_props"))
	add_tool_menu_item("Visual Gasic Object Browser", Callable(self, "_on_obj_browser"))
	add_tool_menu_item("Visual Gasic Tab Order", Callable(self, "_on_tab_order"))
	add_tool_menu_item("Visual Gasic Components...", Callable(self, "_on_components"))

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

## Removes VG panels from Godot docks back to plugin children.
## Called when exiting VB6 mode. Docks return to clean Godot state.
func undock_vg_panels():
	# Panels are embedded in the IDE layout — no undocking needed
	if is_instance_valid(_ide_layout):
		return
	if not _vg_panels_docked:
		return
	if is_instance_valid(toolbox):
		remove_control_from_docks(toolbox)
		add_child(toolbox)
		toolbox.visible = false
	if is_instance_valid(_project_explorer):
		remove_control_from_docks(_project_explorer)
		add_child(_project_explorer)
		_project_explorer.visible = false
	if is_instance_valid(_properties_inspector):
		remove_control_from_docks(_properties_inspector)
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
	return "Form Designer"

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
	else:
		_show_godot_panels()
	# Auto-load the currently edited scene into the C++ Form Designer
	if p_visible and _form_designer:
		_sync_scene_to_form_designer()

## Called when user clicks the "↩ Godot Editor" button.
## Switches from Form Designer back to the 2D editor, restoring all Godot panels.
func _on_back_to_godot_pressed() -> void:
	EditorInterface.set_main_screen_editor("2D")

## Called by the editor after restoring saved window layout.
func _set_window_layout(config: ConfigFile):
	if is_instance_valid(_layout_manager):
		_layout_manager.on_window_layout_restored(config)
	# Restore the form path from last session so the designer isn't blank
	var saved_form_path = config.get_value("VisualGasic", "form_path", "")
	if not saved_form_path.is_empty() and is_instance_valid(_form_designer):
		if FileAccess.file_exists(saved_form_path):
			_form_designer.open_form(saved_form_path)
			print("[VisualGasic] Restored form from layout config: ", saved_form_path)

## Called by the editor when saving window layout.
func _get_window_layout(config: ConfigFile):
	if is_instance_valid(_layout_manager):
		_layout_manager.on_window_layout_saving(config)
	# Persist the current form path so it survives editor restart
	if is_instance_valid(_form_designer):
		var fpath = _form_designer.get_form_path()
		if not fpath.is_empty():
			config.set_value("VisualGasic", "form_path", fpath)

## Called by the editor before saving any external data (scenes, resources).
## We write the C++ Form Designer state to disk, then force Godot to reload
## the scene so its in-memory scene tree matches our .tscn.  Without the
## reload, Godot's own scene-save (which runs right after this) would
## overwrite our file with its stale version.
func _save_external_data() -> void:
	if _saving_external:
		return  # reentrancy guard — reload_scene can trigger another save cycle
	_saving_external = true
	if is_instance_valid(_form_designer) and not _form_designer.get_form_path().is_empty():
		_form_designer.save_form()
		var path = _form_designer.get_form_path()
		# Force Godot to re-read the .tscn so its scene tree matches our save
		var scene_root = EditorInterface.get_edited_scene_root()
		if scene_root and scene_root.scene_file_path == path:
			EditorInterface.reload_scene_from_path(path)
		print("[VisualGasic] _save_external_data → form saved & scene reloaded")
	_saving_external = false

## Called when the plugin exits the editor tree.
## Cleans up all plugin components and disconnects signals.
func _exit_tree():
	# Auto-save the form before cleanup so Godot doesn't lose our work
	if is_instance_valid(_form_designer) and not _form_designer.get_form_path().is_empty():
		_form_designer.save_form()
		print("[VisualGasic] _exit_tree → form auto-saved")
	# Restore any hidden Godot docks before cleanup
	_show_godot_panels()
	
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
	remove_tool_menu_item("Import VB6 Form...")
	remove_tool_menu_item("Import VB6 Project...")
	remove_tool_menu_item("Visual Gasic Menu Editor")
	remove_tool_menu_item("Visual Gasic Project Properties...")
	remove_tool_menu_item("Visual Gasic Object Browser")
	remove_tool_menu_item("Visual Gasic Tab Order")
	remove_tool_menu_item("Visual Gasic Components...")
	remove_tool_menu_item("VG: Snippet Browser")
	remove_tool_menu_item("VG: Theme Picker")
	
	if is_instance_valid(immediate_window):
		remove_control_from_bottom_panel(immediate_window)
		immediate_window.queue_free()
		immediate_window = null
	
	# Cleanup Profiler Panel
	if is_instance_valid(_profiler_panel):
		remove_control_from_bottom_panel(_profiler_panel)
		_profiler_panel.queue_free()
		_profiler_panel = null
	
	# Cleanup Code Navigator (injected above code editor)
	if is_instance_valid(_code_navigator):
		if _code_navigator.get_parent():
			_code_navigator.get_parent().remove_child(_code_navigator)
		_code_navigator.queue_free()
		_code_navigator = null
	_nav_injected_parent = null
	
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
	
	# Reload the scene in the editor
	get_editor_interface().reload_scene_from_path(edited_scene_path)
	
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
	get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.6)

## Performs the actual VB6 project import.
## @param path: Full filesystem path to the .vbp file
func _do_import_vbp(path):
	var importer = load("res://addons/visual_gasic/vb6_importer.gd")
	if importer:
		importer.import_project(path)
		get_editor_interface().get_resource_filesystem().scan() # Refresh FileSystem
		_add_to_recent_projects(path)  # Track in recent projects

## Opens a file dialog to select and import a single VB6 form (.frm) file.
## The form will be converted to a Godot scene with an attached .vg script.
func _on_import_vb6_form():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.frm ; VB6 Form Files"])
	fd.connect("file_selected", Callable(self, "_do_import_frm"))
	get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.6)

## Performs the actual VB6 form import.
## Creates a scene in res://start_forms/ and code in res://mixed/
## @param path: Full filesystem path to the .frm file
func _do_import_frm(path):
	var importer = load("res://addons/visual_gasic/vb6_importer.gd")
	if !importer:
		print("Importer script not found")
		return

	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://start_forms"): dir.make_dir("res://start_forms")
	if not dir.dir_exists("res://mixed"): dir.make_dir("res://mixed")
		
	var root = Control.new()
	root.name = path.get_file().get_basename()
	
	# Create Scene Root
	var packed_scene = PackedScene.new()
	# Can't pack yet, need node tree
	
	# We want to create it in the currently open scene or a new scene?
	# Let's creating a new scene file.
	
	var code = importer.import_form(path, root, root)
	
	packed_scene.pack(root)
	var save_path = "res://start_forms/" + root.name + ".tscn"
	ResourceSaver.save(packed_scene, save_path)
	print("Saved Scene to " + save_path)
	
	if code != "":
		var bas_path = "res://mixed/" + root.name + ".vg"
		var f = FileAccess.open(bas_path, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		print("Saved Code to " + bas_path)
		_add_to_recent_projects(bas_path)  # Track in recent projects
		
	get_editor_interface().open_scene_from_path(save_path)

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
	# Now create the Window node - DO NOT attach VG script until after all children and owners are set
	var root = Window.new()
	root.name = form_name
	root.title = form_name
	root.position = Vector2i(10,36)  # Align with canvas origin in editor
	root.size = template.get("size", Vector2(800, 600))
	
	# Add MenuBar FIRST if specified - so _FormBackground comes AFTER and intercepts drops
	if template.get("has_menu", false):
		var menu_bar = MenuBar.new()
		menu_bar.name = "MenuBar"
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
		EditorInterface.set_main_screen_editor("Form Designer")
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
	_form_designer.open_form(tscn_path)
	EditorInterface.set_main_screen_editor("Form Designer")
	print("VisualGasic: Opened '", tscn_path, "' in Form Designer")

## Sets initial split positions for the embedded VB6 IDE layout.
## Called deferred after the layout is added to the scene tree.
func _setup_ide_split_ratios() -> void:
	if not is_instance_valid(_ide_layout):
		return
	# Main horizontal split: Toolbox gets ~200px
	var main_split = _ide_layout.get_node_or_null("MainHSplit")
	if main_split and main_split is HSplitContainer:
		main_split.split_offset = 200
		# Canvas-Right split: right panel gets ~280px from the right
		var canvas_right = main_split.get_node_or_null("CanvasRightSplit")
		if canvas_right and canvas_right is HSplitContainer:
			canvas_right.split_offset = -280
	# Apply VB6 visual styling
	_apply_vb6_theme()
	_restyle_toolbox_buttons()
	_apply_designer_theme()

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

	# NOTE: Theme file overlay disabled — hardcoded defaults above are used.
	# To revisit external theming later, re-enable loading from
	# vg_form_designer_theme.gd here.
	print("VisualGasic: Theme loaded (hardcoded defaults, %d values)" % _theme.size())

## Builds a VB6-style light Theme resource for the entire IDE layout.
## When applied to _ide_layout, this propagates to ALL children — including
## the C++ VisualGasicToolbox (PanelContainer) that would otherwise use
## Godot's dark editor theme.
func _build_vb6_theme() -> Theme:
	var t = Theme.new()
	var bg: Color = _theme.get("panel_background", Color("#F0EDE8"))
	var border: Color = _theme.get("panel_border", Color(0.72, 0.71, 0.68))
	var text_color := Color.BLACK

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
	tab_sel.bg_color = bg
	tab_sel.border_color = border
	tab_sel.border_width_left = 1; tab_sel.border_width_top = 1
	tab_sel.border_width_right = 1; tab_sel.border_width_bottom = 0
	tab_sel.content_margin_left = 8; tab_sel.content_margin_right = 8
	tab_sel.content_margin_top = 4; tab_sel.content_margin_bottom = 4
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_selected", "TabBar", tab_sel)

	var tab_unsel = StyleBoxFlat.new()
	tab_unsel.bg_color = Color(0.85, 0.84, 0.82)
	tab_unsel.border_color = border
	tab_unsel.set_border_width_all(1)
	tab_unsel.content_margin_left = 8; tab_unsel.content_margin_right = 8
	tab_unsel.content_margin_top = 4; tab_unsel.content_margin_bottom = 4
	t.set_stylebox("tab_unselected", "TabContainer", tab_unsel)
	t.set_stylebox("tab_unselected", "TabBar", tab_unsel)

	var tab_hover = StyleBoxFlat.new()
	tab_hover.bg_color = Color(0.95, 0.94, 0.92)
	tab_hover.border_color = border
	tab_hover.border_width_left = 1; tab_hover.border_width_top = 1
	tab_hover.border_width_right = 1; tab_hover.border_width_bottom = 0
	tab_hover.content_margin_left = 8; tab_hover.content_margin_right = 8
	tab_hover.content_margin_top = 4; tab_hover.content_margin_bottom = 4
	t.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	t.set_stylebox("tab_hovered", "TabBar", tab_hover)

	# Tab font colors
	t.set_color("font_selected_color", "TabContainer", text_color)
	t.set_color("font_unselected_color", "TabContainer", Color(0.3, 0.3, 0.3))
	t.set_color("font_hovered_color", "TabContainer", text_color)
	t.set_color("font_selected_color", "TabBar", text_color)
	t.set_color("font_unselected_color", "TabBar", Color(0.3, 0.3, 0.3))
	t.set_color("font_hovered_color", "TabBar", text_color)

	# ── Tree (Project Explorer, Properties Inspector) ──
	var tree_sb = StyleBoxFlat.new()
	tree_sb.bg_color = Color.WHITE
	tree_sb.border_color = border
	tree_sb.set_border_width_all(1)
	t.set_stylebox("panel", "Tree", tree_sb)
	t.set_color("font_color", "Tree", text_color)
	t.set_color("font_selected_color", "Tree", Color.WHITE)

	# ── ItemList ──
	var il_sb = StyleBoxFlat.new()
	il_sb.bg_color = Color.WHITE
	il_sb.border_color = border
	il_sb.set_border_width_all(1)
	t.set_stylebox("panel", "ItemList", il_sb)
	t.set_color("font_color", "ItemList", text_color)

	# ── Label ──
	t.set_color("font_color", "Label", text_color)

	# ── LineEdit (property fields) ──
	var le_sb = StyleBoxFlat.new()
	le_sb.bg_color = Color.WHITE
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
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.95, 0.94, 0.92)
	btn_hover.border_color = border
	btn_hover.set_border_width_all(1)
	btn_hover.content_margin_left = 4; btn_hover.content_margin_right = 4
	btn_hover.content_margin_top = 2; btn_hover.content_margin_bottom = 2
	t.set_stylebox("hover", "Button", btn_hover)
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.88, 0.87, 0.85)
	btn_pressed.border_color = border
	btn_pressed.set_border_width_all(1)
	btn_pressed.content_margin_left = 4; btn_pressed.content_margin_right = 4
	btn_pressed.content_margin_top = 2; btn_pressed.content_margin_bottom = 2
	t.set_stylebox("pressed", "Button", btn_pressed)
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

	return t

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
					btn.custom_minimum_size = Vector2(0, 26)
					btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
					btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
					btn.expand_icon = false

					# Apply custom SVG icon (use icon_key_map for remapped names)
					var icon_key: String = icon_key_map.get(tool_name, tool_name)
					if vb6_icons.has(icon_key):
						btn.icon = vb6_icons[icon_key]

					# ── CRITICAL: Override icon colors to prevent green editor tint ──
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
	file_menu.add_separator()
	file_menu.add_item("Open Project...", 2)
	file_menu.add_separator()
	file_menu.add_item("Save Form", 10)
	file_menu.add_shortcut(_make_shortcut(KEY_S, true), 10)
	file_menu.add_item("Save Form As...", 11)
	file_menu.add_separator()
	file_menu.add_item("Import VB6 Form...", 20)
	file_menu.add_item("Import VB6 Project...", 21)
	file_menu.add_separator()
	file_menu.add_item("Exit to Godot Editor", 99)
	file_menu.id_pressed.connect(_on_vb6_file_menu)
	mb.add_child(file_menu)

	# ── Edit ──
	var edit_menu = PopupMenu.new()
	edit_menu.name = "Edit"
	_style_popup_menu(edit_menu)
	edit_menu.add_item("Undo", 0)
	edit_menu.add_shortcut(_make_shortcut(KEY_Z, true), 0)
	edit_menu.add_item("Redo", 1)
	edit_menu.add_shortcut(_make_shortcut(KEY_Y, true), 1)
	edit_menu.add_separator()
	edit_menu.add_item("Cut", 10)
	edit_menu.add_shortcut(_make_shortcut(KEY_X, true), 10)
	edit_menu.add_item("Copy", 11)
	edit_menu.add_shortcut(_make_shortcut(KEY_C, true), 11)
	edit_menu.add_item("Paste", 12)
	edit_menu.add_shortcut(_make_shortcut(KEY_V, true), 12)
	edit_menu.add_item("Delete", 13)
	edit_menu.add_separator()
	edit_menu.add_item("Select All", 20)
	edit_menu.add_shortcut(_make_shortcut(KEY_A, true), 20)
	edit_menu.id_pressed.connect(_on_vb6_edit_menu)
	mb.add_child(edit_menu)

	# ── View ──
	var view_menu = PopupMenu.new()
	view_menu.name = "View"
	_style_popup_menu(view_menu)
	view_menu.add_item("Code", 0)
	view_menu.add_item("Object", 1)
	view_menu.add_separator()
	view_menu.add_item("Toolbox", 10)
	view_menu.add_item("Project Explorer", 11)
	view_menu.add_item("Properties Window", 12)
	view_menu.add_item("Immediate Window", 13)
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
	format_menu.id_pressed.connect(_on_vb6_format_menu)
	mb.add_child(format_menu)

	# ── Debug ──
	var debug_menu = PopupMenu.new()
	debug_menu.name = "Debug"
	_style_popup_menu(debug_menu)
	debug_menu.add_item("Run Project", 0)
	debug_menu.add_shortcut(_make_shortcut(KEY_F5), 0)
	debug_menu.add_item("Run Current Scene", 1)
	debug_menu.add_shortcut(_make_shortcut(KEY_F6), 1)
	debug_menu.add_separator()
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
	tools_menu.add_separator()
	tools_menu.add_item("Snippet Browser...", 10)
	tools_menu.add_item("Theme Picker...", 11)
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
	help_menu.id_pressed.connect(_on_vb6_help_menu)
	mb.add_child(help_menu)

	return mb

## Creates a Shortcut for use in menu items.
func _make_shortcut(key: Key, ctrl: bool = false) -> Shortcut:
	var ev = InputEventKey.new()
	ev.keycode = key
	ev.ctrl_pressed = ctrl
	var sc = Shortcut.new()
	sc.events = [ev]
	return sc

## Applies VB6/Win95-style contrast styling to a PopupMenu.
func _style_popup_menu(popup: PopupMenu) -> void:
	# Light background panel (Win95 menu style)
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color("#F0F0F0")
	panel_sb.border_width_top = 2
	panel_sb.border_width_bottom = 2
	panel_sb.border_width_left = 2
	panel_sb.border_width_right = 2
	panel_sb.border_color = Color("#808080")
	panel_sb.content_margin_left = 20
	panel_sb.content_margin_right = 12
	panel_sb.content_margin_top = 2
	panel_sb.content_margin_bottom = 2
	popup.add_theme_stylebox_override("panel", panel_sb)

	# Hover / selection highlight (navy blue like classic Windows)
	var hover_sb = StyleBoxFlat.new()
	hover_sb.bg_color = Color("#000080")
	hover_sb.content_margin_left = 20
	hover_sb.content_margin_right = 12
	hover_sb.content_margin_top = 1
	hover_sb.content_margin_bottom = 1
	popup.add_theme_stylebox_override("hover", hover_sb)

	# Separator style
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = Color("#808080")
	sep_sb.content_margin_top = 0
	sep_sb.content_margin_bottom = 0
	popup.add_theme_stylebox_override("separator", sep_sb)

	# Font colors — black on light gray, white on navy hover
	popup.add_theme_color_override("font_color", Color("#000000"))
	popup.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	popup.add_theme_color_override("font_disabled_color", Color("#808080"))
	popup.add_theme_color_override("font_separator_color", Color("#404040"))
	popup.add_theme_color_override("font_accelerator_color", Color("#404040"))

# ── VB6 Menu Bar Handlers ──

func _on_vb6_file_menu(id: int) -> void:
	match id:
		0: _on_add_form()
		1: _on_new_module()
		10: _do_save_form()
		11: _do_save_form_as()
		20: _on_import_vb6_form()
		21: _on_import_vb6_project()
		99: _on_back_to_godot_pressed()

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
		_reload_scene_after_form_save(path)
		fd.queue_free()
	)
	fd.canceled.connect(fd.queue_free)
	get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered()

## After the C++ Form Designer writes a .tscn, force Godot to reload it.
## This ensures Godot's in-memory scene tree matches our save, preventing
## Godot from overwriting our .tscn with its stale version on editor close.
func _reload_scene_after_form_save(tscn_path: String) -> void:
	if tscn_path.is_empty():
		return
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	# Only reload if this is the currently edited scene
	if scene_root.scene_file_path != tscn_path:
		return
	# Defer the reload so the file write completes first
	call_deferred("_deferred_reload_scene", tscn_path)

func _deferred_reload_scene(tscn_path: String) -> void:
	# Tell Godot to reload the scene from disk — now its scene tree matches our save
	EditorInterface.reload_scene_from_path(tscn_path)
	# Re-sync the C++ form designer from the reloaded file
	if is_instance_valid(_form_designer):
		# Clear cached path so _sync re-reads from disk
		_form_designer.open_form(tscn_path)
	print("[VisualGasic] Scene reloaded from disk after save: ", tscn_path)

func _on_vb6_edit_menu(id: int) -> void:
	if not _form_designer:
		return
	match id:
		0: _form_designer.undo()
		1: _form_designer.redo()
		10: _form_designer.cut()
		11: _form_designer.copy()
		12: _form_designer.paste()
		13: _form_designer.remove_selected()
		20: _form_designer.select_all()

func _on_vb6_view_menu(id: int) -> void:
	match id:
		0: # Code view — switch to Script editor
			EditorInterface.set_main_screen_editor("Script")
		1: # Object view — switch back to Form Designer
			EditorInterface.set_main_screen_editor("Form Designer")
		10: pass # Toolbox — already visible
		11: pass # Project Explorer — already visible
		12: pass # Properties — already visible
		13: # Immediate Window — focus it in bottom panel
			if is_instance_valid(immediate_window):
				make_bottom_panel_item_visible(immediate_window)

func _on_vb6_project_menu(id: int) -> void:
	match id:
		0: _on_add_form()
		1: _on_new_module()
		10: _on_proj_props()
		11: _on_components()

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

func _on_vb6_debug_menu(id: int) -> void:
	match id:
		0: EditorInterface.play_main_scene()
		1: EditorInterface.play_current_scene()
		10: EditorInterface.stop_playing_scene()

func _on_vb6_run_menu(id: int) -> void:
	match id:
		0: # Preview Form
			if is_instance_valid(form_preview_toolbar) and form_preview_toolbar.has_method("_on_preview"):
				form_preview_toolbar._on_preview()
		1: # Preview + Debug
			if is_instance_valid(form_preview_toolbar) and form_preview_toolbar.has_method("_on_preview_debug"):
				form_preview_toolbar._on_preview_debug()
		10: pass # Build
		11: EditorInterface.play_main_scene()

func _on_vb6_tools_menu(id: int) -> void:
	match id:
		0: _on_menu_editor()
		1: _on_tab_order()
		2: _on_obj_browser()
		10: _on_open_snippet_browser()
		11: _on_open_theme_picker()
		20: _on_new_custom_control()

func _on_vb6_window_menu(id: int) -> void:
	match id:
		10: _on_toggle_vb6_layout()

func _on_vb6_help_menu(id: int) -> void:
	match id:
		0: OS.shell_open("https://github.com/nickshouse/VisualGasic")
		1: pass # About dialog

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
	var status_text = _form_designer.get_status_text() if _form_designer.has_method("get_status_text") else ""
	var grid_size = _form_designer.get_grid_size() if _form_designer.has_method("get_grid_size") else 8
	_status_bar.text = "  %s  |  %s  |  Grid: %d px" % [form_name, status_text, grid_size]

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

## Syncs the currently edited scene into the C++ Form Designer canvas.
## Called by _make_visible(true) when user switches to Form Designer tab.
## Reads the scene root's .tscn path and loads it into the designer.
func _sync_scene_to_form_designer() -> void:
	if not _form_designer:
		return
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		return
	var scene_path = scene_root.scene_file_path
	if scene_path.is_empty():
		scene_path = scene_root.get_meta("_edit_scene_file_path", "") if scene_root.has_meta("_edit_scene_file_path") else ""
	if scene_path.is_empty():
		return
	if not scene_path.ends_with(".tscn") and not scene_path.ends_with(".scn"):
		return
	# Only reload if the path changed (avoid re-parsing the same scene)
	if _form_designer.get_form_path() == scene_path:
		return
	_form_designer.open_form(scene_path)
	print("VisualGasic: Synced scene '", scene_path, "' into Form Designer")

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
	pass  # Could update title bar asterisk, etc.

## Signal: Right-click on the form designer canvas.
## Shows a context menu with type-specific actions.
## @param index: Control index (-1 if right-clicked empty form area)
## @param position: Global screen position for popup placement
var _fd_context_menu: PopupMenu = null
var _fd_context_ctrl_index: int = -1
var _editing_external_scene: bool = false
var _saving_external: bool = false  ## reentrancy guard for _save_external_data

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
		_fd_context_menu.add_item("View Code (" + ctrl_name + "_Click)", 10)
		_fd_context_menu.add_separator()
		_fd_context_menu.add_item("Cut", 31)
		_fd_context_menu.add_item("Copy", 32)
		_fd_context_menu.add_item("Delete", 30)
		_fd_context_menu.add_separator()
		_fd_context_menu.add_item("Edit Control Scene...", 20)
		var idx = _fd_context_menu.get_item_index(20)
		_fd_context_menu.set_item_disabled(idx, true)
		_fd_context_menu.add_separator()
		_fd_context_menu.add_item("Properties", 40)
	else:
		# Right-clicked on empty form area
		_fd_context_menu.add_item("View Code", 11)
		_fd_context_menu.add_item("Paste", 50)
		_fd_context_menu.add_separator()
		_fd_context_menu.add_item("Form Properties", 41)
	
	_fd_context_menu.id_pressed.connect(_on_fd_context_menu_pressed)
	get_editor_interface().get_base_control().add_child(_fd_context_menu)
	_fd_context_menu.popup(Rect2(position, Vector2.ZERO))

func _on_fd_context_menu_pressed(id: int) -> void:
	var index = _fd_context_ctrl_index
	match id:
		10: # View Code (control event handler)
			_on_fd_control_double_clicked(index)
		11: # View Code (form-level)
			if _form_designer:
				var form_path = _form_designer.get_form_path()
				if not form_path.is_empty():
					var vg_path = form_path.get_basename() + ".vg"
					get_editor_interface().edit_resource(load(vg_path) if ResourceLoader.exists(vg_path) else null)
		20: # Edit Control Scene
			_edit_control_scene(index)
		30: # Delete
			if _form_designer:
				_form_designer.remove_selected()
		31: # Cut
			if _form_designer:
				_form_designer.cut()
		32: # Copy
			if _form_designer:
				_form_designer.copy()
		40: # Properties (control)
			if is_instance_valid(_properties_inspector) and _properties_inspector.has_method("show_control_properties") and _form_designer:
				var info = _form_designer.get_control_info(index)
				_properties_inspector.show_control_properties(info, _form_designer, index)
		41: # Form Properties
			if is_instance_valid(_properties_inspector) and _properties_inspector.has_method("show_form_properties") and _form_designer:
				_properties_inspector.show_form_properties(_form_designer)
		50: # Paste
			if _form_designer:
				_form_designer.paste()
		100: # Edit Menus (MenuBar-specific)
			_open_menu_editor_for_fd(index)

## Opens a control's prototype scene for editing in the Godot scene editor.
## Built-in prototypes are copied to a user-editable location first.
func _edit_control_scene(index: int) -> void:
	if not _form_designer:
		return
	var info = _form_designer.get_control_info(index)
	var scene_path: String = info.get("scene_path", "")
	var ctrl_name: String = info.get("name", "")
	var ctrl_type: String = info.get("type", "")
	
	# Fall back to prototype if scene_path is empty or the file was deleted
	if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
		scene_path = "res://addons/visual_gasic/prototypes/" + ctrl_type + ".tscn"
		if not FileAccess.file_exists(scene_path):
			push_error("No prototype scene found for control type '" + ctrl_type + "'")
			return
		_form_designer.set_control_property(index, "scene_path", scene_path)
	
	# Check if this is a built-in prototype (under addons/visual_gasic/)
	var is_builtin := scene_path.begins_with("res://addons/visual_gasic/")
	var edit_path := scene_path
	
	if is_builtin:
		# Copy to a user-editable location: res://custom_controls/<ControlName>.tscn
		var dir = DirAccess.open("res://")
		if dir and not dir.dir_exists("custom_controls"):
			dir.make_dir("custom_controls")
		
		var basename = scene_path.get_file()  # e.g. "MenuBar.tscn"
		edit_path = "res://custom_controls/" + ctrl_name + ".tscn"
		
		if not FileAccess.file_exists(edit_path):
			# Copy the prototype
			var src = FileAccess.open(scene_path, FileAccess.READ)
			if src:
				var content = src.get_as_text()
				src.close()
				var dst = FileAccess.open(edit_path, FileAccess.WRITE)
				if dst:
					dst.store_string(content)
					dst.close()
					print("VisualGasic: Copied built-in prototype to ", edit_path)
				else:
					push_error("Cannot write to " + edit_path)
					return
			else:
				push_error("Cannot read " + scene_path)
				return
		
		# Update the control's scene_path to point to the custom copy
		_form_designer.set_control_property(index, "scene_path", edit_path)
		# Also update scene_path in the control info struct via C++ API
		# (The C++ set_control_property stores in the properties dict,
		#  but scene_path is a separate field — we need a dedicated setter)
	
	# Open the scene in Godot's editor and switch to 2D
	_editing_external_scene = true
	get_editor_interface().open_scene_from_path(edit_path)
	EditorInterface.set_main_screen_editor("2D")
	print("VisualGasic: Opened control scene: ", edit_path)

## Signal: A control was double-clicked — generate event handler stub.
func _on_fd_control_double_clicked(index: int) -> void:
	if not _form_designer:
		return
	var info = _form_designer.get_control_info(index)
	var ctrl_name = info.get("name", "")
	var ctrl_type = info.get("type", "")
	if ctrl_name.is_empty():
		push_warning("VisualGasic: Double-click — control has no name")
		return
	# Determine default event suffix based on type
	var event_suffix = "Click"
	if ctrl_type in ["LineEdit", "TextEdit"]:
		event_suffix = "Change"
	elif ctrl_type in ["HScrollBar", "VScrollBar", "HSlider", "VSlider"]:
		event_suffix = "Change"
	# Get form path — try multiple fallbacks
	var form_path = _form_designer.get_form_path()
	if form_path.is_empty():
		# Try syncing from the currently edited scene
		_sync_scene_to_form_designer()
		form_path = _form_designer.get_form_path()
	if form_path.is_empty():
		# Still empty — auto-save form to a default location
		var form_name = _form_designer.get_form_name() if _form_designer.has_method("get_form_name") else "Form1"
		var default_path = "res://" + form_name + ".tscn"
		print("VisualGasic: Form not saved yet — auto-saving to ", default_path)
		_form_designer.save_form_as(default_path)
		form_path = _form_designer.get_form_path()
	if form_path.is_empty():
		push_warning("VisualGasic: Cannot open code — form has no save path. Save the form first (File > Save).")
		return
	var vg_path = form_path.get_basename() + ".vg"
	var sub_name = ctrl_name + "_" + event_suffix
	print("VisualGasic: Double-click → opening ", sub_name, " in ", vg_path)
	_open_or_create_event_handler(vg_path, sub_name)

## Opens the .vg script and creates/navigates to the given Sub stub.
## Reuses the existing _open_and_inject infrastructure.
func _open_or_create_event_handler(vg_path: String, sub_name: String) -> void:
	# Split sub_name into obj + event parts for _open_and_inject
	var parts = sub_name.split("_", true, 1)
	if parts.size() < 2:
		return
	var obj = parts[0]
	var event = parts[1]

	# Create file if missing
	if not FileAccess.file_exists(vg_path):
		var f = FileAccess.open(vg_path, FileAccess.WRITE)
		if f:
			f.store_string("' Visual Gasic Form Script\nOption Explicit\n\n")
			f.close()
		get_editor_interface().get_resource_filesystem().scan()

	_open_and_inject(vg_path, obj, event)

## Called from Project > Tools > Toggle VG IDE Layout menu item.
func _on_toggle_vb6_layout():
	if is_instance_valid(_layout_manager):
		_layout_manager.toggle()
	else:
		push_warning("VisualGasic: Layout manager not available")

## Opens the Snippet Browser dialog (v2.4.1)
func _on_open_snippet_browser():
	if _snippet_browser:
		_snippet_browser.popup_centered()

## Inserts a snippet at the current cursor position in the code editor
func _on_snippet_insert(text: String):
	if _current_code_edit and is_instance_valid(_current_code_edit):
		var line = _current_code_edit.get_caret_line()
		var col = _current_code_edit.get_caret_column()
		_current_code_edit.insert_text_at_caret(text)

## Opens the Theme Picker dialog (v2.4.1)
func _on_open_theme_picker():
	if _theme_picker:
		_theme_picker.popup_centered()

## Applies a new theme to the active code editor (v2.4.1)
func _on_theme_changed(theme_name: String):
	var theme_mgr_script = load("res://addons/visual_gasic/vg_theme_manager.gd")
	if theme_mgr_script and _current_code_edit and is_instance_valid(_current_code_edit):
		theme_mgr_script.apply_to_code_edit(_current_code_edit)
		print("VisualGasic: Applied theme '", theme_name, "'")


## Updates the Form Designer button pressed state when mode changes.
func _on_vb6_mode_changed(is_vb6: bool) -> void:
	_update_main_screen_buttons(is_vb6)

## Signal: A tool was clicked in the Toolbox (click-to-place mode).
## Sets the FormDesigner's active tool so the next click on the canvas
## creates the control at the click position.
func _on_toolbox_tool_selected(ctrl_class: String, scene_path: String) -> void:
	if not is_instance_valid(_form_designer):
		return
	if ctrl_class.is_empty():
		_form_designer.clear_active_tool()
	else:
		_form_designer.set_active_tool(ctrl_class, scene_path)
	print("VisualGasic: Toolbox → FormDesigner active tool = '", ctrl_class, "'")

## Button pressed-state is now handled by Godot's built-in main screen system.
func _update_main_screen_buttons(_form_designer_active: bool) -> void:
	pass  # Godot manages the auto-created button state

## Finds the HBoxContainer holding the main screen buttons (2D, 3D, Script, AssetLib).
func _find_main_screen_bar() -> HBoxContainer:
	var base = get_editor_interface().get_base_control()
	return _search_main_screen_bar(base)

func _search_main_screen_bar(node: Node) -> HBoxContainer:
	if node is HBoxContainer:
		for child in node.get_children():
			if child is Button and child.text == "AssetLib":
				return node
	for child in node.get_children():
		var result = _search_main_screen_bar(child)
		if result:
			return result
	return null

## Applies icon + font styling to the Form Designer button.
## Copies the exact font from a sibling button so it matches perfectly,
## then adds a subtle gold tint so it stands out.
func _style_form_designer_button() -> void:
	if not is_instance_valid(_vb6_toggle_button):
		return
	
	# Copy font + font size from a sibling button (e.g. AssetLib) for exact match
	var bar = _vb6_toggle_button.get_parent()
	if bar:
		for child in bar.get_children():
			if child is Button and child != _vb6_toggle_button and child.text != "":
				var font = child.get_theme_font("font")
				var font_size = child.get_theme_font_size("font_size")
				if font:
					_vb6_toggle_button.add_theme_font_override("font", font)
				if font_size > 0:
					_vb6_toggle_button.add_theme_font_size_override("font_size", font_size)
				break
	
	# Get editor icon (Window = form shape)
	var theme = get_editor_interface().get_base_control().get_theme()
	if theme:
		var icon = theme.get_icon("Window", "EditorIcons")
		if not icon:
			icon = theme.get_icon("Control", "EditorIcons")
		if icon:
			_vb6_toggle_button.icon = icon
	
	# Gold tint to stand out (customizable via vg_form_designer_theme.gd)
	_vb6_toggle_button.add_theme_color_override("font_color", _theme.get("toggle_button_text", Color(0.95, 0.82, 0.2)))
	_vb6_toggle_button.add_theme_color_override("font_hover_color", _theme.get("toggle_button_hover", Color(1.0, 0.9, 0.3)))
	_vb6_toggle_button.add_theme_color_override("font_pressed_color", _theme.get("toggle_button_pressed", Color(1.0, 1.0, 0.5)))
	_vb6_toggle_button.add_theme_color_override("font_focus_color", _theme.get("toggle_button_pressed", Color(1.0, 1.0, 0.5)))

func _register_vg_file_icon() -> void:
	"""Register the custom .vg file icon so it appears in the FileSystem dock."""
	var icon_path := "res://addons/visual_gasic/vg_file_icon.svg"
	if not ResourceLoader.exists(icon_path):
		return
	var icon_texture: Texture2D = load(icon_path)
	if icon_texture == null:
		return
	# Inject into the editor theme so the FileSystem dock picks it up
	var theme := get_editor_interface().get_base_control().get_theme()
	if theme:
		# Godot maps file extension icons via "res://path.ext" → icon lookup
		# The most reliable way is overriding the GDExtension script icon
		theme.set_icon("VisualGasicScript", "EditorIcons", icon_texture)
		print("VisualGasic: Registered .vg file icon")

# =============================================================================
# FORM & MODULE CREATION
# =============================================================================

## Opens a dialog to add a new Form (scene + .vg script) — like VB6 Project > Add Form.
## Delegates to the full New Form dialog with VB6, Game, Platform, and Custom templates.
func _on_add_form():
	_on_new_form()

## Creates a new form: .tscn scene file + companion .vg script.
## @param form_name: Name for the form (without extension)
func _create_new_form(form_name: String):
	# Generate unique filenames
	var base_path = "res://" + form_name
	var scene_path = base_path + ".tscn"
	var script_path = base_path + ".vg"
	var idx = 1
	while FileAccess.file_exists(scene_path) or FileAccess.file_exists(script_path):
		idx += 1
		form_name = form_name.rstrip("0123456789") + str(idx)
		base_path = "res://" + form_name
		scene_path = base_path + ".tscn"
		script_path = base_path + ".vg"

	# Create the .vg script with VB6-style form boilerplate
	var vg_code = "' %s — Visual Gasic Form\n" % form_name
	vg_code += "' Created: %s\n\n" % Time.get_datetime_string_from_system()
	vg_code += "Option Explicit\n\n"
	vg_code += "Sub Form_Load()\n"
	vg_code += "    ' Initialize the form here\n"
	vg_code += "    Me.Caption = \"%s\"\n" % form_name
	vg_code += "End Sub\n\n"
	vg_code += "Sub Form_Unload(Cancel As Integer)\n"
	vg_code += "    ' Clean up before the form closes\n"
	vg_code += "End Sub\n"

	var f = FileAccess.open(script_path, FileAccess.WRITE)
	if not f:
		push_error("VisualGasic: Could not create form script: " + script_path)
		return
	f.store_string(vg_code)
	f.close()

	# Create a minimal .tscn scene (Panel root with the form name)
	var tscn_content = '[gd_scene format=3]\n\n'
	tscn_content += '[node name="%s" type="Panel"]\n' % form_name
	tscn_content += 'anchors_preset = 15\n'
	tscn_content += 'anchor_right = 1.0\n'
	tscn_content += 'anchor_bottom = 1.0\n'
	tscn_content += 'grow_horizontal = 2\n'
	tscn_content += 'grow_vertical = 2\n'

	var sf = FileAccess.open(scene_path, FileAccess.WRITE)
	if not sf:
		push_error("VisualGasic: Could not create form scene: " + scene_path)
		return
	sf.store_string(tscn_content)
	sf.close()

	print("VisualGasic: Created form '%s' at %s + %s" % [form_name, scene_path, script_path])

	# Refresh filesystem and open the scene
	get_editor_interface().get_resource_filesystem().scan()

	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(func():
		timer.queue_free()
		# Open the scene in the editor
		get_editor_interface().open_scene_from_path(scene_path)
		# Switch to Form Designer
		EditorInterface.set_main_screen_editor("Form Designer")
		# Refresh Project Explorer
		if is_instance_valid(_project_explorer) and _project_explorer.has_method("refresh"):
			_project_explorer.refresh()
		print("VisualGasic: Opened form '%s' in Form Designer" % form_name)
	)
	get_editor_interface().get_base_control().add_child(timer)
	timer.start()

# =============================================================================

## Opens a dialog to create a new Visual Gasic module (.vg code file).
## Modules are standalone code files without a form — like VB6 .bas modules.
func _on_new_module():
	var dlg = AcceptDialog.new()
	dlg.title = "New Module"
	dlg.dialog_text = "Enter a name for the new module:"
	dlg.ok_button_text = "Create"
	
	var vbox = VBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = "Module Name:"
	vbox.add_child(name_label)
	
	var name_edit = LineEdit.new()
	name_edit.text = "Module1"
	name_edit.placeholder_text = "Module1"
	name_edit.select_all_on_focus = true
	vbox.add_child(name_edit)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var type_label = Label.new()
	type_label.text = "Module Type:"
	vbox.add_child(type_label)
	
	var type_option = OptionButton.new()
	type_option.add_item("Standard Module (.bas style)")
	type_option.add_item("Class Module")
	type_option.add_item("Game Module")
	type_option.add_item("Utility Module")
	vbox.add_child(type_option)
	
	dlg.add_child(vbox)
	dlg.min_size = Vector2i(350, 200)
	
	get_editor_interface().get_base_control().add_child(dlg)
	
	dlg.confirmed.connect(func():
		var module_name = name_edit.text.strip_edges()
		var module_type = type_option.selected
		dlg.queue_free()
		if not module_name.is_empty():
			_create_new_module(module_name, module_type)
	)
	
	dlg.canceled.connect(func():
		dlg.queue_free()
	)
	
	dlg.popup_centered()
	name_edit.grab_focus()

## Creates a new .vg module file with boilerplate code.
## @param module_name: Name for the module (without extension)
## @param module_type: 0=Standard, 1=Class, 2=Game, 3=Utility
func _create_new_module(module_name: String, module_type: int):
	# Generate unique filename
	var path = "res://" + module_name + ".vg"
	var idx = 1
	while FileAccess.file_exists(path):
		idx += 1
		module_name = module_name.rstrip("0123456789") + str(idx)
		path = "res://" + module_name + ".vg"
	
	var code = _generate_module_code(module_name, module_type)
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("VisualGasic: Could not create module file: " + path)
		return
	f.store_string(code)
	f.close()
	
	print("VisualGasic: Created module at ", path)
	
	# Refresh filesystem and open the script
	get_editor_interface().get_resource_filesystem().scan()
	
	# Defer opening to allow filesystem scan
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.one_shot = true
	timer.timeout.connect(func():
		timer.queue_free()
		var script = load(path)
		if script:
			get_editor_interface().edit_resource(script)
			print("VisualGasic: Opened module for editing: ", path)
		_add_to_recent_projects(path)
	)
	get_editor_interface().get_base_control().add_child(timer)
	timer.start()

## Generates boilerplate code for a new module.
## @param module_name: Name of the module
## @param module_type: 0=Standard, 1=Class, 2=Game, 3=Utility
func _generate_module_code(module_name: String, module_type: int) -> String:
	match module_type:
		0:  # Standard Module (.bas style)
			return """' %s.vg - Standard Module
' A standard code module (like VB6 .bas files)
' Contains reusable functions and subroutines
Option Explicit

' Module-level variables
Dim initialized As Boolean

' ====== Public Functions ======

Sub Main()
    ' Entry point for the module
    Print "%s module loaded"
    initialized = True
End Sub

Function GetModuleName() As String
    GetModuleName = "%s"
End Function

' ====== Helper Functions ======

' Add your module functions below

""" % [module_name, module_name, module_name]
		1:  # Class Module
			return """' %s.vg - Class Module
' A class-style module with initialization and cleanup
Option Explicit

' Private module data
Dim m_name As String
Dim m_initialized As Boolean

' ====== Lifecycle ======

Sub Class_Initialize()
    ' Called when module is first loaded
    m_name = "%s"
    m_initialized = True
    Print m_name & " initialized"
End Sub

Sub Class_Terminate()
    ' Called when module is unloaded
    m_initialized = False
    Print m_name & " terminated"
End Sub

' ====== Properties ======

Function GetName() As String
    GetName = m_name
End Function

Function IsInitialized() As Boolean
    IsInitialized = m_initialized
End Function

' ====== Methods ======

' Add your class methods below

""" % [module_name, module_name]
		2:  # Game Module
			return """' %s.vg - Game Module
' Game logic module with state management
Option Explicit

' Game state variables
Dim score As Integer
Dim lives As Integer
Dim level As Integer
Dim gameRunning As Boolean

' ====== Game Lifecycle ======

Sub Game_Init()
    score = 0
    lives = 3
    level = 1
    gameRunning = True
    Print "Game initialized - Level " & level
End Sub

Sub Game_Update()
    ' Called each frame - put game logic here
    If Not gameRunning Then Exit Sub
    
    ' Check for input
    If Input.IsActionJustPressed("ui_accept") Then
        score = score + 10
        Print "Score: " & score
    End If
End Sub

Sub Game_Reset()
    Game_Init()
    Print "Game reset!"
End Sub

' ====== Score Management ======

Function GetScore() As Integer
    GetScore = score
End Function

Sub AddScore(points As Integer)
    score = score + points
    
    ' Level up every 100 points
    If score >= level * 100 Then
        level = level + 1
        Print "Level Up! Now at level " & level
    End If
End Sub

Sub LoseLife()
    lives = lives - 1
    Print "Lives remaining: " & lives
    If lives <= 0 Then
        gameRunning = False
        Print "Game Over! Final Score: " & score
    End If
End Sub

""" % [module_name]
		3:  # Utility Module
			return """' %s.vg - Utility Module
' Common utility functions
Option Explicit

' ====== String Utilities ======

Function PadLeft(s As String, totalWidth As Integer, padChar As String) As String
    Dim result As String
    result = s
    Do While Len(result) < totalWidth
        result = padChar & result
    Loop
    PadLeft = result
End Function

Function PadRight(s As String, totalWidth As Integer, padChar As String) As String
    Dim result As String
    result = s
    Do While Len(result) < totalWidth
        result = result & padChar
    Loop
    PadRight = result
End Function

' ====== Math Utilities ======

Function Clamp(value As Double, minVal As Double, maxVal As Double) As Double
    If value < minVal Then
        Clamp = minVal
    ElseIf value > maxVal Then
        Clamp = maxVal
    Else
        Clamp = value
    End If
End Function

Function Lerp(a As Double, b As Double, t As Double) As Double
    Lerp = a + (b - a) * t
End Function

Function RandRange(minVal As Integer, maxVal As Integer) As Integer
    RandRange = Int(Rnd() * (maxVal - minVal + 1)) + minVal
End Function

' ====== Array Utilities ======

Function ArrayContains(arr() As Variant, value As Variant) As Boolean
    Dim i As Integer
    For i = LBound(arr) To UBound(arr)
        If arr(i) = value Then
            ArrayContains = True
            Exit Function
        End If
    Next i
    ArrayContains = False
End Function

""" % [module_name]
		_:
			return "' %s.vg\nOption Explicit\n\nSub Main()\n    ' Your code here\nEnd Sub\n" % [module_name]

# =============================================================================
# EDITOR DIALOGS
# =============================================================================

## Opens the visual Menu Editor for the selected MenuBar node.
## Allows drag-and-drop menu item arrangement and property editing.
## Works with both Form Designer MenuBar controls and real scene tree MenuBars.
func _on_menu_editor():
	# First, check if we have a Form Designer MenuBar selected (design-time)
	if is_instance_valid(_form_designer):
		var mb_index := -1
		# Look for a selected MenuBar control
		for i in range(_form_designer.get_control_count()):
			var info = _form_designer.get_control_info(i)
			if info.get("type", "") == "MenuBar" and info.get("selected", false):
				mb_index = i
				break
		# If none selected, find the first MenuBar on the form
		if mb_index < 0:
			for i in range(_form_designer.get_control_count()):
				var info = _form_designer.get_control_info(i)
				if info.get("type", "") == "MenuBar":
					mb_index = i
					break
		if mb_index >= 0:
			_open_menu_editor_for_fd(mb_index)
			return
	
	# Fallback: try Godot scene tree selection (runtime/scene editing)
	var selected = get_editor_interface().get_selection().get_selected_nodes()
	if not selected.is_empty() and selected[0] is MenuBar:
		var dlg = load("res://addons/visual_gasic/menu_editor.gd").new()
		dlg.set_menu_bar(selected[0])
		dlg.menu_applied.connect(_on_menu_applied.bind(selected[0]))
		get_editor_interface().get_base_control().add_child(dlg)
		dlg.popup_centered()
		return
	
	push_error("No MenuBar found. Add a MenuBar to the form first, or select one in the Scene Tree.")

## Opens the Menu Editor for a form designer MenuBar control by index.
## Creates a temporary real MenuBar from stored properties, edits it,
## and serializes the result back to the form designer on apply.
func _open_menu_editor_for_fd(fd_index: int) -> void:
	# Build a temporary real MenuBar from stored menu data
	var temp_mb = MenuBar.new()
	temp_mb.name = "TempMenuBar"
	
	# Load existing menu structure from the control's properties
	var menu_data = _form_designer.get_control_property(fd_index, "_menu_data")
	if menu_data is Array and menu_data.size() > 0:
		_rebuild_menubar_from_data(temp_mb, menu_data)
	else:
		# No stored menu data yet — add default File/Edit/View
		for menu_name in ["File", "Edit", "View"]:
			var popup = PopupMenu.new()
			popup.name = menu_name
			temp_mb.add_child(popup)
	
	# Add to tree temporarily so signals work
	get_editor_interface().get_base_control().add_child(temp_mb)
	temp_mb.visible = false
	
	# Open menu editor
	var dlg = load("res://addons/visual_gasic/menu_editor.gd").new()
	dlg.set_menu_bar(temp_mb)
	dlg.menu_applied.connect(_on_fd_menu_applied.bind(fd_index, temp_mb))
	dlg.close_requested.connect(func(): temp_mb.queue_free())
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

## Called when the Menu Editor applies changes back to a form designer MenuBar.
## Serializes the MenuBar's PopupMenu hierarchy into the control's properties.
func _on_fd_menu_applied(fd_index: int, temp_mb: MenuBar) -> void:
	var menu_data: Array = []
	for i in range(temp_mb.get_child_count()):
		var popup = temp_mb.get_child(i)
		if popup is PopupMenu:
			menu_data.append(_serialize_popup_menu(popup))
	# Store the menu structure in the form designer control's properties
	_form_designer.set_control_property(fd_index, "_menu_data", menu_data)
	# Update the design-time label to reflect actual menu names
	var labels := PackedStringArray()
	for m in menu_data:
		labels.append(m.get("name", "?"))
	_form_designer.set_control_property(fd_index, "_menu_labels", "|".join(labels))
	print("Menu Editor: Saved ", menu_data.size(), " menus to form designer control #", fd_index)
	# Clean up the temporary MenuBar
	temp_mb.queue_free()

## Serializes a PopupMenu and its items into a Dictionary.
func _serialize_popup_menu(popup: PopupMenu) -> Dictionary:
	var result := {
		"name": popup.name,
		"items": []
	}
	for i in range(popup.item_count):
		var item := {
			"text": popup.get_item_text(i),
			"separator": popup.is_item_separator(i),
			"checked": popup.is_item_checked(i),
			"disabled": popup.is_item_disabled(i),
		}
		# Check for submenus
		var sub_name = popup.get_item_submenu(i)
		if not sub_name.is_empty():
			var sub_popup = popup.get_node_or_null(NodePath(sub_name))
			if sub_popup is PopupMenu:
				item["submenu"] = _serialize_popup_menu(sub_popup)
		result["items"].append(item)
	return result

## Rebuilds a real MenuBar from serialized menu data.
func _rebuild_menubar_from_data(mb: MenuBar, menu_data: Array) -> void:
	for menu_dict in menu_data:
		if not menu_dict is Dictionary:
			continue
		var popup = PopupMenu.new()
		popup.name = menu_dict.get("name", "Menu")
		_rebuild_popup_items(popup, menu_dict.get("items", []))
		mb.add_child(popup)

## Rebuilds PopupMenu items from serialized item data.
func _rebuild_popup_items(popup: PopupMenu, items: Array) -> void:
	for item_dict in items:
		if not item_dict is Dictionary:
			continue
		if item_dict.get("separator", false):
			popup.add_separator()
		else:
			var text: String = item_dict.get("text", "")
			popup.add_item(text)
			var idx = popup.item_count - 1
			if item_dict.get("checked", false):
				popup.set_item_checked(idx, true)
			if item_dict.get("disabled", false):
				popup.set_item_disabled(idx, true)
			# Handle submenus
			if item_dict.has("submenu"):
				var sub_data: Dictionary = item_dict["submenu"]
				var sub_popup = PopupMenu.new()
				sub_popup.name = sub_data.get("name", "SubMenu")
				_rebuild_popup_items(sub_popup, sub_data.get("items", []))
				popup.add_child(sub_popup)
				popup.set_item_submenu(idx, sub_popup.name)

## Callback when menu changes are applied from the Menu Editor.
## Forces the editor to refresh the MenuBar display.
## @param menu_bar: The MenuBar that was modified
func _on_menu_applied(menu_bar: MenuBar):
	# Force editor to update
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(menu_bar)
	get_editor_interface().edit_node(menu_bar)

## Opens the Project Properties dialog.
## Configure app name, version, icon, and other project settings.
func _on_proj_props():
	var dlg = load("res://addons/visual_gasic/project_properties.gd").new()
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

## Opens the Object Browser.
## Browse available classes, methods, properties, and constants.
func _on_obj_browser():
	var dlg = load("res://addons/visual_gasic/object_browser.gd").new()
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

## Opens the Tab Order Editor.
## Set the focus order for controls in a form (like VB6 TabIndex).
func _on_tab_order():
	var root = get_editor_interface().get_selected_paths() # Wait, get_edited_scene_root()
	var sel = get_editor_interface().get_selection().get_selected_nodes()
	
	var target = null
	if sel.size() > 0:
		target = sel[0]
	else:
		target = get_editor_interface().get_edited_scene_root()
		
	if not target:
		print("Select a container or form to edit tab order.")
		return
		
	var dlg = load("res://addons/visual_gasic/tab_order_editor.gd").new()
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.set_root(target)
	dlg.popup_centered()

## Opens the Components dialog.
## Add/remove VB6-style components and custom controls to the toolbox.
func _on_components():
	var dlg = load("res://addons/visual_gasic/components_dialog.gd").new()
	dlg.components_changed.connect(_on_components_changed)
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

# =============================================================================
# NEW CUSTOM CONTROL WIZARD
# =============================================================================

## Opens the "New Custom Control" wizard dialog.
## Lets user choose a name and root node type, then generates a .tscn file,
## registers it in the Components config, and refreshes the toolbox.
func _on_new_custom_control():
	var dlg = AcceptDialog.new()
	dlg.title = "New Custom Control"
	dlg.ok_button_text = "Create"
	dlg.size = Vector2i(380, 200)

	# Build a small form inside the dialog
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(340, 0)
	dlg.add_child(vbox)

	# Name field
	var name_label = Label.new()
	name_label.text = "Control Name:"
	vbox.add_child(name_label)

	var name_edit = LineEdit.new()
	name_edit.text = "MyCustomControl"
	name_edit.placeholder_text = "e.g. WobblyButton"
	name_edit.select_all_on_focus = true
	vbox.add_child(name_edit)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	# Root node type
	var type_label = Label.new()
	type_label.text = "Root Node Type:"
	vbox.add_child(type_label)

	var type_option = OptionButton.new()
	type_option.add_item("Control", 0)
	type_option.add_item("Panel", 1)
	type_option.add_item("PanelContainer", 2)
	type_option.add_item("HBoxContainer", 3)
	type_option.add_item("VBoxContainer", 4)
	type_option.add_item("MarginContainer", 5)
	type_option.add_item("Button", 6)
	type_option.add_item("TextureRect", 7)
	vbox.add_child(type_option)

	# Info label
	var info = Label.new()
	info.text = "Saves to res://custom_controls/ and adds to Toolbox."
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vbox.add_child(info)

	dlg.confirmed.connect(func():
		var ctrl_name = name_edit.text.strip_edges()
		if ctrl_name.is_empty():
			push_warning("VisualGasic: Custom control name cannot be empty.")
			dlg.queue_free()
			return

		# Sanitize: remove spaces, ensure PascalCase-friendly
		ctrl_name = ctrl_name.replace(" ", "")

		var root_types := ["Control", "Panel", "PanelContainer", "HBoxContainer",
						   "VBoxContainer", "MarginContainer", "Button", "TextureRect"]
		var root_type: String = root_types[type_option.selected]

		_create_custom_control_scene(ctrl_name, root_type)
		dlg.queue_free()
	)

	dlg.canceled.connect(func():
		dlg.queue_free()
	)

	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

## Creates a minimal .tscn file for a new custom control, registers it, and refreshes the toolbox.
## @param ctrl_name: The name of the new custom control (e.g. "WobblyButton")
## @param root_type: The Godot node type for the root (e.g. "Panel")
func _create_custom_control_scene(ctrl_name: String, root_type: String) -> void:
	var dir_path = "res://custom_controls"
	var scene_path = dir_path + "/" + ctrl_name + ".tscn"

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Check if file already exists
	if FileAccess.file_exists(scene_path):
		push_warning("VisualGasic: '" + scene_path + "' already exists. Skipping creation.")
		return

	# Generate minimal .tscn content
	var tscn_content := '[gd_scene format=3]\n\n'
	tscn_content += '[node name="' + ctrl_name + '" type="' + root_type + '"]\n'
	# Give it a visible default size
	if root_type in ["Control", "Panel", "PanelContainer", "MarginContainer",
					  "HBoxContainer", "VBoxContainer", "TextureRect", "Button"]:
		tscn_content += 'custom_minimum_size = Vector2(100, 60)\n'

	# Write the .tscn file
	var f = FileAccess.open(scene_path, FileAccess.WRITE)
	if not f:
		push_error("VisualGasic: Failed to write " + scene_path)
		return
	f.store_string(tscn_content)
	f.close()

	# Register in Components config
	_register_custom_control_in_config(ctrl_name, scene_path)

	# Refresh toolbox
	_on_components_changed()

	# Tell the editor to rescan so the new file appears in FileSystem dock
	EditorInterface.get_resource_filesystem().scan()

	print("VisualGasic: Created custom control '", ctrl_name, "' at ", scene_path)
	print("VisualGasic: Design it in Godot's Scene tab, then use it in your forms!")

## Registers a new custom control in the custom_components.cfg file.
## @param ctrl_name: The display name
## @param scene_path: Path to the .tscn file
func _register_custom_control_in_config(ctrl_name: String, scene_path: String) -> void:
	var config = ConfigFile.new()
	var cfg_path = "res://addons/visual_gasic/custom_components.cfg"
	if FileAccess.file_exists(cfg_path):
		config.load(cfg_path)

	# Save as a custom component (enabled by default)
	var data := {
		"name": ctrl_name,
		"scene": scene_path,
		"icon": "Control",
		"class": "Control",
		"enabled": true,
		"category": "2D"
	}
	config.set_value("custom", ctrl_name, data)
	config.save(cfg_path)

## Called when a .tscn file is dragged from the FileSystem dock onto the form designer canvas.
## Auto-registers the scene as a custom component and refreshes the toolbox.
## @param scene_path: The res:// path of the dropped .tscn file
## @param control_name: The inferred control name (filename without extension)
func _on_fd_scene_file_dropped(scene_path: String, control_name: String) -> void:
	print("VisualGasic: Scene file dropped on canvas: ", scene_path, " → ", control_name)
	# Register in config if not already present
	_register_custom_control_in_config(control_name, scene_path)
	# Refresh toolbox so the new control appears
	_on_components_changed()
	# Generate a preview texture for design-time rendering
	_generate_preview_for_custom_control(control_name, scene_path)

# =============================================================================
# THUMBNAIL / PREVIEW TEXTURE GENERATION
# =============================================================================

## Generates a design-time preview texture for a custom control by instantiating
## its .tscn in a hidden SubViewport, waiting one frame, then capturing the image.
## The resulting ImageTexture is passed to the C++ form designer for WYSIWYG rendering,
## and a 20×20 icon version is set on the toolbox button.
## @param ctrl_name: The custom control type name
## @param scene_path: Path to the .tscn file
func _generate_preview_for_custom_control(ctrl_name: String, scene_path: String) -> void:
	if not FileAccess.file_exists(scene_path):
		return

	var packed = load(scene_path)
	if not packed or not packed is PackedScene:
		return

	var instance = packed.instantiate()
	if not instance or not instance is Control:
		if instance:
			instance.queue_free()
		return

	# Create a SubViewport to render into
	var vp = SubViewport.new()
	vp.size = Vector2i(200, 150)  # Reasonable capture size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	vp.add_child(instance)
	# Ensure the instance fills the viewport
	if instance is Control:
		instance.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add viewport to tree so it renders
	add_child(vp)

	# Wait two frames for rendering to complete, then capture
	await get_tree().process_frame
	await get_tree().process_frame

	var img: Image = vp.get_texture().get_image()
	if img and not img.is_empty():
		# Design-time preview texture (full size for canvas rendering)
		var preview_tex = ImageTexture.create_from_image(img)
		if _form_designer and _form_designer.has_method("set_control_preview_texture"):
			_form_designer.set_control_preview_texture(ctrl_name, preview_tex)

		# Toolbox icon (scaled to 20×20)
		var icon_img = img.duplicate()
		icon_img.resize(20, 20, Image.INTERPOLATE_LANCZOS)
		var icon_tex = ImageTexture.create_from_image(icon_img)
		_set_toolbox_button_icon(ctrl_name, icon_tex)

	# Cleanup
	vp.remove_child(instance)
	instance.queue_free()
	remove_child(vp)
	vp.queue_free()

## Sets a custom icon on a toolbox button by name.
## @param tool_name: The toolbox button's node name
## @param icon: The texture to set as the icon
func _set_toolbox_button_icon(tool_name: String, icon: Texture2D) -> void:
	var real_toolbox = _get_toolbox_instance()
	if not real_toolbox:
		return
	for c in real_toolbox.get_children():
		if c is TabContainer:
			for tab_idx in range(c.get_tab_count()):
				var grid = c.get_child(tab_idx)
				if grid is GridContainer:
					for btn_idx in range(grid.get_child_count()):
						var btn = grid.get_child(btn_idx)
						if btn is Button and btn.name == tool_name:
							btn.icon = icon
							return

## Generates preview textures for all enabled custom components.
## Called after toolbox refresh to provide design-time rendering and toolbox icons.
func _generate_all_custom_previews() -> void:
	var ComponentsDialog = load("res://addons/visual_gasic/components_dialog.gd")
	var enabled = ComponentsDialog.load_enabled_components()
	for comp in enabled:
		var cname: String = comp["name"]
		var scene: String = comp.get("scene", "")
		# Only generate for non-builtin custom controls with a scene path
		if not comp.get("builtin", false) and not scene.is_empty():
			_generate_preview_for_custom_control(cname, scene)

## Callback when components are added/removed via the Components dialog.
## Clears custom tools and reloads only enabled ones.
func _on_components_changed():
	# Clear existing custom tools from toolbox
	var real_toolbox = _get_toolbox_instance()
	if real_toolbox:
		real_toolbox.clear_custom_tools()
	
	# Re-add the GDScript extended tools (FlexGrid, Form, etc.)
	_register_extended_tools()
	
	# Load enabled components from config
	_load_custom_components()
	
	# Re-apply VB6 icons and labels to the new buttons
	_restyle_toolbox_buttons()
	
	# Generate preview textures for all custom components
	_generate_all_custom_previews()

## Registers the GDScript-extended tools (not in C++ defaults)
func _register_extended_tools():
	# NOTE: VGComboBox, RadioButton, MenuBar, PictureButton, Line, DriveListBox
	# are registered by _load_custom_components() via the Components dialog.
	# Do NOT register them here to avoid duplicate toolbox buttons.
	if not _get_toolbox_instance():
		return  # C++ extension not loaded — skip silently
	register_tool("FlexGrid", "Tree", "Tree", "res://custom_widgets/FlexGrid.tscn")
	register_tool("Form", "Panel", "Window", "res://custom_widgets/Form.tscn")
	register_tool("Option", "CheckBox", "CheckBox", "res://custom_widgets/Option.tscn")
	register_tool("CommonDialog", "Control", "FileDialog", "res://custom_widgets/CommonDialog.tscn")
	register_tool("ColorBtn", "ColorPickerButton", "ColorPickerButton", "res://custom_widgets/ColorBtn.tscn")
	register_tool("Video", "VideoStreamPlayer", "VideoStreamPlayer", "res://custom_widgets/Video.tscn")
	register_tool("Viewport", "SubViewportContainer", "SubViewportContainer", "res://custom_widgets/Viewport.tscn")
	
	# 3D Tools
	var cat3d = "3D"
	register_tool("Box", "MeshInstance3D", "BoxMesh", "res://custom_widgets/3d/Box.tscn", cat3d)
	register_tool("Sphere", "MeshInstance3D", "SphereMesh", "res://custom_widgets/3d/Sphere.tscn", cat3d)
	register_tool("Capsule", "MeshInstance3D", "CapsuleMesh", "res://custom_widgets/3d/Capsule.tscn", cat3d)
	register_tool("Cylinder", "MeshInstance3D", "CylinderMesh", "res://custom_widgets/3d/Cylinder.tscn", cat3d)
	register_tool("Light", "OmniLight3D", "OmniLight3D", "res://custom_widgets/3d/Light.tscn", cat3d)
	register_tool("Camera", "Camera3D", "Camera3D", "res://custom_widgets/3d/Camera.tscn", cat3d)
	register_tool("Text3D", "Label3D", "Label3D", "res://custom_widgets/3d/Text3D.tscn", cat3d)
	register_tool("Sprite3D", "Sprite3D", "Sprite3D", "res://custom_widgets/3d/Sprite3D.tscn", cat3d)
	register_tool("Sound3D", "AudioStreamPlayer3D", "AudioStreamPlayer3D", "res://custom_widgets/3d/Sound3D.tscn", cat3d)

## Loads enabled components from the config file and adds them to the toolbox.
func _load_custom_components():
	var ComponentsDialog = load("res://addons/visual_gasic/components_dialog.gd")
	var enabled = ComponentsDialog.load_enabled_components()

	# Collect existing tool names to avoid duplicates
	var existing_names := {}
	var real_toolbox = _get_toolbox_instance()
	if real_toolbox:
		for c in real_toolbox.get_children():
			if c is TabContainer:
				for tab_idx in range(c.get_tab_count()):
					var grid = c.get_child(tab_idx)
					if grid is GridContainer:
						for btn_idx in range(grid.get_child_count()):
							existing_names[grid.get_child(btn_idx).name] = true

	var added := 0
	for comp in enabled:
		var cname: String = comp["name"]
		if existing_names.has(cname):
			continue  # Already in toolbox
		register_tool(cname, comp["class"], comp.get("icon", "Control"), comp["scene"], comp.get("category", "2D"))
		added += 1

	print("VisualGasic: Loaded ", added, " custom/optional components (", enabled.size(), " enabled, ", enabled.size() - added, " already present)")


# =============================================================================
# HELPER LOADERS
# =============================================================================

## Loads and instantiates the Property Inspector panel.
## @returns: Inspector instance or null if not found
func loading_inspector():
	if FileAccess.file_exists("res://addons/visual_gasic/simple_inspector.gd"):
		var s = load("res://addons/visual_gasic/simple_inspector.gd")
		var inst = s.new()
		return inst
	return null

## Loads and instantiates the Code Navigator panel.
## @returns: Navigator instance or null if not found
func loading_code_navigator():
	if FileAccess.file_exists("res://addons/visual_gasic/code_navigator.gd"):
		var s = load("res://addons/visual_gasic/code_navigator.gd")
		var inst = s.new()
		return inst
	return null

# =============================================================================
# TOOLBOX INITIALIZATION
# =============================================================================

## Post-initialization setup.
## Registers additional toolbox controls (beyond C++ defaults) and connects editor signals.
## NOTE: C++ toolbox already provides: Pointer, Picture, Label, TextBox, Button, CheckBox,
##       ComboBox, Frame, GroupBox, ListBox, TreeView, HScroll, VScroll, ProgressBar,
##       HSlider, VSlider, SpinBox, Shape, HLine, VLine, RichText, TextArea, TabStrip, Timer, Files
func _post_init():
	# Register extended components not in C++ toolbox
	_register_extended_tools()
	
	# Load custom/optional components from Components dialog config
	_load_custom_components()
	
	# Generate preview textures for custom controls (deferred so tree is ready)
	call_deferred("_generate_all_custom_previews")
	
	# Connect to screen change signal
	main_screen_changed.connect(_on_main_screen_changed)
	
	# Connect to scene change (tab switch)
	scene_changed.connect(_on_scene_changed)
	
	# Fix nesting behavior by monitoring selection
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	
	# Hook into node_added to catch drops inside MenuBar and reparent them
	get_tree().node_added.connect(_on_node_added)

	print("VisualGasic: Initialized. Monitoring nesting & double-click events.")

## Called when the editor switches between 2D, 3D, Script, and AssetLib screens.
## Automatically switches toolbox tabs to show relevant controls.
## @param scene_root: The root node of the newly active scene
func _on_scene_changed(scene_root: Node):
	# Auto-refresh navigator when switching scenes
	var nav = _get_navigator()
	if nav:
		nav.refresh_objects()
	
	# Disable mouse input on any MenuBars in the scene (prevents drop interception)
	if scene_root:
		_disable_menubar_mouse_in_editor(scene_root)
	
	# If the Form Designer is visible, sync the newly active scene into it
	if _form_designer and is_instance_valid(_form_designer) and _form_designer.visible:
		_sync_scene_to_form_designer()

## Determines if this plugin handles input for the given object.
## Always returns false — the Form Designer never auto-activates.
## Users open it manually via the "Form Designer" tab when needed.
## @param object: The object being edited
## @returns: always false
func _handles(_object):
	return false

## Intercepts canvas GUI input for:
## 1. Custom vg_control drag-drop handling (avoids MenuBar issues)
## 2. Double-click event handler generation
## @param event: The input event
## @returns: true if event was consumed
func _forward_canvas_gui_input(event):
	# Handle mouse button events for vg_control drag-drop
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				# Mouse released - check if we have active vg_control drag from C++ toolbox
				# The C++ toolbox stores drag data in Engine singleton metadata
				if Engine.has_meta("_vg_active_drag"):
					var drag_data = Engine.get_meta("_vg_active_drag")
					if drag_data is Dictionary and drag_data.get("type") == "vg_control":
						var result = _handle_vg_control_drop(event.position, drag_data)
						Engine.remove_meta("_vg_active_drag")
						if result:
							return true
		
		# Double-click handling for event generation
		if event.double_click:
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				var sel = get_editor_interface().get_selection().get_selected_nodes()
				if sel.size() == 1:
					_generate_event_handler(sel[0])
					return true
	
	return false

## Handles dropping a vg_control onto the 2D canvas.
## Computes form-local position and delegates to _handle_vg_drop_delayed.
## @param canvas_pos: The position in the canvas where drop occurred
## @param drag_data: The drag data dictionary from C++ toolbox
## @returns: true if drop was handled
func _handle_vg_control_drop(canvas_pos: Vector2, drag_data: Dictionary) -> bool:
	var root = get_editor_interface().get_edited_scene_root()
	if not root:
		return false
	
	# Transform canvas viewport position to form-local coordinates
	var viewport = get_editor_interface().get_editor_viewport_2d()
	if viewport:
		var canvas_xform = viewport.get_canvas_transform()
		var world_pos = canvas_xform.affine_inverse() * canvas_pos
		var form_offset = Vector2.ZERO
		if root is Window:
			form_offset = Vector2(root.position)
		elif root is Control:
			form_offset = root.position
		drag_data["drop_position"] = (world_pos - form_offset).snapped(Vector2(8, 8))
	else:
		drag_data["drop_position"] = canvas_pos.snapped(Vector2(8, 8))
	
	_handle_vg_drop_delayed(drag_data)
	return true

## Generates an event handler for the given node.
## Creates or opens the .vg script and inserts a Sub based on node type:
## - Button: NodeName_Click()
## - LineEdit/TextEdit: NodeName_Change()
## - Slider/ScrollBar: NodeName_Change()
## @param node: The control node to generate a handler for
func _generate_event_handler(node):
	print("VisualGasic: Event Gen Request for " + node.name)
	var sub_suffix = ""
	
	# Mapping (VB6-ish style)
	if node is BaseButton: 
		sub_suffix = "Click"
	elif node is LineEdit:
		sub_suffix = "Change"
	elif node is TextEdit:
		sub_suffix = "Change"
	elif node is ScrollBar:
		sub_suffix = "Change"
	elif node is Slider:
		sub_suffix = "Change"
	else:
		# Fallback
		sub_suffix = "Click"
		
	var root = get_editor_interface().get_edited_scene_root()
	if not root: 
		printerr("VisualGasic: No active scene root. Save the scene first.")
		return
		
	var scene_path = root.scene_file_path
	if scene_path.is_empty():
		printerr("VisualGasic: Scene must be saved to generate code.")
		return
		
	# Assume .vg file is adjacent to scene
	var bas_path = scene_path.get_basename() + ".vg"
	# absolute path for OS shell
	var abs_path = ProjectSettings.globalize_path(bas_path)
	
	print("VisualGasic: Targeting Script " + abs_path)
	
	# Create file if missing
	if not FileAccess.file_exists(bas_path):
		var f = FileAccess.open(bas_path, FileAccess.WRITE)
		# VB6 Form Header Style
		f.store_string("' Visual Gasic Form Script\nOption Explicit\n\n")
		f.close()
		print("VisualGasic: Created new script file.")
		# Trigger filesystem to recognize the file
		get_editor_interface().get_resource_filesystem().scan()

	# Open and Inject via Editor Buffer (to avoid disk reload conflicts)
	_open_and_inject(bas_path, node.name, sub_suffix)

## Opens the script file and injects the event handler code.
## Uses deferred polling to wait for filesystem scan completion.
## @param path: Path to the .vg script file
## @param obj: Name of the control (e.g., "Button1")
## @param event: Event suffix (e.g., "Click", "Change")
func _open_and_inject(path: String, obj: String, event: String):
	# We rely on async scan, but we can't block here easily.
	_poll_for_inject.call_deferred(path, obj, event, 0)

## Polls for script resource availability and injects event handler code.
## Retries up to 20 times (2 seconds) waiting for filesystem scan.
## @param path: Path to the .vg script file
## @param obj: Name of the control
## @param event: Event suffix
## @param attempts: Current retry count
func _poll_for_inject(path: String, obj: String, event: String, attempts: int):
	# Max retries: 20 * 0.1s = 2 seconds
	if attempts > 20:
		printerr("VisualGasic: Timeout waiting for script resource. Opening externally.")
		OS.shell_open(ProjectSettings.globalize_path(path))
		return
		
	if ResourceLoader.exists(path):
		var res = load(path)
		if res:
			# Attach to Scene Root (Form) to act as Code-Behind
			var root = get_editor_interface().get_edited_scene_root()
			if root:
				# Only attach if no script is present or it's the same script
				if root.get_script() == null:
					root.set_script(res)
					print("VisualGasic: Attached " + path.get_file() + " to Form (" + root.name + ").")
			
			# Open in Editor — switch to Script view
			get_editor_interface().edit_resource(res)
			# Switch to the Script editor screen so the CodeEdit is visible
			EditorInterface.set_main_screen_editor("Script")
			print("VisualGasic: Opened script in Godot Editor -> " + path)
			
			# INJECT CODE INTO BUFFER
			var sub_name = "Sub " + obj + "_" + event
			var script_editor = get_editor_interface().get_script_editor()
			var current_editor = script_editor.get_current_editor()
			
			if current_editor:
				var code_edit = current_editor.get_base_editor()
				if code_edit:
					var text = code_edit.text
					
					if text.find(sub_name) == -1:
						# Generate a clean event handler stub (no placeholder Print)
						var new_code = "\n" + sub_name + "()\n    \nEnd Sub\n"
						code_edit.text += new_code
						text = code_edit.text # Refresh for search
					
					# Navigate to the Sub body line (the blank line inside the Sub)
					var lines = text.split("\n")
					for i in lines.size():
						if lines[i].strip_edges().begins_with(sub_name):
							# Position caret on the line INSIDE the Sub body
							var body_line = i + 1
							code_edit.set_caret_line(body_line)
							code_edit.set_caret_column(4)
							break
					
					# Deferred scroll — wait for the editor to finish layout
					_deferred_scroll_to_caret.call_deferred(code_edit)
	else:
		await get_tree().create_timer(0.1).timeout
		_poll_for_inject(path, obj, event, attempts + 1)

## Deferred helper: scrolls the CodeEdit viewport to the caret position.
## Uses a short timer to let the Script editor fully lay out after a screen switch,
## then centers the viewport on the caret and grabs focus.
func _deferred_scroll_to_caret(code_edit: CodeEdit) -> void:
	if not is_instance_valid(code_edit):
		return
	# Wait for the Script editor to finish its layout after the screen switch.
	# A single call_deferred is too early — the editor needs ~150ms to resize.
	var timer = get_tree().create_timer(0.15)
	await timer.timeout
	if is_instance_valid(code_edit):
		code_edit.center_viewport_to_caret()
		code_edit.grab_focus()
		# Second pass after another short delay for robustness
		var timer2 = get_tree().create_timer(0.15)
		await timer2.timeout
		if is_instance_valid(code_edit):
			code_edit.center_viewport_to_caret()

## Called when the main editor screen changes (2D, 3D, Script, AssetLib).
## Switches toolbox tab to match the current view.
## Also: if Form Designer mode is active and user clicked a different screen,
## deactivate Form Designer (like switching away from any main screen).
## @param screen_name: Name of the screen ("2D", "3D", "Script", etc.)
func _on_main_screen_changed(screen_name: String):
	# VB6 mode is STICKY — it stays active when switching between
	# Form Designer / 2D / Script / 3D.  Only the explicit
	# "Toggle VG IDE Layout" menu item deactivates it.
	# This keeps Toolbox, Properties, and Project Explorer docked.
	
	var real_toolbox = _get_toolbox_instance()
	if real_toolbox:
		var tabs = null
		# Find the TabContainer (should be the first child if C++ constructor is correct)
		for c in real_toolbox.get_children():
			if c is TabContainer:
				tabs = c
				break
		
		if tabs:
			if screen_name == "3D":
				tabs.current_tab = 1 # 3D Index
			elif screen_name == "2D":
				tabs.current_tab = 0 # 2D Index
	
	# Update Code Navigator on Screen Change (e.g. entering Script view)
	var nav = _get_navigator()
	if nav:
		nav.refresh_objects()

	# Refresh Project Explorer on screen change
	if _project_explorer and is_instance_valid(_project_explorer) and _project_explorer.visible:
		_project_explorer.refresh()

## Sets up the toolbox control palette.
## Instantiates the C++ VisualGasicToolbox class if available,
## otherwise shows an error message.
func setup_toolbox():
	if ClassDB.class_exists("VisualGasicToolbox"):
		var real_toolbox = ClassDB.instantiate("VisualGasicToolbox")
		real_toolbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		real_toolbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# No minimum size - let the dock be resizable
		real_toolbox.visible = true
		toolbox.add_child(real_toolbox)
		# Wire tool_selected signal → FormDesigner active tool
		if real_toolbox.has_signal("tool_selected"):
			real_toolbox.tool_selected.connect(_on_toolbox_tool_selected)
			print("VisualGasic: Toolbox tool_selected signal connected")
	else:
		var err = Label.new()
		err.text = "VisualGasicToolbox Missing!"
		toolbox.add_child(err)
		
	# Fallback/Additional Logic if needed
	pass

## Sets up a right-click context menu on the Toolbox with "Components..." shortcut.
## This mirrors VB6's toolbox behavior where right-clicking opens the Components dialog.
func _setup_toolbox_context_menu():
	if not toolbox:
		return
	
	var popup = PopupMenu.new()
	popup.name = "ToolboxContextMenu"
	popup.add_item("Components...", 0)
	popup.add_separator()
	popup.add_item("Add Tab...", 1)
	popup.id_pressed.connect(func(id):
		match id:
			0: _on_components()
			1: pass  # Future: Add custom toolbox tab
	)
	toolbox.add_child(popup)
	
	# Connect right-click on the toolbox container
	toolbox.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			popup.position = Vector2i(DisplayServer.mouse_get_position())
			popup.popup()
	)

## Registers a tool in the toolbox control palette.
## @param name: Display name in the toolbox (e.g., "Button", "TextEdit")
## @param create_class: Godot class to instantiate when dropped
## @param icon_name: Icon to display (usually same as create_class)
## @param scene_path: Optional .tscn scene to instantiate instead
## @param category: Toolbox tab category ("2D" or "3D")
func register_tool(name: String, create_class: String, icon_name: String = "", scene_path: String = "", category: String = "2D"):
	var real_toolbox = _get_toolbox_instance()
	if real_toolbox:
		real_toolbox.add_tool(name, create_class, icon_name, scene_path, category)

## Gets the C++ VisualGasicToolbox instance from the toolbox container.
## @returns: The toolbox instance or null if not found
func _get_toolbox_instance():
	if toolbox:
		for c in toolbox.get_children():
			if c.get_class() == "VisualGasicToolbox":
				return c
	return null

## Disables mouse input on all MenuBars in a scene tree.
## This prevents MenuBars from intercepting editor drag-drop operations.
## Called when a scene is opened for editing.
## @param root: The root node to search from
func _disable_menubar_mouse_in_editor(root: Node):
	if not root:
		return
	# Find all MenuBars in the scene
	_find_and_disable_menubars(root)

## Recursively finds MenuBars and disables their mouse input.
## @param node: Current node to check
func _find_and_disable_menubars(node: Node):
	if node is MenuBar:
		# Disable mouse input on MenuBar and all its children
		_set_mouse_filter_recursive(node, Control.MOUSE_FILTER_IGNORE)
	# Check children
	for child in node.get_children():
		_find_and_disable_menubars(child)

## Recursively sets mouse_filter on a Control and all its Control children.
## @param node: The node to modify
## @param filter: The mouse filter to set
func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter):
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

# =============================================================================
# NODE ADDED HANDLER (Early MenuBar detection)
# =============================================================================

## Called when ANY node is added to the scene tree.
## This catches drops inside MenuBar BEFORE owner is set, preventing errors.
## Only redirects user controls (Button, Label, etc.) - NOT PopupMenu or internal nodes.
## @param node: The node that was added
func _on_node_added(node: Node):
	# Only process in editor
	if not Engine.is_editor_hint():
		return
	
	# Skip invalid nodes
	if not is_instance_valid(node):
		return
	
	# Skip internal nodes (start with _ or @)
	var node_name = node.name
	if node_name.begins_with("_") or node_name.begins_with("@"):
		return
	
	# Skip PopupMenu and its children - these are LEGITIMATE MenuBar children
	if node is PopupMenu:
		return
	
	# Check if node is inside a PopupMenu (internal components) - skip those
	var parent = node.get_parent()
	if not parent:
		return
	if parent is PopupMenu:
		return
	
	# Only process common VB6-style controls that could be accidentally dropped
	var is_user_control = (
		node is Button or
		node is Label or
		node is LineEdit or
		node is TextEdit or
		node is CheckBox or
		node is CheckButton or
		node is ProgressBar or
		node is SpinBox or
		node is HSlider or
		node is VSlider or
		node is Panel or
		node is TextureRect or
		node is ColorRect
	)
	
	if not is_user_control:
		return
	
	# Walk up to check if parent is inside a MenuBar
	var check_node = parent
	var root = get_editor_interface().get_edited_scene_root()
	if not root:
		return
	
	var is_inside_menubar = false
	while check_node and check_node != root:
		if check_node is MenuBar:
			is_inside_menubar = true
			break
		check_node = check_node.get_parent()
	
	if is_inside_menubar:
		# This is a user control dropped inside MenuBar - reparent IMMEDIATELY
		# We MUST do this before the editor tries to set owner, which would fail
		print("VisualGasic: Redirecting user control from MenuBar: ", node.name)
		_immediate_reparent_to_root(node, root)

## Immediate reparenting for nodes dropped in wrong places like MenuBar.
## Must be called synchronously during node_added to prevent owner errors.
## @param node: The node to reparent
## @param root: The scene root to reparent to
func _immediate_reparent_to_root(node: Node, root: Node):
	if not is_instance_valid(node) or not is_instance_valid(root):
		return
	
	var parent = node.get_parent()
	if not parent or parent == root:
		return  # Already at root or no parent
	
	var node_pos = Vector2.ZERO
	if node is Control:
		node_pos = node.position
	
	print("VisualGasic: Reparenting ", node.name, " from ", parent.name, " to ", root.name)
	
	# Remove from bad parent and add to root
	parent.remove_child(node)
	root.add_child(node)
	node.owner = root
	
	# Restore position (relative to root now)
	if node is Control:
		node.position = node_pos
	
	# Select the reparented node on next frame
	call_deferred("_select_node", node)

## Selects a node in the editor (deferred to avoid conflicts)
func _select_node(node: Node):
	if is_instance_valid(node):
		get_editor_interface().get_selection().clear()
		get_editor_interface().get_selection().add_node(node)

## Deferred reparenting to avoid issues during node_added signal.
## @param node: The node to reparent
## @param root: The scene root to reparent to
func _deferred_reparent_to_root(node: Node, root: Node):
	if not is_instance_valid(node) or not is_instance_valid(root):
		return
	if not node.is_inside_tree():
		return
	
	var parent = node.get_parent()
	if parent == root:
		return  # Already at root
	
	var global_pos = Vector2.ZERO
	if node is Control:
		global_pos = node.global_position
	
	print("VisualGasic: Reparenting ", node.name, " from ", parent.name, " to ", root.name)
	
	parent.remove_child(node)
	root.add_child(node)
	node.owner = root
	
	if node is Control and global_pos != Vector2.ZERO:
		node.global_position = global_pos
	
	# Select the reparented node
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)


# =============================================================================
# SELECTION & NESTING MANAGEMENT
# =============================================================================

## Called when the editor selection changes.
## Handles VB6-style nesting restrictions and auto-text updates.
func _on_selection_changed():
	var sel = get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() == 1:
		call_deferred("_check_nesting", sel[0])
		call_deferred("_auto_set_text_from_name", sel[0])
	
	# Update Code Navigator
	var nav = _get_navigator()
	if nav:
		# Does not auto-refresh on simple selection to avoid flicker/perf, 
		# but refreshing the list when nodes are added/renamed is wise.
		# For now, just a button, but can call nav.refresh_objects() if hierarchy changed?
		pass

## Gets the Code Navigator instance.
## @returns: The navigator panel or null
func _get_navigator():
	return _code_navigator

## Automatically sets control's text property to match its name.
## Only applies when text is a default value like "Button" or "Label".
## @param node: The node to check and update
func _auto_set_text_from_name(node: Node):
	if not is_instance_valid(node): return
	# Don't process nodes that aren't fully in the tree yet
	if not node.is_inside_tree(): return
	
	# Only applies to controls with a 'text' property
	if "text" in node:
		var current = node.text
		# Defaults defined in our prototypes
		if current == "Button" or current == "Check1" or current == "Label" or current == "CheckBox":
			if node.name != current:
				print("VisualGasic: Auto-setting text to match name -> " + node.name)
				node.text = node.name

## Checks and enforces VB6-style nesting restrictions.
## In VB6, most controls cannot contain other controls.
## Only explicit containers (Panel, TabContainer, etc.) allow children.
## Non-container parents cause the node to be reparented to the form root.
## @param node: The node to check
func _check_nesting(node: Node):
	if not is_instance_valid(node): return
	# Don't process nodes that aren't fully in the tree yet (e.g. during drag-drop)
	if not node.is_inside_tree(): return
	
	# CHECK FOR MISSING ROOT (Empty Scene)
	var root = get_editor_interface().get_edited_scene_root()
	if not root:
		# If there is no root, but we have a node, this node IS the root candidates?
		# No, Godot usually sets the dropped node as root automatically if empty.
		# But if we drop subsequent nodes, we need a valid root.
		return

	# If the node IS the new root (because scene was empty), enable "Form" preset for it?
	if node == root:
		print("VisualGasic: New Root Node Created -> " + node.name)
		# Optional: Auto-rename to "Form" if it's a Control/Panel?
		return

	var parent = node.get_parent()
	if not parent: return
	
	var is_bad = false
	
	# AllowList Strategy: Only specific nodes can be parents
	var is_container = false
	
	# 1. Root is always valid
	if parent == root:
		is_container = true
	
	# 2. Check if parent is inside a MenuBar - these are internal containers, NOT valid
	var is_inside_menubar = false
	var check_node = parent
	while check_node and check_node != root:
		if check_node is MenuBar:
			is_inside_menubar = true
			break
		check_node = check_node.get_parent()
	
	if is_inside_menubar:
		# This is a MenuBar's internal container - redirect to root
		print("VisualGasic: Blocked drop inside MenuBar. Reparenting to Root.")
		_reparent_node(node, root)
		return
	
	# 3. Check if parent is a PopupMenu - these are also not valid drop targets  
	if parent is PopupMenu:
		print("VisualGasic: Blocked drop inside PopupMenu. Reparenting to Root.")
		_reparent_node(node, root)
		return
		
	# 4. explicit Containers (user-created)
	if parent is Panel: is_container = true
	elif parent is TabContainer: is_container = true
	elif parent is ScrollContainer: is_container = true
	elif parent is VBoxContainer: is_container = true
	elif parent is HBoxContainer: is_container = true
	elif parent is GridContainer: is_container = true
	elif parent is Control and parent.name == "Form": is_container = true
	
	# If it's not a container, it's BAD.
	if not is_container:
		print("VisualGasic: Blocked Nesting in " + parent.name + " (" + parent.get_class() + "). Reparenting to Root.")
		# Move to Root (Form) directly, as that is the safest "VB6" behavior
		_reparent_node(node, root)
	else:
		print("VisualGasic: Allowed Nesting in " + parent.name)

## Moves a node to a new parent while preserving global position.
## Used by _check_nesting to fix invalid parent relationships.
## @param node: The node to reparent
## @param new_parent: The target parent node
func _reparent_node(node: Node, new_parent: Node):
	if not new_parent: return
	
	var global_pos = Vector2.ZERO
	if node is Node2D or node is Control:
		global_pos = node.global_position
		
	print("VisualGasic: Moving " + node.name + " from " + node.get_parent().name + " to " + new_parent.name + " at " + str(global_pos))
	
	# Capture owner before removing
	var owner_node = node.owner
	if not owner_node:
		owner_node = get_editor_interface().get_edited_scene_root()
		
	node.get_parent().remove_child(node)
	new_parent.add_child(node)
	
	node.owner = owner_node
	
	if node is Node2D or node is Control:
		# If Position is 0,0, try to guess or leave it
		if global_pos == Vector2.ZERO and new_parent is Control:
             # Just leave it, Godot might have failed to set pos
			pass
		else:
			node.global_position = global_pos
		
	# Restore selection
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)

# =============================================================================
# RECENT PROJECTS
# =============================================================================

## Sets up the recent projects menu in the Tools menu.
func _setup_recent_projects_menu():
	"""Setup recent projects tracking and menu"""
	# Load the recent projects manager
	var manager_script = load("res://addons/visual_gasic/vg_recent_projects.gd")
	if manager_script:
		_recent_projects_manager = manager_script.new()
	
	# Create the popup menu
	var menu_script = load("res://addons/visual_gasic/recent_projects_menu.gd")
	if menu_script:
		_recent_projects_menu = menu_script.new()
		_recent_projects_menu.project_selected.connect(_on_recent_project_selected)
		# Note: add_tool_submenu_item handles parenting, don't add to base_control
		add_tool_submenu_item("Recent Projects", _recent_projects_menu)
		print("VisualGasic: Added Recent Projects menu")

## Called when a recent project is selected from the menu.
func _on_recent_project_selected(path: String) -> void:
	if path.ends_with(".vbp"):
		# Import VB6 project
		_do_import_vbp(path)
	elif path.ends_with(".vg"):
		# Open VG script
		var script = load(path)
		if script:
			get_editor_interface().edit_resource(script)
	elif path.ends_with(".tscn") or path.ends_with(".scn"):
		# Open scene
		get_editor_interface().open_scene_from_path(path)

## Adds a project to the recent projects list.
func _add_to_recent_projects(path: String) -> void:
	if _recent_projects_manager:
		_recent_projects_manager.add_project(path)

# =============================================================================
# SCRIPT EDITOR RENAME REFACTORING
# =============================================================================

## Sets up the script editor context menu for rename refactoring.
## Creates a popup menu with scope-aware rename options and starts
## a timer to monitor for .vg files in the script editor.
func _setup_script_editor_context_menu():
	"""Setup timer to monitor script editor for .vg files"""
	# Create context menu
	_script_context_menu = PopupMenu.new()
	_script_context_menu.add_item("Rename in Current Scope...", 0)
	_script_context_menu.add_item("Rename in Entire Script...", 1)
	_script_context_menu.add_item("Rename Everywhere...", 2)
	_script_context_menu.id_pressed.connect(_on_script_context_menu_selected)
	get_editor_interface().get_base_control().add_child(_script_context_menu)
	
	# Timer to periodically check for .vg script in editor
	_script_editor_check_timer = Timer.new()
	_script_editor_check_timer.wait_time = 0.5
	_script_editor_check_timer.timeout.connect(_check_script_editor_for_vg)
	get_editor_interface().get_base_control().add_child(_script_editor_check_timer)
	_script_editor_check_timer.start()

## Periodically checks if a .vg file is being edited in the script editor.
## If found, hooks into the CodeEdit for keyboard shortcut handling and
## injects the Code Navigator bar above the code editor (VB6-style).
func _check_script_editor_for_vg():
	"""Check if a .vg file is being edited and hook into its CodeEdit"""
	var script_editor = get_editor_interface().get_script_editor()
	if not script_editor:
		return
	
	var current_script = script_editor.get_current_script()
	if not current_script:
		# No script open — hide navigator
		if _code_navigator:
			_code_navigator.visible = false
		return
	
	var script_path = current_script.resource_path
	if not script_path.ends_with(".vg"):
		_current_code_edit = null
		# Not a .vg file — hide navigator
		if _code_navigator:
			_code_navigator.visible = false
		return
	
	# Get the CodeEdit for this script
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
	
	var code_edit = current_editor.get_base_editor() as CodeEdit
	if not code_edit:
		return
	
	# --- Inject Code Navigator above the code editor (VB6-style) ---
	if _code_navigator and is_instance_valid(_code_navigator):
		# Find the VBoxContainer parent of the CodeEdit — this is the
		# script editor's internal layout that holds the code area.
		var code_parent = code_edit.get_parent()
		if code_parent and code_parent != _nav_injected_parent:
			# Reparent navigator to the new script tab's container
			if _code_navigator.get_parent():
				_code_navigator.get_parent().remove_child(_code_navigator)
			code_parent.add_child(_code_navigator)
			# Move to index 0 so it appears ABOVE the CodeEdit
			code_parent.move_child(_code_navigator, 0)
			_nav_injected_parent = code_parent
		_code_navigator.visible = true
	
	if code_edit == _current_code_edit:
		return
	
	# New CodeEdit — hook into it
	_current_code_edit = code_edit
	if not code_edit.gui_input.is_connected(_on_code_edit_gui_input):
		code_edit.gui_input.connect(_on_code_edit_gui_input)
	
	# Refresh navigator for the new script
	if _code_navigator:
		_code_navigator.refresh_objects()
	
	# Apply VGThemeManager theme to the code editor (v2.4.1)
	var theme_mgr_script = load("res://addons/visual_gasic/vg_theme_manager.gd")
	if theme_mgr_script:
		theme_mgr_script.apply_to_code_edit(code_edit)
	
	# NOTE: Do NOT apply a custom CodeHighlighter to .vg files!
	# Godot's script editor uses the ScriptLanguageExtension's built-in
	# highlighting methods (_get_comment_delimiters, _get_string_delimiters).
	# Assigning a CodeHighlighter conflicts with this and causes crash.
	# The C++ extension handles syntax highlighting natively.

## Handles keyboard shortcuts in the code editor.
## Ctrl+R triggers the rename refactoring dialog for the word under cursor.
## @param event: The input event
func _on_code_edit_gui_input(event: InputEvent):
	"""Handle keyboard shortcuts in the code editor"""
	if not _current_code_edit:
		return
	
	# Use Ctrl+R for rename (like many IDEs)
	if event is InputEventKey and event.pressed:
		var key_event = event as InputEventKey
		if key_event.ctrl_pressed and key_event.keycode == KEY_R:
			# Get the word under cursor
			var word = _get_word_under_cursor(_current_code_edit)
			if not word.is_empty() and _is_valid_identifier(word):
				# Store the word for later use
				_script_context_menu.set_meta("selected_word", word)
				_script_context_menu.set_meta("script_path", get_editor_interface().get_script_editor().get_current_script().resource_path)
				
				# Show menu at caret position
				var caret_pos = _current_code_edit.get_caret_draw_pos()
				_script_context_menu.position = Vector2i(_current_code_edit.get_screen_position()) + Vector2i(caret_pos)
				_script_context_menu.popup()
				_current_code_edit.accept_event()  # Consume the event

## Extracts the word under the cursor in a CodeEdit.
## Scans left and right from cursor position to find word boundaries.
## @param code_edit: The CodeEdit control
## @returns: The word under cursor, or empty string if none
func _get_word_under_cursor(code_edit: CodeEdit) -> String:
	"""Get the word under the cursor in a CodeEdit"""
	var line = code_edit.get_caret_line()
	var col = code_edit.get_caret_column()
	var text = code_edit.get_line(line)
	
	if col > text.length():
		col = text.length()
	
	# Find word start
	var start = col
	while start > 0 and _is_identifier_char(text[start - 1]):
		start -= 1
	
	# Find word end
	var end = col
	while end < text.length() and _is_identifier_char(text[end]):
		end += 1
	
	if start >= end:
		return ""
	
	return text.substr(start, end - start)

## Checks if a character is valid for identifiers (letters, digits, underscore).
## @param c: Single character string
## @returns: true if valid identifier character
func _is_identifier_char(c: String) -> bool:
	return c.is_valid_identifier() or c == "_" or (c >= "0" and c <= "9")

## Validates that a string is a valid identifier name.
## Must not be empty, start with a digit, or contain invalid characters.
## @param name: The identifier to validate
## @returns: true if valid identifier
func _is_valid_identifier(name: String) -> bool:
	if name.is_empty():
		return false
	if name[0] >= "0" and name[0] <= "9":
		return false
	for c in name:
		if not _is_identifier_char(c):
			return false
	return true

## Applies VisualGasic syntax highlighting to a CodeEdit.
## NOTE: This function is DISABLED because assigning a CodeHighlighter
## to a CodeEdit editing a ScriptLanguageExtension script causes Godot to crash.
## The C++ extension provides highlighting via _get_comment_delimiters() etc.
## @param code_edit: The CodeEdit to apply highlighting to
func _apply_vg_syntax_highlighting(_code_edit: CodeEdit) -> void:
	# DISABLED - causes Godot crash (signal 11)
	# Godot's script editor already uses VisualGasicLanguage's built-in methods
	pass

## Handles script editor context menu item selection.
## Triggers the appropriate rename dialog based on selected option.
## @param id: Menu item ID (0=scope, 1=script, 2=everywhere)
func _on_script_context_menu_selected(id: int):
	"""Handle script editor context menu selection"""
	var word = _script_context_menu.get_meta("selected_word", "")
	var script_path = _script_context_menu.get_meta("script_path", "")
	
	if word.is_empty():
		return
	
	# id: 0 = current scope, 1 = entire script, 2 = everywhere
	_show_rename_dialog_for_script(word, script_path, id)

## Shows the rename dialog for a variable in script files.
## @param old_name: Current variable/identifier name
## @param script_path: Path to the current .vg script
## @param mode: Rename scope (0=current Sub/Function, 1=entire script, 2=all .vg files)
func _show_rename_dialog_for_script(old_name: String, script_path: String, mode: int):
	"""Show dialog to rename a variable in script files
	   mode: 0 = current scope, 1 = entire script, 2 = everywhere"""
	var mode_names = ["Current Scope", "Entire Script", "Everywhere"]
	var dialog = AcceptDialog.new()
	dialog.title = "Rename '%s' (%s)" % [old_name, mode_names[mode]]
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Rename '%s' to:" % old_name
	vbox.add_child(label)
	
	var input = LineEdit.new()
	input.text = old_name
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
		if new_name.is_empty() or new_name == old_name:
			return
		if not _is_valid_identifier(new_name):
			push_warning("'%s' is not a valid identifier" % new_name)
			return
		_perform_rename_in_scripts(old_name, new_name, script_path, mode)
		dialog.queue_free()
	)
	
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2(350, 150))
	input.grab_focus()

## Performs the actual rename operation in script files.
## Handles three modes: current scope, entire script, or all .vg files.
## Uses word-boundary aware regex to avoid partial matches.
## @param old_name: Current variable name
## @param new_name: New variable name
## @param script_path: Path to the current .vg script
## @param mode: Rename scope (0=scope, 1=script, 2=everywhere)
func _perform_rename_in_scripts(old_name: String, new_name: String, script_path: String, mode: int):
	"""Perform the actual rename operation in script files
	   mode: 0 = current scope, 1 = entire script, 2 = everywhere"""
	
	if mode == 2:
		# All files
		var files_to_search: Array[String] = _find_all_vg_files("res://")
		var total_replacements = 0
		var files_modified = 0
		
		for file_path in files_to_search:
			var result = _rename_in_file(file_path, old_name, new_name)
			if result > 0:
				total_replacements += result
				files_modified += 1
		
		if total_replacements > 0:
			print("Renamed '%s' → '%s': %d replacements in %d file(s)" % [
				old_name, new_name, total_replacements, files_modified
			])
		else:
			print("No occurrences of '%s' found" % old_name)
	elif mode == 1:
		# Entire script
		var result = _rename_in_file(script_path, old_name, new_name)
		if result > 0:
			print("Renamed '%s' → '%s': %d replacements" % [old_name, new_name, result])
		else:
			print("No occurrences of '%s' found in script" % old_name)
	else:
		# Current scope - need cursor position
		var caret_line = 0
		if _current_code_edit:
			caret_line = _current_code_edit.get_caret_line()
		var result = _rename_in_scope(script_path, old_name, new_name, caret_line)
		if result > 0:
			print("Renamed '%s' → '%s': %d replacements in current scope" % [old_name, new_name, result])
		else:
			print("No occurrences of '%s' found in current scope" % old_name)
	
	# Reload the script in the editor
	_reload_current_script()

## Reloads the current script in the editor to show changes.
func _reload_current_script():
	"""Reload the current script to show changes"""
	var script_editor = get_editor_interface().get_script_editor()
	if script_editor:
		var current = script_editor.get_current_script()
		if current:
			current.reload()

## Renames a variable only within the current Sub/Function scope.
## Finds the enclosing procedure based on cursor position and only
## replaces occurrences within that scope.
## @param file_path: Path to the .vg script file
## @param old_name: Current variable name
## @param new_name: New variable name
## @param caret_line: Current cursor line (0-based)
## @returns: Number of replacements made
func _rename_in_scope(file_path: String, old_name: String, new_name: String, caret_line: int) -> int:
	"""Rename variable only within the current Sub/Function scope."""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 0
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	var proc_start = -1
	var proc_end = -1
	
	# Find the enclosing Sub/Function based on caret position
	for i in range(caret_line, -1, -1):
		if i >= lines.size():
			continue
		var line_upper = lines[i].strip_edges().to_upper()
		if line_upper.begins_with("SUB ") or line_upper.begins_with("FUNCTION ") or \
		   line_upper.begins_with("PRIVATE SUB ") or line_upper.begins_with("PUBLIC SUB ") or \
		   line_upper.begins_with("PRIVATE FUNCTION ") or line_upper.begins_with("PUBLIC FUNCTION "):
			proc_start = i
			break
	
	if proc_start == -1:
		# Caret is at module level - rename only module-level occurrences
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
		for i in range(proc_start, lines.size()):
			var line_upper = lines[i].strip_edges().to_upper()
			if line_upper == "END SUB" or line_upper == "END FUNCTION":
				proc_end = i + 1
				break
		if proc_end == -1:
			proc_end = lines.size()
	
	# Rename only within proc_start to proc_end
	var regex = RegEx.new()
	regex.compile("(?<![A-Za-z0-9_])" + old_name + "(?![A-Za-z0-9_])")
	
	var replacements = 0
	var new_lines = lines.duplicate()
	
	for i in range(proc_start, proc_end):
		var line = new_lines[i]
		var matches = regex.search_all(line)
		if matches.is_empty():
			continue
		
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

## Recursively finds all .vg files in a directory.
## @param path: Directory path to search
## @returns: Array of .vg file paths
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

## Renames a variable in a single file using word-boundary matching.
## Skips occurrences inside strings and comments.
## @param file_path: Path to the .vg file
## @param old_name: Current variable name
## @param new_name: New variable name
## @returns: Number of replacements made
func _rename_in_file(file_path: String, old_name: String, new_name: String) -> int:
	"""Rename variable in a single file. Returns number of replacements."""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 0
	
	var content = file.get_as_text()
	file.close()
	
	# Use word-boundary aware replacement
	var regex = RegEx.new()
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

## Checks if a position in the content is inside a string or comment.
## Used to avoid renaming text within strings or comments.
## @param content: The full file content
## @param pos: Character position to check
## @returns: true if position is inside string or comment
func _is_inside_string_or_comment(content: String, pos: int) -> bool:
	"""Check if a position in the content is inside a string or comment"""
	var line_start = content.rfind("\n", pos)
	if line_start == -1:
		line_start = 0
	else:
		line_start += 1
	
	var line_portion = content.substr(line_start, pos - line_start)
	
	# Check for comment
	var comment_pos = line_portion.find("'")
	if comment_pos >= 0:
		var in_string = false
		for i in range(comment_pos):
			if line_portion[i] == '"':
				in_string = not in_string
		if not in_string:
			return true
	
	# Check if inside string
	var quote_count = 0
	for i in range(line_portion.length()):
		if line_portion[i] == '"':
			quote_count += 1
	
	return quote_count % 2 == 1

