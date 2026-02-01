@tool
extends EditorPlugin

var toolbox
var import_plugin
var immediate_window
var debugger_plugin: EditorDebuggerPlugin
var _script_context_menu: PopupMenu
var _current_code_edit: CodeEdit
var _script_editor_check_timer: Timer

func _enter_tree():
	# Store self for static retrieval
	get_editor_interface().get_base_control().set_meta("visual_gasic_plugin_instance", self)

	# Import Plugin
	import_plugin = preload("res://addons/visual_gasic/frm_import_plugin.gd").new()
	add_import_plugin(import_plugin)
	
	# Debugger Plugin for remote debugging
	var debugger_script = load("res://addons/visual_gasic/vg_debugger_plugin.gd")
	if debugger_script:
		debugger_plugin = debugger_script.new()
		add_debugger_plugin(debugger_plugin)
	
	# Add autoload for game-side debug handler
	if not ProjectSettings.has_setting("autoload/VGDebugHandler"):
		add_autoload_singleton("VGDebugHandler", "res://addons/visual_gasic/vg_debug_handler.gd")
	
	# Immediate Window - Load dynamically to avoid preload issues
	var immediate_window_script = load("res://addons/visual_gasic/immediate_window.gd")
	if immediate_window_script:
		immediate_window = immediate_window_script.new()
		# Pass the debugger plugin reference
		if immediate_window.has_method("set_debugger_plugin"):
			immediate_window.set_debugger_plugin(debugger_plugin)
		add_control_to_bottom_panel(immediate_window, "Immediate")
	else:
		print("Warning: Could not load immediate_window.gd")

	# TEST: Create a simple Label to verify dock mechanism
	toolbox = VBoxContainer.new()
	toolbox.name = "Toolbox"
	var label = Label.new()
	label.text = "Visual Gasic Debug"
	toolbox.add_child(label)
	
	# Import Buttons
	var btn_import_proj = Button.new()
	btn_import_proj.text = "Import VB6 Project..."
	btn_import_proj.pressed.connect(_on_import_vb6_project)
	toolbox.add_child(btn_import_proj)
	
	var btn_import_form = Button.new()
	btn_import_form.text = "Import VB6 Form..."
	btn_import_form.pressed.connect(_on_import_vb6_form)
	toolbox.add_child(btn_import_form)
	
	toolbox.add_child(HSeparator.new())
	
	var btn_new_form = Button.new()
	btn_new_form.text = "New Form"
	btn_new_form.pressed.connect(_on_new_form)
	toolbox.add_child(btn_new_form)
	
	setup_toolbox()

	# HACK: If C++ toolbox is used, stick the buttons inside it or above it?
	# setup_toolbox adds a child. We want our buttons to persist.
	# But C++ toolbox might take up all space.
	# Let's Move buttons to TOP if setup_toolbox added below.
	if toolbox.get_child_count() > 3:
		toolbox.move_child(btn_import_proj, 0)
		toolbox.move_child(btn_import_form, 1)
	
	# Add Code Navigator
	var nav = loading_code_navigator()
	if nav:
		toolbox.add_child(nav)
		nav.setup(self)

	# Add Property Inspector
	var props = loading_inspector()
	if props:
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, props)
		props.setup(self)

	# Setup Dock
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, toolbox)
	print("Manually added Toolbox (GDScript Wrapper) to Dock Left BL")
	
	_post_init()
	_setup_script_editor_context_menu()

	add_tool_menu_item("Import VB6 Form...", Callable(self, "_on_import_vb6_form"))
	add_tool_menu_item("Import VB6 Project...", Callable(self, "_on_import_vb6_project"))
	add_tool_menu_item("Visual Gasic Menu Editor", Callable(self, "_on_menu_editor"))
	add_tool_menu_item("Visual Gasic Project Properties...", Callable(self, "_on_proj_props"))
	add_tool_menu_item("Visual Gasic Object Browser", Callable(self, "_on_obj_browser"))
	add_tool_menu_item("Visual Gasic Tab Order", Callable(self, "_on_tab_order"))

func _exit_tree():
	get_editor_interface().get_base_control().remove_meta("visual_gasic_plugin_instance")
	
	remove_import_plugin(import_plugin)
	import_plugin = null
	
	if debugger_plugin:
		remove_debugger_plugin(debugger_plugin)
		debugger_plugin = null
	
	remove_tool_menu_item("Import VB6 Form...")
	remove_tool_menu_item("Import VB6 Project...")
	remove_tool_menu_item("Visual Gasic Menu Editor")
	remove_tool_menu_item("Visual Gasic Project Properties...")
	remove_tool_menu_item("Visual Gasic Object Browser")
	remove_tool_menu_item("Visual Gasic Tab Order")
	
	if immediate_window:
		remove_control_from_bottom_panel(immediate_window)
		immediate_window.queue_free()
		immediate_window = null
	
	if toolbox:
		remove_control_from_docks(toolbox)
		toolbox.queue_free()
		toolbox = null
	
	# Cleanup script editor context menu
	if _script_editor_check_timer:
		_script_editor_check_timer.stop()
		_script_editor_check_timer.queue_free()
		_script_editor_check_timer = null
	
	if _script_context_menu:
		_script_context_menu.queue_free()
		_script_context_menu = null
		
	if get_editor_interface().get_selection().selection_changed.is_connected(_on_selection_changed):
		get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)

