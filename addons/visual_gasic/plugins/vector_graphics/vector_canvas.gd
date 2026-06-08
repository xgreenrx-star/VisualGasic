@tool
extends Node2D
class_name VectorCanvas

enum CommandType { LINE, RECT, ROUNDED_RECT, ELLIPSE, ARC, PIE_SLICE, POLYGON, POLYLINE, TEXT }

var _commands: Array = []
var _command_id_counter: int = 0
# Runtime-placed/duplicated commands. Survive Clear()/re-emit cycles by being
# re-appended into _commands every frame after the .vg code finishes drawing.
# Filled by duplicate_command() (Ctrl+D) and add_runtime_command() (palette).
var _runtime_commands: Array = []
var _runtime_id_counter: int = 0
var _transform_stack: Array = [Transform2D()]
var _group_stack: Array = []
var _group_overrides: Dictionary = {}
var _group_source_hints: Dictionary = {}  # group_name -> { prop: {file,line,col,literal} }
var _command_overrides: Dictionary = {}   # stable_id -> override dict
var _frame_line_ord: Dictionary = {}      # "file:line" -> next ordinal this frame
var _pending_redraw: bool = false
var stroke_color: Color = Color(1, 1, 1, 1)
var fill_color: Color = Color(1, 1, 1, 0)
var stroke_width: float = 2.0
var default_font: Font = null
var _vector_fonts: Dictionary = {}
var _vector_font_name: String = "default"
func _ready() -> void:
	_load_persisted_overrides()
	queue_redraw()

func _load_persisted_overrides() -> void:
	# Seed _group_overrides from disk so saved tweaks apply on game startup,
	# not just when the overlay opens. _queue_command consults this map on
	# every command emit, so the canvas re-applies tweaks each frame.
	if Engine.is_editor_hint():
		return
	var script_path := "res://addons/visual_gasic/vg_tweak/vg_tweak_persistence.gd"
	if not ResourceLoader.exists(script_path):
		return
	var persistence = load(script_path)
	if persistence == null or not persistence.has_method("load_all"):
		return
	var all: Dictionary = persistence.load_all()
	if all.is_empty():
		return
	var prefix := "vg:" + str(get_path()) + ":"
	for key in all.keys():
		var k := str(key)
		# Overlay stores keys as "vg:<canvas_path>:<raw_id>". Strip prefix so
		# we only load entries that belong to *this* canvas.
		if not k.begins_with(prefix):
			continue
		var raw := k.substr(prefix.length())
		if raw == "__runtime_cmds__":
			if typeof(all[key]) == TYPE_ARRAY:
				restore_runtime_commands_from_save(all[key])
			continue
		if raw.begins_with("cmd:"):
			_command_overrides[raw.substr(4)] = (all[key] as Dictionary).duplicate(true)
		else:
			_group_overrides[raw] = (all[key] as Dictionary).duplicate(true)

func _draw() -> void:
	_pending_redraw = false
	for command in _commands:
		if command.get("_visible", true) == false:
			continue
		match command.type:
			CommandType.LINE:
				draw_line(_transform_point(command.from, command.transform), _transform_point(command.to, command.transform), command.color, command.width)
			CommandType.RECT:
				_draw_rect_command(command)
			CommandType.ROUNDED_RECT:
				_draw_rounded_rect_command(command)
			CommandType.ELLIPSE:
				_draw_ellipse_command(command)
			CommandType.ARC:
				_draw_arc_command(command)
			CommandType.PIE_SLICE:
				_draw_pie_slice_command(command)
			CommandType.POLYGON:
				_draw_polygon_command(command)
			CommandType.POLYLINE:
				_draw_polyline_command(command)
			CommandType.TEXT:
				_draw_text_command(command)

func _fill_color_array(color: Color, count: int) -> PackedColorArray:
	var result := PackedColorArray()
	for i in range(count):
		result.append(color)
	return result

func _queue_command(command: Dictionary) -> void:
	command["command_id"] = _command_id_counter
	command["target_id"] = command.get("target_id", str(_command_id_counter))
	var gname: String = _group_stack[-1] if _group_stack.size() > 0 else ""
	command["group"] = gname
	_command_id_counter += 1
	# Capture .vg source location for this draw call so the overlay can click-
	# pick a single shape and jump to (or AI-edit) the exact line that drew it.
	var src_file: String = ""
	var src_line: int = -1
	if ClassDB.class_exists("VisualGasicLanguage"):
		src_file = ClassDB.class_call_static("VisualGasicLanguage", "vg_get_current_debug_file")
		src_line = int(ClassDB.class_call_static("VisualGasicLanguage", "vg_get_current_debug_line"))
	command["__src_file"] = src_file
	command["__src_line"] = src_line
	var lkey := "%s:%d" % [src_file, src_line]
	var ord: int = int(_frame_line_ord.get(lkey, 0))
	_frame_line_ord[lkey] = ord + 1
	command["__src_ord"] = ord
	command["__stable_id"] = "%s:%d:%d" % [src_file, src_line, ord] if src_file != "" else ""
	# Auto-seed per-group source hints from the first command's source so the
	# inspector's source/AI buttons work without an explicit TagSource call.
	var gkey: String = gname if gname != "" else "__misc"
	if src_file != "" and src_line > 0 and not _group_source_hints.has(gkey):
		var auto_hint = {"file": src_file, "line": src_line, "col": -1, "literal": ""}
		_group_source_hints[gkey] = {
			"position": auto_hint, "color": auto_hint,
			"fill_color": auto_hint, "width": auto_hint, "visible": auto_hint,
		}
	# Re-apply any stored group override so tweaks survive the Clear()/re-emit
	# cycle the .vg runtime performs every frame.
	var ov: Dictionary = _group_overrides.get(gkey, {})
	if not ov.is_empty():
		_apply_override_to_command(command, ov)
	# Then layer any per-command override on top (more specific wins).
	if command["__stable_id"] != "":
		var cov: Dictionary = _command_overrides.get(command["__stable_id"], {})
		if not cov.is_empty():
			_apply_override_to_command(command, cov)
	_commands.append(command)
	if not _pending_redraw:
		_pending_redraw = true
		queue_redraw()

