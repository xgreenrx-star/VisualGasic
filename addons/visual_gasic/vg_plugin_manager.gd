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

## Whether the "🔌 Plugins" separator label has been added to toolbar
var _plugin_separator_added: bool = false

## Reference to plugin settings popup
var _settings_popup: Window = null

## Reference to the gear button on toolbar
var _gear_btn: Button = null

## Reference to the overflow "⋯" menu button for when plugins don't fit
var _overflow_btn: MenuButton = null

## Ordered list of plugin IDs for overflow management
var _plugin_order: Array = []

## Maximum number of visible plugin buttons before overflow kicks in
const MAX_VISIBLE_PLUGINS = 6

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

	# Built-in entries — surface bundled IDE modes (Form Designer, etc.)
	# alongside discovered plugins so users see them in the same strip and
	# can switch to them without remembering a hidden setting. These don't
	# go through the VGPluginBase activation flow because they're built
	# into the host plugin already; the button just calls the host's view
	# switcher directly.
	_register_builtin_form_designer()

	print("VisualGasic: Plugin Manager loaded ", _plugins.size(), " plugin(s)")


## Project setting path for the built-in Form Designer toggle. Stored
## on the project rather than globally so users can disable the legacy
## VB6-style designer on a per-project basis (new code-first projects
## typically don't need it taking up toolbar space).
const BUILTIN_FORM_DESIGNER_ID := "__builtin_form_designer__"
const BUILTIN_FORM_DESIGNER_SETTING := "vg/form_designer_enabled"


## Register the Form Designer as a pseudo-plugin: gets a row in the
## Plugin Settings dialog and (when enabled) a button in the plugin
## strip. Toggle state is persisted in vg/form_designer_enabled.
func _register_builtin_form_designer() -> void:
	var enabled := true
	if ProjectSettings.has_setting(BUILTIN_FORM_DESIGNER_SETTING):
		enabled = bool(ProjectSettings.get_setting(BUILTIN_FORM_DESIGNER_SETTING, true))

	# Meta entry — the settings popup iterates _plugin_meta, so adding a
	# row here is all that's needed for it to appear in the dialog. The
	# "_builtin" flag tells the toggle handler to write to ProjectSettings
	# instead of looking for a plugin.cfg on disk.
	_plugin_meta[BUILTIN_FORM_DESIGNER_ID] = {
		"name": "Form Designer",
		"description": "Legacy VB6-style visual form designer. Drag controls onto a canvas, set properties, and wire up events. Built-in — disable if you prefer code-only workflow.",
		"script": "",
		"enabled": enabled,
		"_builtin": true,
	}

	if not enabled:
		return  # Don't add the strip button; user has opted out.

	_add_form_designer_strip_button()


## Add the "🎨 Form Designer" button to the plugin strip. Split out so
## _on_plugin_toggle() can recreate it if the user re-enables the
## designer without restarting.
func _add_form_designer_strip_button() -> void:
	if not is_instance_valid(_toolbar_row) or not _host_plugin:
		return
	if _toolbar_row.find_child("VGBuiltinBtn_FormDesigner", false, false):
		return  # Already present.
	if not is_instance_valid(_toolbar_row) or not _host_plugin:
		return

	# Reuse the gear-button setup if discover_plugins() found nothing.
	if not _plugin_separator_added:
		_plugin_separator_added = true
		_gear_btn = Button.new()
		_gear_btn.name = "PluginSettingsBtn"
		_gear_btn.text = "⚙"
		_gear_btn.tooltip_text = "Plugin Settings — enable/disable or install plugins"
		_gear_btn.flat = true
		_gear_btn.add_theme_font_size_override("font_size", 12)
		_gear_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		_gear_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		_gear_btn.pressed.connect(_show_settings_popup)
		_toolbar_row.add_child(_gear_btn)

	var btn := Button.new()
	btn.name = "VGBuiltinBtn_FormDesigner"
	btn.text = "🎨 Form Designer"
	btn.tooltip_text = "Switch to the visual Form Designer (legacy VB6 mode)"
	btn.flat = false
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

	var base_color := Color(0.42, 0.32, 0.55)  # muted purple
	var style := StyleBoxFlat.new()
	style.bg_color = base_color.darkened(0.1)
	style.set_corner_radius_all(10)
	style.border_color = base_color.lightened(0.35)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = base_color.lightened(0.1)
	hover_style.border_color = Color(1.0, 1.0, 1.0, 0.6)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.pressed.connect(_on_builtin_form_designer_pressed)
	_toolbar_row.add_child(btn)
	print("VisualGasic: Built-in 'Form Designer' entry added to plugin strip")


