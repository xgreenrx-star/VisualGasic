@tool
extends RefCounted
## Working-Nodes-spec — Narcea emits a complete `.wnodes` graph (the
## same JSON the Working Nodes editor saves/loads).  The AI panel
## writes the file via safe_writer.  The user can then open it in the
## Working Nodes editor and (optionally) export back to .vg.
##
## Schema (fenced as ```vg-wnodes-spec):
##
##   {
##     "path": "res://my_form.wnodes",
##     "graph": {
##       "nodes": [
##         {
##           "name": "Event_Click_1",
##           "kind": "Event",
##           "title": "On Click",
##           "params": { "Target": "btnGo", "Sub_Name": "btnGo_Click" },
##           "position": [40, 40]
##         },
##         {
##           "name": "Action_Spawn_1",
##           "kind": "Action",
##           "title": "Spawn bullet",
##           "params": { "Scene": "res://bullet.tscn" },
##           "position": [340, 40]
##         }
##       ],
##       "connections": [
##         { "from": "Event_Click_1", "to": "Action_Spawn_1" }
##       ]
##     },
##     "summary": "Wires btnGo → spawn bullet"
##   }
##
## Or a multi-graph batch under `graphs`:
##
##   {
##     "graphs": [
##       {"path": "res://a.wnodes", "graph": {...}, "summary": "..."},
##       {"path": "res://b.wnodes", "graph": {...}, "summary": "..."}
##     ]
##   }

const FENCE_RE := "```vg-wnodes-spec\\s*([\\s\\S]*?)```"


func extract_spec(response_text: String) -> Dictionary:
	if response_text.is_empty():
		return {}
	var rx := RegEx.new()
	rx.compile(FENCE_RE)
	var m := rx.search(response_text)
	if m == null:
		return {}
	var parsed = JSON.parse_string(m.get_string(1).strip_edges())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	# Normalise into {"graphs":[{path, graph, summary?}, ...]}.
	if parsed.has("graphs") and typeof(parsed["graphs"]) == TYPE_ARRAY:
		return parsed
	if parsed.has("path") and parsed.has("graph"):
		return {"graphs": [parsed]}
	return {}


func describe(spec: Dictionary) -> String:
	var arr: Array = spec.get("graphs", [])
	if arr.size() == 1:
		var g: Dictionary = arr[0]
		var node_count: int = (g.get("graph", {}).get("nodes", []) as Array).size()
		return "1 .wnodes (%s — %d nodes)" % [str(g.get("path", "?")), node_count]
	return "%d .wnodes files" % arr.size()


## Returns a plan compatible with vg_ai_diff_dialog.
func plan(spec: Dictionary, safe_writer: Object) -> Array:
	var out: Array = []
	for g in spec.get("graphs", []):
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var p := str(g.get("path", ""))
		if p.is_empty() or not g.has("graph"):
			continue
		var src := JSON.stringify(g["graph"], "\t")
		var old := ""
		if FileAccess.file_exists(p):
			var rf := FileAccess.open(p, FileAccess.READ)
			if rf:
				old = rf.get_as_text()
				rf.close()
		var safety: Array = safe_writer.is_safe(p) if safe_writer else [true, ""]
		var action := "create" if old.is_empty() else "update"
		if old == src:
			action = "unchanged"
		out.append({
			"path": p,
			"old": old,
			"new": src,
			"action": action,
			"safe": safety[0],
			"safe_reason": str(safety[1]),
			"lint": [],
		})
	return out


## Apply (write) the .wnodes files.
func apply(spec: Dictionary, safe_writer: Object, _strict: bool = false) -> Dictionary:
	var result := {"ok": false, "written": [], "skipped": [], "lint": [], "summary": ""}
	if spec.is_empty() or safe_writer == null:
		result["summary"] = "No .wnodes spec to apply."
		return result
	for g in spec.get("graphs", []):
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var p := str(g.get("path", ""))
		if p.is_empty() or not g.has("graph"):
			result["skipped"].append({"path": p, "reason": "missing path or graph"})
			continue
		var src := JSON.stringify(g["graph"], "\t")
		var safety: Array = safe_writer.is_safe(p)
		if not safety[0]:
			result["skipped"].append({"path": p, "reason": str(safety[1])})
			continue
		var write_res: Array = safe_writer.write(p, src)
		if write_res[0]:
			result["written"].append(p)
		else:
			result["skipped"].append({"path": p, "reason": str(write_res[1])})
	var w: int = result["written"].size()
	var s: int = result["skipped"].size()
	result["ok"] = w > 0
	result["summary"] = "wrote %d .wnodes file(s), skipped %d" % [w, s]
	return result
