@tool
extends EditorPlugin

var toolbox
var import_plugin
var immediate_window

func _enter_tree():
	# Store self for static retrieval
	get_editor_interface().get_base_control().set_meta("visual_gasic_plugin_instance", self)

	# Import Plugin
	import_plugin = preload("res://addons/visual_gasic/frm_import_plugin.gd").new()
	add_import_plugin(import_plugin)
	
	# Immediate Window
	immediate_window = preload("res://addons/visual_gasic/immediate_window.gd").new()
	add_control_to_bottom_panel(immediate_window, "Immediate")

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

	add_tool_menu_item("Import VB6 Form...", Callable(self, "_on_import_vb6_form"))
	add_tool_menu_item("Import VB6 Project...", Callable(self, "_on_import_vb6_project"))
	add_tool_menu_item("Visual Gasic Menu Editor", Callable(self, "_on_menu_editor"))

func _exit_tree():
	get_editor_interface().get_base_control().remove_meta("visual_gasic_plugin_instance")
	
	remove_import_plugin(import_plugin)
	import_plugin = null
	
	remove_tool_menu_item("Import VB6 Form...")
	remove_tool_menu_item("Import VB6 Project...")
	remove_tool_menu_item("Visual Gasic Menu Editor")
	
	if immediate_window:
		remove_control_from_bottom_panel(immediate_window)
		immediate_window.queue_free()
		immediate_window = null
	
	if toolbox:
		remove_control_from_docks(toolbox)
		toolbox.queue_free()
		toolbox = null
		
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
	var root = Panel.new()
	root.name = "Form1"
	root.custom_minimum_size = Vector2(400, 300)
	
	var packed = PackedScene.new()
	packed.pack(root)
	var path = "res://Form1.tscn"
	var idx = 1
	while FileAccess.file_exists(path):
		idx += 1
		path = "res://Form" + str(idx) + ".tscn"
		root.name = "Form" + str(idx)
		
	ResourceSaver.save(packed, path)
	
	# Create bas
	var bas_path = path.replace(".tscn", ".vg")
	var f = FileAccess.open(bas_path, FileAccess.WRITE)
	f.store_string("' Code for " + root.name + "\n")
	f.close()
	
	get_editor_interface().open_scene_from_path(path)
	# Attach script
	call_deferred("_attach_script_deferred", path, bas_path)

func _attach_script_deferred(scene_path, script_path):
	var root = get_editor_interface().get_edited_scene_root()
	if root and root.scene_file_path == scene_path:
		pass # Logic to attach script handled by inspector or manual attach for now. 
		# We need a proper resource loader for bas to set it effectively.

func _on_menu_editor():
	var dlg = load("res://addons/visual_gasic/menu_editor.gd").new()
	get_editor_interface().get_base_control().add_child(dlg)
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
