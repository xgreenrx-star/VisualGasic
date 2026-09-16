@tool
extends Control
## VGComboBox — VB6-faithful ComboBox control.
##
## Replicates the VB6 ComboBox with all standard properties, methods, events,
## and three Style modes:
##   0 = vbComboDropDown   — editable text + dropdown list (default)
##   1 = vbComboSimple     — editable text + always-visible list
##   2 = vbComboDropDownList — read-only text + dropdown list
##
## VB6-compatible API:
##   Properties: Text, List(i), ListIndex, ListCount, Sorted, Locked,
##               NewIndex, ItemData(i), Style, Enabled, Tag
##   Methods:    AddItem, RemoveItem, Clear, SetFocus
##   Events:     Click (item_selected), Change (text_changed), DropDown

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

## Click — fires when the user selects an item (VB6: Click event).
signal item_selected(index: int)

## Change — fires when the edit text changes (VB6: Change event).
signal text_changed(new_text: String)

## DropDown — fires when the dropdown list opens (VB6: DropDown event).
signal dropdown_opened()

# =============================================================================
# Style constants (match VB6)
# =============================================================================

const vbComboDropDown: int = 0      ## Editable text + dropdown
const vbComboSimple: int = 1        ## Editable text + always-visible list
const vbComboDropDownList: int = 2  ## Read-only text + dropdown

# =============================================================================
# Internal nodes
# =============================================================================

var _line_edit: LineEdit
var _arrow_btn: Button
var _popup: PopupPanel         # Popup for Style 0 and 2
var _popup_list: ItemList       # ItemList inside the popup
var _inline_list: ItemList      # Always-visible list for Style 1
var _item_list: ItemList        # Points to whichever list is active

# =============================================================================
# Internal data
# =============================================================================

var _data: Array = []            # [{text, item_data, metadata}]
var _selected_idx: int = -1
var _new_index: int = -1
var _suppress_text: bool = false
var _popup_just_closed: bool = false
var _sorted: bool = false
var _style: int = vbComboDropDown
var _locked: bool = false
var _vb6_props: Dictionary = {}

# =============================================================================
# VB6 Properties
# =============================================================================

## Style — 0=DropdownCombo, 1=SimpleCombo, 2=DropdownList.
@export_enum("DropdownCombo:0", "SimpleCombo:1", "DropdownList:2")
var Style: int = 0:
	get: return _style
	set(v):
		if _style == v:
			return
		_style = v
		_apply_style()

## Text — the text displayed in the edit area.
var Text: String:
	get:
		if _line_edit:
			return _line_edit.text
		return ""
	set(v):
		if not _line_edit:
			return
		if _style == vbComboDropDownList:
			for i in _data.size():
				if _data[i]["text"] == v:
					select(i)
					return
		else:
			_suppress_text = true
			_line_edit.text = v
			_suppress_text = false

## ListIndex — index of the selected item (-1 = none).
var ListIndex: int:
	get: return _selected_idx
	set(v): select(v)

## ListCount — number of items (read-only).
var ListCount: int:
	get: return _data.size()

## Sorted — keep items in alphabetical order.
@export var Sorted: bool = false:
	get: return _sorted
	set(v):
		_sorted = v
		if _sorted and _data.size() > 1:
			_resort()

## Locked — make the text area read-only (Style 0/1 only).
@export var Locked: bool = false:
	get: return _locked
	set(v):
		_locked = v
		if _line_edit:
			_line_edit.editable = not _locked and _style != vbComboDropDownList

## NewIndex — index of the most recently added item (read-only).
var NewIndex: int:
	get: return _new_index

## List — design-time items (one per entry). Set in the Inspector to pre-populate.
## In VB6, this is the List property in the Properties window.
@export var DesignTimeList: PackedStringArray = []:
	set(v):
		DesignTimeList = v
		if is_inside_tree() or Engine.is_editor_hint():
			_load_design_time_list()

## Tag — general-purpose variant storage (VB6 convention).
@export var Tag: String = ""

## Enabled — whether the control accepts input.
var Enabled: bool:
	get:
		if _line_edit:
			return not _line_edit.editable == false and _style == vbComboDropDownList or _line_edit.editable
		return true
	set(v):
		if _line_edit:
			_line_edit.editable = v and not _locked and _style != vbComboDropDownList
		if _arrow_btn:
			_arrow_btn.disabled = not v

# Legacy / code_navigator compat aliases
var item_count: int:
	get: return _data.size()

var selected: int:
	get: return _selected_idx

# =============================================================================
# VB6 Methods
# =============================================================================

