@tool
extends ItemList
## VGListBox — VB6-faithful ListBox control.
##
## Wraps Godot's ItemList with the standard VB6 ListBox API.
## All native ItemList functionality is preserved — this only ADDS the VB6 layer.
##
## VB6-compatible API:
##   Properties: Text, List(i), ListIndex, ListCount, Sorted, NewIndex,
##               ItemData(i), Selected(i), SelCount, Tag
##   Methods:    AddItem, RemoveItem, Clear, SetFocus, SetList, GetItemData, SetItemData
##   Events:     Click, DblClick

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

## Click — fires when the user clicks/selects an item (VB6: Click event).
signal Click()

## DblClick — fires when the user double-clicks an item (VB6: DblClick event).
signal DblClick()

# =============================================================================
# Internal state
# =============================================================================

var _new_index: int = -1
var _sorted: bool = false
var _vb6_props: Dictionary = {}

# =============================================================================
# VB6 Properties
# =============================================================================

## Text — text of the currently selected item.
var Text: String:
	get:
		var sel := get_selected_items()
		if sel.size() > 0 and sel[0] < item_count:
			return get_item_text(sel[0])
		return ""
	set(v):
		for i in item_count:
			if get_item_text(i) == v:
				select(i)
				return

## ListIndex — index of the selected item (-1 = none).
var ListIndex: int:
	get:
		var sel := get_selected_items()
		return sel[0] if sel.size() > 0 else -1
	set(v):
		if v >= 0 and v < item_count:
			select(v)
			ensure_current_is_visible()
		else:
			deselect_all()

## ListCount — number of items (read-only).
var ListCount: int:
	get: return item_count

## Sorted — if true, items are kept in alphabetical order.
@export var Sorted: bool = false:
	get: return _sorted
	set(v):
		_sorted = v
		if _sorted and item_count > 1:
			_resort()

## NewIndex — index of the most recently added item (read-only).
var NewIndex: int:
	get: return _new_index

## SelCount — number of selected items (read-only, for MultiSelect).
var SelCount: int:
	get: return get_selected_items().size()

## List — design-time items (one per entry). Set in the Inspector to pre-populate.
## In VB6, this is the List property in the Properties window.
@export var DesignTimeList: PackedStringArray = []:
	set(v):
		DesignTimeList = v
		if is_inside_tree() or Engine.is_editor_hint():
			_load_design_time_list()

## Tag — general-purpose string storage (VB6 convention).
@export var Tag: String = ""

# =============================================================================
# VB6 Methods
# =============================================================================

## AddItem text [, index] — Insert an item. If Sorted, index is ignored.
func AddItem(item_text: String, index: int = -1) -> void:
	if _sorted:
		var pos := _find_sorted_pos(item_text)
		add_item(item_text)
		var last := item_count - 1
		if pos < last:
			move_item(last, pos)
		_new_index = pos
	elif index >= 0 and index < item_count:
		add_item(item_text)
		var last := item_count - 1
		if index < last:
			move_item(last, index)
		_new_index = index
	else:
		add_item(item_text)
		_new_index = item_count - 1
	call_deferred("_apply_vb6_scrollbar_theme")

## RemoveItem index — Remove the item at the given index.
func RemoveItem(index: int) -> void:
	if index >= 0 and index < item_count:
		remove_item(index)
		call_deferred("_apply_vb6_scrollbar_theme")

## Clear — Remove all items and reset.
func Clear() -> void:
	clear()
	_new_index = -1
	call_deferred("_apply_vb6_scrollbar_theme")

## SetFocus — Give keyboard focus to this control.
func SetFocus() -> void:
	grab_focus()

## List(index) — Get the text of an item by index.
func List(index: int) -> String:
	if index >= 0 and index < item_count:
		return get_item_text(index)
	return ""

## SetList(index, value) — Set the text of an item by index.
func SetList(index: int, value: String) -> void:
	if index >= 0 and index < item_count:
		set_item_text(index, value)
		if _sorted:
			_resort()

## GetItemData(index) — Get per-item integer data (VB6 convention).
func GetItemData(index: int) -> int:
	if index >= 0 and index < item_count:
		var meta = get_item_metadata(index)
		return meta if meta is int else 0
	return 0

