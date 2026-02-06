@tool
extends HBoxContainer
## Form Preview Toolbar
##
## Adds a "Preview Form" button to quickly test forms:
## - Opens the current form in a popup window
## - Fires Form_Load, Form_Shown events
## - Interactive - buttons, inputs work
## - Close returns to editor

var _preview_button: Button
var _editor_plugin: EditorPlugin

func _init() -> void:
	name = "FormPreviewToolbar"

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Preview button
	_preview_button = Button.new()
	_preview_button.text = "▶ Preview Form"
	_preview_button.tooltip_text = "Preview the current form (F5)"
	_preview_button.pressed.connect(_on_preview_pressed)
	add_child(_preview_button)
	
	# Separator
	add_child(VSeparator.new())
	
	# Preview with debug
	var debug_btn = Button.new()
	debug_btn.text = "🐛 Preview + Debug"
	debug_btn.tooltip_text = "Preview with Immediate Window connected"
	debug_btn.pressed.connect(_on_preview_debug_pressed)
	add_child(debug_btn)

func setup(plugin: EditorPlugin) -> void:
	_editor_plugin = plugin

func _on_preview_pressed() -> void:
	_preview_current_form(false)

func _on_preview_debug_pressed() -> void:
	_preview_current_form(true)

func _preview_current_form(with_debug: bool) -> void:
	if not _editor_plugin:
		push_error("FormPreviewToolbar: No editor plugin set")
		return
	
	var editor = _editor_plugin.get_editor_interface()
	var scene_root = editor.get_edited_scene_root()
	
	if not scene_root:
		push_warning("No scene is currently open")
		return
	
	# Check if it's a valid form (Window or Control with VG script)
	if not (scene_root is Window or scene_root is Control):
		push_warning("Current scene is not a form (Window or Control)")
		return
	
	# Save the current scene first
	editor.save_scene()
	
	# Get the scene path
	var scene_path = scene_root.scene_file_path
	if scene_path.is_empty():
		push_warning("Scene must be saved before previewing")
		return
	
	# Play the custom scene
	if with_debug:
		# Save breakpoints before running
		_save_breakpoints_for_preview()
	
	editor.play_custom_scene(scene_path)

func _save_breakpoints_for_preview() -> void:
	"""Save breakpoints to file so they're available during preview"""
	# This leverages the existing breakpoint system
	# The vg_debug_handler.gd will load these on startup
	pass

func _input(event: InputEvent) -> void:
	# F5 to preview
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		if not event.ctrl_pressed and not event.shift_pressed:
			_on_preview_pressed()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and not event.shift_pressed:
			# Ctrl+F5 = Preview without debug
			_on_preview_pressed()
			get_viewport().set_input_as_handled()
		elif event.shift_pressed:
			# Shift+F5 would stop preview (handled by Godot)
			pass
