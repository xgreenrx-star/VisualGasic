@tool
extends Window
# VisualGasic Project Properties

func _init():
	title = "Project Properties"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	size = Vector2(400, 300)
	exclusive = true
	visible = false
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10; vbox.offset_top = 10; vbox.offset_right = -10; vbox.offset_bottom = -10
	panel.add_child(vbox)
	
	# -- Content --
	var grid = GridContainer.new()
	grid.columns = 2
	vbox.add_child(grid)
	
	# Project Name
	grid.add_child(_lbl("Project Name:"))
	var txt_name = LineEdit.new()
	txt_name.text = ProjectSettings.get_setting("application/config/name", "New Project")
	txt_name.text_changed.connect(func(t): ProjectSettings.set_setting("application/config/name", t))
	grid.add_child(txt_name)
	
	# Startup Object (Main Scene)
	grid.add_child(_lbl("Startup Object:"))
	var hbox_start = HBoxContainer.new()
	var txt_start = LineEdit.new()
	txt_start.text = ProjectSettings.get_setting("application/run/main_scene", "")
	txt_start.editable = false
	txt_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_browse = Button.new()
	btn_browse.text = "..."
	btn_browse.pressed.connect(func(): _browse_main(txt_start))
	hbox_start.add_child(txt_start)
	hbox_start.add_child(btn_browse)
	grid.add_child(hbox_start)
	
	# Separator
	vbox.add_child(HSeparator.new())
	
	var grid_disp = GridContainer.new()
	grid_disp.columns = 2
	vbox.add_child(grid_disp)

	# Dimensions
	grid_disp.add_child(_lbl("Width:"))
	var type_w = SpinBox.new()
	type_w.max_value = 10000
	type_w.value = ProjectSettings.get_setting("display/window/size/viewport_width", 1152)
	type_w.value_changed.connect(func(v): ProjectSettings.set_setting("display/window/size/viewport_width", v))
	grid_disp.add_child(type_w)
	
	grid_disp.add_child(_lbl("Height:"))
	var type_h = SpinBox.new()
	type_h.max_value = 10000
	type_h.value = ProjectSettings.get_setting("display/window/size/viewport_height", 648)
	type_h.value_changed.connect(func(v): ProjectSettings.set_setting("display/window/size/viewport_height", v))
	grid_disp.add_child(type_h)
	
	# -- Buttons --
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	var bots = HBoxContainer.new()
	bots.alignment = BoxContainer.ALIGNMENT_END
	var btn_ok = Button.new()
	btn_ok.text = "OK"
	btn_ok.pressed.connect(_on_ok)
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.pressed.connect(queue_free)
	bots.add_child(btn_ok)
	bots.add_child(btn_cancel)
	vbox.add_child(bots)

func _lbl(t):
	var l = Label.new()
	l.text = t
	return l

func _browse_main(txt_node):
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.filters = PackedStringArray(["*.tscn, *.scn; Scenes"])
	fd.file_selected.connect(func(path): 
		txt_node.text = path
		ProjectSettings.set_setting("application/run/main_scene", path)
	)
	add_child(fd)
	fd.popup_centered_ratio(0.5)

func _on_ok():
	ProjectSettings.save()
	print("Project settings saved.")
	queue_free()