## SetItemData(index, value) — Set per-item integer data.
func SetItemData(index: int, value: int) -> void:
	if index >= 0 and index < item_count:
		set_item_metadata(index, value)

## Selected(index) — Returns true if the item at index is selected (for MultiSelect).
func Selected(index: int) -> bool:
	if index >= 0 and index < item_count:
		return is_selected(index)
	return false

# =============================================================================
# Construction
# =============================================================================

func _enter_tree() -> void:
	_apply_vb6_hover_theme()
	_apply_vb6_scrollbar_theme()

func _ready() -> void:
	if not Engine.is_editor_hint():
		if not item_clicked.is_connected(_on_item_clicked):
			item_clicked.connect(_on_item_clicked)
		if not item_activated.is_connected(_on_item_activated):
			item_activated.connect(_on_item_activated)
	_load_design_time_list()

## Godot 4.6+ ItemList hover uses font_hovered_color (default ~white). On VB6 white
## ListBox background that is unreadable; VB6 only highlights the selected row (navy).
func _apply_vb6_hover_theme() -> void:
	add_theme_color_override("font_hovered_color", Color(0, 0, 0, 1))
	add_theme_color_override("font_hovered_selected_color", Color(1, 1, 1, 1))
	add_theme_stylebox_override("hovered", StyleBoxEmpty.new())
	var sel := get_theme_stylebox("selected")
	if sel:
		add_theme_stylebox_override("hovered_selected", sel)
		add_theme_stylebox_override("hovered_selected_focus", sel)

## VB6 ListBox shows a vertical scrollbar when items overflow. ItemList scrolls
## internally but the editor/default theme grabber is often invisible — style it.
func _apply_vb6_scrollbar_theme() -> void:
	var vbar := get_v_scroll_bar()
	if vbar == null:
		return
	var scrollbar_bg := Color(0.87, 0.87, 0.87)
	var btn_face := Color(0.83, 0.83, 0.83)
	var btn_shadow := Color(0.50, 0.50, 0.50)
	var track := StyleBoxFlat.new()
	track.bg_color = scrollbar_bg
	track.set_content_margin_all(0)
	var grab := StyleBoxFlat.new()
	grab.bg_color = btn_face
	grab.border_color = btn_shadow
	grab.set_border_width_all(1)
	grab.set_corner_radius_all(0)
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	grab.content_margin_top = 2
	grab.content_margin_bottom = 2
	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("scroll_focus", track)
	vbar.add_theme_stylebox_override("grabber", grab)
	vbar.add_theme_stylebox_override("grabber_highlight", grab)
	vbar.add_theme_stylebox_override("grabber_pressed", grab)
	vbar.custom_minimum_size.x = 12

func _load_design_time_list() -> void:
	if DesignTimeList.is_empty():
		return
	# Only populate if list is currently empty (don't overwrite runtime data)
	if item_count > 0:
		return
	for item_text in DesignTimeList:
		AddItem(item_text)

func _on_item_clicked(_index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	Click.emit()

func _on_item_activated(_index: int) -> void:
	DblClick.emit()

# =============================================================================
# Sorting helpers
# =============================================================================

func _find_sorted_pos(item_text: String) -> int:
	var lower := item_text.to_lower()
	for i in item_count:
		if get_item_text(i).to_lower() > lower:
			return i
	return item_count

func _resort() -> void:
	var items: Array = []
	var sel_texts: Array = []
	for idx in get_selected_items():
		sel_texts.append(get_item_text(idx))
	for i in item_count:
		items.append({
			"text": get_item_text(i),
			"metadata": get_item_metadata(i),
		})
	items.sort_custom(func(a, b): return a["text"].to_lower() < b["text"].to_lower())
	clear()
	for entry in items:
		add_item(entry["text"])
		var idx := item_count - 1
		if entry["metadata"] != null:
			set_item_metadata(idx, entry["metadata"])
	# Restore selection by text
	for t in sel_texts:
		for i in item_count:
			if get_item_text(i) == t:
				select(i, false)
				break

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
