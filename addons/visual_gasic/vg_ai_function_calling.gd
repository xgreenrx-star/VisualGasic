@tool
extends RefCounted
## Phase 6c — Provider-native function-calling adapter.
##
## Converts VisualGasic's tool registry into the native function-calling
## wire format for OpenAI, Claude, and Gemini, and normalises native
## tool_calls / input_json_delta / functionCall responses back into the
## fenced vg-tool text that the existing dispatch path processes unchanged.
##
## Usage in vg_ai_help.gd:
##   1. Before send:  inject_tools_into_body(provider_id, body_dict)
##   2. While stream: parse_stream_line_for_fc(provider_id, line) → fragment
##   3. After stream: assemble_fc_calls(fragments) → [{name, args}]
##                    to_fenced_text(calls) → append to _accumulated_response

## Providers with a native function-calling protocol.
## Ollama uses the existing fenced-JSON system-prompt approach (no change).
const PROVIDERS_WITH_NATIVE_FC := ["openai", "claude", "gemini"]

static func supports_native_fc(provider_id: String) -> bool:
	return PROVIDERS_WITH_NATIVE_FC.has(provider_id)


# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------
# _get_tool_defs() returns the canonical list of VG tools with JSON-Schema
# parameter definitions.  Function-calling APIs forbid dots in names, so
# tools with dots are given a normalised FC name; the "_vg_name" key holds
# the original name for the round-trip conversion back to vg-tool fences.

static func _get_tool_defs() -> Array:
	return [
		{
			"name": "highlight_lines",
			"description": "Highlight specific lines in the code editor.",
			"properties": {
				"lines": {
					"type": "array",
					"items": {"type": "integer"},
					"description": "1-based line numbers to highlight",
				},
				"color": {
					"type": "string",
					"enum": ["yellow", "green", "red", "blue", "orange"],
					"description": "Highlight colour",
				},
				"duration_sec": {
					"type": "number",
					"description": "Seconds to display the highlight (default 8)",
				},
			},
			"required": ["lines", "color"],
		},
		{
			"name": "clear_highlights",
			"description": "Clear all editor line highlights.",
			"properties": {},
			"required": [],
		},
		{
			"name": "goto_line",
			"description": "Move the editor caret to a specific line.",
			"properties": {
				"line": {"type": "integer", "description": "1-based target line"},
				"column": {"type": "integer", "description": "0-based column (default 0)"},
			},
			"required": ["line"],
		},
		{
			"name": "open_file",
			"description": "Open a project file in the editor.",
			"properties": {
				"path": {"type": "string", "description": "File path (res://, user://)"},
			},
			"required": ["path"],
		},
		{
			"name": "read_file",
			"description": "Read and return the contents of a project file.",
			"properties": {
				"path": {"type": "string", "description": "File path (res://, user://)"},
				"max_lines": {
					"type": "integer",
					"description": "Maximum lines to return (default 200)",
				},
			},
			"required": ["path"],
		},
		{
			"name": "list_dir",
			"description": "List files and subdirectories at a path.",
			"properties": {
				"path": {
					"type": "string",
					"description": "Directory to list (default res://)",
				},
				"recursive": {
					"type": "boolean",
					"description": "List recursively (default false)",
				},
				"max_entries": {
					"type": "integer",
					"description": "Maximum entries to return (default 200)",
				},
			},
			"required": [],
		},
		{
			"name": "find_in_files",
			"description": "Search for a text pattern across project source files.",
			"properties": {
				"pattern": {"type": "string", "description": "Search text or regex pattern"},
				"path": {
					"type": "string",
					"description": "Root directory to search (default res://)",
				},
				"max_hits": {
					"type": "integer",
					"description": "Maximum results to return (default 50)",
				},
				"regex": {
					"type": "boolean",
					"description": "Treat pattern as a regular expression",
				},
			},
			"required": ["pattern"],
		},
		{
			"name": "insert_text",
			"description": "Insert text before a given line in the active editor buffer.",
			"properties": {
				"line": {
					"type": "integer",
					"description": "1-based line number to insert before",
				},
				"text": {
					"type": "string",
					"description": "Text to insert (include \\n as needed)",
				},
			},
			"required": ["line", "text"],
		},
		{
			"name": "replace_range",
			"description": "Replace a range of lines in the active editor buffer.",
			"properties": {
				"start_line": {
					"type": "integer",
					"description": "First line to replace (1-based, inclusive)",
				},
				"end_line": {
					"type": "integer",
					"description": "Last line to replace (1-based, inclusive)",
				},
				"text": {"type": "string", "description": "Replacement text"},
			},
			"required": ["start_line", "end_line", "text"],
		},
		{
			"name": "replace_in_buffer",
			"description": "Find-and-replace text in the active editor buffer.",
			"properties": {
				"find": {"type": "string", "description": "Text to find"},
				"replace": {"type": "string", "description": "Replacement text"},
				"all": {
					"type": "boolean",
					"description": "Replace all occurrences (default true)",
				},
			},
			"required": ["find", "replace"],
		},
		{
			"name": "set_buffer_text",
			"description": "Replace the entire active editor buffer with new text.",
			"properties": {
				"text": {"type": "string", "description": "New buffer content"},
			},
			"required": ["text"],
		},
		{
			"name": "save_file",
			"description": "Save the active editor buffer to disk.",
			"properties": {},
			"required": [],
		},
		{
			"name": "write_file",
			"description": "Write content to a file on disk (creates or overwrites).",
			"properties": {
				"path": {"type": "string", "description": "Target file path (res://, user://)"},
				"contents": {"type": "string", "description": "Content to write"},
			},
			"required": ["path", "contents"],
		},
		{
			"name": "play_run_main",
			"description": "Run the project's main scene in the Godot engine.",
			"properties": {},
			"required": [],
			"_vg_name": "play.run_main",  # Round-trip mapping back to VG tool name.
		},
		{
			"name": "play_stop",
			"description": "Stop the currently running scene.",
			"properties": {},
			"required": [],
			"_vg_name": "play.stop",
		},
	]