## AddItem text [, index] — Insert an item. If Sorted, index is ignored.
func AddItem(text: String, index: int = -1) -> void:
	var entry := {"text": text, "item_data": 0, "metadata": null}
	if _sorted:
		var pos := _find_sorted_pos(text)
		_data.insert(pos, entry)
		_rebuild_item_list()
		_new_index = pos
	elif index >= 0 and index <= _data.size():
		_data.insert(index, entry)
		_rebuild_item_list()
		_new_index = index
	else:
		_data.append(entry)
		if _item_list and is_instance_valid(_item_list):
			_item_list.add_item(text)
		_new_index = _data.size() - 1

## RemoveItem index — Remove the item at index.
func RemoveItem(index: int) -> void:
	if index < 0 or index >= _data.size():
		return
	_data.remove_at(index)
	if _item_list and is_instance_valid(_item_list):
		_item_list.remove_item(index)
	if _selected_idx == index:
		_selected_idx = -1
		if _line_edit and is_instance_valid(_line_edit):
			_suppress_text = true
			_line_edit.text = ""
			_suppress_text = false
	elif _selected_idx > index:
		_selected_idx -= 1

## Clear — Remove all items and reset.
func Clear() -> void:
	_data.clear()
	if _item_list and is_instance_valid(_item_list):
		_item_list.clear()
	_selected_idx = -1
	_new_index = -1
	if _line_edit and is_instance_valid(_line_edit):
		_suppress_text = true
		_line_edit.text = ""
		_suppress_text = false

## SetFocus — Give keyboard focus to the text area.
func SetFocus() -> void:
	if _line_edit:
		_line_edit.grab_focus()

## List(index) — Get the text of an item.
func List(index: int) -> String:
	if index >= 0 and index < _data.size():
		return _data[index]["text"]
	return ""

## SetList(index, value) — Set the text of an item.
func SetList(index: int, value: String) -> void:
	if index < 0 or index >= _data.size():
		return
	_data[index]["text"] = value
	_item_list.set_item_text(index, value)
	if index == _selected_idx:
		_suppress_text = true
		_line_edit.text = value
		_suppress_text = false
	if _sorted:
		_resort()

## ItemData(index) — Get per-item integer data (VB6 convention).
func GetItemData(index: int) -> int:
	if index >= 0 and index < _data.size():
		return _data[index]["item_data"]
	return 0

## SetItemData(index, value) — Set per-item integer data.
func SetItemData(index: int, value: int) -> void:
	if index >= 0 and index < _data.size():
		_data[index]["item_data"] = value

# =============================================================================
# OptionButton / code_navigator compat API
# =============================================================================

func add_item(text: String, _id: int = -1) -> void:
	AddItem(text)

func clear() -> void:
	Clear()

func select(idx: int) -> void:
	if idx < 0 or idx >= _data.size():
		_selected_idx = -1
		return
	_selected_idx = idx
	if _line_edit and is_instance_valid(_line_edit):
		_suppress_text = true
		_line_edit.text = _data[idx]["text"]
		_line_edit.caret_column = 0
		_suppress_text = false

func set_item_metadata(idx: int, value) -> void:
	if idx >= 0 and idx < _data.size():
		_data[idx]["metadata"] = value

func get_item_metadata(idx: int):
	if idx >= 0 and idx < _data.size():
		return _data[idx].get("metadata", null)
	return null

func get_item_text(idx: int) -> String:
	return List(idx)

func set_item_custom_color(idx: int, color: Color) -> void:
	if _item_list and is_instance_valid(_item_list) and idx >= 0 and idx < _item_list.item_count:
		_item_list.set_item_custom_fg_color(idx, color)

# =============================================================================
# Construction
# =============================================================================

func _init():
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

func _ready():
	# Guard: don't re-create children if they already exist (scene reload)
	if _line_edit and is_instance_valid(_line_edit):
		_load_design_time_list()
		return
	_build_ui()
	_apply_style()
	_load_design_time_list()

