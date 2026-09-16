@tool
extends RefCounted
## VisualGasic Recent Projects Manager
##
## Tracks recently opened .vbp and .vg projects:
## - Stores last 10 projects
## - Pin favorite projects
## - Persistence via EditorSettings
## - Clear history option

class_name VGRecentProjects

# =============================================================================
# CONSTANTS
# =============================================================================

const MAX_RECENT_PROJECTS = 10
const SETTINGS_KEY = "visual_gasic/recent_projects"
const PINNED_KEY = "visual_gasic/pinned_projects"

# =============================================================================
# SIGNALS
# =============================================================================

signal projects_changed()

# =============================================================================
# STORAGE
# =============================================================================

var _recent_projects: Array[String] = []
var _pinned_projects: Array[String] = []
var _editor_settings: EditorSettings = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	if Engine.is_editor_hint():
		_editor_settings = EditorInterface.get_editor_settings()
		_load_projects()

func _load_projects() -> void:
	if not _editor_settings:
		return
	
	# Load recent projects
	if _editor_settings.has_setting(SETTINGS_KEY):
		var saved = _editor_settings.get_setting(SETTINGS_KEY)
		if saved is Array:
			for path in saved:
				if path is String and not path.is_empty():
					_recent_projects.append(path)
	
	# Load pinned projects
	if _editor_settings.has_setting(PINNED_KEY):
		var saved = _editor_settings.get_setting(PINNED_KEY)
		if saved is Array:
			for path in saved:
				if path is String and not path.is_empty():
					_pinned_projects.append(path)

func _save_projects() -> void:
	if not _editor_settings:
		return
	
	_editor_settings.set_setting(SETTINGS_KEY, _recent_projects)
	_editor_settings.set_setting(PINNED_KEY, _pinned_projects)

# =============================================================================
# PROJECT MANAGEMENT
# =============================================================================

## Adds a project to recent list
func add_project(path: String) -> void:
	if path.is_empty():
		return
	
	# Remove if already exists (will be moved to top)
	var idx = _recent_projects.find(path)
	if idx >= 0:
		_recent_projects.remove_at(idx)
	
	# Add to front
	_recent_projects.insert(0, path)
	
	# Trim to max size
	while _recent_projects.size() > MAX_RECENT_PROJECTS:
		_recent_projects.pop_back()
	
	_save_projects()
	projects_changed.emit()

## Removes a project from recent list
func remove_project(path: String) -> void:
	var idx = _recent_projects.find(path)
	if idx >= 0:
		_recent_projects.remove_at(idx)
		_save_projects()
		projects_changed.emit()

## Clears all recent projects (keeps pinned)
func clear_recent() -> void:
	_recent_projects.clear()
	_save_projects()
	projects_changed.emit()

## Clears everything including pinned
func clear_all() -> void:
	_recent_projects.clear()
	_pinned_projects.clear()
	_save_projects()
	projects_changed.emit()

## Gets all recent projects (pinned first, then recent)
func get_all_projects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	# Pinned projects first
	for path in _pinned_projects:
		result.append({
			"path": path,
			"name": path.get_file(),
			"pinned": true,
			"exists": FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
		})
	
	# Recent projects (exclude pinned)
	for path in _recent_projects:
		if path not in _pinned_projects:
			result.append({
				"path": path,
				"name": path.get_file(),
				"pinned": false,
				"exists": FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
			})
	
	return result

## Gets just the recent projects list
func get_recent_projects() -> Array[String]:
	return _recent_projects.duplicate()

## Gets just the pinned projects list
func get_pinned_projects() -> Array[String]:
	return _pinned_projects.duplicate()

# =============================================================================
# PIN MANAGEMENT
# =============================================================================

## Pins a project (keeps it at top permanently)
func pin_project(path: String) -> void:
	if path.is_empty() or path in _pinned_projects:
		return
	
	_pinned_projects.append(path)
	_save_projects()
	projects_changed.emit()

## Unpins a project
func unpin_project(path: String) -> void:
	var idx = _pinned_projects.find(path)
	if idx >= 0:
		_pinned_projects.remove_at(idx)
		_save_projects()
		projects_changed.emit()

## Checks if a project is pinned
func is_pinned(path: String) -> bool:
	return path in _pinned_projects

## Toggles pin status
func toggle_pin(path: String) -> void:
	if is_pinned(path):
		unpin_project(path)
	else:
		pin_project(path)

# =============================================================================
# UTILITY
# =============================================================================

## Gets the count of all projects
func get_project_count() -> int:
	var unique: Array[String] = _pinned_projects.duplicate()
	for path in _recent_projects:
		if path not in unique:
			unique.append(path)
	return unique.size()

## Checks if a project exists in the list
func has_project(path: String) -> bool:
	return path in _recent_projects or path in _pinned_projects
