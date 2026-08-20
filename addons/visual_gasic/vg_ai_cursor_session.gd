@tool
extends Node
class_name VGAiCursorSession
## Streams a Cursor SDK agent run via `vg_cursor_agent.py` subprocess.
##
## Emits NDJSON events from stdout as stream_token / stream_error / stream_finished.

signal stream_token(text: String)
signal stream_error(message: String)
signal stream_finished(status: String)

const POLL_INTERVAL := 0.05
const PYTHON_CANDIDATES := ["python3", "python"]
const WINDOWS_PYTHON_CANDIDATES := ["py", "python3", "python"]


static func _is_windows() -> bool:
	return OS.get_name() in ["Windows", "UWP"]


static func _is_macos() -> bool:
	return OS.get_name() == "macOS"


static func _macos_python_candidates() -> PackedStringArray:
	return PackedStringArray([
		"/opt/homebrew/bin/python3",  # Apple Silicon Homebrew
		"/usr/local/bin/python3",     # Intel Homebrew / older installs
		"/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
	])


static func venv_dir() -> String:
	return OS.get_user_data_dir().path_join("vg_cursor_venv")


static func venv_python_path() -> String:
	var vdir := venv_dir()
	if _is_windows():
		var win_py := vdir.path_join("Scripts/python.exe")
		return win_py if FileAccess.file_exists(win_py) else ""
	for rel in ["bin/python3", "bin/python"]:
		var py := vdir.path_join(rel)
		if FileAccess.file_exists(py):
			return py
	return ""


static func venv_pip_path() -> String:
	var vdir := venv_dir()
	if _is_windows():
		var win_pip := vdir.path_join("Scripts/pip.exe")
		return win_pip if FileAccess.file_exists(win_pip) else ""
	for rel in ["bin/pip3", "bin/pip"]:
		var pip := vdir.path_join(rel)
		if FileAccess.file_exists(pip):
			return pip
	return ""


static func _resolve_system_python() -> String:
	var output: Array = []
	if _is_windows():
		for candidate in WINDOWS_PYTHON_CANDIDATES:
			var args := PackedStringArray(["-3", "-c", "import sys; print(sys.executable)"]) if candidate == "py" else PackedStringArray(["-c", "import sys; print(sys.executable)"])
			var code: int = OS.execute(candidate, args, output, true, false)
			if code == 0 and output.size() > 0:
				var path := str(output[0]).strip_edges()
				if not path.is_empty() and FileAccess.file_exists(path):
					return path
		return ""
	if _is_macos():
		for candidate in _macos_python_candidates():
			if not FileAccess.file_exists(candidate):
				continue
			output.clear()
			var code: int = OS.execute(candidate, ["-c", "import sys; print(sys.executable)"], output, true, false)
			if code == 0 and output.size() > 0:
				var path := str(output[0]).strip_edges()
				if not path.is_empty() and FileAccess.file_exists(path):
					return path
	for candidate in PYTHON_CANDIDATES:
		output.clear()
		var exit := OS.execute("bash", ["-lc", "command -v %s 2>/dev/null || true" % candidate], output, true, false)
		if exit == 0 and output.size() > 0:
			var path := str(output[0]).strip_edges()
			if not path.is_empty() and FileAccess.file_exists(path):
				return path
	return ""

var _pid: int = -1
var _stdio: FileAccess = null
var _stderr: FileAccess = null
var _stdout_buf := ""
var _stderr_buf := ""
var _timer: Timer = null
var _running := false
var _request_path := ""
var _finished_emitted := false


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL
	_timer.one_shot = false
	_timer.timeout.connect(_poll)
	add_child(_timer)


static func agent_script_path() -> String:
	return ProjectSettings.globalize_path("res://addons/visual_gasic/scripts/vg_cursor_agent.py")


