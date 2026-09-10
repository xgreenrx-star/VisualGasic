@tool
extends SceneTree
## Headless tests: inline vector Data resolver, sync, VGV I/O, highlights.
## Run: scripts/run_vector_data_tests.sh

const Resolver := preload("res://addons/visual_gasic/vg_vector_data_resolver.gd")
const Sync := preload("res://addons/visual_gasic/vg_vector_data_sync.gd")
const Highlight := preload("res://addons/visual_gasic/vg_vector_data_highlight.gd")
const Vgv := preload("res://addons/visual_gasic/vg_vgv_resolver.gd")
const CanvasScript := preload("res://addons/visual_gasic/vg_vector_edit_canvas.gd")

var _failed := 0
var _passed := 0

const FIXTURE := """ArrowVector:
Data 64, 64, 4
Data LINE, 4, 32, 60, 32, 255, 255, 255, 255, 2
Data POLYLINE, 3, 44, 20, 60, 32, 44, 44, 255, 200, 80, 255, 2

NoteData:
Data \"C4\", 261.63
"""

const POD_FIXTURE := """PodCapsuleVector:
Data 48, 28, 2
Data RECT, 8, 8, 32, 20, 56, 82, 107, 255, 0
Data RECT, 26, 8, 42, 20, 56, 82, 107, 255, 0
Data RECT, 30, 10, 40, 18, 61, 204, 255, 255, 0
Data LINE, 2, 14, 10, 14, 61, 204, 255, 160, 2
"""

const SKIFF_FIXTURE := """SkiffVector:
Data 72, 28, 2
Data RECT, 0, 10, 72, 26, 232, 245, 255, 191, 0
Data RECT, 18, 4, 54, 16, 61, 204, 255, 140, 0
Data LINE, 58, 14, 68, 14, 61, 204, 255, 230, 255, 2
Data POLYLINE, 3, 68, 14, 72, 12, 72, 16, 61, 204, 255, 200, 255, 1.5
"""

const VGV_SAMPLE := """VGV1
64,64
1,12
FRAMES
FRAME 0
SHAPE LINE,4.0000,32.0000,60.0000,32.0000,255,255,255,255,2.0000,0,0,0,0
SHAPE POLYLINE,44.0000,20.0000,60.0000,32.0000,255,200,80,255,2.0000,0,0,0,0
POINTS 3,44.0000,20.0000,60.0000,32.0000,44.0000,44.0000
ENDFRAME
ENDVGV
"""


func _init() -> void:
	print("=== vector_data headless tests ===")
	print("")
	_test_resolver_hits()
	_test_resolver_rejects()
	_test_sync_roundtrip()
	_test_enumerate_blocks()
	_test_native_highlight()
	_test_vgv_roundtrip()
	_test_sync_add_shape()
	_test_skiff_wide_block()
	_test_pod_capsule_tokens()
	_test_canvas_refit_on_resize()
	_finish()


func _test_resolver_hits() -> void:
	print("-- resolver: valid *Vector block --")
	var sec := Resolver.resolve_at_line(FIXTURE, 2)
	_check("resolves on shape line", not sec.is_empty())
	_check("label ArrowVector", sec.get("label", "") == "ArrowVector")
	_check("64x64 view", sec.get("view_w", 0) == 64 and sec.get("view_h", 0) == 64)
	_check("grid step 4", sec.get("grid_step", -1) == 4)
	var shapes: Array = sec.get("shapes", [])
	_check("two shapes", shapes.size() == 2)
	_check("first is LINE", str(shapes[0].get("type", "")).to_upper() == "LINE")
	_check("polyline points", (shapes[1].get("points", PackedVector2Array()) as PackedVector2Array).size() == 3)


func _test_resolver_rejects() -> void:
	print("-- resolver: reject non-vector --")
	_check("NoteData line empty", Resolver.resolve_at_line(FIXTURE, 6).is_empty())
	_check("NoteData not vector label", not Resolver.is_vector_label("NoteData"))
	_check("empty source", Resolver.resolve_at_line("", 0).is_empty())


func _test_sync_roundtrip() -> void:
	print("-- sync: CodeEdit write-back --")
	var ce := CodeEdit.new()
	ce.text = FIXTURE
	var sec := Resolver.resolve_at_line(ce.text, 2)
	_check("section for sync", not sec.is_empty())
	var shapes: Array = (sec.get("shapes", []) as Array).duplicate(true)
	var pts: PackedVector2Array = shapes[0].get("points", PackedVector2Array()).duplicate()
	pts[0] = Vector2(8, 8)
	shapes[0]["points"] = pts
	_check("apply_shapes ok", Sync.apply_shapes(ce, sec, shapes))
	_check("not guarded after apply", not Sync.is_sync_guarded(ce))
	var line2 := ce.get_line(sec["data_start_line"])
	_check("row0 starts with LINE", line2.begins_with("Data LINE"))
	_check("row0 has 8", ", 8," in line2 or ", 8 " in line2)
	ce.free()


func _test_native_highlight() -> void:
	print("-- native line backgrounds --")
	var ce := CodeEdit.new()
	ce.text = FIXTURE
	var painted := Highlight.paint_native_lines(ce, FIXTURE, 2)
	_check("painted vector lines", painted.size() >= 3)
	var c := ce.get_line_background_color(2)
	_check("line 2 has tint", c.a > 0.01)
	Highlight.clear_native_lines(ce, painted)
	_check("cleared line 2", ce.get_line_background_color(2).a < 0.01)
	ce.free()


