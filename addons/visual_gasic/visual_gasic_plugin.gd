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

	# TEST: Create a simple Label to verify dock mechanism
	toolbox = VBoxContainer.new()
	toolbox.name = "Toolbox"
	toolbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var label = Label.new()
	label.text = "Visual Gasic Debug"
	toolbox.add_child(label)
	
	var btn_new_form = Button.new()
	btn_new_form.text = "New Form"
	btn_new_form.pressed.connect(_on_new_form)
	toolbox.add_child(btn_new_form)
	
	var btn_new_module = Button.new()
	btn_new_module.text = "New Module"
	btn_new_module.pressed.connect(_on_new_module)
	toolbox.add_child(btn_new_module)
	
	setup_toolbox()
	_setup_toolbox_context_menu()

	# HACK: If C++ toolbox is used, stick the buttons inside it or above it?
	# setup_toolbox adds a child. We want our buttons to persist.
	# But C++ toolbox might take up all space.
	# Let's Move buttons to TOP if setup_toolbox added below.
	
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
	
	# Add "Form Designer" button next to AssetLib in main screen bar.
	# It behaves like 2D/3D/Script — click activates, clicking others deactivates.
	_vb6_toggle_button = Button.new()
	_vb6_toggle_button.text = "Form Designer"
	_vb6_toggle_button.toggle_mode = true  # So it can show pressed state like siblings
	_vb6_toggle_button.tooltip_text = "Form Designer — VB6-style IDE with toolbox, properties & alignment toolbars"
	_vb6_toggle_button.flat = true
	_vb6_toggle_button.focus_mode = Control.FOCUS_NONE
	_vb6_toggle_button.pressed.connect(_on_form_designer_pressed)
	# Find the main screen button bar (parent of 2D/3D/Script/AssetLib)
	var _main_screen_bar = _find_main_screen_bar()
	if _main_screen_bar:
		_main_screen_bar.add_child(_vb6_toggle_button)
		print("VisualGasic: Added 'Form Designer' to main screen bar")
	else:
		add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _vb6_toggle_button)
		print("VisualGasic: Added 'Form Designer' to toolbar (fallback)")
	# Style after in tree so sibling theme lookups work
	call_deferred("_style_form_designer_button")

	_post_init()
	_setup_script_editor_context_menu()
	_setup_recent_projects_menu()

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

## No VB6 main screen tab. The form designer IS the Godot 2D viewport.
## VB6 mode = 2D viewport + VG dock panels (Toolbox, Properties, Project Explorer)
##         + VG toolbars (Alignment, Preview, Color Palette).
## Toggled via Project > Tools > Toggle VG IDE Layout.
func _has_main_screen() -> bool:
	return false

## Called by the editor after restoring saved window layout.
func _set_window_layout(config: ConfigFile):
	if is_instance_valid(_layout_manager):
		_layout_manager.on_window_layout_restored(config)

## Called by the editor when saving window layout.
func _get_window_layout(config: ConfigFile):
	if is_instance_valid(_layout_manager):
		_layout_manager.on_window_layout_saving(config)

## Called when the plugin exits the editor tree.
## Cleans up all plugin components and disconnects signals.
func _exit_tree():
	get_editor_interface().get_base_control().remove_meta("visual_gasic_plugin_instance")
	
	remove_import_plugin(import_plugin)
	import_plugin = null
	
	if debugger_plugin:
		remove_debugger_plugin(debugger_plugin)
		debugger_plugin = null
	
	# Remove Form Designer toggle button
	if is_instance_valid(_vb6_toggle_button):
		if _vb6_toggle_button.get_parent():
			_vb6_toggle_button.get_parent().remove_child(_vb6_toggle_button)
		_vb6_toggle_button.queue_free()
		_vb6_toggle_button = null
	
	remove_tool_menu_item("Toggle VG IDE Layout")
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
		if _vg_toolbars_in_container:
			remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, alignment_toolbar)
		elif alignment_toolbar.get_parent() == self:
			remove_child(alignment_toolbar)
		alignment_toolbar.queue_free()
		alignment_toolbar = null
	
	# Cleanup form preview toolbar
	if is_instance_valid(form_preview_toolbar):
		if _vg_toolbars_in_container:
			remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, form_preview_toolbar)
		elif form_preview_toolbar.get_parent() == self:
			remove_child(form_preview_toolbar)
		form_preview_toolbar.queue_free()
		form_preview_toolbar = null
	
	# Cleanup Color Palette toolbar
	if is_instance_valid(_color_palette):
		if _vg_toolbars_in_container:
			remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _color_palette)
		elif _color_palette.get_parent() == self:
			remove_child(_color_palette)
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

	# Cleanup VG panels — may be in docks or as plugin children
	if _vg_panels_docked:
		if is_instance_valid(toolbox):
			remove_control_from_docks(toolbox)
		if is_instance_valid(_project_explorer):
			remove_control_from_docks(_project_explorer)
		if is_instance_valid(_properties_inspector):
			remove_control_from_docks(_properties_inspector)
	else:
		if is_instance_valid(toolbox) and toolbox.get_parent() == self:
			remove_child(toolbox)
		if is_instance_valid(_project_explorer) and _project_explorer.get_parent() == self:
			remove_child(_project_explorer)
		if is_instance_valid(_properties_inspector) and _properties_inspector.get_parent() == self:
			remove_child(_properties_inspector)
	if is_instance_valid(toolbox):
		toolbox.queue_free()
		toolbox = null
	if is_instance_valid(_project_explorer):
		_project_explorer.queue_free()
		_project_explorer = null
	if is_instance_valid(_properties_inspector):
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
## Since _forward_canvas_gui_input doesn't receive mouse release during drag,
## we detect when dragging stops and handle the drop here.
func _process(_delta: float) -> void:
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
	if not is_instance_valid(_layout_manager):
		return
	if _vb6_toggle_button.button_pressed:
		# Button was just pressed ON - activate Form Designer
		if not _layout_manager.is_vb6_mode():
			_layout_manager.toggle()  # Activate
		else:
			# Already active - just ensure we are on 2D
			_layout_manager.switching_internally = true
			EditorInterface.set_main_screen_editor("2D")
			_layout_manager.switching_internally = false
		_update_main_screen_buttons(true)
	else:
		# Button was just pressed OFF - deactivate and go to 2D
		if _layout_manager.is_vb6_mode():
			_layout_manager._deactivate_vb6_mode()
		_layout_manager.switching_internally = true
		EditorInterface.set_main_screen_editor("2D")
		_layout_manager.switching_internally = false
		_update_main_screen_buttons(false)

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
	var VGThemeManager = load("res://addons/visual_gasic/vg_theme_manager.gd")
	if VGThemeManager and _current_code_edit and is_instance_valid(_current_code_edit):
		VGThemeManager.apply_to_code_edit(_current_code_edit)
		print("VisualGasic: Applied theme '", theme_name, "'")


