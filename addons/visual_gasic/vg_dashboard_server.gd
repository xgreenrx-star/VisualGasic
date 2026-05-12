@tool
extends Node
class_name VGDashboardServer

# ── VG Browser Dashboard — minimal embedded HTTP server ────────────────────
# Phase-5 of the long-deferred Browser Dashboard (was a v5.0.1 blocker, now
# landed in v5.2).  Binds 127.0.0.1:8765 by default and serves:
#
#   GET  /                   → tabbed HTML dashboard (Info / Settings / Build / Files / Projects)
#   GET  /api/info           → project + engine version JSON
#   GET  /api/csrf-token     → fresh per-server CSRF token (also set as cookie)
#   GET  /api/settings       → current dashboard settings JSON
#   POST /api/settings       → replace settings (validated, persisted to disk)
#   GET  /api/build/targets  → whitelisted target names + labels
#   GET  /api/build/status   → current build state + last stdout tail
#   GET  /api/build/log      → incremental ?offset=N text fetch (live stream)
#   POST /api/build/run      → start a whitelisted target non-blocking
#   POST /api/build/cancel   → kill the running build, if any
#   GET  /api/files/list     → directory listing under res:// (read-only)
#   GET  /api/files/read     → text file content under res:// (1 MiB cap)
#   GET  /api/projects/list  → current + saved project entries
#   POST /api/projects/add   → add absolute path (must contain project.godot)
#   POST /api/projects/remove→ drop a saved entry
#   POST /api/projects/open  → spawn a fresh Godot editor with the chosen project
#
# Why TCPServer (not godot-cpp HTTPServer)?  Godot has no first-party HTTP
# server class — only client.  We hand-parse a tiny request-line subset
# (METHOD PATH HTTP/1.x + headers + optional Content-Length-framed body)
# which is all the dashboard's fetches need.
#
# Security:
#   - Default bind is 127.0.0.1 (loopback only).  External bind requires
#     an explicit `bind_address` param — caller's responsibility.
#   - CSRF: every POST must carry a matching `X-CSRF-Token` header.  Token
#     is generated once per server start; rotates on stop/start.  Clients
#     fetch it from /api/csrf-token (which also sets it as a cookie).
#   - Build runner accepts only commands from a hard-coded whitelist; raw
#     shell command strings from the client are rejected.
#   - No path-based file serving — pages are inlined to prevent traversal.
#   - All responses set Cache-Control: no-store and X-Content-Type-Options.

const DEFAULT_PORT := 8765
const DEFAULT_BIND := "127.0.0.1"
const MAX_REQUEST_BYTES := 65536  # Hard cap incl. body — refuse anything larger.
const POLL_INTERVAL_SEC := 0.05
const SETTINGS_PATH := "user://vg_dashboard_settings.json"
const BUILD_OUTPUT_TAIL_BYTES := 8192
const BUILD_LOG_PATH := "user://vg_dashboard_build.log"
const BUILD_LOG_MAX_BYTES := 4 * 1024 * 1024  # 4 MiB cap on the on-disk log.

# Whitelist of buildable targets.  Each entry maps a stable API name to a
# concrete argv that OS.execute will run from the project root.  Adding a
# new target is the only supported way to enable it — accepting raw shell
# strings from the client would be an obvious RCE.
const BUILD_COMMANDS := {
	"tests":     {"label": "Run test suite",     "argv": ["bash", "run_test_suite.sh"]},
	"gd_tests":  {"label": "GDScript tests only", "argv": ["bash", "run_test_suite.sh", "--gd-only"]},
	"scons":     {"label": "Build C++ extension", "argv": ["scons", "platform=linux", "target=editor", "-j2"]},
}

var _server: TCPServer
var _connections: Array = []  # Array of {peer, buf, started_at_msec}
var _port: int = DEFAULT_PORT
var _bind: String = DEFAULT_BIND
var _started_at_msec: int = 0
var _timer: Timer = null
var _csrf_token: String = ""
var _settings_cache: Dictionary = {}
var _build_state: Dictionary = {
	"running": false,
	"target": "",
	"started_at_msec": 0,
	"finished_at_msec": 0,
	"exit_code": -1,
	"output_tail": "",
	"log_bytes": 0,    # Total bytes written to BUILD_LOG_PATH so far.
	"pid": -1,
}


func start_server(p_port: int = DEFAULT_PORT, p_bind: String = DEFAULT_BIND) -> bool:
	if _server != null and _server.is_listening():
		push_warning("[VGDashboard] Already listening on %s:%d" % [_bind, _port])
		return true
	_server = TCPServer.new()
	var err := _server.listen(p_port, p_bind)
	if err != OK:
		push_error("[VGDashboard] listen() failed (err=%d) on %s:%d" % [err, p_bind, p_port])
		_server = null
		return false
	_port = p_port
	_bind = p_bind
	_started_at_msec = Time.get_ticks_msec()
	# Fresh CSRF token per server lifetime — rotates on stop/start.
	_csrf_token = _generate_csrf_token()
	_load_settings()
	if _timer == null:
		_timer = Timer.new()
		_timer.wait_time = POLL_INTERVAL_SEC
		_timer.one_shot = false
		_timer.timeout.connect(_on_poll)
		add_child(_timer)
	_timer.start()
	print("[VGDashboard] Listening on http://%s:%d/" % [_bind, _port])
	return true


func stop_server() -> void:
	if _timer != null:
		_timer.stop()
	for c in _connections:
		var peer: StreamPeerTCP = c["peer"]
		if peer != null:
			peer.disconnect_from_host()
	_connections.clear()
	if _server != null:
		_server.stop()
		_server = null
	print("[VGDashboard] Stopped")


func is_running() -> bool:
	return _server != null and _server.is_listening()


func get_url() -> String:
	return "http://%s:%d/" % [_bind, _port]