# ---------------------------------------------------------------------------
# Provider-specific schema builders
# ---------------------------------------------------------------------------

static func _to_openai_schema(defs: Array) -> Array:
	var result: Array = []
	for d in defs:
		result.append({
			"type": "function",
			"function": {
				"name": d["name"],
				"description": d.get("description", ""),
				"parameters": {
					"type": "object",
					"properties": d.get("properties", {}),
					"required": d.get("required", []),
				},
			},
		})
	return result


static func _to_claude_schema(defs: Array) -> Array:
	var result: Array = []
	for d in defs:
		result.append({
			"name": d["name"],
			"description": d.get("description", ""),
			"input_schema": {
				"type": "object",
				"properties": d.get("properties", {}),
				"required": d.get("required", []),
			},
		})
	return result


static func _to_gemini_schema(defs: Array) -> Array:
	var result: Array = []
	for d in defs:
		var fn: Dictionary = {
			"name": d["name"],
			"description": d.get("description", ""),
		}
		var props: Dictionary = d.get("properties", {})
		if not props.is_empty():
			fn["parameters"] = {
				"type": "object",
				"properties": props,
				"required": d.get("required", []),
			}
		result.append(fn)
	return result


## Inject tool schemas into an already-parsed request body dict.
## The dict is mutated in place — re-serialise to JSON after calling this.
static func inject_tools_into_body(provider_id: String, body_dict: Dictionary) -> void:
	var defs := _get_tool_defs()
	match provider_id:
		"openai":
			body_dict["tools"] = _to_openai_schema(defs)
			body_dict["tool_choice"] = "auto"
		"claude":
			body_dict["tools"] = _to_claude_schema(defs)
		"gemini":
			body_dict["tools"] = [{"functionDeclarations": _to_gemini_schema(defs)}]


# ---------------------------------------------------------------------------
# FC name reverse-mapping: provider function name → VG tool name
# ---------------------------------------------------------------------------
# play_run_main → play.run_main, play_stop → play.stop, others unchanged.

static func _fc_name_to_vg(fc_name: String) -> String:
	for d in _get_tool_defs():
		if d["name"] == fc_name:
			return d.get("_vg_name", fc_name)
	return fc_name


# ---------------------------------------------------------------------------
# Stream delta parsing
# ---------------------------------------------------------------------------
# Each function parses one SSE line and returns a fragment dict or null.
#
# Fragment keys (any subset may be present):
#   index      : int    — which parallel call slot (usually 0)
#   call_id    : String — provider-assigned ID (OpenAI/Claude)
#   name       : String — FC function name (NOT the VG tool name)
#   args_chunk : String — partial JSON arguments text (OpenAI/Claude)
#   args_dict  : Variant — pre-parsed arguments dict (Gemini only)

## Parse one SSE line looking for native FC content.
## Returns a fragment dict, or null if this line carries no FC data.
static func parse_stream_line_for_fc(provider_id: String, line: String) -> Variant:
	var json_str: String
	if line.begins_with("data: "):
		json_str = line.substr(6).strip_edges()
	else:
		json_str = line.strip_edges()
	if json_str.is_empty() or json_str == "[DONE]":
		return null
	if not json_str.begins_with("{"):
		return null
	var json = JSON.parse_string(json_str)
	if json == null or typeof(json) != TYPE_DICTIONARY:
		return null
	match provider_id:
		"openai":  return _parse_openai_fc(json)
		"claude":  return _parse_claude_fc(json)
		"gemini":  return _parse_gemini_fc(json)
	return null


