extends SceneTree

## Tests for Working Nodes codegen + parser improvements (#1, #2, #3, #8).
## Run with:
##   ./Godot_v4.6.1-stable_linux.x86_64 --headless --path . \
##       --script res://tests/test_wn_codegen_roundtrip.gd

const WNC = preload("res://addons/visual_gasic/plugins/working_nodes/working_nodes_codegen.gd")


func _init() -> void:
	_test_while_loop_uses_condition()
	_test_foreach_uses_source_array()
	_test_action_intent_from_title()
	_test_parser_wn_calls()
	_test_parser_if_block()
	_test_parser_set_prop()
	_test_parser_get_prop()
	_test_parser_roundtrip_smoke()
	print("[PASS] test_wn_codegen_roundtrip.gd")
	quit(0)


# ─── Codegen #1: while-loop condition param ────────────────────────────────
func _test_while_loop_uses_condition() -> void:
	var data := {
		"version": 1, "next_node_id": 5, "next_group_id": 2,
		"nodes": [
			{"name":"WN_Ev_1","title":"Start","kind":"Event","event_type":"On Start","position":[0,0]},
			{"name":"WN_Loop_1","title":"Wait Until","kind":"Loop","loop_type":"While",
				"params":{"Condition":"score < 10"},"position":[200,0]},
		],
		"connections": [
			{"from":"WN_Ev_1","from_port":0,"to":"WN_Loop_1","to_port":0},
		],
		"groups":[{"id":1,"name":"Group 1","color":"#88AAFF"}],
	}
	var code: String = WNC.generate_vg_code(data)
	assert("Do While score < 10" in code, "while-loop didn't use Condition param. Got:\n" + code)
	# The unconditional "Do While True" placeholder must NOT appear.
	assert(not ("Do While True" in code), "should not emit Do While True when Condition is set")
	print("✓ while-loop uses Condition param")


# ─── Codegen #2: For Each uses Source_Array param ──────────────────────────
func _test_foreach_uses_source_array() -> void:
	var data := {
		"version": 1, "next_node_id": 5, "next_group_id": 2,
		"nodes": [
			{"name":"WN_Ev_1","title":"Start","kind":"Event","event_type":"On Start","position":[0,0]},
			{"name":"WN_Loop_1","title":"For Each","kind":"Loop","loop_type":"For Each",
				"params":{"Source_Array":"enemies"},"position":[200,0]},
		],
		"connections": [{"from":"WN_Ev_1","from_port":0,"to":"WN_Loop_1","to_port":0}],
		"groups":[{"id":1,"name":"Group 1","color":"#88AAFF"}],
	}
	var code: String = WNC.generate_vg_code(data)
	assert("For Each _item In enemies()" in code, "For Each didn't use Source_Array. Got:\n" + code)
	assert(not ("In arr()" in code), "should not emit placeholder arr()")
	print("✓ For Each uses Source_Array param")


# ─── Codegen #3: Action node stubs inferred from title ─────────────────────
func _test_action_intent_from_title() -> void:
	var data := {
		"version": 1, "next_node_id": 5, "next_group_id": 2,
		"nodes": [
			{"name":"WN_Ev_1","title":"Click","kind":"Event","event_type":"On Click","position":[0,0]},
			{"name":"WN_Act_1","title":"Shoot Bullet","kind":"Action","position":[200,0]},
			{"name":"WN_Act_2","title":"Play Beep","kind":"Action","position":[400,0]},
			{"name":"WN_Act_3","title":"Spin Sprite","kind":"Action","position":[600,0]},
		],
		"connections": [
			{"from":"WN_Ev_1","from_port":0,"to":"WN_Act_1","to_port":0},
			{"from":"WN_Act_1","from_port":0,"to":"WN_Act_2","to_port":0},
			{"from":"WN_Act_2","from_port":0,"to":"WN_Act_3","to_port":0},
		],
		"groups":[{"id":1,"name":"Group 1","color":"#88AAFF"}],
	}
	var code: String = WNC.generate_vg_code(data)
	assert("Call WN_Spawn" in code, "Shoot Bullet should infer WN_Spawn. Got:\n" + code)
	assert("Call WN_PlaySFX" in code, "Play Beep should infer WN_PlaySFX. Got:\n" + code)
	assert("Call WN_Rotate" in code, "Spin Sprite should infer WN_Rotate. Got:\n" + code)
	print("✓ Action node titles infer WN palette intents")


# ─── Parser #8: round-trip Call WN_xxx() lines ─────────────────────────────
func _test_parser_wn_calls() -> void:
	var vg := """
Sub Form_Load()
    Call WN_Move(1, 100, 0, 0.5)
    Call WN_Rotate(2, 90, 0.2)
    Call WN_PlaySFX("res://beep.wav", 1, 1)
End Sub
"""
	var data: Dictionary = WNC.parse_vg_to_graph_data(vg)
	assert(data.has("nodes"))
	var kinds: Array[String] = []
	for nd in data["nodes"]:
		kinds.append(str(nd.get("kind", "")).to_lower())
	assert(kinds.has("move"), "expected a Move node, got kinds=%s" % str(kinds))
	assert(kinds.has("rotate"))
	assert(kinds.has("play sfx"))
	# Verify params were captured for the Move node.
	for nd in data["nodes"]:
		if str(nd.get("kind","")).to_lower() == "move":
			var p: Dictionary = nd.get("params", {})
			assert(str(p.get("Group_ID","")) == "1", "Group_ID=%s" % p.get("Group_ID"))
			assert(str(p.get("X","")) == "100")
			assert(str(p.get("Duration","")) == "0.5")
	print("✓ parser maps Call WN_xxx() → kind+params")


