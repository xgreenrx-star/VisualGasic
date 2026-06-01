@tool
extends RefCounted
class_name VGTweakTarget

# Universal tweak target adapter. One instance per logical object the user
# can edit through the Tweak Overlay. Subclass and override the virtuals.
#
# Schema entries describe an editable property:
#   { "type": "Vector2"|"Rect2"|"Color"|"float"|"int"|"bool"|"String"|"enum",
#     "min": float,        # float/int only
#     "max": float,        # float/int only
#     "step": float,       # float/int only
#     "values": Array,     # enum only
#     "label": String }    # optional pretty label

var id: String = ""
var label: String = ""
var group: String = ""
var kind: String = ""          # "Control", "Node2D", "VectorCanvasGroup", ...
var owner_node: Node = null    # back-reference for hit-test / persistence keying
var source_hints: Dictionary = {}  # { prop_name: { file, line, col, literal } }

func get_rect() -> Rect2:
	return Rect2()

func get_schema() -> Dictionary:
	return {}

func get_value(prop: String) -> Variant:
	return null

func set_value(prop: String, value: Variant) -> bool:
	return false

func get_source(prop: String) -> Dictionary:
	return source_hints.get(prop, {})

func can_swap() -> bool:
	return false

func swap_options() -> Array:
	return []

func swap_to(option_id: String) -> bool:
	return false

func snapshot() -> Dictionary:
	var out := {}
	for prop in get_schema().keys():
		out[prop] = get_value(prop)
	return out

func apply(overrides: Dictionary) -> void:
	for prop in overrides.keys():
		set_value(prop, overrides[prop])
