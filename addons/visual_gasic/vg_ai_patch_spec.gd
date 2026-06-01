@tool
extends RefCounted
## Line-level patch spec — Narcea's path to surgical edits without
## rewriting whole files.  Complements vg_ai_code_spec.gd:
##
##   vg-code-spec   → full-file rewrite (replaces source)
##   vg-patch-spec  → small ordered edits applied to existing files
##
## Use when only a handful of lines need to change in a large file, so the
## diff stays readable and the user doesn't lose unrelated code if the
## model forgets to copy a Sub body.
##
## Schema (fenced as ```vg-patch-spec):
##
##   {
##     "edits": [
##       {"path":"res://Form1.vg",
##        "op":"replace",
##        "find":"txtMessage.Text = \"\"",
##        "with":"txtMessage.Text = \"hello\""},
##
##       {"path":"res://Form1.vg",
##        "op":"insert_after",
##        "anchor":"Option Explicit",
##        "text":"' Patched by Narcea"},
##
##       {"path":"res://Form1.vg",
##        "op":"insert_before",
##        "anchor":"End Sub",
##        "text":"    MsgBox \"done\""},
##
##       {"path":"res://Form1.vg",
##        "op":"append",
##        "text":"\nSub btnReset_Click()\n    txtMessage.Text = \"\"\nEnd Sub\n"}
##     ]
##   }
##
## Ops:
##   replace       — first occurrence of `find` becomes `with` (literal,
##                   case-sensitive).  Optional `count` (default 1, -1 = all).
##   insert_after  — find first line equal to `anchor` (trimmed), insert
##                   `text` immediately after it (one new line).
##   insert_before — find first line equal to `anchor` (trimmed), insert
##                   `text` immediately before it.
##   append        — append `text` to the end of the file (creates a
##                   trailing newline if absent).
##
## Each edit is validated; failures surface in the result.skipped list but
## subsequent edits still attempt.  All file writes go through
## vg_ai_safe_write so paths outside `res://` are rejected.

const PATCH_FENCE_RE := "```vg-patch-spec\\s*([\\s\\S]*?)```"


## Pull the first vg-patch-spec block out of an LLM response.
func extract_spec(response_text: String) -> Dictionary:
	if response_text.is_empty():
		return {}
	var rx := RegEx.new()
	rx.compile(PATCH_FENCE_RE)
	var m := rx.search(response_text)
	if m == null:
		return {}
	var parsed = JSON.parse_string(m.get_string(1).strip_edges())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if not parsed.has("edits") or typeof(parsed["edits"]) != TYPE_ARRAY:
		return {}
	return parsed


## Short human description for tooltips.
func describe(spec: Dictionary) -> String:
	if spec.is_empty():
		return ""
	var n: int = (spec.get("edits", []) as Array).size()
	return "%d edit(s)" % n