func _on_import_vb6_project():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.vbp ; VB6 Project Files"])
	fd.connect("file_selected", Callable(self, "_do_import_vbp"))
	get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.6)

func _do_import_vbp(path):
	var importer = load("res://addons/visual_gasic/vb6_importer.gd")
	if importer:
		importer.import_project(path)
		get_editor_interface().get_resource_filesystem().scan() # Refresh FileSystem

func _on_import_vb6_form():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.frm ; VB6 Form Files"])
	fd.connect("file_selected", Callable(self, "_do_import_frm"))
	get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.6)

func _do_import_frm(path):
	var importer = load("res://addons/visual_gasic/vb6_importer.gd")
	if !importer:
		print("Importer script not found")
		return

	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://start_forms"): dir.make_dir("res://start_forms")
	if not dir.dir_exists("res://mixed"): dir.make_dir("res://mixed")
		
	var root = Control.new()
	root.name = path.get_file().get_basename()
	
	# Create Scene Root
	var packed_scene = PackedScene.new()
	# Can't pack yet, need node tree
	
	# We want to create it in the currently open scene or a new scene?
	# Let's creating a new scene file.
	
	var code = importer.import_form(path, root, root)
	
	packed_scene.pack(root)
	var save_path = "res://start_forms/" + root.name + ".tscn"
	ResourceSaver.save(packed_scene, save_path)
	print("Saved Scene to " + save_path)
	
	if code != "":
		var bas_path = "res://mixed/" + root.name + ".vg"
		var f = FileAccess.open(bas_path, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		print("Saved Code to " + bas_path)
		
	get_editor_interface().open_scene_from_path(save_path)

func _on_new_form():
	var dlg = load("res://addons/visual_gasic/new_form_dialog.gd").new()
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()
	
	# Wait for user to select template
	var result = await dlg.confirmed
	var template = dlg.get_selected_template()
	dlg.queue_free()
	
	# Create the form based on selected template
	_create_form_from_template(template)

func _attach_script_deferred(scene_path, script_path):
	var root = get_editor_interface().get_edited_scene_root()
	if root and root.scene_file_path == scene_path:
		pass # Logic to attach script handled by inspector or manual attach for now. 
		# We need a proper resource loader for bas to set it effectively.

func _create_form_from_template(template: Dictionary):
	# Generate unique filename first
	var path = "res://Form1.tscn"
	var form_name = "Form1"
	var idx = 1
	while FileAccess.file_exists(path):
		idx += 1
		form_name = "Form" + str(idx)
		path = "res://" + form_name + ".tscn"
	
	# Create the .vg script file FIRST
	var vg_path = path.replace(".tscn", ".vg")
	_create_vg_form_code(vg_path, form_name, template)
	
	# Force reimport so the script is available
	get_editor_interface().get_resource_filesystem().scan()
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Now create the Window node with the VG script attached
	var root = Window.new()
	root.name = form_name
	root.title = form_name
	root.position = Vector2i(10,36)  # Align with canvas origin in editor
	root.size = template.get("size", Vector2(800, 600))
	
	# Add a background panel for visual boundaries and editor resize support
	var bg_panel = Panel.new()
	bg_panel.name = "_FormBackground"
	# Don't use PRESET_FULL_RECT - let the panel have its own size for editor resize
	bg_panel.size = root.size
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Attach the form editor helper script for drag-resize support
	var helper_script = load("res://addons/visual_gasic/form_editor_helper.gd")
	if helper_script:
		bg_panel.set_script(helper_script)
	root.add_child(bg_panel)
	bg_panel.owner = root
	
	# Load and attach the .vg script
	var vg_script = load(vg_path)
	if vg_script:
		root.set_script(vg_script)
		print("VisualGasic: Attached VG script to form: ", vg_path)
	else:
		# Fallback to GDScript base if VG script couldn't load
		var vg_form_base = load("res://addons/visual_gasic/VGFormBase.gd")
		root.set_script(vg_form_base)
		print("VisualGasic: Warning - VG script not found, using VGFormBase.gd")
	
	# The form will handle its own lifecycle and window management
	# User can override Form_Load(), Form_Shown(), etc. in their .vg file
	
	# Add standard controls if specified in template
	if template.get("has_menu", false):
		var menu_bar = MenuBar.new()
		menu_bar.name = "MenuBar"
		menu_bar.anchor_left = 0.0
		menu_bar.anchor_top = 0.0
		menu_bar.anchor_right = 1.0
		menu_bar.anchor_bottom = 0.0
		menu_bar.offset_bottom = 30
		
		root.add_child(menu_bar)
		menu_bar.owner = root
		
		# Add default menus
		var file_menu = PopupMenu.new()
		file_menu.name = "mnuFile"
		file_menu.add_item("New", 0)
		file_menu.add_item("Open", 1)
		file_menu.add_item("Save", 2)
		file_menu.add_separator()
		file_menu.add_item("Exit", 3)
		menu_bar.add_child(file_menu)
		file_menu.owner = root
		menu_bar.set_menu_title(0, "File")
		
		var help_menu = PopupMenu.new()
		help_menu.name = "mnuHelp"
		help_menu.add_item("About", 0)
		menu_bar.add_child(help_menu)
		help_menu.owner = root
		menu_bar.set_menu_title(1, "Help")
	
	# Add controls from template
	for control_data in template.get("controls", []):
		var control = null
		var ctrl_type = control_data.get("type", "Button")
		
		match ctrl_type:
			"Button":
				control = Button.new()
			"Label":
				control = Label.new()
			"TextEdit", "LineEdit":
				control = LineEdit.new()
		
		if control:
			control.name = control_data.get("name", "Control")
			if control.has_method("set_text"):
				control.text = control_data.get("text", "")
			control.position = control_data.get("position", Vector2.ZERO)
			control.size = control_data.get("size", Vector2(100, 30))
			root.add_child(control)
			control.owner = root
	
	# form_name already set at the top of the function
	root.name = form_name
	
	# Save scene (VG script is already attached from above)
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, path)
	print("VisualGasic: Created form at ", path)
	
	# Open the scene
	get_editor_interface().open_scene_from_path(path)