func _build_ui() -> void:
	var in_editor := Engine.is_editor_hint()
	var arrow_w := 22

	# --- LineEdit (fills left, leaves room for arrow) ---
	_line_edit = LineEdit.new()
	_line_edit.name = &"_LE"
	_line_edit.set_anchors_preset(PRESET_FULL_RECT)
	_line_edit.offset_right = -arrow_w
	_line_edit.select_all_on_focus = true
	_line_edit.gui_input.connect(_on_line_edit_gui_input)
	_line_edit.text_changed.connect(_on_text_changed)
	add_child(_line_edit, false, INTERNAL_MODE_FRONT)

	# --- ▼ Arrow Button (anchored to right edge) ---
	_arrow_btn = Button.new()
	_arrow_btn.name = &"_AB"
	_arrow_btn.anchor_left = 1.0
	_arrow_btn.anchor_right = 1.0
	_arrow_btn.anchor_top = 0.0
	_arrow_btn.anchor_bottom = 1.0
	_arrow_btn.offset_left = -arrow_w
	_arrow_btn.offset_right = 0
	_arrow_btn.offset_top = 0
	_arrow_btn.offset_bottom = 0
	_arrow_btn.focus_mode = Control.FOCUS_NONE
	_arrow_btn.pressed.connect(_on_arrow_pressed)
	add_child(_arrow_btn, false, INTERNAL_MODE_FRONT)
	_update_arrow_icon()

	# --- Popup + ItemList (Style 0 / 2) ---
	_popup = PopupPanel.new()
	_popup.name = &"_PP"
	_popup.popup_hide.connect(_on_popup_hide)
	_popup_list = ItemList.new()
	_popup_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_list.auto_height = false
	_popup_list.item_clicked.connect(_on_item_clicked)
	_popup_list.item_activated.connect(_on_item_activated)
	_popup.add_child(_popup_list)
	add_child(_popup, false, INTERNAL_MODE_FRONT)

	# --- Inline ItemList (Style 1) ---
	_inline_list = ItemList.new()
	_inline_list.name = &"_IL"
	_inline_list.set_anchors_preset(PRESET_FULL_RECT)
	_inline_list.custom_minimum_size = Vector2(0, 100)
	_inline_list.auto_height = false
	_inline_list.visible = false
	_inline_list.item_clicked.connect(_on_item_clicked)
	_inline_list.item_activated.connect(_on_item_activated)

	# Active list pointer
	_item_list = _popup_list

func _load_design_time_list() -> void:
	if DesignTimeList.is_empty():
		return
	if not _item_list:
		return
	# Only populate if list is currently empty (don't overwrite runtime data)
	if _data.size() > 0:
		return
	for item_text in DesignTimeList:
		AddItem(item_text)

func _notification(what: int):
	if what == NOTIFICATION_THEME_CHANGED:
		# Defer so the call runs after any reparent sequence is complete and
		# the editor theme is fully re-established. A direct call here can
		# fire mid-remove_child when get_theme_icon() returns null, leaving
		# the button in a corrupted icon+text state.
		_update_arrow_icon.call_deferred()
	elif what == NOTIFICATION_READY:
		_update_arrow_icon()
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _update_layout() -> void:
	if not _line_edit or not is_instance_valid(_line_edit):
		return
	var arrow_w := 22 if (_arrow_btn and _arrow_btn.visible) else 0
	_line_edit.offset_right = -arrow_w

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
		_arrow_btn.icon = null  # prevent icon+text coexistence on theme-change race
		_arrow_btn.text = "▼"

# =============================================================================
# Style management
# =============================================================================

func _apply_style() -> void:
	if not _line_edit or not is_instance_valid(_line_edit):
		return
	match _style:
		vbComboDropDown:
			_line_edit.editable = not _locked
			if _arrow_btn: _arrow_btn.visible = true
			if _inline_list: _inline_list.visible = false
			_item_list = _popup_list
		vbComboSimple:
			_line_edit.editable = not _locked
			if _arrow_btn: _arrow_btn.visible = false
			if _inline_list: _inline_list.visible = true
			_item_list = _inline_list
			_reparent_inline_list()
		vbComboDropDownList:
			_line_edit.editable = false
			if _arrow_btn: _arrow_btn.visible = true
			if _inline_list: _inline_list.visible = false
			_item_list = _popup_list
	_update_layout()
	_rebuild_item_list()

func _reparent_inline_list() -> void:
	if not is_inside_tree():
		return
	if not _inline_list or not is_instance_valid(_inline_list):
		return
	if _inline_list.get_parent():
		return
	# Keep inline list as our own internal child
	add_child(_inline_list, false, INTERNAL_MODE_FRONT)

# =============================================================================
# Sorting
# =============================================================================

func _find_sorted_pos(text: String) -> int:
	var lower := text.to_lower()
	for i in _data.size():
		if _data[i]["text"].to_lower() > lower:
			return i
	return _data.size()

func _resort() -> void:
	var sel_text := ""
	if _selected_idx >= 0 and _selected_idx < _data.size():
		sel_text = _data[_selected_idx]["text"]
	_data.sort_custom(func(a, b): return a["text"].to_lower() < b["text"].to_lower())
	_rebuild_item_list()
	if not sel_text.is_empty():
		for i in _data.size():
			if _data[i]["text"] == sel_text:
				_selected_idx = i
				return
	_selected_idx = -1

func _rebuild_item_list() -> void:
	if not _item_list or not is_instance_valid(_item_list):
		return
	_item_list.clear()
	for entry in _data:
		_item_list.add_item(entry["text"])

# =============================================================================
# Popup management
# =============================================================================

func _on_arrow_pressed() -> void:
	if _popup_just_closed:
		return
	if _style == vbComboSimple:
		return
	if not _popup or not is_instance_valid(_popup):
		return
	_toggle_popup()

