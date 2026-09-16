@tool
extends RefCounted
## FORM_SPEC parser + applier — Narcea's stepping-stone toward agent mode.
##
## Narcea is prompted to (optionally) include a JSON block of the form:
##
##   ```vg-form-spec
##   {
##     "form_name": "TicTacToe",
##     "form_size": [300, 350],
##     "controls": [
##       {"type": "Label", "name": "lblTitle", "text": "Tic-Tac-Toe",
##        "left": 10, "top": 10, "width": 280, "height": 20},
##       {"type": "Button", "name": "btn00", "text": "",
##        "left": 10, "top": 40, "width": 90, "height": 90},
##       ...
##     ]
##   }
##   ```
##
## The AI panel scans the latest response, extracts the spec, and
## offers a "🛠 Build form" button.  Clicking it switches to the Form
## Designer, calls new_form() then add_control() per spec entry.
##
## Strict whitelist of control types + property keys to keep this safe:
## the model can't ask for arbitrary script execution or filesystem
## access, only properties the Form Designer knows how to handle.

const CODE_FENCE_RE := "```vg-form-spec\\s*([\\s\\S]*?)```"
const FALLBACK_FENCE_RE := "```(?:json|form|form-spec)?\\s*(\\{[\\s\\S]*?\"controls\"[\\s\\S]*?\\})\\s*```"

# VB6 type aliases → canonical Godot type names.  The model may emit either
# the VB6 name (TextBox, CommandButton) or the Godot name (LineEdit, Button).
# This table normalises both forms so neither gets silently skipped.
const TYPE_ALIASES := {
	"TextBox":       "LineEdit",
	"MultiLine":     "TextEdit",
	"CommandButton": "Button",
	"ComboBox":      "OptionButton",
	"ListBox":       "ItemList",
	"PictureBox":    "TextureRect",
	"Shape":         "ColorRect",
	"Frame":         "GroupBox",
	"ScrollBar":     "VScrollBar",
	"HScrollBar":    "HSlider",
	"VScrollBar":    "VScrollBar",
}

# Whitelist: bare Godot type names the FormDesigner accepts via add_control(type, "", ...)
const ALLOWED_TYPES := [
	"Button",          # CommandButton in VB6 dialect
	"Label",
	"LineEdit",        # TextBox single-line
	"TextEdit",        # TextBox multi-line
	"CheckBox",
	"OptionButton",    # ComboBox
	"ItemList",        # ListBox
	"Panel",
	"PanelContainer",
	"ColorRect",
	"TextureRect",
	"ProgressBar",
	"HSlider",
	"VSlider",
	"SpinBox",
	"Timer",
	# Containers (Round 2): VB6 Frame / GroupBox.  Treated like Panel by
	# the designer but rendered with a border + caption, and child
	# controls in the spec can declare `parent: "<container_name>"`.
	"Frame",
	"GroupBox",
]

# Whitelist of property keys we'll forward to set_control_property().
# The Form Designer's setter understands VB6-style aliases (Caption, Left,
# Top, Width, Height) and the underlying Godot property names.  Round 2
# adds colour and font properties (stored in the property bag, applied at
# render time).
const ALLOWED_PROPS := [
	"text", "caption", "name",
	"font_size",
	"alignment", "horizontal_alignment", "vertical_alignment",
	"editable", "disabled", "visible",
	"placeholder_text",
	"max_length",
	"value", "min_value", "max_value", "step",
	"tooltip_text",
	"modulate",
	"backcolor", "forecolor",   # VB6-style colour properties
	"borderstyle", "appearance",
	"items",          # ItemList / OptionButton: list of strings
	"wait_time",      # Timer
	"autostart",      # Timer
	"parent",         # logical parent: name of a Frame/GroupBox in this spec
]

# Default events emitted per control type when the spec asks for handlers.
# Keep aligned with visual_gasic_plugin._on_fd_control_double_clicked() so
# Narcea's stubs match what double-click would produce manually.
const DEFAULT_EVENT := {
	"Button":       "Click",
	"CheckBox":     "Click",
	"OptionButton": "Click",
	"ItemList":     "Click",
	"LineEdit":     "Change",
	"TextEdit":     "Change",
	"HSlider":      "Change",
	"VSlider":      "Change",
	"SpinBox":      "Change",
	"Timer":        "Timer",
}