func _test_enumerate_blocks() -> void:
	print("-- enumerate_blocks --")
	var blocks := Resolver.enumerate_blocks(FIXTURE)
	_check("one vector block", blocks.size() == 1)
	if blocks.size() == 1:
		_check("label line 0", blocks[0].get("label_line", -1) == 0)


func _test_sync_add_shape() -> void:
	print("-- sync: insert shape row --")
	var ce := CodeEdit.new()
	ce.text = FIXTURE
	var sec := Resolver.resolve_at_line(ce.text, 2)
	var shapes: Array = (sec.get("shapes", []) as Array).duplicate(true)
	shapes.append({
		"type": "LINE",
		"points": PackedVector2Array([Vector2(0, 0), Vector2(16, 16)]),
		"stroke_r": 255, "stroke_g": 0, "stroke_b": 0, "stroke_a": 255, "stroke_w": 1.0,
	})
	_check("add shape ok", Sync.apply_shapes(ce, sec, shapes))
	var sec2 := Resolver.resolve_at_line(ce.text, 2)
	_check("three shapes after add", (sec2.get("shapes", []) as Array).size() == 3)
	ce.free()


func _test_pod_capsule_tokens() -> void:
	print("-- resolver: PodCapsuleVector stroke widths --")
	var sec := Resolver.resolve_at_line(POD_FIXTURE, 2)
	_check("pod resolves", not sec.is_empty())
	var shapes: Array = sec.get("shapes", [])
	_check("pod four shapes", shapes.size() == 4)
	if shapes.size() >= 4:
		_check("pod hull filled", is_equal_approx(float(shapes[0].get("stroke_w", 1.0)), 0.0))
		_check("pod cockpit filled", is_equal_approx(float(shapes[2].get("stroke_w", 1.0)), 0.0))
		_check("pod thrust stroke 2", is_equal_approx(float(shapes[3].get("stroke_w", 0.0)), 2.0))


func _test_skiff_wide_block() -> void:
	print("-- resolver: wide SkiffVector block --")
	var sec := Resolver.resolve_at_line(SKIFF_FIXTURE, 2)
	_check("skiff resolves", not sec.is_empty())
	_check("skiff 72x28", sec.get("view_w", 0) == 72 and sec.get("view_h", 0) == 28)
	var shapes: Array = sec.get("shapes", [])
	_check("skiff four shapes", shapes.size() == 4)
	if shapes.size() >= 2:
		_check("skiff hull rects", str(shapes[0].get("type", "")).to_upper() == "RECT")
		_check("skiff fill rects", float(shapes[0].get("stroke_w", 1.0)) == 0.0)


func _test_canvas_refit_on_resize() -> void:
	print("-- canvas: refit wide block after resize --")
	var sec := Resolver.resolve_at_line(SKIFF_FIXTURE, 2)
	var shapes: Array = sec.get("shapes", [])
	var canvas: Control = CanvasScript.new()
	canvas.size = Vector2(1200, 800)
	canvas.set_model(int(sec.get("view_w", 72)), int(sec.get("view_h", 28)), int(sec.get("grid_step", 2)), shapes)
	canvas._refit_if_auto()
	var big_zoom: float = canvas.debug_fit_state().get("zoom", 0.0)
	canvas.size = Vector2(240, 160)
	canvas._on_resized()
	var state: Dictionary = canvas.debug_fit_state()
	var zoom: float = state.get("zoom", 0.0)
	var doc_size: Vector2 = state.get("doc_size", Vector2.ZERO)
	_check("canvas shrinks zoom after resize", zoom < big_zoom)
	_check("canvas zoom sane for rail", zoom >= 1.5 and zoom <= 4.5)
	_check("canvas doc fits width", doc_size.x <= 240.0 + 1.0)
	_check("canvas doc fits height", doc_size.y <= 160.0 + 1.0)
	canvas.free()


func _test_vgv_roundtrip() -> void:
	print("-- vgv parse/serialize --")
	var model := Vgv.parse_text(VGV_SAMPLE)
	_check("vgv parsed", not model.is_empty())
	_check("vgv view 64", model.get("view_w", 0) == 64)
	var shapes: Array = model.get("shapes", [])
	_check("vgv two shapes", shapes.size() == 2)
	var poly_pts: PackedVector2Array = shapes[1].get("points", PackedVector2Array())
	_check("vgv polyline 3 pts", poly_pts.size() == 3)
	var text := Vgv.serialize(model)
	_check("vgv reserializes", text.begins_with("VGV1"))
	var model2 := Vgv.parse_text(text)
	_check("vgv roundtrip shapes", (model2.get("shapes", []) as Array).size() == 2)


func _check(label: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % label)
	else:
		_failed += 1
		print("  [FAIL] %s" % label)


func _finish() -> void:
	print("")
	print("=== Results: %d passed, %d failed ===" % [_passed, _failed])
	print("RESULTS: %d/%d passed, %d failed" % [_passed, _passed + _failed, _failed])
	quit(1 if _failed > 0 else 0)
