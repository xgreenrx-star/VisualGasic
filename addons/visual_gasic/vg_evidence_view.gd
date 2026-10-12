@tool
extends RefCounted
## Turns one static Whenever report and one behavior-run snapshot into rows.
## Status words only. No prose.

const VGCausalChain = preload("res://addons/visual_gasic/vg_causal_chain.gd")


func build_view(static_report: Dictionary, run: Dictionary, run_state: String) -> Dictionary:
	var chain = VGCausalChain.new()
	var joined: Dictionary = chain.join_runtime(static_report, run)
	var source: Dictionary = static_report.get("source", {})
	var file := str(source.get("identity", ""))
	var root: Dictionary = _whenever_root(static_report)
	var section := str(root.get("section", ""))
	var joined_root: Dictionary = _joined_root(joined, section)
	var root_status := str(joined_root.get("status", "unknown"))
	if root_status.is_empty():
		root_status = "unknown"
	var fire_seqs: Array = joined_root.get("seqs", [])
	var forced := ""
	if root_status == "stale" or root_status == "unknown":
		forced = root_status
	var steps: Array = static_report.get("steps", [])
	var root_index := _root_index(static_report, root)
	var section_steps: Array = _steps_for_root(steps, root_index)
	var rows: Array = []
	var root_line := int(root.get("line", 0))
	rows.append(_row(
		"root",
		"whenever",
		str(root.get("declaration", section)),
		file,
		root_line,
		bool(root.get("location_known", root_line > 0)),
		[],
		root_status,
		fire_seqs,
		_root_detail(run, section),
		0
	))
	var handlers: Array = root.get("handlers", [])
	for handler in handlers:
		if typeof(handler) != TYPE_DICTIONARY:
			continue
		var recorded: Dictionary = handler
		var name := str(recorded.get("name", ""))
		var status := root_status
		var seqs: Array = []
		if forced.is_empty():
			if _callback_missing(run, section, name):
				status = "missing"
			elif _callback_listed(run, section, name):
				status = "observed"
				seqs = _callback_seqs(run, section, name)
			else:
				status = root_status
		else:
			status = forced
		var handler_line := int(recorded.get("line", 0))
		var risks: Array = []
		if str(recorded.get("resolution", "")) != "resolved":
			risks.append("unresolved target")
		rows.append(_row(
			"callback:" + name,
			"callback",
			name,
			file,
			handler_line,
			handler_line > 0 and str(recorded.get("resolution", "")) == "resolved",
			risks,
			status,
			seqs,
			[],
			1
		))
	for step in section_steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var step_row: Dictionary = step
		if _is_handler_call_step(step_row, handlers):
			continue
		var kind := str(step_row.get("kind", ""))
		var runtime := "not_recorded"
		var seqs: Array = []
		var detail: Array = []
		if not forced.is_empty():
			runtime = forced
		elif kind == "state_write":
			var variable := _write_variable(str(step_row.get("text", "")))
			var write_line := int(step_row.get("line", 0))
			var procedure := _procedure_for(step_row, section_steps, root)
			if not _watched(run, variable):
				runtime = "not_recorded"
			else:
				var matches: Array = _matching_writes(run, variable, procedure, write_line, str(source.get("content_hash", "")))
				if matches.is_empty():
					runtime = "not_observed"
				else:
					runtime = "observed"
					for event in matches:
						var write: Dictionary = event
						seqs.append(int(write.get("seq", 0)))
						detail.append("%s %s → %s" % [variable, _fact(write.get("old", "")), _fact(write.get("new", ""))])
		var step_file := str(step_row.get("file", ""))
		if step_file.is_empty():
			step_file = file
		rows.append(_row(
			str(step_row.get("id", "")),
			kind,
			str(step_row.get("text", "")),
			step_file,
			int(step_row.get("line", 0)),
			bool(step_row.get("location_known", false)),
			_copy_risks(step_row.get("risks", [])),
			runtime,
			seqs,
			detail,
			_depth(step_row, section_steps) + 1
		))
	return {
		"header": {
			"section": section,
			"root_status": root_status,
			"fire_count": fire_seqs.size(),
			"run_state": run_state,
			"recording": bool(run.get("recording", false)),
			"dropped": int(run.get("dropped", 0)),
			"capacity": int(run.get("capacity", 0)),
			"watch": run.get("watch", []),
			"stale": root_status == "stale",
			"limitations": _limitations(static_report, run),
		},
		"rows": rows,
	}


func _row(step_id: String, kind: String, text: String, file: String, line: int, location_known: bool, risks: Array, runtime: String, seqs: Array, detail: Array, depth: int) -> Dictionary:
	return {
		"step_id": step_id,
		"kind": kind,
		"text": text,
		"file": file,
		"line": line,
		"location_known": location_known,
		"risks": risks,
		"runtime": runtime,
		"seqs": seqs,
		"detail": detail,
		"depth": depth,
	}


func _whenever_root(static_report: Dictionary) -> Dictionary:
	for root in static_report.get("roots", []):
		if typeof(root) == TYPE_DICTIONARY and str(root.get("kind", "")) == "whenever":
			return root
	return {}


func _root_index(static_report: Dictionary, root: Dictionary) -> int:
	var roots: Array = static_report.get("roots", [])
	for index in roots.size():
		if roots[index] == root:
			return index
	return 0


func _joined_root(joined: Dictionary, section: String) -> Dictionary:
	for root in joined.get("roots", []):
		if typeof(root) != TYPE_DICTIONARY:
			continue
		if str(root.get("section", "")).to_lower() == section.to_lower():
			return root
	return {}


