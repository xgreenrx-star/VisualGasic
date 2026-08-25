@tool
extends SceneTree

const UsageAnalyzer := preload("res://addons/visual_gasic/vg_datafile_usage_analyzer.gd")
const GridIO := preload("res://addons/visual_gasic/vg_datafile_grid_io.gd")

var _failed := 0
var _passed := 0

const SAMPLE := """Const MAP_W As Integer = 12
Const MAP_H As Integer = 10

WorldTiles:
DataFile "res://data/world.vgd"

Sub DrawMap()
    Dim n As Integer
    n = DataCount("WorldTiles")
    Dim tile As Integer
    tile = PeekData("WorldTiles", 119)
    For row = 0 To MAP_H - 1
        For col = 0 To MAP_W - 1
            Dim idx As Integer
            idx = row * MAP_W + col
            tile = PeekData("WorldTiles", idx)
        Next col
    Next row
End Sub
"""


func _init() -> void:
	print("=== datafile usage analyzer tests ===")
	_test_resize_cells()
	_test_analyze_sample()
	_finish()


func _test_resize_cells() -> void:
	var cells := PackedByteArray([1, 2, 3, 4])
	var out := GridIO.resize_cells(cells, 2, 2, 3, 2, 0)
	_check("resize widens", out.size() == 6)
	_check("keeps top-left", out[0] == 1 and out[1] == 2 and out[3] == 3)


func _test_analyze_sample() -> void:
	var tmp := OS.get_cache_dir().path_join("vg_usage_test.vg")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(SAMPLE)
	f.close()
	var report := UsageAnalyzer.analyze_resize_impact(
		"WorldTiles", 12, 10, 16, 12, tmp.get_base_dir(), PackedStringArray([tmp])
	)
	var findings: Array = report.get("findings", [])
	_check("finds datacount", _has_kind(findings, UsageAnalyzer.KIND_DATACOUNT))
	_check("finds peek literal", _has_kind(findings, UsageAnalyzer.KIND_PEEKDATA_LITERAL))
	_check("finds const width", _has_kind(findings, UsageAnalyzer.KIND_CONST_WIDTH))
	_check("finds const height", _has_kind(findings, UsageAnalyzer.KIND_CONST_HEIGHT))
	_check("finds flat index", _has_kind(findings, UsageAnalyzer.KIND_PEEKDATA_EXPR))


func _has_kind(findings: Array, kind: String) -> bool:
	for item in findings:
		if str(item.get("kind", "")) == kind:
			return true
	return false


func _check(label: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  OK  ", label)
	else:
		_failed += 1
		push_error("FAIL: " + label)


func _finish() -> void:
	print("")
	print("usage analyzer tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
