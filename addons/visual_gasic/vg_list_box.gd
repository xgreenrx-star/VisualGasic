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

## RemoveItem index — Remove the item at the given index.
func RemoveItem(index: int) -> void:
	if index >= 0 and index < item_count:
		remove_item(index)

## Clear — Remove all items and reset.
func Clear() -> void:
	clear()
	_new_index = -1

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

func _ready() -> void:
	if not item_clicked.is_connected(_on_item_clicked):
		item_clicked.connect(_on_item_clicked)
	if not item_activated.is_connected(_on_item_activated):
		item_activated.connect(_on_item_activated)

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
