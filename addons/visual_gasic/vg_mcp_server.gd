@tool
extends Node
class_name VGMcpServer

## MCP (Model Context Protocol) server for VisualGasic — item 5.
##
## Speaks JSON-RPC 2.0 over HTTP on 127.0.0.1:8766 (loopback only).
## Exposes VG's file/editor tools so external AI clients (Claude Desktop,
## Continue.dev, custom LLM toolchains) can call them directly.
##
## Implemented MCP methods:
##   initialize          → server info + capabilities
##   tools/list          → all available VG tools with JSON Schema
##   tools/call          → invoke a named tool by name + arguments dict
##   ping                → health check
##
## Available tools:
##   read_file           {"path": "res://…", "max_lines": 200}
##   write_file          {"path": "res://…", "contents": "…"}
##   list_dir            {"path": "res://…"}
##   find_in_files       {"query": "…", "path": "res://…"}
##   apply_diff         {"path": "res://…", "diff": "unified diff string"}
##
## Security:
##   - Loopback-only by default (127.0.0.1).
##   - read_file / list_dir / find_in_files are read-only.
##   - write_file is restricted to res:// paths and must pass the path
##     safety check (no traversal outside project root).
##   - OS commands are never accepted from the client.

const DEFAULT_PORT := 8766
const DEFAULT_BIND := "127.0.0.1"
const MAX_REQUEST_BYTES := 131072  # 128 KiB
const POLL_INTERVAL_SEC := 0.05
const MCP_VERSION := "2024-11-05"
const SERVER_NAME := "vg-mcp"
const SERVER_VERSION := "1.0.0"

var _server: TCPServer = null
var _connections: Array = []   # [{peer, buf, started_at_msec}]
var _port: int = DEFAULT_PORT
var _bind: String = DEFAULT_BIND
var _timer: Timer = null
var _started: bool = false

# Optional reference to a VGAiTools instance for richer tool execution.
# Set externally by the panel after creation if desired.
var ai_tools = null

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL_SEC
	_timer.one_shot = false
	_timer.timeout.connect(_poll)
	add_child(_timer)

func _exit_tree() -> void:
	stop_server()

# ─── Public API ──────────────────────────────────────────────────────────────

func start_server(p_port: int = DEFAULT_PORT, p_bind: String = DEFAULT_BIND) -> bool:
	if _started:
		return true
	_port = p_port
	_bind = p_bind
	_server = TCPServer.new()
	var err := _server.listen(_port, _bind)
	if err != OK:
		push_warning("VGMcpServer: could not bind %s:%d — %s" % [_bind, _port, error_string(err)])
		_server = null
		return false
	_started = true
	_timer.start()
	print("VGMcpServer: listening on %s:%d" % [_bind, _port])
	return true

func stop_server() -> void:
	if not _started:
		return
	_timer.stop()
	for c in _connections:
		if c["peer"] and c["peer"].get_status() != StreamPeerTCP.STATUS_NONE:
			c["peer"].disconnect_from_host()
	_connections.clear()
	if _server:
		_server.stop()
		_server = null
	_started = false

func is_running() -> bool:
	return _started

# ─── Poll ────────────────────────────────────────────────────────────────────

func _poll() -> void:
	if _server == null:
		return
	# Accept new connections.
	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		if peer:
			_connections.append({
				"peer": peer,
				"buf": PackedByteArray(),
				"started_at_msec": Time.get_ticks_msec(),
			})

	# Service existing connections.
	var stale: Array = []
	for c in _connections:
		var peer: StreamPeerTCP = c["peer"]
		if peer.get_status() == StreamPeerTCP.STATUS_NONE or \
		   peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			stale.append(c)
			continue
		var avail := peer.get_available_bytes()
		if avail > 0:
			var chunk := peer.get_data(avail)
			if chunk[0] == OK:
				c["buf"].append_array(chunk[1])
		# Timeout guard (10 s).
		if Time.get_ticks_msec() - c["started_at_msec"] > 10000:
			stale.append(c)
			continue
		# Try to parse a complete HTTP request.
		var result := _try_parse_request(c["buf"])
		if not result.is_empty() and not result.get("_incomplete", false):
			_handle_http_request(peer, result)
			stale.append(c)  # HTTP/1.0 — one request per connection

	for c in stale:
		var peer: StreamPeerTCP = c["peer"]
		if peer.get_status() != StreamPeerTCP.STATUS_NONE:
			peer.disconnect_from_host()
		_connections.erase(c)

