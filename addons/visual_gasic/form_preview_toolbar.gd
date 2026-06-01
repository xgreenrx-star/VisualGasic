@tool
extends HBoxContainer
## Form Preview & Build Toolbar
##
## Unified ▶ Play toolbar — one button, dropdown menu with every run/build
## variant. Replaces the older four-button layout (Preview, Preview+Debug,
## Build, Run Project) that was spread across two rows and confused users.
##
## Entries:
##   • Run Current Scene          (F5)
##   • Run Main Scene             (Ctrl+F5)
##   • Preview Current Form       (Shift+F5)   — form-designer-aware variant
##   • Preview + Debug            (Shift+Ctrl+F5)
##   • Build (validate .vg files)
##
## Plugins can register additional actions into the menu via add_menu_item().
## Working Nodes, for example, adds "Run Graph (2D)" and "Run Graph (3D)"
## here once it's loaded, instead of putting its own ▶ buttons in the graph
## panel toolbar.

# MenuButton exposing every run/build variant. A single visible control so
# the user always knows where ▶ lives, regardless of which dock they're in.
var _play_menu: MenuButton
var _stop_button: Button  # future: hook to EditorInterface.stop_playing_scene()
var _editor_plugin: EditorPlugin
var _preview_window: Window = null

# Enum-like ids for the popup entries. Kept as ints so external plugins can
# register starting from PLUGIN_ACTION_BASE without clashing with builtins.
const ACT_RUN_CURRENT   := 100
const ACT_RUN_MAIN      := 101
const ACT_PREVIEW_FORM  := 102
const ACT_PREVIEW_DEBUG := 103
const ACT_BUILD         := 104
const PLUGIN_ACTION_BASE := 1000

# Plugin-registered entries: id → Callable. Looked up from _on_menu_item().
var _plugin_actions: Dictionary = {}
var _next_plugin_id: int = PLUGIN_ACTION_BASE

func _init() -> void:
	name = "FormPreviewToolbar"

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Idempotent: add_menu_item() may call this before _ready() to allow
	# plugin registration during their own init. Don't build twice or two
	# ▶ Play MenuButtons end up in the toolbar.
	if _play_menu != null and is_instance_valid(_play_menu):
		return
	_play_menu = MenuButton.new()
	_play_menu.text = "▶ Play"
	_play_menu.tooltip_text = "Run / preview / build (F5 for primary action)"
	_play_menu.flat = false
	_play_menu.focus_mode = Control.FOCUS_NONE
	var popup := _play_menu.get_popup()
	popup.clear()
	# Force dark text — the popup background is light/white so the
	# inherited theme's white font color renders unreadable except on
	# hover. Lock all states to near-black for legibility.
	var _dark := Color(0.05, 0.05, 0.05)
	popup.add_theme_color_override("font_color", _dark)
	popup.add_theme_color_override("font_hover_color", _dark)
	popup.add_theme_color_override("font_focus_color", _dark)
	popup.add_theme_color_override("font_accelerator_color", Color(0.25, 0.25, 0.25))
	popup.add_theme_color_override("font_separator_color", Color(0.4, 0.4, 0.4))
	popup.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	# F5 is the default primary action; users can still click the menu
	# for the others. Shortcuts are labelled in the menu entry text so
	# the user sees them without opening a help page.
	popup.add_item("Run Current Scene     F5",            ACT_RUN_CURRENT)
	popup.add_item("Run Main Scene        Ctrl+F5",       ACT_RUN_MAIN)
	popup.add_separator()
	popup.add_item("Preview Current Form  Shift+F5",      ACT_PREVIEW_FORM)
	popup.add_item("Preview + Debug       Shift+Ctrl+F5", ACT_PREVIEW_DEBUG)
	popup.add_separator()
	popup.add_item("Build (validate .vg)",                ACT_BUILD)
	popup.id_pressed.connect(_on_menu_item)
	add_child(_play_menu)


## Public API — plugins can drop their own ▶-style actions into this menu.
## Returns the id assigned (for later removal via remove_menu_item).
func add_menu_item(label: String, callback: Callable) -> int:
	var id := _next_plugin_id
	_next_plugin_id += 1
	_plugin_actions[id] = callback
	# Plugin may register before _ready has constructed _play_menu
	# (ready-order isn't deterministic across sibling plugins). Lazily
	# build the menu now so we can insert the item immediately.
	if _play_menu == null:
		_build_ui()
	var popup := _play_menu.get_popup()
	# Insert a separator above the first plugin entry so built-ins stay
	# visually grouped at the top.
	if _plugin_actions.size() == 1:
		popup.add_separator()
	popup.add_item(label, id)
	return id


