@tool
extends ScrollBar
## VGScrollBar — VB6-faithful HScrollBar / VScrollBar control.
##
## Wraps Godot's ScrollBar (shared by HScrollBar and VScrollBar) with the
## standard VB6 scrollbar API.  All native ScrollBar functionality is
## preserved — this only ADDS the VB6 layer.
##
## VB6-compatible API:
##   Properties: Min, Max, Value, SmallChange, LargeChange, Tag
##   Methods:    SetFocus
##   Events:     Change, Scroll

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

## Change — fires when the value changes and the thumb is released (VB6: Change event).
signal Change()

## Scroll — fires continuously while the user drags the thumb (VB6: Scroll event).
signal Scroll()

# =============================================================================
# Internal state
# =============================================================================

var _small_change: float = 1.0
var _large_change: float = 10.0
var _was_dragging: bool = false
var _vb6_props: Dictionary = {}

# =============================================================================
# VB6 Properties
# =============================================================================

## Min — minimum value of the scroll bar (alias for min_value).
var Min: float:
	get: return min_value
	set(v): min_value = v

## Max — maximum value of the scroll bar (alias for max_value).
var Max: float:
	get: return max_value
	set(v): max_value = v

## Value — current scroll position (alias for .value).
var Value: float:
	get: return value
	set(v): value = v

## SmallChange — amount to scroll when clicking an arrow button (VB6 convention).
## Maps to Godot's step property.
@export var SmallChange: float = 1.0:
	get: return _small_change
	set(v):
		_small_change = maxf(v, 0.001)
		step = _small_change

## LargeChange — amount to scroll when clicking the track area (VB6 convention).
## Maps to Godot's page property.
@export var LargeChange: float = 10.0:
	get: return _large_change
	set(v):
		_large_change = maxf(v, 0.001)
		page = _large_change

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
	step = _small_change
	page = _large_change
	if not Engine.is_editor_hint():
		if not value_changed.is_connected(_on_value_changed):
			value_changed.connect(_on_value_changed)
		if not scrolling.is_connected(_on_scrolling):
			scrolling.connect(_on_scrolling)

func _on_value_changed(_val: float) -> void:
	Change.emit()

func _on_scrolling() -> void:
	Scroll.emit()

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
