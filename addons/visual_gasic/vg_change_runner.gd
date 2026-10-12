@tool
extends RefCounted
## Runs one protected scenario at a time. The editor polls; it does not block.
## Model text is never passed to the process.

const OUTPUT_CAP := 65536
const DETAIL_LINES := 40

static var timeout_sec := 120.0
static var _job: Dictionary = {}
static var _last_arguments: PackedStringArray = PackedStringArray()


static func last_arguments() -> PackedStringArray:
	return _last_arguments


static func start(project_path: String, script_path: String, _model_text: String = "") -> bool:
	if not _job.is_empty() and OS.is_process_running(int(_job.get("pid", 0))):
		return false
	var args := PackedStringArray()
	args.append("--headless")
	args.append("--path")
	args.append(project_path)
	args.append("--script")
	args.append(script_path)
	_last_arguments = args
	var pipe: Dictionary = OS.execute_with_pipe(OS.get_executable_path(), args, false)
	var pid := int(pipe.get("pid", 0))
	if pid <= 0:
		_job = {}
		return false
	_job = {
		"pid": pid,
		"stdio": pipe.get("stdio", null),
		"stderr": pipe.get("stderr", null),
		"started": Time.get_ticks_msec(),
		"script": script_path,
		"output": "",
	}
	return true


static func poll() -> Dictionary:
	if _job.is_empty():
		return {"done": true, "status": "incomplete", "pid": 0, "name": "", "detail": "", "output": ""}
	var pid := int(_job.get("pid", 0))
	var running := OS.is_process_running(pid)
	var timed := Time.get_ticks_msec() - int(_job.get("started", 0)) >= int(timeout_sec * 1000.0)
	if running and not timed:
		_job["output"] = str(_job.get("output", "")) + _drain()
		return {"done": false, "pid": pid}
	if running and timed:
		OS.kill(pid)
	var output := str(_job.get("output", "")) + _drain()
	if output.length() > OUTPUT_CAP:
		output = output.substr(output.length() - OUTPUT_CAP)
	var parsed := _parse(output, str(_job.get("script", "")))
	if timed or not bool(parsed.get("matched", false)):
		parsed["status"] = "incomplete"
	if timed:
		parsed["reason"] = "timeout"
	parsed["done"] = true
	parsed["pid"] = pid
	parsed["output"] = output
	parsed["detail"] = _tail(output)
	_close_job()
	_job = {}
	return parsed


static func scenario_rows(project_root: String) -> Array:
	var manifest_path := project_root.path_join("vg_expectations.json")
	if not FileAccess.file_exists(manifest_path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var rows: Array = []
	for entry in parsed.get("protected", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var path := str(entry.get("path", ""))
		if not path.ends_with(".gd"):
			continue
		rows.append({
			"path": path,
			"note": str(entry.get("note", "")),
			"sha256": str(entry.get("sha256", "")),
		})
	return rows


static func _drain() -> String:
	return _read_pipe(_job.get("stdio", null)) + _read_pipe(_job.get("stderr", null))


static func _read_pipe(file) -> String:
	if file == null or not (file is FileAccess):
		return ""
	var text := ""
	var guard := 0
	while not file.eof_reached() and guard < 64:
		guard += 1
		var available: int = int(file.get_length()) - int(file.get_position())
		if available <= 0:
			break
		var chunk: PackedByteArray = file.get_buffer(mini(available, 4096))
		if chunk.is_empty():
			break
		text += chunk.get_string_from_utf8()
		if text.length() > OUTPUT_CAP:
			break
	return text


static func _parse(output: String, script_path: String) -> Dictionary:
	var status := "incomplete"
	var name := script_path.get_file()
	var matched := false
	for line in output.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("[PASS] ") or trimmed.begins_with("[FAIL] "):
			matched = true
			status = "pass" if trimmed.begins_with("[PASS]") else "fail"
			name = trimmed.substr(7).strip_edges().split(" ")[0]
	return {"status": status, "name": name, "matched": matched}


static func _tail(output: String) -> String:
	var lines := output.split("\n")
	if lines.size() > DETAIL_LINES:
		lines = lines.slice(lines.size() - DETAIL_LINES)
	return "\n".join(lines)


static func _close_job() -> void:
	for key in ["stdio", "stderr"]:
		var file = _job.get(key, null)
		if file is FileAccess:
			file.close()