func remove_menu_item(id: int) -> void:
	if not _plugin_actions.has(id):
		return
	_plugin_actions.erase(id)
	if _play_menu == null:
		return
	var popup := _play_menu.get_popup()
	var idx := popup.get_item_index(id)
	if idx >= 0:
		popup.remove_item(idx)



func _on_menu_item(id: int) -> void:
	match id:
		ACT_RUN_CURRENT:   _run_project()
		ACT_RUN_MAIN:      _run_main_scene()
		ACT_PREVIEW_FORM:  _preview_current_form(false)
		ACT_PREVIEW_DEBUG: _preview_current_form(true)
		ACT_BUILD:         _build_project()
		_:
			var cb = _plugin_actions.get(id)
			if cb is Callable and cb.is_valid():
				cb.call()


func setup(plugin: EditorPlugin) -> void:
	_editor_plugin = plugin


# ── Run Main Scene — respects application/run/main_scene ───────────────────
func _run_main_scene() -> void:
	if not _editor_plugin:
		push_error("FormPreviewToolbar: No editor plugin set")
		return
	var editor = _editor_plugin.get_editor_interface()
	editor.save_all_scenes()
	# Always defer to the unified _run_project() so the form-designer-open-
	# form fallback is used.  Without this, hitting Play in a project with
	# no main_scene set silently does nothing.
	_run_project()


func _preview_current_form(with_debug: bool) -> void:
	if not _editor_plugin:
		push_error("FormPreviewToolbar: No editor plugin set")
		return

	var editor = _editor_plugin.get_editor_interface()

	# Save all scenes / scripts so the latest code is on disk
	editor.save_all_scenes()

	# Always save breakpoints so the game process can check them at startup
	_save_breakpoints_for_preview()

	# Find the scene to run: currently edited scene first
	var scene_path := ""
	var scene_root = editor.get_edited_scene_root()
	if scene_root and not scene_root.scene_file_path.is_empty():
		scene_path = scene_root.scene_file_path
	else:
		# Fallback: ask the form designer
		var designer = _editor_plugin.get("_form_designer") if "_form_designer" in _editor_plugin else null
		if designer and designer.has_method("get_form_scene_path"):
			scene_path = designer.get_form_scene_path()

	if scene_path.is_empty():
		push_warning("No form is open — open a form first, then click Preview.")
		return

	print("VisualGasic: Running form preview: ", scene_path)
	editor.play_custom_scene(scene_path)

func _build_project() -> void:
	"""Validate all .vg files in the project by scanning for syntax issues"""
	if not _editor_plugin:
		push_error("FormPreviewToolbar: No editor plugin set")
		return
	
	print("VisualGasic: Building project - validating .vg files...")
	
	var errors = 0
	var warnings = 0
	var files_checked = 0
	var error_messages: Array[String] = []
	
	# Scan for all .vg files
	var vg_files = _find_vg_files("res://")
	
	for vg_path in vg_files:
		files_checked += 1
		var file = FileAccess.open(vg_path, FileAccess.READ)
		if not file:
			errors += 1
			error_messages.append("Cannot open: " + vg_path)
			continue
		
		var content = file.get_as_text()
		file.close()
		
		# Basic validation checks
		var line_num = 0
		var open_blocks: Array[String] = []
		
		for line in content.split("\n"):
			line_num += 1
			var trimmed = line.strip_edges()
			var upper = trimmed.to_upper()
			
			# Track block openings
			if upper.begins_with("SUB ") and not upper.begins_with("SUB = "):
				open_blocks.append("Sub")
			elif upper.begins_with("FUNCTION "):
				open_blocks.append("Function")
			elif upper.begins_with("IF ") and upper.ends_with(" THEN") and not trimmed.contains(":"):
				# Multi-line If (not single-line)
				open_blocks.append("If")
			elif upper.begins_with("FOR ") or upper.begins_with("FOR EACH "):
				open_blocks.append("For")
			elif upper.begins_with("DO ") or upper == "DO":
				open_blocks.append("Do")
			elif upper.begins_with("SELECT CASE"):
				open_blocks.append("Select")
			elif upper.begins_with("WHILE ") and not upper.begins_with("WHILE WEND"):
				open_blocks.append("While")
			
			# Track block closings
			elif upper == "END SUB":
				if open_blocks.size() > 0 and open_blocks[-1] == "Sub":
					open_blocks.pop_back()
			elif upper == "END FUNCTION":
				if open_blocks.size() > 0 and open_blocks[-1] == "Function":
					open_blocks.pop_back()
			elif upper == "END IF":
				if open_blocks.size() > 0 and open_blocks[-1] == "If":
					open_blocks.pop_back()
			elif upper.begins_with("NEXT"):
				if open_blocks.size() > 0 and open_blocks[-1] == "For":
					open_blocks.pop_back()
			elif upper == "LOOP" or upper.begins_with("LOOP "):
				if open_blocks.size() > 0 and open_blocks[-1] == "Do":
					open_blocks.pop_back()
			elif upper == "END SELECT":
				if open_blocks.size() > 0 and open_blocks[-1] == "Select":
					open_blocks.pop_back()
			elif upper == "WEND":
				if open_blocks.size() > 0 and open_blocks[-1] == "While":
					open_blocks.pop_back()
		
		# Check for unclosed blocks
		if open_blocks.size() > 0:
			warnings += 1
			for block in open_blocks:
				error_messages.append("%s: Possibly unclosed '%s' block" % [vg_path, block])
	
	# Print build results
	if errors == 0 and warnings == 0:
		print("VisualGasic: Build succeeded - %d files checked, no issues found ✅" % files_checked)
	else:
		print("VisualGasic: Build completed - %d files, %d errors, %d warnings" % [files_checked, errors, warnings])
		for msg in error_messages:
			print("  ⚠ " + msg)
	
	print("VisualGasic: Build complete.")

