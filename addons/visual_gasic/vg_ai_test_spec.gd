@tool
extends RefCounted
## Test-spec — Narcea emits a GDScript `SceneTree` headless test that
## verifies whatever code change she just made.  The AI panel writes the
## file via safe_writer and then runs it through vg_ai_run_session, so
## the user gets an automated green/red result without leaving the chat.
##
## Schema (fenced as ```vg-test-spec):
##
##   {
##     "path": "res://test_my_fix.gd",
##     "source": "extends SceneTree\nfunc _init():\n    assert(...)\n    print(\"[PASS]\")\n    quit(0)\n",
##     "summary": "verifies btnAdd_Click increments the counter"
##   }
##
## Or a multi-test array under `tests`:
##
##   {
##     "tests": [
##       {"path": "res://test_a.gd", "source": "...", "summary": "..."},
##       {"path": "res://test_b.gd", "source": "...", "summary": "..."}
##     ]
##   }

const FENCE_RE := "```vg-test-spec\\s*([\\s\\S]*?)```"


func extract_spec(response_text: String) -> Dictionary:
	if response_text.is_empty():
		return {}
	var rx := RegEx.new()
	rx.compile(FENCE_RE)
	var m := rx.search(response_text)
	if m == null:
		return {}
	var parsed = JSON.parse_string(m.get_string(1).strip_edges())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	# Normalise into {"tests":[{path,source,summary?}, ...]}.
	if parsed.has("tests") and typeof(parsed["tests"]) == TYPE_ARRAY:
		return parsed
	if parsed.has("path") and parsed.has("source"):
		return {"tests": [parsed]}
	return {}


func describe(spec: Dictionary) -> String:
	var n: int = (spec.get("tests", []) as Array).size()
	if n == 1:
		return "1 test (%s)" % str(spec["tests"][0].get("path", "?"))
	return "%d tests" % n


## Returns a plan compatible with vg_ai_diff_dialog.
func plan(spec: Dictionary, safe_writer: Object) -> Array:
	var out: Array = []
	for t in spec.get("tests", []):
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var p := str(t.get("path", ""))
		var src := str(t.get("source", ""))
		if p.is_empty() or src.is_empty():
			continue
		var old := ""
		if FileAccess.file_exists(p):
			var rf := FileAccess.open(p, FileAccess.READ)
			if rf:
				old = rf.get_as_text()
				rf.close()
		var safety: Array = safe_writer.is_safe(p) if safe_writer else [true, ""]
		var action := "create" if old.is_empty() else "update"
		if old == src:
			action = "unchanged"
		out.append({
			"path": p,
			"old": old,
			"new": src,
			"action": action,
			"safe": safety[0],
			"safe_reason": str(safety[1]),
			"lint": [],
		})
	return out


## Apply (write) the test files.  Caller is responsible for running them
## through vg_ai_run_session afterwards.
func apply(spec: Dictionary, safe_writer: Object, _strict: bool = false) -> Dictionary:
	var result := {"ok": false, "written": [], "skipped": [], "lint": [], "summary": ""}
	if spec.is_empty() or safe_writer == null:
		result["summary"] = "No test spec to apply."
		return result
	for t in spec.get("tests", []):
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var p := str(t.get("path", ""))
		var src := str(t.get("source", ""))
		if p.is_empty() or src.is_empty():
			result["skipped"].append({"path": p, "reason": "missing path or source"})
			continue
		var safety: Array = safe_writer.is_safe(p)
		if not safety[0]:
			result["skipped"].append({"path": p, "reason": str(safety[1])})
			continue
		var write_res: Array = safe_writer.write(p, src)
		if write_res[0]:
			result["written"].append(p)
		else:
			result["skipped"].append({"path": p, "reason": str(write_res[1])})
	var w: int = result["written"].size()
	var s: int = result["skipped"].size()
	result["ok"] = w > 0
	result["summary"] = "wrote %d test file(s), skipped %d" % [w, s]
	return result