func _create_vg_form_code(path: String, form_name: String, template: Dictionary):
	var f = FileAccess.open(path, FileAccess.WRITE)
	var code = """' """ + form_name + """.vg - WinForms-style Form
' Extends VGFormBase which provides proper Form lifecycle
Option Explicit

' Form-level variables
Dim btnOK As Button
Dim btnCancel As Button
Dim lblTitle As Label

' InitializeComponent - Called by designer (like WinForms)
Sub InitializeComponent()
    ' Set form properties
    Me.Text = \"""" + form_name + """\"
    Me.FormBorderStyle = FormBorderStyleEnum.Sizable
    Me.StartPosition = FormStartPositionEnum.CenterScreen
    Me.size = Vector2(400, 300)
    
    ' Create a title label
    Set lblTitle = Label.new()
    lblTitle.name = "lblTitle"
    lblTitle.text = "Welcome to " + \"""" + form_name + """\"
    lblTitle.position = Vector2(100, 50)
    lblTitle.size = Vector2(200, 30)
    Me.add_child(lblTitle)
    
    ' Create OK button
    Set btnOK = Button.new()
    btnOK.name = "btnOK"
    btnOK.text = "OK"
    btnOK.position = Vector2(200, 220)
    btnOK.size = Vector2(80, 30)
    Me.add_child(btnOK)
    ' Note: Events are auto-wired! VGFormBase will automatically connect
    ' btnOK.pressed to btnOK_Click() if that method exists
    
    ' Create Cancel button
    Set btnCancel = Button.new()
    btnCancel.name = "btnCancel"
    btnCancel.text = "Cancel"
    btnCancel.position = Vector2(290, 220)
    btnCancel.size = Vector2(80, 30)
    Me.add_child(btnCancel)
    ' Events are auto-wired! No need to call .connect()
End Sub

' Form_Load - Called before form is displayed (like WinForms Load event)
Sub Form_Load()
    Print "Form loading..."
    InitializeComponent()
    ' Initialize your data, load settings, etc.
End Sub

' Form_Shown - Called after form becomes visible
Sub Form_Shown()
    Print "Form is now visible"
End Sub

' Form_Closing - Called when form is about to close (can cancel)
Sub Form_Closing(evt)
    ' evt.Cancel = True  ' Uncomment to prevent closing
    Print "Form closing"
End Sub

' Form_Closed - Called after form is closed
Sub Form_Closed()
    Print "Form closed"
End Sub

' Form_Resize - Called when form is resized
Sub Form_Resize()
    ' Reposition controls if needed
End Sub

' ====== Event Handlers ======
' These are automatically wired by VGFormBase based on naming pattern:
' ControlName_EventType (e.g. btnOK_Click, txtName_Change)

Sub btnOK_Click()
    Print "OK button clicked!"
    ' Close the form with OK result
    Me.DialogResult = DialogResultEnum.OK
    Me.Close()
End Sub

Sub btnCancel_Click()
    Print "Cancel button clicked!"
    ' Close the form with Cancel result
    Me.DialogResult = DialogResultEnum.Cancel
    Me.Close()
End Sub
"""
	f.store_string(code)
	f.close()


func _on_menu_editor():
	var selected = get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		push_error("Please select a MenuBar node first")
		return
	
	var menu_bar = selected[0]
	if not menu_bar is MenuBar:
		push_error("Selected node must be a MenuBar")
		return
	
	var dlg = load("res://addons/visual_gasic/menu_editor.gd").new()
	dlg.set_menu_bar(menu_bar)
	dlg.menu_applied.connect(_on_menu_applied.bind(menu_bar))
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

func _on_menu_applied(menu_bar: MenuBar):
	# Force editor to update
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(menu_bar)
	get_editor_interface().edit_node(menu_bar)

func _on_proj_props():
	var dlg = load("res://addons/visual_gasic/project_properties.gd").new()
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

func _on_obj_browser():
	var dlg = load("res://addons/visual_gasic/object_browser.gd").new()
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.popup_centered()

func _on_tab_order():
	var root = get_editor_interface().get_selected_paths() # Wait, get_edited_scene_root()
	var sel = get_editor_interface().get_selection().get_selected_nodes()
	
	var target = null
	if sel.size() > 0:
		target = sel[0]
	else:
		target = get_editor_interface().get_edited_scene_root()
		
	if not target:
		print("Select a container or form to edit tab order.")
		return
		
	var dlg = load("res://addons/visual_gasic/tab_order_editor.gd").new()
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.set_root(target)
	dlg.popup_centered()