## Search a response for a form spec.  Returns parsed Dictionary or {} if
## none found / malformed.  Tolerant of LLM prose around the JSON block.
func extract_spec(response_text: String) -> Dictionary:
	if response_text.is_empty():
		return {}
	# 1. Preferred fence: ```vg-form-spec ... ```
	var rx := RegEx.new()
	rx.compile(CODE_FENCE_RE)
	var m := rx.search(response_text)
	if m:
		return _parse_json(m.get_string(1))
	# 2. Fallback: any code fence whose body looks like a form spec
	#    (contains "controls" key).  Keeps this useful even if the model
	#    forgot the language tag.
	rx.compile(FALLBACK_FENCE_RE)
	m = rx.search(response_text)
	if m:
		return _parse_json(m.get_string(1))
	return {}


func _parse_json(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return {}
	var parsed = JSON.parse_string(trimmed)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	# Bare-minimum shape check: must have a "controls" array.
	if not parsed.has("controls") or typeof(parsed["controls"]) != TYPE_ARRAY:
		return {}
	return parsed


## Validate the layout of a parsed spec.  Returns an Array of human-readable
## warning strings.  An empty array means no issues were detected.
## Checks: (a) every visible control is within form_size bounds,
##         (b) no two visible controls have overlapping bounding boxes.
## Call before or after apply_to_designer.
func check_layout(spec: Dictionary) -> Array:
	var warnings: Array = []
	var controls: Array = spec.get("controls", [])
	if controls.is_empty():
		return warnings

	# Resolve form dimensions.
	var form_w := 400.0
	var form_h := 300.0
	var fs = spec.get("form_size")
	if typeof(fs) == TYPE_ARRAY and (fs as Array).size() == 2:
		form_w = float((fs as Array)[0])
		form_h = float((fs as Array)[1])

	# Build resolved rect list, honouring parent offsets same as apply_to_designer.
	var rects: Array = []  # [{name, l, t, r, b}]
	var name_to_origin: Dictionary = {}  # name -> Vector2 absolute top-left
	for entry in controls:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype: String = TYPE_ALIASES.get(str(entry.get("type", "")), str(entry.get("type", "")))
		if ctype == "Timer":
			continue  # invisible — skip overlap checks
		var cname := str(entry.get("name", ctype))
		var parent_name := str(entry.get("parent", ""))
		var origin := Vector2.ZERO
		if not parent_name.is_empty() and name_to_origin.has(parent_name):
			origin = name_to_origin[parent_name]
		var l := origin.x + float(entry.get("left", 0))
		var t := origin.y + float(entry.get("top", 0))
		var w := float(entry.get("width", 0))
		var h := float(entry.get("height", 0))
		name_to_origin[cname] = Vector2(l, t)
		if w <= 0 or h <= 0:
			continue  # no geometry — nothing to check
		# Bounds check.
		if l + w > form_w:
			warnings.append("'%s' exceeds form width: left(%d)+width(%d)=%d > %d" \
				% [cname, int(l), int(w), int(l + w), int(form_w)])
		if t + h > form_h:
			warnings.append("'%s' exceeds form height: top(%d)+height(%d)=%d > %d" \
				% [cname, int(t), int(h), int(t + h), int(form_h)])
		rects.append({"name": cname, "l": l, "t": t, "r": l + w, "b": t + h})

	# Pairwise overlap check.
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Dictionary = rects[i]
			var b: Dictionary = rects[j]
			if a["l"] < b["r"] and a["r"] > b["l"] and a["t"] < b["b"] and a["b"] > b["t"]:
				var ox := int(minf(a["r"], b["r"]) - maxf(a["l"], b["l"]))
				var oy := int(minf(a["b"], b["b"]) - maxf(a["t"], b["t"]))
				warnings.append("'%s' and '%s' overlap by %dx%d px" \
					% [a["name"], b["name"], ox, oy])
	return warnings


## Build a one-line summary for the confirm dialog.
func describe(spec: Dictionary) -> String:
	if spec.is_empty():
		return ""
	var name: String = str(spec.get("form_name", "Form1"))
	var n: int = (spec.get("controls", []) as Array).size()
	return "Form '%s' with %d control(s)" % [name, n]


## Apply the spec to an instantiated VisualGasicFormDesigner node.
## Returns [ok: bool, msg: String] — `msg` describes what was done or
## why it failed.
func apply_to_designer(spec: Dictionary, designer: Object) -> Array:
	if spec.is_empty():
		return [false, "No form spec found in the AI's reply."]
	if designer == null or not is_instance_valid(designer):
		return [false, "Form Designer is not available."]
	if not designer.has_method("new_form") or not designer.has_method("add_control"):
		return [false, "Form Designer is missing the expected API."]

	var form_name: String = str(spec.get("form_name", "Form1"))
	# Sanitise — strip path separators / junk to be safe.
	form_name = _safe_identifier(form_name, "Form1")

	designer.new_form(form_name)

	# Optional form size.
	if spec.has("form_size") and typeof(spec["form_size"]) == TYPE_ARRAY \
			and (spec["form_size"] as Array).size() == 2 \
			and designer.has_method("set_form_size"):
		var fs: Array = spec["form_size"]
		designer.set_form_size(Vector2(float(fs[0]), float(fs[1])))

	var controls: Array = spec.get("controls", [])
	# Round 2: support a logical "parent" name that points at a container
	# control declared earlier in the spec.  We resolve to absolute pixel
	# offsets so the FormDesigner's flat layout stays correct — the C++
	# side does not (yet) reparent runtime nodes by name.
	var name_to_origin: Dictionary = {}  # control name -> Vector2 absolute origin
	var placed_rects: Array = []          # [{l,t,r,b}] for auto-restack safety net
	var added := 0
	var skipped: Array[String] = []
	for entry in controls:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype := str(entry.get("type", ""))
		# Normalise VB6 aliases (TextBox → LineEdit, CommandButton → Button, …)
		ctype = TYPE_ALIASES.get(ctype, ctype)
		if not ALLOWED_TYPES.has(ctype):
			skipped.append("'%s' (type not whitelisted)" % ctype)
			continue
		var local_pos := Vector2(
			float(entry.get("left", 0)),
			float(entry.get("top", 0)))
		var size := Vector2(
			float(entry.get("width", -1)),
			float(entry.get("height", -1)))
		# Resolve parent offset (Round 2).
		var origin := Vector2.ZERO
		var parent_name := str(entry.get("parent", ""))
		if not parent_name.is_empty() and name_to_origin.has(parent_name):
			origin = name_to_origin[parent_name]
		var pos := origin + local_pos
		# Safety net: if the AI produced overlapping coordinates, push this
		# control down until it clears every already-placed control.
		var ew := size.x if size.x > 0.0 else 80.0
		var eh := size.y if size.y > 0.0 else 24.0
		pos.y = _auto_restack_top(pos.x, pos.y, ew, eh, placed_rects)
		var idx: int = designer.add_control(ctype, "", pos, size)
		if idx < 0:
			skipped.append("'%s' (designer rejected add_control)" % ctype)
			continue
		# Apply whitelisted properties.
		for key in entry.keys():
			var sk := str(key)
			# Skip the structural keys we already consumed.
			if sk in ["type", "left", "top", "width", "height", "parent", "events"]:
				continue
			if not ALLOWED_PROPS.has(sk.to_lower()):
				continue
			if designer.has_method("set_control_property"):
				designer.set_control_property(idx, sk, entry[key])
		# Track placed bounding box for subsequent overlap checks.
		placed_rects.append({"l": pos.x, "t": pos.y, "r": pos.x + ew, "b": pos.y + eh})
		# Register this control as a possible parent for later entries.
		var ctrl_name := str(entry.get("name", ""))
		if not ctrl_name.is_empty():
			name_to_origin[ctrl_name] = pos
		added += 1

	var msg := "Built form '%s' \u2014 %d control(s) added" % [form_name, added]
	if not skipped.is_empty():
		msg += "; skipped %d (%s)" % [skipped.size(), ", ".join(skipped)]
	return [added > 0, msg]


## Push a proposed control's top coordinate down until it no longer overlaps
## any already-placed bounding box.  Runs in O(n²) which is fine for the
## small number of controls on a form.
func _auto_restack_top(nl: float, nt: float, nw: float, nh: float, placed: Array) -> float:
	const GAP := 8.0
	var candidate := nt
	var changed := true
	while changed:
		changed = false
		var nr := nl + nw
		var nb := candidate + nh
		for rect in placed:
			if nl < rect["r"] and nr > rect["l"] \
					and candidate < rect["b"] and nb > rect["t"]:
				candidate = rect["b"] + GAP
				changed = true
				break
	return candidate


## Generate VB6-style event-handler stubs from a spec.  Returns the .vg
## source fragment that should be inserted / written.  Each control with
## an `events` array (or, if absent, the default event for its type when
## `auto_events` is true on the spec) gets one `Sub <name>_<event>()`
## stub with a single comment placeholder body.
##
## Idempotent on the caller side: pass an existing file's text via
## `existing_source` and we'll skip stubs whose Sub already exists.
func generate_event_stubs(spec: Dictionary, existing_source: String = "") -> String:
	if spec.is_empty():
		return ""
	var controls: Array = spec.get("controls", [])
	var auto_events: bool = bool(spec.get("auto_events", false))
	var stubs: Array[String] = []
	for entry in controls:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype := str(entry.get("type", ""))
		# Normalise VB6 aliases so DEFAULT_EVENT lookup works regardless of
		# whether the model used the VB6 name (TextBox) or Godot name (LineEdit).
		ctype = TYPE_ALIASES.get(ctype, ctype)
		var ctrl_name := _safe_identifier(str(entry.get("name", "")), "")
		if ctrl_name.is_empty():
			continue
		# Explicit event list wins; fallback to default for the type.
		var events: Array = entry.get("events", []) if typeof(entry.get("events", null)) == TYPE_ARRAY else []
		if events.is_empty() and auto_events and DEFAULT_EVENT.has(ctype):
			events = [DEFAULT_EVENT[ctype]]
		for ev in events:
			var ev_name := _safe_identifier(str(ev), "")
			if ev_name.is_empty():
				continue
			var sub_name := "%s_%s" % [ctrl_name, ev_name]
			# Skip if the Sub is already in the file (idempotent insert).
			if _has_sub(existing_source, sub_name):
				continue
			stubs.append(_format_stub(sub_name))
	if stubs.is_empty():
		return ""
	return "\n".join(stubs) + "\n"


func _format_stub(sub_name: String) -> String:
	return "\nSub %s()\n    ' TODO: implement %s\nEnd Sub\n" % [sub_name, sub_name]


func _has_sub(source: String, sub_name: String) -> bool:
	if source.is_empty():
		return false
	# Accept "Sub Name(", "Sub Name (", or "Sub Name\n" \u2014 case-insensitive.
	var lower := source.to_lower()
	var needle := ("sub " + sub_name + "(").to_lower()
	if lower.find(needle) != -1:
		return true
	needle = ("sub " + sub_name + " (").to_lower()
	if lower.find(needle) != -1:
		return true
	needle = ("sub " + sub_name).to_lower()
	# Make sure it's followed by space/newline and not another identifier char.
	var idx := lower.find(needle)
	while idx != -1:
		var end := idx + needle.length()
		if end >= lower.length():
			return true
		var nxt := lower[end]
		if nxt == " " or nxt == "(" or nxt == "\t" or nxt == "\n" or nxt == "\r":
			return true
		idx = lower.find(needle, end)
	return false


func _safe_identifier(s: String, fallback: String) -> String:
	var out := ""
	for i in s.length():
		var c := s[i]
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") \
				or (c >= "0" and c <= "9") or c == "_":
			out += c
	if out.is_empty():
		return fallback
	# Identifiers can't start with a digit.
	if out[0] >= "0" and out[0] <= "9":
		out = "_" + out
	return out
