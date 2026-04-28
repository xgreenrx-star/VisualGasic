@tool
extends VBoxContainer
## VG File Browser — shown in place of Properties when the Code Editor is active.
##
## Displays the project's res:// directory tree with:
##  - Folder/file icons by type
##  - Double-click to open .vg / .tscn / .gd files
##  - Right-click context menu (Godot FileSystem-style)
##  - Drag-and-drop: files emit "files" drag data compatible with the code editor
##  - Auto-refresh when EditorFileSystem reports filesystem_changed

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the user wants to open a file in the IDE.
signal file_open_requested(path: String)

## Emitted when the user chooses "Open in Hex Editor" from the context menu.
signal open_hex_editor_requested(path: String)

# =============================================================================
# MEMBER VARIABLES
# =============================================================================

var editor_plugin: EditorPlugin

var _tree: Tree
var _toolbar: HBoxContainer
var _btn_refresh: Button
var _filter_edit: LineEdit
var _context_menu: PopupMenu

# Dialogs
var _rename_dialog: ConfirmationDialog
var _rename_edit: LineEdit
var _new_vg_dialog: ConfirmationDialog
var _new_vg_edit: LineEdit
var _new_gd_dialog: ConfirmationDialog
var _new_gd_edit: LineEdit
var _new_folder_dialog: ConfirmationDialog
var _new_folder_edit: LineEdit
var _confirm_delete_dialog: ConfirmationDialog

var _right_clicked_path: String = ""

## Map<res://path, true> of files whose mtime diverged from what the
## IDE last wrote. Set by VGAssetBus.asset_invalidated, cleared by
## asset_saved (user reconciled). Used to render a ⚠ badge in the tree.
var _externally_changed: Dictionary = {}
# =============================================================================
# CONSTANTS — file-extension icons
# =============================================================================

const FILE_ICONS: Dictionary = {
	"vg":     "📄",
	"gd":     "📜",
	"tscn":   "🎬",
	"scn":    "🎬",
	"tres":   "🗄️",
	"res":    "🗄️",
	"png":    "🖼️",
	"jpg":    "🖼️",
	"jpeg":   "🖼️",
	"svg":    "🖼️",
	"webp":   "🖼️",
	"wav":    "🔊",
	"ogg":    "🔊",
	"mp3":    "🔊",
	"ttf":    "🔤",
	"otf":    "🔤",
	"cfg":    "⚙️",
	"json":   "📋",
	"txt":    "📝",
	"md":     "📝",
	"import": "⬇️",
	"uid":    "🔑",
}
const FOLDER_ICON: String  = "📁"
const FILE_DEFAULT: String = "📄"

# =============================================================================
# CONSTANTS — context-menu item IDs  (non-zero to avoid separator ID -1)
# =============================================================================

