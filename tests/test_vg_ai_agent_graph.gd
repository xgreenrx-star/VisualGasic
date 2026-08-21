extends SceneTree

func _init() -> void:
	var AG = load("res://addons/visual_gasic/vg_ai_agent_graph.gd")
	assert(AG != null, "vg_ai_agent_graph.gd missing")
	var ag = AG.new()

	var plan := {
		"read_only": [{"tool": "read_file", "path": "res://Form1.vg"}],
		"mutating": [{"tool": "write_file", "path": "res://Form1.vg", "contents": "x"}],
		"blocked": [{"call": {"tool": "write_file"}, "reason": "budget exhausted"}],
	}
	var tools: Array = ag.tools_from_plan(plan)
	assert(tools.size() == 3)
	assert(tools[0]["status"] == "read")
	assert(tools[1]["status"] == "mutate")
	assert(tools[2]["status"] == "blocked")

	var hops := [{
		"hop": 0,
		"prompt": "Fix the counter bug",
		"tools": tools,
	}]
	var proj: Dictionary = ag.build_project(hops, {"reason": "complete"})
	assert(proj.has("nodes"))
	assert(proj.has("connections"))
	var nodes: Array = proj["nodes"]
	assert(nodes.size() >= 4, "expected session + hop + 3 tools + end")
	assert((proj["connections"] as Array).size() == nodes.size() - 1)
	assert(str(nodes[0]["type"]) == "event")
	assert("Hop 0" in str(nodes[1]["title"]))
	print("[PASS] test_vg_ai_agent_graph.gd")
	quit(0)
