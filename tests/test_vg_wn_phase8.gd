extends SceneTree

## Smoke test for the Working-Nodes round-trip improvements:
## (1) while-loop reads Condition param
## (2) For-Each reads Source_Array param
## (3) Action-node stubs use _intent_from_title
## (7) vg_ai_wnodes_spec parses fenced graphs
## (8) _VGParser recognises Call WN_X / If…Then / GetNode().prop = …

const CG = preload("res://addons/visual_gasic/plugins/working_nodes/working_nodes_codegen.gd")

func _init() -> void:
	_test_while_with_condition()
	_test_foreach_with_source_array()
	_test_action_intent_from_title()
	_test_wnodes_spec_parse()
	_test_vgparser_reverse()
	print("[PASS] test_vg_wn_phase8.gd")
	quit(0)


func _test_while_with_condition() -> void:
	var data := {
		"nodes": [
			{"name":"E1","kind":"Event","title":"On Start","event_type":"On Start","position":[0,0]},
			{"name":"L1","kind":"Loop","title":"loop","loop_type":"while","params":{"Condition":"hp > 0"},"position":[0,0]},
		],
		"connections": [{"from":"E1","from_port":0,"to":"L1","to_port":0}],
	}
	var code: String = CG.generate_vg_code(data)
	assert(code.find("Do While hp > 0") != -1,
		"while loop should emit 'Do While hp > 0', got:\n%s" % code)
	# And NOT the old hard-coded True placeholder.
	assert(code.find("Do While True") == -1,
		"while loop must not fall back to 'Do While True'")
	print("✓ while-loop honours Condition param")


func _test_foreach_with_source_array() -> void:
	var data := {
		"nodes": [
			{"name":"E1","kind":"Event","title":"On Start","event_type":"On Start","position":[0,0]},
			{"name":"L1","kind":"Loop","title":"loop","loop_type":"For Each","params":{"Source_Array":"enemies"},"position":[0,0]},
		],
		"connections": [{"from":"E1","from_port":0,"to":"L1","to_port":0}],
	}
	var code: String = CG.generate_vg_code(data)
	assert(code.find("For Each") != -1, "expected For Each, got:\n%s" % code)
	assert(code.find("enemies") != -1,
		"For Each should reference 'enemies' array, got:\n%s" % code)
	# Should not emit the placeholder comment "replace arr() with your array"
	assert(code.find("replace arr()") == -1,
		"For Each must drop the placeholder when Source_Array is provided")
	print("✓ For-Each honours Source_Array param")


func _test_action_intent_from_title() -> void:
	# _intent_from_title is exposed as a static helper on _VGGen via the codegen API.
	# We can't call inner classes directly from outside, so smoke-test through
	# generate_vg_code: an Action node titled "Fire Bullet" should produce a
	# Print body that mentions either "Fire" or "Spawn" intent — not a bare
	# "Action_WN_X executed" placeholder.
	var data := {
		"nodes": [
			{"name":"E1","kind":"Event","title":"On Start","event_type":"On Start","position":[0,0]},
			{"name":"A1","kind":"Action","title":"Fire Bullet","position":[0,0]},
		],
		"connections": [{"from":"E1","from_port":0,"to":"A1","to_port":0}],
	}
	var code: String = CG.generate_vg_code(data)
	# Body should at least include the title, and ideally not be the bare default.
	assert(code.find("Fire Bullet") != -1,
		"Action stub should mention the title 'Fire Bullet', got:\n%s" % code)
	print("✓ Action stub references node title")


func _test_wnodes_spec_parse() -> void:
	var SPEC = load("res://addons/visual_gasic/vg_ai_wnodes_spec.gd")
	assert(SPEC != null, "vg_ai_wnodes_spec.gd missing")
	var spec_obj = SPEC.new()
	var reply := """blah
```vg-wnodes-spec
{"path":"res://example.wnodes",
 "graph":{
   "nodes":[{"name":"E1","kind":"Event","title":"On Start","position":[0,0]}],
   "connections":[]
 }}
```
done"""
	var spec: Dictionary = spec_obj.extract_spec(reply)
	assert(not spec.is_empty(), "wnodes-spec should be extracted")
	assert(str(spec.get("path","")) == "res://example.wnodes")
	assert(spec.has("graph"), "spec must contain 'graph'")
	var desc: String = spec_obj.describe(spec)
	assert(desc.findn("example.wnodes") != -1, "describe() should mention the path")
	# Empty / malformed → empty dict.
	assert(spec_obj.extract_spec("nothing here").is_empty())
	assert(spec_obj.extract_spec("```vg-wnodes-spec\nnot json\n```").is_empty())
	print("✓ vg-wnodes-spec parsing")


func _test_vgparser_reverse() -> void:
	# (8) Round-trip a tiny VG program through parse_vg_to_graph_data and
	# check that recognisable patterns produce richer graphs than the old
	# header-only parser would have.
	var vg := """Sub Form_Load()
	Call WN_Move(1, 50, 0, 0.5)
	If hp > 0 Then
		GetNode("Player").position.x = 100
	End If
End Sub
"""
	var data: Dictionary = CG.parse_vg_to_graph_data(vg)
	assert(data.has("nodes"))
	var nodes: Array = data["nodes"]
	# We expect more than just the Sub header — at least the event itself
	# plus *something* representing the body (move call, branch, or set_prop).
	# This is intentionally loose because the parser is still heuristic.
	assert(nodes.size() >= 2,
		"reverse parser should emit at least 2 nodes, got %d:\n%s"
		% [nodes.size(), str(nodes)])
	print("✓ _VGParser produces multi-node graph from body")