# ─── Parser #8: If/Then/Else block → branch node ───────────────────────────
func _test_parser_if_block() -> void:
	var vg := """
Sub Form_Load()
    If score >= 10 Then
        Call WN_Spawn(1, 0)
    Else
        Print "not yet"
    End If
End Sub
"""
	var data: Dictionary = WNC.parse_vg_to_graph_data(vg)
	var saw_branch := false
	var saw_spawn := false
	for nd in data["nodes"]:
		var k: String = str(nd.get("kind","")).to_lower()
		if k == "cmp trig":
			saw_branch = true
			var p: Dictionary = nd.get("params", {})
			assert(str(p.get("A","")) == "score", "A=%s" % p.get("A"))
			assert(str(p.get("Op","")) == ">=")
			assert(str(p.get("B","")) == "10")
		if k == "spawn":
			saw_spawn = true
	assert(saw_branch, "If/Then/Else not converted to Cmp Trig branch")
	assert(saw_spawn, "Spawn child of If wasn't captured")
	# Verify the spawn is wired off port 0 of the branch.
	var branch_name := ""
	for nd in data["nodes"]:
		if str(nd.get("kind","")).to_lower() == "cmp trig":
			branch_name = str(nd["name"])
	var found_port_0 := false
	for c in data["connections"]:
		if str(c.get("from","")) == branch_name and int(c.get("from_port",-1)) == 0:
			found_port_0 = true
	assert(found_port_0, "branch true-port connection missing")
	print("✓ parser converts If/Else → Cmp Trig branch with port wiring")


# ─── Parser #8: GetNode().prop = value → set_prop ──────────────────────────
func _test_parser_set_prop() -> void:
	var vg := """
Sub Form_Load()
    GetNode("Player").position.x = 42
End Sub
"""
	var data: Dictionary = WNC.parse_vg_to_graph_data(vg)
	for nd in data["nodes"]:
		if str(nd.get("kind","")).to_lower() == "set prop":
			var p: Dictionary = nd.get("params", {})
			assert(str(p.get("Node_Path","")) == "Player")
			assert(str(p.get("Property","")) == "position.x")
			assert(str(p.get("Value","")) == "42")
			print("✓ parser converts GetNode().prop = X → set_prop")
			return
	assert(false, "no set_prop node produced")


# ─── Parser #8: var = GetNode().prop → get_prop ────────────────────────────
func _test_parser_get_prop() -> void:
	var vg := """
Sub Form_Load()
    myX = GetNode("Player").position.x
End Sub
"""
	var data: Dictionary = WNC.parse_vg_to_graph_data(vg)
	for nd in data["nodes"]:
		if str(nd.get("kind","")).to_lower() == "get prop":
			var p: Dictionary = nd.get("params", {})
			assert(str(p.get("Node_Path","")) == "Player")
			assert(str(p.get("Property","")) == "position.x")
			assert(str(p.get("Store_To","")) == "myX")
			print("✓ parser converts var = GetNode().prop → get_prop")
			return
	assert(false, "no get_prop node produced")


# ─── End-to-end smoke: codegen → parser produces structurally valid graph ──
func _test_parser_roundtrip_smoke() -> void:
	var orig := {
		"version": 1, "next_node_id": 5, "next_group_id": 2,
		"nodes": [
			{"name":"WN_Ev_1","title":"Start","kind":"Event","event_type":"On Start","position":[0,0]},
			{"name":"WN_Move_1","title":"Move","kind":"Move",
				"params":{"Group_ID":"1","X":"50","Y":"0","Duration":"0.5"},"position":[200,0]},
			{"name":"WN_Rot_1","title":"Rotate","kind":"Rotate",
				"params":{"Group_ID":"1","Degrees":"90","Duration":"0.3"},"position":[400,0]},
		],
		"connections": [
			{"from":"WN_Ev_1","from_port":0,"to":"WN_Move_1","to_port":0},
			{"from":"WN_Move_1","from_port":0,"to":"WN_Rot_1","to_port":0},
		],
		"groups":[{"id":1,"name":"Group 1","color":"#88AAFF"}],
	}
	var code: String = WNC.generate_vg_code(orig)
	var parsed: Dictionary = WNC.parse_vg_to_graph_data(code)
	# The parser should recover the Move + Rotate nodes from the generated WN_Move
	# and WN_Rotate calls inside Sub Form_Load.
	var kinds: Array[String] = []
	for nd in parsed["nodes"]:
		kinds.append(str(nd.get("kind","")).to_lower())
	assert("move" in kinds, "round-trip lost Move. kinds=%s" % str(kinds))
	assert("rotate" in kinds, "round-trip lost Rotate. kinds=%s" % str(kinds))
	print("✓ codegen → parser round-trip recovers move/rotate")
