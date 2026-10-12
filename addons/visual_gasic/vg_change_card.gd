@tool
extends RefCounted
## Plain change card. Sections stay separate. Nothing here calls a model.

const CLAIM_LIMIT := 600
const LIMITATION := "Static analysis describes possible behavior, not proof that it ran."
const DOES_NOT_REVERSE := "game runs, user:// data, network calls, external tools, editor buffer-only edits, and anything listed as not tracked."
const NO_EXPECTATIONS := "No protected expectations in this project."


static func build_card(change_set: Dictionary, inputs: Dictionary) -> Dictionary:
	var reply := str(inputs.get("reply", change_set.get("reply", "")))
	if reply.length() > CLAIM_LIMIT:
		reply = reply.substr(0, CLAIM_LIMIT)
	var files := _files(change_set, inputs)
	var static_section := _static_section(change_set, inputs)
	var observed := _observed(change_set, inputs)
	var expectations := _expectations(change_set, inputs)
	var rollback := _rollback(change_set, inputs)
	return {
		"claim": {"source": "model", "label": "Narcea says (not verified)", "text": reply},
		"files": {"source": "write_path", "rows": files},
		"static": static_section,
		"observed": {"source": "runtime", "rows": observed},
		"expectations": expectations,
		"rollback": rollback,
	}


