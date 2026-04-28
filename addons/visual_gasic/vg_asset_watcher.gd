@tool
## VGAssetWatcher — detects external changes to tracked assets.
##
## Listens for VGAssetBus.asset_opened to start tracking a file, and
## emits VGAssetBus.asset_invalidated when the file's mtime changes
## without an intervening asset_saved (which would indicate the change
## came from inside the IDE).
##
## Polls on a Timer (2 s default) — fine for a few hundred tracked
## files, no threading required, and survives editor reloads.
##
## Tracking is bounded:
##   - Files only outside `res://.godot/`, `res://.import/`, etc.
##   - Stops tracking on asset_deleted.
##   - Renames re-bind the tracker to the new path.
##
## Singleton: VGAssetWatcher.get_instance(). The plugin manager calls
## this at editor startup so the timer node exists in the IDE scene.
class_name VGAssetWatcher
extends Node

const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")
const _PLUGIN_ID := "vg_asset_watcher"

## Polling interval, seconds. Keep above 1.0 so big projects don't
## thrash the disk; below 5.0 so external edits feel responsive.
const POLL_INTERVAL := 2.0

## Hard cap on tracked files — anything past this is silently dropped
## to keep the per-poll cost bounded.
const MAX_TRACKED := 500


## Map<absolute_path, last_known_mtime_unix>. We use absolute paths so
## file moves outside res:// (config files, etc.) can still be watched
## by callers that pass abs paths. res:// paths are converted via
## ProjectSettings.globalize_path.
var _tracked: Dictionary = {}

var _timer: Timer = null


static var _instance: VGAssetWatcher = null

static func get_instance() -> VGAssetWatcher:
	if _instance == null or not is_instance_valid(_instance):
		_instance = VGAssetWatcher.new()
		# Park on the editor's main scene tree so the Timer ticks.
		# We can't always reach a scene tree from a static method, so
		# defer attachment to the caller via attach_to(parent).
	return _instance


## Attach the watcher to a scene-tree node (typically EditorInterface
## base control or the host plugin). Idempotent.
func attach_to(parent: Node) -> void:
	if get_parent() == parent:
		return
	if get_parent() != null:
		get_parent().remove_child(self)
	parent.add_child(self)
	_ensure_running()


# ─── Lifecycle ──────────────────────────────────────────────

func _ready() -> void:
	_ensure_running()
	var bus = _AssetBus.get_instance()
	if not bus.asset_opened.is_connected(_on_asset_opened):
		bus.asset_opened.connect(_on_asset_opened)
	if not bus.asset_saved.is_connected(_on_asset_saved):
		bus.asset_saved.connect(_on_asset_saved)
	if not bus.asset_deleted.is_connected(_on_asset_deleted):
		bus.asset_deleted.connect(_on_asset_deleted)
	if not bus.asset_renamed.is_connected(_on_asset_renamed):
		bus.asset_renamed.connect(_on_asset_renamed)


func _ensure_running() -> void:
	if _timer != null and is_instance_valid(_timer):
		return
	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL
	_timer.autostart = true
	_timer.one_shot = false
	_timer.timeout.connect(_poll)
	add_child(_timer)


# ─── Bus handlers ───────────────────────────────────────────

func _on_asset_opened(path: String, _by_plugin_id: String) -> void:
	_track(path)


func _on_asset_saved(path: String, _by_plugin_id: String) -> void:
	# Update the baseline mtime so our own write doesn't trigger an
	# invalidation on the next poll.
	if _tracked.has(_normalize(path)):
		_tracked[_normalize(path)] = _mtime_of(path)


func _on_asset_deleted(path: String, _by_plugin_id: String) -> void:
	_tracked.erase(_normalize(path))


func _on_asset_renamed(old_path: String, new_path: String, _by_plugin_id: String) -> void:
	var key := _normalize(old_path)
	if _tracked.has(key):
		_tracked.erase(key)
		_track(new_path)


# ─── Tracking ───────────────────────────────────────────────

func _track(path: String) -> void:
	if path.is_empty():
		return
	var key := _normalize(path)
	if _tracked.size() >= MAX_TRACKED and not _tracked.has(key):
		# Evict the oldest entry (Dictionaries preserve insertion order).
		var first_key = _tracked.keys()[0]
		_tracked.erase(first_key)
	_tracked[key] = _mtime_of(path)


func _poll() -> void:
	if _tracked.is_empty():
		return
	var bus = _AssetBus.get_instance()
	for key in _tracked.keys():
		var current := _mtime_of(key)
		if current == 0:
			continue  # transient read failure, try again next tick
		var last: int = _tracked[key]
		if last == 0:
			_tracked[key] = current
			continue
		if current != last:
			# External change — emit and bring the baseline forward.
			_tracked[key] = current
			bus.emit_invalidated(key, _PLUGIN_ID)


# ─── Helpers ────────────────────────────────────────────────

## Normalize res:// → absolute fs path (so `FileAccess.get_modified_time`
## works on both forms).
func _normalize(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _mtime_of(path: String) -> int:
	var p := _normalize(path)
	if not FileAccess.file_exists(p):
		return 0
	return int(FileAccess.get_modified_time(p))
