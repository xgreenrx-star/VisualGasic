@tool
extends HBoxContainer
## Form Preview & Build Toolbar
##
## Provides build and run functionality for VisualGasic projects:
## - Preview Form (F5): Runs the current form scene
## - Preview + Debug: Runs with breakpoints and debug connection
## - Build Project: Validates all .vg files in the project
## - Run Project: Runs the project's main/startup scene
## - Keyboard shortcuts: F5 (run), Ctrl+F5 (run without debug), Shift+F5 (stop)

var _preview_button: Button
var _debug_button: Button
var _build_button: Button
var _run_project_button: Button
var _editor_plugin: EditorPlugin
var _preview_window: Window = null

func _init() -> void:
	name = "FormPreviewToolbar"

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Compact button text — total width target: ~200px (was ~400px)
	_preview_button = Button.new()
	_preview_button.text = "▶ Preview"
	_preview_button.tooltip_text = "Preview current form (F5)"
	_preview_button.pressed.connect(_on_preview_pressed)
	add_child(_preview_button)
	
	_debug_button = Button.new()
	_debug_button.text = "Preview+Debug"
	_debug_button.tooltip_text = "Preview with Immediate Window (Shift+F5)"
	_debug_button.pressed.connect(_on_preview_debug_pressed)
	add_child(_debug_button)
	
	add_child(VSeparator.new())
	
	_build_button = Button.new()
	_build_button.text = "Build"
	_build_button.tooltip_text = "Validate all .vg files"
	_build_button.pressed.connect(_on_build_pressed)
	add_child(_build_button)
	
	_run_project_button = Button.new()
	_run_project_button.text = "▶ Run Project"
	_run_project_button.tooltip_text = "Run main scene (Ctrl+F5)"
	_run_project_button.pressed.connect(_on_run_project_pressed)
	add_child(_run_project_button)

func setup(plugin: EditorPlugin) -> void:
	_editor_plugin = plugin

func _on_preview_pressed() -> void:
	_preview_current_form(false)

func _on_preview_debug_pressed() -> void:
	_preview_current_form(true)

func _on_build_pressed() -> void:
	_build_project()

func _on_run_project_pressed() -> void:
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

	# Save breakpoints so the game process can check them at startup
	_save_breakpoints_for_preview()

	# 1. Check for project main scene (explicit setting always wins)
	var main_scene = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene is String and not main_scene.is_empty():
		print("VisualGasic: Running project main scene: ", main_scene)
		editor.play_main_scene()
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
	
	# Scan for any .tscn file at project root
	var dir = DirAccess.open("res://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				return "res://" + file_name
			file_name = dir.get_next()
		dir.list_dir_end()
	
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
	# F5 to preview current form
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		if not event.ctrl_pressed and not event.shift_pressed:
			_on_preview_pressed()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and not event.shift_pressed:
			# Ctrl+F5 = Run project (without debug)
			_on_run_project_pressed()
			get_viewport().set_input_as_handled()
		elif event.shift_pressed and not event.ctrl_pressed:
			# Shift+F5 would stop preview (handled by Godot)
			pass