## Build a per-file diff plan WITHOUT writing anything.
## Groups edits by path so the diff dialog shows one entry per file with
## the full before/after preview.
## Returns [{path, action, old, new, lint, safe, safe_reason, edits}]
func plan(spec: Dictionary, safe_writer: Object) -> Array:
	var out: Array = []
	if spec.is_empty():
		return out
	# Group edits by path while preserving order.
	var by_path: Dictionary = {}
	var path_order: Array = []
	for entry in spec.get("edits", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var p := str(entry.get("path", ""))
		if p.is_empty():
			continue
		if not by_path.has(p):
			by_path[p] = []
			path_order.append(p)
		by_path[p].append(entry)
	for p in path_order:
		var edits: Array = by_path[p]
		var old := ""
		if FileAccess.file_exists(p):
			var rf := FileAccess.open(p, FileAccess.READ)
			if rf:
				old = rf.get_as_text()
				rf.close()
		var apply_res: Dictionary = _apply_edits_to_text(old, edits)
		var new_src: String = apply_res["text"]
		var safety: Array = safe_writer.is_safe(p) if safe_writer else [true, ""]
		var action := "update"
		if not FileAccess.file_exists(p):
			action = "create"
		elif new_src == old:
			action = "unchanged"
		out.append({
			"path": p,
			"old": old,
			"new": new_src,
			"action": action,
			"edits": edits,
			"errors": apply_res["errors"],
			"safe": safety[0],
			"safe_reason": str(safety[1]),
			"lint": [],
		})
	return out


## Apply the spec — writes every safe file via the safe-writer.
func apply(spec: Dictionary, safe_writer: Object, _strict: bool = false) -> Dictionary:
	var result := {
		"ok": false,
		"written": [],
		"skipped": [],
		"lint": [],
		"summary": "",
	}
	if spec.is_empty():
		result["summary"] = "No patch spec to apply."
		return result
	if safe_writer == null:
		result["summary"] = "Safe-writer unavailable."
		return result
	var the_plan := plan(spec, safe_writer)
	for item in the_plan:
		var p: String = item["path"]
		if not item["safe"]:
			result["skipped"].append({"path": p, "reason": item["safe_reason"]})
			continue
		var errs: Array = item["errors"]
		if not errs.is_empty():
			# Record per-edit anchor / find failures but still try to write
			# whatever applied successfully (item.new already reflects only
			# the edits that hit).
			for e in errs:
				result["skipped"].append({"path": p, "reason": str(e)})
		if item["action"] == "unchanged":
			continue
		var write_res: Array = safe_writer.write(p, item["new"])
		if write_res[0]:
			result["written"].append(p)
		else:
			result["skipped"].append({"path": p, "reason": str(write_res[1])})
	var w: int = result["written"].size()
	var s: int = result["skipped"].size()
	result["ok"] = w > 0
	result["summary"] = "patched %d file(s), skipped %d issue(s)" % [w, s]
	return result


# --- internals -------------------------------------------------------------


## Pure helper: given a starting text and an ordered list of edit dicts,
## return {"text": String, "errors": [String]}.  Edits that fail to match
## an anchor / find target are recorded in `errors` and skipped, but
## subsequent edits still try.
func _apply_edits_to_text(text: String, edits: Array) -> Dictionary:
	var errors: Array = []
	var cur := text
	for e in edits:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var op := str(e.get("op", "")).to_lower()
		match op:
			"replace":
				var find_str := str(e.get("find", ""))
				var with_str := str(e.get("with", e.get("replace", "")))
				var count := int(e.get("count", 1))
				if find_str.is_empty():
					errors.append("replace: empty `find`")
					continue
				if cur.find(find_str) == -1:
					errors.append("replace: `find` not found: %s" % _short(find_str))
					continue
				if count < 0:
					cur = cur.replace(find_str, with_str)
				else:
					var remaining := count
					var idx := cur.find(find_str)
					while idx != -1 and remaining > 0:
						cur = cur.substr(0, idx) + with_str + cur.substr(idx + find_str.length())
						idx = cur.find(find_str, idx + with_str.length())
						remaining -= 1
			"insert_after", "insert_before":
				var anchor := str(e.get("anchor", "")).strip_edges()
				var inject := str(e.get("text", ""))
				if anchor.is_empty():
					errors.append("%s: empty `anchor`" % op)
					continue
				var lines := cur.split("\n", true)
				var hit := -1
				for i in lines.size():
					if str(lines[i]).strip_edges() == anchor:
						hit = i
						break
				if hit == -1:
					errors.append("%s: anchor not found: %s" % [op, _short(anchor)])
					continue
				var new_lines: Array = []
				for i in lines.size():
					if op == "insert_before" and i == hit:
						new_lines.append(inject)
					new_lines.append(lines[i])
					if op == "insert_after" and i == hit:
						new_lines.append(inject)
				cur = "\n".join(new_lines)
			"append":
				var txt := str(e.get("text", ""))
				if not cur.is_empty() and not cur.ends_with("\n"):
					cur += "\n"
				cur += txt
			_:
				errors.append("unknown op: %s" % op)
	return {"text": cur, "errors": errors}


func _short(s: String) -> String:
	var t := s.replace("\n", " ").strip_edges()
	if t.length() > 40:
		t = t.substr(0, 37) + "..."
	return t
