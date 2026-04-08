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

	# ── Pre-launch error gate ──────────────────────────────────────
	if not _pre_launch_validate():
		return

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
	"""Validate all .vg files in the project using the C++ parser/linter"""
	if not _editor_plugin:
		push_error("FormPreviewToolbar: No editor plugin set")
		return

	print("VisualGasic: Building project — validating .vg files…")

	var total_errors := 0
	var total_warnings := 0
	var files_checked := 0
	var error_messages: Array[String] = []

	# Check if the C++ validation API is available
	var has_vg_validate := ClassDB.class_exists(&"VisualGasicLanguage") and ClassDB.class_has_method(&"VisualGasicLanguage", &"vg_validate_code")

	# Scan for all .vg files
	var vg_files = _find_vg_files("res://")

	for vg_path in vg_files:
		files_checked += 1
		var file = FileAccess.open(vg_path, FileAccess.READ)
		if not file:
			total_errors += 1
			error_messages.append("Cannot open: " + vg_path)
			continue

		var content = file.get_as_text()
		file.close()

		if has_vg_validate:
			# Use the C++ parser via the static ClassDB-bound method
			var result: Dictionary = VisualGasicLanguage.vg_validate_code(content, vg_path)
			var file_errors: Array = result.get("errors", [])
			var file_warnings: Array = result.get("warnings", [])
			for err in file_errors:
				total_errors += 1
				var line_num: int = err.get("line", 0)
				var msg: String = err.get("message", "Unknown error")
				error_messages.append("%s(%d): ✖ %s" % [vg_path, line_num, msg])
			for warn in file_warnings:
				total_warnings += 1
				var line_num: int = warn.get("line", 0)
				var msg: String = warn.get("message", "Unknown warning")
				error_messages.append("%s(%d): ⚠ %s" % [vg_path, line_num, msg])
		else:
			# Fallback: try reload and check error code
			var script = load(vg_path) as Script
			if script and script.reload() != OK:
				total_errors += 1
				error_messages.append("%s: Parse error (details in Output)" % vg_path)

	# Route results to the Errors tab if the embedded code editor is available
	if "_embedded_code_editor" in _editor_plugin:
		var ece = _editor_plugin._embedded_code_editor
		if ece and is_instance_valid(ece):
			# Log build results to the Output tab
			if ece.has_method("append_output"):
				ece.append_output("")
				ece.append_output("═══ Build Results ═══")
				if error_messages.is_empty():
					ece.append_output("Build succeeded — %d files checked, no issues found ✓" % files_checked)
				else:
					ece.append_output("Build: %d files, %d errors, %d warnings" % [files_checked, total_errors, total_warnings])
					for msg in error_messages:
						ece.append_output("  " + msg)
			# Switch to the Errors tab if there are problems
			if total_errors > 0 and ece.has_method("focus_errors"):
				ece.focus_errors()

	# Console summary
	if total_errors == 0 and total_warnings == 0:
		print("VisualGasic: Build succeeded — %d files checked, no issues found ✅" % files_checked)
	else:
		print("VisualGasic: Build completed — %d files, %d errors, %d warnings" % [files_checked, total_errors, total_warnings])
		for msg in error_messages:
			print("  " + msg)

	print("VisualGasic: Build complete.")

func _pre_launch_validate() -> bool:
	"""Pre-launch error gate — validates the current .vg file before running.
	Returns true if OK to launch, false if errors block launch."""
	# Get the embedded code editor
	if not "_embedded_code_editor" in _editor_plugin:
		return true  # No code editor → nothing to validate
	var ece = _editor_plugin._embedded_code_editor
	if not ece or not is_instance_valid(ece):
		return true
	if not ece.has_method("validate_code"):
		return true

	var is_valid: bool = ece.validate_code()
	if is_valid:
		return true

	# Errors found — collect the first few for the dialog message
	var err_count: int = 0
	var first_errors: Array[String] = []
	if ece.has_method("get_current_errors"):
		var errors: Array = ece.get_current_errors()
		err_count = errors.size()
		for i in mini(errors.size(), 5):
			var e: Dictionary = errors[i]
			var line_num: int = e.get("line", 0)
			var msg: String = e.get("message", "Unknown error")
			first_errors.append("Line %d: %s" % [line_num, msg])

	# Build the VB6-style error message
	var dialog_text := "There %s %d compile error%s. Please fix %s before running.\n\n" % [
		"is" if err_count == 1 else "are",
		err_count,
		"" if err_count == 1 else "s",
		"it" if err_count == 1 else "them",
	]
	for line_text in first_errors:
		dialog_text += "  ✖ " + line_text + "\n"
	if err_count > 5:
		dialog_text += "  … and %d more\n" % (err_count - 5)

	# Show a blocking dialog
	var dlg := AcceptDialog.new()
	dlg.title = "VisualGasic — Compile Error"
	dlg.dialog_text = dialog_text
	dlg.ok_button_text = "OK"
	dlg.min_size = Vector2i(460, 200)
	# Focus the Errors tab when the dialog is dismissed
	dlg.confirmed.connect(func():
		if ece.has_method("focus_errors"):
			ece.focus_errors()
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	EditorInterface.get_base_control().add_child(dlg)
	dlg.popup_centered()

	print("VisualGasic: Launch blocked — %d compile error(s)" % err_count)
	return false

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

	# ── Pre-launch error gate ──────────────────────────────────────
	if not _pre_launch_validate():
		return

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