func _find_vg_files(dir_path: String) -> Array[String]:
	"""Recursively find all .vg files in a directory"""
	var result: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if not dir:
		return result
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with(".") and file_name != "addons":
				result.append_array(_find_vg_files(full_path))
		elif file_name.ends_with(".vg"):
			result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return result

func _run_project() -> void:
	"""Run the project using the main scene or startup form"""
	if not _editor_plugin:
		push_error("FormPreviewToolbar: No editor plugin set")
		return

	var editor = _editor_plugin.get_editor_interface()

	# Save all open scenes first
	editor.save_all_scenes()

	# Flush the embedded code editor's buffer to disk so the running game
	# uses the latest edits, but keep the editor's dirty flag intact so
	# Ctrl+S / File→Save remains the only formal "save" action.
	if _editor_plugin and _editor_plugin.has_method("get"):
		var ece = _editor_plugin.get("_embedded_code_editor")
		if ece and is_instance_valid(ece) and ece.has_method("flush_for_run"):
			ece.flush_for_run()

	# Save breakpoints so the game process can check them at startup
	_save_breakpoints_for_preview()

	# 1. Check for project main scene (explicit setting always wins)
	var main_scene = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene is String and not main_scene.is_empty():
		print("VisualGasic: Running project main scene: ", main_scene)
		editor.play_main_scene()
		return

	# 1b. Prefer the form currently open in the Form Designer (VB6 style:
	# pressing Run from inside a form always launches that form).
	var designer = _editor_plugin.get("_form_designer") if "_form_designer" in _editor_plugin else null
	if designer and is_instance_valid(designer):
		var fd_path := ""
		if designer.has_method("get_form_path"):
			fd_path = str(designer.get_form_path())
		if fd_path.is_empty() and designer.has_method("get_form_scene_path"):
			fd_path = str(designer.get_form_scene_path())
		if not fd_path.is_empty() and FileAccess.file_exists(fd_path):
			print("VisualGasic: Running open form: ", fd_path)
			editor.play_custom_scene(fd_path)
			return

	# 2. Prefer the currently edited scene (the user is looking at it)
	var scene_root = editor.get_edited_scene_root()
	if scene_root and not scene_root.scene_file_path.is_empty():
		print("VisualGasic: Running current scene: ", scene_root.scene_file_path)
		editor.play_custom_scene(scene_root.scene_file_path)
		return

	# 3. Try to find a startup form
	var startup = _find_startup_form()
	if not startup.is_empty():
		print("VisualGasic: Running startup form: ", startup)
		editor.play_custom_scene(startup)
		return

	push_warning("No main scene set and no form is open. Set a main scene in Project Settings.")

func _find_startup_form() -> String:
	"""Find a startup form - looks for Form1.tscn or first .tscn in res://"""
	# Check common VB6-style startup forms
	for candidate in ["res://Form1.tscn", "res://Main.tscn", "res://frmMain.tscn", "res://start_forms/Form1.tscn"]:
		if FileAccess.file_exists(candidate):
			return candidate

	# Scan project tree (root + one level of subdirs) for any .tscn file.
	return _scan_dir_for_tscn("res://", 0)

