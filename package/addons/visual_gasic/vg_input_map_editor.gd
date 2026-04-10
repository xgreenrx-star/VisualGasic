# vg_input_map_editor.gd
# VB6-style Input Map editor for configuring game input actions and key bindings.
# Reads/writes project.godot input/* entries through ProjectSettings API.
@tool
extends AcceptDialog

const VGTheme = preload("res://addons/visual_gasic/vg_theme_utils.gd")

# VB6 theme palette
const VB6_PANEL_BG       = Color(0.941, 0.929, 0.910)
const VB6_TEXT           = Color(0.0, 0.0, 0.0)
const VB6_LIST_BG        = Color(1.0, 1.0, 1.0)
const VB6_BTN_FACE       = Color("#D4D0C8")
const VB6_HEADER_BG      = Color(0.58, 0.58, 0.62)
const VB6_HEADER_TEXT    = Color(1.0, 1.0, 1.0)
const VB6_ACTIVE_TITLE   = Color(0.0, 0.0, 0.5)

# UI references
var _action_list: ItemList
var _event_list: ItemList
var _action_name_edit: LineEdit
var _add_action_btn: Button
var _remove_action_btn: Button
var _add_key_btn: Button
var _add_mouse_btn: Button
var _add_joy_btn: Button
var _remove_event_btn: Button
var _deadzone_spin: SpinBox
var _key_capture_dialog: AcceptDialog
var _capturing_key: bool = false

# Data
var _actions: Array[String] = []
var _selected_action: String = ""

func _init():
	title = "Input Map Editor"
	size = Vector2i(700, 500)
	unresizable = false
	ok_button_text = "Close"
	dialog_hide_on_ok = true

	var main_hbox = HBoxContainer.new()
	main_hbox.custom_minimum_size = Vector2(660, 400)
	main_hbox.add_theme_constant_override("separation", 8)
	add_child(main_hbox)

	# ── LEFT: Actions list ──
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.4
	main_hbox.add_child(left_vbox)

	var actions_label = Label.new()
	actions_label.text = "Actions:"
	left_vbox.add_child(actions_label)

	_action_list = ItemList.new()
	_action_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_list.item_selected.connect(_on_action_selected)
	left_vbox.add_child(_action_list)

	# Add action row
	var add_row = HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	left_vbox.add_child(add_row)

	_action_name_edit = LineEdit.new()
	_action_name_edit.placeholder_text = "New action name..."
	_action_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(_action_name_edit)

	_add_action_btn = Button.new()
	_add_action_btn.text = "Add"
	_add_action_btn.pressed.connect(_on_add_action)
	add_row.add_child(_add_action_btn)

	_remove_action_btn = Button.new()
	_remove_action_btn.text = "Remove"
	_remove_action_btn.pressed.connect(_on_remove_action)
	left_vbox.add_child(_remove_action_btn)

	# ── RIGHT: Events/bindings for selected action ──
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.6
	main_hbox.add_child(right_vbox)

	var events_label = Label.new()
	events_label.text = "Key Bindings for Action:"
	right_vbox.add_child(events_label)

	_event_list = ItemList.new()
	_event_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_event_list)

	# Binding buttons row
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	right_vbox.add_child(btn_row)

	_add_key_btn = Button.new()
	_add_key_btn.text = "⌨ Add Key..."
	_add_key_btn.tooltip_text = "Press a key to bind"
	_add_key_btn.pressed.connect(_on_add_key_binding)
	btn_row.add_child(_add_key_btn)

	_add_mouse_btn = Button.new()
	_add_mouse_btn.text = "🖱 Add Mouse..."
	_add_mouse_btn.tooltip_text = "Add a mouse button binding"
	_add_mouse_btn.pressed.connect(_on_add_mouse_binding)
	btn_row.add_child(_add_mouse_btn)

	_add_joy_btn = Button.new()
	_add_joy_btn.text = "🎮 Add Gamepad..."
	_add_joy_btn.tooltip_text = "Add a gamepad button binding"
	_add_joy_btn.pressed.connect(_on_add_joy_binding)
	btn_row.add_child(_add_joy_btn)

	_remove_event_btn = Button.new()
	_remove_event_btn.text = "Remove Binding"
	_remove_event_btn.pressed.connect(_on_remove_event)
	right_vbox.add_child(_remove_event_btn)

	# Deadzone row
	var dz_row = HBoxContainer.new()
	dz_row.add_theme_constant_override("separation", 4)
	right_vbox.add_child(dz_row)

	var dz_label = Label.new()
	dz_label.text = "Deadzone:"
	dz_row.add_child(dz_label)

	_deadzone_spin = SpinBox.new()
	_deadzone_spin.min_value = 0.0
	_deadzone_spin.max_value = 1.0
	_deadzone_spin.step = 0.05
	_deadzone_spin.value = 0.5
	_deadzone_spin.custom_minimum_size.x = 80
	_deadzone_spin.value_changed.connect(_on_deadzone_changed)
	dz_row.add_child(_deadzone_spin)

	# Key capture dialog
	_key_capture_dialog = AcceptDialog.new()
	_key_capture_dialog.title = "Press a Key"
	_key_capture_dialog.dialog_text = "Press any key to bind it to this action...\n(Press Escape to cancel)"
	_key_capture_dialog.size = Vector2i(350, 150)
	_key_capture_dialog.unresizable = true
	add_child(_key_capture_dialog)

	confirmed.connect(_on_close)

