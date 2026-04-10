@tool
## VisualGasic Plugin Manager
##
## Discovers, loads, and manages VG IDE plugins from:
##   res://addons/visual_gasic/plugins/<name>/plugin.cfg
##
## Each plugin.cfg is an INI file:
##   [plugin]
##   name=AGCK
##   description=Arcade Game Construction Kit
##   script=agck_plugin.gd
##   enabled=true
##
## The manager creates toolbar buttons for each plugin and handles
## view switching in coordination with the host IDE plugin.
extends RefCounted

## Emitted when a plugin view should become active.
## The host IDE plugin connects to this to coordinate view switching.
signal plugin_activated(plugin_id: String)

## Emitted when all plugin views should be hidden (back to form).
signal all_plugins_deactivated

## Dictionary of loaded plugins: { "plugin_id": VGPluginBase instance }
var _plugins: Dictionary = {}

## Dictionary of plugin metadata: { "plugin_id": { name, description, script_path, enabled } }
var _plugin_meta: Dictionary = {}

## Dictionary of toolbar buttons: { "plugin_id": Button }
var _toolbar_buttons: Dictionary = {}

## Currently active plugin ID (empty string = none)
var _active_plugin_id: String = ""

## Reference to host IDE plugin
var _host_plugin = null

## Reference to the toolbar HBoxContainer where buttons are added
var _toolbar_row: HBoxContainer = null

## Reference to CanvasRightSplit where plugin views are parented
var _canvas_right_split: Control = null

## Plugins base path
const PLUGINS_DIR = "res://addons/visual_gasic/plugins/"


# ─── Initialization ─────────────────────────────────────────

## Set up the manager with references to the host IDE.
func setup(host_plugin, toolbar_row: HBoxContainer, canvas_right_split: Control) -> void:
	_host_plugin = host_plugin
	_toolbar_row = toolbar_row
	_canvas_right_split = canvas_right_split


## Discover and load all plugins from the plugins/ directory.
func discover_plugins() -> void:
	var dir = DirAccess.open(PLUGINS_DIR)
	if not dir:
		print("VisualGasic: No plugins directory found at ", PLUGINS_DIR)
		return

	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var cfg_path = PLUGINS_DIR + folder_name + "/plugin.cfg"
			if FileAccess.file_exists(cfg_path):
				_load_plugin(folder_name, cfg_path)
		folder_name = dir.get_next()
	dir.list_dir_end()

	print("VisualGasic: Plugin Manager loaded ", _plugins.size(), " plugin(s)")


## Load a single plugin from its config file.
func _load_plugin(plugin_id: String, cfg_path: String) -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(cfg_path)
	if err != OK:
		push_warning("VisualGasic: Failed to load plugin config: " + cfg_path)
		return

	var meta = {
		"name": cfg.get_value("plugin", "name", plugin_id),
		"description": cfg.get_value("plugin", "description", ""),
		"script": cfg.get_value("plugin", "script", ""),
		"enabled": cfg.get_value("plugin", "enabled", true),
	}
	_plugin_meta[plugin_id] = meta

	if not meta["enabled"]:
		print("VisualGasic: Plugin '", meta["name"], "' is disabled, skipping")
		return

	if meta["script"].is_empty():
		push_warning("VisualGasic: Plugin '", meta["name"], "' has no script defined")
		return

	var script_path = PLUGINS_DIR + plugin_id + "/" + meta["script"]
	var plugin_script = load(script_path)
	if not plugin_script:
		push_warning("VisualGasic: Failed to load plugin script: " + script_path)
		return

	var plugin_instance = plugin_script.new()

	# Initialize the plugin — this creates its view Control
	var view = plugin_instance.initialize(_host_plugin, self)
	if not view:
		push_warning("VisualGasic: Plugin '", meta["name"], "' returned null view")
		return

	# Connect back-to-form signal
	plugin_instance.back_to_form_requested.connect(_on_plugin_back_to_form)

	# Add view to the canvas area (hidden)
	_canvas_right_split.add_child(view)

	# Create toolbar button
	_create_toolbar_button(plugin_id, plugin_instance)

	# Store the plugin
	_plugins[plugin_id] = plugin_instance

	print("VisualGasic: Plugin '", meta["name"], "' loaded successfully")


## Create a styled toolbar button for a plugin.
func _create_toolbar_button(plugin_id: String, plugin_instance) -> void:
	if not is_instance_valid(_toolbar_row):
		return

	var btn = Button.new()
	btn.name = "VGPluginBtn_" + plugin_id
	btn.text = "  " + plugin_instance.get_toolbar_icon() + " " + plugin_instance.get_plugin_name() + "  "
	btn.tooltip_text = plugin_instance.get_toolbar_tooltip()
	btn.flat = false
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))

	var base_color: Color = plugin_instance.get_toolbar_color()
	var style = StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = base_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = base_color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Bind the button press to activate this plugin
	btn.pressed.connect(_on_plugin_button_pressed.bind(plugin_id))

	# Insert before the spacer (second-to-last child = spacer, last = Godot btn)
	# Find the spacer to insert before it
	var insert_idx = _toolbar_row.get_child_count()
	for i in range(_toolbar_row.get_child_count()):
		var child = _toolbar_row.get_child(i)
		if child.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
			insert_idx = i
			break
	_toolbar_row.add_child(btn)
	_toolbar_row.move_child(btn, insert_idx)

	_toolbar_buttons[plugin_id] = btn


# ─── View Switching ──────────────────────────────────────────

## Called when a plugin's toolbar button is pressed.
func _on_plugin_button_pressed(plugin_id: String) -> void:
	if _active_plugin_id == plugin_id:
		return  # Already active
	activate_plugin(plugin_id)


## Activate a specific plugin's view.
func activate_plugin(plugin_id: String) -> void:
	# Deactivate current plugin if any
	if not _active_plugin_id.is_empty() and _plugins.has(_active_plugin_id):
		_plugins[_active_plugin_id].deactivate()

	_active_plugin_id = plugin_id

	# Notify the host IDE so it can hide its own views
	plugin_activated.emit(plugin_id)

	# Activate the new plugin
	if _plugins.has(plugin_id):
		_plugins[plugin_id].activate()


## Deactivate all plugins (called when switching to Form/Code/3D/2D/Sprite views).
func deactivate_all() -> void:
	if not _active_plugin_id.is_empty() and _plugins.has(_active_plugin_id):
		_plugins[_active_plugin_id].deactivate()
	_active_plugin_id = ""


## Called when a plugin requests back-to-form.
func _on_plugin_back_to_form() -> void:
	deactivate_all()
	all_plugins_deactivated.emit()


## Check if any plugin is currently active.
func has_active_plugin() -> bool:
	return not _active_plugin_id.is_empty()


## Get the currently active plugin ID.
func get_active_plugin_id() -> String:
	return _active_plugin_id


## Get a loaded plugin instance by ID.
func get_plugin(plugin_id: String):
	return _plugins.get(plugin_id, null)


## Get all loaded plugin IDs.
func get_plugin_ids() -> Array:
	return _plugins.keys()


# ─── Cleanup ────────────────────────────────────────────────

## Clean up all plugins.
func cleanup() -> void:
	for plugin_id in _plugins:
		_plugins[plugin_id].cleanup()
	_plugins.clear()
	_plugin_meta.clear()
	for btn_id in _toolbar_buttons:
		if is_instance_valid(_toolbar_buttons[btn_id]):
			_toolbar_buttons[btn_id].queue_free()
	_toolbar_buttons.clear()
	_active_plugin_id = ""
