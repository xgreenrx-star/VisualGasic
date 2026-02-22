@tool
extends Node
## VB6 Layout Manager for VisualGasic
##
## Two completely separate modes:
##
##   GODOT MODE (default):
##     - Standard Godot docks only (Scene, Inspector, FileSystem, etc.)
##     - ZERO VG panels in docks — clean Godot experience
##     - Panels are hidden children of plugin node (not docked)
##
##   VB6 MODE (toggled via Project > Tools > Toggle VG IDE Layout):
##     - VG panels dynamically ADDED to Godot docks:
##       Toolbox (left), Properties (right-bottom), Project Explorer (right-upper)
##     - Panels are real dock tabs — fully resizable by Godot's dock system
##     - Persist across VB6 tab ↔ 2D tab switching (for form design)
##     - Toggle again to cleanly REMOVE them from docks
##
## The key: panels are added/removed from docks via
##   editor_plugin.dock_vg_panels() / editor_plugin.undock_vg_panels()
## NOT via visible=true/false (which leaves empty dock slots).

signal layout_changed(is_vb6_mode: bool)

const SETTING_KEY := "visual_gasic/layout/vb6_mode"

var editor_plugin: EditorPlugin
var _vb6_mode: bool = false
var _main_screen: Control = null
## Guard flag: true while we're calling set_main_screen_editor internally,
## so the plugin's main_screen_changed handler won't re-trigger deactivation.
var switching_internally: bool = false

# Extra toolbars to hide/show with mode
var _compact_toolbars: Array = []

func setup(plugin: EditorPlugin, _toolbox: Control = null, _proj_explorer: Control = null, _props_inspector: Control = null, compact_toolbars: Array = []):
	editor_plugin = plugin
	_compact_toolbars = compact_toolbars
	# Check if VB6 mode was saved from last session
	if ProjectSettings.has_setting(SETTING_KEY):
		var saved = ProjectSettings.get_setting(SETTING_KEY)
		if saved is bool and saved:
			_vb6_mode = true

func set_main_screen(main_screen: Control):
	_main_screen = main_screen

func cleanup():
	# Undock panels + toolbars before plugin exits (so cleanup can free them)
	if _vb6_mode and editor_plugin and is_instance_valid(editor_plugin):
		editor_plugin.undock_vg_panels()
		editor_plugin.undock_vg_toolbars()

# === LAYOUT PERSISTENCE ===

func on_window_layout_restored(config: ConfigFile):
	if _main_screen and is_instance_valid(_main_screen) and _main_screen.has_method("restore_layout"):
		_main_screen.restore_layout(config)
	# Restore VB6 mode if it was active last session
	if _vb6_mode:
		call_deferred("_activate_vb6_mode")

func on_window_layout_saving(config: ConfigFile):
	config.set_value("VisualGasic", "vb6_mode", _vb6_mode)
	if _main_screen and is_instance_valid(_main_screen) and _main_screen.has_method("save_layout"):
		_main_screen.save_layout(config)

# === MODE TOGGLE ===

func toggle():
	if _vb6_mode:
		_deactivate_vb6_mode()
	else:
		_activate_vb6_mode()

func _activate_vb6_mode():
	_vb6_mode = true
	ProjectSettings.set_setting(SETTING_KEY, true)
	# Add VG panels to Godot docks + toolbars to 2D canvas bar
	if editor_plugin and is_instance_valid(editor_plugin):
		editor_plugin.dock_vg_panels()
		editor_plugin.dock_vg_toolbars()
	# Do NOT switch the main screen here. The user is already on
	# Form Designer (which triggered this). Switching to 2D would hide
	# the Form Designer and cascade back to _make_visible(false).
	layout_changed.emit(true)
	print("VisualGasic: VB6 mode ON — panels docked, toolbars visible")

func _deactivate_vb6_mode():
	if not _vb6_mode:
		return
	_vb6_mode = false
	ProjectSettings.set_setting(SETTING_KEY, false)
	# Remove VG panels from docks + toolbars from 2D bar (clean Godot mode)
	if editor_plugin and is_instance_valid(editor_plugin):
		editor_plugin.undock_vg_panels()
		editor_plugin.undock_vg_toolbars()
	# Don't call set_main_screen_editor here — the user is already switching
	# to another screen, or we're being called from the plugin's handler.
	layout_changed.emit(false)
	print("VisualGasic: VB6 mode OFF — docks cleaned")

# === TOOLBAR MANAGEMENT ===
# Toolbars are now dynamically added/removed from the 2D canvas editor menu
# via editor_plugin.dock_vg_toolbars() / editor_plugin.undock_vg_toolbars()
# (same pattern as dock panels — visible=false still reserves layout space)

func is_vb6_mode() -> bool:
	return _vb6_mode