# ─── HTTP parsing ─────────────────────────────────────────────────────────────

func _try_parse_request(buf: PackedByteArray) -> Dictionary:
	if buf.size() > MAX_REQUEST_BYTES:
		return {}  # Reject oversized requests.
	var raw := buf.get_string_from_utf8()
	var header_end := raw.find("\r\n\r\n")
	if header_end == -1:
		return {"_incomplete": true}  # Not complete yet.
	var header_section := raw.substr(0, header_end)
	var lines := header_section.split("\r\n")
	if lines.is_empty():
		return {}
	var request_line := lines[0]
	var parts := request_line.split(" ")
	if parts.size() < 3:
		return {}
	var method := parts[0]
	var path := parts[1]
	var headers: Dictionary = {}
	for i in range(1, lines.size()):
		var colon := lines[i].find(":")
		if colon != -1:
			var key := lines[i].substr(0, colon).strip_edges().to_lower()
			var val := lines[i].substr(colon + 1).strip_edges()
			headers[key] = val
	var content_length: int = int(headers.get("content-length", "0"))
	var body_start := header_end + 4
	if buf.size() < body_start + content_length:
		return {"_incomplete": true}  # Body not fully received yet.
	var body_bytes := buf.slice(body_start, body_start + content_length)
	return {
		"method": method,
		"path": path,
		"headers": headers,
		"body": body_bytes.get_string_from_utf8(),
	}

# ─── HTTP dispatch ────────────────────────────────────────────────────────────

func _handle_http_request(peer: StreamPeerTCP, req: Dictionary) -> void:
	var method: String = req.get("method", "")
	var path: String = req.get("path", "")
	var body: String = req.get("body", "")

	# Only POST to / is the MCP endpoint; provide a GET /health for liveness.
	if method == "GET" and path == "/health":
		_send_json(peer, 200, {"status": "ok", "server": SERVER_NAME, "version": SERVER_VERSION})
		return
	if method == "POST" and (path == "/" or path == "/mcp"):
		_handle_jsonrpc(peer, body)
		return
	# OPTIONS for CORS preflight (some MCP clients send this).
	if method == "OPTIONS":
		_send_raw(peer, 204, "", "")
		return
	_send_json(peer, 404, {"error": "Not found"})

# ─── JSON-RPC 2.0 ─────────────────────────────────────────────────────────────

func _handle_jsonrpc(peer: StreamPeerTCP, body: String) -> void:
	if body.strip_edges().is_empty():
		_send_jsonrpc_error(peer, null, -32700, "Parse error: empty body")
		return
	var parsed = JSON.parse_string(body)
	if not parsed is Dictionary:
		_send_jsonrpc_error(peer, null, -32700, "Parse error: not a JSON object")
		return
	var req: Dictionary = parsed
	var req_id = req.get("id", null)
	var rpc_method: String = str(req.get("method", ""))
	var params = req.get("params", {})
	if not params is Dictionary:
		params = {}
	match rpc_method:
		"initialize":
			_rpc_initialize(peer, req_id, params)
		"tools/list":
			_rpc_tools_list(peer, req_id)
		"tools/call":
			_rpc_tools_call(peer, req_id, params)
		"ping":
			_send_jsonrpc_result(peer, req_id, {})
		_:
			_send_jsonrpc_error(peer, req_id, -32601, "Method not found: " + rpc_method)

func _rpc_initialize(peer: StreamPeerTCP, req_id, _params: Dictionary) -> void:
	_send_jsonrpc_result(peer, req_id, {
		"protocolVersion": MCP_VERSION,
		"capabilities": {
			"tools": {"listChanged": false},
		},
		"serverInfo": {
			"name": SERVER_NAME,
			"version": SERVER_VERSION,
		},
	})

func _rpc_tools_list(peer: StreamPeerTCP, req_id) -> void:
	_send_jsonrpc_result(peer, req_id, {
		"tools": _tool_definitions(),
	})