func loading_inspector():
	if FileAccess.file_exists("res://addons/visual_gasic/simple_inspector.gd"):
		var s = load("res://addons/visual_gasic/simple_inspector.gd")
		var inst = s.new()
		return inst
	return null

func loading_code_navigator():
	if FileAccess.file_exists("res://addons/visual_gasic/code_navigator.gd"):
		var s = load("res://addons/visual_gasic/code_navigator.gd")
		var inst = s.new()
		return inst
	return null

func _post_init():
	# Register extended components
	register_tool("FlexGrid", "Tree", "Tree", "res://custom_widgets/FlexGrid.tscn")
	register_tool("Shape", "ColorRect", "ColorRect", "res://custom_widgets/Shape.tscn")
	register_tool("Line", "HSeparator", "HSeparator", "res://custom_widgets/Line.tscn")
	register_tool("RichText", "RichTextLabel", "RichTextLabel", "res://custom_widgets/RichText.tscn")
	register_tool("Form", "Panel", "Window", "res://custom_widgets/Form.tscn")
	register_tool("Timer", "Timer", "Timer", "res://custom_widgets/Timer.tscn")
	register_tool("ProgressBar", "ProgressBar", "ProgressBar", "res://custom_widgets/ProgressBar.tscn")
	register_tool("Slider", "HSlider", "HSlider", "res://custom_widgets/Slider.tscn")
	register_tool("Spinner", "SpinBox", "SpinBox", "res://custom_widgets/Spinner.tscn")
	register_tool("Tabs", "TabContainer", "TabContainer", "res://custom_widgets/Tabs.tscn")
	register_tool("Option", "CheckBox", "CheckBox", "res://custom_widgets/Option.tscn")
	register_tool("Memo", "TextEdit", "TextEdit", "res://custom_widgets/Memo.tscn")
	register_tool("CommonDialog", "Control", "FileDialog", "res://custom_widgets/CommonDialog.tscn")
	register_tool("FileDialog", "Control", "FileDialog", "res://custom_widgets/CommonDialog.tscn")
	register_tool("VSlider", "VSlider", "VSlider", "res://custom_widgets/VSlider.tscn")
	register_tool("ColorBtn", "ColorPickerButton", "ColorPickerButton", "res://custom_widgets/ColorBtn.tscn")
	register_tool("Video", "VideoStreamPlayer", "VideoStreamPlayer", "res://custom_widgets/Video.tscn")
	register_tool("ComboBox", "OptionButton", "OptionButton", "res://custom_widgets/OptionButton.tscn")
	register_tool("ListBox", "ItemList", "ItemList", "res://custom_widgets/ItemList.tscn")
	register_tool("Picture", "TextureRect", "TextureRect", "res://custom_widgets/TextureRect.tscn")
	register_tool("Frame", "Panel", "PanelContainer", "res://custom_widgets/Frame.tscn")
	register_tool("Viewport", "SubViewportContainer", "SubViewportContainer", "res://custom_widgets/Viewport.tscn")
	
	# 3D Tools
	var cat3d = "3D"
	register_tool("Box", "MeshInstance3D", "BoxMesh", "res://custom_widgets/3d/Box.tscn", cat3d)
	register_tool("Sphere", "MeshInstance3D", "SphereMesh", "res://custom_widgets/3d/Sphere.tscn", cat3d)
	register_tool("Capsule", "MeshInstance3D", "CapsuleMesh", "res://custom_widgets/3d/Capsule.tscn", cat3d)
	register_tool("Cylinder", "MeshInstance3D", "CylinderMesh", "res://custom_widgets/3d/Cylinder.tscn", cat3d)
	register_tool("Light", "OmniLight3D", "OmniLight3D", "res://custom_widgets/3d/Light.tscn", cat3d)
	register_tool("Camera", "Camera3D", "Camera3D", "res://custom_widgets/3d/Camera.tscn", cat3d)
	register_tool("Text3D", "Label3D", "Label3D", "res://custom_widgets/3d/Text3D.tscn", cat3d)
	register_tool("Sprite3D", "Sprite3D", "Sprite3D", "res://custom_widgets/3d/Sprite3D.tscn", cat3d)
	register_tool("Sound3D", "AudioStreamPlayer3D", "AudioStreamPlayer3D", "res://custom_widgets/3d/Sound3D.tscn", cat3d)
	
	# Connect to screen change signal
	main_screen_changed.connect(_on_main_screen_changed)
	
	# Connect to scene change (tab switch)
	scene_changed.connect(_on_scene_changed)
	
	# Fix nesting behavior by monitoring selection
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

	print("VisualGasic: Initialized. Monitoring nesting & double-click events.")

func _on_scene_changed(scene_root: Node):
	# Auto-refresh navigator when switching scenes
	var nav = _get_navigator()
	if nav:
		nav.refresh_objects()

func _handles(object):
	# Handle input for any Control or Node2D being edited
	return object is Control or object is Node2D

func _forward_canvas_gui_input(event):
	if event is InputEventMouseButton and event.double_click:
		# Support both Left (Standard) and Right (User Request) double clicks
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			var sel = get_editor_interface().get_selection().get_selected_nodes()
			if sel.size() == 1:
				_generate_event_handler(sel[0])
				return true # Consume event
	return false

