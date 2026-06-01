@tool
extends RefCounted
class_name VGTweakSource

# Tier A source-aware patcher: when a target carries a source_hint
# { file, line, col, literal } the patcher rewrites that literal in-place.
#
# Tier B (AI) is exposed as a static helper that just builds a request
# dict; the host project wires it to vg_ai_help.

static func _resolve_path(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://") or p.begins_with("/"):
		return p
	return "res://" + p

static func can_patch(hint: Dictionary) -> bool:
	if hint.is_empty():
		return false
	if not hint.has("file") or not hint.has("line"):
		return false
	return FileAccess.file_exists(_resolve_path(hint["file"]))

static func patch_literal(hint: Dictionary, new_value: Variant) -> Dictionary:
	# Returns {"ok": bool, "old": String, "new": String, "diff": String, "error": String}
	var result := {"ok": false, "old": "", "new": "", "diff": "", "error": ""}
	if not can_patch(hint):
		result["error"] = "no patchable source hint"
		return result
	var path: String = _resolve_path(hint["file"])
	var line_idx: int = int(hint["line"]) - 1
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		result["error"] = "cannot open " + path
		return result
	var text := f.get_as_text()
	f.close()
	var lines := text.split("\n")
	if line_idx < 0 or line_idx >= lines.size():
		result["error"] = "line out of range"
		return result
	var line: String = lines[line_idx]
	var old_literal: String = str(hint.get("literal", ""))
	var new_literal := _format_literal(new_value)
	if old_literal == "":
		result["error"] = "no literal in hint"
		return result
	var col := int(hint.get("col", -1))
	var patched: String
	if col >= 0 and line.substr(col, old_literal.length()) == old_literal:
		patched = line.substr(0, col) + new_literal + line.substr(col + old_literal.length())
	elif line.find(old_literal) >= 0:
		patched = line.replace(old_literal, new_literal)
	else:
		result["error"] = "literal not found on line"
		return result
	result["old"] = line
	result["new"] = patched
	result["diff"] = "- %s\n+ %s" % [line, patched]
	lines[line_idx] = patched
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		result["error"] = "cannot write " + path
		return result
	w.store_string("\n".join(lines))
	w.close()
	result["ok"] = true
	return result

static func _format_literal(v: Variant) -> String:
	match typeof(v):
		TYPE_VECTOR2:
			return "Vector2(%s, %s)" % [_num(v.x), _num(v.y)]
		TYPE_COLOR:
			return "Color(%s, %s, %s, %s)" % [_num(v.r), _num(v.g), _num(v.b), _num(v.a)]
		TYPE_RECT2:
			return "Rect2(%s, %s, %s, %s)" % [_num(v.position.x), _num(v.position.y), _num(v.size.x), _num(v.size.y)]
		TYPE_STRING:
			return "\"%s\"" % String(v).c_escape()
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_FLOAT:
			return _num(v)
		TYPE_INT:
			return str(int(v))
	return str(v)

static func _num(f: float) -> String:
	if abs(f - round(f)) < 0.0001:
		return "%d" % int(round(f))
	return "%.4f" % f

# ─────────────────────────────────────────────────────────────────────────────
# D3 — Property-targeted source patch (MVP)
# ─────────────────────────────────────────────────────────────────────────────
# patch_property(hint, prop, value) is a softer cousin of patch_literal: it
# only needs {file, line} and uses a per-property regex to locate the right
# literal on the line. Today we support `color`/`fill_color` (matches both
# `Color(r,g,b[,a])` and named `Color.RED` forms). Other props return an
# explanatory error so the caller can fall back to the JSON tweak bag.
#
# This is deliberately conservative: the .vg compiler does not yet attach
# token spans to AST nodes (tracked separately), so a one-line one-call
# heuristic is the best we can do without a re-parse step. Round-trip is
# safe for typical Draw* calls where the only `Color(...)` on the line is
# the one we want.
static func patch_property(hint: Dictionary, prop: String, new_value: Variant) -> Dictionary:
	var result := {"ok": false, "old": "", "new": "", "diff": "", "error": ""}
	if hint == null or not hint.has("file") or not hint.has("line"):
		result["error"] = "no source hint (need file+line)"
		return result
	var path: String = _resolve_path(hint["file"])
	if not FileAccess.file_exists(path):
		result["error"] = "file not found: " + path
		return result
	var line_idx: int = int(hint["line"]) - 1
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		result["error"] = "cannot read " + path
		return result
	var text := f.get_as_text()
	f.close()
	var lines := text.split("\n")
	if line_idx < 0 or line_idx >= lines.size():
		result["error"] = "line %d out of range" % (line_idx + 1)
		return result
	var line: String = lines[line_idx]
	var pattern := _pattern_for_prop(prop)
	if pattern == "":
		result["error"] = "source write-back not supported for property '%s' yet" % prop
		return result
	var regex := RegEx.new()
	var compile_err := regex.compile(pattern)
	if compile_err != OK:
		result["error"] = "bad regex for prop"
		return result
	var m := regex.search(line)
	if m == null:
		result["error"] = "no '%s' literal found on line %d" % [prop, line_idx + 1]
		return result
	var old_literal := m.get_string()
	var new_literal := _format_literal(new_value)
	var col := m.get_start()
	var patched := line.substr(0, col) + new_literal + line.substr(col + old_literal.length())
	if patched == line:
		result["error"] = "no change"
		return result
	result["old"] = line
	result["new"] = patched
	result["diff"] = "- %s\n+ %s" % [line, patched]
	lines[line_idx] = patched
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		result["error"] = "cannot write " + path
		return result
	w.store_string("\n".join(lines))
	w.close()
	result["ok"] = true
	return result

static func _pattern_for_prop(prop: String) -> String:
	# Returns a regex matching the source literal that holds `prop`, or ""
	# when D3 doesn't know how to find it yet.
	match prop:
		"color", "fill_color", "modulate", "self_modulate":
			# Color(r, g, b[, a])  OR  Color.RED / Color.SKY_BLUE
			return "Color\\s*\\([^)]*\\)|Color\\.[A-Z][A-Z_0-9]*"
	return ""

# Tier B: build an AI edit request the host can route to vg_ai_help.
static func build_ai_request(target_label: String, prop: String, old_value: Variant, new_value: Variant, source_file: String = "") -> Dictionary:
	return {
		"action": "tweak_edit",
		"target": target_label,
		"property": prop,
		"old_value": str(old_value),
		"new_value": str(new_value),
		"file": source_file,
		"instruction": "Modify the code so that %s.%s resolves to %s instead of %s. Preserve all other behavior." % [target_label, prop, str(new_value), str(old_value)],
	}