func _rpc_tools_call(peer: StreamPeerTCP, req_id, params: Dictionary) -> void:
	var tool_name: String = str(params.get("name", ""))
	var arguments = params.get("arguments", {})
	if not arguments is Dictionary:
		arguments = {}
	var result := _invoke_tool(tool_name, arguments)
	if result.has("error"):
		_send_jsonrpc_error(peer, req_id, -32000, result["error"])
		return
	_send_jsonrpc_result(peer, req_id, {
		"content": [
			{"type": "text", "text": str(result.get("output", ""))},
		],
		"isError": false,
	})

# ─── Tool definitions (JSON Schema) ──────────────────────────────────────────

func _tool_definitions() -> Array:
	return [
		{
			"name": "read_file",
			"description": "Read the text content of a file in the current Godot project.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "res:// path (e.g. res://forms/Form1.vg)"},
					"max_lines": {"type": "integer", "description": "Maximum number of lines to return (default 200)"},
				},
				"required": ["path"],
			},
		},
		{
			"name": "write_file",
			"description": "Write text content to a file in the current Godot project (res:// paths only).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "res:// path"},
					"contents": {"type": "string", "description": "Full text content to write"},
				},
				"required": ["path", "contents"],
			},
		},
		{
			"name": "list_dir",
			"description": "List files and sub-directories under a res:// path.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "res:// directory path"},
				},
				"required": ["path"],
			},
		},
		{
			"name": "find_in_files",
			"description": "Search for a text query across .vg and .gd files under a directory.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"query": {"type": "string", "description": "Text to search for"},
					"path": {"type": "string", "description": "Root res:// path to search under (default res://)"},
				},
				"required": ["query"],
			},
		},
		{
			"name": "apply_diff",
			"description": "Apply a unified diff (--- / +++ / @@ hunks) to an existing res:// file. Lines beginning with '-' are removed and lines beginning with '+' are inserted at the matched position. Context lines (no prefix or ' ' prefix) are used to locate each hunk. Returns the number of hunks applied or an error if any hunk failed to match.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "res:// path of the file to patch"},
					"diff": {"type": "string", "description": "Unified diff string (as produced by `diff -u` or git diff). Must contain at least one @@ hunk."},
				},
				"required": ["path", "diff"],
			},
		},
		{
			"name": "run_benchmark",
			"description": "Run the AI correctness benchmark suite and return a summary of pass/fail counts.",
			"inputSchema": {
				"type": "object",
				"properties": {},
			},
		},
	]

# ─── Tool execution ───────────────────────────────────────────────────────────

func _invoke_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"read_file":
			return _tool_read_file(args)
		"write_file":
			return _tool_write_file(args)
		"list_dir":
			return _tool_list_dir(args)
		"find_in_files":
			return _tool_find_in_files(args)
		"apply_diff":
			return _tool_apply_diff(args)
		"run_benchmark":
			return _tool_run_benchmark()
		_:
			return {"error": "Unknown tool: " + tool_name}

func _tool_read_file(args: Dictionary) -> Dictionary:
	var path: String = str(args.get("path", ""))
	if not _is_safe_res_path(path):
		return {"error": "Unsafe or non-res:// path: " + path}
	var max_lines: int = int(args.get("max_lines", 200))
	if not FileAccess.file_exists(path):
		return {"error": "File not found: " + path}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "Cannot open: " + path}
	var lines: PackedStringArray = []
	var count := 0
	while not f.eof_reached() and count < max_lines:
		lines.append(f.get_line())
		count += 1
	var truncated := not f.eof_reached()
	f.close()
	var text := "\n".join(lines)
	if truncated:
		text += "\n[... truncated at %d lines ...]" % max_lines
	return {"output": text}

func _tool_write_file(args: Dictionary) -> Dictionary:
	var path: String = str(args.get("path", ""))
	if not _is_safe_res_path(path):
		return {"error": "Unsafe or non-res:// path: " + path}
	var contents: String = str(args.get("contents", ""))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"error": "Cannot write: " + path}
	f.store_string(contents)
	f.close()
	return {"output": "Written %d bytes to %s" % [contents.length(), path]}

func _tool_list_dir(args: Dictionary) -> Dictionary:
	var path: String = str(args.get("path", "res://"))
	if not _is_safe_res_path(path):
		return {"error": "Unsafe or non-res:// path: " + path}
	var dir := DirAccess.open(path)
	if dir == null:
		return {"error": "Cannot open directory: " + path}
	var entries: PackedStringArray = []
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			entries.append(name + "/")
		else:
			entries.append(name)
	dir.list_dir_end()
	entries.sort()
	return {"output": "\n".join(entries)}

