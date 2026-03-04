@tool
extends CheckBox
## VGCheckBox — VB6-faithful CheckBox control.
##
## Wraps Godot's CheckBox with the standard VB6 CheckBox API.
## All native CheckBox functionality is preserved — this only ADDS the VB6 layer.
##
## VB6-compatible API:
##   Properties: Value (0/1/2), Caption, Alignment, Tag
##   Methods:    SetFocus
##   Events:     Click
##
## Value mapping:
##   0 = vbUnchecked  — not checked
##   1 = vbChecked    — checked
##   2 = vbGrayed     — checked but dimmed (grayed out appearance)

# =============================================================================
# Value constants (match VB6)
# =============================================================================

const vbUnchecked: int = 0
const vbChecked: int = 1
const vbGrayed: int = 2

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

## Click — fires when the checkbox state changes (VB6: Click event).
signal Click()

# =============================================================================
# Internal state
# =============================================================================

var _grayed: bool = false
var _vb6_props: Dictionary = {}

# =============================================================================
# VB6 Properties
# =============================================================================

## Value — checkbox state: 0=Unchecked, 1=Checked, 2=Grayed (VB6 convention).
var Value: int:
	get:
		if _grayed:
			return vbGrayed
		return vbChecked if button_pressed else vbUnchecked
	set(v):
		match v:
			vbUnchecked:
				_grayed = false
				button_pressed = false
			vbChecked:
				_grayed = false
				button_pressed = true
			vbGrayed:
				_grayed = true
				button_pressed = true
		_update_grayed_appearance()

## Caption — the text label next to the checkbox (alias for .text).
var Caption: String:
	get: return text
	set(v): text = v

## Alignment — 0=Left (check left of text), 1=Right (check right of text).
@export_enum("Left:0", "Right:1") var Alignment: int = 0:
	set(v):
		Alignment = v
		match v:
			0: alignment = HORIZONTAL_ALIGNMENT_LEFT
			1: alignment = HORIZONTAL_ALIGNMENT_RIGHT

## Tag — general-purpose string storage (VB6 convention).
@export var Tag: String = ""

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
	if Engine.is_editor_hint():
		return
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)

func _on_toggled(_pressed: bool) -> void:
	# If user clicks while grayed, clear the grayed state
	if _grayed:
		_grayed = false
		_update_grayed_appearance()
	Click.emit()

func _update_grayed_appearance() -> void:
	if _grayed:
		modulate = Color(0.7, 0.7, 0.7, 1.0)
	else:
		modulate = Color.WHITE

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