func _on_builtin_form_designer_pressed() -> void:
	# Switch IDE to form view. Goes through host's _show_form_view so any
	# active plugin/code/3D view is properly torn down first.
	if _host_plugin and _host_plugin.has_method("_show_form_view"):
		_host_plugin._show_form_view()


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
		"autoloads": _read_autoloads_section(cfg, plugin_id),
		# Capability fields — optional [capabilities] section in plugin.cfg.
		# Plugins use these to advertise what they can do (e.g. edit sprites)
		# so VGPluginRegistry can route open-asset requests to the right one.
		"provides": cfg.get_value("capabilities", "provides", []),
		"handles_extensions": cfg.get_value("capabilities", "handles_extensions", []),
		"priority": int(cfg.get_value("capabilities", "priority", 0)),
	}
	_plugin_meta[plugin_id] = meta

	# Register with capability registry up front (even if disabled), so
	# the settings/command-palette UIs can list every known plugin.
	VGPluginRegistry.get_instance().register_provider(plugin_id, meta, null)

	if not meta["enabled"]:
		print("VisualGasic: Plugin '", meta["name"], "' is disabled, skipping")
		return

	# Register autoloads BEFORE loading the plugin script — the plugin's
	# scripts may reference autoload identifiers that GDScript resolves at
	# parse time. If any new autoloads were added, the user must restart
	# VisualGasic for them to take effect (Godot autoloads are only
	# wired into the global scope at engine startup).
	if not meta["autoloads"].is_empty():
		var paths_unhidden := _unhide_autoload_paths(plugin_id, meta["autoloads"])
		var newly_added := _register_plugin_autoloads(plugin_id, meta["autoloads"])
		if newly_added or paths_unhidden:
			ProjectSettings.save()
			push_warning("VisualGasic: Plugin '%s' added autoloads. Restart VisualGasic to activate them." % meta["name"])
			# Don't try to load the plugin script this session — it will
			# fail to parse because the autoload identifiers aren't bound.
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

	# Now that the live instance exists, attach it to the registry so
	# capability-based routing (open_asset, find_providers) can dispatch
	# to it.
	VGPluginRegistry.get_instance().attach_instance(plugin_id, plugin_instance)

	print("VisualGasic: Plugin '", meta["name"], "' loaded successfully")


## Create a styled toolbar button for a plugin.
## Plugin buttons live in the menu-bar row (right-aligned PluginStrip).
## If the strip gets too crowded, an overflow "⋯" menu collects extras.
func _create_toolbar_button(plugin_id: String, plugin_instance) -> void:
	if not is_instance_valid(_toolbar_row):
		return

	# Add gear settings button once (leftmost in the strip)
	if not _plugin_separator_added:
		_plugin_separator_added = true

		_gear_btn = Button.new()
		_gear_btn.name = "PluginSettingsBtn"
		_gear_btn.text = "⚙"
		_gear_btn.tooltip_text = "Plugin Settings — enable/disable or install plugins"
		_gear_btn.flat = true
		_gear_btn.add_theme_font_size_override("font_size", 12)
		_gear_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		_gear_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		_gear_btn.pressed.connect(_show_settings_popup)
		_toolbar_row.add_child(_gear_btn)

		# Overflow "⋯" menu button (hidden until needed)
		_overflow_btn = MenuButton.new()
		_overflow_btn.name = "PluginOverflowBtn"
		_overflow_btn.text = "⋯"
		_overflow_btn.tooltip_text = "More plugins..."
		_overflow_btn.flat = true
		_overflow_btn.add_theme_font_size_override("font_size", 12)
		_overflow_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_overflow_btn.visible = false
		_toolbar_row.add_child(_overflow_btn)

	var btn = Button.new()
	btn.name = "VGPluginBtn_" + plugin_id
	btn.text = plugin_instance.get_toolbar_icon() + " " + plugin_instance.get_plugin_name()
	btn.tooltip_text = plugin_instance.get_toolbar_tooltip()
	btn.flat = false
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))

	var base_color: Color = plugin_instance.get_toolbar_color()
	var style = StyleBoxFlat.new()
	style.bg_color = base_color.darkened(0.1)
	style.set_corner_radius_all(10)
	style.border_color = base_color.lightened(0.35)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = base_color.lightened(0.1)
	hover_style.border_color = Color(1.0, 1.0, 1.0, 0.6)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = base_color.darkened(0.25)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Bind the button press to activate this plugin
	btn.pressed.connect(_on_plugin_button_pressed.bind(plugin_id))

	_toolbar_row.add_child(btn)
	_toolbar_buttons[plugin_id] = btn
	_plugin_order.append(plugin_id)

	# Check overflow — hide excess buttons and populate ⋯ menu
	_update_overflow()


