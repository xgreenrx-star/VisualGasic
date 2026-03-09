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

## Embedded VB6-style code editor (replaces canvas in-place)
var _embedded_code_editor = null
## Whether the IDE is currently showing the code view (vs form view)
var _showing_code_view: bool = false

## Snippet Browser dialog (v2.4.1)
var _snippet_browser = null

## Theme Picker dialog (v2.4.1)
var _theme_picker = null

## Profiler Panel (v2.6.0) — bottom panel for bytecode profiling
var _profiler_panel = null

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

	# Enable input processing so _input() fires for our keyboard shortcuts
	set_process_input(true)

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
		# Keyboard fallback: catch shortcuts when canvas has focus
		_form_designer.gui_input.connect(_on_canvas_gui_input)

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
		toolbar_row.add_child(view_obj_btn)

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

		# ── Embedded Code Editor (hidden by default, replaces canvas on View Code) ──
		var ece_script = load("res://addons/visual_gasic/vg_embedded_code_editor.gd")
		if ece_script:
			_embedded_code_editor = ece_script.new()
			_embedded_code_editor.visible = false
			_embedded_code_editor.view_object_requested.connect(_show_form_view)
			canvas_right_split.add_child(_embedded_code_editor)
			# Move it before CanvasScroll's sibling index so the split works
			# Actually, just add after canvas_scroll — when visible it takes over
			print("VisualGasic: Embedded Code Editor created")

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

	# Tip of the Day — load preference and create dialog
	_load_tip_config()
	_create_tip_of_day_dialog()

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
		# If we were showing code view, switch back to form view state
		# (so next time Form Designer opens it shows the form canvas)
		if _showing_code_view:
			_show_form_view()
		# Leaving Form Designer → flush C++ state to disk.
		if is_instance_valid(_form_designer):
			# Derive the save path: prefer scene_root.scene_file_path (the
			# source of truth), then form_path, then fallback from form_name.
			# We can NOT rely solely on get_form_path() — it may be empty if
			# open_form was never called or form_path was cleared.
			var save_path := ""
			var scene_root = EditorInterface.get_edited_scene_root()
			if scene_root and not scene_root.scene_file_path.is_empty():
				save_path = scene_root.scene_file_path
			if save_path.is_empty():
				save_path = _form_designer.get_form_path()
			if save_path.is_empty() and _form_designer.get_control_count() > 0:
				save_path = "res://" + _form_designer.get_form_name() + ".tscn"
			print("[VG-SYNC] _make_visible(false)  save_path='", save_path, "'  fp='", _form_designer.get_form_path(), "'  controls=", _form_designer.get_control_count())
			if not save_path.is_empty():
				_form_designer.save_form_as(save_path)
				_strip_empty_menubar_from_tscn(save_path)
				EditorInterface.get_resource_filesystem().update_file(save_path)
				# Patch in-memory tree so Godot won't overwrite with stale data
				_sync_form_state_to_scene_tree()
				print("[VG-SYNC]   saved & update_file done for '", save_path, "'")
				# Schedule reload for AFTER the screen transition completes.
				# Godot's reload_scene_from_path() silently does nothing while
				# is_changing_scene() is true (see editor_interface.cpp:707).
				# We store the path and do the reload in _on_main_screen_changed.
				if not _switching_to_code_editor:
					_pending_reload_path = save_path
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
		if _show_tips_on_startup:
			call_deferred("_show_tip_of_day")

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

## Called by the editor when saving window layout.
## CRITICAL: This fires AFTER Godot has saved all open scene tabs to disk.
## We re-save the form .tscn from C++ here to overwrite any stale data
## that Godot's scene saver may have written from its in-memory tree.
func _get_window_layout(config: ConfigFile):
	if is_instance_valid(_layout_manager):
		_layout_manager.on_window_layout_saving(config)
	# Persist the current form path so it survives editor restart
	if is_instance_valid(_form_designer):
		var fpath = _form_designer.get_form_path()
		if not fpath.is_empty():
			config.set_value("VisualGasic", "form_path", fpath)
			# CRITICAL: Re-save from C++ to overwrite any stale .tscn that
			# Godot's scene saver just wrote.  The C++ FormDesigner's
			# form_size is the source of truth.
			_form_designer.save_form_as(fpath)
			_strip_empty_menubar_from_tscn(fpath)
			print("[VG-SYNC] _get_window_layout → re-saved form to overwrite stale Godot save")

