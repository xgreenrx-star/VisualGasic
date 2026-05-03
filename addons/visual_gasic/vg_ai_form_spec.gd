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
	# offsets so the FormDesigner's flat layout stays correct \u2014 the C++
	# side does not (yet) reparent runtime nodes by name.
	var name_to_origin: Dictionary = {}  # control name -> Vector2 absolute origin
	var added := 0
	var skipped: Array[String] = []
	for entry in controls:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype := str(entry.get("type", ""))
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
		# Register this control as a possible parent for later entries.
		var ctrl_name := str(entry.get("name", ""))
		if not ctrl_name.is_empty():
			name_to_origin[ctrl_name] = pos
		added += 1

	var msg := "Built form '%s' \u2014 %d control(s) added" % [form_name, added]
	if not skipped.is_empty():
		msg += "; skipped %d (%s)" % [skipped.size(), ", ".join(skipped)]
	return [added > 0, msg]


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