## Update overflow: show first N plugin buttons, hide rest into ⋯ dropdown.
func _update_overflow() -> void:
	if not is_instance_valid(_overflow_btn):
		return
	var total = _plugin_order.size()
	var need_overflow = total > MAX_VISIBLE_PLUGINS

	# Show/hide individual plugin buttons
	for i in range(total):
		var pid = _plugin_order[i]
		if _toolbar_buttons.has(pid) and is_instance_valid(_toolbar_buttons[pid]):
			_toolbar_buttons[pid].visible = (i < MAX_VISIBLE_PLUGINS)

	# Update overflow menu
	_overflow_btn.visible = need_overflow
	if need_overflow:
		var popup = _overflow_btn.get_popup()
		popup.clear()
		for i in range(MAX_VISIBLE_PLUGINS, total):
			var pid = _plugin_order[i]
			var meta = _plugin_meta.get(pid, {})
			var label = meta.get("name", pid)
			popup.add_item(label)
			var idx = popup.item_count - 1
			popup.set_item_metadata(idx, pid)
		if not popup.id_pressed.is_connected(_on_overflow_item_pressed):
			popup.id_pressed.connect(_on_overflow_item_pressed)


## Handle overflow menu item selection.
func _on_overflow_item_pressed(idx: int) -> void:
	var popup = _overflow_btn.get_popup()
	var pid = popup.get_item_metadata(idx)
	if pid:
		_on_plugin_button_pressed(pid)


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


# ─── Plugin Settings ─────────────────────────────────────────

## Show the plugin settings popup with enable/disable toggles + install option.
func _show_settings_popup() -> void:
	# Clean up previous popup
	if is_instance_valid(_settings_popup):
		_settings_popup.queue_free()
		_settings_popup = null

	_settings_popup = Window.new()
	_settings_popup.title = "Plugin Settings"
	_settings_popup.size = Vector2i(560, 420)
	_settings_popup.unresizable = false
	_settings_popup.transient = true
	_settings_popup.exclusive = true

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_popup.add_child(panel)

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	var outer_margin = MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 12)
	outer_margin.add_theme_constant_override("margin_right", 12)
	outer_margin.add_theme_constant_override("margin_top", 12)
	outer_margin.add_theme_constant_override("margin_bottom", 12)
	outer_margin.add_child(outer)
	panel.add_child(outer_margin)

	# Tabs: "Installed Plugins" + "Default Editors". The Default Editors
	# tab lets the user pick a preferred provider for each capability the
	# registry knows about (sprite editing, scene editing, etc.).
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(tabs)

	# ─── Tab 1: Installed Plugins ───
	var plugins_root = VBoxContainer.new()
	plugins_root.name = "Installed Plugins"
	plugins_root.add_theme_constant_override("separation", 6)
	tabs.add_child(plugins_root)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	plugins_root.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(list_vbox)

	# Build rows from all discovered plugin metadata (loaded + disabled)
	var sorted_ids = _plugin_meta.keys()
	sorted_ids.sort()
	for pid in sorted_ids:
		var meta = _plugin_meta[pid]
		var row = _build_plugin_settings_row(pid, meta)
		list_vbox.add_child(row)

	if sorted_ids.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No plugins installed."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		list_vbox.add_child(empty_lbl)

	# ─── Tab 2: Default Editors ───
	var defaults_root = _build_default_editors_tab()
	defaults_root.name = "Default Editors"
	tabs.add_child(defaults_root)

	# Bottom buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_END

	var install_btn = Button.new()
	install_btn.text = "📁 Install Plugin..."
	install_btn.tooltip_text = "Browse filesystem to install a plugin folder into VisualGasic"
	install_btn.pressed.connect(_on_install_plugin_pressed)
	btn_row.add_child(install_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): _settings_popup.hide())
	btn_row.add_child(close_btn)

	outer.add_child(btn_row)

	# Show centered
	if is_instance_valid(_host_plugin):
		var editor = _host_plugin.get_editor_interface()
		var base = editor.get_base_control() if editor else null
		if is_instance_valid(base):
			base.add_child(_settings_popup)
		else:
			_toolbar_row.add_child(_settings_popup)
	else:
		_toolbar_row.add_child(_settings_popup)

	_settings_popup.popup_centered()
	_settings_popup.close_requested.connect(func(): _settings_popup.hide())


