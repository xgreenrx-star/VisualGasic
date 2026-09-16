@tool
## Base class for VisualGasic IDE plugins.
##
## Extend this class to create a plugin that registers an editor tab
## inside the VG IDE.  The plugin manager discovers plugins from
##   addons/visual_gasic/plugins/<name>/plugin.cfg
## and calls the lifecycle methods below.
##
## Minimal plugin example:
##   @tool
##   extends "res://addons/visual_gasic/vg_plugin_base.gd"
##   func get_plugin_name() -> String: return "My Plugin"
##   func get_toolbar_icon() -> String: return "🔧"
##   func get_toolbar_color() -> Color: return Color(0.3, 0.3, 0.5)
##   func _build_ui() -> void:
##       var label = Label.new(); label.text = "Hello from plugin!"
##       _view.add_child(label)
extends RefCounted

## Emitted when the plugin wants to return to Form view
signal back_to_form_requested

## The root Control that is added to CanvasRightSplit.
## Created automatically — plugins add children to it via _build_ui().
var _view: Control = null

## Reference to the host IDE plugin (visual_gasic_plugin.gd) — set by the manager.
var _host_plugin = null

## Reference to the plugin manager — set by the manager.
var _manager = null

## Whether this plugin's view is currently visible.
var _is_active: bool = false


# ─── Override These ──────────────────────────────────────────

## Return the display name shown in the toolbar button and status bar.
func get_plugin_name() -> String:
	return "Unnamed Plugin"

## Return an emoji or short text prefix for the toolbar button.
func get_toolbar_icon() -> String:
	return "🔌"

## Return the background color for the toolbar button (normal state).
func get_toolbar_color() -> Color:
	return Color(0.35, 0.35, 0.4)

## Return a tooltip for the toolbar button.
func get_toolbar_tooltip() -> String:
	return "Switch to " + get_plugin_name()

## Called once after the view Control is created.
## Override to build your UI inside _view.
func _build_ui() -> void:
	pass

## Called every time the plugin tab becomes visible.
func _on_activated() -> void:
	pass

## Called every time the plugin tab becomes hidden.
func _on_deactivated() -> void:
	pass

## Called when the host plugin exits the tree (cleanup).
func _on_cleanup() -> void:
	pass


# ─── Lifecycle (called by VGPluginManager — do not override) ────

## Initialize the plugin: create the root view, call _build_ui().
func initialize(host_plugin, manager) -> Control:
	_host_plugin = host_plugin
	_manager = manager

	# Create the root container for this plugin's UI
	_view = HSplitContainer.new()
	_view.name = "VGPlugin_" + get_plugin_name().replace(" ", "_")
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.visible = false

	# Let the plugin populate its UI
	_build_ui()

	return _view

## Show this plugin's view.
func activate() -> void:
	if _view:
		_view.visible = true
	_is_active = true
	_on_activated()

## Hide this plugin's view.
func deactivate() -> void:
	if _view:
		_view.visible = false
	_is_active = false
	_on_deactivated()

## Final cleanup.
func cleanup() -> void:
	_on_cleanup()
	if is_instance_valid(_view):
		_view.queue_free()
		_view = null

## Request returning to form view (convenience for sub-editors).
func request_back_to_form() -> void:
	back_to_form_requested.emit()
