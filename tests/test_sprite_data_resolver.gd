@tool
extends SceneTree
## Headless tests: sprite Data resolver, palettes, sync, editor assist.
## Run: scripts/run_sprite_data_tests.sh

const Resolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")
const Palettes := preload("res://addons/visual_gasic/vg_sprite_data_palettes.gd")
const Sync := preload("res://addons/visual_gasic/vg_sprite_data_sync.gd")
const Assist := preload("res://addons/visual_gasic/vg_editor_assist.gd")
const Highlight := preload("res://addons/visual_gasic/vg_sprite_data_highlight.gd")
const Ux := preload("res://addons/visual_gasic/vg_sprite_data_ux.gd")

var _failed := 0
var _passed := 0

const FIXTURE := """PlayerSprite:
Data 4, 4, 0, 0
Data 0, 1, 1, 0
Data 0, 1, 2, 1
Data 0, 0, 1, 0
Data 0, 0, 0, 0

NoteData:
Data \"C4\", 261.63
"""


func _init() -> void:
	print("=== sprite_data headless tests ===")
	print("")
	_test_resolver_hits()
	_test_resolver_rejects()
	_test_resolver_limits()
	_test_resize_header()
	_test_palettes()
	_test_sync_roundtrip()
	_test_grid_alignment()
	_test_indent_and_folds()
	_test_enumerate_blocks()
	_test_native_highlight()
	_test_assist_keyword()
	_finish()


func _test_resolver_hits() -> void:
	print("-- resolver: valid *Sprite block --")
	var sec := Resolver.resolve_at_line(FIXTURE, 2)
	_check("resolves on grid line", not sec.is_empty())
	_check("label PlayerSprite", sec.get("label", "") == "PlayerSprite")
	_check("4x4 dimensions", sec.get("w", 0) == 4 and sec.get("h", 0) == 4)
	_check("header line index", sec.get("header_line", -1) == 1)
	_check("data start line", sec.get("data_start_line", -1) == 2)
	var px: PackedInt32Array = sec.get("pixels", PackedInt32Array())
	_check("16 pixels", px.size() == 16)
	_check("pixel (1,1) == 1", px[5] == 1)
	_check("caret on label line", not Resolver.resolve_at_line(FIXTURE, 0).is_empty())
	_check("caret on header line", not Resolver.resolve_at_line(FIXTURE, 1).is_empty())


func _test_resolver_rejects() -> void:
	print("-- resolver: reject non-sprite --")
	_check("NoteData line empty", Resolver.resolve_at_line(FIXTURE, 7).is_empty())
	_check("NoteData not sprite label", not Resolver.is_sprite_label("NoteData"))
	_check("empty source", Resolver.resolve_at_line("", 0).is_empty())
	_check("negative caret", Resolver.resolve_at_line(FIXTURE, -1).is_empty())


func _test_resolver_limits() -> void:
	print("-- resolver: size limits --")
	var row_parts: PackedStringArray = PackedStringArray()
	for _i in 33:
		row_parts.append("0")
	var big := "BigSprite:\nData 33, 8, 0, 0\nData " + ", ".join(row_parts) + "\n"
	_check("oversized width rejected", Resolver.resolve_at_line(big, 2).is_empty())
	var bad_header := "BadSprite:\nData 4, 4\nData 0,0,0,0\n"
	_check("short header rejected", Resolver.resolve_at_line(bad_header, 2).is_empty())