func _apply_override_to_command(command: Dictionary, override: Dictionary) -> void:
	for prop in override.keys():
		var value = override[prop]
		match prop:
			"position", "translate":
				var base: Transform2D = command.get("_base_transform", command.get("transform", Transform2D()))
				command["_base_transform"] = base
				var t := Transform2D(base)
				t.origin = base.origin + value
				command["transform"] = t
			"visible":
				command["_visible"] = value == true
			_:
				if prop in command:
					command[prop] = value

func BeginGroup(name: String) -> void:
	_group_stack.append(name)

func EndGroup() -> void:
	if _group_stack.size() > 0:
		_group_stack.pop_back()

func TagSource(group_name: String, prop: String, file: String, line: int, literal: String, col: int = -1) -> void:
	# Bind a tweakable property of a group to a source-code literal so the
	# overlay's "->src" button can rewrite the value in-place.
	var key = group_name if group_name != "" else "__misc"
	var bag: Dictionary = _group_source_hints.get(key, {})
	bag[prop] = {"file": file, "line": line, "col": col, "literal": literal}
	_group_source_hints[key] = bag

func get_tweak_targets() -> Array:
	# Collapse commands into one target per BeginGroup() name. Ungrouped
	# commands collapse into a single "misc" target per canvas to keep the
	# overlay list manageable. The overlay queries grouped properties through
	# get_tweak_value/apply_tweak_override and we apply them across every
	# command bearing the same group.
	var groups: Dictionary = {}
	var order: Array = []
	for command in _commands:
		var gname = str(command.get("group", ""))
		var bucket_key = gname if gname != "" else "__misc"
		if not groups.has(bucket_key):
			groups[bucket_key] = {
				"target_id": bucket_key,
				"type": "VectorCanvasGroup",
				"group": gname,
				"rect": Rect2(),
				"description": gname if gname != "" else "%s (misc)" % name,
				"_first": true,
				"_count": 0,
			}
			order.append(bucket_key)
		var bucket: Dictionary = groups[bucket_key]
		bucket["_count"] = bucket["_count"] + 1
		var bounds = _get_command_bounds(command)
		if bucket["_first"]:
			bucket["rect"] = bounds
			bucket["_first"] = false
		else:
			bucket["rect"] = bucket["rect"].merge(bounds)
	var targets: Array = []
	for key in order:
		var b: Dictionary = groups[key]
		b["description"] = "%s [%d]" % [b["description"], b["_count"]]
		b.erase("_first")
		b.erase("_count")
		b["schema"] = {
			"position": {"type": "Vector2"},
			"color": {"type": "Color"},
			"fill_color": {"type": "Color"},
			"width": {"type": "float", "min": 0.0, "max": 32.0, "step": 0.5},
			"visible": {"type": "bool"},
		}
		b["source_hints"] = _group_source_hints.get(key, {})
		targets.append(b)
	return targets

func get_tweak_value(target_id, prop: String) -> Variant:
	var key = str(target_id)
	if key.begins_with("cmd:"):
		var sid := key.substr(4)
		var cov: Dictionary = _command_overrides.get(sid, {})
		if cov.has(prop):
			return cov[prop]
		for command in _commands:
			if str(command.get("__stable_id", "")) == sid:
				if prop == "position" or prop == "translate":
					return command.get("transform", Transform2D()).origin
				if prop in command:
					return command[prop]
				return null
		return null
	var ov = _group_overrides.get(key, {})
	if ov.has(prop):
		return ov[prop]
	var match_group: String = "" if key == "__misc" else key
	for command in _commands:
		if str(command.get("group", "")) == match_group:
			if prop == "position" or prop == "translate":
				return command.get("transform", Transform2D()).origin
			if prop in command:
				return command[prop]
			return null
	return null

func apply_tweak_override(target_id, override: Dictionary) -> bool:
	var key = str(target_id)
	if key.begins_with("cmd:"):
		var sid := key.substr(4)
		var cstored: Dictionary = _command_overrides.get(sid, {})
		for k in override.keys():
			cstored[k] = override[k]
		_command_overrides[sid] = cstored
		var cmatched := false
		for command in _commands:
			if str(command.get("__stable_id", "")) != sid:
				continue
			cmatched = true
			_apply_override_to_command(command, override)
		if cmatched:
			queue_redraw()
		return cmatched
	var stored: Dictionary = _group_overrides.get(key, {})
	for k in override.keys():
		stored[k] = override[k]
	_group_overrides[key] = stored
	var match_group: String = "" if key == "__misc" else key
	var matched := false
	for command in _commands:
		if str(command.get("group", "")) != match_group:
			continue
		matched = true
		_apply_override_to_command(command, override)
	if matched:
		queue_redraw()
	return matched

func pick_command_at(local_pos: Vector2, tolerance: float = 4.0) -> Dictionary:
	# Walk commands in reverse (topmost first) and return the first whose
	# precise geometry contains local_pos. Empty dict means no hit.
	for i in range(_commands.size() - 1, -1, -1):
		var c: Dictionary = _commands[i]
		if c.get("_visible", true) == false:
			continue
		if _command_contains_point(c, local_pos, tolerance):
			return c
	return {}

func clear_tweak_override(target_id) -> bool:
	# Remove any stored override for the given target so commands re-emit at
	# their original literal values on next frame. Returns true if something
	# was actually cleared.
	var tid := str(target_id)
	var cleared := false
	if tid.begins_with("cmd:"):
		var sid := tid.substr(4)
		if _command_overrides.erase(sid):
			cleared = true
	else:
		if _group_overrides.erase(tid):
			cleared = true
	for c in _commands:
		var match_cmd := false
		if tid.begins_with("cmd:"):
			match_cmd = str(c.get("__stable_id", "")) == tid.substr(4)
		else:
			match_cmd = str(c.get("group", "")) == tid or (tid == "__misc" and str(c.get("group", "")) == "")
		if not match_cmd:
			continue
		if c.has("_base_transform"):
			c["transform"] = c["_base_transform"]
			c.erase("_base_transform")
		c.erase("_visible")
		cleared = true
	if cleared:
		queue_redraw()
	return cleared

func find_commands_in_rect(local_rect: Rect2) -> Array:
	# Return stable IDs of every visible command whose bounding box intersects
	# local_rect. Used by the overlay's rubber-band selection.
	var out: Array = []
	for c in _commands:
		if c.get("_visible", true) == false:
			continue
		var sid := str(c.get("__stable_id", ""))
		if sid == "":
			continue
		if _get_command_bounds(c).intersects(local_rect):
			out.append(sid)
	return out

