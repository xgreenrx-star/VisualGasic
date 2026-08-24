@tool
extends SceneTree
## Regression: Narcea KNOWLEDGE cites DataFile for large tilemap questions.
## Simulates the AI panel calling set_query_hint before build_context_block.

const NarceaScript := preload("res://addons/visual_gasic/vg_ai_narcea.gd")

var _failed := 0
var _passed := 0

const TILEMAP_HINT := "how do I load a large tilemap?"


func _init() -> void:
	print("=== narcea datafile knowledge tests ===")
	_test_knowledge_contains_datafile()
	_test_query_hint_tilemap()
	_finish()


func _test_knowledge_contains_datafile() -> void:
	print("-- knowledge block (no hint) --")
	var n := NarceaScript.new()
	var ctx: String = n.build_context_block(null)
	_check("context non-empty", ctx.length() > 200)
	_check("mentions DataFile", ctx.find("DataFile") != -1)
	_check("mentions .vgd", ctx.find(".vgd") != -1)
	_check("mentions DataBuffer or PeekData", ctx.find("DataBuffer") != -1 or ctx.find("PeekData") != -1)


func _test_query_hint_tilemap() -> void:
	print("-- query hint: large tilemap --")
	var n := NarceaScript.new()
	n.set_query_hint(TILEMAP_HINT)
	var ctx: String = n.build_context_block(null)
	_check("hint builds context", ctx.length() > 200)
	_check("tilemap hint still cites DataFile", ctx.find("DataFile") != -1)
	_check("discourages inline megadata", ctx.find("inline") != -1 or ctx.find("Large tilemaps") != -1)


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
