@tool
extends HBoxContainer
## VGComboBox — VB6-style ComboBox: LineEdit + ▼ Button + popup ItemList.
## Drop-in replacement for OptionButton with per-item color and type-ahead scrolling.
##
## VB6 ComboBox behaviour:
##   • Click ▼ or press Down arrow → open dropdown
##   • Type text → scroll to first matching item (prefix, case-insensitive)
##   • Single-click or Enter → commit selection, close dropdown
##   • Escape → close dropdown, restore previous text
##   • Per-item colour via set_item_custom_color() (VB6 bold substitute)

signal item_selected(index: int)

var _line_edit: LineEdit
var _arrow_btn: Button
var _popup: PopupPanel
var _item_list: ItemList

var _data: Array = []            # [{text: String, metadata: Variant}]
var _selected_idx: int = -1
var _suppress_text: bool = false
var _popup_just_closed: bool = false

## Number of items in the dropdown.
var item_count: int:
	get: return _data.size()

## Index of the currently selected item (-1 if none).
var selected: int:
	get: return _selected_idx

func _init():
	add_theme_constant_override("separation", 0)

	# --- LineEdit (editable text area) ---
	_line_edit = LineEdit.new()
	_line_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_line_edit.text_changed.connect(_on_text_changed)
	_line_edit.gui_input.connect(_on_line_edit_gui_input)
	add_child(_line_edit)

	# --- ▼ Arrow Button ---
	_arrow_btn = Button.new()
	_arrow_btn.custom_minimum_size = Vector2(22, 0)
	_arrow_btn.size_flags_vertical = SIZE_EXPAND_FILL
	_arrow_btn.focus_mode = Control.FOCUS_NONE
	_arrow_btn.pressed.connect(_on_arrow_pressed)
	add_child(_arrow_btn)
	_update_arrow_icon()

	# --- Popup containing ItemList ---
	_popup = PopupPanel.new()
	_popup.popup_hide.connect(_on_popup_hide)
	_item_list = ItemList.new()
	_item_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item_list.auto_height = false
	_item_list.item_clicked.connect(_on_item_clicked)
	_item_list.item_activated.connect(_on_item_activated)
	_popup.add_child(_item_list)
	add_child(_popup)

func _notification(what: int):
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_READY:
		_update_arrow_icon()

func _update_arrow_icon() -> void:
	if not _arrow_btn:
		return
	var icon = _arrow_btn.get_theme_icon("GuiOptionArrow", "EditorIcons")
	if not icon:
		icon = _arrow_btn.get_theme_icon("ArrowDown", "EditorIcons")
	if icon:
		_arrow_btn.icon = icon
		_arrow_btn.text = ""
	else:
		_arrow_btn.text = "▼"

# ============================================================
# OptionButton-compatible API
# ============================================================

func add_item(text: String, _id: int = -1) -> void:
	"""Add an item. Second argument is accepted for OptionButton compat but ignored."""
	_data.append({"text": text, "metadata": null})
	_item_list.add_item(text)

func clear() -> void:
	"""Remove all items."""
	_data.clear()
	_item_list.clear()
	_selected_idx = -1
	_suppress_text = true
	_line_edit.text = ""
	_suppress_text = false

func select(idx: int) -> void:
	"""Select an item by index and display its text."""
	if idx < 0 or idx >= _data.size():
		_selected_idx = -1
		return
	_selected_idx = idx
	_suppress_text = true
	_line_edit.text = _data[idx]["text"]
	_line_edit.caret_column = 0
	_suppress_text = false

func set_item_metadata(idx: int, value) -> void:
	if idx >= 0 and idx < _data.size():
		_data[idx]["metadata"] = value

func get_item_metadata(idx: int):
	if idx >= 0 and idx < _data.size():
		return _data[idx]["metadata"]
	return null

func get_item_text(idx: int) -> String:
	if idx >= 0 and idx < _data.size():
		return _data[idx]["text"]
	return ""

## Set per-item foreground colour (for VB6 bold emulation).
## Use a dim colour for unimplemented events, leave implemented at default.
func set_item_custom_color(idx: int, color: Color) -> void:
	if idx >= 0 and idx < _item_list.item_count:
		_item_list.set_item_custom_fg_color(idx, color)

# ============================================================
# Popup management
# ============================================================

func _on_arrow_pressed() -> void:
	if _popup_just_closed:
		return
	_toggle_popup()

func _toggle_popup() -> void:
	if _popup.visible:
		_popup.hide()
	else:
		_show_popup()

func _show_popup() -> void:
	if _data.is_empty():
		return
	var scr := get_screen_position()
	var sz := size
	# 28 px per item + 20 px panel padding, min 60 px, max 300 px
	var h := clampi(_data.size() * 28 + 20, 60, 300)
	_popup.popup(Rect2i(int(scr.x), int(scr.y + sz.y), int(sz.x), h))
	# Highlight current selection
	if _selected_idx >= 0 and _selected_idx < _data.size():
		_item_list.select(_selected_idx)
		_item_list.ensure_current_is_visible()

func _on_popup_hide() -> void:
	# Prevent the arrow button click from immediately re-opening the popup
	# (the popup closes on focus-loss before the button press fires).
	_popup_just_closed = true
	if is_inside_tree():
		get_tree().create_timer(0.15).timeout.connect(_clear_popup_flag, CONNECT_ONE_SHOT)

func _clear_popup_flag() -> void:
	_popup_just_closed = false

# ============================================================
# Type-ahead search
# ============================================================

func _on_text_changed(new_text: String) -> void:
	if _suppress_text:
		return
	# Open the popup while the user is typing
	if not _popup.visible:
		_show_popup()
	if new_text.is_empty():
		return
	# Scroll to first item whose text starts with the typed prefix
	var prefix := new_text.to_lower()
	for i in _data.size():
		if _data[i]["text"].to_lower().begins_with(prefix):
			_item_list.select(i)
			_item_list.ensure_current_is_visible()
			return

# ============================================================
# Keyboard navigation
# ============================================================

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var kc := (event as InputEventKey).keycode
	if kc == KEY_DOWN:
		if not _popup.visible:
			_show_popup()
		else:
			_move_selection(1)
	elif kc == KEY_UP:
		if _popup.visible:
			_move_selection(-1)
	elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
		if _popup.visible:
			_commit_list_selection()
	elif kc == KEY_ESCAPE:
		if _popup.visible:
			_popup.hide()
			# Restore previously committed text
			if _selected_idx >= 0 and _selected_idx < _data.size():
				_suppress_text = true
				_line_edit.text = _data[_selected_idx]["text"]
				_suppress_text = false

func _move_selection(delta: int) -> void:
	var sel := _item_list.get_selected_items()
	var cur := sel[0] if sel.size() > 0 else -1
	var nxt := clampi(cur + delta, 0, _data.size() - 1)
	_item_list.select(nxt)
	_item_list.ensure_current_is_visible()

# ============================================================
# Item selection / commit
# ============================================================

func _on_item_clicked(idx: int, _pos: Vector2, _btn: int) -> void:
	_commit_selection(idx)

func _on_item_activated(idx: int) -> void:
	_commit_selection(idx)

func _commit_list_selection() -> void:
	var sel := _item_list.get_selected_items()
	if sel.size() > 0:
		_commit_selection(sel[0])

func _commit_selection(idx: int) -> void:
	if idx < 0 or idx >= _data.size():
		return
	_selected_idx = idx
	_suppress_text = true
	_line_edit.text = _data[idx]["text"]
	_line_edit.caret_column = 0
	_suppress_text = false
	_popup.hide()
	item_selected.emit(idx)