func get_command_bounds(stable_id: String) -> Rect2:
	for c in _commands:
		if str(c.get("__stable_id", "")) == stable_id:
			return _get_command_bounds(c)
	return Rect2()

func get_target_bounds(target_id) -> Rect2:
	# Fresh bounds for either a per-command ("cmd:...") target OR a group
	# target (raw group name, or "__misc" for un-grouped). Group bounds are
	# the union of every member command's bounds, computed against the live
	# transform so the overlay's selection rectangle tracks any position
	# override applied to the group.
	var key := str(target_id)
	if key.begins_with("cmd:"):
		return get_command_bounds(key.substr(4))
	var match_group: String = "" if key == "__misc" else key
	var bounds := Rect2()
	var first := true
	for c in _commands:
		if str(c.get("group", "")) != match_group:
			continue
		var b := _get_command_bounds(c)
		if first:
			bounds = b
			first = false
		else:
			bounds = bounds.merge(b)
	return bounds

func get_command_target(stable_id: String) -> Dictionary:
	# Build a target dict (same shape as get_tweak_targets entries) for one
	# specific draw command, used by the overlay after click-picking.
	for c in _commands:
		if str(c.get("__stable_id", "")) != stable_id:
			continue
		var src_file: String = c.get("__src_file", "")
		var src_line: int = int(c.get("__src_line", -1))
		var auto_hint = {"file": src_file, "line": src_line, "col": -1, "literal": ""}
		var label := "%s @ %s:%d" % [_get_command_type_name(c.type), src_file.get_file(), src_line]
		return {
			"target_id": "cmd:" + stable_id,
			"type": "VectorCanvasCommand",
			"group": str(c.get("group", "")),
			"rect": _get_command_bounds(c),
			"description": label,
			"schema": {
				"position": {"type": "Vector2"},
				"color": {"type": "Color"},
				"fill_color": {"type": "Color"},
				"width": {"type": "float", "min": 0.0, "max": 32.0, "step": 0.5},
				"visible": {"type": "bool"},
			},
			"source_hints": {
				"position": auto_hint, "color": auto_hint,
				"fill_color": auto_hint, "width": auto_hint, "visible": auto_hint,
			},
		}
	return {}

func duplicate_command(stable_id: String, offset: Vector2 = Vector2(16, 16)) -> String:
	# Clone the command with stable_id into the runtime list with a new id and
	# a translate offset so the duplicate is visible. Returns the new stable_id
	# (without the "cmd:" prefix); empty string if not found.
	for c in _commands:
		if str(c.get("__stable_id", "")) != stable_id:
			continue
		var clone: Dictionary = c.duplicate(true)
		_runtime_id_counter += 1
		var new_sid := "runtime:%d" % _runtime_id_counter
		clone["__stable_id"] = new_sid
		clone["__src_file"] = ""
		clone["__src_line"] = -1
		clone["__src_ord"] = 0
		clone["group"] = ""
		# Offset by mutating transform.origin so geometry-typed commands
		# (rect/ellipse/polygon) draw in the new spot without relying on
		# per-property overrides.
		var t: Transform2D = clone.get("transform", Transform2D())
		t.origin += offset
		clone["transform"] = t
		clone["_base_transform"] = t
		# Strip any per-command override carried over from the source.
		clone.erase("_visible")
		_runtime_commands.append(clone)
		_commands.append(clone.duplicate(true))
		queue_redraw()
		return new_sid
	return ""

func remove_runtime_command(stable_id: String) -> bool:
	# Erase a runtime command so it stops being re-emitted next frame.
	for i in range(_runtime_commands.size()):
		if str(_runtime_commands[i].get("__stable_id", "")) == stable_id:
			_runtime_commands.remove_at(i)
			# Also remove from the live frame so the change is immediate.
			for j in range(_commands.size() - 1, -1, -1):
				if str(_commands[j].get("__stable_id", "")) == stable_id:
					_commands.remove_at(j)
			queue_redraw()
			return true
	return false

func add_runtime_command(kind: String, local_pos: Vector2, defaults: Dictionary = {}) -> String:
	# Build a fresh runtime command from a palette shape descriptor.
	# kind ∈ {"rect", "ellipse", "line", "text"}. Returns new stable_id.
	var clone: Dictionary = {}
	_runtime_id_counter += 1
	var new_sid := "runtime:%d" % _runtime_id_counter
	var t := Transform2D()
	t.origin = local_pos
	var color: Color = defaults.get("color", Color(1, 1, 1, 1))
	var fill: Color = defaults.get("fill_color", Color(0.3, 0.6, 1.0, 0.5))
	var width: float = float(defaults.get("width", 2.0))
	match kind:
		"rect":
			clone = {
				"type": CommandType.RECT,
				"rect": Rect2(-32, -20, 64, 40),
				"color": color, "fill_color": fill, "width": width,
			}
		"ellipse":
			clone = {
				"type": CommandType.ELLIPSE,
				"rect": Rect2(-32, -20, 64, 40),
				"color": color, "fill_color": fill, "width": width,
			}
		"line":
			clone = {
				"type": CommandType.LINE,
				"from": Vector2(-30, 0), "to": Vector2(30, 0),
				"color": color, "width": width,
			}
		"text":
			clone = {
				"type": CommandType.TEXT,
				"text": str(defaults.get("text", "Text")),
				"position": Vector2.ZERO,
				"color": color,
				"font_size": int(defaults.get("font_size", 16)),
			}
		_:
			return ""
	clone["transform"] = t
	clone["_base_transform"] = t
	clone["__stable_id"] = new_sid
	clone["__src_file"] = ""
	clone["__src_line"] = -1
	clone["__src_ord"] = 0
	clone["group"] = ""
	clone["command_id"] = _command_id_counter
	clone["target_id"] = str(_command_id_counter)
	_command_id_counter += 1
	_runtime_commands.append(clone)
	_commands.append(clone.duplicate(true))
	queue_redraw()
	return new_sid