# Open group
const MENU_OPEN_VG_IDE   = 10   # open in VG code/form editor
const MENU_OPEN_EXTERNAL = 11   # open in OS default app
const MENU_OPEN_HEX      = 12   # open in VG Hex Editor
# Clipboard / navigate
const MENU_COPY_PATH     = 20
const MENU_COPY_UID      = 21
const MENU_SHOW_IN_FM    = 22   # reveal in native file manager
# Edit
const MENU_RENAME        = 30
const MENU_DUPLICATE     = 31
# Create
const MENU_NEW_VG        = 40   # new .vg script
const MENU_NEW_GD        = 41   # new .gd script
const MENU_NEW_FOLDER    = 42
# Destroy
const MENU_DELETE        = 50

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	name = "FileSystem"
	size_flags_vertical  = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size  = Vector2(100, 80)

	# ── Header / Toolbar ─────────────────────────────────────────────────────
	# PanelContainer is required so the StyleBoxFlat background actually renders;
	# HBoxContainer does not paint a "panel" stylebox override.
	_toolbar = HBoxContainer.new()
	_toolbar.custom_minimum_size.y = 26
	var tb_style = StyleBoxFlat.new()
	tb_style.bg_color = Color("#3C3F41")  # dark header matching Godot editor panels
	tb_style.content_margin_left   = 6
	tb_style.content_margin_right  = 4
	tb_style.content_margin_top    = 2
	tb_style.content_margin_bottom = 2
	var _tb_panel := PanelContainer.new()
	_tb_panel.add_theme_stylebox_override("panel", tb_style)
	_tb_panel.add_child(_toolbar)

	var title_lbl = Label.new()
	title_lbl.text = "FileSystem"
	title_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))  # light on dark header
	title_lbl.add_theme_font_size_override("font_size", 12)
	_toolbar.add_child(title_lbl)

	_btn_refresh = Button.new()
	_btn_refresh.text = "⟳"
	_btn_refresh.tooltip_text = "Refresh"
	_btn_refresh.flat = true
	_btn_refresh.custom_minimum_size = Vector2(26, 0)
	_btn_refresh.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_btn_refresh.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_btn_refresh.pressed.connect(refresh)
	_toolbar.add_child(_btn_refresh)

	add_child(_tb_panel)

	# ── Filter bar ───────────────────────────────────────────────────────────
	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "🔍 Filter files..."
	_filter_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_filter_edit.clear_button_enabled = true
	_filter_edit.custom_minimum_size.y = 22
	var filter_sb = StyleBoxFlat.new()
	filter_sb.bg_color = Color(1.0, 1.0, 1.0)
	filter_sb.border_color = Color(0.65, 0.64, 0.62)
	filter_sb.set_border_width_all(1)
	filter_sb.content_margin_left  = 4
	filter_sb.content_margin_right = 4
	_filter_edit.add_theme_stylebox_override("normal", filter_sb)
	_filter_edit.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_filter_edit.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	_filter_edit.add_theme_color_override("caret_color", Color(0.0, 0.0, 0.0))
	_filter_edit.add_theme_font_size_override("font_size", 11)
	_filter_edit.text_changed.connect(_on_filter_changed)
	add_child(_filter_edit)

	# ── File Tree ────────────────────────────────────────────────────────────
	_tree = Tree.new()
	_tree.size_flags_vertical  = SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.allow_reselect = true
	_tree.select_mode = Tree.SELECT_SINGLE
	_tree.scroll_horizontal_enabled = true
	_tree.custom_minimum_size = Vector2(0, 80)
	# VB6-style light background
	var tree_bg = StyleBoxFlat.new()
	tree_bg.bg_color = Color("#FAFAF8")
	tree_bg.content_margin_left   = 2
	tree_bg.content_margin_right  = 2
	tree_bg.content_margin_top    = 2
	tree_bg.content_margin_bottom = 2
	_tree.add_theme_stylebox_override("panel", tree_bg)
	_tree.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_tree.add_theme_color_override("font_selected_color", Color(0.1, 0.1, 0.1))
	_tree.add_theme_color_override("title_button_color", Color(0.1, 0.1, 0.1))
	_tree.add_theme_font_size_override("font_size", 12)
	_tree.item_activated.connect(_on_item_activated)
	# gui_input fires for ALL mouse events regardless of selection state;
	# item_mouse_selected is skipped when right-clicking an already-selected row.
	_tree.gui_input.connect(_on_tree_gui_input)
	add_child(_tree)

	# ── Context Menu (Godot FileSystem style) ─────────────────────────────────
	_context_menu = PopupMenu.new()
	# Open group
	_context_menu.add_item("Open in VG IDE",         MENU_OPEN_VG_IDE)
	_context_menu.add_item("Open in External Editor", MENU_OPEN_EXTERNAL)
	_context_menu.add_item("Open in Hex Editor",     MENU_OPEN_HEX)
	_context_menu.add_separator()
	# Clipboard / navigate
	_context_menu.add_item("Copy Path",              MENU_COPY_PATH)
	_context_menu.add_item("Copy UID",               MENU_COPY_UID)
	_context_menu.add_item("Show in File Manager",   MENU_SHOW_IN_FM)
	_context_menu.add_separator()
	# Edit
	_context_menu.add_item("Rename...",              MENU_RENAME)
	_context_menu.add_item("Duplicate",              MENU_DUPLICATE)
	_context_menu.add_separator()
	# Create
	_context_menu.add_item("New VG Script...",       MENU_NEW_VG)
	_context_menu.add_item("New GDScript...",        MENU_NEW_GD)
	_context_menu.add_item("New Folder...",          MENU_NEW_FOLDER)
	_context_menu.add_separator()
	# Destroy
	_context_menu.add_item("Delete",                 MENU_DELETE)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(_context_menu)

	# ── Rename dialog ─────────────────────────────────────────────────────────
	_rename_edit = LineEdit.new()
	_rename_edit.custom_minimum_size.x = 260
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Rename"
	_rename_dialog.add_child(_rename_edit)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)

	# ── New VG Script dialog ──────────────────────────────────────────────────
	_new_vg_edit = LineEdit.new()
	_new_vg_edit.placeholder_text = "e.g. Module1.vg"
	_new_vg_edit.custom_minimum_size.x = 260
	_new_vg_dialog = ConfirmationDialog.new()
	_new_vg_dialog.title = "New VG Script"
	_new_vg_dialog.add_child(_new_vg_edit)
	_new_vg_dialog.confirmed.connect(_on_new_vg_confirmed)
	add_child(_new_vg_dialog)

	# ── New GDScript dialog ───────────────────────────────────────────────────
	_new_gd_edit = LineEdit.new()
	_new_gd_edit.placeholder_text = "e.g. my_script.gd"
	_new_gd_edit.custom_minimum_size.x = 260
	_new_gd_dialog = ConfirmationDialog.new()
	_new_gd_dialog.title = "New GDScript"
	_new_gd_dialog.add_child(_new_gd_edit)
	_new_gd_dialog.confirmed.connect(_on_new_gd_confirmed)
	add_child(_new_gd_dialog)

	# ── New Folder dialog ─────────────────────────────────────────────────────
	_new_folder_edit = LineEdit.new()
	_new_folder_edit.placeholder_text = "e.g. scripts"
	_new_folder_edit.custom_minimum_size.x = 260
	_new_folder_dialog = ConfirmationDialog.new()
	_new_folder_dialog.title = "New Folder"
	_new_folder_dialog.add_child(_new_folder_edit)
	_new_folder_dialog.confirmed.connect(_on_new_folder_confirmed)
	add_child(_new_folder_dialog)

	# ── Delete confirm dialog ─────────────────────────────────────────────────
	_confirm_delete_dialog = ConfirmationDialog.new()
	_confirm_delete_dialog.title = "Confirm Delete"
	_confirm_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_confirm_delete_dialog)

