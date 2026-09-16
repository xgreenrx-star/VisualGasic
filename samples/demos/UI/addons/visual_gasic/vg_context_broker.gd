@tool
## VGContextBroker — tracks "what is the user looking at right now?"
##
## Plugins frequently need to know:
##   * What asset/file is currently focused in the IDE?
##   * Which project (canonical or game_projects/<x>) is active?
##   * If the user has selected an object/control inside that asset
##     (e.g. a Form Designer control, a tile in AGCK, a node in the
##     working_nodes graph), what is its identifier?
##
## Rather than each plugin polling the host or storing its own copy,
## the broker centralizes that state and emits context_changed when it
## moves. Plugins should call set_*() when *they* drive a change (e.g.
## the file browser opens a new file) and read get_*() when they need
## to know the current state.
##
## Usage:
##   var ctx := VGContextBroker.get_instance()
##   ctx.set_current_asset("res://gfx/hero.png", "sprite_editor")
##   ctx.context_changed.connect(_on_ctx)
##   func _on_ctx(kind: String, value):
##       if kind == "asset": print("Now editing:", value)
class_name VGContextBroker
extends RefCounted

## Emitted when *any* tracked piece of context changes.
##   kind: one of "asset", "project", "object_id", "selection"
##   value: the new value (String for asset/project/object_id; Variant
##          for selection — usually an Array or Dictionary)
signal context_changed(kind: String, value)


# ─── State ──────────────────────────────────────────────────

var _current_asset: String = ""
var _current_project: String = ""
var _current_object_id: String = ""
var _current_selection: Variant = null
## Plugin id that last changed each piece of context (for attribution /
## avoiding feedback loops where a plugin reacts to its own change).
var _asset_setter: String = ""
var _project_setter: String = ""
var _object_setter: String = ""


# ─── Singleton plumbing ─────────────────────────────────────

static var _instance: VGContextBroker = null

static func get_instance() -> VGContextBroker:
	if _instance == null:
		_instance = VGContextBroker.new()
	return _instance


static func reset_for_testing() -> void:
	_instance = null


# ─── Setters ────────────────────────────────────────────────

func set_current_asset(path: String, by_plugin_id: String = "") -> void:
	if path == _current_asset:
		return
	_current_asset = path
	_asset_setter = by_plugin_id
	context_changed.emit("asset", path)


func set_current_project(project_path: String, by_plugin_id: String = "") -> void:
	if project_path == _current_project:
		return
	_current_project = project_path
	_project_setter = by_plugin_id
	context_changed.emit("project", project_path)


func set_current_object_id(object_id: String, by_plugin_id: String = "") -> void:
	if object_id == _current_object_id:
		return
	_current_object_id = object_id
	_object_setter = by_plugin_id
	context_changed.emit("object_id", object_id)


func set_selection(selection: Variant, by_plugin_id: String = "") -> void:
	# Selection is treated as always-changing (Arrays/Dicts may mutate
	# in place, so equality checks aren't reliable).
	_current_selection = selection
	context_changed.emit("selection", selection)
	# Note: by_plugin_id intentionally not stored — selection is too
	# transient to bother attributing.
	var _unused := by_plugin_id


# ─── Getters ────────────────────────────────────────────────

func get_current_asset() -> String:
	return _current_asset


func get_current_project() -> String:
	return _current_project


func get_current_object_id() -> String:
	return _current_object_id


func get_current_selection() -> Variant:
	return _current_selection


## Returns the plugin id that most recently set the asset (or empty).
func get_asset_setter() -> String:
	return _asset_setter