func get_runtime_commands_for_save() -> Array:
	# Snapshot of runtime commands serializable enough for vg_tweaks.json.
	# Values are tagged by VGTweakPersistence on the way out.
	var out: Array = []
	for rc in _runtime_commands:
		var spec := {
			"stable_id": rc.get("__stable_id", ""),
			"type": rc.get("type", -1),
			"transform": rc.get("transform", Transform2D()),
			"color": rc.get("color", Color.WHITE),
			"fill_color": rc.get("fill_color", Color(0, 0, 0, 0)),
			"width": rc.get("width", 1.0),
		}
		if rc.has("rect"):
			spec["rect"] = rc.get("rect")
		if rc.has("from"):
			spec["from"] = rc.get("from")
			spec["to"] = rc.get("to")
		if rc.has("text"):
			spec["text"] = rc.get("text")
			spec["position"] = rc.get("position", Vector2.ZERO)
			spec["font_size"] = rc.get("font_size", 16)
		out.append(spec)
	return out

func restore_runtime_commands_from_save(specs: Array) -> void:
	for spec in specs:
		var sid := str(spec.get("stable_id", ""))
		if sid == "":
			continue
		var clone: Dictionary = {
			"type": int(spec.get("type", -1)),
			"transform": spec.get("transform", Transform2D()),
			"color": spec.get("color", Color.WHITE),
			"fill_color": spec.get("fill_color", Color(0, 0, 0, 0)),
			"width": float(spec.get("width", 1.0)),
			"__stable_id": sid,
			"__src_file": "",
			"__src_line": -1,
			"__src_ord": 0,
			"group": "",
		}
		clone["_base_transform"] = clone["transform"]
		if spec.has("rect"):
			clone["rect"] = spec.get("rect")
		if spec.has("from"):
			clone["from"] = spec.get("from")
			clone["to"] = spec.get("to")
		if spec.has("text"):
			clone["text"] = spec.get("text")
			clone["position"] = spec.get("position", Vector2.ZERO)
			clone["font_size"] = int(spec.get("font_size", 16))
		# Bump counter past restored ids so new duplicates don't collide.
		var n := sid.trim_prefix("runtime:").to_int()
		if n > _runtime_id_counter:
			_runtime_id_counter = n
		_runtime_commands.append(clone)
	queue_redraw()

func _command_contains_point(c: Dictionary, p: Vector2, tol: float) -> bool:
	var xf: Transform2D = c.get("transform", Transform2D())
	var inv: Transform2D = xf.affine_inverse()
	var lp: Vector2 = inv * p  # point in command's local space
	match c.type:
		CommandType.LINE:
			return _dist_point_segment(p, xf * c.from, xf * c.to) <= max(c.width, tol) * 0.5 + tol
		CommandType.RECT, CommandType.ROUNDED_RECT:
			var r: Rect2 = c.rect
			if c.get("fill", false):
				return r.grow(tol).has_point(lp)
			# Outline-only: hit if near edge.
			var outer = r.grow(max(c.width, tol) * 0.5 + tol)
			var inner = r.grow(-max(c.width, tol) * 0.5 - tol)
			return outer.has_point(lp) and not inner.has_point(lp)
		CommandType.ELLIPSE:
			var r2: Rect2 = c.rect
			var center = r2.position + r2.size * 0.5
			var rad = r2.size * 0.5
			if rad.x <= 0.0 or rad.y <= 0.0:
				return false
			var d = (lp - center) / rad
			var dist = d.length()
			if c.get("fill", false):
				return dist <= 1.0 + tol / max(rad.x, rad.y)
			return absf(dist - 1.0) <= (max(c.width, tol) * 0.5 + tol) / max(rad.x, rad.y)
		CommandType.POLYGON:
			var pts = c.points
			if c.transform != Transform2D():
				pts = _transform_points(pts, c.transform)
			if c.get("fill", false) and Geometry2D.is_point_in_polygon(p, pts):
				return true
			# Outline test: distance to any segment
			for i in range(pts.size()):
				var a = pts[i]
				var b = pts[(i + 1) % pts.size()]
				if _dist_point_segment(p, a, b) <= max(c.width, tol) * 0.5 + tol:
					return true
			return false
		CommandType.POLYLINE:
			var pts2 = c.points
			if c.transform != Transform2D():
				pts2 = _transform_points(pts2, c.transform)
			for i in range(pts2.size() - 1):
				if _dist_point_segment(p, pts2[i], pts2[i + 1]) <= max(c.width, tol) * 0.5 + tol:
					return true
			return false
		CommandType.ARC, CommandType.PIE_SLICE:
			# Approximate via bounds for now; arcs are rare picks.
			return _get_command_bounds(c).grow(tol).has_point(p)
		CommandType.TEXT:
			var tp = xf * c.position
			return Rect2(tp - Vector2(4, 12), Vector2(120, 20)).grow(tol).has_point(p)
	return false

func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var len2 = ab.length_squared()
	if len2 <= 0.00001:
		return p.distance_to(a)
	var t = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _get_command_type_name(command_type: int) -> String:
	match command_type:
		CommandType.LINE:
			return "LINE"
		CommandType.RECT:
			return "RECT"
		CommandType.ROUNDED_RECT:
			return "ROUNDED_RECT"
		CommandType.ELLIPSE:
			return "ELLIPSE"
		CommandType.ARC:
			return "ARC"
		CommandType.PIE_SLICE:
			return "PIE_SLICE"
		CommandType.POLYGON:
			return "POLYGON"
		CommandType.POLYLINE:
			return "POLYLINE"
		CommandType.TEXT:
			return "TEXT"
	return "UNKNOWN"

func _get_command_bounds(command: Dictionary) -> Rect2:
	match command.type:
		CommandType.LINE:
			var a = _transform_point(command.from, command.transform)
			var b = _transform_point(command.to, command.transform)
			return _rect_from_points([a, b])
		CommandType.RECT, CommandType.ROUNDED_RECT, CommandType.ELLIPSE:
			if command.transform == Transform2D():
				return command.rect
			return _rect_from_points(_transform_points(_rect_points(command.rect), command.transform))
		CommandType.ARC:
			var points = _arc_points(command.center, command.radius, command.start_angle, command.end_angle, command.segments)
			if command.transform != Transform2D():
				points = _transform_points(points, command.transform)
			return _rect_from_points(points)
		CommandType.PIE_SLICE:
			var points = _arc_points(command.center, command.radius, command.start_angle, command.end_angle, command.segments)
			points.append(command.center)
			if command.transform != Transform2D():
				points = _transform_points(points, command.transform)
			return _rect_from_points(points)
		CommandType.POLYGON, CommandType.POLYLINE:
			var points = command.points.duplicate()
			if command.transform != Transform2D():
				points = _transform_points(points, command.transform)
			return _rect_from_points(points)
		CommandType.TEXT:
			var position = _transform_point(command.position, command.transform)
			return Rect2(position, Vector2.ZERO)
	return Rect2()

