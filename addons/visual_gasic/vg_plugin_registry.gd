@tool
## VGPluginRegistry — capability/extension routing for VG plugins.
##
## Each plugin's plugin.cfg may declare what capabilities it provides
## and which file extensions it handles, e.g.:
##
##   [plugin]
##   name="Sprite Editor"
##   script="sprite_editor_plugin.gd"
##   enabled=true
##
##   [capabilities]
##   provides = ["asset_editor.sprite", "asset_editor.sprite.advanced"]
##   handles_extensions = ["png", "ase", "vgsprite"]
##   priority = 50            # higher wins ties when multiple plugins
##                            # claim the same default
##
## VGPluginManager calls register_provider() once per discovered plugin
## (whether or not the plugin actually loads — disabled plugins still
## appear in the registry as inactive entries so settings UIs can list
## them). Other plugins / core IDE code then ask:
##
##   * find_providers("asset_editor.sprite") → [plugin_id, ...]
##   * find_provider_for_path("res://gfx/x.png") → plugin_id
##   * get_default_for("asset_editor.sprite") → plugin_id
##   * set_default_for("asset_editor.sprite", "sprite_editor")
##   * open_asset("res://gfx/x.png") → bool
##
## Default-provider preferences are persisted in ProjectSettings under
##   vg/plugin_registry/defaults/<capability>
## so users can pick "I always want the AGCK sprite editor for .png"
## once and have it stick across sessions.
class_name VGPluginRegistry
extends RefCounted

# Sibling singletons referenced via preload so this script parses even
# when Godot's global class_name index hasn't been built yet (e.g. when
# running --check-only on a single file outside an open editor).
const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")
const _ContextBroker := preload("res://addons/visual_gasic/vg_context_broker.gd")

const DEFAULTS_SETTING_PREFIX := "vg/plugin_registry/defaults/"

## Emitted whenever a provider is added, removed, or has its enabled
## flag toggled. UIs (command palette, settings dialog) listen to this
## to refresh their lists without polling.
signal providers_changed


# ─── State ──────────────────────────────────────────────────

## plugin_id → {
##   "name": String,
##   "provides": Array[String],
##   "handles_extensions": Array[String],
##   "priority": int,
##   "enabled": bool,
##   "instance": VGPluginBase or null,
## }
var _providers: Dictionary = {}

## capability → user-chosen default plugin_id (cached from ProjectSettings).
var _defaults_cache: Dictionary = {}


# ─── Singleton plumbing ─────────────────────────────────────

static var _instance: VGPluginRegistry = null

static func get_instance() -> VGPluginRegistry:
	if _instance == null:
		_instance = VGPluginRegistry.new()
	return _instance


static func reset_for_testing() -> void:
	_instance = null


# ─── Registration (called by VGPluginManager) ───────────────

## Register a plugin's capabilities. Call once per plugin discovered,
## even if it's disabled (so the UI can list and toggle it).
##   meta: dict with keys "name", "provides", "handles_extensions",
##         "priority", "enabled". Missing keys default to safe values.
##   instance: the live VGPluginBase (or null if not loaded yet).
func register_provider(plugin_id: String, meta: Dictionary, instance = null) -> void:
	var provides: Array = meta.get("provides", [])
	var exts: Array = meta.get("handles_extensions", [])
	# Normalize extensions to lowercase, no leading dot.
	var norm_exts: Array = []
	for e in exts:
		var s := String(e).to_lower()
		if s.begins_with("."):
			s = s.substr(1)
		if not s.is_empty():
			norm_exts.append(s)

	_providers[plugin_id] = {
		"name": meta.get("name", plugin_id),
		"provides": provides.duplicate(),
		"handles_extensions": norm_exts,
		"priority": int(meta.get("priority", 0)),
		"enabled": bool(meta.get("enabled", true)),
		"instance": instance,
	}
	providers_changed.emit()


## Update an existing provider's live instance (called once the plugin
## has actually been loaded after register_provider was called with null).
func attach_instance(plugin_id: String, instance) -> void:
	if not _providers.has(plugin_id):
		return
	_providers[plugin_id]["instance"] = instance
	providers_changed.emit()


func unregister_provider(plugin_id: String) -> void:
	if _providers.erase(plugin_id):
		providers_changed.emit()


## Toggle a plugin's enabled state in the registry. Does NOT load/unload
## the plugin itself — VGPluginManager handles that. The flag here is
## used so find_providers() skips disabled entries.
func set_enabled(plugin_id: String, enabled: bool) -> void:
	if not _providers.has(plugin_id):
		return
	if _providers[plugin_id]["enabled"] == enabled:
		return
	_providers[plugin_id]["enabled"] = enabled
	providers_changed.emit()


# ─── Queries ────────────────────────────────────────────────