## Build the "Default Editors" tab — for every capability the registry
## knows about, lets the user pick which provider should be the default.
## Selections are stored in ProjectSettings under
## `vg/plugin_registry/defaults/<capability>` (handled by the registry).
func _build_default_editors_tab() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)

	var help = Label.new()
	help.text = "Choose which plugin handles each kind of asset by default.\nApplies to file-browser double-click and the command palette."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	root.add_child(help)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var grid = VBoxContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 4)
	scroll.add_child(grid)

	# Collect every capability that any registered provider claims, then
	# build a row per capability with an OptionButton listing that
	# capability's providers (sorted by priority desc, plugin_id asc).
	var registry = VGPluginRegistry.get_instance()
	var providers: Dictionary = registry.get_all_providers()
	var caps_set: Dictionary = {}
	for pid in providers.keys():
		var meta: Dictionary = providers[pid]
		for c in meta.get("provides", []):
			caps_set[c] = true
	var caps: Array = caps_set.keys()
	caps.sort()

	if caps.is_empty():
		var empty := Label.new()
		empty.text = "No capability-aware plugins registered yet."
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		grid.add_child(empty)
		return root

	for cap in caps:
		grid.add_child(_build_default_capability_row(cap, providers))
	return root


## Build a single row: <capability label>  [OptionButton with providers]
func _build_default_capability_row(capability: String, providers: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = _humanize_capability(capability)
	lbl.tooltip_text = capability
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(220, 0)
	row.add_child(lbl)

	# Find candidate providers for this capability, sorted by priority desc.
	var candidates: Array = []
	for pid in providers.keys():
		var meta: Dictionary = providers[pid]
		if capability in meta.get("provides", []):
			candidates.append({"id": pid, "meta": meta})
	candidates.sort_custom(func(a, b):
		var pa: int = int(a.meta.get("priority", 0))
		var pb: int = int(b.meta.get("priority", 0))
		if pa != pb:
			return pa > pb
		return a.id < b.id)

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item("(auto: highest priority)", 0)
	var registry = VGPluginRegistry.get_instance()
	var current_default: String = registry.get_default_for(capability)
	var selected_idx := 0
	for i in range(candidates.size()):
		var cand = candidates[i]
		var meta: Dictionary = cand.meta
		var nice: String = "%s  [priority %s]" % [
			str(meta.get("name", cand.id)), str(meta.get("priority", 0))
		]
		if not meta.get("enabled", true):
			nice += " (disabled)"
		opt.add_item(nice, i + 1)
		if cand.id == current_default:
			selected_idx = i + 1
	opt.select(selected_idx)
	opt.item_selected.connect(func(idx: int):
		if idx == 0:
			registry.set_default_for(capability, "")  # "" clears
		else:
			registry.set_default_for(capability, candidates[idx - 1].id))
	row.add_child(opt)
	return row


## Human-readable label for a capability id (e.g. "asset_editor.scene.2d" → "2D Scene").
func _humanize_capability(cap: String) -> String:
	var parts: Array = cap.split(".")
	if parts.is_empty():
		return cap
	var ns: String = parts[0]
	var rest: String = ".".join(parts.slice(1)) if parts.size() > 1 else ""
	var pretty_rest: String = rest.replace("_", " ").replace(".", " / ").capitalize()
	match ns:
		"asset_editor":
			return "Edit %s" % pretty_rest
		"asset_generator":
			return "Generate %s" % pretty_rest
		"game_builder":
			return "Build %s" % pretty_rest
		"panel":
			return "Panel: %s" % pretty_rest
		"command":
			return "Command: %s" % pretty_rest
		_:
			return cap


## Build a single plugin row for the settings list.
func _build_plugin_settings_row(plugin_id: String, meta: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Enabled toggle
	var toggle = CheckButton.new()
	toggle.button_pressed = meta.get("enabled", true)
	toggle.tooltip_text = "Enable or disable this plugin (applied immediately)"
	toggle.toggled.connect(_on_plugin_toggle.bind(plugin_id))
	row.add_child(toggle)

	# Info column
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl = Label.new()
	name_lbl.text = meta.get("name", plugin_id)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	info.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = meta.get("description", "No description")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(desc_lbl)

	row.add_child(info)

	# Status indicator
	var is_loaded = _plugins.has(plugin_id)
	var status = Label.new()
	status.text = "● Active" if is_loaded else ("○ Disabled" if not meta.get("enabled", true) else "○ Idle")
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if is_loaded else Color(0.5, 0.5, 0.5))
	row.add_child(status)

	return row


## Toggle a plugin's enabled state in its plugin.cfg (or in ProjectSettings
## for built-in pseudo-plugins like the Form Designer).
func _on_plugin_toggle(enabled: bool, plugin_id: String) -> void:
	var meta: Dictionary = _plugin_meta.get(plugin_id, {})

	# Built-in entries live in ProjectSettings, not in a plugin.cfg. Apply
	# the change immediately so the strip button appears/disappears without
	# requiring an editor restart — users toggling UI elements expect
	# instant feedback.
	if meta.get("_builtin", false):
		if plugin_id == BUILTIN_FORM_DESIGNER_ID:
			ProjectSettings.set_setting(BUILTIN_FORM_DESIGNER_SETTING, enabled)
			ProjectSettings.save()
			meta["enabled"] = enabled
			if enabled:
				_add_form_designer_strip_button()
			else:
				var existing = _toolbar_row.find_child("VGBuiltinBtn_FormDesigner", false, false) if is_instance_valid(_toolbar_row) else null
				if is_instance_valid(existing):
					existing.queue_free()
			print("VisualGasic: Built-in 'Form Designer' ", "enabled" if enabled else "disabled")
		return

	var cfg_path = PLUGINS_DIR + plugin_id + "/plugin.cfg"
	var cfg = ConfigFile.new()
	var err = cfg.load(cfg_path)
	if err != OK:
		push_warning("VisualGasic: Could not load plugin config to toggle: " + cfg_path)
		return
	cfg.set_value("plugin", "enabled", enabled)
	cfg.save(cfg_path)

	# Update local meta
	if _plugin_meta.has(plugin_id):
		_plugin_meta[plugin_id]["enabled"] = enabled

	# Live load/unload — no editor restart required.
	if enabled:
		# Load + activate the plugin so users see it immediately.
		if not _plugins.has(plugin_id):
			_load_plugin(plugin_id, cfg_path)
		if _plugins.has(plugin_id):
			activate_plugin(plugin_id)
	else:
		# If we just disabled the active plugin, switch back to the
		# code editor so the user isn't left staring at a hidden view.
		var was_active := (_active_plugin_id == plugin_id)
		_unload_plugin(plugin_id)
		if was_active and is_instance_valid(_host_plugin) and _host_plugin.has_method("_show_code_view"):
			_host_plugin._show_code_view()

	# Refresh the settings popup so the row's status indicator updates.
	if is_instance_valid(_settings_popup) and _settings_popup.visible:
		_show_settings_popup()

	print("VisualGasic: Plugin '", plugin_id, "' ", "enabled" if enabled else "disabled")


## Tear down a single loaded plugin: deactivate, free its view, button,
## and remove it from internal tracking. The plugin.cfg "enabled" field
## is the caller's responsibility (see _on_plugin_toggle).
func _unload_plugin(plugin_id: String) -> void:
	if not _plugins.has(plugin_id):
		return

	# Deactivate if currently active.
	if _active_plugin_id == plugin_id:
		_plugins[plugin_id].deactivate()
		_active_plugin_id = ""

	# Tear down the plugin's UI/state.
	_plugins[plugin_id].cleanup()
	_plugins.erase(plugin_id)

	# Remove the toolbar button.
	if _toolbar_buttons.has(plugin_id):
		var btn = _toolbar_buttons[plugin_id]
		if is_instance_valid(btn):
			btn.queue_free()
		_toolbar_buttons.erase(plugin_id)

	# Drop from the order list and refresh overflow visibility.
	_plugin_order.erase(plugin_id)
	_update_overflow()

	# Unregister any autoloads this plugin declared.  Newly removed
	# autoloads only take effect after a VisualGasic restart.
	var meta: Dictionary = _plugin_meta.get(plugin_id, {})
	var autoloads: Dictionary = meta.get("autoloads", {})
	if not autoloads.is_empty():
		var unhid := _hide_autoload_paths(plugin_id, autoloads)
		if _unregister_plugin_autoloads(plugin_id, autoloads) or unhid:
			ProjectSettings.save()
			push_warning("VisualGasic: Plugin '%s' removed autoloads. Restart VisualGasic for the change to take full effect." % plugin_id)


## Open a file dialog to install a plugin folder.
func _on_install_plugin_pressed() -> void:
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.title = "Select Plugin Folder (must contain plugin.cfg)"
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.size = Vector2i(600, 400)

	fd.dir_selected.connect(_on_install_dir_selected.bind(fd))
	fd.canceled.connect(func(): fd.queue_free())

	if is_instance_valid(_settings_popup):
		_settings_popup.add_child(fd)
	else:
		_toolbar_row.add_child(fd)
	fd.popup_centered()


## Copy a selected plugin folder into the plugins directory.
func _on_install_dir_selected(dir_path: String, dialog: FileDialog) -> void:
	dialog.queue_free()

	# Verify plugin.cfg exists in selected folder
	var src_cfg = dir_path + "/plugin.cfg"
	if not FileAccess.file_exists(src_cfg):
		push_warning("VisualGasic: Selected folder has no plugin.cfg — not a valid VG plugin")
		print("VisualGasic: Install failed — no plugin.cfg in: ", dir_path)
		return

	# Extract folder name for plugin_id
	var folder_name = dir_path.get_file()
	var dest_dir = PLUGINS_DIR + folder_name + "/"

	# Copy all files from source to dest
	var src_da = DirAccess.open(dir_path)
	if not src_da:
		push_warning("VisualGasic: Could not open source plugin directory: " + dir_path)
		return

	# Ensure destination exists
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))

	var copied = 0
	src_da.list_dir_begin()
	var fname = src_da.get_next()
	while fname != "":
		if not src_da.current_is_dir():
			var src_file = dir_path + "/" + fname
			var dst_file = ProjectSettings.globalize_path(dest_dir + fname)
			var content = FileAccess.get_file_as_bytes(src_file)
			if content.size() > 0:
				var out = FileAccess.open(dest_dir + fname, FileAccess.WRITE)
				if out:
					out.store_buffer(content)
					out.close()
					copied += 1
		fname = src_da.get_next()
	src_da.list_dir_end()

	print("VisualGasic: Installed plugin '", folder_name, "' (", copied, " files copied). Restart to load.")

	# Refresh settings popup to show new plugin
	if is_instance_valid(_settings_popup):
		_settings_popup.hide()
	_show_settings_popup()