static func resolve_python() -> String:
	# Prefer project-local venv when cursor-sdk is installed there.
	var venv_py := venv_python_path()
	if not venv_py.is_empty() and cursor_sdk_available(venv_py):
		return venv_py
	var system_py := _resolve_system_python()
	if not system_py.is_empty() and cursor_sdk_available(system_py):
		return system_py
	if not venv_py.is_empty():
		return venv_py
	return system_py


static func cursor_sdk_install_hint() -> String:
	var vdir := venv_dir()
	if _is_windows():
		return (
			"Install cursor-sdk for Cursor (Composer): AI Pair → ⚙️ → "
			+ "\"Install cursor-sdk (venv)\", or in cmd:\n  py -3 -m venv \"%s\"\n  \"%s\\Scripts\\pip.exe\" install cursor-sdk"
			% [vdir, vdir]
		)
	if _is_macos():
		return (
			"Install cursor-sdk: AI Pair → ⚙️ → \"Install cursor-sdk (venv)\", or in Terminal:\n"
			+ "  python3 -m venv \"%s\"\n  \"%s/bin/pip\" install cursor-sdk\n"
			+ "(Need Python 3.10+?  brew install python@3.12  or python.org installer)"
			% [vdir, vdir]
		)
	return (
		"Install cursor-sdk: AI Pair → ⚙️ → \"Install cursor-sdk (venv)\", or run:\n"
		+ "  python3 -m venv \"%s\"\n  \"%s/bin/pip\" install cursor-sdk\n"
		+ "(Linux often blocks system pip — use the venv path above.)"
		% [vdir, vdir]
	)


## Create user://vg_cursor_venv and pip install cursor-sdk. Returns {ok, error, python}.
static func bootstrap_cursor_sdk() -> Dictionary:
	var result := {"ok": false, "error": "", "python": ""}
	var system_py := _resolve_system_python()
	if system_py.is_empty():
		if _is_macos():
			result["error"] = (
				"Python 3.10+ not found. Install: brew install python@3.12 "
				+ "or download from python.org, then retry Install cursor-sdk."
			)
		elif _is_windows():
			result["error"] = "Python 3 not found — install from python.org (check \"Add to PATH\")."
		else:
			result["error"] = "Python 3 not found on PATH — install python3 / python3-venv."
		return result

	var vdir := venv_dir()
	var vpy := venv_python_path()
	if vpy.is_empty():
		var out: Array = []
		var code: int = OS.execute(system_py, ["-m", "venv", vdir], out, true, false)
		if code != 0:
			result["error"] = "venv failed: %s" % "\n".join(out).strip_edges()
			return result
		vpy = venv_python_path()
		if vpy.is_empty():
			result["error"] = "venv created but python executable missing"
			return result

	if cursor_sdk_available(vpy):
		result["ok"] = true
		result["python"] = vpy
		return result

	var pip := venv_pip_path()
	if pip.is_empty():
		result["error"] = "venv pip missing under %s" % vdir
		return result

	var pip_out: Array = []
	var pip_code: int = OS.execute(pip, ["install", "cursor-sdk"], pip_out, true, false)
	if pip_code != 0:
		result["error"] = "pip install cursor-sdk failed: %s" % "\n".join(pip_out).strip_edges().substr(0, 400)
		return result
	if not cursor_sdk_available(vpy):
		result["error"] = "pip finished but import cursor_sdk still fails"
		return result

	result["ok"] = true
	result["python"] = vpy
	return result


static func cursor_sdk_available(python: String = "") -> bool:
	var py := python if not python.is_empty() else resolve_python()
	if py.is_empty():
		return false
	var output: Array = []
	var exit := OS.execute(py, ["-c", "import cursor_sdk"], output, true, false)
	return exit == 0