func _generate_event_handler(node):
	print("VisualGasic: Event Gen Request for " + node.name)
	var sub_suffix = ""
	
	# Mapping (VB6-ish style)
	if node is BaseButton: 
		sub_suffix = "Click"
	elif node is LineEdit:
		sub_suffix = "Change"
	elif node is TextEdit:
		sub_suffix = "Change"
	elif node is ScrollBar:
		sub_suffix = "Change"
	elif node is Slider:
		sub_suffix = "Change"
	else:
		# Fallback
		sub_suffix = "Click"
		
	var root = get_editor_interface().get_edited_scene_root()
	if not root: 
		printerr("VisualGasic: No active scene root. Save the scene first.")
		return
		
	var scene_path = root.scene_file_path
	if scene_path.is_empty():
		printerr("VisualGasic: Scene must be saved to generate code.")
		return
		
	# Assume .vg file is adjacent to scene
	var bas_path = scene_path.get_basename() + ".vg"
	# absolute path for OS shell
	var abs_path = ProjectSettings.globalize_path(bas_path)
	
	print("VisualGasic: Targeting Script " + abs_path)
	
	# Create file if missing
	if not FileAccess.file_exists(bas_path):
		var f = FileAccess.open(bas_path, FileAccess.WRITE)
		# VB6 Form Header Style
		f.store_string("' Visual Gasic Form Script\nOption Explicit\n\n")
		f.close()
		print("VisualGasic: Created new script file.")
		# Trigger filesystem to recognize the file
		get_editor_interface().get_resource_filesystem().scan()

	# Open and Inject via Editor Buffer (to avoid disk reload conflicts)
	_open_and_inject(bas_path, node.name, sub_suffix)

func _open_and_inject(path: String, obj: String, event: String):
	# We rely on async scan, but we can't block here easily.
	_poll_for_inject.call_deferred(path, obj, event, 0)

func _poll_for_inject(path: String, obj: String, event: String, attempts: int):
	# Max retries: 20 * 0.1s = 2 seconds
	if attempts > 20:
		printerr("VisualGasic: Timeout waiting for script resource. Opening externally.")
		OS.shell_open(ProjectSettings.globalize_path(path))
		return
		
	if ResourceLoader.exists(path):
		var res = load(path)
		if res:
			# Attach to Scene Root (Form) to act as Code-Behind
			var root = get_editor_interface().get_edited_scene_root()
			if root:
				# Only attach if no script is present or it's the same script
				if root.get_script() == null:
					root.set_script(res)
					print("VisualGasic: Attached " + path.get_file() + " to Form (" + root.name + ").")
			
			# Open in Editor
			get_editor_interface().edit_resource(res)
			print("VisualGasic: Opened script in Godot Editor -> " + path)
			
			# INJECT CODE INTO BUFFER
			var sub_name = "Sub " + obj + "_" + event
			var script_editor = get_editor_interface().get_script_editor()
			var current_editor = script_editor.get_current_editor()
			
			if current_editor:
				var code_edit = current_editor.get_base_editor()
				if code_edit:
					var text = code_edit.text
					
					if text.find(sub_name) == -1:
						var new_code = "\n" + sub_name + "()\n    Print \"" + obj + " " + event + "\"\nEnd Sub\n"
						code_edit.text += new_code
						text = code_edit.text # Refresh for search
					
					# Goto Line
					var lines = text.split("\n")
					for i in lines.size():
						if lines[i].strip_edges().begins_with(sub_name):
							code_edit.set_caret_line(i + 1)
							code_edit.set_caret_column(4)
							code_edit.center_viewport_to_caret()
							code_edit.grab_focus()
							break
	else:
		await get_tree().create_timer(0.1).timeout
		_poll_for_inject(path, obj, event, attempts + 1)


func _on_main_screen_changed(screen_name: String):
	var real_toolbox = _get_toolbox_instance()
	if real_toolbox:
		var tabs = null
		# Find the TabContainer (should be the first child if C++ constructor is correct)
		for c in real_toolbox.get_children():
			if c is TabContainer:
				tabs = c
				break
		
		if tabs:
			if screen_name == "3D":
				tabs.current_tab = 1 # 3D Index
			elif screen_name == "2D":
				tabs.current_tab = 0 # 2D Index
	
	# Update Code Navigator on Screen Change (e.g. entering Script view)
	var nav = _get_navigator()
	if nav:
		nav.refresh_objects()

func setup_toolbox():
	if ClassDB.class_exists("VisualGasicToolbox"):
		var real_toolbox = ClassDB.instantiate("VisualGasicToolbox")
		real_toolbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		real_toolbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		real_toolbox.custom_minimum_size = Vector2(200, 300) 
		real_toolbox.visible = true
		toolbox.add_child(real_toolbox)
	else:
		var err = Label.new()
		err.text = "VisualGasicToolbox Missing!"
		toolbox.add_child(err)
		
	# Fallback/Additional Logic if needed
	pass

func register_tool(name: String, create_class: String, icon_name: String = "", scene_path: String = "", category: String = "2D"):
	var real_toolbox = _get_toolbox_instance()
	if real_toolbox:
		real_toolbox.add_tool(name, create_class, icon_name, scene_path, category)
	else:
		printerr("VisualGasic: Toolbox not found!")

