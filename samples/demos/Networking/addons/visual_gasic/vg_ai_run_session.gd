@tool
extends Node
## Run session — launches a Godot scene as a child process and pipes its
## stdout/stderr back into the AI chat.  The "▶ Run" button uses this so
## Narcea sees runtime output in her next prompt context.
##
## Wraps OS.execute_with_pipe (Godot 4.3+).  We read both pipes on a Timer
## and emit one signal per line.  Owners (vg_ai_help) connect to:
##
##   output_line(stream: "stdout"|"stderr", line: String)
##   finished(exit_code: int)
##
## Usage:
##   var session = preload(\"vg_ai_run_session.gd\").new()
##   add_child(session)              # needs to be in tree for the Timer
##   session.output_line.connect(_on_run_line)
##   session.finished.connect(_on_run_finished)
##   var ok = session.start(scene_path, project_root)
##   ...
##   session.stop()                  # OS.kill on the pid
##
## Output is also captured into a rolling log accessible via
## get_recent_output(max_lines) so Narcea's context probe can include it
## on the next user prompt without the panel having to remember it.

signal output_line(stream: String, line: String)
signal finished(exit_code: int)

const POLL_INTERVAL := 0.1
const MAX_LOG_LINES := 200

var _pid: int = -1
var _stdio: FileAccess = null
var _stderr: FileAccess = null
var _stdout_buf := ""
var _stderr_buf := ""
var _timer: Timer
var _running := false
var _log: Array[String] = []   # newest entries last; ring-bounded


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL
	_timer.one_shot = false
	_timer.timeout.connect(_poll)
	add_child(_timer)


## Start a Godot subprocess running the given scene.
##   scene_path:    "res://path/to/Scene.tscn" (absolute res://) or relative
##                  to scaffold_root when rebasing ai_projects files.
##   scaffold_root: res:// subfolder written by Make project (e.g.
##                  res://ai_projects/Pong/). Used only to rebase relative
##                  scene paths — --path always targets the host project root
##                  that contains project.godot.
##
## Returns true if the process spawned, false otherwise (with an
## explanatory line emitted via output_line(stderr, ...)).
func start(scene_path: String, scaffold_root: String = "") -> bool:
	if _running:
		_emit_stderr("Run session already active.")
		return false
	var scene_res := _normalize_scene_path(scene_path, scaffold_root)
	if scene_res.is_empty():
		_emit_stderr("No scene specified.")
		return false
	var godot_bin := OS.get_executable_path()
	if godot_bin.is_empty():
		godot_bin = "godot"
	# Subprocess godot must --path to the host project (project.godot), not
	# ai_projects/<name>/ which is only a scaffold folder inside it.
	var path_abs := _resolve_godot_project_root(scaffold_root)
	var args := PackedStringArray([
		"--path", path_abs,
		scene_res,
	])
	var info: Dictionary = OS.execute_with_pipe(godot_bin, args)
	if info.is_empty():
		_emit_stderr("OS.execute_with_pipe failed for %s" % godot_bin)
		return false
	_pid    = int(info.get("pid", -1))
	_stdio  = info.get("stdio")
	_stderr = info.get("stderr")
	if _pid <= 0:
		_emit_stderr("Process failed to spawn (pid=%d)" % _pid)
		return false
	_running = true
	_log.clear()
	_emit_stdout("$ %s --path %s %s" % [godot_bin, path_abs, scene_res])
	_timer.start()
	return true


## Host Godot project directory (contains project.godot). ai_projects/
## subfolders are scaffold roots, not standalone projects.
static func _resolve_godot_project_root(scaffold_root: String = "") -> String:
	var host := ProjectSettings.globalize_path("res://").rstrip("/")
	if scaffold_root.strip_edges().is_empty() or scaffold_root == "res://":
		return host
	var candidate := ProjectSettings.globalize_path(scaffold_root).rstrip("/")
	if FileAccess.file_exists(candidate.path_join("project.godot")):
		return candidate
	return host


static func _normalize_scene_path(scene_path: String, scaffold_root: String = "") -> String:
	var p := scene_path.strip_edges()
	if p.is_empty():
		return ""
	if p.begins_with("res://"):
		return p
	var root := scaffold_root.strip_edges()
	if root.is_empty():
		root = "res://"
	if not root.ends_with("/"):
		root += "/"
	return root + p.lstrip("/")


## Send SIGTERM to the running scene (if any).  Idempotent.
func stop() -> void:
	if _pid > 0:
		OS.kill(_pid)
	_finalise(-1)


## Is the subprocess still alive?
func is_running() -> bool:
	return _running and _pid > 0 and OS.is_process_running(_pid)


## Last N captured lines (both streams interleaved with [out]/[err]
## prefixes).  Used by the Narcea context probe.
func get_recent_output(max_lines: int = 40) -> String:
	if _log.is_empty():
		return ""
	var n: int = min(max_lines, _log.size())
	var slice := _log.slice(_log.size() - n)
	return "\n".join(slice)


# --- internals -------------------------------------------------------------


func _poll() -> void:
	if not _running:
		_timer.stop()
		return
	# Drain whatever's in each pipe.  get_as_text() reads all currently
	# buffered bytes without blocking on EOF when used on a pipe.
	if _stdio:
		var s := _stdio.get_as_text()
		if not s.is_empty():
			_stdout_buf += s
			_drain_buf("stdout")
	if _stderr:
		var s2 := _stderr.get_as_text()
		if not s2.is_empty():
			_stderr_buf += s2
			_drain_buf("stderr")
	# Process gone?  Reap exit code and finalise.
	if _pid > 0 and not OS.is_process_running(_pid):
		# Flush any tail.
		if not _stdout_buf.strip_edges().is_empty():
			_emit("stdout", _stdout_buf)
			_stdout_buf = ""
		if not _stderr_buf.strip_edges().is_empty():
			_emit("stderr", _stderr_buf)
			_stderr_buf = ""
		var exit_code := OS.get_process_exit_code(_pid) if OS.has_method("get_process_exit_code") else 0
		_finalise(exit_code)


func _drain_buf(stream: String) -> void:
	var buf := _stdout_buf if stream == "stdout" else _stderr_buf
	while true:
		var nl := buf.find("\n")
		if nl == -1:
			break
		var line := buf.substr(0, nl).rstrip("\r")
		buf = buf.substr(nl + 1)
		_emit(stream, line)
	if stream == "stdout":
		_stdout_buf = buf
	else:
		_stderr_buf = buf


func _emit(stream: String, line: String) -> void:
	if line.is_empty():
		return
	var prefix := "[out] " if stream == "stdout" else "[err] "
	_log.append(prefix + line)
	if _log.size() > MAX_LOG_LINES:
		_log = _log.slice(_log.size() - MAX_LOG_LINES)
	emit_signal("output_line", stream, line)


func _emit_stdout(line: String) -> void:
	_emit("stdout", line)


func _emit_stderr(line: String) -> void:
	_emit("stderr", line)


func _finalise(exit_code: int) -> void:
	if not _running:
		return
	_running = false
	_timer.stop()
	if _stdio:
		_stdio.close()
	if _stderr:
		_stderr.close()
	_stdio = null
	_stderr = null
	_pid = -1
	emit_signal("finished", exit_code)