func _steps_for_root(steps: Array, root_index: int) -> Array:
	var found: Array = []
	for step in steps:
		if typeof(step) == TYPE_DICTIONARY and int(step.get("root_index", -1)) == root_index:
			found.append(step)
	return found


func _step_by_id(steps: Array, step_id: String) -> Dictionary:
	for step in steps:
		if typeof(step) == TYPE_DICTIONARY and str(step.get("id", "")) == step_id:
			return step
	return {}


func _depth(step: Dictionary, steps: Array) -> int:
	var depth := 0
	var parent_id := str(step.get("parent_id", ""))
	var guard := 0
	while not parent_id.is_empty() and guard < 40:
		guard += 1
		var parent: Dictionary = _step_by_id(steps, parent_id)
		if parent.is_empty():
			break
		depth += 1
		parent_id = str(parent.get("parent_id", ""))
	return depth


func _procedure_for(step: Dictionary, steps: Array, root: Dictionary) -> String:
	var parent_id := str(step.get("parent_id", ""))
	var guard := 0
	while not parent_id.is_empty() and guard < 40:
		guard += 1
		var parent: Dictionary = _step_by_id(steps, parent_id)
		if parent.is_empty():
			break
		if str(parent.get("kind", "")) == "call" and str(parent.get("target_name", "")) != "":
			return str(parent.get("target_name", ""))
		parent_id = str(parent.get("parent_id", ""))
	return str(root.get("handler", ""))


func _is_handler_call_step(step: Dictionary, handlers: Array) -> bool:
	if str(step.get("kind", "")) != "call" or str(step.get("parent_id", "")) != "":
		return false
	var text := str(step.get("text", "")).to_lower()
	for handler in handlers:
		if typeof(handler) != TYPE_DICTIONARY:
			continue
		var name := str(handler.get("name", "")).to_lower()
		if name.is_empty():
			continue
		if text == "call %s()" % name or text.begins_with("call %s(" % name):
			return true
	return false


func _write_variable(text: String) -> String:
	var at := text.find(" = ")
	if at < 0:
		return text.strip_edges()
	return text.substr(0, at).strip_edges()


func _watched(run: Dictionary, variable: String) -> bool:
	var want := variable.to_lower()
	if want.is_empty():
		return false
	var names = run.get("watch", [])
	if typeof(names) != TYPE_ARRAY and typeof(names) != TYPE_PACKED_STRING_ARRAY:
		return false
	for name in names:
		if str(name).to_lower() == want:
			return true
	return false


func _matching_writes(run: Dictionary, variable: String, procedure: String, line: int, content_hash: String) -> Array:
	var found: Array = []
	for event in run.get("events", []):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("kind", "")) != "watched_write":
			continue
		if str(event.get("variable", "")).to_lower() != variable.to_lower():
			continue
		if str(event.get("procedure", "")).to_lower() != procedure.to_lower():
			continue
		if int(event.get("line", 0)) != line:
			continue
		var event_hash := str(event.get("script_hash", ""))
		if not content_hash.is_empty() and not event_hash.is_empty() and event_hash != content_hash:
			continue
		found.append(event)
	return found


func _callback_missing(run: Dictionary, section: String, callback: String) -> bool:
	for event in run.get("events", []):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("kind", "")) != "callback_missing":
			continue
		if str(event.get("section", "")).to_lower() != section.to_lower():
			continue
		if str(event.get("callback", "")).to_lower() == callback.to_lower():
			return true
	return false


func _callback_listed(run: Dictionary, section: String, callback: String) -> bool:
	for event in _fires(run, section):
		var callbacks: Array = event.get("callbacks", [])
		for row in callbacks:
			if typeof(row) == TYPE_DICTIONARY and str(row.get("name", "")).to_lower() == callback.to_lower():
				return true
	return false


func _callback_seqs(run: Dictionary, section: String, callback: String) -> Array:
	var seqs: Array = []
	for event in _fires(run, section):
		var listed := false
		var callbacks: Array = event.get("callbacks", [])
		for row in callbacks:
			if typeof(row) == TYPE_DICTIONARY and str(row.get("name", "")).to_lower() == callback.to_lower():
				listed = true
		if listed:
			seqs.append(int(event.get("seq", 0)))
	return seqs


func _fires(run: Dictionary, section: String) -> Array:
	var found: Array = []
	for event in run.get("events", []):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("kind", "")) != "whenever_fired":
			continue
		if str(event.get("section", "")).to_lower() == section.to_lower():
			found.append(event)
	return found


func _root_detail(run: Dictionary, section: String) -> Array:
	var detail: Array = []
	for event in run.get("events", []):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("section", "")).to_lower() != section.to_lower():
			continue
		var kind := str(event.get("kind", ""))
		if kind == "whenever_fired":
			detail.append("%s %s → %s" % [str(event.get("variable", "")), _fact(event.get("old", "")), _fact(event.get("new", ""))])
		elif kind == "whenever_suppressed":
			detail.append("reason=%s" % str(event.get("reason", "")))
	return detail


func _fact(value) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var boxed: Dictionary = value
		if boxed.has("value"):
			return str(boxed.get("value", ""))
		if boxed.has("type"):
			return "%s size %s" % [str(boxed.get("type", "")), str(boxed.get("size", 0))]
	return str(value)


func _copy_risks(value) -> Array:
	var risks: Array = []
	if typeof(value) != TYPE_ARRAY:
		return risks
	for item in value:
		risks.append(str(item))
	return risks


func _limitations(static_report: Dictionary, run: Dictionary) -> Array:
	var notes: Array = []
	for text in static_report.get("limitations", []):
		notes.append({"text": str(text), "source": "static"})
	for text in run.get("limitations", []):
		notes.append({"text": str(text), "source": "run"})
	return notes