# ─── Cleanup ────────────────────────────────────────────────

## Clean up all plugins.
func cleanup() -> void:
	if is_instance_valid(_settings_popup):
		_settings_popup.queue_free()
		_settings_popup = null
	for plugin_id in _plugins:
		_plugins[plugin_id].cleanup()
	_plugins.clear()
	_plugin_meta.clear()
	for btn_id in _toolbar_buttons:
		if is_instance_valid(_toolbar_buttons[btn_id]):
			_toolbar_buttons[btn_id].queue_free()
	_toolbar_buttons.clear()
	_plugin_order.clear()
	_active_plugin_id = ""
	_plugin_separator_added = false



# ─── Plugin autoload management ─────────────────────────────────
#
# Plugins can declare autoloads in their plugin.cfg, e.g.:
#   [autoloads]
#   Controller="bosca/globals/Controller.gd"
#
# The manager registers each entry as ProjectSettings("autoload/<Name>" =
# "*res://addons/visual_gasic/plugins/<plugin_id>/<relative_path>").
# Because Godot only wires autoloads into the global identifier scope at
# engine startup, newly-added autoloads require a VisualGasic restart
# before the plugin's scripts will parse correctly.

## Read the [autoloads] ConfigFile section into a Dictionary mapping
## autoload name -> relative path (relative to the plugin folder).
func _read_autoloads_section(cfg: ConfigFile, _plugin_id: String) -> Dictionary:
	var out: Dictionary = {}
	if not cfg.has_section("autoloads"):
		return out
	for key in cfg.get_section_keys("autoloads"):
		var rel_path := str(cfg.get_value("autoloads", key, ""))
		if rel_path.is_empty():
			continue
		out[str(key)] = rel_path
	return out


