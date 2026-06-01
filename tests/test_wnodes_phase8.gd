extends SceneTree

## Smoke test for Phase 8: vg-wnodes-spec extract.
##
## Codegen-level tests (parser + while/foreach codegen) are NOT runtime-tested
## here because working_nodes_codegen.gd self-references its `class_name`,
## which only resolves with a populated `.godot/global_script_class_cache.cfg`.
## Those changes are validated by `get_errors` (LSP) and live IDE usage.

func _init() -> void:
	_test_wnodes_spec_extract()
	print("[PASS] test_wnodes_phase8.gd")
	quit(0)


func _test_wnodes_spec_extract() -> void:
	var WS = load("res://addons/visual_gasic/vg_ai_wnodes_spec.gd")
	assert(WS != null, "vg_ai_wnodes_spec.gd missing")
	var ws = WS.new()
	# Single graph form
	var reply := """noise
```vg-wnodes-spec
{"path":"res://test.wnodes","graph":{"nodes":[{"name":"E1","kind":"Event","title":"On Start"}],"connections":[]},"summary":"test graph"}
```
end"""
	var spec: Dictionary = ws.extract_spec(reply)
	assert(spec.has("graphs"))
	assert(spec["graphs"].size() == 1)
	assert(str(spec["graphs"][0]["path"]) == "res://test.wnodes")
	assert("1 .wnodes" in ws.describe(spec))
	print("✓ vg-wnodes-spec extract single")

	# Multi-graph batch
	var multi := """```vg-wnodes-spec
{"graphs":[{"path":"res://a.wnodes","graph":{"nodes":[]}},{"path":"res://b.wnodes","graph":{"nodes":[]}}]}
```"""
	var spec2: Dictionary = ws.extract_spec(multi)
	assert(spec2["graphs"].size() == 2)
	assert("2 .wnodes" in ws.describe(spec2))
	print("✓ vg-wnodes-spec extract multi")

	# Reject garbage
	assert(ws.extract_spec("nothing").is_empty())
	assert(ws.extract_spec("```vg-wnodes-spec\ngarbage\n```").is_empty())
	print("✓ vg-wnodes-spec rejects garbage")