func _tool_find_in_files(args: Dictionary) -> Dictionary:
	var query: String = str(args.get("query", ""))
	if query.is_empty():
		return {"error": "query must not be empty"}
	var root: String = str(args.get("path", "res://"))
	if not _is_safe_res_path(root):
		return {"error": "Unsafe or non-res:// path: " + root}
	var results: PackedStringArray = []
	_grep_dir(root, query, results, 0)
	if results.is_empty():
		return {"output": "(no matches found)"}
	return {"output": "\n".join(results)}

func _grep_dir(dir_path: String, query: String, out: PackedStringArray, depth: int) -> void:
	if depth > 8 or out.size() > 200:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_grep_dir(full, query, out, depth + 1)
		elif name.ends_with(".vg") or name.ends_with(".gd"):
			_grep_file(full, query, out)
	dir.list_dir_end()

func _grep_file(path: String, query: String, out: PackedStringArray) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var lnum := 0
	while not f.eof_reached():
		var line := f.get_line()
		lnum += 1
		if line.contains(query):
			out.append("%s:%d: %s" % [path, lnum, line.strip_edges()])
			if out.size() >= 200:
				break
	f.close()

func _tool_apply_diff(args: Dictionary) -> Dictionary:
	var path: String = str(args.get("path", ""))
	if not _is_safe_res_path(path):
		return {"error": "Unsafe or non-res:// path: " + path}
	var diff: String = str(args.get("diff", ""))
	if diff.strip_edges().is_empty():
		return {"error": "diff must not be empty"}
	if not FileAccess.file_exists(path):
		return {"error": "File not found: " + path}
	# Read original lines.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "Cannot open: " + path}
	var original_text := f.get_as_text()
	f.close()
	var lines: Array = Array(original_text.split("\n"))
	# Trim a single trailing empty element that split() adds for files ending with \n.
	if not lines.is_empty() and lines[-1] == "":
		lines.pop_back()
		var had_trailing_newline := true
	# Parse and apply hunks.
	var diff_lines: Array = Array(diff.split("\n"))
	var hunks_applied := 0
	var i := 0
	var n := diff_lines.size()
	while i < n:
		var dl: String = diff_lines[i]
		# Skip file headers (--- +++ index diff --git etc.)
		if dl.begins_with("---") or dl.begins_with("+++") or \
				dl.begins_with("diff ") or dl.begins_with("index ") or \
				dl.begins_with("new file") or dl.begins_with("old file") or \
				dl.begins_with("deleted file"):
			i += 1
			continue
		if not dl.begins_with("@@"):
			i += 1
			continue
		# Parse @@ -start[,count] +start[,count] @@ ...
		# We only need the original start line to anchor the search.
		var hunk_start := _parse_hunk_start(dl)
		i += 1
		# Collect hunk body.
		var context_before: Array = []
		var removes: Array = []
		var adds: Array = []
		var after_first_change := false
		while i < n:
			var hl: String = diff_lines[i]
			if hl.begins_with("@@") or hl.begins_with("---") or hl.begins_with("+++"):
				break
			if hl.begins_with("-"):
				removes.append(hl.substr(1))
				after_first_change = true
			elif hl.begins_with("+"):
				adds.append(hl.substr(1))
				after_first_change = true
			else:
				# Context line (" " prefix or no prefix).
				var ctx := hl.substr(1) if hl.begins_with(" ") else hl
				if not after_first_change:
					context_before.append(ctx)
			i += 1
		# Find the exact position in `lines` where the hunk matches.
		# Search near hunk_start first (0-indexed = hunk_start - 1), then expand.
		var anchor := _find_hunk_anchor(lines, context_before, removes, hunk_start)
		if anchor < 0:
			return {"error": "Hunk %d failed to match near line %d" % [hunks_applied + 1, hunk_start]}
		# Apply: remove then insert.
		var insert_pos := anchor + context_before.size()
		for _r in removes.size():
			lines.remove_at(insert_pos)
		var add_idx := adds.size() - 1
		while add_idx >= 0:
			lines.insert(insert_pos, adds[add_idx])
			add_idx -= 1
		hunks_applied += 1
	if hunks_applied == 0:
		return {"error": "No @@ hunks found in diff"}
	# Write back.
	var fw := FileAccess.open(path, FileAccess.WRITE)
	if fw == null:
		return {"error": "Cannot write: " + path}
	fw.store_string("\n".join(lines) + "\n")
	fw.close()
	return {"output": "Applied %d hunk(s) to %s" % [hunks_applied, path]}