func _rect_from_points(points: Array) -> Rect2:
	if points.size() == 0:
		return Rect2()
	var min_x = points[0].x
	var min_y = points[0].y
	var max_x = points[0].x
	var max_y = points[0].y
	for point in points:
		min_x = min(min_x, point.x)
		min_y = min(min_y, point.y)
		max_x = max(max_x, point.x)
		max_y = max(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _get_current_transform() -> Transform2D:
	return _transform_stack[_transform_stack.size() - 1]

func _transform_point(point: Vector2, transform: Transform2D) -> Vector2:
	return transform * point

func _transform_points(points: Array, transform: Transform2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(_transform_point(point, transform))
	return result

func _rect_points(rect: Rect2) -> Array:
	return [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	]

func _ellipse_points(rect: Rect2, segments: int = 32) -> Array:
	var points: Array = []
	var center = rect.position + rect.size * 0.5
	var radius = rect.size * 0.5
	for i in range(segments):
		var angle = TAU * float(i) / segments
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

func _rounded_rect_points(rect: Rect2, radius: float, segments: int = 8) -> Array:
	var max_r = minf(rect.size.x, rect.size.y) * 0.5
	var r = minf(radius, max_r)
	var points: Array = []

	for i in range(segments + 1):
		var a = -PI * 0.5 + PI * 0.5 * float(i) / float(segments)
		points.append(Vector2(rect.end.x - r + cos(a) * r, rect.position.y + r + sin(a) * r))
	for i in range(segments + 1):
		var a = PI * 0.5 * float(i) / float(segments)
		points.append(Vector2(rect.end.x - r + cos(a) * r, rect.end.y - r + sin(a) * r))
	for i in range(segments + 1):
		var a = PI * 0.5 + PI * 0.5 * float(i) / float(segments)
		points.append(Vector2(rect.position.x + r + cos(a) * r, rect.end.y - r + sin(a) * r))
	for i in range(segments + 1):
		var a = PI + PI * 0.5 * float(i) / float(segments)
		points.append(Vector2(rect.position.x + r + cos(a) * r, rect.position.y + r + sin(a) * r))

	return points

func _arc_points(center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int = 32) -> Array:
	var points: Array = []
	var sweep = end_angle - start_angle
	for i in range(segments + 1):
		var angle = start_angle + sweep * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

func _draw_rect_command(command: Dictionary) -> void:
	if command.transform == Transform2D():
		if command.fill:
			draw_rect(command.rect, command.fill_color, true)
		if command.width > 0.0:
			draw_rect(command.rect, command.color, false, command.width)
	else:
		var points = _transform_points(_rect_points(command.rect), command.transform)
		if command.fill:
			draw_polygon(points, _fill_color_array(command.fill_color, points.size()))
		if command.width > 0.0:
			var outline = points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, command.color, command.width)

func _draw_rounded_rect_command(command: Dictionary) -> void:
	var points = _rounded_rect_points(command.rect, command.radius, command.segments)
	if command.transform != Transform2D():
		points = _transform_points(points, command.transform)
	if command.fill:
		draw_polygon(points, _fill_color_array(command.fill_color, points.size()))
	if command.width > 0.0:
		var outline = points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, command.color, command.width)

func _draw_ellipse_command(command: Dictionary) -> void:
	var points = _ellipse_points(command.rect, command.segments)
	if command.transform != Transform2D():
		points = _transform_points(points, command.transform)
	if command.fill:
		draw_polygon(points, _fill_color_array(command.fill_color, points.size()))
	if command.width > 0.0:
		draw_polyline(points, command.color, command.width)

func _draw_arc_command(command: Dictionary) -> void:
	var points = _arc_points(command.center, command.radius, command.start_angle, command.end_angle, command.segments)
	if command.transform != Transform2D():
		points = _transform_points(points, command.transform)
	if command.fill:
		var filled = points.duplicate()
		filled.append(_transform_point(command.center, command.transform))
		draw_polygon(filled, _fill_color_array(command.fill_color, filled.size()))
	if command.width > 0.0 or not command.fill:
		draw_polyline(points, command.color, command.width)

func _draw_pie_slice_command(command: Dictionary) -> void:
	var points = _arc_points(command.center, command.radius, command.start_angle, command.end_angle, command.segments)
	points.insert(0, command.center)
	if command.transform != Transform2D():
		points = _transform_points(points, command.transform)
	if command.fill:
		draw_polygon(points, _fill_color_array(command.fill_color, points.size()))
	if command.width > 0.0:
		if points.size() > 0:
			points.append(points[1])
			draw_polyline(points, command.color, command.width)

func _draw_polygon_command(command: Dictionary) -> void:
	var points = _transform_points(command.points, command.transform)
	if command.fill:
		draw_polygon(points, _fill_color_array(command.fill_color, points.size()))
	if command.width > 0.0:
		var outline = points.duplicate()
		if outline.size() > 0:
			outline.append(outline[0])
		draw_polyline(outline, command.color, command.width)

func _draw_polyline_command(command: Dictionary) -> void:
	var points = _transform_points(command.points, command.transform)
	if command.fill:
		draw_polygon(points, _fill_color_array(command.fill_color, points.size()))
	if command.width > 0.0:
		if command.close:
			var outline = points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, command.color, command.width)
		else:
			draw_polyline(points, command.color, command.width)

func _draw_text_command(command: Dictionary) -> void:
	if command.font == null and command.text != "":
		var position = _transform_point(command.position, command.transform)
		DrawVectorText(position, command.text, command.color, 1.0, 2.0, command.align)
		return

	if typeof(command.font) == TYPE_STRING:
		var position = _transform_point(command.position, command.transform)
		DrawVectorText(position, command.text, command.color, 1.0, 2.0, command.align, 2.0, command.font)
		return

	var font = command.font if command.font != null else default_font
	if font != null:
		var position = _transform_point(command.position, command.transform)
		var text_size = font.get_string_size(command.text)
		if command.align == "center":
			position.x -= text_size.x * 0.5
		elif command.align == "right":
			position.x -= text_size.x
		draw_string(font, position, command.text, command.color)