## Register the plugin's declared autoloads in ProjectSettings.
## Returns true if any entries were newly added (caller should save +
## warn about restart).
func _register_plugin_autoloads(plugin_id: String, autoloads: Dictionary) -> bool:
	var any_new := false
	for autoload_name in autoloads:
		var rel_path: String = autoloads[autoload_name]
		var abs_path := "*res://addons/visual_gasic/plugins/%s/%s" % [plugin_id, rel_path]
		var setting_key := "autoload/%s" % autoload_name
		var existing = ProjectSettings.get_setting(setting_key, "")
		if str(existing) == abs_path:
			continue
		ProjectSettings.set_setting(setting_key, abs_path)
		any_new = true
	return any_new


## Remove autoloads previously registered for a plugin. Returns true if
## any were removed (caller should save + warn about restart).
func _unregister_plugin_autoloads(plugin_id: String, autoloads: Dictionary) -> bool:
	var any_removed := false
	for autoload_name in autoloads:
		var setting_key := "autoload/%s" % autoload_name
		if ProjectSettings.has_setting(setting_key):
			# Only remove if it matches *our* plugin's path - don't clobber
			# autoloads from a different plugin or the host project.
			var expected := "*res://addons/visual_gasic/plugins/%s/%s" % [plugin_id, autoloads[autoload_name]]
			var current := str(ProjectSettings.get_setting(setting_key, ""))
			if current == expected:
				ProjectSettings.set_setting(setting_key, null)
				any_removed = true
	return any_removed


