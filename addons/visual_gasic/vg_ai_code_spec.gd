@tool
extends RefCounted
## Multi-file code spec — Narcea's text-only path to actual VG source.
##
## Schema (fenced as ```vg-code-spec):
##
##   {
##     "files": [
##       {"path": "res://frmGame.vg",     "source": "..."},
##       {"path": "res://game_state.vg",  "source": "..."},
##       {"path": "res://assets/help.txt", "source": "...", "kind": "text"}
##     ],
##     "main_scene": "res://frmGame.tscn"   // optional, advisory
##   }
##
## Each file is validated before write:
##   * path goes through vg_ai_safe_write (root + forbidden globs);
##   * .vg files are tokenised with VGLinter; ERROR-severity issues are
##     reported but DO NOT block writes by default — the AI panel can
##     pass strict=true to make them fatal.  Warnings are always advisory.
##
## Returns rich result Dictionaries so the caller can render diffs/toasts:
##   {
##     ok: bool,
##     written: [String],          # paths actually written
##     skipped: [{path, reason}],
##     lint:    [{path, issues}],  # only files with lint findings
##     summary: String,
##   }

const CODE_FENCE_RE := "```vg-code-spec\\s*([\\s\\S]*?)```"


## Pull the first vg-code-spec block out of an LLM response.  Returns
## an empty dict if not present / malformed.
func extract_spec(response_text: String) -> Dictionary:
	if response_text.is_empty():
		return {}
	var rx := RegEx.new()
	rx.compile(CODE_FENCE_RE)
	var m := rx.search(response_text)
	if m == null:
		return {}
	var parsed = JSON.parse_string(m.get_string(1).strip_edges())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if not parsed.has("files") or typeof(parsed["files"]) != TYPE_ARRAY:
		return {}
	return parsed


## Short human description for tooltips / toasts.
func describe(spec: Dictionary) -> String:
	if spec.is_empty():
		return ""
	var n: int = (spec.get("files", []) as Array).size()
	return "%d file(s)" % n


## Build a per-file diff plan WITHOUT writing anything.  Returns
##   [{path, action: "create"|"update"|"unchanged", old, new, lint}]
## Used by the diff-preview dialog before the user confirms.
func plan(spec: Dictionary, safe_writer: Object) -> Array:
	var out: Array = []
	if spec.is_empty():
		return out
	var files: Array = spec.get("files", [])
	for entry in files:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var path := str(entry.get("path", ""))
		var src := str(entry.get("source", ""))
		var safety: Array = safe_writer.is_safe(path) if safe_writer else [true, ""]
		var item := {
			"path": path,
			"new": src,
			"old": "",
			"action": "create",
			"lint": [],
			"safe": safety[0],
			"safe_reason": str(safety[1]),
		}
		if FileAccess.file_exists(path):
			var rf := FileAccess.open(path, FileAccess.READ)
			if rf:
				item["old"] = rf.get_as_text()
				rf.close()
			if item["old"] == src:
				item["action"] = "unchanged"
			else:
				item["action"] = "update"
		# Lint .vg only.
		if path.ends_with(".vg"):
			item["lint"] = _lint(src, path)
		out.append(item)
	return out


## Apply the spec — writes every safe file via the safe-writer.  Files
## that fail the safety check or fail to write are reported but the rest
## still proceed.  Returns the result Dictionary documented at the top.
func apply(spec: Dictionary, safe_writer: Object, strict: bool = false) -> Dictionary:
	var result := {
		"ok": false,
		"written": [],
		"skipped": [],
		"lint": [],
		"summary": "",
	}
	if spec.is_empty():
		result["summary"] = "No code spec to apply."
		return result
	if safe_writer == null:
		result["summary"] = "Safe-writer unavailable."
		return result
	var files: Array = spec.get("files", [])
	for entry in files:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var path := str(entry.get("path", ""))
		var src := str(entry.get("source", ""))
		if path.is_empty():
			result["skipped"].append({"path": "<empty>", "reason": "missing path"})
			continue
		# Lint .vg sources before writing.
		if path.ends_with(".vg"):
			var issues := _lint(src, path)
			if not issues.is_empty():
				result["lint"].append({"path": path, "issues": issues})
				if strict and _has_errors(issues):
					result["skipped"].append({"path": path, "reason": "lint errors (strict)"})
					continue
		var write_res: Array = safe_writer.write(path, src)
		if write_res[0]:
			result["written"].append(path)
		else:
			result["skipped"].append({"path": path, "reason": str(write_res[1])})
	var w: int = result["written"].size()
	var s: int = result["skipped"].size()
	result["ok"] = w > 0
	result["summary"] = "wrote %d, skipped %d" % [w, s]
	return result


# --- internals -------------------------------------------------------------


func _lint(source: String, path: String) -> Array:
	# Lazy-load the linter; class_name lookup may fail in headless tests.
	var linter_script := load("res://addons/visual_gasic/vg_linter.gd")
	if linter_script == null:
		return []
	var raw: Array = linter_script.lint_text(source, path)
	var simplified: Array = []
	for issue in raw:
		# LintIssue has at least: severity, message, line.  Convert to a
		# JSON-friendly dict so the diff dialog and chat log can render it.
		var sev := ""
		if "severity" in issue:
			sev = str(issue.severity)
		var msg := ""
		if "message" in issue:
			msg = str(issue.message)
		var line := 0
		if "line" in issue:
			line = int(issue.line)
		simplified.append({"severity": sev, "message": msg, "line": line})
	return simplified


func _has_errors(issues: Array) -> bool:
	for i in issues:
		if typeof(i) != TYPE_DICTIONARY:
			continue
		var sev := str(i.get("severity", "")).to_lower()
		if sev == "error" or sev == "fatal":
			return true
	return false
