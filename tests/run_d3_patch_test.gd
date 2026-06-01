#!/usr/bin/env -S godot --headless --script
extends SceneTree

# D3 source write-back regression test.
# Run with:
#   ./Godot_v4.6.1-stable_linux.x86_64 --headless --path tests \
#       --script res://run_d3_patch_test.gd
#
# Asserts that VGTweakSource.patch_property() correctly:
#   (1) rewrites a `Color(r, g, b, a)` literal,
#   (2) rewrites a named `Color.RED` literal,
#   (3) returns ok=false (without corrupting the file) when no Color is on the line,
#   (4) returns ok=false for unsupported properties.

const SRC := preload("res://addons/visual_gasic/vg_tweak/vg_tweak_source.gd")

var _failures: Array[String] = []

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		print("  FAIL ", msg)
		_failures.append(msg)

func _write_tmp(name: String, text: String) -> String:
	var path := "user://%s" % name
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return path

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	var t := f.get_as_text()
	f.close()
	return t

func _initialize() -> void:
	print("=== D3 source-patch test ===")

	# (1) Color(r,g,b,a) form
	var p1 := _write_tmp("d3_test_1.vg",
		"Call vg.DrawRect(canvas, Vector2(0, 0), Vector2(10, 10), 1.0, Color(1.0, 0.0, 0.0, 1.0), True, Color(1.0, 0.0, 0.0, 1.0))\n")
	var r1: Dictionary = SRC.patch_property({"file": p1, "line": 1}, "color", Color(0.0, 1.0, 0.0, 1.0))
	_ok(r1.get("ok", false), "Color(...) form: ok=true (err=%s)" % r1.get("error", ""))
	_ok(_read(p1).find("Color(0, 1, 0, 1)") >= 0, "Color(...) form: file contains new literal")
	_ok(_read(p1).find("Color(1.0, 0.0, 0.0, 1.0)") < 0 or _read(p1).count("Color(") <= 2, "Color(...) form: at most one literal still present (fill)")

	# (2) Named Color.RED form
	var p2 := _write_tmp("d3_test_2.vg",
		"Call vg.DrawRect(canvas, Vector2(0, 0), Vector2(10, 10), 1.0, Color.RED, True, Color.RED)\n")
	var r2: Dictionary = SRC.patch_property({"file": p2, "line": 1}, "color", Color(0.0, 0.0, 1.0, 1.0))
	_ok(r2.get("ok", false), "Color.RED form: ok=true (err=%s)" % r2.get("error", ""))
	_ok(_read(p2).find("Color(0, 0, 1, 1)") >= 0, "Color.RED form: file contains new Color literal")

	# (3) No Color on line — must NOT corrupt the file
	var src3 := "Call vg.DrawLine(canvas, Vector2(0, 0), Vector2(10, 10), 1.0)\n"
	var p3 := _write_tmp("d3_test_3.vg", src3)
	var r3: Dictionary = SRC.patch_property({"file": p3, "line": 1}, "color", Color(1.0, 0.0, 0.0, 1.0))
	_ok(not r3.get("ok", false), "No literal: ok=false")
	_ok(_read(p3) == src3, "No literal: file unchanged")

	# (4) Unsupported property
	var src4 := "Call vg.DrawText(canvas, \"hi\", Vector2(0, 0), 12, Color.WHITE)\n"
	var p4 := _write_tmp("d3_test_4.vg", src4)
	var r4: Dictionary = SRC.patch_property({"file": p4, "line": 1}, "thickness", 2.0)
	_ok(not r4.get("ok", false), "Unsupported prop: ok=false")
	_ok(str(r4.get("error", "")).find("not supported") >= 0, "Unsupported prop: error mentions 'not supported'")
	_ok(_read(p4) == src4, "Unsupported prop: file unchanged")

	# (5) Bad hint
	var r5: Dictionary = SRC.patch_property({}, "color", Color.WHITE)
	_ok(not r5.get("ok", false), "Empty hint: ok=false")

	print("=== %d failure(s) ===" % _failures.size())
	for m in _failures:
		print("    !! ", m)
	quit(0 if _failures.is_empty() else 1)
