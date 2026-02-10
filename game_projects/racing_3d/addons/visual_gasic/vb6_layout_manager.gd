@tool
extends HBoxContainer
## Layout Manager for Visual Gasic
##
## Provides a toggle between the standard Godot editor layout and a
## Visual Gasic layout matching the classic Visual Basic 6 IDE:
##
## Visual Gasic Layout:
##   LEFT       : Toolbox (control palette)
##   CENTER     : Form Designer (2D) / Code Editor (Script)
##   RIGHT-TOP  : Project Explorer
##   RIGHT-BOT  : Properties Window
##   BOTTOM     : Immediate Window
##
## Godot Layout (default):
##   Standard Godot editor — Visual Gasic panels (Toolbox, Properties,
##   Project Explorer) removed from docks so they don't clutter the
##   native Godot workflow.

# =============================================================================
# SIGNALS
# =============================================================================

signal layout_changed(is_vb6_mode: bool)

# =============================================================================
# CONSTANTS
# =============================================================================

const SETTING_KEY := "visual_gasic/layout/vb6_mode"

# =============================================================================
# MEMBER VARIABLES
# =============================================================================

var editor_plugin: EditorPlugin

## The toggle button
var _toggle_btn: Button

## True when VB6 layout is active
var _vb6_mode: bool = false

## Visual Gasic panels managed by this layout manager
var _toolbox: Control = null
var _project_explorer: Control = null
var _properties_inspector: Control = null

## Track whether each panel is currently docked
var _toolbox_docked: bool = false
var _project_explorer_docked: bool = false
var _properties_docked: bool = false

## Godot dock tabs hidden while in VG mode (for restoration)
var _hidden_godot_tabs: Array = []

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init():
	name = "VGLayoutToggle"
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = SIZE_SHRINK_CENTER

	add_child(VSeparator.new())

	_toggle_btn = Button.new()
	_toggle_btn.text = "  Visual Gasic IDE  "
	_toggle_btn.tooltip_text = "Switch to Visual Gasic IDE layout\n(Toolbox left, Project Explorer top-right, Properties bottom-right)"
	_toggle_btn.toggle_mode = true
	_toggle_btn.flat = false
	_toggle_btn.custom_minimum_size = Vector2(130, 0)
	_toggle_btn.toggled.connect(_on_toggle)
	add_child(_toggle_btn)

	add_child(VSeparator.new())

## Setup with plugin reference and the Visual Gasic panels.
## @param plugin: The EditorPlugin instance (needed for dock API)
## @param toolbox_control: Toolbox panel (or null)
## @param project_explorer: Project Explorer panel (or null)
## @param properties_inspector: Properties panel (or null)
func setup(plugin: EditorPlugin, toolbox_control: Control = null, project_explorer: Control = null, properties_inspector: Control = null):
	editor_plugin = plugin
	_toolbox = toolbox_control
	_project_explorer = project_explorer
	_properties_inspector = properties_inspector

	# Restore saved preference (deferred so editor is ready)
	if ProjectSettings.has_setting(SETTING_KEY):
		var saved = ProjectSettings.get_setting(SETTING_KEY)
		if saved is bool and saved:
			call_deferred("_activate_vb6_mode")

## Cleanup — undock any panels we docked.
func cleanup():
	_undock_vb6_panels()

# =============================================================================
# TOGGLE
# =============================================================================

func _on_toggle(pressed: bool):
	if pressed:
		_activate_vb6_mode()
	else:
		_deactivate_vb6_mode()

func _activate_vb6_mode():
	if _vb6_mode:
		return
	_vb6_mode = true
	_toggle_btn.button_pressed = true
	_toggle_btn.text = "  Godot IDE  "
	_toggle_btn.tooltip_text = "Switch back to standard Godot editor layout"

	ProjectSettings.set_setting(SETTING_KEY, true)

	# Dock the Visual Gasic panels
	_dock_vb6_panels()

	layout_changed.emit(true)
	print("VisualGasic: Switched to Visual Gasic IDE layout")

func _deactivate_vb6_mode():
	if not _vb6_mode:
		return
	_vb6_mode = false
	_toggle_btn.button_pressed = false
	_toggle_btn.text = "  Visual Gasic IDE  "
	_toggle_btn.tooltip_text = "Switch to Visual Gasic IDE layout"

	ProjectSettings.set_setting(SETTING_KEY, false)

	# Undock the Visual Gasic panels
	_undock_vb6_panels()

	layout_changed.emit(false)
	print("VisualGasic: Restored Godot editor layout")