func _get_toolbox_instance():
	if toolbox:
		for c in toolbox.get_children():
			if c.get_class() == "VisualGasicToolbox":
				return c
	return null



func _on_selection_changed():
	var sel = get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() == 1:
		call_deferred("_check_nesting", sel[0])
		call_deferred("_auto_set_text_from_name", sel[0])
	
	# Update Code Navigator
	var nav = _get_navigator()
	if nav:
		# Does not auto-refresh on simple selection to avoid flicker/perf, 
		# but refreshing the list when nodes are added/renamed is wise.
		# For now, just a button, but can call nav.refresh_objects() if hierarchy changed?
		pass
		
func _get_navigator():
	if toolbox:
		for c in toolbox.get_children():
			if c.name == "Code Navigator":
				return c
	return null

func _auto_set_text_from_name(node: Node):
	if not is_instance_valid(node): return
	
	# Only applies to controls with a 'text' property
	if "text" in node:
		var current = node.text
		# Defaults defined in our prototypes
		if current == "Button" or current == "Check1" or current == "Label" or current == "CheckBox":
			if node.name != current:
				print("VisualGasic: Auto-setting text to match name -> " + node.name)
				node.text = node.name

func _check_nesting(node: Node):
	if not is_instance_valid(node): return
	
	# CHECK FOR MISSING ROOT (Empty Scene)
	var root = get_editor_interface().get_edited_scene_root()
	if not root:
		# If there is no root, but we have a node, this node IS the root candidates?
		# No, Godot usually sets the dropped node as root automatically if empty.
		# But if we drop subsequent nodes, we need a valid root.
		return

	# If the node IS the new root (because scene was empty), enable "Form" preset for it?
	if node == root:
		print("VisualGasic: New Root Node Created -> " + node.name)
		# Optional: Auto-rename to "Form" if it's a Control/Panel?
		return

	var parent = node.get_parent()
	if not parent: return
	
	var is_bad = false
	
	# AllowList Strategy: Only specific nodes can be parents
	var is_container = false
	
	# 1. Root is always valid
	if parent == root:
		is_container = true
		
	# 2. explicit Containers
	elif parent is Panel: is_container = true
	elif parent is TabContainer: is_container = true
	elif parent is ScrollContainer: is_container = true
	elif parent is VBoxContainer: is_container = true
	elif parent is HBoxContainer: is_container = true
	elif parent is GridContainer: is_container = true
	elif parent is Control and parent.name == "Form": is_container = true
	
	# If it's not a container, it's BAD.
	if not is_container:
		print("VisualGasic: Blocked Nesting in " + parent.name + " (" + parent.get_class() + "). Reparenting to Root.")
		# Move to Root (Form) directly, as that is the safest "VB6" behavior
		_reparent_node(node, root)
	else:
		print("VisualGasic: Allowed Nesting in " + parent.name)

func _reparent_node(node: Node, new_parent: Node):
	if not new_parent: return
	
	var global_pos = Vector2.ZERO
	if node is Node2D or node is Control:
		global_pos = node.global_position
		
	print("VisualGasic: Moving " + node.name + " from " + node.get_parent().name + " to " + new_parent.name + " at " + str(global_pos))
	
	# Capture owner before removing
	var owner_node = node.owner
	if not owner_node:
		owner_node = get_editor_interface().get_edited_scene_root()
		
	node.get_parent().remove_child(node)
	new_parent.add_child(node)
	
	node.owner = owner_node
	
	if node is Node2D or node is Control:
		# If Position is 0,0, try to guess or leave it
		if global_pos == Vector2.ZERO and new_parent is Control:
             # Just leave it, Godot might have failed to set pos
			pass
		else:
			node.global_position = global_pos
		
	# Restore selection
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)

# === Script Editor Context Menu for Rename Refactoring ===

func _setup_script_editor_context_menu():
	"""Setup timer to monitor script editor for .vg files"""
	# Create context menu
	_script_context_menu = PopupMenu.new()
	_script_context_menu.add_item("Rename in Current Scope...", 0)
	_script_context_menu.add_item("Rename in Entire Script...", 1)
	_script_context_menu.add_item("Rename Everywhere...", 2)
	_script_context_menu.id_pressed.connect(_on_script_context_menu_selected)
	get_editor_interface().get_base_control().add_child(_script_context_menu)
	
	# Timer to periodically check for .vg script in editor
	_script_editor_check_timer = Timer.new()
	_script_editor_check_timer.wait_time = 0.5
	_script_editor_check_timer.timeout.connect(_check_script_editor_for_vg)
	get_editor_interface().get_base_control().add_child(_script_editor_check_timer)
	_script_editor_check_timer.start()

func _check_script_editor_for_vg():
	"""Check if a .vg file is being edited and hook into its CodeEdit"""
	var script_editor = get_editor_interface().get_script_editor()
	if not script_editor:
		return
	
	var current_script = script_editor.get_current_script()
	if not current_script:
		return
	
	var script_path = current_script.resource_path
	if not script_path.ends_with(".vg"):
		_current_code_edit = null
		return
	
	# Get the CodeEdit for this script
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
	
	var code_edit = current_editor.get_base_editor() as CodeEdit
	if not code_edit or code_edit == _current_code_edit:
		return
	
	# New CodeEdit - hook into it
	_current_code_edit = code_edit
	if not code_edit.gui_input.is_connected(_on_code_edit_gui_input):
		code_edit.gui_input.connect(_on_code_edit_gui_input)