## Updates the Form Designer button pressed state when mode changes.
func _on_vb6_mode_changed(is_vb6: bool) -> void:
	_update_main_screen_buttons(is_vb6)

## Syncs pressed/unpressed state of our button and the sibling main screen buttons.
func _update_main_screen_buttons(form_designer_active: bool) -> void:
	if not is_instance_valid(_vb6_toggle_button):
		return
	_vb6_toggle_button.set_pressed_no_signal(form_designer_active)
	if form_designer_active:
		# Unpress all sibling main screen buttons (2D, 3D, Script, etc.)
		var bar = _vb6_toggle_button.get_parent()
		if bar:
			for child in bar.get_children():
				if child is Button and child != _vb6_toggle_button and child.toggle_mode:
					child.set_pressed_no_signal(false)

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
	
	# Gold tint to stand out
	_vb6_toggle_button.add_theme_color_override("font_color", Color(0.95, 0.82, 0.2))
	_vb6_toggle_button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.3))
	_vb6_toggle_button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 0.5))
	_vb6_toggle_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.5))

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
# MODULE CREATION
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
func _on_menu_editor():
	var selected = get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		push_error("Please select a MenuBar node first")
		return
	
	var menu_bar = selected[0]
	if not menu_bar is MenuBar:
		push_error("Selected node must be a MenuBar")
		return
	
	var dlg = load("res://addons/visual_gasic/menu_editor.gd").new()
	dlg.set_menu_bar(menu_bar)
	dlg.menu_applied.connect(_on_menu_applied.bind(menu_bar))
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

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

## Registers the GDScript-extended tools (not in C++ defaults)
func _register_extended_tools():
	register_tool("VGComboBox", "HBoxContainer", "OptionButton", "res://addons/visual_gasic/prototypes/VGComboBox.tscn")
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
	
	for comp in enabled:
		register_tool(comp["name"], comp["class"], comp.get("icon", "Control"), comp["scene"], comp.get("category", "2D"))
	
	print("VisualGasic: Loaded ", enabled.size(), " custom/optional components")


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

## Determines if this plugin handles input for the given object.
## Returns true for Control and Node2D nodes to enable double-click event generation.
## @param object: The object being edited
## @returns: true if plugin should handle input for this object
func _handles(object):
	# Handle input for any Control or Node2D being edited
	return object is Control or object is Node2D

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
			
			# Open in Editor
			get_editor_interface().edit_resource(res)
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
						var new_code = "\n" + sub_name + "()\n    Print \"" + obj + " " + event + "\"\nEnd Sub\n"
						code_edit.text += new_code
						text = code_edit.text # Refresh for search
					
					# Goto Line
					var lines = text.split("\n")
					for i in lines.size():
						if lines[i].strip_edges().begins_with(sub_name):
							code_edit.set_caret_line(i + 1)
							code_edit.set_caret_column(4)
							code_edit.center_viewport_to_caret()
							code_edit.grab_focus()
							break
	else:
		await get_tree().create_timer(0.1).timeout
		_poll_for_inject(path, obj, event, attempts + 1)

## Called when the main editor screen changes (2D, 3D, Script, AssetLib).
## Switches toolbox tab to match the current view.
## Also: if Form Designer mode is active and user clicked a different screen,
## deactivate Form Designer (like switching away from any main screen).
## @param screen_name: Name of the screen ("2D", "3D", "Script", etc.)
func _on_main_screen_changed(screen_name: String):
	# Auto-deactivate Form Designer when user switches to another screen.
	# Guard: don't deactivate if WE triggered the screen change (e.g. activating VB6 → 2D).
	if is_instance_valid(_layout_manager) and _layout_manager.is_vb6_mode():
		if not _layout_manager.switching_internally:
			_layout_manager._deactivate_vb6_mode()
			_update_main_screen_buttons(false)
	
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
	else:
		printerr("VisualGasic: Toolbox not found!")

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
	var VGThemeManager = load("res://addons/visual_gasic/vg_theme_manager.gd")
	if VGThemeManager:
		VGThemeManager.apply_to_code_edit(code_edit)
	
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

