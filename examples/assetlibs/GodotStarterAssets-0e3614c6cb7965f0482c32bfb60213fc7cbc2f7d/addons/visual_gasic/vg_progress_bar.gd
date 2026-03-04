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
