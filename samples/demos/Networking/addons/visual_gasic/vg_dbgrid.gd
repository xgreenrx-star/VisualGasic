@tool
extends Control
## VGDBGrid — VB6-style data-bound grid control.
##
## Displays records from a Data control's Recordset in a spreadsheet-like grid.
## Supports read/write editing, column headers, and row navigation.
##
## VB6-compatible API:
##   Properties: DataSource, AllowAddNew, AllowDelete, ReadOnly, Columns
##   Methods:    Refresh, ReBind
##   Events:     RowColChange, BeforeUpdate, AfterUpdate, Click

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

signal RowColChange(row: int, col: int)
signal BeforeUpdate(cancel: bool)
signal AfterUpdate()
signal Click()
signal DblClick()

# =============================================================================
# Properties
# =============================================================================

## Name of the Data control on the form to bind to.
@export var DataSource: String = ""

## Allow inserting new records via the grid.
@export var AllowAddNew: bool = false

## Allow deleting records via the grid.
@export var AllowDelete: bool = false

## If true, the grid is read-only.
@export var ReadOnly: bool = false

## Tag — general-purpose string.
@export var Tag: String = ""

# =============================================================================
# Internal nodes
# =============================================================================

var _tree: Tree
var _data_control = null     # Reference to the VGDataControl node
var _columns: PackedStringArray = []
var _current_row: int = -1
var _current_col: int = 0
var _vb6_props: Dictionary = {}

# =============================================================================
# Lifecycle
# =============================================================================

func _ready():
	custom_minimum_size = Vector2(300, 200)
	
	_tree = Tree.new()
	_tree.columns = 1
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	add_child(_tree)
	
	if Engine.is_editor_hint():
		# Show a placeholder in the form designer
		_show_placeholder()
		return
	
	# Find and bind to the DataSource at runtime
	call_deferred("_bind_data_source")

func _show_placeholder() -> void:
	"""Show a design-time preview grid."""
	_tree.columns = 3
	_tree.set_column_title(0, "Column1")
	_tree.set_column_title(1, "Column2")
	_tree.set_column_title(2, "Column3")
	var root = _tree.create_item()
	for i in 3:
		var item = _tree.create_item(root)
		item.set_text(0, "Data %d" % (i + 1))
		item.set_text(1, "Value %d" % (i + 1))
		item.set_text(2, "%d" % ((i + 1) * 100))

# =============================================================================
# Data Binding
# =============================================================================

func _bind_data_source() -> void:
	if DataSource.is_empty():
		return
	# Search siblings for a node with matching name
	var parent = get_parent()
	if not parent:
		return
	_data_control = parent.find_child(DataSource, false, false)
	if not _data_control:
		# Try case-insensitive
		for child in parent.get_children():
			if child.name.nocasecmp_to(DataSource) == 0:
				_data_control = child
				break
	if _data_control:
		if _data_control.has_signal("Reposition"):
			_data_control.Reposition.connect(_on_data_reposition)
		# Initial populate
		call_deferred("Refresh")

func Refresh() -> void:
	"""Reload the grid from the DataSource's Recordset."""
	_tree.clear()
	if not _data_control:
		return
	var rs = _data_control.Recordset
	if not rs or not rs.IsOpen:
		return
	
	# Set up columns from recordset column names
	_columns = rs.get_column_names()
	_tree.columns = max(_columns.size(), 1)
	for i in _columns.size():
		_tree.set_column_title(i, _columns[i])
		_tree.set_column_expand(i, true)
	
	# Populate rows
	var root = _tree.create_item()
	var all_rows = rs.get_rows()
	for row_idx in all_rows.size():
		var row_data: Dictionary = all_rows[row_idx]
		var item = _tree.create_item(root)
		for col_idx in _columns.size():
			var val = row_data.get(_columns[col_idx], "")
			item.set_text(col_idx, str(val))
			if not ReadOnly:
				item.set_editable(col_idx, true)
		item.set_metadata(0, row_idx)
	
	# Highlight current record
	_highlight_current()

func ReBind() -> void:
	"""Re-bind to the DataSource and refresh."""
	_bind_data_source()

func _highlight_current() -> void:
	if not _data_control or not _data_control.Recordset:
		return
	var rs = _data_control.Recordset
	if rs.BOF or rs.EOF:
		return
	var pos = rs.AbsolutePosition
	var root = _tree.get_root()
	if not root:
		return
	var child = root.get_first_child()
	while child:
		if child.get_metadata(0) == pos:
			child.select(0)
			_tree.scroll_to_item(child)
			break
		child = child.get_next()

func _on_data_reposition() -> void:
	_highlight_current()

func _on_item_selected() -> void:
	var item = _tree.get_selected()
	if not item:
		return
	var row_idx = item.get_metadata(0)
	if row_idx is int and row_idx != _current_row:
		_current_row = row_idx
		# Navigate the Data control's recordset
		if _data_control and _data_control.Recordset:
			_data_control.Recordset.move_to(row_idx)
			if _data_control.has_signal("Reposition"):
				_data_control.Reposition.emit()
		RowColChange.emit(_current_row, _current_col)
	Click.emit()

func _on_item_activated() -> void:
	DblClick.emit()

# =============================================================================
# Row / Col access
# =============================================================================

## Current selected row index.
var Row: int:
	get: return _current_row
	set(v):
		if _data_control and _data_control.Recordset:
			_data_control.Recordset.move_to(v)
			_highlight_current()
		_current_row = v

## Current selected column index.
var Col: int:
	get: return _current_col
	set(v): _current_col = v

## Number of visible columns.
var ColCount: int:
	get: return _columns.size()

## Number of rows in the grid.
var RowCount: int:
	get:
		if _data_control and _data_control.Recordset:
			return _data_control.Recordset.RecordCount
		return 0

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
