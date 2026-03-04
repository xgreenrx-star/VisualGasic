@tool
extends ProgressBar
## VGProgressBar — VB6-faithful ProgressBar control.
##
## Wraps Godot's ProgressBar with the standard VB6 ProgressBar API.
## All native ProgressBar functionality is preserved — this only ADDS the VB6 layer.
##
## VB6-compatible API:
##   Properties: Min, Max, Value (inherited), Tag
##
## Note: Godot's ProgressBar already has min_value, max_value, value via Range.
## This wrapper provides VB6-style property names as aliases.

# =============================================================================
# Internal state
# =============================================================================

var _vb6_props: Dictionary = {}

# =============================================================================
# VB6 Properties
# =============================================================================

## Min — minimum value of the progress bar (alias for min_value).
var Min: float:
	get: return min_value
	set(v): min_value = v

## Max — maximum value of the progress bar (alias for max_value).
var Max: float:
	get: return max_value
	set(v): max_value = v

## Tag — general-purpose string storage (VB6 convention).
@export var Tag: String = ""

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