# ── Internal: poll for new connections + advance existing ones ────────────
func _on_poll() -> void:
	if _server == null:
		return
	# Drain any newly-produced output from a running build process first,
	# so /api/build/log readers see fresh bytes within one poll tick.
	if _build_state.get("running", false):
		_pump_build_state()
	# Accept any pending connections.
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer == null:
			break
		_connections.append({
			"peer": peer,
			"buf": PackedByteArray(),
			"started_at_msec": Time.get_ticks_msec(),
		})
	# Advance each connection.
	var still_alive: Array = []
	for c in _connections:
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		var status := peer.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED:
			# Either closed by client or hit an error — drop it.
			continue
		# Drain available bytes.
		var available := peer.get_available_bytes()
		if available > 0:
			var chunk := peer.get_data(available)
			# get_data returns [error, PackedByteArray] when used this way.
			if chunk is Array and chunk.size() == 2 and chunk[0] == OK:
				c["buf"].append_array(chunk[1])
		# Refuse oversized requests outright.
		if c["buf"].size() > MAX_REQUEST_BYTES:
			_send_response(peer, 413, "text/plain", "Request entity too large".to_utf8_buffer())
			peer.disconnect_from_host()
			continue
		# Wait until headers are complete (CRLFCRLF).
		var sep := _find_header_terminator(c["buf"])
		if sep < 0:
			# Connection too old without progress → drop.
			if Time.get_ticks_msec() - c["started_at_msec"] > 5000:
				peer.disconnect_from_host()
				continue
			still_alive.append(c)
			continue
		# Parse the request line + headers up front so we know if there is
		# a Content-Length-framed body still to wait for.
		var head_bytes: PackedByteArray = c["buf"].slice(0, sep)
		var head := head_bytes.get_string_from_utf8()
		var headers := _parse_headers(head)
		var content_length := int(headers.get("content-length", "0"))
		if content_length < 0:
			content_length = 0
		var total_needed := sep + content_length
		if total_needed > MAX_REQUEST_BYTES:
			_send_response(peer, 413, "text/plain", "Request entity too large".to_utf8_buffer())
			peer.disconnect_from_host()
			continue
		if c["buf"].size() < total_needed:
			# Still waiting for body bytes.
			if Time.get_ticks_msec() - c["started_at_msec"] > 10000:
				peer.disconnect_from_host()
				continue
			still_alive.append(c)
			continue
		var body: PackedByteArray = c["buf"].slice(sep, total_needed)
		_handle_request(peer, head, headers, body)
		peer.disconnect_from_host()
	_connections = still_alive


func _find_header_terminator(buf: PackedByteArray) -> int:
	# Returns index of byte AFTER the final \r\n\r\n, or -1 if not found yet.
	# Also accepts bare-LF terminators for tolerant clients.
	for i in range(buf.size() - 3):
		if buf[i] == 13 and buf[i + 1] == 10 and buf[i + 2] == 13 and buf[i + 3] == 10:
			return i + 4
	for i in range(buf.size() - 1):
		if buf[i] == 10 and buf[i + 1] == 10:
			return i + 2
	return -1


func _parse_headers(head: String) -> Dictionary:
	# Returns a dict with lower-cased header names → value.  The request line
	# is intentionally skipped here — callers parse it separately.
	var out: Dictionary = {}
	var lines := head.split("\n", false)
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty():
			continue
		var colon := line.find(":")
		if colon <= 0:
			continue
		var name := line.substr(0, colon).strip_edges().to_lower()
		var value := line.substr(colon + 1).strip_edges()
		out[name] = value
	return out


func _handle_request(peer: StreamPeerTCP, head: String, headers: Dictionary, body: PackedByteArray) -> void:
	# Parse request line: "METHOD PATH HTTP/1.x"
	var first_nl := head.find("\n")
	if first_nl < 0:
		_send_response(peer, 400, "text/plain", "Malformed request".to_utf8_buffer())
		return
	var request_line := head.substr(0, first_nl).strip_edges()
	var parts := request_line.split(" ", false)
	if parts.size() < 2:
		_send_response(peer, 400, "text/plain", "Malformed request line".to_utf8_buffer())
		return
	var method: String = parts[0].to_upper()
	var raw_path: String = parts[1]
	if method != "GET" and method != "POST":
		_send_response(peer, 405, "text/plain", "Only GET and POST are supported".to_utf8_buffer())
		return
	# Strip query string for routing.
	var qs_idx := raw_path.find("?")
	var path := raw_path if qs_idx < 0 else raw_path.substr(0, qs_idx)
	var query := "" if qs_idx < 0 else raw_path.substr(qs_idx + 1)
	if method == "GET":
		_route_get(peer, path, query)
	else:
		# All POSTs need a matching CSRF token.
		var supplied := String(headers.get("x-csrf-token", ""))
		if supplied.is_empty() or supplied != _csrf_token:
			_send_response(peer, 403, "application/json",
				JSON.stringify({"error": "csrf_mismatch"}).to_utf8_buffer())
			return
		_route_post(peer, path, headers, body)


func _route_get(peer: StreamPeerTCP, path: String, query: String = "") -> void:
	match path:
		"/", "/index.html":
			# Stamp the CSRF cookie on every page load — convenient for
			# clients that prefer reading it from document.cookie.
			_send_response(peer, 200, "text/html; charset=utf-8",
				_dashboard_html().to_utf8_buffer(), _csrf_cookie_headers())
		"/api/info":
			_send_response(peer, 200, "application/json",
				JSON.stringify(_collect_info(), "  ").to_utf8_buffer())
		"/api/csrf-token":
			_send_response(peer, 200, "application/json",
				JSON.stringify({"csrf_token": _csrf_token}).to_utf8_buffer(),
				_csrf_cookie_headers())
		"/api/settings":
			_send_response(peer, 200, "application/json",
				JSON.stringify(_settings_cache, "  ").to_utf8_buffer())
		"/api/build/status":
			# Refresh the in-memory tail/log_bytes before reporting so callers
			# polling this route alone (no /api/build/log fetches) still see
			# progress.
			if _build_state.get("running", false):
				_pump_build_state()
			_send_response(peer, 200, "application/json",
				JSON.stringify(_build_state, "  ").to_utf8_buffer())
		"/api/build/targets":
			var t := {}
			for k in BUILD_COMMANDS.keys():
				t[k] = BUILD_COMMANDS[k]["label"]
			_send_response(peer, 200, "application/json",
				JSON.stringify(t, "  ").to_utf8_buffer())
		"/api/build/log":
			_route_build_log(peer, query)
		"/api/files/list":
			_route_files_list(peer, query)
		"/api/files/read":
			_route_files_read(peer, query)
		"/api/projects/list":
			_send_response(peer, 200, "application/json",
				JSON.stringify(_collect_projects(), "  ").to_utf8_buffer())
		"/favicon.ico":
			_send_response(peer, 204, "text/plain", PackedByteArray())
		_:
			_send_response(peer, 404, "text/plain",
				("Not found: " + path).to_utf8_buffer())