func _test_resize_header() -> void:
	print("-- resolver: resize header rows --")
	var row12 := "Data " + ", ".join(PackedStringArray(["0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"]))
	var small := "CloudSprite:\nData 12, 6, 0, 0\n"
	for _r in 6:
		small += row12 + "\n"
	var sec6 := Resolver.resolve_at_line(small, 2)
	_check("12x6 resolves", sec6.get("w", 0) == 12 and sec6.get("h", 0) == 6)
	var big := small.replace("Data 12, 6, 0, 0", "Data 12, 12, 0, 0")
	for _r in 6:
		big += row12 + "\n"
	var sec12 := Resolver.resolve_at_line(big, 2)
	_check("12x12 resolves", sec12.get("w", 0) == 12 and sec12.get("h", 0) == 12)
	_check("12x12 has 144 pixels", (sec12.get("pixels", PackedInt32Array()) as PackedInt32Array).size() == 144)
	var incomplete := small.replace("Data 12, 6, 0, 0", "Data 12, 12, 0, 0")
	_check("12x12 needs 12 rows", Resolver.resolve_at_line(incomplete, 2).is_empty())


func _test_palettes() -> void:
	print("-- palettes --")
	_check("NES name id 0", Palettes.palette_name_for_id(0) == "NES")
	_check("16 NES colors", Palettes.colors_for_id(0).size() == 16)
	var c := Palettes.color_for_index(0, 1)
	_check("index 1 is Color", c is Color)
	_check("clamp high palette id", Palettes.palette_name_for_id(99) == "CGA")


func _test_sync_roundtrip() -> void:
	print("-- sync: CodeEdit write-back --")
	var ce := CodeEdit.new()
	ce.text = FIXTURE
	var sec := Resolver.resolve_at_line(ce.text, 3)
	_check("section for sync", not sec.is_empty())
	var px: PackedInt32Array = sec.get("pixels", PackedInt32Array()).duplicate()
	px[0] = 9
	_check("apply_pixels ok", Sync.apply_pixels(ce, sec, px))
	_check("not guarded after apply", not Sync.is_sync_guarded(ce))
	var line2 := ce.get_line(sec["data_start_line"])
	_check("row0 is indented for folding", line2.begins_with("\t"))
	_check("row0 starts with padded 9", line2.strip_edges().begins_with("Data  9"))
	var sec2 := Resolver.resolve_at_line(ce.text, 3)
	var px2: PackedInt32Array = sec2.get("pixels", PackedInt32Array())
	_check("roundtrip pixel 0", px2[0] == 9)
	_check("reject bad pixel count", not Sync.apply_pixels(ce, sec, PackedInt32Array()))
	ce.free()

func _test_grid_alignment() -> void:
	var ce := CodeEdit.new()
	ce.text = FIXTURE.replace("Data 0, 1, 2, 1", "' Keep this note\nData 0, 10, 15, 1")
	var before := ce.text
	var sec := Resolver.resolve_at_line(ce.text, 2)
	var original_pixels: PackedInt32Array = sec["pixels"]
	_check("align grid succeeds", Sync.align_grid(ce, sec))
	_check("single digit values space padded", ce.get_line(2) == "\tData  0,  1,  1,  0")
	_check("mixed digit values align", ce.get_line(4) == "\tData  0, 10, 15,  1")
	_check("header unchanged", ce.get_line(1) == "Data 4, 4, 0, 0")
	_check("comment unchanged", ce.get_line(3) == "' Keep this note")
	_check("other Data block unchanged", ce.text.ends_with('NoteData:\nData "C4", 261.63\n'))
	var after := Resolver.resolve_at_line(ce.text, 2)
	_check("aligned pixels unchanged", after["pixels"] == original_pixels)
	ce.undo()
	_check("align is one undo action", ce.text == before)
	ce.redo()
	var aligned := ce.text
	_check("second alignment succeeds", Sync.align_grid(ce, Resolver.resolve_at_line(ce.text, 2)))
	_check("alignment idempotent", ce.text == aligned)
	_check("painting with intervening comment succeeds", Sync.apply_pixels(ce, Resolver.resolve_at_line(ce.text, 2), original_pixels))
	_check("painting keeps comment intact", ce.get_line(3) == "' Keep this note")
	_check("painting preserves aligned columns", ce.get_line(4) == "\tData  0, 10, 15,  1")
	var rows := Sync.pixel_rows(PackedInt32Array([0, 100, -1, 15]), 2, 2)
	_check("wider fields use spaces without truncation", rows == PackedStringArray(["Data   0, 100", "Data  -1,  15"]))
	var inserted := Sync.insert_new_block(ce, 0, "AddedSprite", 2, 2, 0, 2)
	_check("new sprite pixel rows aligned", inserted["ok"] and ce.get_line(2) == "\tData  0,  0")
	var insert_sec: Dictionary = inserted["section"]
	_check("full editor write aligned", Sync.apply_section(ce, insert_sec, PackedInt32Array([1, 15, 10, 0])) and ce.get_line(2) == "\tData  1, 15")
	ce.free()