func start(request: Dictionary) -> bool:
	if _running:
		stream_error.emit("Cursor agent already running.")
		return false
	_finished_emitted = false
	var script := agent_script_path()
	if not FileAccess.file_exists(script):
		stream_error.emit("Missing Cursor bridge script: %s" % script)
		return false
	var python := resolve_python()
	if python.is_empty():
		var msg := "Python 3.10+ not found."
		if _is_macos():
			msg += " Install: brew install python@3.12 or python.org installer."
		elif _is_windows():
			msg += " Install from python.org (enable Add to PATH)."
		else:
			msg += " Install python3 and python3-venv."
		stream_error.emit(msg)
		return false
	if not cursor_sdk_available(python):
		stream_error.emit(cursor_sdk_install_hint())
		return false

	_request_path = OS.get_cache_dir().path_join(
		"vg_cursor_req_%d.json" % Time.get_ticks_msec()
	)
	var f := FileAccess.open(_request_path, FileAccess.WRITE)
	if f == null:
		stream_error.emit("Could not write Cursor request file.")
		return false
	f.store_string(JSON.stringify(request))
	f.close()

	var info: Dictionary = OS.execute_with_pipe(
		python,
		PackedStringArray([script, _request_path])
	)
	if info.is_empty():
		_cleanup_request_file()
		stream_error.emit("Failed to spawn Cursor agent subprocess.")
		return false

	_pid = int(info.get("pid", -1))
	_stdio = info.get("stdio")
	_stderr = info.get("stderr")
	if _pid <= 0:
		_cleanup_request_file()
		stream_error.emit("Cursor agent failed to start (pid=%d)." % _pid)
		return false

	_running = true
	_stdout_buf = ""
	_stderr_buf = ""
	_timer.start()
	return true


func stop() -> void:
	if _pid > 0:
		OS.kill(_pid)
	_finalise("cancelled")


func is_running() -> bool:
	return _running and _pid > 0 and OS.is_process_running(_pid)


func _poll() -> void:
	if not _running:
		_timer.stop()
		return
	if _stdio:
		var chunk := _stdio.get_as_text()
		if not chunk.is_empty():
			_stdout_buf += chunk
			_drain_stdout()
	if _stderr:
		_stderr_buf += _stderr.get_as_text()
	if _pid > 0 and not OS.is_process_running(_pid):
		_drain_stdout(true)
		if _running:
			var exit_code := 0
			if OS.has_method("get_process_exit_code"):
				exit_code = int(OS.get_process_exit_code(_pid))
			if exit_code != 0 and not _stderr_buf.strip_edges().is_empty():
				stream_error.emit(_stderr_buf.strip_edges().left(500))
			_finalise("finished" if exit_code == 0 else "error")


func _drain_stdout(flush_tail: bool = false) -> void:
	while true:
		var nl := _stdout_buf.find("\n")
		if nl == -1:
			if flush_tail and not _stdout_buf.strip_edges().is_empty():
				_handle_line(_stdout_buf.strip_edges())
				_stdout_buf = ""
			break
		var line := _stdout_buf.substr(0, nl).strip_edges()
		_stdout_buf = _stdout_buf.substr(nl + 1)
		if not line.is_empty():
			_handle_line(line)


func _handle_line(line: String) -> void:
	var parsed = JSON.parse_string(line)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	match str(parsed.get("type", "")):
		"token":
			var text := str(parsed.get("text", ""))
			if not text.is_empty():
				stream_token.emit(text)
		"error":
			stream_error.emit(str(parsed.get("message", "Cursor agent error")))
			_finalise("error")
		"done":
			_finalise(str(parsed.get("status", "finished")))


func _finalise(status: String) -> void:
	if not _running:
		return
	_running = false
	_finished_emitted = true
	_timer.stop()
	if _stdio:
		_stdio.close()
	if _stderr:
		_stderr.close()
	_stdio = null
	_stderr = null
	_pid = -1
	_cleanup_request_file()
	stream_finished.emit(status)


func _cleanup_request_file() -> void:
	if _request_path.is_empty():
		return
	if FileAccess.file_exists(_request_path):
		DirAccess.remove_absolute(_request_path)
	_request_path = ""
