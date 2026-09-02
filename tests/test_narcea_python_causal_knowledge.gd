@tool
extends SceneTree
## Regression: Narcea KNOWLEDGE cites typed PyBridge protocol and causal chain audit.

const NarceaScript := preload("res://addons/visual_gasic/vg_ai_narcea.gd")

var _failed := 0
var _passed := 0


func _init() -> void:
	print("=== narcea python + causal knowledge tests ===")
	_test_knowledge_pybridge_and_causal()
	_finish()


func _test_knowledge_pybridge_and_causal() -> void:
	var n := NarceaScript.new()
	var ctx: String = n.build_context_block(null)
	_check("context non-empty", ctx.length() > 200)
	_check("mentions PyBridgeFacade", ctx.find("PyBridgeFacade") != -1)
	_check("mentions use_typed_protocol", ctx.find("use_typed_protocol") != -1)
	_check("mentions Show Causal Chain", ctx.find("Show Causal Chain") != -1)
	_check("mentions vg_analyze_causal_graph", ctx.find("vg_analyze_causal_graph") != -1)


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  OK  ", label)
	else:
		_failed += 1
		print("  FAIL ", label)


func _finish() -> void:
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