func _ready():
	theme = _build_vb6_dialog_theme()
	_load_actions()

# ─────────────────────────────────────────────────────────────────────────────
# DATA LOADING
# ─────────────────────────────────────────────────────────────────────────────
func _load_actions() -> void:
	_actions.clear()
	_action_list.clear()

	# Get all input actions from ProjectSettings
	for prop in ProjectSettings.get_property_list():
		var name: String = prop["name"]
		if name.begins_with("input/"):
			var action_name := name.trim_prefix("input/")
			# Skip built-in ui_ actions
			if action_name.begins_with("ui_"):
				continue
			_actions.append(action_name)

	_actions.sort()
	for action_name in _actions:
		_action_list.add_item(action_name)

	if _actions.size() > 0:
		_action_list.select(0)
		_on_action_selected(0)

func _on_action_selected(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	_selected_action = _actions[index]
	_refresh_events()

func _refresh_events() -> void:
	_event_list.clear()
	if _selected_action.is_empty():
		return

	var setting = ProjectSettings.get_setting("input/" + _selected_action)
	if setting is Dictionary and setting.has("events"):
		var events: Array = setting["events"]
		if setting.has("deadzone"):
			_deadzone_spin.value = setting["deadzone"]
		for event in events:
			_event_list.add_item(_describe_event(event))

func _describe_event(event) -> String:
	if event is InputEventKey:
		var desc := ""
		if event.ctrl_pressed: desc += "Ctrl+"
		if event.alt_pressed: desc += "Alt+"
		if event.shift_pressed: desc += "Shift+"
		desc += OS.get_keycode_string(event.keycode) if event.keycode != KEY_NONE else OS.get_keycode_string(event.physical_keycode)
		return "⌨ " + desc
	elif event is InputEventMouseButton:
		var btn_name := "Unknown"
		match event.button_index:
			MOUSE_BUTTON_LEFT: btn_name = "Left Click"
			MOUSE_BUTTON_RIGHT: btn_name = "Right Click"
			MOUSE_BUTTON_MIDDLE: btn_name = "Middle Click"
			MOUSE_BUTTON_WHEEL_UP: btn_name = "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: btn_name = "Wheel Down"
		return "🖱 " + btn_name
	elif event is InputEventJoypadButton:
		return "🎮 Button " + str(event.button_index)
	elif event is InputEventJoypadMotion:
		return "🎮 Axis " + str(event.axis) + (" +" if event.axis_value > 0 else " -")
	return str(event)

# ─────────────────────────────────────────────────────────────────────────────
# ACTION MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────
func _on_add_action() -> void:
	var action_name := _action_name_edit.text.strip_edges()
	if action_name.is_empty():
		return
	# Sanitize: replace spaces with underscores
	action_name = action_name.replace(" ", "_").to_lower()

	if ProjectSettings.has_setting("input/" + action_name):
		push_warning("[VGInput] Action already exists: " + action_name)
		return

	ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.5, "events": []})
	ProjectSettings.save()
	_action_name_edit.text = ""
	_load_actions()

	# Select the new action
	var idx := _actions.find(action_name)
	if idx >= 0:
		_action_list.select(idx)
		_on_action_selected(idx)

func _on_remove_action() -> void:
	if _selected_action.is_empty():
		return

	ProjectSettings.set_setting("input/" + _selected_action, null)
	ProjectSettings.save()
	_selected_action = ""
	_load_actions()

# ─────────────────────────────────────────────────────────────────────────────
# EVENT BINDING
# ─────────────────────────────────────────────────────────────────────────────
func _on_add_key_binding() -> void:
	if _selected_action.is_empty():
		return
	_capturing_key = true
	_key_capture_dialog.popup_centered()

func _unhandled_key_input(event: InputEvent) -> void:
	if not _capturing_key:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_capturing_key = false
			_key_capture_dialog.hide()
			return

		_capturing_key = false
		_key_capture_dialog.hide()

		# Create a clean InputEventKey
		var key_event := InputEventKey.new()
		key_event.keycode = event.keycode
		key_event.physical_keycode = event.physical_keycode
		key_event.ctrl_pressed = event.ctrl_pressed
		key_event.alt_pressed = event.alt_pressed
		key_event.shift_pressed = event.shift_pressed
		key_event.meta_pressed = event.meta_pressed

		_add_event_to_action(key_event)

