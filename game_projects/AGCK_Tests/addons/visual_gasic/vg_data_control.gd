@tool
extends Node
## VGDataControl — VB6-style Data control for SQLite database binding.
##
## The Data control provides a simple way to connect forms to a SQLite database.
## It creates and manages a VGRecordset internally, providing navigation and
## data binding to DBGrid and DBCombo controls on the form.
##
## VB6-compatible API:
##   Properties: DatabaseName, RecordSource, ReadOnly, BOFAction, EOFAction
##   Methods:    Refresh, UpdateRecord, UpdateControls
##   Events:     Reposition, Validate, Error

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

## Reposition — fires when the cursor moves to a different record.
signal Reposition()

## Validate — fires before any navigation/update (can cancel).
signal Validate(action: int, save: bool)

## Error — fires when a database error occurs.
signal Error(error_text: String)

# =============================================================================
# Properties
# =============================================================================

## Path to the SQLite database file (relative to project or absolute).
@export var DatabaseName: String = "":
	set(v):
		DatabaseName = v
		if Engine.is_editor_hint():
			return
		_reconnect()

## SQL query or table name for the recordset.
@export var RecordSource: String = "":
	set(v):
		RecordSource = v
		if Engine.is_editor_hint():
			return
		_requery()

## If true, the recordset is read-only (no AddNew/Update/Delete).
@export var ReadOnly: bool = false

## BOFAction: 0 = MoveFirst, 1 = BOF (stay at BOF)
@export_enum("MoveFirst:0", "BOF:1") var BOFAction: int = 0

## EOFAction: 0 = MoveLast, 1 = EOF (stay at EOF), 2 = AddNew
@export_enum("MoveLast:0", "EOF:1", "AddNew:2") var EOFAction: int = 0

## Tag — general-purpose string (VB6 standard).
@export var Tag: String = ""

## Caption — displayed label text (VB6 Data control shows a label).
@export var Caption: String = "Data1"

# =============================================================================
# Internal state
# =============================================================================

var _db = null          # VGDatabase instance
var _recordset = null   # VGRecordset instance
var _is_ready: bool = false

# =============================================================================
# Public API
# =============================================================================

## The Recordset bound to this Data control.
var Recordset:
	get:
		return _recordset

## Refresh — re-opens the database and re-queries.
func Refresh() -> void:
	_reconnect()

## UpdateRecord — commits any pending edit to the database.
func UpdateRecord() -> void:
	if _recordset and _recordset.IsOpen:
		_recordset.Update()

## UpdateControls — notifies bound controls to refresh their display.
func UpdateControls() -> void:
	Reposition.emit()

## Navigate forward one record.
func MoveNext() -> void:
	if not _recordset or not _recordset.IsOpen:
		return
	_recordset.MoveNext()
	if _recordset.EOF:
		match EOFAction:
			0: _recordset.MoveLast()
			2:
				if not ReadOnly:
					_recordset.AddNew()
	Reposition.emit()

## Navigate backward one record.
func MovePrevious() -> void:
	if not _recordset or not _recordset.IsOpen:
		return
	_recordset.MovePrevious()
	if _recordset.BOF:
		match BOFAction:
			0: _recordset.MoveFirst()
	Reposition.emit()

## Navigate to first record.
func MoveFirst() -> void:
	if not _recordset or not _recordset.IsOpen:
		return
	_recordset.MoveFirst()
	Reposition.emit()

## Navigate to last record.
func MoveLast() -> void:
	if not _recordset or not _recordset.IsOpen:
		return
	_recordset.MoveLast()
	Reposition.emit()

# =============================================================================
# Lifecycle
# =============================================================================

func _ready():
	if Engine.is_editor_hint():
		return
	_is_ready = true
	if not DatabaseName.is_empty() and not RecordSource.is_empty():
		call_deferred("_reconnect")

func _reconnect() -> void:
	if Engine.is_editor_hint() or not _is_ready:
		return
	# Close existing
	if _recordset:
		_recordset.Close()
		_recordset = null
	if _db:
		_db.Close()
		_db = null
	
	if DatabaseName.is_empty():
		return
	
	# Resolve path
	var path = DatabaseName
	if not path.begins_with("/") and not path.begins_with("res://") and not path.begins_with("user://"):
		path = "res://" + path
	# For SQLite, use the global path
	if path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	elif path.begins_with("user://"):
		path = ProjectSettings.globalize_path(path)
	
	# Create database connection
	_db = ClassDB.instantiate("VGDatabase")
	if not _db:
		Error.emit("Failed to create VGDatabase — SQLite may not be available")
		return
	
	if not _db.Open(path):
		Error.emit("Failed to open database: " + path + " — " + str(_db.get_last_error()))
		_db = null
		return
	
	_requery()

func _requery() -> void:
	if Engine.is_editor_hint() or not _is_ready:
		return
	if not _db or not _db.get_is_open():
		return
	if RecordSource.is_empty():
		return
	
	# Create recordset
	_recordset = ClassDB.instantiate("VGRecordset")
	if not _recordset:
		Error.emit("Failed to create VGRecordset")
		return
	
	_recordset.Open(RecordSource, _db)
	Reposition.emit()

# =============================================================================
# Form Designer support (_set/_get for VB6 property persistence)
# =============================================================================

var _vb6_props: Dictionary = {}

func _set(property: StringName, value) -> bool:
	match str(property):
		"Enabled", "Visible", "Tag", "FontSize", "BackColor", "ForeColor":
			_vb6_props[str(property)] = value
			return true
	return false

func _get(property: StringName):
	var key = str(property)
	if _vb6_props.has(key):
		return _vb6_props[key]
	return null