## Parse the original-file start line from a unified diff @@ header.
## e.g. "@@ -12,7 +12,9 @@ func foo():" → 12 (1-based)
func _parse_hunk_start(header: String) -> int:
	# Format: @@ -<start>[,<count>] +<start>[,<count>] @@
	var rx := RegEx.new()
	rx.compile(r"@@ -(?P<start>\d+)")
	var m := rx.search(header)
	if m == null:
		return 1
	return int(m.get_string("start"))

## Find where context_before + removes begins in `lines`, starting near
## `hunk_start` (1-based).  Searches ±50 lines from the anchor.
func _find_hunk_anchor(lines: Array, context_before: Array, removes: Array, hunk_start: int) -> int:
	var pattern: Array = context_before + removes
	if pattern.is_empty():
		# No context or removes — insert at anchor position.
		return maxi(0, hunk_start - 1)
	var total := lines.size()
	var ideal := maxi(0, hunk_start - 1 - context_before.size())
	var search_range := 50
	for delta in range(0, search_range + 1):
		for sign in [0, 1, -1] if delta == 0 else [1, -1]:
			if delta == 0 and sign == -1:
				continue
			var candidate: int = ideal + delta * int(sign)
			if candidate < 0 or candidate + pattern.size() > total:
				continue
			var is_match := true
			for pi in pattern.size():
				if lines[candidate + pi] != pattern[pi]:
					is_match = false
					break
			if is_match:
				return candidate
	return -1

func _tool_run_benchmark() -> Dictionary:
	# Run the aggregate.py script from bench/ai_correctness and return stdout.
	var script_path := ProjectSettings.globalize_path("res://bench/ai_correctness/scripts/aggregate.py")
	if not FileAccess.file_exists(script_path):
		return {"error": "Benchmark script not found: " + script_path}
	var output: Array = []
	var exit := OS.execute("python3", [script_path], output, true)
	var text: String = ""
	for line in output:
		text += str(line)
	return {"output": "exit=%d\n%s" % [exit, text]}

# ─── Path safety ──────────────────────────────────────────────────────────────

func _is_safe_res_path(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	# Reject traversal attempts.
	if path.contains(".."):
		return false
	return true

# ─── HTTP response helpers ────────────────────────────────────────────────────

func _send_jsonrpc_result(peer: StreamPeerTCP, req_id, result) -> void:
	var obj := {"jsonrpc": "2.0", "id": req_id, "result": result}
	_send_json(peer, 200, obj)

func _send_jsonrpc_error(peer: StreamPeerTCP, req_id, code: int, message: String) -> void:
	var obj := {
		"jsonrpc": "2.0",
		"id": req_id,
		"error": {"code": code, "message": message},
	}
	_send_json(peer, 200, obj)  # JSON-RPC errors still use HTTP 200.

func _send_json(peer: StreamPeerTCP, status: int, body_obj) -> void:
	var json_str := JSON.stringify(body_obj)
	_send_raw(peer, status, json_str, "application/json")

func _send_raw(peer: StreamPeerTCP, status: int, body: String, content_type: String) -> void:
	var status_text := _status_text(status)
	var body_bytes := body.to_utf8_buffer()
	var ct_line := ("Content-Type: " + content_type + "\r\n") if not content_type.is_empty() else ""
	var response := ("HTTP/1.0 %d %s\r\n" % [status, status_text]) + \
		"Access-Control-Allow-Origin: *\r\n" + \
		"Cache-Control: no-store\r\n" + \
		"X-Content-Type-Options: nosniff\r\n" + \
		ct_line + \
		("Content-Length: %d\r\n" % body_bytes.size()) + \
		"Connection: close\r\n\r\n"
	peer.put_data(response.to_utf8_buffer())
	if not body.is_empty():
		peer.put_data(body_bytes)

func _status_text(code: int) -> String:
	match code:
		200: return "OK"
		204: return "No Content"
		400: return "Bad Request"
		404: return "Not Found"
		500: return "Internal Server Error"
		_:   return "Unknown"
