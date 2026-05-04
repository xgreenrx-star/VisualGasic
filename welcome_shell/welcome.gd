# VisualGasic Welcome shell — replaces Godot's Project Manager.
#
# Reads the cross-project recent list written by the VG plugin, lets the
# user browse / search / tag-filter, and on activation spawns a fresh
# Godot instance pointed at the chosen project.
#
# Optional features:
#   - Per-project icon thumbnails (loaded from <proj>/icon.svg | icon.png)
#   - Free-text search across name + path
#   - Tag chips derived from the parent dir (demos, examples, game_projects, …)
#   - "Ask Narcea" entry: drops a narcea_seed.txt into a fresh project so
#     the IDE plugin can hand it to the AI panel on first open.
extends Control

const RECENT_CFG_FILENAME := "recent_projects.cfg"
const ICON_CACHE_MAX := 64

@onready var _recent_list: ItemList = $HSplit/Left/RecentList
@onready var _empty_label: Label = $HSplit/Left/Empty
@onready var _search_edit: LineEdit = $FilterBar/SearchEdit
@onready var _tag_bar: HBoxContainer = $FilterBar/TagBar
@onready var _open_btn: Button = $HSplit/Right/Buttons/OpenBtn
@onready var _create_btn: Button = $HSplit/Right/Buttons/CreateBtn
@onready var _narcea_btn: Button = $HSplit/Right/Buttons/NarceaBtn
@onready var _browse_btn: Button = $HSplit/Right/Buttons/BrowseBtn
@onready var _forget_btn: Button = $HSplit/Right/Buttons/ForgetBtn
@onready var _quit_btn: Button = $HSplit/Right/Buttons/QuitBtn
@onready var _thumb: TextureRect = $HSplit/Right/Detail/ThumbRow/Thumb
@onready var _detail_name: Label = $HSplit/Right/Detail/ThumbRow/ThumbInfo/NameLabel
@onready var _detail_path: Label = $HSplit/Right/Detail/ThumbRow/ThumbInfo/PathLabel
@onready var _detail_ts: Label = $HSplit/Right/Detail/ThumbRow/ThumbInfo/TimestampLabel
@onready var _detail_tags: Label = $HSplit/Right/Detail/ThumbRow/ThumbInfo/TagsLabel
@onready var _status: Label = $StatusBar/StatusLabel

var _recent: Array = []                 # all entries from disk
var _filtered_indices: Array[int] = []  # indices into _recent currently displayed
var _icon_cache: Dictionary = {}        # path -> Texture2D
var _active_tag: String = ""
var _search_text: String = ""