func _on_code_edit_gui_input(event: InputEvent):
	"""Handle keyboard shortcuts in the code editor"""
	if not _current_code_edit:
		return
	
	# Use Ctrl+R for rename (like many IDEs)
	if event is InputEventKey and event.pressed:
		var key_event = event as InputEventKey
		if key_event.ctrl_pressed and key_event.keycode == KEY_R:
			# Get the word under cursor
			var word = _get_word_under_cursor(_current_code_edit)
			if not word.is_empty() and _is_valid_identifier(word):
				# Store the word for later use
				_script_context_menu.set_meta("selected_word", word)
				_script_context_menu.set_meta("script_path", get_editor_interface().get_script_editor().get_current_script().resource_path)
				
				# Show menu at caret position
				var caret_pos = _current_code_edit.get_caret_draw_pos()
				_script_context_menu.position = Vector2i(_current_code_edit.get_screen_position()) + Vector2i(caret_pos)
				_script_context_menu.popup()
				_current_code_edit.accept_event()  # Consume the event

func _get_word_under_cursor(code_edit: CodeEdit) -> String:
	"""Get the word under the cursor in a CodeEdit"""
	var line = code_edit.get_caret_line()
	var col = code_edit.get_caret_column()
	var text = code_edit.get_line(line)
	
	if col > text.length():
		col = text.length()
	
	# Find word start
	var start = col
	while start > 0 and _is_identifier_char(text[start - 1]):
		start -= 1
	
	# Find word end
	var end = col
	while end < text.length() and _is_identifier_char(text[end]):
		end += 1
	
	if start >= end:
		return ""
	
	return text.substr(start, end - start)

func _is_identifier_char(c: String) -> bool:
	return c.is_valid_identifier() or c == "_" or (c >= "0" and c <= "9")

func _is_valid_identifier(name: String) -> bool:
	if name.is_empty():
		return false
	if name[0] >= "0" and name[0] <= "9":
		return false
	for c in name:
		if not _is_identifier_char(c):
			return false
	return true

func _on_script_context_menu_selected(id: int):
	"""Handle script editor context menu selection"""
	var word = _script_context_menu.get_meta("selected_word", "")
	var script_path = _script_context_menu.get_meta("script_path", "")
	
	if word.is_empty():
		return
	
	# id: 0 = current scope, 1 = entire script, 2 = everywhere
	_show_rename_dialog_for_script(word, script_path, id)

func _show_rename_dialog_for_script(old_name: String, script_path: String, mode: int):
	"""Show dialog to rename a variable in script files
	   mode: 0 = current scope, 1 = entire script, 2 = everywhere"""
	var mode_names = ["Current Scope", "Entire Script", "Everywhere"]
	var dialog = AcceptDialog.new()
	dialog.title = "Rename '%s' (%s)" % [old_name, mode_names[mode]]
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Rename '%s' to:" % old_name
	vbox.add_child(label)
	
	var input = LineEdit.new()
	input.text = old_name
	input.select_all()
	vbox.add_child(input)
	
	if mode == 2:
		var warning = Label.new()
		warning.text = "⚠ This will rename in ALL .vg files!"
		warning.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(warning)
	elif mode == 1:
		var info = Label.new()
		info.text = "ℹ This will rename in the entire script file"
		info.add_theme_color_override("font_color", Color.CYAN)
		vbox.add_child(info)
	else:
		var info = Label.new()
		info.text = "ℹ This will rename only in the current Sub/Function"
		info.add_theme_color_override("font_color", Color.LIME_GREEN)
		vbox.add_child(info)
	
	dialog.confirmed.connect(func():
		var new_name = input.text.strip_edges()
		if new_name.is_empty() or new_name == old_name:
			return
		if not _is_valid_identifier(new_name):
			push_warning("'%s' is not a valid identifier" % new_name)
			return
		_perform_rename_in_scripts(old_name, new_name, script_path, mode)
		dialog.queue_free()
	)
	
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2(350, 150))
	input.grab_focus()

func _perform_rename_in_scripts(old_name: String, new_name: String, script_path: String, mode: int):
	"""Perform the actual rename operation in script files
	   mode: 0 = current scope, 1 = entire script, 2 = everywhere"""
	
	if mode == 2:
		# All files
		var files_to_search: Array[String] = _find_all_vg_files("res://")
		var total_replacements = 0
		var files_modified = 0
		
		for file_path in files_to_search:
			var result = _rename_in_file(file_path, old_name, new_name)
			if result > 0:
				total_replacements += result
				files_modified += 1
		
		if total_replacements > 0:
			print("Renamed '%s' → '%s': %d replacements in %d file(s)" % [
				old_name, new_name, total_replacements, files_modified
			])
		else:
			print("No occurrences of '%s' found" % old_name)
	elif mode == 1:
		# Entire script
		var result = _rename_in_file(script_path, old_name, new_name)
		if result > 0:
			print("Renamed '%s' → '%s': %d replacements" % [old_name, new_name, result])
		else:
			print("No occurrences of '%s' found in script" % old_name)
	else:
		# Current scope - need cursor position
		var caret_line = 0
		if _current_code_edit:
			caret_line = _current_code_edit.get_caret_line()
		var result = _rename_in_scope(script_path, old_name, new_name, caret_line)
		if result > 0:
			print("Renamed '%s' → '%s': %d replacements in current scope" % [old_name, new_name, result])
		else:
			print("No occurrences of '%s' found in current scope" % old_name)
	
	# Reload the script in the editor
	_reload_current_script()