# =============================================================================
# SETUP
# =============================================================================

func setup(plugin: EditorPlugin) -> void:
	editor_plugin = plugin
	# Auto-refresh when the editor filesystem changes (files added/deleted/renamed)
	var efs: EditorFileSystem = editor_plugin.get_editor_interface().get_resource_filesystem()
	if efs and not efs.filesystem_changed.is_connected(refresh):
		efs.filesystem_changed.connect(refresh)
	# Auto-refresh on plugin-driven asset writes too. Godot's EFS only
	# rescans on its own polling cadence, so a sprite save coming from a
	# VG plugin can take seconds to show up. Listening to VGAssetBus
	# closes that gap — the tree updates the moment any plugin announces
	# saved/deleted/renamed/invalidated.
	var bus = preload("res://addons/visual_gasic/vg_asset_bus.gd").get_instance()
	if not bus.asset_saved.is_connected(_on_bus_asset_event):
		bus.asset_saved.connect(_on_bus_asset_event)
		bus.asset_deleted.connect(_on_bus_asset_event)
		bus.asset_invalidated.connect(_on_bus_asset_invalidated)
		bus.asset_renamed.connect(_on_bus_asset_renamed)
	# Populate lazily — refresh() is called in _show_code_view() when panel is made visible


## Bus listeners — collapse all asset events to a single deferred refresh
## so a burst of saves (e.g. AGCK exporting 16 sprite frames) doesn't
## thrash the tree. call_deferred coalesces multiple invocations in the
## same frame down to one rebuild.
func _on_bus_asset_event(path: String, _by_plugin_id: String) -> void:
	# A successful save clears any "externally changed" badge on this
	# file (the user has reconciled, one way or another).
	_externally_changed.erase(path)
	if is_inside_tree():
		call_deferred("refresh")