func _route_post(peer: StreamPeerTCP, path: String, headers: Dictionary, body: PackedByteArray) -> void:
	var body_str := body.get_string_from_utf8()
	var parsed: Variant = null
	if not body_str.is_empty():
		var j := JSON.new()
		if j.parse(body_str) != OK:
			_send_response(peer, 400, "application/json",
				JSON.stringify({"error": "invalid_json", "detail": j.get_error_message()}).to_utf8_buffer())
			return
		parsed = j.data
	match path:
		"/api/settings":
			if not (parsed is Dictionary):
				_send_response(peer, 400, "application/json",
					JSON.stringify({"error": "expected_object"}).to_utf8_buffer())
				return
			var validated := _validate_settings(parsed)
			_settings_cache = validated
			_save_settings()
			_send_response(peer, 200, "application/json",
				JSON.stringify({"ok": true, "settings": _settings_cache}).to_utf8_buffer())
		"/api/build/run":
			if _build_state["running"]:
				_send_response(peer, 409, "application/json",
					JSON.stringify({"error": "build_already_running"}).to_utf8_buffer())
				return
			var target: String = ""
			if parsed is Dictionary:
				target = String(parsed.get("target", ""))
			if not BUILD_COMMANDS.has(target):
				_send_response(peer, 400, "application/json",
					JSON.stringify({"error": "unknown_target", "valid": BUILD_COMMANDS.keys()}).to_utf8_buffer())
				return
			var started := _start_build(target)
			if not started.get("ok", false):
				_send_response(peer, 500, "application/json",
					JSON.stringify(started).to_utf8_buffer())
				return
			_send_response(peer, 200, "application/json",
				JSON.stringify({"ok": true, "target": target, "pid": _build_state["pid"]}).to_utf8_buffer())
		"/api/build/cancel":
			if not _build_state.get("running", false):
				_send_response(peer, 409, "application/json",
					JSON.stringify({"error": "no_build_running"}).to_utf8_buffer())
				return
			var cancelled := _cancel_build()
			_send_response(peer, 200, "application/json",
				JSON.stringify(cancelled).to_utf8_buffer())
		"/api/projects/add":
			var p_path: String = ""
			if parsed is Dictionary:
				p_path = String(parsed.get("path", ""))
			var added := _projects_add(p_path)
			var code := 200 if added.get("ok", false) else 400
			_send_response(peer, code, "application/json",
				JSON.stringify(added).to_utf8_buffer())
		"/api/projects/remove":
			var r_path: String = ""
			if parsed is Dictionary:
				r_path = String(parsed.get("path", ""))
			var removed := _projects_remove(r_path)
			var code2 := 200 if removed.get("ok", false) else 400
			_send_response(peer, code2, "application/json",
				JSON.stringify(removed).to_utf8_buffer())
		"/api/projects/open":
			var o_path: String = ""
			if parsed is Dictionary:
				o_path = String(parsed.get("path", ""))
			var opened := _projects_open(o_path)
			var code3 := 200 if opened.get("ok", false) else 400
			_send_response(peer, code3, "application/json",
				JSON.stringify(opened).to_utf8_buffer())
		_:
			_send_response(peer, 404, "application/json",
				JSON.stringify({"error": "not_found", "path": path}).to_utf8_buffer())


# ── Settings persistence ──────────────────────────────────────────────────
func _settings_defaults() -> Dictionary:
	return {
		"auto_refresh_secs": 2,
		"show_build_panel": true,
		"theme": "dark",
	}


func _validate_settings(d: Dictionary) -> Dictionary:
	# Whitelist-only: drop unknown keys, clamp known ones to safe ranges.
	var defaults := _settings_defaults()
	var out := defaults.duplicate()
	if d.has("auto_refresh_secs"):
		var r := int(d["auto_refresh_secs"])
		out["auto_refresh_secs"] = clamp(r, 1, 60)
	if d.has("show_build_panel"):
		out["show_build_panel"] = bool(d["show_build_panel"])
	if d.has("theme"):
		var t := String(d["theme"])
		out["theme"] = t if t in ["dark", "light"] else "dark"
	return out


func _load_settings() -> void:
	_settings_cache = _settings_defaults()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var j := JSON.new()
	if j.parse(f.get_as_text()) == OK and j.data is Dictionary:
		_settings_cache = _validate_settings(j.data)


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[VGDashboard] Cannot persist settings to %s" % SETTINGS_PATH)
		return
	f.store_string(JSON.stringify(_settings_cache, "  "))


# ── Build runner (non-blocking, whitelisted) ──────────────────────────────
func _start_build(target: String) -> Dictionary:
	# Wrap the target argv inside bash -c so a single shell pipeline can
	# redirect both streams to BUILD_LOG_PATH.  This decouples reading the
	# log from the child's pipe buffering — we read the file on every poll
	# tick and OS never has to wait on us.
	var argv: Array = BUILD_COMMANDS[target]["argv"]
	var log_abs := ProjectSettings.globalize_path(BUILD_LOG_PATH)

	# Reset the log file before each run so log_offset=0 always starts at
	# the new build's first byte.
	var fw := FileAccess.open(BUILD_LOG_PATH, FileAccess.WRITE)
	if fw == null:
		return {"ok": false, "error": "cannot_open_log", "path": log_abs}
	fw.close()

	# Build a properly quoted shell command from the argv whitelist entry.
	var quoted_parts: Array[String] = []
	for piece in argv:
		quoted_parts.append(_shell_quote(String(piece)))
	var cmd_str := " ".join(quoted_parts)
	var shell_line := "set -o pipefail; { %s; } > %s 2>&1" % [cmd_str, _shell_quote(log_abs)]

	var pid := OS.create_process("bash", ["-c", shell_line])
	if pid <= 0:
		return {"ok": false, "error": "spawn_failed"}

	_build_state["running"] = true
	_build_state["target"] = target
	_build_state["started_at_msec"] = Time.get_ticks_msec()
	_build_state["finished_at_msec"] = 0
	_build_state["exit_code"] = -1
	_build_state["output_tail"] = ""
	_build_state["log_bytes"] = 0
	_build_state["pid"] = pid
	return {"ok": true, "pid": pid}


func _cancel_build() -> Dictionary:
	var pid := int(_build_state.get("pid", -1))
	if pid <= 0:
		return {"ok": false, "error": "no_pid"}
	var err := OS.kill(pid)
	if err != OK:
		return {"ok": false, "error": "kill_failed", "code": err}
	# Let _pump_build_state observe the exit on the next tick so log_bytes
	# stays consistent for in-flight log readers.
	return {"ok": true, "pid": pid}


