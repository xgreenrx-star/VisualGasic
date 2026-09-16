@tool
extends PopupMenu
## VisualGasic Recent Projects Menu
##
## A popup menu showing recently opened projects:
## - Pinned projects at top with pin icon
## - Recent projects below
## - Clear history option
## - Tooltip with full path

signal project_selected(path: String)
signal pin_toggled(path: String)

var _recent_manager: VGRecentProjects

# Menu item IDs
const ID_SEPARATOR = -1
const ID_CLEAR_RECENT = 1000
const ID_CLEAR_ALL = 1001
const ID_PIN_BASE = 2000  # IDs 2000+ are for pin toggle

func _init() -> void:
	name = "RecentProjectsMenu"
	_recent_manager = VGRecentProjects.new()
	
	# Connect signals
	id_pressed.connect(_on_id_pressed)
	about_to_popup.connect(_on_about_to_popup)

func _on_about_to_popup() -> void:
	_rebuild_menu()

func _rebuild_menu() -> void:
	clear()
	
	var projects = _recent_manager.get_all_projects()
	
	if projects.is_empty():
		add_item("(No Recent Projects)", -1)
		set_item_disabled(0, true)
		return
	
	var idx = 0
	var has_pinned = false
	
	# Add pinned projects first
	for proj in projects:
		if proj["pinned"]:
			has_pinned = true
			var display_name = "📌 " + proj["name"]
			if not proj["exists"]:
				display_name += " (missing)"
			add_item(display_name, idx)
			set_item_tooltip(idx, proj["path"])
			if not proj["exists"]:
				set_item_disabled(idx, true)
			idx += 1
	
	# Separator between pinned and recent
	if has_pinned:
		add_separator()
		idx += 1
	
	# Add recent projects
	for proj in projects:
		if not proj["pinned"]:
			var display_name = proj["name"]
			if not proj["exists"]:
				display_name += " (missing)"
			add_item(display_name, idx)
			set_item_tooltip(idx, proj["path"])
			if not proj["exists"]:
				set_item_disabled(idx, true)
			idx += 1
	
	# Separator before actions
	add_separator()
	
	# Clear options
	add_item("Clear Recent Projects", ID_CLEAR_RECENT)
	add_item("Clear All (including pinned)", ID_CLEAR_ALL)

func _on_id_pressed(id: int) -> void:
	if id == ID_CLEAR_RECENT:
		_recent_manager.clear_recent()
		return
	
	if id == ID_CLEAR_ALL:
		_recent_manager.clear_all()
		return
	
	if id >= ID_PIN_BASE:
		# Pin toggle
		var proj_idx = id - ID_PIN_BASE
		var projects = _recent_manager.get_all_projects()
		if proj_idx < projects.size():
			pin_toggled.emit(projects[proj_idx]["path"])
		return
	
	# Regular project selection
	var projects = _recent_manager.get_all_projects()
	if id >= 0 and id < projects.size():
		var proj = projects[id]
		if proj["exists"]:
			project_selected.emit(proj["path"])

## Adds a project to the recent list
func add_project(path: String) -> void:
	_recent_manager.add_project(path)

## Pins/unpins a project
func toggle_pin(path: String) -> void:
	_recent_manager.toggle_pin(path)

## Gets the recent manager instance
func get_manager() -> VGRecentProjects:
	return _recent_manager

func _gui_input(event: InputEvent) -> void:
	# Right-click to toggle pin
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Get focused item index - PopupMenu doesn't have get_item_at_position in all versions
		var idx = get_focused_item()
		if idx >= 0 and idx < _recent_manager.get_project_count():
			var projects = _recent_manager.get_all_projects()
			if idx < projects.size():
				_recent_manager.toggle_pin(projects[idx]["path"])
				_rebuild_menu()
