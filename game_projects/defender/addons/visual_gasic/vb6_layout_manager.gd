@tool
extends HBoxContainer
## Layout Manager for Visual Gasic
##
## Provides a toggle between the standard Godot editor layout and a
## Visual Gasic layout matching the classic Visual Basic 6 IDE.

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
var _toggle_btn: Button
var _vb6_mode: bool = false

var _toolbox: Control = null
var _project_explorer: Control = null
var _properties_inspector: Control = null

var _toolbox_docked: bool = false
var _project_explorer_docked: bool = false
var _properties_docked: bool = false

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
	_toggle_btn.tooltip_text = "Switch to Visual Gasic IDE layout"
	_toggle_btn.toggle_mode = true
	_toggle_btn.flat = false
	_toggle_btn.custom_minimum_size = Vector2(130, 0)
	_toggle_btn.toggled.connect(_on_toggle)
	add_child(_toggle_btn)
	add_child(VSeparator.new())

func setup(plugin: EditorPlugin, toolbox_control: Control = null, project_explorer: Control = null, properties_inspector: Control = null):
	editor_plugin = plugin
	_toolbox = toolbox_control
	_project_explorer = project_explorer
	_properties_inspector = properties_inspector
	if ProjectSettings.has_setting(SETTING_KEY):
		var saved = ProjectSettings.get_setting(SETTING_KEY)
		if saved is bool and saved:
			call_deferred("_activate_vb6_mode")

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
	_undock_vb6_panels()
	layout_changed.emit(false)
	print("VisualGasic: Restored Godot editor layout")

# =============================================================================
# DOCK MANAGEMENT
# =============================================================================

func _dock_vb6_panels():
	if not editor_plugin:
		return
	if _toolbox and is_instance_valid(_toolbox) and not _toolbox_docked:
		editor_plugin.add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, _toolbox)
		_toolbox_docked = true
	if _toolbox and is_instance_valid(_toolbox):
		_toolbox.visible = true
	if _project_explorer and is_instance_valid(_project_explorer) and not _project_explorer_docked:
		editor_plugin.add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _project_explorer)
		_project_explorer_docked = true
	if _project_explorer and is_instance_valid(_project_explorer):
		_project_explorer.visible = true
		if _project_explorer.has_method("refresh"):
			_project_explorer.call_deferred("refresh")
		call_deferred("_select_tab_for", _project_explorer)
	if _properties_inspector and is_instance_valid(_properties_inspector) and not _properties_docked:
		editor_plugin.add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, _properties_inspector)
		_properties_docked = true
	if _properties_inspector and is_instance_valid(_properties_inspector):
		_properties_inspector.visible = true
	_hide_godot_docks()

func _undock_vb6_panels():
	if not editor_plugin:
		return
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
# GODOT DOCK VISIBILITY
# =============================================================================

func _hide_godot_docks():
	_hidden_godot_tabs.clear()
	var base = EditorInterface.get_base_control()
	if not base:
		return
	var fs_dock = EditorInterface.get_file_system_dock()
	var hide_titles := ["Scene", "Import", "FileSystem"]
	var hide_classes := ["SceneTreeDock", "ImportDock", "FileSystemDock"]
	for tc_node in base.find_children("*", "TabContainer", true, false):
		var tc = tc_node as TabContainer
		if not tc:
			continue
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
				_hidden_godot_tabs.append({"container": tc, "control": child})

func _show_godot_docks():
	for tab_info in _hidden_godot_tabs:
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
