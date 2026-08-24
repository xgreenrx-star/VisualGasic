@tool
extends SceneTree

const Resolver := preload("res://addons/visual_gasic/vg_datafile_resolver.gd")
const Sniff := preload("res://addons/visual_gasic/vg_datafile_sniff.gd")
const VgdWriter := preload("res://addons/visual_gasic/vg_vgd_writer.gd")

var _failed := 0
var _passed := 0

const FIXTURE := """WorldMap:
DataFile "res://test_data/world.csv"

PlayerSprite:
Data 4, 4, 0, 0
Data 0, 1, 1, 0
"""


func _init() -> void:
	print("=== datafile headless tests ===")
	_test_resolve_datafile()
	_test_sniff_csv()
	_test_vgd_write_sniff()
	_finish()


func _test_resolve_datafile() -> void:
	print("-- resolver: DataFile under label --")
	var ref := Resolver.resolve_at_line(FIXTURE, 1)
	_check("resolves on DataFile line", not ref.is_empty())
	_check("label WorldMap", ref.get("label", "") == "WorldMap")
	_check("path csv", str(ref.get("path", "")).ends_with("world.csv"))
	_check("label line 0", int(ref.get("label_line", -1)) == 0)
	_check("data line 1", int(ref.get("data_line", -1)) == 1)
	_check("sprite block no datafile", Resolver.resolve_at_line(FIXTURE, 5).is_empty())

	const MULTI := """WorldTiles:
DataFile "res://data/world.vgd"
DataFile "res://data/world2.vgd"
"""
	print("-- resolver: multiple DataFile under one label --")
	var r1 := Resolver.resolve_at_line(MULTI, 1)
	_check("line1 world.vgd", str(r1.get("path", "")).ends_with("world.vgd"))
	_check("line1 data_line 1", int(r1.get("data_line", -1)) == 1)
	var r2 := Resolver.resolve_at_line(MULTI, 2)
	_check("line2 world2.vgd", str(r2.get("path", "")).ends_with("world2.vgd"))
	_check("line2 data_line 2", int(r2.get("data_line", -1)) == 2)


func _test_sniff_csv() -> void:
	print("-- sniff: csv heuristic --")
	var tmp := OS.get_cache_dir().path_join("vg_test_sniff.csv")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("0,1,2\n3,4,5\n")
	f.close()
	var s := Sniff.sniff_path(tmp)
	_check("csv kind", str(s.get("kind_name", "")) == "csv")
	_check("exists", bool(s.get("exists", false)))


func _test_vgd_write_sniff() -> void:
	print("-- vgd write + sniff --")
	var tmp := OS.get_cache_dir().path_join("vg_test_grid.vgd")
	var cells := PackedByteArray([0, 1, 2, 3])
	VgdWriter.write_grid_u8(tmp, 2, 2, cells)
	var s2 := Sniff.sniff_path(tmp)
	_check("vgd kind", str(s2.get("kind_name", "")) == "vgd")
	_check("2x2", int(s2.get("width", 0)) == 2 and int(s2.get("height", 0)) == 2)


func _check(label: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  OK  ", label)
	else:
		_failed += 1
		push_error("FAIL: " + label)


func _finish() -> void:
	print("")
	print("datafile tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