func DrawVectorText(position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), scale: float = 1.0, width: float = 2.0, align: String = "left", spacing: float = 2.0, font_name: String = "") -> void:
	var string_text = text.to_upper()
	var font_map = _get_vector_font(font_name)
	var total_width = 0.0
	var glyphs = []
	for i in range(string_text.length()):
		var ch = string_text.substr(i, 1)
		var glyph = font_map.get(ch, null)
		if glyph == null:
			glyph = {"width": 8.0, "strokes": []}
		glyphs.append(glyph)
		total_width += glyph.width * scale
		if i < string_text.length() - 1:
			total_width += spacing

	if total_width > 0.0:
		if align == "center":
			position.x -= total_width * 0.5
		elif align == "right":
			position.x -= total_width

	var x_offset = 0.0
	for glyph in glyphs:
		for stroke in glyph.strokes:
			var points = PackedVector2Array()
			for original_point in stroke:
				points.append(position + Vector2(x_offset + original_point.x * scale, original_point.y * scale))
			if points.size() > 1:
				DrawPolyline(points, width, color, false, Color(1, 1, 1, 0), false)
		x_offset += glyph.width * scale + spacing

func DrawVectorTextCentered(position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), scale: float = 1.0, width: float = 2.0, spacing: float = 2.0, font_name: String = "") -> void:
	DrawVectorText(position, text, color, scale, width, "center", spacing, font_name)

func DrawVectorTextRightAligned(position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), scale: float = 1.0, width: float = 2.0, spacing: float = 2.0, font_name: String = "") -> void:
	DrawVectorText(position, text, color, scale, width, "right", spacing, font_name)

func RegisterVectorFont(name: String, glyphs: Dictionary, make_default: bool = false) -> void:
	if name == "":
		return
	_vector_fonts[name] = glyphs
	if make_default:
		_vector_font_name = name

func SetVectorFont(name: String) -> void:
	if _vector_fonts.has(name):
		_vector_font_name = name

func GetVectorFontNames() -> Array:
	return _vector_fonts.keys()

# ── Sine-wave horizontal scroller ──────────────────────────────────────────
func DrawVectorTextWave(text: String, x_offset: float, base_y: float, time: float,
		color: Color = Color(1,1,1,1), scale: float = 1.0, width: float = 2.0,
		amplitude: float = 60.0, wave_freq: float = 0.18, wave_speed: float = 3.0,
		spacing: float = 2.0, hue_cycle: bool = true, font_name: String = "") -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

# ── 3-D helix orbit ────────────────────────────────────────────────────────
func DrawVectorTextHelix(text: String, cx: float, cy: float, time: float,
		color: Color = Color(1,1,1,1), scale: float = 1.0, width: float = 2.0,
		radius: float = 200.0, perspective: float = 0.6, helical_pitch: float = 18.0,
		twist_speed: float = 1.2, char_spacing: float = 0.22, font_name: String = "") -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

# ── Head-over-heels per-character flip (coin-tumble) ───────────────────────
func DrawVectorTextFlip(text: String, x_offset: float, base_y: float, time: float,
		color: Color = Color(1,1,1,1), scale: float = 1.0, width: float = 2.0,
		char_spacing: float = 52.0, flip_speed: float = 0.9, flip_wave: float = 0.38,
		font_name: String = "") -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

# ── Batch draw helpers ─────────────────────────────────────────────────────
func DrawLines(segments: PackedVector2Array, width: float = 2.0, color: Color = Color(1,1,1,1)) -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

func DrawRects(rects_xywh: PackedVector2Array, colors: PackedColorArray, fill: bool = true) -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

func DrawRectsUniform(rects_xywh: PackedVector2Array, color: Color = Color(1,1,1,1), fill: bool = true) -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

# ── Demoscene C++ effects ──────────────────────────────────────────────────
func DrawPlasmaCells(gw: int, gh: int, spd: float, fade: float, pw: float, ph: float, parity: int) -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

func DrawTorusWireframe(rot_y: float, rot_x: float, hue_off: float, tt: float,
		fade: float, cx: float, cy: float, scale: float = 1.0) -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

func DrawSpriteLines(texture: Texture2D, segments: PackedVector2Array, width: float = 6.0, color: Color = Color(1,1,1,1)) -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

# ── Blend / batch mode ────────────────────────────────────────────────────
func SetAdditiveBlend(enable: bool) -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

func SetBatchMode(enable: bool) -> void:
	pass  # implemented in C++ parent VGVectorCanvas2D

# ── Texture helpers ───────────────────────────────────────────────────────
func MakeGlowTexture(size: int = 32, core_color: Color = Color(1,1,1,1)) -> Texture2D:
	return null  # implemented in C++ parent VGVectorCanvas2D

func MakeRadialGlowTexture(size: int = 48, core_color: Color = Color(1,1,1,1)) -> Texture2D:
	return null  # implemented in C++ parent VGVectorCanvas2D

func _get_vector_font(name: String = "") -> Dictionary:
	if _vector_fonts.size() == 0:
		_register_default_vector_font()
	var selected = name
	if selected == "":
		selected = _vector_font_name
	if _vector_fonts.has(selected):
		return _vector_fonts[selected]
	return _vector_fonts["default"]