# =============================================================================
# DOCK MANAGEMENT
# =============================================================================

## Add Visual Gasic panels to the editor docks.
func _dock_vb6_panels():
	if not editor_plugin:
		return

	# Toolbox → Left-Lower dock (like VB6)
	if _toolbox and is_instance_valid(_toolbox) and not _toolbox_docked:
		editor_plugin.add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, _toolbox)
		_toolbox_docked = true
	if _toolbox and is_instance_valid(_toolbox):
		_toolbox.visible = true

	# Project Explorer → Right-Upper dock (like VB6)
	if _project_explorer and is_instance_valid(_project_explorer) and not _project_explorer_docked:
		editor_plugin.add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _project_explorer)
		_project_explorer_docked = true
	if _project_explorer and is_instance_valid(_project_explorer):
		_project_explorer.visible = true
		if _project_explorer.has_method("refresh"):
			_project_explorer.call_deferred("refresh")
		# Make Project Explorer the active tab in its dock (deferred so layout is ready)
		call_deferred("_select_tab_for", _project_explorer)

	# Properties Inspector → Right-Lower dock (like VB6)
	if _properties_inspector and is_instance_valid(_properties_inspector) and not _properties_docked:
		editor_plugin.add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, _properties_inspector)
		_properties_docked = true
	if _properties_inspector and is_instance_valid(_properties_inspector):
		_properties_inspector.visible = true

	# Hide standard Godot docks that clutter the VG layout
	_hide_godot_docks()

	# Adjust dock split widths so panels aren't squished (deferred so layout is settled)
	call_deferred("_adjust_dock_widths")

## Remove Visual Gasic panels from the editor docks.
func _undock_vb6_panels():
	if not editor_plugin:
		return

	# Restore standard Godot docks first
	_show_godot_docks()

	if _toolbox_docked and _toolbox and is_instance_valid(_toolbox):
		editor_plugin.remove_control_from_docks(_toolbox)
		_toolbox.visible = false
		_toolbox_docked = false

	if _project_explorer_docked and _project_explorer and is_instance_valid(_project_explorer):
		editor_plugin.remove_control_from_docks(_project_explorer)
		_project_explorer.visible = false
		_project_explorer_docked = false

	if _properties_docked and _properties_inspector and is_instance_valid(_properties_inspector):
		editor_plugin.remove_control_from_docks(_properties_inspector)
		_properties_inspector.visible = false
		_properties_docked = false

# =============================================================================
# DOCK WIDTH ADJUSTMENT
# =============================================================================

## Desired pixel widths for the VB6 dock panels.
const LEFT_DOCK_WIDTH := 230
const RIGHT_DOCK_WIDTH := 280

## After docking, walk up the node tree from each panel to find the parent
## HSplitContainer and adjust its split_offset so panels aren't squished.
## Must be called deferred (after the editor has finished layout).
func _adjust_dock_widths():
	# --- Left dock (Toolbox) ---
	if _toolbox and is_instance_valid(_toolbox):
		var hsplit = _find_dock_hsplit(_toolbox)
		if hsplit:
			# Toolbox is in the FIRST child of this HSplitContainer.
			# A positive split_offset pushes the divider right → more room for left child.
			var first_child = hsplit.get_child(0) if hsplit.get_child_count() > 0 else null
			if first_child:
				var current_w = first_child.size.x
				if current_w < LEFT_DOCK_WIDTH:
					hsplit.split_offset += (LEFT_DOCK_WIDTH - int(current_w))

	# --- Right dock (Properties / Project Explorer) ---
	var right_panel = _properties_inspector if (_properties_inspector and is_instance_valid(_properties_inspector)) else _project_explorer
	if right_panel and is_instance_valid(right_panel):
		var hsplit = _find_dock_hsplit(right_panel)
		if hsplit:
			# Right panels are in the SECOND (last) child of the HSplitContainer.
			var last_child = hsplit.get_child(hsplit.get_child_count() - 1) if hsplit.get_child_count() > 1 else null
			if last_child:
				var current_w = last_child.size.x
				if current_w < RIGHT_DOCK_WIDTH:
					hsplit.split_offset -= (RIGHT_DOCK_WIDTH - int(current_w))

	# Ensure the split dragger handles are visible (not collapsed)
	_ensure_draggers_visible()