func _pump_build_state() -> void:
	# Refresh log_bytes from disk so /api/build/log readers can request the
	# range they have not yet seen, and refresh output_tail for status
	# pollers that don't fetch the log directly.
	var fr := FileAccess.open(BUILD_LOG_PATH, FileAccess.READ)
	if fr != null:
		var n := fr.get_length()
		if n > 0:
			var tail_off: int = max(0, n - BUILD_OUTPUT_TAIL_BYTES)
			fr.seek(tail_off)
			var tail_buf := fr.get_buffer(n - tail_off)
			var tail := tail_buf.get_string_from_utf8()
			if tail_off > 0:
				tail = "...(truncated head)...\n" + tail
			_build_state["output_tail"] = tail
		_build_state["log_bytes"] = n
		fr.close()

	var pid := int(_build_state.get("pid", -1))
	if pid > 0 and not OS.is_process_running(pid):
		_build_state["running"] = false
		_build_state["finished_at_msec"] = Time.get_ticks_msec()
		_build_state["exit_code"] = OS.get_process_exit_code(pid)


# Plain-text incremental log slice starting at ?offset=N.  Headers carry
# running flag, exit code, and current log_bytes so the client can decide
# whether to keep polling.
func _route_build_log(peer: StreamPeerTCP, query: String) -> void:
	var params := _parse_query(query)
	var offset := int(params.get("offset", "0"))
	if offset < 0:
		offset = 0
	var headers := [
		"X-Build-Running: " + ("1" if _build_state.get("running", false) else "0"),
		"X-Build-Exit-Code: " + str(int(_build_state.get("exit_code", -1))),
		"X-Build-Log-Bytes: " + str(int(_build_state.get("log_bytes", 0))),
	]
	var fr := FileAccess.open(BUILD_LOG_PATH, FileAccess.READ)
	if fr == null:
		_send_response(peer, 200, "text/plain; charset=utf-8", PackedByteArray(), headers)
		return
	var n := fr.get_length()
	if offset >= n:
		fr.close()
		_send_response(peer, 200, "text/plain; charset=utf-8", PackedByteArray(), headers)
		return
	var to_read: int = min(n - offset, BUILD_LOG_MAX_BYTES)
	fr.seek(offset)
	var buf := fr.get_buffer(to_read)
	fr.close()
	_send_response(peer, 200, "text/plain; charset=utf-8", buf, headers)


func _parse_query(query: String) -> Dictionary:
	var out: Dictionary = {}
	if query.is_empty():
		return out
	for pair in query.split("&", false):
		var eq := pair.find("=")
		if eq < 0:
			out[pair.uri_decode()] = ""
		else:
			var k := pair.substr(0, eq).uri_decode()
			var v := pair.substr(eq + 1).uri_decode()
			out[k] = v
	return out


func _shell_quote(s: String) -> String:
	# POSIX single-quote escaping: foo → 'foo' ; ' inside becomes '\''.
	return "'" + s.replace("'", "'\\''") + "'"


# ── Project file explorer (read-only, res:// only) ────────────────────────
# All paths are normalised to "/"-rooted relative paths inside res://.
# Anything containing ".." or starting with "/" outside that prefix gets
# rejected before touching the filesystem.
const FILE_READ_MAX_BYTES := 1024 * 1024  # 1 MiB cap on a single viewer read.
const FILE_TEXT_EXTS := [
	"vg", "gd", "json", "tres", "tscn", "cfg", "txt", "md", "yaml", "yml",
	"xml", "ini", "csv", "shader", "gdshader", "log", "html", "css", "js",
	"py", "sh", "ps1", "c", "cpp", "h", "hpp", "scons", "uid",
]
const FILE_LIST_HIDDEN_PREFIXES := [".git", ".godot", ".import", ".vscode"]


func _safe_res_path(rel: String) -> String:
	# Returns a clean res:// path, or "" if `rel` tries to escape.
	var p := rel.strip_edges()
	while p.begins_with("/"):
		p = p.substr(1)
	if p == "" or p == ".":
		return "res://"
	# Reject any traversal attempt up front — also rejects encoded forms
	# that survive uri_decode().
	if "\\" in p:
		return ""
	var parts := p.split("/", false)
	for part in parts:
		if part == ".." or part == ".":
			return ""
	return "res://" + p


func _route_files_list(peer: StreamPeerTCP, query: String) -> void:
	var params := _parse_query(query)
	var rel: String = String(params.get("path", ""))
	var safe := _safe_res_path(rel)
	if safe == "":
		_send_response(peer, 400, "application/json",
			JSON.stringify({"error": "bad_path"}).to_utf8_buffer())
		return
	var dir := DirAccess.open(safe)
	if dir == null:
		_send_response(peer, 404, "application/json",
			JSON.stringify({"error": "not_found", "path": safe}).to_utf8_buffer())
		return
	var entries: Array = []
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue
		var is_dir := dir.current_is_dir()
		var skip := false
		for prefix in FILE_LIST_HIDDEN_PREFIXES:
			if name.begins_with(prefix):
				skip = true
				break
		if skip:
			continue
		var entry := {"name": name, "is_dir": is_dir}
		if not is_dir:
			# Cheap stat — open + length.
			var f := FileAccess.open(safe.path_join(name), FileAccess.READ)
			if f != null:
				entry["size"] = f.get_length()
				f.close()
		entries.append(entry)
	dir.list_dir_end()
	# Sort: directories first, then by name.
	entries.sort_custom(func(a, b):
		if a["is_dir"] != b["is_dir"]:
			return a["is_dir"]
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0
	)
	var out := {"path": safe, "entries": entries}
	_send_response(peer, 200, "application/json",
		JSON.stringify(out, "  ").to_utf8_buffer())


func _route_files_read(peer: StreamPeerTCP, query: String) -> void:
	var params := _parse_query(query)
	var rel: String = String(params.get("path", ""))
	var safe := _safe_res_path(rel)
	if safe == "" or safe == "res://":
		_send_response(peer, 400, "application/json",
			JSON.stringify({"error": "bad_path"}).to_utf8_buffer())
		return
	if not FileAccess.file_exists(safe):
		_send_response(peer, 404, "application/json",
			JSON.stringify({"error": "not_found", "path": safe}).to_utf8_buffer())
		return
	var ext := safe.get_extension().to_lower()
	var is_text := ext in FILE_TEXT_EXTS
	var f := FileAccess.open(safe, FileAccess.READ)
	if f == null:
		_send_response(peer, 500, "application/json",
			JSON.stringify({"error": "open_failed"}).to_utf8_buffer())
		return
	var n := f.get_length()
	var truncated := false
	var to_read := n
	if to_read > FILE_READ_MAX_BYTES:
		to_read = FILE_READ_MAX_BYTES
		truncated = true
	var buf := f.get_buffer(to_read)
	f.close()
	if not is_text:
		# Return metadata only — refuse to ship raw binaries to the browser.
		_send_response(peer, 200, "application/json",
			JSON.stringify({
				"path": safe, "size": n, "ext": ext,
				"binary": true, "message": "Binary preview not supported.",
			}, "  ").to_utf8_buffer())
		return
	var text := buf.get_string_from_utf8()
	_send_response(peer, 200, "application/json",
		JSON.stringify({
			"path": safe, "size": n, "ext": ext,
			"binary": false, "truncated": truncated, "content": text,
		}, "  ").to_utf8_buffer())


