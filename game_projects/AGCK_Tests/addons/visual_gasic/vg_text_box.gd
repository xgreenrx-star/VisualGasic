@tool
extends LineEdit
## VGTextBox — VB6-faithful TextBox control.
##
## Wraps Godot's LineEdit with the standard VB6 TextBox API.
## All native LineEdit functionality is preserved — this only ADDS the VB6 layer.
##
## VB6-compatible API:
##   Properties: Text, PasswordChar, MaxLength, Locked, Alignment,
##               SelStart, SelLength, SelText, Tag
##   Methods:    SetFocus
##   Events:     Change, GotFocus, LostFocus

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

## Change — fires when the text content changes (VB6: Change event).
signal Change(new_text: String)

## GotFocus — fires when the control receives focus (VB6: GotFocus event).
signal GotFocus()

## LostFocus — fires when the control loses focus (VB6: LostFocus event).
signal LostFocus()

# =============================================================================
# Internal state
# =============================================================================

var _password_char: String = ""
var _locked: bool = false
var _alignment_vb: int = 0   # 0=Left, 1=Right, 2=Center

## Storage for common VB6 properties that the Form Designer writes to .tscn.
var _vb6_props: Dictionary = {}

# =============================================================================
# VB6 Properties
# =============================================================================

## Text — the text content (alias for .text, provided for VB6 naming).
var Text: String:
	get: return text
	set(v): text = v

## PasswordChar — if non-empty, text is masked with this character (VB6 convention).
## Set to "" to show text normally. Set to "*" or any single char to mask.
@export var PasswordChar: String = "":
	get: return _password_char
	set(v):
		_password_char = v
		if _password_char.length() > 0:
			secret = true
			secret_character = _password_char
		else:
			secret = false

## MaxLength — maximum number of characters (0 = unlimited, VB6 convention).
var MaxLength: int:
	get: return max_length
	set(v): max_length = maxi(v, 0)

## Locked — if true, the text area is read-only (VB6 convention).
@export var Locked: bool = false:
	get: return _locked
	set(v):
		_locked = v
		editable = not _locked

## Alignment — text alignment: 0=Left, 1=Right, 2=Center (VB6 convention).
@export_enum("Left:0", "Right:1", "Center:2") var Alignment: int = 0:
	get: return _alignment_vb
	set(v):
		_alignment_vb = v
		match v:
			0: alignment = HORIZONTAL_ALIGNMENT_LEFT
			1: alignment = HORIZONTAL_ALIGNMENT_RIGHT
			2: alignment = HORIZONTAL_ALIGNMENT_CENTER

## SelStart — caret position / start of selection (VB6 convention).
var SelStart: int:
	get: return caret_column
	set(v):
		caret_column = clampi(v, 0, text.length())

## SelLength — number of selected characters (VB6 convention).
## Setting selects from SelStart for this many characters.
var SelLength: int:
	get:
		if has_selection():
			# Best-effort: use the stored tracking value
			return _sel_len
		return 0
	set(v):
		_sel_len = maxi(v, 0)
		if _sel_len > 0:
			select(caret_column, clampi(caret_column + _sel_len, 0, text.length()))
		else:
			deselect()

## SelText — the currently selected text (VB6 convention).
## Setting replaces the selection with the new text.
var SelText: String:
	get:
		if has_selection() and _sel_len > 0:
			var from := caret_column
			var to := clampi(from + _sel_len, 0, text.length())
			if from > to:
				var tmp := from
				from = to
				to = tmp
			return text.substr(from, to - from)
		return ""
	set(v):
		insert_text_at_caret(v)

## Tag — general-purpose string storage (VB6 convention).
@export var Tag: String = ""

# =============================================================================
# Internal tracking
# =============================================================================

var _sel_len: int = 0

# =============================================================================
# VB6 Methods
# =============================================================================

## SetFocus — give keyboard focus to this control.
func SetFocus() -> void:
	grab_focus()

# =============================================================================
# Construction
# =============================================================================

func _ready() -> void:
	if not Engine.is_editor_hint():
		select_all_on_focus = true
	if not text_changed.is_connected(_on_text_changed):
		text_changed.connect(_on_text_changed)
	if not Engine.is_editor_hint():
		if not focus_entered.is_connected(_on_focus_entered):
			focus_entered.connect(_on_focus_entered)
		if not focus_exited.is_connected(_on_focus_exited):
			focus_exited.connect(_on_focus_exited)

func _on_text_changed(new_text: String) -> void:
	Change.emit(new_text)

func _on_focus_entered() -> void:
	GotFocus.emit()

func _on_focus_exited() -> void:
	LostFocus.emit()

# =============================================================================
# VB6 Common Property Handlers (Form Designer round-trip)
# =============================================================================

## Accepts VB6 properties written by the C++ Form Designer serializer.
func _set(property: StringName, value: Variant) -> bool:
	var p := String(property)
	match p:
		"Enabled":
			editable = value
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
		"PlaceholderText":
			placeholder_text = str(value)
			_vb6_props[p] = value
			return true
	return false

func _get(property: StringName) -> Variant:
	if _vb6_props.has(String(property)):
		return _vb6_props[String(property)]
	return null