func _on_add_mouse_binding() -> void:
	if _selected_action.is_empty():
		return

	# Show a quick selection popup for mouse buttons
	var popup := PopupMenu.new()
	popup.add_item("Left Click", MOUSE_BUTTON_LEFT)
	popup.add_item("Right Click", MOUSE_BUTTON_RIGHT)
	popup.add_item("Middle Click", MOUSE_BUTTON_MIDDLE)
	popup.add_item("Wheel Up", MOUSE_BUTTON_WHEEL_UP)
	popup.add_item("Wheel Down", MOUSE_BUTTON_WHEEL_DOWN)
	popup.id_pressed.connect(func(id: int):
		var ev := InputEventMouseButton.new()
		ev.button_index = id as MouseButton
		_add_event_to_action(ev)
		popup.queue_free()
	)
	add_child(popup)
	popup.position = DisplayServer.mouse_get_position()
	popup.popup()

func _on_add_joy_binding() -> void:
	if _selected_action.is_empty():
		return

	# Show a quick selection popup for common gamepad buttons
	var popup := PopupMenu.new()
	popup.add_item("A / Cross (0)", 0)
	popup.add_item("B / Circle (1)", 1)
	popup.add_item("X / Square (2)", 2)
	popup.add_item("Y / Triangle (3)", 3)
	popup.add_item("L1 / LB (4)", 4)
	popup.add_item("R1 / RB (5)", 5)
	popup.add_item("L Stick Click (6)", 6)
	popup.add_item("R Stick Click (7)", 7)
	popup.add_item("Start (8)", 8)
	popup.add_item("Select (9)", 9)
	popup.add_item("D-Pad Up (10)", 10)
	popup.add_item("D-Pad Down (11)", 11)
	popup.add_item("D-Pad Left (12)", 12)
	popup.add_item("D-Pad Right (13)", 13)
	popup.id_pressed.connect(func(id: int):
		var ev := InputEventJoypadButton.new()
		ev.button_index = id as JoyButton
		_add_event_to_action(ev)
		popup.queue_free()
	)
	add_child(popup)
	popup.position = DisplayServer.mouse_get_position()
	popup.popup()

func _add_event_to_action(event: InputEvent) -> void:
	var setting = ProjectSettings.get_setting("input/" + _selected_action)
	if not setting is Dictionary:
		setting = {"deadzone": 0.5, "events": []}

	var events: Array = setting.get("events", [])
	events.append(event)
	setting["events"] = events
	ProjectSettings.set_setting("input/" + _selected_action, setting)
	ProjectSettings.save()
	_refresh_events()

func _on_remove_event() -> void:
	if _selected_action.is_empty():
		return
	var selected := _event_list.get_selected_items()
	if selected.size() == 0:
		return

	var idx: int = selected[0]
	var setting = ProjectSettings.get_setting("input/" + _selected_action)
	if not setting is Dictionary:
		return

	var events: Array = setting.get("events", [])
	if idx >= 0 and idx < events.size():
		events.remove_at(idx)
		setting["events"] = events
		ProjectSettings.set_setting("input/" + _selected_action, setting)
		ProjectSettings.save()
		_refresh_events()

func _on_deadzone_changed(value: float) -> void:
	if _selected_action.is_empty():
		return
	var setting = ProjectSettings.get_setting("input/" + _selected_action)
	if setting is Dictionary:
		setting["deadzone"] = value
		ProjectSettings.set_setting("input/" + _selected_action, setting)
		ProjectSettings.save()

func _on_close() -> void:
	queue_free()

# ─────────────────────────────────────────────────────────────────────────────
# THEME
# ─────────────────────────────────────────────────────────────────────────────
func _build_vb6_dialog_theme() -> Theme:
	var t = Theme.new()

	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = VB6_PANEL_BG
	panel_sb.set_content_margin_all(8)
	t.set_stylebox("panel", "AcceptDialog", panel_sb)
	t.set_stylebox("panel", "PanelContainer", panel_sb)

	t.set_color("font_color", "Label", VB6_TEXT)
	t.set_color("font_color", "LineEdit", VB6_TEXT)
	t.set_color("font_color", "Button", VB6_TEXT)

	var le_sb = StyleBoxFlat.new()
	le_sb.bg_color = VB6_LIST_BG
	le_sb.border_color = Color(0.5, 0.5, 0.5)
	le_sb.set_border_width_all(1)
	le_sb.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", le_sb)

	var list_sb = StyleBoxFlat.new()
	list_sb.bg_color = VB6_LIST_BG
	list_sb.border_color = Color(0.5, 0.5, 0.5)
	list_sb.set_border_width_all(1)
	t.set_stylebox("panel", "ItemList", list_sb)
	t.set_color("font_color", "ItemList", VB6_TEXT)

	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = VB6_BTN_FACE
	btn_sb.border_color = Color(0.5, 0.5, 0.5)
	btn_sb.set_border_width_all(1)
	btn_sb.set_corner_radius_all(2)
	btn_sb.set_content_margin_all(4)
	t.set_stylebox("normal", "Button", btn_sb)

	return t
