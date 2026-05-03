# VisualGasic Welcome shell — replaces Godot's Project Manager.
#
# Reads the cross-project recent list written by visual_gasic_plugin.gd
# (`_record_recent_vg_project`) from the OS-appropriate config dir, shows
# a list of recents with Open/Create/Browse buttons, and on activation
# spawns a fresh Godot instance pointed at the chosen project then
# quits.
extends Control

const RECENT_CFG_FILENAME := "recent_projects.cfg"

@onready var _recent_list: ItemList = $HSplit/Left/RecentList
@onready var _empty_label: Label = $HSplit/Left/Empty
@onready var _open_btn: Button = $HSplit/Right/Buttons/OpenBtn
@onready var _create_btn: Button = $HSplit/Right/Buttons/CreateBtn
@onready var _browse_btn: Button = $HSplit/Right/Buttons/BrowseBtn
@onready var _quit_btn: Button = $HSplit/Right/Buttons/QuitBtn
@onready var _detail_name: Label = $HSplit/Right/Detail/NameLabel
@onready var _detail_path: Label = $HSplit/Right/Detail/PathLabel
@onready var _detail_ts: Label = $HSplit/Right/Detail/TimestampLabel
@onready var _status: Label = $StatusBar/StatusLabel

var _recent: Array = []  # [{path, name, ts}, ...]


func _ready() -> void:
	get_window().title = "VisualGasic — Welcome"
	_recent_list.item_activated.connect(_on_item_activated)
	_recent_list.item_selected.connect(_on_item_selected)
	_open_btn.pressed.connect(_on_open_pressed)
	_create_btn.pressed.connect(_on_create_pressed)
	_browse_btn.pressed.connect(_on_browse_pressed)
	_quit_btn.pressed.connect(func(): get_tree().quit())
	_load_recent()
	_render_list()
	_status.text = "%d recent project%s" % [_recent.size(), "s" if _recent.size() != 1 else ""]


# ─── Recent-list IO ─────────────────────────────────────────────────────────
func _recent_cfg_path() -> String:
	match OS.get_name():
		"Windows", "UWP":
			var appdata := OS.get_environment("APPDATA")
			if appdata.is_empty():
				return ""
			return appdata + "/VisualGasic/" + RECENT_CFG_FILENAME
		"macOS":
			var home_mac := OS.get_environment("HOME")
			if home_mac.is_empty():
				return ""
			return home_mac + "/Library/Application Support/VisualGasic/" + RECENT_CFG_FILENAME
		_:
			var xdg := OS.get_environment("XDG_CONFIG_HOME")
			if xdg.is_empty():
				var home := OS.get_environment("HOME")
				if home.is_empty():
					return ""
				xdg = home + "/.config"
			return xdg + "/visual_gasic/" + RECENT_CFG_FILENAME


func _load_recent() -> void:
	_recent.clear()
	var path := _recent_cfg_path()
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var entries: Array = cfg.get_value("recent", "projects", [])
	if typeof(entries) != TYPE_ARRAY:
		return
	# Drop entries whose project.godot has vanished.
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var p := str(entry.get("path", ""))
		if p.is_empty() or not FileAccess.file_exists(p + "/project.godot"):
			continue
		_recent.append(entry)


func _save_recent() -> void:
	var path := _recent_cfg_path()
	if path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var cfg := ConfigFile.new()
	cfg.set_value("recent", "projects", _recent)
	cfg.save(path)


func _render_list() -> void:
	_recent_list.clear()
	for entry in _recent:
		var nm := str(entry.get("name", "—"))
		var pth := str(entry.get("path", ""))
		_recent_list.add_item("%s\n%s" % [nm, pth])
	_recent_list.visible = not _recent.is_empty()
	_empty_label.visible = _recent.is_empty()
	_open_btn.disabled = _recent.is_empty()
	_clear_detail()


func _clear_detail() -> void:
	_detail_name.text = ""
	_detail_path.text = ""
	_detail_ts.text = ""


# ─── Selection / activation ─────────────────────────────────────────────────
func _on_item_selected(idx: int) -> void:
	if idx < 0 or idx >= _recent.size():
		_clear_detail()
		return
	var entry: Dictionary = _recent[idx]
	_detail_name.text = "🌿  %s" % str(entry.get("name", "—"))
	_detail_path.text = str(entry.get("path", ""))
	var ts: int = int(entry.get("ts", 0))
	if ts > 0:
		var dt := Time.get_datetime_dict_from_unix_time(ts)
		_detail_ts.text = "Last opened: %04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
	else:
		_detail_ts.text = ""


func _on_item_activated(idx: int) -> void:
	_open_index(idx)


func _on_open_pressed() -> void:
	var idx: int = -1
	if _recent_list.is_anything_selected():
		idx = _recent_list.get_selected_items()[0]
	if idx < 0:
		_status.text = "Select a project first"
		return
	_open_index(idx)


func _open_index(idx: int) -> void:
	if idx < 0 or idx >= _recent.size():
		return
	var entry: Dictionary = _recent[idx]
	var path := str(entry.get("path", ""))
	if path.is_empty() or not FileAccess.file_exists(path + "/project.godot"):
		_status.text = "Project missing on disk: %s" % path
		_recent.remove_at(idx)
		_save_recent()
		_render_list()
		return
	_launch_godot(path)


# ─── Browse / Create ────────────────────────────────────────────────────────
func _on_browse_pressed() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.title = "Open Godot Project (project.godot)"
	fd.add_filter("project.godot ; Godot Project Manifest")
	fd.min_size = Vector2i(620, 420)
	fd.file_selected.connect(func(p: String):
		_launch_godot(p.get_base_dir())
		fd.queue_free()
	)
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered()


func _on_create_pressed() -> void:
	# Without our editor plugin available here (we're in the shell, not
	# the IDE), the simplest path is to launch Godot's own Project Manager
	# so the user can create from there. After they confirm, the new
	# project will register itself in the recent list on first open.
	_status.text = "Launching Godot Project Manager to create…"
	var godot_bin := OS.get_executable_path()
	OS.create_process(godot_bin, [])  # No --path => Project Manager.
	get_tree().quit()


# ─── Launch ─────────────────────────────────────────────────────────────────
func _launch_godot(project_dir: String) -> void:
	var godot_bin := OS.get_executable_path()
	_status.text = "Opening %s …" % project_dir
	var pid: int = OS.create_process(godot_bin, ["--path", project_dir, "--editor"])
	if pid <= 0:
		_status.text = "Failed to launch Godot for %s" % project_dir
		return
	# Bump the recent entry's timestamp so the list is fresh next time.
	for entry in _recent:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("path", "")) == project_dir:
			entry["ts"] = int(Time.get_unix_time_from_system())
			break
	_save_recent()
	# Quit the shell once the new instance has handed off.
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()
