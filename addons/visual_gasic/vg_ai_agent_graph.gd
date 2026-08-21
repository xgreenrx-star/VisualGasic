@tool
extends RefCounted
## Build a Working Nodes project (`.wnodes` JSON) from an agent-session hop
## log.  Phase 6d visual audit: each hop becomes a vertical chain of tool
## nodes that opens in the existing Working Nodes canvas.
##
## Input `hops` shape (built by vg_ai_help.gd):
##   [{ "hop": 0, "prompt": "...", "tools": [
##        {"tool":"read_file","status":"read","params":{"path":"..."}},
##        {"tool":"write_file","status":"mutate","params":{"path":"..."}},
##        {"tool":"blocked","status":"blocked","params":{"Reason":"..."}}
##   ]}, ...]

const Y_STEP := 96
const X_BASE := 48


## Full Working Nodes editor project dict (version 1).
func build_project(hops: Array, meta: Dictionary = {}) -> Dictionary:
	var nodes: Array = []
	var connections: Array = []
	var next_id := 1
	var y := 40.0
	var prev_name := ""

	var start_name := _add_node(nodes, next_id, y, "event", "Agent session", {})
	next_id += 1
	y += Y_STEP
	prev_name = start_name

	for hop_data in hops:
		if typeof(hop_data) != TYPE_DICTIONARY:
			continue
		var hop_n: int = int(hop_data.get("hop", 0))
		var prompt: String = str(hop_data.get("prompt", "")).strip_edges()
		var hop_title := "Hop %d" % hop_n
		if not prompt.is_empty():
			hop_title += ": " + prompt.left(72)
		var hop_name := _add_node(nodes, next_id, y, "note", hop_title, {"Text": prompt.left(800)})
		next_id += 1
		y += Y_STEP
		connections.append(_conn(prev_name, hop_name))
		prev_name = hop_name

		for tool in hop_data.get("tools", []):
			if typeof(tool) != TYPE_DICTIONARY:
				continue
			var status: String = str(tool.get("status", "action"))
			var title: String = describe_tool(tool)
			var ntype := "branch" if status == "blocked" else "action"
			var tname := _add_node(nodes, next_id, y, ntype, title, tool.get("params", {}))
			next_id += 1
			y += Y_STEP
			connections.append(_conn(prev_name, tname))
			prev_name = tname

	var reason: String = str(meta.get("reason", "complete"))
	var end_name := _add_node(nodes, next_id, y, "event", "Session end: %s" % reason, {})
	connections.append(_conn(prev_name, end_name))

	return {
		"version": 1,
		"next_node_id": next_id + 1,
		"next_group_id": 2,
		"groups": [{"id": 1, "name": "Agent run", "color": "#6688cc"}],
		"nodes": nodes,
		"connections": connections,
	}


## One-line label for a tool-call dict (used by graph nodes and chat summaries).
func describe_tool(tool: Dictionary) -> String:
	var tname: String = str(tool.get("tool", "?")).strip_edges()
	var status: String = str(tool.get("status", ""))
	var args: Dictionary = tool.get("params", {}) if typeof(tool.get("params")) == TYPE_DICTIONARY else {}
	match tname:
		"read_file", "write_file", "open_file":
			var p: String = str(args.get("path", args.get("Path", "")))
			if p.is_empty():
				p = str(tool.get("path", ""))
			return "%s %s" % [tname, p.get_file() if not p.is_empty() else ""]
		"list_dir":
			return "list_dir %s" % str(args.get("path", args.get("Path", "."))).left(48)
		"find_in_files":
			return "find '%s'" % str(args.get("query", args.get("pattern", ""))).left(40)
		"insert_text":
			return "insert line %d" % int(tool.get("line", args.get("line", 0)))
		"replace_range":
			return "replace lines %d-%d" % [
				int(tool.get("start_line", args.get("start_line", 0))),
				int(tool.get("end_line", args.get("end_line", 0))),
			]
		"set_buffer_text":
			return "overwrite buffer"
		"save_file":
			return "save file"
		"play.run_main":
			return "▶ run main scene"
		"play.stop":
			return "⏹ stop run"
		"build_form":
			return "build form"
		"blocked":
			return "blocked: %s" % str(args.get("Reason", tool.get("reason", ""))).left(60)
		_:
			if status == "blocked":
				return "blocked %s" % tname
			if status == "read":
				return "read %s" % tname
			if status == "mutate":
				return "mutate %s" % tname
			return tname if not tname.is_empty() else "tool"


## Flatten a vg_ai_tools.plan_response() dict into graph tool entries.
func tools_from_plan(plan: Dictionary) -> Array:
	var out: Array = []
	for c in plan.get("read_only", []):
		if typeof(c) == TYPE_DICTIONARY:
			out.append(_entry_from_call(c, "read"))
	for c in plan.get("mutating", []):
		if typeof(c) == TYPE_DICTIONARY:
			out.append(_entry_from_call(c, "mutate"))
	for b in plan.get("blocked", []):
		if typeof(b) == TYPE_DICTIONARY:
			var call: Dictionary = b.get("call", {}) if typeof(b.get("call")) == TYPE_DICTIONARY else {}
			out.append({
				"tool": str(call.get("tool", "blocked")),
				"status": "blocked",
				"params": {"Reason": str(b.get("reason", ""))},
			})
		else:
			out.append({
				"tool": "blocked",
				"status": "blocked",
				"params": {"Reason": str(b)},
			})
	return out


func default_path(session_ts: String) -> String:
	var safe_ts := session_ts.strip_edges()
	if safe_ts.is_empty():
		safe_ts = "session"
	return "res://.narcea/agent_runs/%s.wnodes" % safe_ts


func _entry_from_call(call: Dictionary, status: String) -> Dictionary:
	var params: Dictionary = {}
	for k in call.keys():
		if k == "tool":
			continue
		params[k] = call[k]
	return {
		"tool": str(call.get("tool", "")),
		"status": status,
		"params": params,
	}


func _add_node(nodes: Array, id: int, y: float, node_type: String, title: String, params: Dictionary) -> String:
	var name := "WN_%d" % id
	nodes.append({
		"name": name,
		"title": title,
		"type": node_type,
		"group": 1,
		"position": [X_BASE, y],
		"params": params,
	})
	return name


func _conn(from_name: String, to_name: String) -> Dictionary:
	return {"from": from_name, "from_port": 0, "to": to_name, "to_port": 0}