func _scan_dir_for_tscn(path: String, depth: int) -> String:
	if depth > 2:
		return ""
	var dir := DirAccess.open(path)
	if dir == null:
		return ""
	var subdirs: PackedStringArray = []
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with(".") or entry == ".godot" or entry == "addons":
			continue
		if dir.current_is_dir():
			subdirs.append(path.path_join(entry))
		elif entry.ends_with(".tscn"):
			dir.list_dir_end()
			return path.path_join(entry)
	dir.list_dir_end()
	for sub in subdirs:
		var found := _scan_dir_for_tscn(sub, depth + 1)
		if not found.is_empty():
			return found
	return ""

func _save_breakpoints_for_preview() -> void:
	"""Save breakpoints to file so they're available during preview.
	Collects breakpoints from the embedded VG code editor (primary source)
	and the debugger plugin (ScriptEditor fallback), then writes to a JSON
	file that the C++ runtime reads at game startup."""
	if not _editor_plugin:
		return

	var breakpoints: Dictionary = {}

	# Source 1: Embedded VG code editor — this is where the user actually sets
	# breakpoints (the red dots in the code view). CodeEdit line indices are
	# 0-based; the parser/runtime uses 1-based, so we add 1.
	if "_embedded_code_editor" in _editor_plugin:
		var ece = _editor_plugin._embedded_code_editor
		if ece and is_instance_valid(ece) and ece.has_method("get_file_path") and ece.has_method("get_code_edit"):
			var vg_path: String = ece.get_file_path()
			var code_edit = ece.get_code_edit()
			if not vg_path.is_empty() and code_edit:
				var bp_lines = code_edit.get_breakpointed_lines()
				if not bp_lines.is_empty():
					var lines_array: Array = []
					for line_idx in bp_lines:
						lines_array.append(line_idx + 1)  # 0-based → 1-based
					breakpoints[vg_path] = lines_array

	# Source 2: Debugger plugin (polls ScriptEditor — rarely has .vg entries
	# but merge them in just in case)
	if _editor_plugin.has_method("get_debugger_breakpoints"):
		var dbg_bps: Dictionary = _editor_plugin.get_debugger_breakpoints()
		for path in dbg_bps:
			if not breakpoints.has(path):
				breakpoints[path] = dbg_bps[path]
			else:
				for l in dbg_bps[path]:
					if l not in breakpoints[path]:
						breakpoints[path].append(l)

	# Always write the file (even if empty — clears stale breakpoints)
	var bp_path := "res://.vg_breakpoints.json"
	var f = FileAccess.open(bp_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(breakpoints, "\t"))
		f.close()
		if not breakpoints.is_empty():
			print("VisualGasic: Saved ", breakpoints.size(), " script breakpoint set(s) for debug session")

func _input(event: InputEvent) -> void:
	# Unified F5 family — mirrors the Play menu. Handled here rather than via
	# Shortcut resources because this toolbar is re-parented across dock
	# toggles and its Shortcut would bind to the wrong viewport.
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: InputEventKey = event
	if k.keycode != KEY_F5:
		return
	var ctrl := k.ctrl_pressed
	var shift := k.shift_pressed

	# Plugin-panel-aware dispatch: when a VG plugin view is currently the
	# active center view, let that plugin handle F5 first (e.g. Working
	# Nodes should run the graph, not the whole project). The plugin has
	# the option to report "not handled" by returning false.
	if _dispatch_f5_to_active_plugin(ctrl, shift):
		get_viewport().set_input_as_handled()
		return

	if shift and ctrl:
		_preview_current_form(true)
	elif shift:
		_preview_current_form(false)
	elif ctrl:
		_run_main_scene()
	else:
		_run_project()
	get_viewport().set_input_as_handled()


## Give the currently-active VG plugin first crack at F5. Returns true if
## the plugin handled it. Plugins opt in by implementing `on_play_shortcut`
## (bool ctrl, bool shift) -> bool on their plugin instance.
func _dispatch_f5_to_active_plugin(ctrl: bool, shift: bool) -> bool:
	if _editor_plugin == null or not is_instance_valid(_editor_plugin):
		return false
	if not "_showing_plugin_view" in _editor_plugin:
		return false
	if not _editor_plugin._showing_plugin_view:
		return false
	if not "_vg_plugin_manager" in _editor_plugin:
		return false
	var pm = _editor_plugin._vg_plugin_manager
	if pm == null or not pm.has_method("get_active_plugin_id") or not pm.has_method("get_plugin"):
		return false
	var active_id: String = pm.get_active_plugin_id()
	if active_id.is_empty():
		return false
	var active = pm.get_plugin(active_id)
	if active == null or not active.has_method("on_play_shortcut"):
		return false
	return bool(active.on_play_shortcut(ctrl, shift))
