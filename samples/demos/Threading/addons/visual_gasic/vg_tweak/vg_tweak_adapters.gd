@tool
extends RefCounted
class_name VGTweakAdapters

# Factory + concrete adapters for every supported node kind.
const VGTweakTargetCls = preload("res://addons/visual_gasic/vg_tweak/vg_tweak_target.gd")

# ---------------- Factory ----------------

static func collect_from_tree(root: Node, skip: Node = null) -> Array:
	var out: Array = []
	_walk(root, skip, out)
	return out

static func _walk(node: Node, skip: Node, out: Array) -> void:
	if node == null or node == skip:
		return
	if skip != null and skip.is_ancestor_of(node):
		return
	var adapters := adapt(node)
	for a in adapters:
		out.append(a)
	for child in node.get_children():
		if child is Node:
			_walk(child, skip, out)

static func adapt(node: Node) -> Array:
	# Nodes that publish their own targets win and short-circuit.
	if node.has_method("get_tweak_adapters"):
		return node.get_tweak_adapters()
	if node.has_method("get_tweak_targets"):
		return _wrap_legacy_targets(node)
	var out: Array = []
	if node is LineEdit or node is TextEdit:
		out.append(TextEditAdapter.new(node))
	elif node is Label or node is RichTextLabel or node is Button:
		out.append(LabelAdapter.new(node))
	elif node is Control:
		out.append(ControlAdapter.new(node))
	elif node is Sprite2D:
		out.append(Sprite2DAdapter.new(node))
	elif node is Node2D:
		out.append(Node2DAdapter.new(node))
	return out

# ---------------- Tweak Host Contract (Track C) ----------------
#
# Any node may opt into per-target tweaking by implementing the following
# duck-typed protocol — no class inheritance or `class_name` needed:
#
#   get_tweak_targets() -> Array
#       Returns a list of dicts. Each dict describes one tweakable target:
#         {
#           "target_id":  String,        # unique per host; "cmd:<sid>" is reserved
#                                        # for per-shape canvas commands
#           "type":       String,        # display kind (e.g. "TerminalCell")
#           "group":      String,        # optional grouping label
#           "rect":       Rect2,         # screen-local bounds (used as fallback
#                                        # when get_command_bounds is absent)
#           "description":String,        # short label for the picker dropdown
#           "schema":     Dictionary,    # {prop_name: {type: ..., min: ...}}
#           "source_hints": Dictionary,  # optional {prop: {file,line,col,literal}}
#         }
#
#   get_tweak_value(target_id, prop) -> Variant
#   apply_tweak_override(target_id, override: Dictionary) -> bool
#   clear_tweak_override(target_id) -> bool      # optional; enables Reset
#   get_command_bounds(stable_id: String) -> Rect2  # optional; live bbox for
#                                                   # "cmd:" targets so the
#                                                   # overlay tracks moves
#
# VectorCanvas satisfies this contract today. The same adapter wraps every
# host that follows it; the class name stays `LegacyCanvasAdapter` for
# backward-compat but is also exported as `TweakHostAdapter` below.

static func _wrap_legacy_targets(node: Node) -> Array:
	var out: Array = []
	for t in node.get_tweak_targets():
		var a = LegacyCanvasAdapter.new(node, t)
		out.append(a)
	return out

# ---------------- Adapters ----------------

class ControlAdapter extends VGTweakTargetCls:
	var _node: Control
	func _init(n: Control) -> void:
		_node = n
		owner_node = n
		id = "ctrl:" + str(n.get_path())
		label = n.name
		kind = "Control"
		group = String(n.get_path().get_concatenated_names()).get_base_dir()
	func get_rect() -> Rect2: return _node.get_global_rect()
	func get_schema() -> Dictionary:
		var s := {
			"position": {"type": "Vector2"},
			"size": {"type": "Vector2"},
			"modulate": {"type": "Color"},
			"visible": {"type": "bool"},
			"rotation": {"type": "float", "min": -PI, "max": PI, "step": 0.01},
			"scale": {"type": "Vector2"},
		}
		if "text" in _node:
			s["text"] = {"type": "String"}
		return s
	func get_value(prop: String) -> Variant:
		if prop in _node:
			return _node.get(prop)
		return null
	func set_value(prop: String, value: Variant) -> bool:
		if prop in _node:
			_node.set(prop, value)
			return true
		return false

class LabelAdapter extends ControlAdapter:
	func _init(n: Control) -> void:
		super(n)
		kind = "Label" if n is Label or n is RichTextLabel else "Button"
	func get_schema() -> Dictionary:
		var s = super()
		s["font_size"] = {"type": "int", "min": 4, "max": 96}
		s["font_color"] = {"type": "Color"}
		return s
	func get_value(prop: String) -> Variant:
		if prop == "font_size":
			return _node.get_theme_font_size("font_size")
		if prop == "font_color":
			return _node.get_theme_color("font_color")
		return super(prop)
	func set_value(prop: String, value: Variant) -> bool:
		if prop == "font_size":
			_node.add_theme_font_size_override("font_size", int(value))
			return true
		if prop == "font_color":
			_node.add_theme_color_override("font_color", value)
			return true
		return super(prop, value)