# ── Project registry (multi-project switcher) ─────────────────────────────
# A small persisted list of known VG/Godot projects.  Each entry is the
# absolute path to a directory containing project.godot.  The current
# project is included automatically as a synthetic first entry.  Adding
# a path validates that project.godot exists before persisting.  Opening
# launches a fresh Godot editor instance via OS.create_process so the
# running editor (and its dashboard) keep operating.
const PROJECTS_PATH := "user://vg_dashboard_projects.json"


func _projects_load_list() -> Array:
	if not FileAccess.file_exists(PROJECTS_PATH):
		return []
	var f := FileAccess.open(PROJECTS_PATH, FileAccess.READ)
	if f == null:
		return []
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return []
	if not (j.data is Array):
		return []
	var clean: Array = []
	for entry in j.data:
		var p := String(entry).strip_edges()
		if p != "" and not (p in clean):
			clean.append(p)
	return clean


func _projects_save_list(list: Array) -> bool:
	var f := FileAccess.open(PROJECTS_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(list, "  "))
	return true


func _project_meta(abs_path: String) -> Dictionary:
	# Returns {path, name, exists}.  `name` is read from project.godot's
	# `application/config/name` line if available, falling back to dir
	# basename.
	var meta := {"path": abs_path, "name": abs_path.get_file(), "exists": false}
	var godot_file := abs_path.path_join("project.godot")
	if not FileAccess.file_exists(godot_file):
		return meta
	meta["exists"] = true
	var f := FileAccess.open(godot_file, FileAccess.READ)
	if f == null:
		return meta
	# Cheap line scan — project.godot is ini-ish; the first match wins.
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("config/name="):
			var v := line.substr("config/name=".length()).strip_edges()
			if v.begins_with("\"") and v.ends_with("\""):
				v = v.substr(1, v.length() - 2)
			meta["name"] = v
			break
	return meta


func _current_project_dir() -> String:
	return ProjectSettings.globalize_path("res://").rstrip("/")


func _collect_projects() -> Dictionary:
	var current := _current_project_dir()
	var entries: Array = []
	var seen: Array = []
	# Synthetic first entry: the running project.
	var cur_meta := _project_meta(current)
	cur_meta["current"] = true
	entries.append(cur_meta)
	seen.append(current)
	for p in _projects_load_list():
		if p in seen:
			continue
		var m := _project_meta(p)
		m["current"] = false
		entries.append(m)
		seen.append(p)
	return {"current": current, "entries": entries}


func _projects_add(p_path: String) -> Dictionary:
	var abs := p_path.strip_edges()
	if abs == "":
		return {"ok": false, "error": "empty_path"}
	# Reject relative paths — caller must pass an absolute filesystem path.
	if not abs.is_absolute_path():
		return {"ok": false, "error": "not_absolute"}
	abs = abs.rstrip("/")
	if not FileAccess.file_exists(abs.path_join("project.godot")):
		return {"ok": false, "error": "no_project_godot", "path": abs}
	var list := _projects_load_list()
	if abs in list:
		return {"ok": true, "added": false, "path": abs}
	list.append(abs)
	if not _projects_save_list(list):
		return {"ok": false, "error": "save_failed"}
	return {"ok": true, "added": true, "path": abs}


func _projects_remove(p_path: String) -> Dictionary:
	var abs := p_path.strip_edges().rstrip("/")
	if abs == "":
		return {"ok": false, "error": "empty_path"}
	var list := _projects_load_list()
	if not (abs in list):
		return {"ok": false, "error": "not_in_list", "path": abs}
	list.erase(abs)
	if not _projects_save_list(list):
		return {"ok": false, "error": "save_failed"}
	return {"ok": true, "path": abs}


func _projects_open(p_path: String) -> Dictionary:
	var abs := p_path.strip_edges().rstrip("/")
	if abs == "":
		return {"ok": false, "error": "empty_path"}
	if not abs.is_absolute_path():
		return {"ok": false, "error": "not_absolute"}
	var godot_file := abs.path_join("project.godot")
	if not FileAccess.file_exists(godot_file):
		return {"ok": false, "error": "no_project_godot", "path": abs}
	# Re-use whatever Godot binary launched the current editor.  This is
	# how we keep the AGCK plugin and other VG addons sharing the same
	# editor build across projects.
	var godot_bin := OS.get_executable_path()
	var pid := OS.create_process(godot_bin, ["-e", "--path", abs])
	if pid <= 0:
		return {"ok": false, "error": "spawn_failed", "godot": godot_bin}
	return {"ok": true, "pid": pid, "path": abs, "godot": godot_bin}


# ── CSRF helpers ──────────────────────────────────────────────────────────
func _generate_csrf_token() -> String:
	# 192 bits of entropy from RandomNumberGenerator — sufficient for
	# loopback-only CSRF use.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(24)
	for i in range(24):
		bytes[i] = rng.randi() & 0xFF
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


func _csrf_cookie_headers() -> Array:
	# Returns extra raw header lines to attach to the response.
	return [
		"Set-Cookie: vg_csrf=%s; Path=/; SameSite=Strict" % _csrf_token,
	]


# ── Payload generators ────────────────────────────────────────────────────
func _collect_info() -> Dictionary:
	var info := {}
	info["dashboard_version"] = 5
	info["uptime_msec"] = Time.get_ticks_msec() - _started_at_msec
	info["bind"] = _bind
	info["port"] = _port
	# Godot/engine version.
	info["godot_version"] = Engine.get_version_info()
	# Project info from ProjectSettings.
	info["project_name"] = ProjectSettings.get_setting("application/config/name", "")
	info["project_description"] = ProjectSettings.get_setting("application/config/description", "")
	# VG version — read from the canonical VERSION file if reachable.
	info["vg_version"] = _read_vg_version()
	return info


func _read_vg_version() -> String:
	var paths := ["res://VERSION", "res://addons/visual_gasic/VERSION"]
	for p in paths:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null:
				var s := f.get_as_text().strip_edges()
				return s
	return ""