# ─── Plugin folder visibility (.gdignore management) ───────────
#
# When a plugin is disabled (or installed but never enabled), the GDScript
# parser will still index any *.gd files in its directory and produce
# noisy "identifier not declared" errors on scripts that reference the
# plugin's not-yet-registered autoloads.  To suppress this, we keep a
# `.gdignore` file in each subfolder containing autoload-dependent
# scripts.  Enabling the plugin removes the marker; disabling restores
# it.  An empty .gdignore is sufficient — Godot skips the entire
# directory tree below it.

## For each autoload's containing directory, remove a .gdignore file if
## present so Godot can scan the scripts.  Returns true if any file was
## removed (caller saves project settings + warns about restart).
func _unhide_autoload_paths(plugin_id: String, autoloads: Dictionary) -> bool:
	var removed_any := false
	var dirs := _autoload_root_dirs(plugin_id, autoloads)
	for dir_path_v in dirs:
		var dir_path: String = dir_path_v
		var marker: String = dir_path + "/.gdignore"
		if FileAccess.file_exists(marker):
			var abs_path := ProjectSettings.globalize_path(marker)
			var err := DirAccess.remove_absolute(abs_path)
			if err == OK:
				removed_any = true
			else:
				push_warning("VisualGasic: Failed to remove %s (err %d)" % [marker, err])
	return removed_any


## Recreate .gdignore markers in autoload directories so the plugin's
## sources don't produce parse errors after disable.  Returns true if a
## new marker was written.
func _hide_autoload_paths(plugin_id: String, autoloads: Dictionary) -> bool:
	var wrote_any := false
	var dirs := _autoload_root_dirs(plugin_id, autoloads)
	for dir_path_v in dirs:
		var dir_path: String = dir_path_v
		var marker: String = dir_path + "/.gdignore"
		if FileAccess.file_exists(marker):
			continue
		var f := FileAccess.open(marker, FileAccess.WRITE)
		if f:
			f.close()
			wrote_any = true
		else:
			push_warning("VisualGasic: Failed to create %s" % marker)
	return wrote_any


## Compute the set of top-level directories that contain autoload-dependent
## scripts.  We mark the topmost ancestor directory inside the plugin folder
## (e.g. for "bosca/globals/Controller.gd" -> "res://addons/.../vgmusic/bosca").
func _autoload_root_dirs(plugin_id: String, autoloads: Dictionary) -> Array:
	var plugin_root := PLUGINS_DIR + plugin_id + "/"
	var roots: Dictionary = {}
	for name in autoloads:
		var rel: String = autoloads[name]
		var first_slash := rel.find("/")
		if first_slash <= 0:
			continue
		var top := rel.substr(0, first_slash)
		roots[plugin_root + top] = true
	return roots.keys()