func _register_default_vector_font() -> void:
	_vector_fonts["default"] = {
		" ": {"width": 6.0, "strokes": []},
		"A": {"width": 10.0, "strokes": [[Vector2(0, 10), Vector2(4, 0), Vector2(8, 10)], [Vector2(2, 5), Vector2(6, 5)]]},
		"B": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(0, 10), Vector2(5, 10), Vector2(7, 8), Vector2(7, 6), Vector2(5, 4), Vector2(0, 4)], [Vector2(5, 4), Vector2(7, 2), Vector2(7, 0), Vector2(5, 0), Vector2(0, 0)]]},
		"C": {"width": 10.0, "strokes": [[Vector2(8, 0), Vector2(2, 0), Vector2(0, 2), Vector2(0, 8), Vector2(2, 10), Vector2(8, 10)]]},
		"D": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(0, 10), Vector2(5, 10), Vector2(8, 7), Vector2(8, 3), Vector2(5, 0), Vector2(0, 0)]]},
		"E": {"width": 10.0, "strokes": [[Vector2(8, 0), Vector2(0, 0), Vector2(0, 10), Vector2(8, 10)], [Vector2(0, 5), Vector2(6, 5)]]},
		"F": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(0, 10), Vector2(8, 10)], [Vector2(0, 5), Vector2(6, 5)]]},
		"G": {"width": 10.0, "strokes": [[Vector2(8, 2), Vector2(6, 0), Vector2(2, 0), Vector2(0, 2), Vector2(0, 8), Vector2(2, 10), Vector2(8, 10), Vector2(8, 6), Vector2(5, 6)]]},
		"H": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(0, 10)], [Vector2(8, 0), Vector2(8, 10)], [Vector2(0, 5), Vector2(8, 5)]]},
		"I": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(8, 0)], [Vector2(4, 0), Vector2(4, 10)], [Vector2(0, 10), Vector2(8, 10)]]},
		"J": {"width": 10.0, "strokes": [[Vector2(8, 0), Vector2(8, 10), Vector2(4, 10), Vector2(2, 8), Vector2(2, 6)]]},
		"K": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(0, 10)], [Vector2(8, 0), Vector2(0, 5), Vector2(8, 10)]]},
		"L": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(0, 10), Vector2(8, 10)]]},
		"M": {"width": 10.0, "strokes": [[Vector2(0, 10), Vector2(0, 0), Vector2(4, 6), Vector2(8, 0), Vector2(8, 10)]]},
		"N": {"width": 10.0, "strokes": [[Vector2(0, 10), Vector2(0, 0), Vector2(8, 10), Vector2(8, 0)]]},
		"O": {"width": 10.0, "strokes": [[Vector2(2, 0), Vector2(6, 0), Vector2(8, 2), Vector2(8, 8), Vector2(6, 10), Vector2(2, 10), Vector2(0, 8), Vector2(0, 2), Vector2(2, 0)]]},
		"P": {"width": 10.0, "strokes": [[Vector2(0, 10), Vector2(0, 0), Vector2(6, 0), Vector2(8, 2), Vector2(8, 4), Vector2(6, 6), Vector2(0, 6)]]},
		"Q": {"width": 10.0, "strokes": [[Vector2(2, 0), Vector2(6, 0), Vector2(8, 2), Vector2(8, 8), Vector2(6, 10), Vector2(2, 10), Vector2(0, 8), Vector2(0, 2), Vector2(2, 0)], [Vector2(5, 6), Vector2(8, 10)]]},
		"R": {"width": 10.0, "strokes": [[Vector2(0, 10), Vector2(0, 0), Vector2(6, 0), Vector2(8, 2), Vector2(8, 4), Vector2(6, 6), Vector2(0, 6)], [Vector2(0, 6), Vector2(8, 10)]]},
		"S": {"width": 10.0, "strokes": [[Vector2(8, 0), Vector2(2, 0), Vector2(0, 2), Vector2(0, 4), Vector2(2, 6), Vector2(6, 6), Vector2(8, 8), Vector2(8, 10), Vector2(2, 10), Vector2(0, 8)]]},
		"T": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(8, 0)], [Vector2(4, 0), Vector2(4, 10)]]},
		"U": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(0, 8), Vector2(2, 10), Vector2(6, 10), Vector2(8, 8), Vector2(8, 0)]]},
		"V": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(4, 10), Vector2(8, 0)]]},
		"W": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(2, 10), Vector2(4, 4), Vector2(6, 10), Vector2(8, 0)]]},
		"X": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(8, 10)], [Vector2(8, 0), Vector2(0, 10)]]},
		"Y": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(4, 5), Vector2(8, 0)], [Vector2(4, 5), Vector2(4, 10)]]},
		"Z": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(8, 0), Vector2(0, 10), Vector2(8, 10)]]},
		"0": {"width": 10.0, "strokes": [[Vector2(2, 0), Vector2(6, 0), Vector2(8, 2), Vector2(8, 8), Vector2(6, 10), Vector2(2, 10), Vector2(0, 8), Vector2(0, 2), Vector2(2, 0)]]},
		"1": {"width": 10.0, "strokes": [[Vector2(4, 0), Vector2(4, 10)], [Vector2(2, 2), Vector2(4, 0), Vector2(6, 2)]]},
		"2": {"width": 10.0, "strokes": [[Vector2(0, 2), Vector2(2, 0), Vector2(6, 0), Vector2(8, 2), Vector2(8, 4), Vector2(0, 10), Vector2(8, 10)]]},
		"3": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(6, 0), Vector2(8, 2), Vector2(6, 4), Vector2(8, 6), Vector2(8, 8), Vector2(6, 10), Vector2(0, 10)]]},
		"4": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(0, 4), Vector2(8, 4)], [Vector2(8, 0), Vector2(8, 10)]]},
		"5": {"width": 10.0, "strokes": [[Vector2(8, 0), Vector2(0, 0), Vector2(0, 4), Vector2(6, 4), Vector2(8, 6), Vector2(8, 10), Vector2(0, 10)]]},
		"6": {"width": 10.0, "strokes": [[Vector2(8, 0), Vector2(2, 0), Vector2(0, 2), Vector2(0, 8), Vector2(2, 10), Vector2(6, 10), Vector2(8, 8), Vector2(8, 6), Vector2(6, 4), Vector2(2, 4)]]},
		"7": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(8, 0), Vector2(4, 10)]]},
		"8": {"width": 10.0, "strokes": [[Vector2(2, 0), Vector2(6, 0), Vector2(8, 2), Vector2(8, 4), Vector2(6, 6), Vector2(8, 8), Vector2(8, 10), Vector2(6, 10), Vector2(2, 10), Vector2(0, 8), Vector2(0, 6), Vector2(2, 4), Vector2(0, 2), Vector2(2, 0)]]},
		"9": {"width": 10.0, "strokes": [[Vector2(8, 8), Vector2(6, 10), Vector2(2, 10), Vector2(0, 8), Vector2(0, 6), Vector2(2, 4), Vector2(6, 4), Vector2(8, 6), Vector2(8, 0), Vector2(0, 0)]]},
		"-": {"width": 10.0, "strokes": [[Vector2(1, 5), Vector2(9, 5)]]},
		"=": {"width": 10.0, "strokes": [[Vector2(1, 4), Vector2(9, 4)], [Vector2(1, 6), Vector2(9, 6)]]},
		":": {"width": 10.0, "strokes": [[Vector2(4, 2), Vector2(6, 2)], [Vector2(4, 8), Vector2(6, 8)]]},
		".": {"width": 10.0, "strokes": [[Vector2(5, 8), Vector2(5, 10)]]},
	}