func _dashboard_html() -> String:
	# Inlined static page — no external assets so there's no second request
	# to authorise.  Three tabs: Info (auto-refresh), Settings (POST form),
	# Build (POST trigger + status polling).
	return """<!doctype html>
<html lang=\"en\"><head>
<meta charset=\"utf-8\">
<title>VisualGasic Dashboard</title>
<style>
:root { color-scheme: dark; }
body { font-family: -apple-system, Segoe UI, Roboto, sans-serif;
       background: #1a1f2b; color: #e0e6f0; margin: 0; padding: 2em; }
h1 { margin: 0 0 .2em 0; color: #6fb3ff; }
.sub { color: #8fa0b8; margin-bottom: 1.5em; }
.tabs { display: flex; gap: .4em; margin-bottom: 1em; border-bottom: 1px solid #2a3142; }
.tab { padding: .5em 1.2em; cursor: pointer; border-radius: 4px 4px 0 0;
       color: #8fa0b8; background: transparent; border: 0; font: inherit; }
.tab.active { background: #2c3447; color: #6fb3ff; }
.panel { display: none; }
.panel.active { display: block; }
table { border-collapse: collapse; min-width: 320px; }
th, td { text-align: left; padding: .35em .8em; border-bottom: 1px solid #2a3142; }
th { color: #8fa0b8; font-weight: 500; }
td.val { color: #ffe7a3; font-family: ui-monospace, Menlo, Consolas, monospace; }
.dot { display: inline-block; width: .6em; height: .6em; border-radius: 50%;
       background: #6cd07a; margin-right: .4em; vertical-align: middle; }
.foot { margin-top: 2em; color: #5a6478; font-size: .85em; }
button, select, input { background: #2c3447; color: #e0e6f0; border: 1px solid #3a4258;
         padding: .4em .9em; border-radius: 4px; cursor: pointer; font: inherit; }
button:hover { background: #3a4258; }
button:disabled { opacity: .5; cursor: not-allowed; }
label { display: block; margin: .8em 0 .2em; color: #8fa0b8; }
pre { background: #0e1219; border: 1px solid #2a3142; padding: .8em;
      border-radius: 4px; max-height: 360px; overflow: auto;
      font-family: ui-monospace, Menlo, Consolas, monospace; white-space: pre-wrap; }
.row { display: flex; gap: .6em; align-items: center; margin: .4em 0; }
.bad { color: #ff6b6b; } .good { color: #6cd07a; }
</style></head><body>
<h1><span class=\"dot\"></span>VisualGasic Dashboard</h1>
<div class=\"sub\">Phase 5 — multi-project switcher added.  CSRF-protected POST endpoints.</div>

<div class=\"tabs\">
  <button class=\"tab active\" data-panel=\"info\">Info</button>
  <button class=\"tab\" data-panel=\"settings\">Settings</button>
  <button class=\"tab\" data-panel=\"build\">Build</button>
  <button class=\"tab\" data-panel=\"files\">Files</button>
  <button class=\"tab\" data-panel=\"projects\">Projects</button>
</div>

<section id=\"panel-info\" class=\"panel active\">
  <table id=\"info\"></table>
  <p><button onclick=\"refreshInfo()\">Refresh now</button></p>
</section>

<section id=\"panel-settings\" class=\"panel\">
  <label>Auto-refresh interval (seconds)
    <input type=\"number\" id=\"f-refresh\" min=\"1\" max=\"60\" value=\"2\">
  </label>
  <label>Show build panel
    <input type=\"checkbox\" id=\"f-build\" checked>
  </label>
  <label>Theme
    <select id=\"f-theme\"><option value=\"dark\">dark</option><option value=\"light\">light</option></select>
  </label>
  <p><button onclick=\"saveSettings()\">Save settings</button>
     <span id=\"settings-status\" class=\"sub\"></span></p>
</section>

<section id=\"panel-build\" class=\"panel\">
  <div class=\"row\">
    <label style=\"margin:0\">Target&nbsp;</label>
    <select id=\"b-target\"></select>
    <button id=\"b-run\" onclick=\"runBuild()\">Run</button>
    <button id=\"b-cancel\" onclick=\"cancelBuild()\" disabled>Cancel</button>
    <span id=\"build-status\" class=\"sub\"></span>
  </div>
  <pre id=\"build-output\">(no build yet)</pre>
</section>

<section id=\"panel-files\" class=\"panel\">
  <div class=\"row\">
    <button onclick=\"filesGo('')\" title=\"Project root\">res://</button>
    <span id=\"files-crumbs\" class=\"sub\"></span>
  </div>
  <div style=\"display:flex; gap:1em; align-items:flex-start;\">
    <div style=\"flex:0 0 280px; max-height:480px; overflow:auto;
                background:#0e1219; border:1px solid #2a3142; border-radius:4px;\">
      <ul id=\"files-list\" style=\"list-style:none; margin:0; padding:.4em;\"></ul>
    </div>
    <div style=\"flex:1; min-width:0;\">
      <div id=\"files-meta\" class=\"sub\">Select a file to view.</div>
      <pre id=\"files-view\" style=\"max-height:480px;\"></pre>
    </div>
  </div>
</section>

<section id=\"panel-projects\" class=\"panel\">
  <div class=\"row\">
    <input id=\"p-add-path\" type=\"text\" placeholder=\"/absolute/path/to/project_dir\" style=\"flex:1; min-width:24em;\">
    <button onclick=\"addProject()\">Add</button>
    <button onclick=\"loadProjects()\">Refresh</button>
    <span id=\"projects-status\" class=\"sub\"></span>
  </div>
  <table id=\"projects-table\" style=\"margin-top:1em; width:100%;\"></table>
</section>

<div class=\"foot\">Served by VGDashboardServer · loopback only · CSRF token rotates per server start.</div>

<script>
var CSRF = '';
var REFRESH_TIMER = null;

function row(k, v) {
  return '<tr><th>' + k + '</th><td class=\"val\">' +
         (v === null || v === undefined || v === '' ? '—' :
          (typeof v === 'object' ? JSON.stringify(v) : String(v))) +
         '</td></tr>';
}
function fmtUptime(ms) {
  var s = Math.floor(ms/1000), m = Math.floor(s/60), h = Math.floor(m/60);
  return h + 'h ' + (m%60) + 'm ' + (s%60) + 's';
}
async function refreshInfo() {
  try {
    var r = await fetch('/api/info', { cache: 'no-store' });
    var d = await r.json();
    var gv = d.godot_version || {};
    document.getElementById('info').innerHTML =
      row('Project',     d.project_name) +
      row('Description', d.project_description) +
      row('VG version',  d.vg_version) +
      row('Godot',       gv.string || (gv.major + '.' + gv.minor)) +
      row('Bind',        d.bind + ':' + d.port) +
      row('Uptime',      fmtUptime(d.uptime_msec)) +
      row('Dashboard',   'v' + d.dashboard_version);
  } catch (e) {
    document.getElementById('info').innerHTML = row('Error', e.message);
  }
}
async function loadCsrf() {
  var r = await fetch('/api/csrf-token', { cache: 'no-store' });
  var d = await r.json();
  CSRF = d.csrf_token;
}
async function loadSettings() {
  var r = await fetch('/api/settings', { cache: 'no-store' });
  var d = await r.json();
  document.getElementById('f-refresh').value = d.auto_refresh_secs;
  document.getElementById('f-build').checked = !!d.show_build_panel;
  document.getElementById('f-theme').value = d.theme || 'dark';
  scheduleRefresh(d.auto_refresh_secs);
}
async function saveSettings() {
  var body = {
    auto_refresh_secs: parseInt(document.getElementById('f-refresh').value, 10) || 2,
    show_build_panel:  document.getElementById('f-build').checked,
    theme:             document.getElementById('f-theme').value,
  };
  var s = document.getElementById('settings-status');
  s.textContent = 'Saving…';
  try {
    var r = await fetch('/api/settings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': CSRF },
      body: JSON.stringify(body),
    });
    var d = await r.json();
    if (r.ok && d.ok) {
      s.textContent = 'Saved.';
      s.className = 'good';
      scheduleRefresh(d.settings.auto_refresh_secs);
    } else {
      s.textContent = 'Error: ' + (d.error || r.status);
      s.className = 'bad';
    }
  } catch (e) {
    s.textContent = 'Network error: ' + e.message;
    s.className = 'bad';
  }
}
async function loadBuildTargets() {
  var r = await fetch('/api/build/targets', { cache: 'no-store' });
  var d = await r.json();
  var sel = document.getElementById('b-target');
  sel.innerHTML = '';
  Object.keys(d).forEach(function(k){
    var o = document.createElement('option');
    o.value = k; o.textContent = d[k];
    sel.appendChild(o);
  });
}
async function runBuild() {
  var btn = document.getElementById('b-run');
  var cancelBtn = document.getElementById('b-cancel');
  var status = document.getElementById('build-status');
  var out = document.getElementById('build-output');
  var target = document.getElementById('b-target').value;
  btn.disabled = true;
  cancelBtn.disabled = false;
  status.textContent = 'Starting ' + target + '…';
  status.className = 'sub';
  out.textContent = '';
  try {
    var r = await fetch('/api/build/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': CSRF },
      body: JSON.stringify({ target: target }),
    });
    var d = await r.json();
    if (!r.ok || !d.ok) {
      status.textContent = 'Error: ' + (d.error || r.status);
      status.className = 'bad';
      out.textContent = JSON.stringify(d, null, 2);
      btn.disabled = false;
      cancelBtn.disabled = true;
      return;
    }
    status.textContent = 'Running ' + target + ' (pid ' + d.pid + ')…';
    // Stream the log into the <pre> by re-querying /api/build/log?offset=N
    // until X-Build-Running flips to 0.  ~600ms polling keeps the UI
    // responsive without flooding the server.
    var offset = 0;
    while (true) {
      var lr = await fetch('/api/build/log?offset=' + offset, { cache: 'no-store' });
      var chunk = await lr.text();
      if (chunk) { out.textContent += chunk; out.scrollTop = out.scrollHeight; }
      offset = parseInt(lr.headers.get('X-Build-Log-Bytes') || offset, 10);
      var running = lr.headers.get('X-Build-Running') === '1';
      if (!running) {
        var exit = parseInt(lr.headers.get('X-Build-Exit-Code') || '-1', 10);
        var ok = exit === 0;
        status.textContent = ok ? ('Exit 0 (OK)') : ('Exit ' + exit);
        status.className = ok ? 'good' : 'bad';
        break;
      }
      await new Promise(function(res){ setTimeout(res, 600); });
    }
  } catch (e) {
    status.textContent = 'Network error: ' + e.message;
    status.className = 'bad';
  }
  btn.disabled = false;
  cancelBtn.disabled = true;
}
async function cancelBuild() {
  try {
    var r = await fetch('/api/build/cancel', {
      method: 'POST',
      headers: { 'X-CSRF-Token': CSRF },
    });
    var d = await r.json();
    if (!d.ok) {
      var s = document.getElementById('build-status');
      s.textContent = 'Cancel failed: ' + (d.error || r.status);
      s.className = 'bad';
    }
  } catch (e) { /* runBuild's loop will surface the exit code */ }
}
function scheduleRefresh(secs) {
  if (REFRESH_TIMER) clearInterval(REFRESH_TIMER);
  if (secs > 0) REFRESH_TIMER = setInterval(refreshInfo, secs * 1000);
}
function switchTab(name) {
  document.querySelectorAll('.tab').forEach(function(t){
    t.classList.toggle('active', t.dataset.panel === name);
  });
  document.querySelectorAll('.panel').forEach(function(p){
    p.classList.toggle('active', p.id === 'panel-' + name);
  });
  if (name === 'files' && FILES_CWD === null) { filesGo(''); }
  if (name === 'projects') { loadProjects(); }
}

// ── Files tab ─────────────────────────────────────────────────────────────
var FILES_CWD = null;  // Relative path under res://, '' = root.
function escapeHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
                  .replace(/>/g, '&gt;').replace(/\"/g, '&quot;');
}
async function filesGo(rel) {
  FILES_CWD = rel;
  var meta = document.getElementById('files-meta');
  var view = document.getElementById('files-view');
  var crumbs = document.getElementById('files-crumbs');
  var list = document.getElementById('files-list');
  // Breadcrumb trail.
  if (rel === '') {
    crumbs.textContent = '';
  } else {
    var parts = rel.split('/');
    var acc = '';
    var html = '';
    for (var i = 0; i < parts.length; i++) {
      acc = acc ? (acc + '/' + parts[i]) : parts[i];
      html += ' / <a href=\"#\" data-rel=\"' + escapeHtml(acc) + '\">' +
              escapeHtml(parts[i]) + '</a>';
    }
    crumbs.innerHTML = html;
    crumbs.querySelectorAll('a').forEach(function(a){
      a.addEventListener('click', function(e){
        e.preventDefault(); filesGo(a.dataset.rel);
      });
    });
  }
  list.innerHTML = '<li class=\"sub\">Loading…</li>';
  view.textContent = '';
  meta.textContent = 'Select a file to view.';
  try {
    var r = await fetch('/api/files/list?path=' + encodeURIComponent(rel), { cache: 'no-store' });
    var d = await r.json();
    if (!r.ok) {
      list.innerHTML = '<li class=\"bad\">' + escapeHtml(d.error || r.status) + '</li>';
      return;
    }
    list.innerHTML = '';
    if (rel !== '') {
      var up = rel.indexOf('/') >= 0 ? rel.substring(0, rel.lastIndexOf('/')) : '';
      var li = document.createElement('li');
      li.innerHTML = '<a href=\"#\" data-kind=\"up\">⬆ ..</a>';
      li.querySelector('a').addEventListener('click', function(e){
        e.preventDefault(); filesGo(up);
      });
      list.appendChild(li);
    }
    d.entries.forEach(function(ent){
      var li = document.createElement('li');
      li.style.padding = '.15em .25em';
      var icon = ent.is_dir ? '📁' : '📄';
      var sz = ent.is_dir ? '' : ('  <span class=\"sub\">(' + ent.size + ')</span>');
      li.innerHTML = icon + ' <a href=\"#\">' + escapeHtml(ent.name) + '</a>' + sz;
      li.querySelector('a').addEventListener('click', function(e){
        e.preventDefault();
        var child = rel ? (rel + '/' + ent.name) : ent.name;
        if (ent.is_dir) filesGo(child); else filesView(child);
      });
      list.appendChild(li);
    });
  } catch (e) {
    list.innerHTML = '<li class=\"bad\">' + escapeHtml(e.message) + '</li>';
  }
}
async function filesView(rel) {
  var meta = document.getElementById('files-meta');
  var view = document.getElementById('files-view');
  meta.textContent = 'Loading ' + rel + '…';
  view.textContent = '';
  try {
    var r = await fetch('/api/files/read?path=' + encodeURIComponent(rel), { cache: 'no-store' });
    var d = await r.json();
    if (!r.ok) {
      meta.textContent = 'Error: ' + (d.error || r.status);
      meta.className = 'bad';
      return;
    }
    meta.className = 'sub';
    var info = d.path + ' · ' + d.size + ' bytes · .' + d.ext;
    if (d.truncated) info += ' · (truncated to 1 MiB)';
    meta.textContent = info;
    if (d.binary) {
      view.textContent = '(' + d.message + ')';
    } else {
      view.textContent = d.content;
    }
  } catch (e) {
    meta.textContent = 'Network error: ' + e.message;
    meta.className = 'bad';
  }
}

// ── Projects tab ──────────────────────────────────────────────────────────
async function loadProjects() {
  var tbl = document.getElementById('projects-table');
  var status = document.getElementById('projects-status');
  status.textContent = '';
  status.className = 'sub';
  tbl.innerHTML = '<tr><th>Loading…</th></tr>';
  try {
    var r = await fetch('/api/projects/list', { cache: 'no-store' });
    var d = await r.json();
    if (!r.ok) {
      tbl.innerHTML = '<tr><td class=\"bad\">' + escapeHtml(d.error || r.status) + '</td></tr>';
      return;
    }
    var rows = '<tr><th>Name</th><th>Path</th><th>State</th><th></th></tr>';
    d.entries.forEach(function(p){
      var state = p.current ? '<span class=\"good\">current</span>'
                : (p.exists ? 'available' : '<span class=\"bad\">missing</span>');
      var actions = '';
      if (!p.current && p.exists) {
        actions += '<button data-act=\"open\" data-path=\"' + escapeHtml(p.path) + '\">Open</button> ';
      }
      if (!p.current) {
        actions += '<button data-act=\"remove\" data-path=\"' + escapeHtml(p.path) + '\">Remove</button>';
      }
      rows += '<tr><td class=\"val\">' + escapeHtml(p.name) + '</td>' +
              '<td class=\"val\">' + escapeHtml(p.path) + '</td>' +
              '<td>' + state + '</td>' +
              '<td>' + actions + '</td></tr>';
    });
    tbl.innerHTML = rows;
    tbl.querySelectorAll('button[data-act]').forEach(function(b){
      b.addEventListener('click', function(){
        if (b.dataset.act === 'open') openProject(b.dataset.path);
        else removeProject(b.dataset.path);
      });
    });
  } catch (e) {
    tbl.innerHTML = '<tr><td class=\"bad\">' + escapeHtml(e.message) + '</td></tr>';
  }
}
async function _projectsPost(url, body, label) {
  var status = document.getElementById('projects-status');
  status.textContent = label + '…';
  status.className = 'sub';
  try {
    var r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': CSRF },
      body: JSON.stringify(body),
    });
    var d = await r.json();
    if (!r.ok || !d.ok) {
      status.textContent = 'Error: ' + (d.error || r.status);
      status.className = 'bad';
      return null;
    }
    status.textContent = label + ' OK.';
    status.className = 'good';
    return d;
  } catch (e) {
    status.textContent = 'Network error: ' + e.message;
    status.className = 'bad';
    return null;
  }
}
async function addProject() {
  var inp = document.getElementById('p-add-path');
  var path = inp.value.trim();
  if (!path) return;
  var d = await _projectsPost('/api/projects/add', { path: path }, 'Adding');
  if (d) { inp.value = ''; loadProjects(); }
}
async function removeProject(path) {
  var d = await _projectsPost('/api/projects/remove', { path: path }, 'Removing');
  if (d) loadProjects();
}
async function openProject(path) {
  var d = await _projectsPost('/api/projects/open', { path: path }, 'Opening');
  // Successful open just keeps the row — the new editor spawns its own
  // dashboard on the next free port.
}

document.querySelectorAll('.tab').forEach(function(t){
  t.addEventListener('click', function(){ switchTab(t.dataset.panel); });
});
(async function init() {
  await loadCsrf();
  await Promise.all([refreshInfo(), loadSettings(), loadBuildTargets()]);
})();
</script>
</body></html>
"""


# ── HTTP response writer ──────────────────────────────────────────────────
func _send_response(peer: StreamPeerTCP, code: int, content_type: String, body: PackedByteArray, extra_headers: Array = []) -> void:
	var status_text := _status_text(code)
	var head := "HTTP/1.1 %d %s\r\n" % [code, status_text]
	head += "Content-Type: %s\r\n" % content_type
	head += "Content-Length: %d\r\n" % body.size()
	head += "Connection: close\r\n"
	head += "Cache-Control: no-store\r\n"
	head += "X-Content-Type-Options: nosniff\r\n"
	for h in extra_headers:
		head += String(h) + "\r\n"
	head += "\r\n"
	var head_bytes := head.to_utf8_buffer()
	peer.put_data(head_bytes)
	if body.size() > 0:
		peer.put_data(body)


func _status_text(code: int) -> String:
	match code:
		200: return "OK"
		204: return "No Content"
		400: return "Bad Request"
		403: return "Forbidden"
		404: return "Not Found"
		405: return "Method Not Allowed"
		409: return "Conflict"
		413: return "Payload Too Large"
		_:   return "OK"


func _exit_tree() -> void:
	stop_server()
