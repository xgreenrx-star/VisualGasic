@tool
extends EditorPlugin
## Visual Form Designer for VisualGasic
## Provides VB6-style drag-and-drop form editing

const FormCanvas = preload("res://addons/visual_gasic/form_canvas.gd")
const ControlHandle = preload("res://addons/visual_gasic/control_handle.gd")

var form_canvas: Control
var current_form: Node
var selected_controls: Array[Control] = []
var undo_redo: EditorUndoRedoManager

# Grid settings
var grid_enabled: bool = true
var grid_size: int = 8
var snap_to_grid: bool = true

# UI elements
var designer_toolbar: HBoxContainer
var grid_toggle_btn: Button
var snap_toggle_btn: Button
var align_menu: MenuButton
var menu_editor: Window

func _enter_tree() -> void:
	undo_redo = get_undo_redo()
	_create_ui()
	
	# Connect to toolbox for drag-drop
	if has_node("/root/EditorNode/VisualGasicToolbox"):
		var toolbox = get_node("/root/EditorNode/VisualGasicToolbox")
		if toolbox.has_signal("control_dragged"):
			toolbox.control_dragged.connect(_on_control_dragged)

func _exit_tree() -> void:
	if form_canvas:
		form_canvas.queue_free()
	if designer_toolbar:
		designer_toolbar.queue_free()

func _create_ui() -> void:
	# Create toolbar for VB6-specific features
	# Note: Grid and Snap are handled by Godot's built-in editor controls
	designer_toolbar = HBoxContainer.new()
	designer_toolbar.name = "FormDesignerToolbar"
	
	# Alignment menu
	align_menu = MenuButton.new()
	align_menu.text = "Align"
	var popup = align_menu.get_popup()
	popup.add_item("Align Left", 0)
	popup.add_item("Align Center", 1)
	popup.add_item("Align Right", 2)
	popup.add_separator()
	popup.add_item("Align Top", 3)
	popup.add_item("Align Middle", 4)
	popup.add_item("Align Bottom", 5)
	popup.add_separator()
	popup.add_item("Make Same Width", 6)
	popup.add_item("Make Same Height", 7)
	popup.add_item("Make Same Size", 8)
	popup.id_pressed.connect(_on_align_menu_pressed)
	designer_toolbar.add_child(align_menu)
	
	designer_toolbar.add_child(VSeparator.new())
	
	# Z-order buttons
	var bring_front_btn = Button.new()
	bring_front_btn.text = "Bring to Front"
	bring_front_btn.pressed.connect(_bring_to_front)
	designer_toolbar.add_child(bring_front_btn)
	
	var send_back_btn = Button.new()
	send_back_btn.text = "Send to Back"
	send_back_btn.pressed.connect(_send_to_back)
	designer_toolbar.add_child(send_back_btn)
	
	# Add toolbar to editor
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, designer_toolbar)
	
	# Create canvas
	form_canvas = FormCanvas.new()
	form_canvas.name = "FormDesignerCanvas"
	form_canvas.grid_enabled = grid_enabled
	form_canvas.grid_size = grid_size
	form_canvas.snap_to_grid = snap_to_grid
	form_canvas.control_selected.connect(_on_control_selected)
	form_canvas.control_moved.connect(_on_control_moved)
	form_canvas.control_resized.connect(_on_control_resized)
	form_canvas.edit_form_menu_requested.connect(_on_edit_form_menu)

func _handles(object: Object) -> bool:
	# Handle GasicForm nodes for visual editing
	if object is Node:
		return object.get_class() == "GasicForm" or object.has_meta("gasic_form")
	return false

func _edit(object: Object) -> void:
	if object and _handles(object):
		current_form = object as Node
		_setup_canvas_for_form(current_form)
	else:
		current_form = null
		_clear_canvas()

func _make_visible(visible: bool) -> void:
	if form_canvas:
		form_canvas.visible = visible
	if designer_toolbar:
		designer_toolbar.visible = visible

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	"""Intercept canvas input events for right-click menu"""
	# Only handle input when we're actually editing a form AND it's visible
	if not current_form or not form_canvas or not form_canvas.visible:
		return false
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Show our custom menu
			_show_form_context_menu(event.global_position)
			return true # Consume the event
	
	return false

func _show_form_context_menu(pos: Vector2) -> void:
	"""Show context menu for form"""
	var popup = PopupMenu.new()
	popup.add_item("Edit Form Menu...", 0)
	popup.add_separator()
	popup.add_item("Form Properties", 1)
	
	get_editor_interface().get_base_control().add_child(popup)
	
	popup.id_pressed.connect(func(id):
		match id:
			0: # Edit Form Menu
				_on_edit_form_menu()
			1: # Properties
				pass # TODO: Show form properties
		popup.queue_free()
	)
	
	popup.position = Vector2i(pos)
	popup.popup()

