@tool
## VGAssetBus — process-wide signal bus for asset lifecycle events.
##
## Any plugin (or core IDE code) that opens, modifies, saves, deletes, or
## renames a file/asset should announce it through this bus so other
## plugins can react without direct coupling. Examples:
##   * Sprite editor saves PNG → File browser refreshes thumbnail.
##   * AGCK level editor renames a tile asset → working_nodes graph
##     repaths references automatically.
##   * Hex editor mutates bytes → any open viewer reloads.
##
## Usage:
##   # From inside a plugin:
##   VGAssetBus.get_instance().emit_saved("res://gfx/hero.png", "sprite_editor")
##   VGAssetBus.get_instance().asset_saved.connect(_on_any_asset_saved)
##
## Singleton lifetime: the first call to get_instance() creates the
## RefCounted bus; subsequent calls return the same instance. Because
## RefCounted is reference-counted, holding the static var is enough to
## keep it alive for the editor session. The host plugin is expected to
## drop its reference on cleanup; the bus dies when no listener holds it.
class_name VGAssetBus
extends RefCounted

# ─── Signals ────────────────────────────────────────────────

## Emitted when a plugin opens an asset for editing.
##   path: res:// path or absolute path of the asset
##   by_plugin_id: plugin folder name (e.g. "sprite_editor"); empty for core
signal asset_opened(path: String, by_plugin_id: String)

## Emitted when an asset's in-memory representation has been modified
## but not yet persisted. UI can show a "dirty" marker.
signal asset_modified(path: String, by_plugin_id: String)

## Emitted right after a successful write to disk. File watchers /
## thumbnail cachers / dependent editors should refresh on this.
signal asset_saved(path: String, by_plugin_id: String)

## Emitted when an asset is deleted from the project.
signal asset_deleted(path: String, by_plugin_id: String)

## Emitted when an asset is renamed/moved.
##   old_path → new_path. Emitted *after* the move so listeners see the
##   final state. Listeners that hold path references should remap.
signal asset_renamed(old_path: String, new_path: String, by_plugin_id: String)

## Generic "something happened, you should reload" emitted when none of
## the more specific signals fit. Avoid using if a specific signal exists.
signal asset_invalidated(path: String, by_plugin_id: String)


# ─── Singleton plumbing ─────────────────────────────────────

static var _instance: VGAssetBus = null

## Get (or lazily create) the process-wide bus.
static func get_instance() -> VGAssetBus:
	if _instance == null:
		_instance = VGAssetBus.new()
	return _instance


## Drop the bus (testing only — invalidates all existing connections).
static func reset_for_testing() -> void:
	_instance = null


# ─── Convenience emitters ───────────────────────────────────

## Helper so callers don't have to remember signal argument order.
func emit_opened(path: String, by_plugin_id: String = "") -> void:
	asset_opened.emit(path, by_plugin_id)


func emit_modified(path: String, by_plugin_id: String = "") -> void:
	asset_modified.emit(path, by_plugin_id)


func emit_saved(path: String, by_plugin_id: String = "") -> void:
	asset_saved.emit(path, by_plugin_id)


func emit_deleted(path: String, by_plugin_id: String = "") -> void:
	asset_deleted.emit(path, by_plugin_id)


func emit_renamed(old_path: String, new_path: String, by_plugin_id: String = "") -> void:
	asset_renamed.emit(old_path, new_path, by_plugin_id)


func emit_invalidated(path: String, by_plugin_id: String = "") -> void:
	asset_invalidated.emit(path, by_plugin_id)