func DrawLine(from: Vector2, to: Vector2, width: float = 2.0, color: Color = Color(1, 1, 1, 1)) -> void:
	_queue_command({
		"type": CommandType.LINE,
		"from": from,
		"to": to,
		"width": width,
		"color": color,
		"transform": _get_current_transform(),
	})

func DrawRect(rect: Rect2, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0)) -> void:
	_queue_command({
		"type": CommandType.RECT,
		"rect": rect,
		"width": width,
		"color": color,
		"fill": fill,
		"fill_color": fill_color,
		"transform": _get_current_transform(),
	})

func DrawRoundedRect(rect: Rect2, radius: float = 16.0, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0), segments: int = 8) -> void:
	_queue_command({
		"type": CommandType.ROUNDED_RECT,
		"rect": rect,
		"radius": radius,
		"width": width,
		"color": color,
		"fill": fill,
		"fill_color": fill_color,
		"segments": segments,
		"transform": _get_current_transform(),
	})

func DrawEllipse(rect: Rect2, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0), segments: int = 32) -> void:
	_queue_command({
		"type": CommandType.ELLIPSE,
		"rect": rect,
		"width": width,
		"color": color,
		"fill": fill,
		"fill_color": fill_color,
		"segments": segments,
		"transform": _get_current_transform(),
	})

func DrawArc(center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int = 32, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0)) -> void:
	_queue_command({
		"type": CommandType.ARC,
		"center": center,
		"radius": radius,
		"start_angle": start_angle,
		"end_angle": end_angle,
		"segments": segments,
		"width": width,
		"color": color,
		"fill": fill,
		"fill_color": fill_color,
		"transform": _get_current_transform(),
	})

func DrawPolygon(points: Array, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0)) -> void:
	_queue_command({
		"type": CommandType.POLYGON,
		"points": points.duplicate(),
		"width": width,
		"color": color,
		"fill": fill,
		"fill_color": fill_color,
		"transform": _get_current_transform(),
	})

func DrawPolyline(points: Array, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0), close: bool = false) -> void:
	_queue_command({
		"type": CommandType.POLYLINE,
		"points": points.duplicate(),
		"width": width,
		"color": color,
		"fill": fill,
		"fill_color": fill_color,
		"close": close,
		"transform": _get_current_transform(),
	})

func DrawPath(points: Array, width: float = 2.0, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0), close: bool = false) -> void:
	DrawPolyline(points, width, color, fill, fill_color, close)

func DrawCircle(center: Vector2, radius: float, color: Color = Color(1, 1, 1, 1), fill: bool = false, fill_color: Color = Color(1, 1, 1, 0)) -> void:
	DrawEllipse(Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), 0.0, color, fill, fill_color)

func DrawText(position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), font = null) -> void:
	_queue_command({
		"type": CommandType.TEXT,
		"position": position,
		"text": text,
		"color": color,
		"font": font,
		"align": "left",
		"transform": _get_current_transform(),
	})

func DrawTextCentered(position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), font = null) -> void:
	_queue_command({
		"type": CommandType.TEXT,
		"position": position,
		"text": text,
		"color": color,
		"font": font,
		"align": "center",
		"transform": _get_current_transform(),
	})

func DrawTextRightAligned(position: Vector2, text: String, color: Color = Color(1, 1, 1, 1), font = null) -> void:
	_queue_command({
		"type": CommandType.TEXT,
		"position": position,
		"text": text,
		"color": color,
		"font": font,
		"align": "right",
		"transform": _get_current_transform(),
	})

func SetStrokeColor(color: Color) -> void:
	stroke_color = color

func SetFillColor(color: Color) -> void:
	fill_color = color

func SetDefaultFont(font: Font) -> void:
	default_font = font

func PushTransform(transform: Transform2D) -> void:
	_transform_stack.append(_get_current_transform() * transform)

func PushIdentity() -> void:
	_transform_stack.append(Transform2D())

func PopTransform() -> void:
	if _transform_stack.size() > 1:
		_transform_stack.pop_back()

func Translate(offset: Vector2) -> void:
	var current = _get_current_transform()
	current = current.translated(offset)
	_transform_stack[_transform_stack.size() - 1] = current

func Rotate(angle: float) -> void:
	var current = _get_current_transform()
	current = current.rotated(angle)
	_transform_stack[_transform_stack.size() - 1] = current

func Scale(scale: Vector2) -> void:
	var current = _get_current_transform()
	current = current.scaled(scale)
	_transform_stack[_transform_stack.size() - 1] = current

func Clear() -> void:
	_commands.clear()
	_group_stack.clear()
	_frame_line_ord.clear()
	_pending_redraw = false
	# Re-attach runtime-placed/duplicated commands so they survive the per-frame
	# Clear/Draw cycle that the .vg runtime performs.
	for rc in _runtime_commands:
		_commands.append(rc.duplicate(true))
	queue_redraw()
	# Source hints persist across Clear() because they describe code, not state.

func swap_tweak_target(target_id, option_id) -> bool:
	# Delegate to the project-level swap registry. The canvas only routes;
	# the recipe is supplied by the user via VGTweakSwapRegistry.
	var key = str(target_id)
	var group_name: String = "" if key == "__misc" else key
	var SwapReg = load("res://addons/visual_gasic/vg_tweak/vg_tweak_swap_registry.gd")
	if SwapReg == null:
		return false
	return SwapReg.apply_recipe(target_id, self, group_name, str(option_id).trim_prefix("recipe:"))

func list_swap_options(target_id) -> Array:
	var key = str(target_id)
	var group_name: String = "" if key == "__misc" else key
	var SwapReg = load("res://addons/visual_gasic/vg_tweak/vg_tweak_swap_registry.gd")
	if SwapReg == null:
		return []
	return SwapReg.options_for(group_name)

func Render() -> void:
	if not _pending_redraw:
		_pending_redraw = true
		queue_redraw()