class TextEditAdapter extends ControlAdapter:
	func _init(n: Control) -> void:
		super(n)
		kind = "TextEdit"
	func get_schema() -> Dictionary:
		var s = super()
		s["editable"] = {"type": "bool"}
		return s

class Node2DAdapter extends VGTweakTargetCls:
	var _node: Node2D
	func _init(n: Node2D) -> void:
		_node = n
		owner_node = n
		id = "n2d:" + str(n.get_path())
		label = n.name
		kind = "Node2D"
	func get_rect() -> Rect2:
		var p = _node.global_position
		return Rect2(p - Vector2(20, 20), Vector2(40, 40))
	func get_schema() -> Dictionary:
		return {
			"position": {"type": "Vector2"},
			"rotation": {"type": "float", "min": -PI, "max": PI, "step": 0.01},
			"scale": {"type": "Vector2"},
			"modulate": {"type": "Color"},
			"visible": {"type": "bool"},
		}
	func get_value(prop: String) -> Variant:
		if prop in _node:
			return _node.get(prop)
		return null
	func set_value(prop: String, value: Variant) -> bool:
		if prop in _node:
			_node.set(prop, value)
			return true
		return false

class Sprite2DAdapter extends Node2DAdapter:
	func _init(n: Sprite2D) -> void:
		super(n)
		kind = "Sprite2D"
	func get_rect() -> Rect2:
		var sp: Sprite2D = _node
		if sp.texture == null:
			return super()
		var sz = sp.texture.get_size() * sp.scale
		return Rect2(sp.global_position - sz * 0.5, sz)
	func get_schema() -> Dictionary:
		var s = super()
		s["flip_h"] = {"type": "bool"}
		s["flip_v"] = {"type": "bool"}
		return s

class LegacyCanvasAdapter extends VGTweakTargetCls:
	# Adapter built from a {target_id, description, rect, ...} dict published
	# by a VectorCanvas via get_tweak_targets(). May represent a single command
	# OR an aggregated group, depending on what the canvas chose to emit.
	var _canvas: Node
	var _entry: Dictionary
	func _init(canvas: Node, entry: Dictionary) -> void:
		_canvas = canvas
		_entry = entry
		owner_node = canvas
		var raw_id = str(entry.get("target_id", ""))
		id = "vg:" + str(canvas.get_path()) + ":" + raw_id
		label = str(entry.get("description", entry.get("name", raw_id)))
		kind = str(entry.get("type", "VectorCanvas"))
		group = str(entry.get("group", ""))
		source_hints = entry.get("source_hints", {})
	func get_rect() -> Rect2:
		# For per-command targets, ask the canvas for fresh bounds so the
		# overlay highlight tracks any position override applied since pick.
		var tid := str(_entry.get("target_id", ""))
		if tid.begins_with("cmd:") and _canvas.has_method("get_command_bounds"):
			var r: Rect2 = _canvas.get_command_bounds(tid.substr(4))
			if r.size != Vector2.ZERO:
				return r
		elif _canvas.has_method("get_target_bounds"):
			# Group targets: union live bounds of every member command so the
			# selection rectangle follows a group-level position override.
			var rg: Rect2 = _canvas.get_target_bounds(tid)
			if rg.size != Vector2.ZERO:
				return rg
		return _entry.get("rect", Rect2())
	func get_schema() -> Dictionary:
		return _entry.get("schema", {
			"translate": {"type": "Vector2"},
			"color": {"type": "Color"},
			"fill_color": {"type": "Color"},
			"width": {"type": "float", "min": 0.0, "max": 32.0, "step": 0.5},
		})
	func get_value(prop: String) -> Variant:
		if _canvas.has_method("get_tweak_value"):
			return _canvas.get_tweak_value(_entry.get("target_id"), prop)
		return _entry.get(prop)
	func set_value(prop: String, value: Variant) -> bool:
		var override := {prop: value}
		if _canvas.has_method("apply_tweak_override"):
			return _canvas.apply_tweak_override(_entry.get("target_id"), override)
		return false
	func clear_override() -> bool:
		if _canvas.has_method("clear_tweak_override"):
			return _canvas.clear_tweak_override(_entry.get("target_id"))
		return false
	func can_swap() -> bool:
		return _canvas.has_method("swap_tweak_target")
	func swap_options() -> Array:
		if _canvas.has_method("list_swap_options"):
			return _canvas.list_swap_options(_entry.get("target_id"))
		return []
	func swap_to(option_id: String) -> bool:
		if _canvas.has_method("swap_tweak_target"):
			return _canvas.swap_tweak_target(_entry.get("target_id"), option_id)
		return false

# Preferred name going forward — see "Tweak Host Contract" doc block above.
# Kept as an alias so old code referencing LegacyCanvasAdapter still works.
class TweakHostAdapter extends LegacyCanvasAdapter:
	pass