func _setup_canvas_for_form(form: Node) -> void:
	if not form_canvas.get_parent():
		add_control_to_container(CONTAINER_CANVAS_EDITOR_SIDE_LEFT, form_canvas)
	
	form_canvas.set_form(form)
	_update_control_list()

func _clear_canvas() -> void:
	if form_canvas and form_canvas.get_parent():
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_SIDE_LEFT, form_canvas)
	selected_controls.clear()

func _update_control_list() -> void:
	# Populate canvas with form's children
	if not current_form:
		return
	
	for child in current_form.get_children():
		if child is Control:
			form_canvas.add_design_control(child)

## Grid and snap settings
## Alignment functions
func _on_align_menu_pressed(id: int) -> void:
	if selected_controls.size() < 2:
		return
	
	var reference = selected_controls[0]
	
	match id:
		0: # Align Left
			for ctrl in selected_controls.slice(1):
				_move_control_with_undo(ctrl, Vector2(reference.position.x, ctrl.position.y))
		1: # Align Center
			var ref_center = reference.position.x + reference.size.x / 2
			for ctrl in selected_controls.slice(1):
				var new_x = ref_center - ctrl.size.x / 2
				_move_control_with_undo(ctrl, Vector2(new_x, ctrl.position.y))
		2: # Align Right
			var ref_right = reference.position.x + reference.size.x
			for ctrl in selected_controls.slice(1):
				var new_x = ref_right - ctrl.size.x
				_move_control_with_undo(ctrl, Vector2(new_x, ctrl.position.y))
		3: # Align Top
			for ctrl in selected_controls.slice(1):
				_move_control_with_undo(ctrl, Vector2(ctrl.position.x, reference.position.y))
		4: # Align Middle
			var ref_middle = reference.position.y + reference.size.y / 2
			for ctrl in selected_controls.slice(1):
				var new_y = ref_middle - ctrl.size.y / 2
				_move_control_with_undo(ctrl, Vector2(ctrl.position.x, new_y))
		5: # Align Bottom
			var ref_bottom = reference.position.y + reference.size.y
			for ctrl in selected_controls.slice(1):
				var new_y = ref_bottom - ctrl.size.y
				_move_control_with_undo(ctrl, Vector2(ctrl.position.x, new_y))
		6: # Make Same Width
			for ctrl in selected_controls.slice(1):
				_resize_control_with_undo(ctrl, Vector2(reference.size.x, ctrl.size.y))
		7: # Make Same Height
			for ctrl in selected_controls.slice(1):
				_resize_control_with_undo(ctrl, Vector2(ctrl.size.x, reference.size.y))
		8: # Make Same Size
			for ctrl in selected_controls.slice(1):
				_resize_control_with_undo(ctrl, reference.size)

## Z-order
func _bring_to_front() -> void:
	for ctrl in selected_controls:
		if ctrl.get_parent():
			ctrl.get_parent().move_child(ctrl, -1)

func _send_to_back() -> void:
	for ctrl in selected_controls:
		if ctrl.get_parent():
			ctrl.get_parent().move_child(ctrl, 0)

## Control manipulation with undo/redo
func _move_control_with_undo(ctrl: Control, new_pos: Vector2) -> void:
	var old_pos = ctrl.position
	undo_redo.create_action("Move Control")
	undo_redo.add_do_property(ctrl, "position", new_pos)
	undo_redo.add_undo_property(ctrl, "position", old_pos)
	undo_redo.commit_action()

func _resize_control_with_undo(ctrl: Control, new_size: Vector2) -> void:
	var old_size = ctrl.size
	undo_redo.create_action("Resize Control")
	undo_redo.add_do_property(ctrl, "size", new_size)
	undo_redo.add_undo_property(ctrl, "size", old_size)
	undo_redo.commit_action()

## Signals from canvas
func _on_control_selected(controls: Array) -> void:
	selected_controls = controls
	# Update property inspector
	if controls.size() == 1:
		get_editor_interface().edit_node(controls[0])

func _on_control_moved(ctrl: Control, old_pos: Vector2, new_pos: Vector2) -> void:
	undo_redo.create_action("Move Control")
	undo_redo.add_do_property(ctrl, "position", new_pos)
	undo_redo.add_undo_property(ctrl, "position", old_pos)
	undo_redo.commit_action()
	_sync_to_code()

func _on_control_resized(ctrl: Control, old_size: Vector2, new_size: Vector2) -> void:
	undo_redo.create_action("Resize Control")
	undo_redo.add_do_property(ctrl, "size", new_size)
	undo_redo.add_undo_property(ctrl, "size", old_size)
	undo_redo.commit_action()
	_sync_to_code()

func _on_edit_form_menu() -> void:
	"""Open menu editor for current form"""
	if not menu_editor:
		var MenuEditorScript = load("res://addons/visual_gasic/menu_editor.gd")
		if MenuEditorScript:
			menu_editor = MenuEditorScript.new()
			menu_editor.menu_applied.connect(_on_menu_applied)
			get_tree().root.add_child(menu_editor)
	
	if menu_editor:
		# TODO: Load existing menu structure from form if it has one
		menu_editor.popup_centered()

