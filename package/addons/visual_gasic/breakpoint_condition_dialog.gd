@tool
extends Window
## Breakpoint Condition Editor Dialog
##
## Allows editing:
## - Condition expression
## - Hit count settings
## - Log message
## - Temporary breakpoint option

signal breakpoint_updated(info: VGBreakpointConditions.BreakpointInfo)
signal breakpoint_removed()

var _breakpoint_info: VGBreakpointConditions.BreakpointInfo
var _script_path: String

# UI Elements
var _enabled_check: CheckBox
var _condition_edit: LineEdit
var _hit_count_type: OptionButton
var _hit_count_value: SpinBox
var _log_message_edit: LineEdit
var _temporary_check: CheckBox
var _current_hits_label: Label

func _init() -> void:
	title = "Edit Breakpoint"
	size = Vector2i(450, 320)
	min_size = Vector2i(400, 300)
	transient = true
	exclusive = true

func _ready() -> void:
	_build_ui()
	close_requested.connect(_on_close_requested)

func _build_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 10
	main_vbox.offset_right = -10
	main_vbox.offset_top = 10
	main_vbox.offset_bottom = -10
	add_child(main_vbox)
	
	# Enabled checkbox
	_enabled_check = CheckBox.new()
	_enabled_check.text = "Enabled"
	main_vbox.add_child(_enabled_check)
	
	main_vbox.add_child(HSeparator.new())
	
	# Condition section
	var condition_label = Label.new()
	condition_label.text = "Condition Expression (break when true):"
	main_vbox.add_child(condition_label)
	
	_condition_edit = LineEdit.new()
	_condition_edit.placeholder_text = "e.g., x > 5 or name == \"test\""
	main_vbox.add_child(_condition_edit)
	
	main_vbox.add_child(HSeparator.new())
	
	# Hit count section
	var hit_label = Label.new()
	hit_label.text = "Hit Count:"
	main_vbox.add_child(hit_label)
	
	var hit_hbox = HBoxContainer.new()
	main_vbox.add_child(hit_hbox)
	
	_hit_count_type = OptionButton.new()
	_hit_count_type.add_item("Always break", VGBreakpointConditions.HitCountType.NONE)
	_hit_count_type.add_item("Break when hits =", VGBreakpointConditions.HitCountType.EQUALS)
	_hit_count_type.add_item("Break when hits >=", VGBreakpointConditions.HitCountType.GREATER_EQUAL)
	_hit_count_type.add_item("Break every N hits", VGBreakpointConditions.HitCountType.MULTIPLE)
	_hit_count_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit_hbox.add_child(_hit_count_type)
	
	_hit_count_value = SpinBox.new()
	_hit_count_value.min_value = 0
	_hit_count_value.max_value = 999999
	_hit_count_value.value = 1
	_hit_count_value.custom_minimum_size.x = 80
	hit_hbox.add_child(_hit_count_value)
	
	_current_hits_label = Label.new()
	_current_hits_label.text = "(Current: 0)"
	_current_hits_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hit_hbox.add_child(_current_hits_label)
	
	_hit_count_type.item_selected.connect(_on_hit_count_type_changed)
	
	main_vbox.add_child(HSeparator.new())
	
	# Log message section
	var log_label = Label.new()
	log_label.text = "Log Message (log instead of break, use {var} for values):"
	main_vbox.add_child(log_label)
	
	_log_message_edit = LineEdit.new()
	_log_message_edit.placeholder_text = "e.g., x = {x}, name = {name}"
	main_vbox.add_child(_log_message_edit)
	
	main_vbox.add_child(HSeparator.new())
	
	# Temporary checkbox
	_temporary_check = CheckBox.new()
	_temporary_check.text = "Temporary (delete after first break)"
	main_vbox.add_child(_temporary_check)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)
	
	# Button row
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(button_hbox)
	
	var remove_btn = Button.new()
	remove_btn.text = "Remove Breakpoint"
	remove_btn.pressed.connect(_on_remove_pressed)
	button_hbox.add_child(remove_btn)
	
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_hbox.add_child(spacer2)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(cancel_btn)
	
	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.pressed.connect(_on_ok_pressed)
	button_hbox.add_child(ok_btn)

func _on_hit_count_type_changed(index: int) -> void:
	var type = _hit_count_type.get_item_id(index)
	_hit_count_value.editable = type != VGBreakpointConditions.HitCountType.NONE

## Opens the dialog for a breakpoint
func edit_breakpoint(script_path: String, line: int, info: VGBreakpointConditions.BreakpointInfo) -> void:
	_script_path = script_path
	_breakpoint_info = info
	
	title = "Edit Breakpoint - %s:%d" % [script_path.get_file(), line]
	
	# Populate UI
	_enabled_check.button_pressed = info.enabled
	_condition_edit.text = info.condition
	
	# Find the index for the hit count type
	for i in range(_hit_count_type.item_count):
		if _hit_count_type.get_item_id(i) == info.hit_count_type:
			_hit_count_type.select(i)
			break
	
	_hit_count_value.value = info.hit_count_value if info.hit_count_value > 0 else 1
	_hit_count_value.editable = info.hit_count_type != VGBreakpointConditions.HitCountType.NONE
	_current_hits_label.text = "(Current: %d)" % info.current_hits
	
	_log_message_edit.text = info.log_message
	_temporary_check.button_pressed = info.is_temporary
	
	popup_centered()

func _on_ok_pressed() -> void:
	# Update breakpoint info
	_breakpoint_info.enabled = _enabled_check.button_pressed
	_breakpoint_info.condition = _condition_edit.text.strip_edges()
	
	var selected_idx = _hit_count_type.selected
	_breakpoint_info.hit_count_type = _hit_count_type.get_item_id(selected_idx)
	_breakpoint_info.hit_count_value = int(_hit_count_value.value)
	
	_breakpoint_info.log_message = _log_message_edit.text.strip_edges()
	_breakpoint_info.is_temporary = _temporary_check.button_pressed
	
	breakpoint_updated.emit(_breakpoint_info)
	hide()

func _on_cancel_pressed() -> void:
	hide()

func _on_remove_pressed() -> void:
	breakpoint_removed.emit()
	hide()

func _on_close_requested() -> void:
	hide()