static func to_text(card: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var claim: Dictionary = card.get("claim", {})
	lines.append(str(claim.get("label", "")))
	lines.append("source: model")
	lines.append(str(claim.get("text", "")))
	lines.append("")
	lines.append("Files")
	lines.append("source: write_path")
	for row in card.get("files", {}).get("rows", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var extra := ""
		if bool(row.get("binary", false)):
			extra = " | binary"
		elif not str(row.get("line_delta", "")).is_empty():
			extra = " | line delta %s" % str(row.get("line_delta", ""))
		lines.append("%s | %s | bytes before %s after %s%s" % [
			str(row.get("path", "")), str(row.get("action", "")),
			str(row.get("bytes_before", 0)), str(row.get("bytes_after", 0)), extra,
		])
	lines.append("")
	var static_section: Dictionary = card.get("static", {})
	lines.append("Static")
	lines.append("source: compiler")
	lines.append("engine: %s" % str(static_section.get("engine", "")))
	lines.append(str(static_section.get("limitation", "")))
	for row in static_section.get("rows", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		lines.append("%s | %s | %s" % [str(row.get("section", "")), str(row.get("changes", "")), str(row.get("detail", ""))])
	lines.append("")
	lines.append("Observed")
	lines.append("source: runtime")
	for row in card.get("observed", {}).get("rows", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		lines.append("%s | %s" % [str(row.get("path", "")), str(row.get("text", ""))])
	lines.append("")
	var expectations: Dictionary = card.get("expectations", {})
	lines.append("Expectations")
	lines.append("source: user")
	if not str(expectations.get("text", "")).is_empty():
		lines.append(str(expectations.get("text", "")))
	for row in expectations.get("rows", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		lines.append("%s | %s | %s" % [str(row.get("name", "")), str(row.get("status", "")), str(row.get("note", ""))])
	lines.append("")
	var rollback: Dictionary = card.get("rollback", {})
	lines.append("Rollback")
	lines.append("source: write_path")
	lines.append("status: %s" % str(rollback.get("status", "")))
	if str(rollback.get("status", "")) == "incomplete":
		lines.append("Rollback is incomplete.")
	for path in rollback.get("not_tracked", []):
		lines.append("Not tracked: %s" % str(path))
	for row in rollback.get("conflicts", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		lines.append("%s | %s" % [str(row.get("path", "")), str(row.get("reason", ""))])
	if not str(rollback.get("reason", "")).is_empty():
		lines.append(str(rollback.get("reason", "")))
	lines.append("Does not reverse: %s" % DOES_NOT_REVERSE)
	return "\n".join(lines)


static func _files(change_set: Dictionary, inputs: Dictionary) -> Array:
	var before: Dictionary = inputs.get("before", {})
	var after: Dictionary = inputs.get("after", {})
	var rows: Array = []
	for entry in change_set.get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var op := str(entry.get("op", ""))
		if op == "mkdir":
			rows.append({
				"path": str(entry.get("path", "")),
				"action": "created",
				"bytes_before": 0,
				"bytes_after": 0,
				"binary": false,
				"line_delta": "",
			})
			continue
		var path := str(entry.get("path", entry.get("to", "")))
		var action := "modified"
		if op == "remove":
			action = "deleted"
		elif op == "rename":
			action = "renamed"
		elif not bool(entry.get("existed", true)):
			action = "created"
		var line_delta := ""
		if not bool(entry.get("binary", false)):
			var before_text := str(before.get(path, ""))
			var after_text := str(after.get(path, ""))
			if not after.has(path) and not str(entry.get("post_hash", "")).is_empty():
				line_delta = ""
			elif before.has(path) or after.has(path):
				line_delta = str(_line_count(after_text) - _line_count(before_text))
		rows.append({
			"path": path,
			"action": action,
			"bytes_before": int(entry.get("pre_size", 0)),
			"bytes_after": int(entry.get("post_size", 0)),
			"binary": bool(entry.get("binary", false)),
			"line_delta": line_delta,
		})
	for row in change_set.get("not_tracked", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		rows.append({
			"path": str(row.get("path", "")),
			"action": "not tracked",
			"bytes_before": 0,
			"bytes_after": 0,
			"binary": false,
			"line_delta": "",
		})
	return rows


static func _static_section(change_set: Dictionary, inputs: Dictionary) -> Dictionary:
	var before: Dictionary = inputs.get("before", {})
	var after: Dictionary = inputs.get("after", {})
	var Chain = load("res://addons/visual_gasic/vg_causal_chain.gd")
	var chain = Chain.new()
	var rows: Array = []
	var engine := ""
	for entry in change_set.get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var path := str(entry.get("path", ""))
		if not path.ends_with(".vg"):
			continue
		if not before.has(path) and not after.has(path):
			continue
		if before.has(path) and not after.has(path) and not str(entry.get("post_hash", "")).is_empty():
			rows.append({"section": path, "changes": "not available", "detail": "file no longer matches this change"})
			continue
		var before_text := str(before.get(path, ""))
		var after_text := str(after.get(path, ""))
		var before_report: Dictionary = chain.analyze(before_text, [], path)
		var after_report: Dictionary = chain.analyze(after_text, [], path)
		if engine.is_empty():
			engine = str(after_report.get("engine", before_report.get("engine", "")))
		rows.append_array(_diff_reports(before_report, after_report))
	return {
		"source": "compiler",
		"engine": engine,
		"limitation": LIMITATION,
		"rows": rows,
	}


static func _diff_reports(before_report: Dictionary, after_report: Dictionary) -> Array:
	var before_map := _whenever_map(before_report)
	var after_map := _whenever_map(after_report)
	var names: Array = []
	for key in before_map.keys():
		if not names.has(key):
			names.append(key)
	for key in after_map.keys():
		if not names.has(key):
			names.append(key)
	names.sort()
	var rows: Array = []
	for section in names:
		var had: bool = before_map.has(section)
		var has: bool = after_map.has(section)
		if has and not had:
			rows.append({"section": section, "changes": "added", "detail": ""})
			continue
		if had and not has:
			rows.append({"section": section, "changes": "removed", "detail": ""})
			continue
		var before_root: Dictionary = before_map[section]
		var after_root: Dictionary = after_map[section]
		var before_trigger := _trigger(before_root)
		var after_trigger := _trigger(after_root)
		var before_calls := _callbacks(before_root)
		var after_calls := _callbacks(after_root)
		var before_writes := _writes(before_report, before_root)
		var after_writes := _writes(after_report, after_root)
		var changes: Array = []
		var details: Array = []
		if before_trigger != after_trigger:
			changes.append("trigger changed")
			details.append("target %s -> %s" % [str(before_trigger.get("target", "")), str(after_trigger.get("target", ""))])
		if before_calls != after_calls:
			changes.append("callbacks changed")
			details.append("%s -> %s" % [", ".join(before_calls), ", ".join(after_calls)])
		if before_writes != after_writes:
			changes.append("writes changed")
			details.append("%s -> %s" % [", ".join(before_writes), ", ".join(after_writes)])
		if changes.is_empty():
			changes.append("unchanged")
		rows.append({"section": section, "changes": ", ".join(changes), "detail": " | ".join(details)})
	return rows


static func _observed(change_set: Dictionary, inputs: Dictionary) -> Array:
	var after: Dictionary = inputs.get("after", {})
	var snapshot: Dictionary = inputs.get("snapshot", {})
	var rows: Array = []
	for entry in change_set.get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var path := str(entry.get("path", ""))
		if not path.ends_with(".vg"):
			continue
		# The change's own post-write hash, so a rolled-back file never credits an old run to this change.
		var after_hash := str(entry.get("post_hash", ""))
		if after_hash.is_empty() and after.has(path):
			after_hash = _sha_text(str(after.get(path, "")))
		var ran := false
		for script in snapshot.get("scripts", []):
			if typeof(script) != TYPE_DICTIONARY:
				continue
			if str(script.get("content_hash", "")) == after_hash and _same_file(str(script.get("path", "")), path):
				ran = true
		if not ran:
			rows.append({"path": path, "text": "not run since change"})
			continue
		var fires := 0
		var writes := 0
		var suppressions := 0
		for event in snapshot.get("events", []):
			if typeof(event) != TYPE_DICTIONARY:
				continue
			var kind := str(event.get("kind", ""))
			if kind == "whenever_fired":
				fires += 1
			elif kind == "watched_write":
				writes += 1
			elif kind == "whenever_suppressed":
				suppressions += 1
		rows.append({
			"path": path,
			"text": "run %s: fires %d, writes %d, suppressions %d" % [str(snapshot.get("run_id", "")), fires, writes, suppressions],
		})
	return rows


static func _expectations(change_set: Dictionary, inputs: Dictionary) -> Dictionary:
	var given: Dictionary = inputs.get("expectations", {})
	if not bool(given.get("present", false)):
		return {"source": "user", "text": NO_EXPECTATIONS, "rows": []}
	var ended := int(change_set.get("ended_unix", 0))
	var rows: Array = []
	for row in given.get("rows", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var status := str(row.get("status", "not run"))
		var finished := int(row.get("finished_unix", 0))
		var manifest_hash := str(row.get("manifest_hash", ""))
		var scenario_hash := str(row.get("scenario_hash", ""))
		if finished > 0 and ended > 0 and finished < ended:
			status = "stale"
		elif not manifest_hash.is_empty() and manifest_hash != scenario_hash:
			status = "stale"
		rows.append({
			"name": str(row.get("name", "")),
			"status": status,
			"note": str(row.get("note", "")),
		})
	return {"source": "user", "text": "", "rows": rows}


static func _rollback(change_set: Dictionary, inputs: Dictionary) -> Dictionary:
	var state: Dictionary = inputs.get("rollback_state", {})
	var status := str(state.get("status", change_set.get("status", "unavailable")))
	if status == "frozen":
		status = "available"
	if status.is_empty():
		status = "unavailable"
	var names: Array = []
	for row in change_set.get("not_tracked", []):
		if typeof(row) == TYPE_DICTIONARY:
			names.append(str(row.get("path", "")))
	if not names.is_empty():
		status = "incomplete"
	return {
		"source": "write_path",
		"status": status,
		"conflicts": state.get("conflicts", []),
		"not_tracked": names,
		"reason": str(state.get("reason", "")),
		"does_not_reverse": DOES_NOT_REVERSE,
	}


static func _whenever_map(report: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for root in report.get("roots", []):
		if typeof(root) != TYPE_DICTIONARY or str(root.get("kind", "")) != "whenever":
			continue
		out[str(root.get("section", ""))] = root
	return out


static func _trigger(root: Dictionary) -> Dictionary:
	var condition := str(root.get("condition", "")).strip_edges()
	var space := condition.find(" ")
	var operator := condition if space < 0 else condition.substr(0, space)
	var target := "" if space < 0 else condition.substr(space + 1).strip_edges()
	return {"variable": str(root.get("variable", "")), "operator": operator, "target": target}


static func _callbacks(root: Dictionary) -> Array:
	var names: Array = []
	for row in root.get("handlers", []):
		if typeof(row) == TYPE_DICTIONARY:
			names.append(str(row.get("name", "")))
	if names.is_empty() and not str(root.get("handler", "")).is_empty():
		names.append(str(root.get("handler", "")))
	names.sort()
	return names


static func _writes(report: Dictionary, root: Dictionary) -> Array:
	var roots: Array = report.get("roots", [])
	var index := -1
	for i in roots.size():
		if roots[i] == root:
			index = i
			break
	var handler := str(root.get("handler", ""))
	var found: Array = []
	for step in report.get("steps", []):
		if typeof(step) != TYPE_DICTIONARY or str(step.get("kind", "")) != "state_write":
			continue
		if int(step.get("root_index", -2)) != index:
			continue
		var text := str(step.get("text", ""))
		var eq := text.find("=")
		var variable := text.strip_edges() if eq < 0 else text.substr(0, eq).strip_edges()
		var proc := str(step.get("procedure", ""))
		if proc.is_empty():
			proc = handler
		found.append("%s/%s" % [variable, proc])
	found.sort()
	return found


static func _same_file(a: String, b: String) -> bool:
	if a == b:
		return true
	return not a.is_empty() and ProjectSettings.globalize_path(a) == ProjectSettings.globalize_path(b)


static func _line_count(text: String) -> int:
	if text.is_empty():
		return 0
	var n := text.count("\n")
	if not text.ends_with("\n"):
		n += 1
	return n


static func _sha_text(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()