## Walk up from a docked control to find the HSplitContainer that governs
## the dock column width.  Stops at the first HSplitContainer that has at
## least two children (the split between dock area and center/other docks).
func _find_dock_hsplit(control: Control) -> HSplitContainer:
	var node = control.get_parent()
	while node:
		if node is HSplitContainer and node.get_child_count() >= 2:
			return node
		node = node.get_parent()
	return null

## Make sure all HSplitContainer dragger handles in the main editor are
## visible so the user can drag to resize panels.
func _ensure_draggers_visible():
	var base = EditorInterface.get_base_control()
	if not base:
		return
	for split_node in base.find_children("*", "HSplitContainer", true, false):
		var hsplit = split_node as HSplitContainer
		if hsplit:
			hsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	for split_node in base.find_children("*", "VSplitContainer", true, false):
		var vsplit = split_node as VSplitContainer
		if vsplit:
			vsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE

# =============================================================================
# GODOT DOCK VISIBILITY
# =============================================================================

## Hide the standard Godot docks (FileSystem, Scene, Import) in VG mode.
## Uses tab titles for matching (reliable) and stores control references
## for restoration (immune to tab index shifts from docking/undocking).
## When ALL tabs in a TabContainer become hidden, the container itself
## is hidden so it doesn't leave a blank panel.
func _hide_godot_docks():
	_hidden_godot_tabs.clear()

	var base = EditorInterface.get_base_control()
	if not base:
		return

	var fs_dock = EditorInterface.get_file_system_dock()

	var hide_titles := ["Scene", "Import", "FileSystem"]
	var hide_classes := ["SceneTreeDock", "ImportDock", "FileSystemDock"]

	# Track which TabContainers we touched so we can check if fully empty
	var modified_containers: Array[TabContainer] = []

	for tc_node in base.find_children("*", "TabContainer", true, false):
		var tc = tc_node as TabContainer
		if not tc:
			continue
		var touched := false
		for i in tc.get_tab_count():
			if tc.is_tab_hidden(i):
				continue
			var child = tc.get_tab_control(i)
			if not child:
				continue
			var title = tc.get_tab_title(i)
			var should_hide = title in hide_titles
			if not should_hide:
				should_hide = child.get_class() in hide_classes
			if not should_hide and fs_dock and child == fs_dock:
				should_hide = true
			if should_hide:
				tc.set_tab_hidden(i, true)
				_hidden_godot_tabs.append({"type": "tab", "container": tc, "control": child})
				touched = true
		if touched:
			modified_containers.append(tc)

	# If ALL tabs in a container are now hidden, hide the container itself
	# so it doesn't leave a blank panel occupying space.
	for tc in modified_containers:
		var all_hidden := true
		for i in tc.get_tab_count():
			if not tc.is_tab_hidden(i):
				all_hidden = false
				break
		if all_hidden and tc.visible:
			tc.visible = false
			_hidden_godot_tabs.append({"type": "container", "container": tc})

## Restore all Godot docks that were hidden by _hide_godot_docks().
## Restores container visibility first, then individual tabs.
func _show_godot_docks():
	# Pass 1: restore hidden containers so their tabs become accessible
	for tab_info in _hidden_godot_tabs:
		if tab_info["type"] == "container":
			var tc = tab_info["container"] as TabContainer
			if is_instance_valid(tc):
				tc.visible = true

	# Pass 2: unhide individual tabs
	for tab_info in _hidden_godot_tabs:
		if tab_info["type"] == "tab":
			var tc = tab_info["container"] as TabContainer
			var ctrl = tab_info["control"] as Control
			if is_instance_valid(tc) and is_instance_valid(ctrl):
				var idx = tc.get_tab_idx_from_control(ctrl)
				if idx >= 0:
					tc.set_tab_hidden(idx, false)

	_hidden_godot_tabs.clear()

# =============================================================================
# TAB SELECTION
# =============================================================================

## Make a docked control the active tab in its TabContainer.
func _select_tab_for(control: Control):
	if not is_instance_valid(control):
		return
	var parent = control.get_parent()
	if parent is TabContainer:
		var tc := parent as TabContainer
		var idx = tc.get_tab_idx_from_control(control)
		if idx >= 0:
			tc.current_tab = idx

# =============================================================================
# STATE QUERY
# =============================================================================

func is_vb6_mode() -> bool:
	return _vb6_mode