static func _parse_openai_fc(json: Dictionary) -> Variant:
	var choices: Array = json.get("choices", [])
	if choices.is_empty():
		return null
	var delta: Dictionary = choices[0].get("delta", {})
	var tc_arr: Array = delta.get("tool_calls", [])
	if tc_arr.is_empty():
		return null
	var tc: Dictionary = tc_arr[0]
	var frag: Dictionary = {"index": int(tc.get("index", 0))}
	var call_id: String = str(tc.get("id", ""))
	if not call_id.is_empty():
		frag["call_id"] = call_id
	var fn: Dictionary = tc.get("function", {})
	var fn_name: String = str(fn.get("name", ""))
	if not fn_name.is_empty():
		frag["name"] = fn_name
	var args_chunk: String = str(fn.get("arguments", ""))
	if not args_chunk.is_empty():
		frag["args_chunk"] = args_chunk
	# Need at least name, call_id, or args to be meaningful.
	return frag if frag.size() > 1 else null


static func _parse_claude_fc(json: Dictionary) -> Variant:
	var event_type: String = str(json.get("type", ""))
	match event_type:
		"content_block_start":
			var block: Dictionary = json.get("content_block", {})
			if str(block.get("type", "")) != "tool_use":
				return null
			return {
				"index": int(json.get("index", 0)),
				"call_id": str(block.get("id", "")),
				"name": str(block.get("name", "")),
			}
		"content_block_delta":
			var delta: Dictionary = json.get("delta", {})
			if str(delta.get("type", "")) != "input_json_delta":
				return null
			var chunk: String = str(delta.get("partial_json", ""))
			if chunk.is_empty():
				return null
			return {
				"index": int(json.get("index", 0)),
				"args_chunk": chunk,
			}
	return null


static func _parse_gemini_fc(json: Dictionary) -> Variant:
	var candidates: Array = json.get("candidates", [])
	if candidates.is_empty():
		return null
	var parts: Array = candidates[0].get("content", {}).get("parts", [])
	for i in parts.size():
		var part: Dictionary = parts[i]
		if part.has("functionCall"):
			var fc: Dictionary = part.get("functionCall", {})
			return {
				"index": i,
				"name": str(fc.get("name", "")),
				"args_dict": fc.get("args", {}),
			}
	return null


# ---------------------------------------------------------------------------
# Fragment assembly
# ---------------------------------------------------------------------------

## Assemble streaming fragments into a list of complete calls.
## Returns Array of {name: String (VG tool name), args: Dictionary}.
static func assemble_fc_calls(fragments: Array) -> Array:
	# Collect fragments by call slot index.
	var by_index: Dictionary = {}  # int → {call_id, name, args_buf, args_dict}
	for frag in fragments:
		var idx: int = int(frag.get("index", 0))
		if not by_index.has(idx):
			by_index[idx] = {
				"call_id": "",
				"name": "",
				"args_buf": "",
				"args_dict": null,
			}
		var slot: Dictionary = by_index[idx]
		if frag.has("call_id") and not str(frag["call_id"]).is_empty():
			slot["call_id"] = str(frag["call_id"])
		if frag.has("name") and not str(frag["name"]).is_empty():
			slot["name"] = str(frag["name"])
		if frag.has("args_chunk"):
			slot["args_buf"] += str(frag["args_chunk"])
		if frag.has("args_dict") and frag["args_dict"] != null:
			slot["args_dict"] = frag["args_dict"]

	var sorted_indices: Array = by_index.keys()
	sorted_indices.sort()
	var result: Array = []
	for idx in sorted_indices:
		var slot: Dictionary = by_index[idx]
		var fn_name: String = str(slot.get("name", ""))
		if fn_name.is_empty():
			continue
		var vg_name: String = _fc_name_to_vg(fn_name)
		var args: Dictionary = {}
		# Prefer pre-parsed dict (Gemini) over streamed JSON (OpenAI/Claude).
		if slot["args_dict"] != null and typeof(slot["args_dict"]) == TYPE_DICTIONARY:
			args = slot["args_dict"]
		else:
			var buf: String = str(slot["args_buf"])
			if not buf.is_empty():
				var parsed = JSON.parse_string(buf)
				if typeof(parsed) == TYPE_DICTIONARY:
					args = parsed
		result.append({"name": vg_name, "args": args})
	return result


# ---------------------------------------------------------------------------
# Serialisation back to fenced vg-tool text
# ---------------------------------------------------------------------------

## Convert assembled calls to fenced vg-tool blocks.
## Append the returned string to _accumulated_response so that the existing
## plan_response() / dispatch chain handles them without modification.
static func to_fenced_text(calls: Array) -> String:
	var parts := PackedStringArray()
	for call in calls:
		var tool_obj: Dictionary = {"tool": str(call.get("name", ""))}
		var args: Dictionary = call.get("args", {})
		for k in args:
			tool_obj[k] = args[k]
		parts.append("```vg-tool\n%s\n```" % JSON.stringify(tool_obj))
	return "\n".join(parts)
