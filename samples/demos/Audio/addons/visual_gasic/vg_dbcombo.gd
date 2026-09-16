@tool
extends Control
## VGDBCombo — VB6-style data-bound combo box control.
##
## Populates a dropdown from a Data control's Recordset column.
## Can display one column (ListField) while binding the value from another
## column (BoundColumn) — just like VB6's DBCombo.
##
## VB6-compatible API:
##   Properties: DataSource, DataField, ListField, BoundColumn, RowSource, Text
##   Methods:    Refresh
##   Events:     Click, Change

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

signal Click()
signal Change(new_text: String)

# =============================================================================
# Properties
# =============================================================================

## Name of the Data control on the form to bind to.
@export var DataSource: String = ""

## Column name to read/write the bound value from the recordset.
@export var DataField: String = ""

## Column name displayed in the dropdown list.
@export var ListField: String = ""

## Column name whose value is stored as the bound value.
@export var BoundColumn: String = ""

## Optional SQL override for the dropdown list population.
## If empty, uses DataSource's Recordset with ListField column.
@export var RowSource: String = ""

## Tag — general-purpose string.
@export var Tag: String = ""

# =============================================================================
# Internal
# =============================================================================

var _option_btn: OptionButton
var _data_control = null
var _items_data: Array = []     # Array of {display, value}
var _vb6_props: Dictionary = {}
var _suppress_change: bool = false

# =============================================================================
# Public API
# =============================================================================

## The current display text.
var Text: String:
	get:
		if _option_btn and _option_btn.selected >= 0:
			return _option_btn.get_item_text(_option_btn.selected)
		return ""
	set(v):
		if _option_btn:
			for i in _option_btn.item_count:
				if _option_btn.get_item_text(i) == v:
					_option_btn.select(i)
					return

## The bound value of the currently selected item.
var BoundValue: Variant:
	get:
		if _option_btn and _option_btn.selected >= 0 and _option_btn.selected < _items_data.size():
			return _items_data[_option_btn.selected].get("value", "")
		return ""

## Index of the currently selected item.
var ListIndex: int:
	get:
		if _option_btn:
			return _option_btn.selected
		return -1
	set(v):
		if _option_btn and v >= 0 and v < _option_btn.item_count:
			_option_btn.select(v)

## Number of items.
var ListCount: int:
	get:
		if _option_btn:
			return _option_btn.item_count
		return 0

# =============================================================================
# Lifecycle
# =============================================================================

func _ready():
	custom_minimum_size = Vector2(150, 25)
	
	_option_btn = OptionButton.new()
	_option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_option_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_option_btn.item_selected.connect(_on_item_selected)
	add_child(_option_btn)
	
	if Engine.is_editor_hint():
		_option_btn.add_item("(DBCombo)")
		return
	
	call_deferred("_bind_data_source")

func _bind_data_source() -> void:
	if DataSource.is_empty():
		return
	var parent = get_parent()
	if not parent:
		return
	_data_control = parent.find_child(DataSource, false, false)
	if not _data_control:
		for child in parent.get_children():
			if child.name.nocasecmp_to(DataSource) == 0:
				_data_control = child
				break
	if _data_control:
		if _data_control.has_signal("Reposition"):
			_data_control.Reposition.connect(_on_data_reposition)
		call_deferred("Refresh")

func Refresh() -> void:
	"""Populate the dropdown from the DataSource."""
	if not _option_btn:
		return
	_suppress_change = true
	_option_btn.clear()
	_items_data.clear()
	
	if not _data_control:
		_suppress_change = false
		return
	
	var rs = _data_control.Recordset
	if not rs or not rs.IsOpen:
		_suppress_change = false
		return
	
	# Determine display and value columns
	var display_col = ListField if not ListField.is_empty() else DataField
	var value_col = BoundColumn if not BoundColumn.is_empty() else display_col
	
	if display_col.is_empty():
		# Use first column
		var cols = rs.get_column_names()
		if cols.size() > 0:
			display_col = cols[0]
			if value_col.is_empty():
				value_col = display_col
	
	if display_col.is_empty():
		_suppress_change = false
		return
	
	# If RowSource is set, query separately
	var source_rows: Array
	if not RowSource.is_empty() and _data_control.has_method("get") and _data_control.get("_db"):
		var db = _data_control._db
		if db and db.get_is_open():
			source_rows = db.Query(RowSource)
		else:
			source_rows = rs.get_rows()
	else:
		source_rows = rs.get_rows()
	
	# Populate
	for row in source_rows:
		var display_text = str(row.get(display_col, ""))
		var bound_value = row.get(value_col, display_text)
		_option_btn.add_item(display_text)
		_items_data.append({"display": display_text, "value": bound_value})
	
	_suppress_change = false
	
	# Select based on current record's DataField value
	_sync_to_current_record()

func _sync_to_current_record() -> void:
	"""Select the item matching the current record's DataField value."""
	if not _data_control or DataField.is_empty():
		return
	var rs = _data_control.Recordset
	if not rs or rs.BOF or rs.EOF:
		return
	var current_val = rs.Fields(DataField)
	var value_col = BoundColumn if not BoundColumn.is_empty() else DataField
	for i in _items_data.size():
		if str(_items_data[i].get("value", "")) == str(current_val):
			_suppress_change = true
			_option_btn.select(i)
			_suppress_change = false
			return

func _on_data_reposition() -> void:
	_sync_to_current_record()

func _on_item_selected(idx: int) -> void:
	if _suppress_change:
		return
	Click.emit()
	if _option_btn:
		Change.emit(_option_btn.get_item_text(idx))
	# Update the DataField in the current record
	if _data_control and not DataField.is_empty() and idx < _items_data.size():
		var rs = _data_control.Recordset
		if rs and rs.IsOpen and not rs.BOF and not rs.EOF:
			var value_col = BoundColumn if not BoundColumn.is_empty() else DataField
			rs.Edit()
			rs.SetField(DataField, _items_data[idx].get("value", ""))
			rs.Update()

# =============================================================================
# Form Designer support
# =============================================================================

func _set(property: StringName, value) -> bool:
	match str(property):
		"Enabled", "Visible", "Tag", "FontSize", "BackColor", "ForeColor", \
		"TabStop", "ToolTipText":
			_vb6_props[str(property)] = value
			return true
	return false

func _get(property: StringName):
	var key = str(property)
	if _vb6_props.has(key):
		return _vb6_props[key]
	return null