func _on_menu_applied(menu_structure: Dictionary) -> void:
	"""Apply menu structure to current form"""
	if not current_form:
		return
	
	# Remove existing menu bar if present
	for child in current_form.get_children():
		if child is MenuBar:
			child.queue_free()
	
	# Create new MenuBar
	var menu_bar = MenuBar.new()
	menu_bar.name = "MenuBar"
	menu_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Build menu structure
	if menu_structure.has("items"):
		_build_menu_bar(menu_bar, menu_structure.items)
	
	# Add to form as first child
	current_form.add_child(menu_bar)
	menu_bar.set_owner(current_form.get_tree().edited_scene_root)
	
	# Position at top of form
	menu_bar.position = Vector2.ZERO
	
	print("MenuBar added to form with ", menu_structure.items.size() if menu_structure.has("items") else 0, " top-level menus")

func _build_menu_bar(menu_bar: MenuBar, items: Array) -> void:
	"""Recursively build menu structure"""
	for item_data in items:
		var caption = item_data.get("caption", "")
		var children = item_data.get("children", [])
		
		# Create PopupMenu for this top-level menu
		var popup = PopupMenu.new()
		popup.name = item_data.get("name", "PopupMenu")
		
		# Add child items to popup
		if children.size() > 0:
			_build_popup_menu(popup, children)
		
		# Add to MenuBar
		menu_bar.add_child(popup)
		popup.set_owner(current_form.get_tree().edited_scene_root)
		
		# Set the menu bar item text (removes & for display)
		var display_text = caption.replace("&", "")
		menu_bar.set_menu_title(menu_bar.get_menu_count() - 1, display_text)

func _build_popup_menu(popup: PopupMenu, items: Array) -> void:
	"""Recursively build popup menu items"""
	for item_data in items:
		var caption = item_data.get("caption", "")
		var name = item_data.get("name", "")
		var shortcut_text = item_data.get("shortcut", "")
		var checked = item_data.get("checked", false)
		var enabled = item_data.get("enabled", true)
		var children = item_data.get("children", [])
		
		# Check if separator
		if caption == "-":
			popup.add_separator()
		else:
			var item_idx = popup.get_item_count()
			
			# Add submenu if has children
			if children.size() > 0:
				var submenu = PopupMenu.new()
				submenu.name = name if name != "" else "SubMenu"
				popup.add_child(submenu)
				submenu.set_owner(current_form.get_tree().edited_scene_root)
				_build_popup_menu(submenu, children)
				popup.add_submenu_item(caption.replace("&", ""), submenu.name)
			else:
				# Regular item
				popup.add_item(caption.replace("&", ""))
			
			# Set properties
			if not enabled:
				popup.set_item_disabled(item_idx, true)
			if checked:
				popup.set_item_checked(item_idx, true)
			
			# Store metadata for event handling
			popup.set_item_metadata(item_idx, {
				"name": name,
				"shortcut": shortcut_text
			})

## Drag-drop from toolbox
func _on_control_dragged(control_type: String, drop_position: Vector2) -> void:
	if not current_form:
		return
	
	# Create control instance
	var new_control = _create_control_from_type(control_type)
	if not new_control:
		return
	
	# Snap position if enabled
	if snap_to_grid:
		drop_position = _snap_position(drop_position)
	
	new_control.position = drop_position
	new_control.size = Vector2(100, 24) # Default size
	
	# Add to form with undo
	undo_redo.create_action("Add Control")
	undo_redo.add_do_method(current_form, "add_child", new_control)
	undo_redo.add_do_property(new_control, "owner", get_editor_interface().get_edited_scene_root())
	undo_redo.add_undo_method(current_form, "remove_child", new_control)
	undo_redo.commit_action()
	
	_sync_to_code()

func _create_control_from_type(type: String) -> Control:
	match type:
		"Button": return Button.new()
		"Label": return Label.new()
		"TextEdit": return TextEdit.new()
		"LineEdit": return LineEdit.new()
		"CheckBox": return CheckBox.new()
		"OptionButton": return OptionButton.new()
		"SpinBox": return SpinBox.new()
		"ProgressBar": return ProgressBar.new()
		"Panel": return Panel.new()
		_: return null

func _snap_position(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

## Code synchronization
func _sync_to_code() -> void:
	# TODO: Generate/update .bas file from visual layout
	# This will integrate with visual_gasic_script.cpp to update the script
	if not current_form:
		return
	
	# Collect control properties
	var controls_data = []
	for child in current_form.get_children():
		if child is Control:
			controls_data.append({
				"name": child.name,
				"type": child.get_class(),
				"position": child.position,
				"size": child.size,
				"text": child.get("text") if child.has_method("get") else ""
			})
	
	# Store in form's metadata for code generation
	current_form.set_meta("_designer_data", controls_data)
	
	print("Form designer: Synced ", controls_data.size(), " controls to metadata")