## File mtime diverged from what the IDE last wrote — flag it so the
## tree can render a ⚠ badge and refresh.
func _on_bus_asset_invalidated(path: String, _by_plugin_id: String) -> void:
	_externally_changed[path] = true
	if is_inside_tree():
		call_deferred("refresh")


func _on_bus_asset_renamed(old_path: String, _new_path: String, _by_plugin_id: String) -> void:
	_externally_changed.erase(old_path)
	if is_inside_tree():
		call_deferred("refresh")

# =============================================================================
# REFRESH / POPULATE
# =============================================================================

## Rebuild the tree from the project's res:// directory.
func refresh() -> void:
	if not is_inside_tree():
		return
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	root.set_text(0, "res://")
	var filter: String = _filter_edit.text.to_lower() if is_instance_valid(_filter_edit) else ""
	_populate_dir(_tree, root, "res://", filter)

func _populate_dir(tree: Tree, parent: TreeItem, dir_path: String, filter: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	# Collect dirs and files separately so dirs come first
	var dirs: Array  = []
	var files: Array = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			if dir.current_is_dir():
				dirs.append(entry)
			else:
				files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	dirs.sort()
	files.sort()

	for d in dirs:
		var full: String = dir_path.path_join(d)
		# If filtering, only include dirs that contain matching files
		if filter.is_empty() or _dir_has_match(full, filter):
			var item: TreeItem = tree.create_item(parent)
			item.set_text(0, FOLDER_ICON + " " + d)
			item.set_metadata(0, full + "/")
			item.set_selectable(0, true)
			item.collapsed = not filter.is_empty()  # expand when filtering
			_populate_dir(tree, item, full, filter)

	for f in files:
		if filter.is_empty() or filter in f.to_lower():
			var item: TreeItem = tree.create_item(parent)
			var ext: String = f.get_extension().to_lower()
			var icon: String = FILE_ICONS.get(ext, FILE_DEFAULT)
			var full_path: String = dir_path.path_join(f)
			# Prepend ⚠ if the file changed on disk after the IDE last
			# saved/opened it. The reload prompt covers the action;
			# this is a passive at-a-glance indicator.
			var badge: String = "⚠ " if _externally_changed.has(full_path) else ""
			item.set_text(0, badge + icon + " " + f)
			if not badge.is_empty():
				item.set_tooltip_text(0, "%s\n\nThis file was modified outside the IDE." % full_path)
			item.set_metadata(0, full_path)
			item.set_selectable(0, true)

## Returns true if dir_path (recursively) contains a file matching filter.
func _dir_has_match(dir_path: String, filter: String) -> bool:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			if dir.current_is_dir():
				if _dir_has_match(dir_path.path_join(entry), filter):
					dir.list_dir_end()
					return true
			elif filter in entry.to_lower():
				dir.list_dir_end()
				return true
		entry = dir.get_next()
	dir.list_dir_end()
	return false

# =============================================================================
# DRAG AND DROP
# =============================================================================

func _get_drag_data(at_position: Vector2) -> Variant:
	var item: TreeItem = _tree.get_item_at_position(at_position)
	if not item:
		return null
	var path: String = item.get_metadata(0)
	if path.ends_with("/"):
		return null  # Don't drag folders
	# Godot editor drag format for files
	return {"type": "files", "files": [path]}

# =============================================================================
# EVENT HANDLERS — Tree
# =============================================================================

func _on_item_activated() -> void:
	var item: TreeItem = _tree.get_selected()
	if not item:
		return
	var path: String = item.get_metadata(0)
	if path.ends_with("/"):
		item.collapsed = not item.collapsed
		return
	_open_file(path)

func _on_tree_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if not mb or mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
		return
	var item: TreeItem = _tree.get_item_at_position(mb.position)
	if not item:
		return
	get_viewport().set_input_as_handled()          # prevent propagation
	_tree.set_selected(item, 0)                    # ensure item is selected
	_right_clicked_path = item.get_metadata(0)
	_update_menu_for_path(_right_clicked_path)
	# DisplayServer gives true screen coords; popup(Rect2i) expects screen coords.
	var spos := DisplayServer.mouse_get_position()
	_context_menu.reset_size()                     # size to content before showing
	_context_menu.popup(Rect2i(spos, Vector2i.ZERO))


## Enable/disable context-menu items based on whether the target is a file or folder.
func _update_menu_for_path(path: String) -> void:
	var is_folder := path.ends_with("/")
	_context_menu.set_item_disabled(_context_menu.get_item_index(MENU_OPEN_VG_IDE),   is_folder)
	_context_menu.set_item_disabled(_context_menu.get_item_index(MENU_OPEN_EXTERNAL), is_folder)
	_context_menu.set_item_disabled(_context_menu.get_item_index(MENU_OPEN_HEX),      is_folder)
	_context_menu.set_item_disabled(_context_menu.get_item_index(MENU_COPY_UID),      is_folder)
	_context_menu.set_item_disabled(_context_menu.get_item_index(MENU_DUPLICATE),     is_folder)

# =============================================================================
# EVENT HANDLERS — Context Menu
# =============================================================================

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		MENU_OPEN_VG_IDE:
			_open_file(_right_clicked_path)

		MENU_OPEN_EXTERNAL:
			var abs := ProjectSettings.globalize_path(_right_clicked_path)
			OS.shell_open(abs)

		MENU_OPEN_HEX:
			open_hex_editor_requested.emit(_right_clicked_path)

		MENU_COPY_PATH:
			DisplayServer.clipboard_set(_right_clicked_path)

		MENU_COPY_UID:
			_copy_uid(_right_clicked_path)

		MENU_SHOW_IN_FM:
			var abs := ProjectSettings.globalize_path(_right_clicked_path)
			if not _right_clicked_path.ends_with("/"):
				abs = abs.get_base_dir()
			OS.shell_open(abs)

		MENU_RENAME:
			_rename_edit.text = _right_clicked_path.rstrip("/").get_file()
			_rename_edit.select_all()
			_rename_dialog.popup_centered()

		MENU_DUPLICATE:
			_duplicate_file(_right_clicked_path)

		MENU_NEW_VG:
			_new_vg_edit.text = ""
			_new_vg_dialog.popup_centered()

		MENU_NEW_GD:
			_new_gd_edit.text = ""
			_new_gd_dialog.popup_centered()

		MENU_NEW_FOLDER:
			_new_folder_edit.text = ""
			_new_folder_dialog.popup_centered()

		MENU_DELETE:
			var label := _right_clicked_path.rstrip("/").get_file()
			_confirm_delete_dialog.dialog_text = \
				"Move '%s' to Trash?\n\nThis can be undone via your system's Trash." % label
			_confirm_delete_dialog.popup_centered()


# =============================================================================
# EVENT HANDLERS — Dialogs
# =============================================================================

func _on_rename_confirmed() -> void:
	var new_name := _rename_edit.text.strip_edges()
	if new_name.is_empty():
		return
	var old_path := _right_clicked_path.rstrip("/")
	var da := DirAccess.open(old_path.get_base_dir())
	if da:
		var err := da.rename(old_path.get_file(), new_name)
		if err != OK:
			push_warning("VGFileBrowser: rename failed (%d) %s → %s" % [err, old_path.get_file(), new_name])
		else:
			_scan()


func _on_new_vg_confirmed() -> void:
	var fname := _new_vg_edit.text.strip_edges()
	if fname.is_empty():
		return
	if not fname.ends_with(".vg"):
		fname += ".vg"
	var stem   := fname.get_basename()
	var new_path := _context_parent_dir().path_join(fname)
	var template := 'Attribute VB_Name = "%s"\n\nSub Main()\n\nEnd Sub\n' % stem
	_write_new_file(new_path, template)


func _on_new_gd_confirmed() -> void:
	var fname := _new_gd_edit.text.strip_edges()
	if fname.is_empty():
		return
	if not fname.ends_with(".gd"):
		fname += ".gd"
	var new_path := _context_parent_dir().path_join(fname)
	var template := "extends Node\n\n\nfunc _ready() -> void:\n\tpass\n"
	_write_new_file(new_path, template)


func _on_new_folder_confirmed() -> void:
	var dname := _new_folder_edit.text.strip_edges()
	if dname.is_empty():
		return
	var new_path := _context_parent_dir().path_join(dname)
	var err := DirAccess.make_dir_absolute(ProjectSettings.globalize_path(new_path))
	if err != OK:
		push_warning("VGFileBrowser: mkdir failed (%d) %s" % [err, new_path])
	else:
		_scan()


func _on_delete_confirmed() -> void:
	var path := _right_clicked_path.rstrip("/")
	var abs  := ProjectSettings.globalize_path(path)
	var err  := OS.move_to_trash(abs)
	if err != OK:
		push_warning("VGFileBrowser: delete failed (%d) %s" % [err, path])
	else:
		_scan()


# =============================================================================
# EVENT HANDLERS — Filter
# =============================================================================

func _on_filter_changed(_text: String) -> void:
	refresh()


# =============================================================================
# HELPERS
# =============================================================================

## Returns the directory that "contains" the right-clicked item.
func _context_parent_dir() -> String:
	if _right_clicked_path.ends_with("/"):
		return _right_clicked_path.rstrip("/")
	return _right_clicked_path.get_base_dir()


## Write text content to a new project file and trigger a filesystem scan.
func _write_new_file(res_path: String, content: String) -> void:
	var fa := FileAccess.open(res_path, FileAccess.WRITE)
	if fa:
		fa.store_string(content)
		fa.close()
		_scan()
	else:
		push_warning("VGFileBrowser: could not create '%s'" % res_path)


## Duplicate a file with a _copy suffix, handling name collisions.
func _duplicate_file(path: String) -> void:
	var src := path.rstrip("/")
	var ext  := src.get_extension()
	var stem := src.get_basename().get_file()
	var parent := src.get_base_dir()
	var counter := 0
	var new_name: String
	var dst: String
	while true:
		new_name = stem + "_copy" + ("" if counter == 0 else str(counter))
		if not ext.is_empty():
			new_name += "." + ext
		dst = parent.path_join(new_name)
		if not FileAccess.file_exists(dst):
			break
		counter += 1
	# Copy bytes
	var src_fa := FileAccess.open(src, FileAccess.READ)
	if not src_fa:
		push_warning("VGFileBrowser: cannot read source for duplicate: %s" % src)
		return
	var data := src_fa.get_buffer(src_fa.get_length())
	src_fa.close()
	var dst_fa := FileAccess.open(dst, FileAccess.WRITE)
	if not dst_fa:
		push_warning("VGFileBrowser: cannot create duplicate: %s" % dst)
		return
	dst_fa.store_buffer(data)
	dst_fa.close()
	_scan()


## Copy the resource UID to the clipboard.  Reads the .uid sidecar if present,
## otherwise asks ResourceLoader for the UID.
func _copy_uid(res_path: String) -> void:
	var uid_path := res_path + ".uid"
	if FileAccess.file_exists(uid_path):
		var fa := FileAccess.open(uid_path, FileAccess.READ)
		if fa:
			DisplayServer.clipboard_set(fa.get_as_text().strip_edges())
			fa.close()
			return
	# Fallback: ResourceLoader
	var rid := ResourceLoader.get_resource_uid(res_path)
	if rid != ResourceUID.INVALID_ID:
		DisplayServer.clipboard_set(ResourceUID.id_to_text(rid))
	else:
		push_warning("VGFileBrowser: no UID found for '%s'" % res_path)


## Trigger Godot's filesystem scan (keeps resource database in sync).
func _scan() -> void:
	if is_instance_valid(editor_plugin):
		editor_plugin.get_editor_interface().get_resource_filesystem().scan()


## Emit the open request signal — the parent plugin handles routing.
func _open_file(path: String) -> void:
	if path.ends_with("/"):
		return
	file_open_requested.emit(path)