func _ready() -> void:
	get_window().title = "VisualGasic — Welcome"
	# Open fullscreen so the welcome takes the whole screen from the
	# start — keeps focus, no flash of desktop, and matches the
	# fullscreen cover we use during project launch.
	get_window().mode = Window.MODE_FULLSCREEN
	_recent_list.item_activated.connect(_on_item_activated)
	_recent_list.item_selected.connect(_on_item_selected)
	_search_edit.text_changed.connect(_on_search_changed)
	_open_btn.pressed.connect(_on_open_pressed)
	_create_btn.pressed.connect(_on_create_pressed)
	_narcea_btn.pressed.connect(_on_narcea_pressed)
	_browse_btn.pressed.connect(_on_browse_pressed)
	_forget_btn.pressed.connect(_on_forget_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	_load_recent()
	_rebuild_tag_chips()
	_apply_filter()
	_clear_detail()
	_sweep_stale_launching_flag()


## If a previous welcome-shell run was killed mid-launch, a stale
## launching.flag may still be sitting in the config dir. Anything
## older than 60s is definitely orphaned (typical IDE init is well
## under that), so drop it on startup so the next launch isn't
## confused by a flag it didn't write.
func _sweep_stale_launching_flag() -> void:
	var cfg_dir := _recent_cfg_path().get_base_dir()
	if cfg_dir.is_empty():
		return
	var flag_path := cfg_dir + "/launching.flag"
	if not FileAccess.file_exists(flag_path):
		return
	var age_seconds := Time.get_unix_time_from_system() - FileAccess.get_modified_time(flag_path)
	if age_seconds > 60:
		DirAccess.remove_absolute(flag_path)


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
	# Drop entries whose project.godot has vanished, derive tags from path.
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var p: String = str(entry.get("path", ""))
		if p.is_empty() or not FileAccess.file_exists(p + "/project.godot"):
			continue
		entry["tag"] = _derive_tag(p)
		_recent.append(entry)


func _save_recent() -> void:
	var path := _recent_cfg_path()
	if path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var cfg := ConfigFile.new()
	# Strip our derived "tag" before persisting — it's always recomputed.
	var to_save: Array = []
	for entry in _recent:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = entry.duplicate()
		copy.erase("tag")
		to_save.append(copy)
	cfg.set_value("recent", "projects", to_save)
	cfg.save(path)


# ─── Tags ───────────────────────────────────────────────────────────────────
func _derive_tag(project_path: String) -> String:
	# Tag is the immediate parent directory name, with a few normalisations.
	var parent := project_path.get_base_dir().get_file()
	if parent.is_empty():
		return "other"
	var lower := parent.to_lower()
	# Friendlier labels for the well-known source-tree groups.
	match lower:
		"demos", "demo": return "demos"
		"examples", "example": return "examples"
		"game_projects", "games": return "games"
		"test_proj", "tests": return "tests"
		"ai_projects": return "ai"
	return parent


func _rebuild_tag_chips() -> void:
	for c in _tag_bar.get_children():
		c.queue_free()
	# "All" chip + one per unique tag.
	var counts: Dictionary = {}
	for entry in _recent:
		var t: String = str(entry.get("tag", ""))
		counts[t] = int(counts.get(t, 0)) + 1
	_tag_bar.add_child(_make_tag_chip("All", "", _recent.size()))
	var tags := counts.keys()
	tags.sort()
	for t in tags:
		_tag_bar.add_child(_make_tag_chip(t, t, counts[t]))


func _make_tag_chip(label: String, value: String, count: int) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.text = "%s (%d)" % [label, count]
	btn.button_pressed = (value == _active_tag)
	btn.add_theme_font_size_override("font_size", 11)
	btn.tooltip_text = "Filter by tag: %s" % (label if value != "" else "all")
	btn.pressed.connect(func():
		_active_tag = value
		# Update chip toggles.
		for c in _tag_bar.get_children():
			if c is Button:
				c.button_pressed = (c == btn)
		_apply_filter()
	)
	return btn


# ─── Filtering ──────────────────────────────────────────────────────────────
func _on_search_changed(new_text: String) -> void:
	_search_text = new_text.to_lower()
	_apply_filter()


func _apply_filter() -> void:
	_filtered_indices.clear()
	for i in _recent.size():
		var entry: Dictionary = _recent[i]
		if _active_tag != "" and str(entry.get("tag", "")) != _active_tag:
			continue
		if _search_text != "":
			var hay := (str(entry.get("name", "")) + " " + str(entry.get("path", ""))).to_lower()
			if hay.find(_search_text) == -1:
				continue
		_filtered_indices.append(i)
	_render_list()


func _render_list() -> void:
	_recent_list.clear()
	for i in _filtered_indices:
		var entry: Dictionary = _recent[i]
		var nm := str(entry.get("name", "—"))
		var pth := str(entry.get("path", ""))
		var tag := str(entry.get("tag", ""))
		var label := "%s\n[%s]  %s" % [nm, tag, pth]
		var idx := _recent_list.add_item(label)
		var tex := _icon_for(pth)
		if tex != null:
			_recent_list.set_item_icon(idx, tex)
	var anything := _filtered_indices.size() > 0
	_recent_list.visible = anything
	_empty_label.visible = not anything
	if _recent.is_empty():
		_empty_label.text = "No recent projects yet.\nClick + Create, 📂 Browse, or 🌿 Ask Narcea."
	elif not anything:
		_empty_label.text = "No matches for current filter."
	_open_btn.disabled = not anything
	_status.text = "%d / %d project%s" % [_filtered_indices.size(), _recent.size(), "s" if _recent.size() != 1 else ""]


# ─── Icon loading ───────────────────────────────────────────────────────────
func _icon_for(project_path: String) -> Texture2D:
	if _icon_cache.has(project_path):
		return _icon_cache[project_path]
	var found: Texture2D = null
	for fname in ["icon.svg", "icon.png", "icon.webp"]:
		var p: String = project_path + "/" + fname
		if not FileAccess.file_exists(p):
			continue
		if fname.ends_with(".svg"):
			# Load SVG bytes via Image.load_svg_from_string for portability.
			var f := FileAccess.open(p, FileAccess.READ)
			if f == null:
				continue
			var src := f.get_as_text()
			f.close()
			var img := Image.new()
			# Scale 0.5 keeps thumbnails small and fast to upload.
			if img.load_svg_from_string(src, 0.5) == OK:
				found = ImageTexture.create_from_image(img)
		else:
			var img2 := Image.new()
			if img2.load(p) == OK:
				img2.resize(64, 64, Image.INTERPOLATE_BILINEAR)
				found = ImageTexture.create_from_image(img2)
		if found != null:
			break
	if _icon_cache.size() >= ICON_CACHE_MAX:
		_icon_cache.clear()
	_icon_cache[project_path] = found
	return found


# ─── Selection / activation ─────────────────────────────────────────────────
func _on_item_selected(list_idx: int) -> void:
	if list_idx < 0 or list_idx >= _filtered_indices.size():
		_clear_detail()
		return
	var i := _filtered_indices[list_idx]
	var entry: Dictionary = _recent[i]
	_detail_name.text = "🌿  %s" % str(entry.get("name", "—"))
	_detail_path.text = str(entry.get("path", ""))
	var ts: int = int(entry.get("ts", 0))
	if ts > 0:
		var dt := Time.get_datetime_dict_from_unix_time(ts)
		_detail_ts.text = "Last opened: %04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
	else:
		_detail_ts.text = ""
	_detail_tags.text = "🏷  %s" % str(entry.get("tag", ""))
	_thumb.texture = _icon_for(str(entry.get("path", "")))


func _clear_detail() -> void:
	_detail_name.text = ""
	_detail_path.text = ""
	_detail_ts.text = ""
	_detail_tags.text = ""
	_thumb.texture = null


func _on_item_activated(list_idx: int) -> void:
	_open_filtered(list_idx)


func _on_open_pressed() -> void:
	if not _recent_list.is_anything_selected():
		_status.text = "Select a project first"
		return
	_open_filtered(_recent_list.get_selected_items()[0])


func _open_filtered(list_idx: int) -> void:
	if list_idx < 0 or list_idx >= _filtered_indices.size():
		return
	var i := _filtered_indices[list_idx]
	var entry: Dictionary = _recent[i]
	var path := str(entry.get("path", ""))
	if path.is_empty() or not FileAccess.file_exists(path + "/project.godot"):
		_status.text = "Project missing on disk: %s" % path
		_recent.remove_at(i)
		_save_recent()
		_apply_filter()
		return
	_launch_godot(path)


func _on_forget_pressed() -> void:
	if not _recent_list.is_anything_selected():
		return
	var list_idx: int = _recent_list.get_selected_items()[0]
	if list_idx < 0 or list_idx >= _filtered_indices.size():
		return
	var i := _filtered_indices[list_idx]
	_recent.remove_at(i)
	_save_recent()
	_rebuild_tag_chips()
	_apply_filter()
	_clear_detail()


func _force_dialog_size(dlg: Window, sz: Vector2i) -> void:
	if not is_instance_valid(dlg):
		return
	dlg.size = sz
	# Re-center against the visible viewport. get_window() can return the
	# dialog's own embedded window; viewport rect is the reliable source.
	var view_size := Vector2i(get_viewport().get_visible_rect().size)
	dlg.position = (view_size - sz) / 2


func _on_quit_pressed() -> void:
	# Drop fullscreen/always-on-top first so the WM releases input
	# focus cleanly, then quit. Print for debuggability.
	print("[VG Welcome] Quit pressed")
	var win := get_window()
	if win != null:
		win.always_on_top = false
		if win.mode == Window.MODE_FULLSCREEN:
			win.mode = Window.MODE_WINDOWED
	get_tree().quit()


# ─── Browse / Create / Narcea ───────────────────────────────────────────────
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
	# Local-create dialog: pick name + parent folder, scaffold a tiny
	# Godot project, then hand off to Godot via _launch_godot() which
	# already handles the cover + spinner. Avoids dumping the user back
	# into Godot's stock Project Manager (which is what we're trying to
	# replace in the first place).
	var dlg := AcceptDialog.new()
	dlg.title = "+  Create New Project"
	dlg.ok_button_text = "Create + Open"
	dlg.min_size = Vector2i(560, 180)
	dlg.max_size = Vector2i(560, 220)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dlg.add_child(box)

	var info := Label.new()
	info.text = "A blank VG-ready project will be scaffolded and opened in the IDE."
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)

	# Project name row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = "Project name:"
	name_lbl.custom_minimum_size.x = 110
	name_row.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text = "MyProject"
	name_edit.select_all_on_focus = true
	name_row.add_child(name_edit)
	box.add_child(name_row)

	# Parent folder row
	var folder_row := HBoxContainer.new()
	folder_row.add_theme_constant_override("separation", 8)
	var folder_lbl := Label.new()
	folder_lbl.text = "Parent folder:"
	folder_lbl.custom_minimum_size.x = 110
	folder_row.add_child(folder_lbl)
	var folder_edit := LineEdit.new()
	folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var home := OS.get_environment("HOME")
	folder_edit.text = (home + "/Documents/VisualGasic_Projects") if not home.is_empty() else "VisualGasic_Projects"
	folder_row.add_child(folder_edit)
	var browse_btn := Button.new()
	browse_btn.text = "📂"
	browse_btn.tooltip_text = "Pick parent folder"
	browse_btn.pressed.connect(func():
		var fd := FileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		fd.access = FileDialog.ACCESS_FILESYSTEM
		fd.title = "Pick parent folder"
		fd.current_dir = folder_edit.text
		fd.dir_selected.connect(func(p: String):
			folder_edit.text = p
			fd.queue_free()
		)
		fd.canceled.connect(fd.queue_free)
		add_child(fd)
		fd.popup_centered(Vector2i(720, 480))
	)
	folder_row.add_child(browse_btn)
	box.add_child(folder_row)

	dlg.confirmed.connect(func():
		var nm := name_edit.text.strip_edges()
		var parent_dir := folder_edit.text.strip_edges()
		if nm.is_empty():
			_status.text = "Project name is required."
			return
		if parent_dir.is_empty():
			_status.text = "Parent folder is required."
			return
		var path := _create_blank_project(nm, parent_dir)
		if not path.is_empty():
			_launch_godot(path)
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered(Vector2i(560, 200))
	# Subwindow embedding can ignore the popup minsize; pin it next frame.
	dlg.size = Vector2i(560, 200)
	call_deferred("_force_dialog_size", dlg, Vector2i(560, 200))
	name_edit.grab_focus()


func _create_blank_project(proj_name: String, parent_dir: String) -> String:
	var safe_name := proj_name.strip_edges().replace(" ", "_")
	if safe_name.is_empty():
		_status.text = "Invalid project name."
		return ""
	var mk_parent := DirAccess.make_dir_recursive_absolute(parent_dir)
	if mk_parent != OK and not DirAccess.dir_exists_absolute(parent_dir):
		_status.text = "Cannot create parent folder: %s (err %d)" % [parent_dir, mk_parent]
		return ""
	var dir := parent_dir.rstrip("/") + "/" + safe_name
	if DirAccess.dir_exists_absolute(dir):
		_status.text = "Directory already exists: %s" % dir
		return ""
	var mk := DirAccess.make_dir_recursive_absolute(dir)
	if mk != OK:
		_status.text = "Failed to make directory: %s (err %d)" % [dir, mk]
		return ""

	# project.godot with the VG plugin pre-enabled. We seed the addon
	# directory below; without the [editor_plugins] section Godot would
	# open the project but never load VG.
	var pg := ""
	pg += "config_version=5\n\n"
	pg += "[application]\n\n"
	pg += "config/name=\"%s\"\n" % proj_name.replace("\"", "'")
	pg += "config/features=PackedStringArray(\"4.6\", \"Forward Plus\")\n\n"
	pg += "[audio]\n\n"
	pg += "driver/enable_input=true\n\n"
	pg += "[editor_plugins]\n\n"
	pg += "enabled=PackedStringArray(\"res://addons/visual_gasic/plugin.cfg\")\n"
	var f := FileAccess.open(dir + "/project.godot", FileAccess.WRITE)
	if f == null:
		_status.text = "Failed to write project.godot in %s" % dir
		return ""
	f.store_string(pg)
	f.close()

	# Seed the canonical addon so the project is VG-ready on first open.
	var addon_src := _resolve_canonical_addon_dir()
	if addon_src.is_empty():
		_status.text = "Created %s but couldn't find VG addon source — open from a source-tree checkout or set $VG_ADDON_SOURCE." % dir
		return dir
	var copy_err := _copy_dir_recursive(addon_src, dir + "/addons/visual_gasic")
	if copy_err != OK:
		_status.text = "Created %s but addon copy failed (err %d)." % [dir, copy_err]
		return dir
	_status.text = "Created %s — opening…" % dir
	return dir


func _on_narcea_pressed() -> void:
	# Lightweight prompt: collect a one-paragraph description, write it
	# into a fresh project as `narcea_seed.txt`. The IDE plugin reads
	# that on first open and pre-fills the AI panel so the user can
	# refine and let Narcea scaffold the rest.
	var dlg := AcceptDialog.new()
	dlg.title = "🌿  Ask Narcea to Make a Project"
	dlg.ok_button_text = "Create + Open"
	dlg.min_size = Vector2i(560, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	dlg.add_child(box)

	var info := Label.new()
	info.text = "Describe what you want. Narcea will draft a project plan when the IDE opens."
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = "Project name:"
	name_lbl.custom_minimum_size.x = 110
	name_row.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text = "MyNarceaProject"
	name_edit.select_all_on_focus = true
	name_row.add_child(name_edit)
	box.add_child(name_row)

	var desc := TextEdit.new()
	desc.custom_minimum_size = Vector2(0, 200)
	desc.placeholder_text = "e.g. A small Pong clone with paddles, a ball, score labels, and a Game Over screen. Use VG syntax."
	desc.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(desc)

	dlg.confirmed.connect(func():
		var nm := name_edit.text.strip_edges()
		var d := desc.text.strip_edges()
		if nm.is_empty() or d.is_empty():
			_status.text = "Name and description are required."
			return
		var path := _create_narcea_seed_project(nm, d)
		if not path.is_empty():
			_launch_godot(path)
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered(Vector2i(620, 360))
	dlg.size = Vector2i(620, 360)
	call_deferred("_force_dialog_size", dlg, Vector2i(620, 360))
	desc.grab_focus()


func _create_narcea_seed_project(proj_name: String, description: String) -> String:
	var safe_name := proj_name.strip_edges().replace(" ", "_")
	var home := OS.get_environment("HOME")
	if home.is_empty():
		_status.text = "Couldn't resolve $HOME — aborted."
		return ""
	var base := home + "/Documents/VisualGasic_Projects"
	DirAccess.make_dir_recursive_absolute(base)
	var dir := base + "/" + safe_name
	if DirAccess.dir_exists_absolute(dir):
		_status.text = "Directory already exists: %s" % dir
		return ""
	var mk := DirAccess.make_dir_recursive_absolute(dir)
	if mk != OK:
		_status.text = "Failed to make directory: %s (err %d)" % [dir, mk]
		return ""

	# project.godot with the VG plugin pre-enabled.
	var pg := ""
	pg += "config_version=5\n\n"
	pg += "[application]\n\n"
	pg += "config/name=\"%s\"\n" % proj_name.replace("\"", "'")
	pg += "config/features=PackedStringArray(\"4.6\", \"Forward Plus\")\n\n"
	pg += "[audio]\n\n"
	pg += "driver/enable_input=true\n\n"
	pg += "[editor_plugins]\n\n"
	pg += "enabled=PackedStringArray(\"res://addons/visual_gasic/plugin.cfg\")\n"
	var f := FileAccess.open(dir + "/project.godot", FileAccess.WRITE)
	if f == null:
		_status.text = "Failed to write project.godot in %s" % dir
		return ""
	f.store_string(pg)
	f.close()

	# Seed the canonical addon so VG loads on first open.
	var addon_src := _resolve_canonical_addon_dir()
	if not addon_src.is_empty():
		_copy_dir_recursive(addon_src, dir + "/addons/visual_gasic")

	# Narcea seed file the IDE plugin will pick up on first open.
	var seed := FileAccess.open(dir + "/narcea_seed.txt", FileAccess.WRITE)
	if seed != null:
		seed.store_string(description + "\n")
		seed.close()
	_status.text = "Created %s — opening…" % dir
	return dir


# ─── Launch ─────────────────────────────────────────────────────────────────
## Resolve the canonical addons/visual_gasic directory we should copy
## into newly-created projects. Mirrors the IDE plugin's resolver:
##   1. $VG_ADDON_SOURCE      (explicit override)
##   2. <repo>/addons/visual_gasic where this welcome shell lives in
##      a source-tree checkout (welcome_shell sibling)
##   3. /opt/visual_gasic/addons/visual_gasic
##   4. ~/.local/share/visual_gasic/addons/visual_gasic
func _resolve_canonical_addon_dir() -> String:
	var candidates: Array[String] = []
	var override: String = OS.get_environment("VG_ADDON_SOURCE")
	if not override.is_empty():
		candidates.append(override)
	# We're running from welcome_shell/, so the source-tree addon lives
	# at ../addons/visual_gasic relative to res://.
	var here: String = ProjectSettings.globalize_path("res://").rstrip("/")
	if not here.is_empty():
		var parent: String = here.get_base_dir()
		if DirAccess.dir_exists_absolute(parent + "/addons/visual_gasic"):
			candidates.append(parent + "/addons/visual_gasic")
	candidates.append("/opt/visual_gasic/addons/visual_gasic")
	var home: String = OS.get_environment("HOME")
	if not home.is_empty():
		candidates.append(home + "/.local/share/visual_gasic/addons/visual_gasic")
	for c in candidates:
		if c.is_empty():
			continue
		if FileAccess.file_exists(c + "/plugin.cfg"):
			return c
	return ""


## Recursively copy a directory tree (absolute paths). Skips .uid files
## since Godot regenerates those per-project.
func _copy_dir_recursive(src: String, dst: String) -> int:
	var err := DirAccess.make_dir_recursive_absolute(dst)
	if err != OK and not DirAccess.dir_exists_absolute(dst):
		return err
	var dir := DirAccess.open(src)
	if dir == null:
		return ERR_CANT_OPEN
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var src_path := src + "/" + entry
		var dst_path := dst + "/" + entry
		if dir.current_is_dir():
			var rec := _copy_dir_recursive(src_path, dst_path)
			if rec != OK:
				dir.list_dir_end()
				return rec
		elif not entry.ends_with(".uid"):
			var copy_err := DirAccess.copy_absolute(src_path, dst_path)
			if copy_err != OK:
				dir.list_dir_end()
				return copy_err
		entry = dir.get_next()
	dir.list_dir_end()
	return OK


func _vg_config_dir() -> String:
	# Same dir as recent_projects.cfg's parent.
	return _recent_cfg_path().get_base_dir()


## Build a modern circular loading spinner: a thin rotating arc.
## When set_meta("done", true) is set on it, it freezes as a full ring.
func _make_circular_spinner() -> Control:
	# Vertical holder so the spinner sits below the dialog text with a
	# bit of breathing room — centered-on-top-of-words reads as a crash.
	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.custom_minimum_size = Vector2(64, 96)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 40)
	holder.add_child(pad)
	var center_box := CenterContainer.new()
	holder.add_child(center_box)
	var spinner := Control.new()
	spinner.custom_minimum_size = Vector2(48, 48)
	spinner.set_meta("angle", 0.0)
	spinner.set_meta("done", false)
	spinner.draw.connect(func():
		var size := spinner.size
		var center := size * 0.5
		var radius: float = min(size.x, size.y) * 0.5 - 3.0
		var track_color := Color(1, 1, 1, 0.15)
		var arc_color := Color(0.30, 0.65, 1.0, 1.0)  # accent blue
		var thickness := 3.0
		# Track ring (always full).
		spinner.draw_arc(center, radius, 0.0, TAU, 64, track_color, thickness, true)
		# Active arc.
		var done: bool = bool(spinner.get_meta("done", false))
		if done:
			var done_color := Color(0.30, 0.85, 0.45, 1.0)  # green
			spinner.draw_arc(center, radius, 0.0, TAU, 64, done_color, thickness, true)
		else:
			var a: float = float(spinner.get_meta("angle", 0.0))
			var sweep := TAU * 0.30  # ~110° leading arc
			spinner.draw_arc(center, radius, a, a + sweep, 32, arc_color, thickness, true)
	)
	# Drive the rotation via the SceneTree's per-frame signal so we
	# don't need a custom script on the Control. ~0.9 rev/sec.
	get_tree().process_frame.connect(func():
		if not is_instance_valid(spinner):
			return
		if bool(spinner.get_meta("done", false)):
			spinner.queue_redraw()
			return
		var dt: float = get_process_delta_time()
		var a: float = float(spinner.get_meta("angle", 0.0))
		a = fmod(a + dt * TAU * 0.9, TAU)
		spinner.set_meta("angle", a)
		spinner.queue_redraw()
	)
	center_box.add_child(spinner)
	return holder


func _launch_godot(project_dir: String) -> void:
	var godot_bin := OS.get_executable_path()
	# Drop a "launching" marker the spawned IDE plugin will delete once
	# its UI is built; we poll for it below so the splash matches actual
	# IDE-ready time instead of guessing with a fixed timer.
	var flag_path := ""
	var cfg_dir := _vg_config_dir()
	if not cfg_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(cfg_dir)
		flag_path = cfg_dir + "/launching.flag"
		var ff := FileAccess.open(flag_path, FileAccess.WRITE)
		if ff != null:
			ff.store_string(str(Time.get_unix_time_from_system()))
			ff.close()

	# Show a modal "Loading…" splash. We also expand the welcome
	# window itself to cover the full screen and pin it always-on-top
	# so Godot's editor — which may ignore our --position hints and
	# come up wherever its project.godot tells it to — stays hidden
	# behind the splash until the VG plugin signals ready.
	var win := get_window()
	var prev_mode := win.mode
	var prev_borderless := win.borderless
	var prev_always_on_top := win.always_on_top
	win.borderless = true
	win.always_on_top = true
	win.mode = Window.MODE_FULLSCREEN

	var splash := AcceptDialog.new()
	splash.title = "VisualGasic"
	splash.dialog_text = "Loading %s …\n\nThe IDE will appear in a moment." % project_dir.get_file()
	splash.get_ok_button().visible = false
	splash.exclusive = true
	splash.unresizable = true
	# Modern circular spinner — a custom-drawn arc that rotates while
	# the IDE boots. Flipped to a full ring + checkmark color once the
	# launching.flag is cleared.
	var spinner := _make_circular_spinner()
	splash.add_child(spinner)
	add_child(splash)
	splash.popup_centered(Vector2i(420, 180))
	# Yield one frame so the splash is on screen before we fork Godot.
	await get_tree().process_frame

	# Spawn Godot. We don't bother with --position/--resolution hints —
	# Godot tends to override them with the project's own window
	# settings. The fullscreen always-on-top welcome window above is
	# what actually keeps the editor out of view.
	var pid: int = OS.create_process(godot_bin, [
		"--path", project_dir,
		"--editor",
	])
	if pid <= 0:
		splash.queue_free()
		win.mode = prev_mode
		win.borderless = prev_borderless
		win.always_on_top = prev_always_on_top
		_status.text = "Failed to launch Godot for %s" % project_dir
		if not flag_path.is_empty():
			DirAccess.remove_absolute(flag_path)
		return
	# Bump the recent entry's timestamp so the list is fresh next time.
	for entry in _recent:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("path", "")) == project_dir:
			entry["ts"] = int(Time.get_unix_time_from_system())
			break
	_save_recent()

	# Poll for the spawned IDE deleting its launching.flag (max 20s),
	# then a tail-wait so the editor finishes its window paint before
	# we close the splash and uncover it.
	if not flag_path.is_empty():
		var deadline := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < deadline and FileAccess.file_exists(flag_path):
			await get_tree().create_timer(0.15).timeout
		# Cleanup if the IDE crashed / never started.
		if FileAccess.file_exists(flag_path):
			DirAccess.remove_absolute(flag_path)
	# Flip the spinner to a satisfying "done" state, then a longer
	# tail-wait so the Godot editor finishes its first paint before we
	# drop our always-on-top cover — otherwise the user sees ~0.5s of
	# bare editor before the VG IDE skins itself in.
	spinner.set_meta("done", true)
	splash.dialog_text = "Ready. Opening %s…" % project_dir.get_file()
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()