## All plugin ids that advertise the given capability and are enabled,
## sorted by descending priority (then alphabetical for stable order).
func find_providers(capability: String) -> Array:
	var hits: Array = []
	for pid in _providers:
		var p: Dictionary = _providers[pid]
		if not p["enabled"]:
			continue
		if capability in p["provides"]:
			hits.append(pid)
	hits.sort_custom(func(a, b):
		var pa: int = _providers[a]["priority"]
		var pb: int = _providers[b]["priority"]
		if pa != pb:
			return pa > pb
		return String(a) < String(b)
	)
	return hits


## All enabled plugin ids that handle the given file path's extension.
func find_providers_for_path(path: String) -> Array:
	var ext := path.get_extension().to_lower()
	if ext.is_empty():
		return []
	var hits: Array = []
	for pid in _providers:
		var p: Dictionary = _providers[pid]
		if not p["enabled"]:
			continue
		if ext in p["handles_extensions"]:
			hits.append(pid)
	hits.sort_custom(func(a, b):
		var pa: int = _providers[a]["priority"]
		var pb: int = _providers[b]["priority"]
		if pa != pb:
			return pa > pb
		return String(a) < String(b)
	)
	return hits


## Resolve the single best provider for a capability, honoring the
## user's persisted default (if any) before falling back to priority.
## Returns "" if nothing claims it.
func get_default_for(capability: String) -> String:
	var providers := find_providers(capability)
	if providers.is_empty():
		return ""
	var pref := _read_default(capability)
	if pref != "" and pref in providers:
		return pref
	return providers[0]


## Persist the user's preferred default for a capability.
func set_default_for(capability: String, plugin_id: String) -> void:
	_defaults_cache[capability] = plugin_id
	var key := DEFAULTS_SETTING_PREFIX + capability
	ProjectSettings.set_setting(key, plugin_id)
	# Tell ProjectSettings this is a savable user setting (not engine
	# internal); without this the value is in-memory only.
	if not ProjectSettings.has_setting(key):
		ProjectSettings.set_initial_value(key, "")
	ProjectSettings.save()
	providers_changed.emit()


## Best provider for a path: prefers an extension-specific default over
## the generic capability default. Used by file-browser double-click.
func get_default_for_path(path: String) -> String:
	# Extension-specific default first.
	var ext := path.get_extension().to_lower()
	if ext != "":
		var ext_key := "ext." + ext
		var pref := _read_default(ext_key)
		var ext_providers := find_providers_for_path(path)
		if pref != "" and pref in ext_providers:
			return pref
		if not ext_providers.is_empty():
			return ext_providers[0]
	return ""


## Snapshot of all providers (for settings UI). Returns a copy so
## callers can't accidentally mutate registry state.
func get_all_providers() -> Dictionary:
	return _providers.duplicate(true)


## Lookup a single provider's metadata, or {} if unknown.
func get_provider(plugin_id: String) -> Dictionary:
	return _providers.get(plugin_id, {}).duplicate(true) if _providers.has(plugin_id) else {}


# ─── Action ─────────────────────────────────────────────────

## Open an asset using the best available provider for its extension.
## Returns true if a provider was found and accepted the open request.
##
## The provider's plugin instance must implement either:
##   * open_asset(path: String) -> bool   (preferred)
##   * activate() and we just switch to it (fallback — caller still
##     has to navigate to the file inside the plugin)
##
## Emits VGAssetBus.asset_opened on success.
func open_asset(path: String) -> bool:
	var pid := get_default_for_path(path)
	if pid == "":
		push_warning("VGPluginRegistry: no provider handles '%s'" % path)
		return false
	var entry: Dictionary = _providers[pid]
	var inst = entry.get("instance")
	if inst == null:
		push_warning("VGPluginRegistry: provider '%s' for '%s' is registered but not loaded" % [pid, path])
		return false

	var accepted := false
	if inst.has_method("open_asset"):
		accepted = bool(inst.open_asset(path))
	else:
		# Fallback — just bring the plugin to the front. The user will
		# need to navigate to the asset inside it manually.
		if inst.has_method("activate"):
			inst.activate()
		accepted = true

	if accepted:
		_AssetBus.get_instance().emit_opened(path, pid)
		_ContextBroker.get_instance().set_current_asset(path, pid)
	return accepted


# ─── Internals ──────────────────────────────────────────────

func _read_default(capability: String) -> String:
	if _defaults_cache.has(capability):
		return _defaults_cache[capability]
	var key := DEFAULTS_SETTING_PREFIX + capability
	if ProjectSettings.has_setting(key):
		var v := String(ProjectSettings.get_setting(key, ""))
		_defaults_cache[capability] = v
		return v
	_defaults_cache[capability] = ""
	return ""