func _toggle_popup() -> void:
	if not _popup or not is_instance_valid(_popup):
		return
	if _popup.visible:
		_popup.hide()
	else:
		_show_popup()

func _show_popup() -> void:
	if _data.is_empty():
		return
	if _style == vbComboSimple:
		return
	if not _popup or not is_instance_valid(_popup):
		return
	var scr := get_screen_position()
	var sz := size
	var h := clampi(_data.size() * 28 + 20, 60, 300)
	_popup.popup(Rect2i(int(scr.x), int(scr.y + sz.y), int(sz.x), h))
	dropdown_opened.emit()
	if _selected_idx >= 0 and _selected_idx < _data.size():
		_item_list.select(_selected_idx)
		_item_list.ensure_current_is_visible()

func _on_popup_hide() -> void:
	_popup_just_closed = true
	if is_inside_tree() and get_tree():
		get_tree().create_timer(0.15).timeout.connect(_clear_popup_flag, CONNECT_ONE_SHOT)

func _clear_popup_flag() -> void:
	_popup_just_closed = false

# =============================================================================
# Type-ahead search
# =============================================================================

func _on_text_changed(new_text: String) -> void:
	if _suppress_text:
		return
	text_changed.emit(new_text)
	if _popup and is_instance_valid(_popup) and _style != vbComboSimple and not _popup.visible:
		_show_popup()
	if new_text.is_empty():
		return
	var prefix := new_text.to_lower()
	for i in _data.size():
		if _data[i]["text"].to_lower().begins_with(prefix):
			_item_list.select(i)
			_item_list.ensure_current_is_visible()
			return

# =============================================================================
# Keyboard navigation
# =============================================================================

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var kc := (event as InputEventKey).keycode
	var popup_vis := _popup and is_instance_valid(_popup) and _popup.visible
	if kc == KEY_DOWN:
		if _style == vbComboSimple:
			_move_selection(1)
		elif not popup_vis:
			_show_popup()
		else:
			_move_selection(1)
	elif kc == KEY_UP:
		_move_selection(-1)
	elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
		if _style == vbComboSimple:
			_commit_list_selection()
		elif popup_vis:
			_commit_list_selection()
	elif kc == KEY_ESCAPE:
		if popup_vis:
			_popup.hide()
			if _selected_idx >= 0 and _selected_idx < _data.size():
				if _line_edit and is_instance_valid(_line_edit):
					_suppress_text = true
					_line_edit.text = _data[_selected_idx]["text"]
					_suppress_text = false

func _move_selection(delta: int) -> void:
	if not _item_list or not is_instance_valid(_item_list):
		return
	var sel := _item_list.get_selected_items()
	var cur := sel[0] if sel.size() > 0 else -1
	var nxt := clampi(cur + delta, 0, _data.size() - 1)
	_item_list.select(nxt)
	_item_list.ensure_current_is_visible()

# =============================================================================
# Item selection / commit
# =============================================================================

func _on_item_clicked(idx: int, _pos: Vector2, _btn: int) -> void:
	_commit_selection(idx)

func _on_item_activated(idx: int) -> void:
	_commit_selection(idx)

func _commit_list_selection() -> void:
	if not _item_list or not is_instance_valid(_item_list):
		return
	var sel := _item_list.get_selected_items()
	if sel.size() > 0:
		_commit_selection(sel[0])

func _commit_selection(idx: int) -> void:
	if idx < 0 or idx >= _data.size():
		return
	_selected_idx = idx
	if _line_edit and is_instance_valid(_line_edit):
		_suppress_text = true
		_line_edit.text = _data[idx]["text"]
		_line_edit.caret_column = 0
		_suppress_text = false
	if _style != vbComboSimple and _popup and is_instance_valid(_popup):
		_popup.hide()
	item_selected.emit(idx)

# =============================================================================
# VB6 Common Property Handlers (Form Designer round-trip)
# =============================================================================

## Accepts VB6 properties written by the C++ Form Designer serializer.
func _set(property: StringName, value: Variant) -> bool:
	var p := String(property)
	match p:
		"Enabled":
			_vb6_props[p] = value
			return true
		"TabStop":
			focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
			_vb6_props[p] = value
			return true
		"TabIndex", "MousePointer", "Appearance", "BorderStyle", \
		"FontSize", "FontBold", "FontItalic":
			_vb6_props[p] = value
			return true
		"ToolTipText":
			tooltip_text = str(value)
			_vb6_props[p] = value
			return true
		"BackColor", "ForeColor":
			_vb6_props[p] = value
			return true
		"FontName":
			_vb6_props[p] = value
			return true
	return false

func _get(property: StringName) -> Variant:
	if _vb6_props.has(String(property)):
		return _vb6_props[String(property)]
	return null
