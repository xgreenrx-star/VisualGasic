@tool
extends Node
class_name VGDashboardServer

# ── VG Browser Dashboard — minimal embedded HTTP server ────────────────────
# Phase-1 foundation for the long-deferred Browser Dashboard (was a v5.0.1
# blocker, now landed in v5.2).  Binds 127.0.0.1:8765 by default, serves a
# single static HTML page plus a JSON info endpoint.  Subsequent phases
# will add a build monitor, settings panel, and project explorer.
#
# Why TCPServer (not godot-cpp HTTPServer)?  Godot has no first-party HTTP
# server class — only client.  We hand-parse a tiny request-line subset
# (METHOD PATH HTTP/1.x + headers) which is all the dashboard fetches need.
#
# Security:
#   - Default bind is 127.0.0.1 (loopback only).  External bind requires
#     explicit `bind_address` param — caller's responsibility.
#   - No write endpoints in Phase 1.  All routes are GET-only.
#   - No path-based file serving — pages are inlined to prevent traversal.

const DEFAULT_PORT := 8765
const DEFAULT_BIND := "127.0.0.1"
const MAX_REQUEST_BYTES := 16384  # Hard cap — refuse anything larger.
const POLL_INTERVAL_SEC := 0.05

var _server: TCPServer
var _connections: Array = []  # Array of {peer, buf, started_at_msec}
var _port: int = DEFAULT_PORT
var _bind: String = DEFAULT_BIND
var _started_at_msec: int = 0
var _timer: Timer = null


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
		# Parse and handle.
		var head := c["buf"].slice(0, sep).get_string_from_utf8()
		_handle_request(peer, head)
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


func _handle_request(peer: StreamPeerTCP, head: String) -> void:
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
	if method != "GET":
		_send_response(peer, 405, "text/plain", "Only GET is supported".to_utf8_buffer())
		return
	# Strip query string for routing — keep raw for ?refresh=1 etc later.
	var qs_idx := raw_path.find("?")
	var path := raw_path if qs_idx < 0 else raw_path.substr(0, qs_idx)
	_route(peer, path)


func _route(peer: StreamPeerTCP, path: String) -> void:
	match path:
		"/", "/index.html":
			_send_response(peer, 200, "text/html; charset=utf-8",
				_dashboard_html().to_utf8_buffer())
		"/api/info":
			_send_response(peer, 200, "application/json",
				JSON.stringify(_collect_info(), "  ").to_utf8_buffer())
		"/favicon.ico":
			# Empty 204 to silence browser noise.
			_send_response(peer, 204, "text/plain", PackedByteArray())
		_:
			_send_response(peer, 404, "text/plain",
				("Not found: " + path).to_utf8_buffer())


# ── Payload generators ────────────────────────────────────────────────────
func _collect_info() -> Dictionary:
	var info := {}
	info["dashboard_version"] = 1
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
	# to authorise.  The JS polls /api/info every 2s and renders into the
	# table.  Keep simple — Phase 1 only.
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
table { border-collapse: collapse; min-width: 320px; }
th, td { text-align: left; padding: .35em .8em; border-bottom: 1px solid #2a3142; }
th { color: #8fa0b8; font-weight: 500; }
td.val { color: #ffe7a3; font-family: ui-monospace, Menlo, Consolas, monospace; }
.dot { display: inline-block; width: .6em; height: .6em; border-radius: 50%;
       background: #6cd07a; margin-right: .4em; vertical-align: middle; }
.foot { margin-top: 2em; color: #5a6478; font-size: .85em; }
button { background: #2c3447; color: #e0e6f0; border: 1px solid #3a4258;
         padding: .4em .9em; border-radius: 4px; cursor: pointer; }
button:hover { background: #3a4258; }
</style></head><body>
<h1><span class=\"dot\"></span>VisualGasic Dashboard</h1>
<div class=\"sub\">Phase 1 — project info &amp; uptime.  Auto-refreshes every 2s.</div>
<table id=\"info\"></table>
<p><button onclick=\"refresh()\">Refresh now</button></p>
<div class=\"foot\">Served by VGDashboardServer · loopback only · GET-only API.</div>
<script>
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
async function refresh() {
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
      row('Uptime',      fmtUptime(d.uptime_msec));
  } catch (e) {
    document.getElementById('info').innerHTML = row('Error', e.message);
  }
}
refresh();
setInterval(refresh, 2000);
</script>
</body></html>
"""


# ── HTTP response writer ──────────────────────────────────────────────────
func _send_response(peer: StreamPeerTCP, code: int, content_type: String, body: PackedByteArray) -> void:
	var status_text := _status_text(code)
	var head := "HTTP/1.1 %d %s\r\n" % [code, status_text]
	head += "Content-Type: %s\r\n" % content_type
	head += "Content-Length: %d\r\n" % body.size()
	head += "Connection: close\r\n"
	head += "Cache-Control: no-store\r\n"
	head += "X-Content-Type-Options: nosniff\r\n"
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
		404: return "Not Found"
		405: return "Method Not Allowed"
		413: return "Payload Too Large"
		_:   return "OK"


func _exit_tree() -> void:
	stop_server()