func _reload_current_script():
	"""Reload the current script to show changes"""
	var script_editor = get_editor_interface().get_script_editor()
	if script_editor:
		var current = script_editor.get_current_script()
		if current:
			current.reload()

func _rename_in_scope(file_path: String, old_name: String, new_name: String, caret_line: int) -> int:
	"""Rename variable only within the current Sub/Function scope."""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 0
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	var proc_start = -1
	var proc_end = -1
	
	# Find the enclosing Sub/Function based on caret position
	for i in range(caret_line, -1, -1):
		if i >= lines.size():
			continue
		var line_upper = lines[i].strip_edges().to_upper()
		if line_upper.begins_with("SUB ") or line_upper.begins_with("FUNCTION ") or \
		   line_upper.begins_with("PRIVATE SUB ") or line_upper.begins_with("PUBLIC SUB ") or \
		   line_upper.begins_with("PRIVATE FUNCTION ") or line_upper.begins_with("PUBLIC FUNCTION "):
			proc_start = i
			break
	
	if proc_start == -1:
		# Caret is at module level - rename only module-level occurrences
		for i in range(lines.size()):
			var line_upper = lines[i].strip_edges().to_upper()
			if line_upper.begins_with("SUB ") or line_upper.begins_with("FUNCTION ") or \
			   line_upper.begins_with("PRIVATE SUB ") or line_upper.begins_with("PUBLIC SUB ") or \
			   line_upper.begins_with("PRIVATE FUNCTION ") or line_upper.begins_with("PUBLIC FUNCTION "):
				proc_end = i  # Stop before first procedure
				break
		if proc_end == -1:
			proc_end = lines.size()
		proc_start = 0
	else:
		# Find END SUB or END FUNCTION
		for i in range(proc_start, lines.size()):
			var line_upper = lines[i].strip_edges().to_upper()
			if line_upper == "END SUB" or line_upper == "END FUNCTION":
				proc_end = i + 1
				break
		if proc_end == -1:
			proc_end = lines.size()
	
	# Rename only within proc_start to proc_end
	var regex = RegEx.new()
	regex.compile("(?<![A-Za-z0-9_])" + old_name + "(?![A-Za-z0-9_])")
	
	var replacements = 0
	var new_lines = lines.duplicate()
	
	for i in range(proc_start, proc_end):
		var line = new_lines[i]
		var matches = regex.search_all(line)
		if matches.is_empty():
			continue
		
		var new_line = line
		for j in range(matches.size() - 1, -1, -1):
			var m = matches[j]
			if not _is_inside_string_or_comment(line, m.get_start()):
				new_line = new_line.substr(0, m.get_start()) + new_name + new_line.substr(m.get_end())
				replacements += 1
		new_lines[i] = new_line
	
	if replacements > 0:
		var write_file = FileAccess.open(file_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string("\n".join(new_lines))
			write_file.close()
	
	return replacements

func _find_all_vg_files(path: String) -> Array[String]:
	"""Recursively find all .vg files in a directory"""
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				if not file_name.begins_with("."):
					files.append_array(_find_all_vg_files(full_path))
			elif file_name.ends_with(".vg"):
				files.append(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	return files

func _rename_in_file(file_path: String, old_name: String, new_name: String) -> int:
	"""Rename variable in a single file. Returns number of replacements."""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 0
	
	var content = file.get_as_text()
	file.close()
	
	# Use word-boundary aware replacement
	var regex = RegEx.new()
	regex.compile("(?<![A-Za-z0-9_])" + old_name + "(?![A-Za-z0-9_])")
	
	var matches = regex.search_all(content)
	if matches.is_empty():
		return 0
	
	# Filter out matches inside strings and comments
	var valid_matches: Array = []
	for m in matches:
		if not _is_inside_string_or_comment(content, m.get_start()):
			valid_matches.append(m)
	
	if valid_matches.is_empty():
		return 0
	
	# Replace from end to start to preserve positions
	var new_content = content
	for i in range(valid_matches.size() - 1, -1, -1):
		var m = valid_matches[i]
		new_content = new_content.substr(0, m.get_start()) + new_name + new_content.substr(m.get_end())
	
	# Write back
	var write_file = FileAccess.open(file_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(new_content)
		write_file.close()
		return valid_matches.size()
	return 0

func _is_inside_string_or_comment(content: String, pos: int) -> bool:
	"""Check if a position in the content is inside a string or comment"""
	var line_start = content.rfind("\n", pos)
	if line_start == -1:
		line_start = 0
	else:
		line_start += 1
	
	var line_portion = content.substr(line_start, pos - line_start)
	
	# Check for comment
	var comment_pos = line_portion.find("'")
	if comment_pos >= 0:
		var in_string = false
		for i in range(comment_pos):
			if line_portion[i] == '"':
				in_string = not in_string
		if not in_string:
			return true
	
	# Check if inside string
	var quote_count = 0
	for i in range(line_portion.length()):
		if line_portion[i] == '"':
			quote_count += 1
	
	return quote_count % 2 == 1