func _test_native_highlight() -> void:
	print("-- native line backgrounds --")
	var ce := CodeEdit.new()
	ce.text = FIXTURE
	var painted := Highlight.paint_native_lines(ce, FIXTURE, 2)
	_check("painted sprite lines", painted.size() >= 5)
	var c := ce.get_line_background_color(2)
	_check("line 2 has tint", c.a > 0.01)
	Highlight.clear_native_lines(ce, painted)
	_check("cleared line 2", ce.get_line_background_color(2).a < 0.01)
	ce.free()

func _test_indent_and_folds() -> void:
	var ce := CodeEdit.new()
	ce.line_folding = true
	ce.indent_size = 4
	ce.text = "\t\t" + FIXTURE.replace("\n", "\n\t\t")
	var original := ce.text
	var pixels: PackedInt32Array = Resolver.resolve_at_line(ce.text, 2)["pixels"]
	_check("equal label/row indentation repaired", Ux.migrate_all_indents(ce) == 1)
	_check("label indentation preserved", ce.get_line(0) == "\t\tPlayerSprite:")
	_check("rows deeper than indented label", ce.get_line(1) == "\t\t\tData 4, 4, 0, 0")
	_check("indentation preserves pixel values", Resolver.resolve_at_line(ce.text, 2)["pixels"] == pixels)
	_check("other Data unchanged", ce.get_line(8) == "\t\tData \"C4\", 261.63")
	var repaired := ce.text
	_check("migration idempotent", Ux.migrate_all_indents(ce) == 0 and ce.text == repaired)
	ce.undo()
	_check("indent migration one-step undo", ce.text == original)
	ce.redo()
	ce.set_caret_line(3)
	_check("collapse succeeds from inside data", Ux.set_data_folded(ce, true) == 1)
	_check("collapse moves caret to visible label", ce.get_caret_line() == 0)
	_check("all data folded detected", Ux.all_data_folded(ce))
	_check("expand succeeds", Ux.set_data_folded(ce, false) == 1 and not Ux.all_data_folded(ce))
	_check("fold toggle leaves source unchanged", ce.text == repaired)
	ce.text = FIXTURE.replace("\nData", "\n    Data")
	_check("already foldable spaces stay untouched", Ux.migrate_all_indents(ce) == 0)
	ce.free()


func _test_assist_keyword() -> void:
	print("-- editor assist: keyword at caret --")
	var ce := CodeEdit.new()
	ce.text = "Sub _Draw()\n    DrawRect 0, 0, 10, 10, Color.White\nEnd Sub"
	ce.set_caret_line(1)
	ce.set_caret_column(8)
	_check("DrawRect keyword", Assist.get_keyword_at_cursor(ce) == "DrawRect")
	ce.free()


func _test_enumerate_blocks() -> void:
	print("-- enumerate_blocks --")
	var blocks := Resolver.enumerate_blocks(FIXTURE)
	_check("one sprite block", blocks.size() == 1)
	if blocks.size() == 1:
		_check("label line 0", blocks[0].get("label_line", -1) == 0)
		_check("end line 5", blocks[0].get("end_line", -1) == 5)


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