## Called by the editor before saving any external data (scenes, resources).
## We write the C++ Form Designer state to disk, then force Godot to reload
## the scene so its in-memory scene tree matches our .tscn.  Without the
## reload, Godot's own scene-save (which runs right after this) would
## overwrite our file with its stale version.
func _save_external_data() -> void:
	if _saving_external:
		return  # reentrancy guard — reload_scene can trigger another save cycle
	_saving_external = true
	if is_instance_valid(_form_designer):
		var fp = _form_designer.get_form_path()
		# Derive a save path if the form was never saved to disk yet
		if fp.is_empty() and _form_designer.get_control_count() > 0:
			var scene_root = EditorInterface.get_edited_scene_root()
			if scene_root and not scene_root.scene_file_path.is_empty():
				fp = scene_root.scene_file_path
			else:
				fp = "res://" + _form_designer.get_form_name() + ".tscn"
			_form_designer.save_form_as(fp)
		elif not fp.is_empty():
			_form_designer.save_form()
		# Notify Godot's filesystem and reload the scene
		fp = _form_designer.get_form_path()
		if not fp.is_empty():
			# CRITICAL: Patch in-memory tree FIRST.  reload_scene_from_path()
			# silently fails during Godot's save cycle (is_changing_scene),
			# so we must ensure the tree already has the correct values.
			_sync_form_state_to_scene_tree()
			var scene_root = EditorInterface.get_edited_scene_root()
			if scene_root and scene_root.scene_file_path == fp:
				_force_godot_scene_reload(fp)
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

	# ── Ctrl+S  →  Save Form ──
	if event.keycode == KEY_S and event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed:
		_do_save_form()
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
	# Ctrl+S → Save Form
	if event.keycode == KEY_S and event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed:
		_do_save_form()
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
	# Now create the Window node - DO NOT attach VG script until after all children and owners are set
	var root = Window.new()
	root.name = form_name
	root.title = form_name
	root.position = Vector2i(10,36)  # Align with canvas origin in editor
	root.size = template.get("size", Vector2(800, 600))
	
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
	# Open as a Godot scene tab FIRST so _sync_form_state_to_scene_tree()
	# can patch Godot's in-memory tree when saving.
	if not tscn_path in EditorInterface.get_open_scenes():
		EditorInterface.open_scene_from_path(tscn_path)
	_form_designer.open_form(tscn_path)
	_fixup_form_size_from_tscn(tscn_path)
	EditorInterface.set_main_screen_editor("Form Designer")
	print("VisualGasic: Opened '", tscn_path, "' in Form Designer")
	# Apply VB6 theme to the live scene tree immediately
	_apply_vb6_theme_to_scene_root()
	# Also force a scene reload so the 2D viewport picks up any C++ changes.
	get_tree().create_timer(0.3).timeout.connect(_force_godot_scene_reload.bind(tscn_path))

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

	# ── Build a tooltip-only theme for the toolbox ──
	# Tooltip popups inherit from the triggering control's theme owner,
	# so we set a Theme on the C++ toolbox that includes TooltipPanel/TooltipLabel.
	var tooltip_theme := Theme.new()
	var tooltip_sb := StyleBoxFlat.new()
	tooltip_sb.bg_color = Color(1.0, 1.0, 0.94)   # Classic light-yellow
	tooltip_sb.border_color = Color(0.0, 0.0, 0.0)
	tooltip_sb.set_border_width_all(1)
	tooltip_sb.set_content_margin_all(4)
	tooltip_theme.set_stylebox("panel", "TooltipPanel", tooltip_sb)
	tooltip_theme.set_color("font_color", "TooltipLabel", Color.BLACK)
	cpp_toolbox.theme = tooltip_theme

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
func _make_shortcut(key: Key, ctrl: bool = false