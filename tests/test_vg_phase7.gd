extends SceneTree

## Smoke test for Phase 7 additions: vg_ai_test_spec, vg_ai_lesson_spec,
## decode_error, _trim_to_budget, persona memory & pinned files.

func _init() -> void:
	_test_test_spec()
	_test_lesson_spec()
	_test_decode_error()
	_test_trim_to_budget()
	_test_pinned_and_notes()
	print("[PASS] test_vg_phase7.gd")
	quit(0)


func _test_test_spec() -> void:
	var TS = load("res://addons/visual_gasic/vg_ai_test_spec.gd")
	assert(TS != null)
	var ts = TS.new()
	var reply := """blah blah
```vg-test-spec
{"path":"res://test_foo.gd","source":"extends SceneTree\\nfunc _init():\\n\\tprint(\\"[PASS]\\")\\n\\tquit(0)\\n","summary":"foo"}
```
done"""
	var spec: Dictionary = ts.extract_spec(reply)
	assert(not spec.is_empty(), "test-spec not extracted")
	assert(spec.has("tests"), "no tests array")
	assert(spec["tests"].size() == 1, "expected 1 test")
	assert(str(spec["tests"][0]["path"]) == "res://test_foo.gd")
	print("✓ vg_ai_test_spec.extract_spec single")

	var multi := """```vg-test-spec
{"tests":[{"path":"res://a.gd","source":"x"},{"path":"res://b.gd","source":"y"}]}
```"""
	var spec2: Dictionary = ts.extract_spec(multi)
	assert(spec2["tests"].size() == 2)
	assert("2 tests" in ts.describe(spec2))
	print("✓ vg_ai_test_spec.extract_spec multi")

	# Empty / malformed → empty dict.
	assert(ts.extract_spec("nothing here").is_empty())
	assert(ts.extract_spec("```vg-test-spec\nnot json\n```").is_empty())
	print("✓ vg_ai_test_spec rejects garbage")


func _test_lesson_spec() -> void:
	var LS = load("res://addons/visual_gasic/vg_ai_lesson_spec.gd")
	var ls = LS.new()
	var reply := """```vg-lesson-spec
{"title":"Loops","goal":"Learn For","steps":["Do X","Do Y"],"hints":["mind the Next"],"snippet":"For i = 1 To 10\\nNext"}
```"""
	var spec: Dictionary = ls.extract_spec(reply)
	assert(not spec.is_empty())
	assert(str(spec["title"]) == "Loops")
	var bb: String = ls.render_bbcode(spec)
	assert(bb.find("📘 LESSON") != -1)
	assert(bb.find("Do X") != -1)
	assert(bb.find("mind the Next") != -1)
	assert(bb.find("[code]") != -1)
	print("✓ vg_ai_lesson_spec render_bbcode")
	var res: Dictionary = ls.apply(spec, null)
	assert(res["ok"])
	assert(res.has("bbcode"))
	print("✓ vg_ai_lesson_spec.apply returns bbcode")


func _test_decode_error() -> void:
	var N = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	var n = N.new()
	assert(n.has_method("decode_error"))
	var tests := {
		"SCRIPT ERROR: Parse Error: Identifier \"foo\" not declared in the current scope": "declared",
		"Invalid call. Nonexistent function 'bar' on base 'Node'": "doesn't exist",
		"Attempt to call function 'foo' on a null instance": "null",
		"Division By Zero in operator '/'.": "zero",
		"Out of bounds get index 5 (on size 3)": "past the end",
		"Stack overflow.": "recursion",
		"Error opening file 'res://foo.vg'": "path",
		"Some random non-matching line": "",
	}
	for line in tests:
		var got: String = n.decode_error(line)
		var expected_sub: String = tests[line]
		if expected_sub.is_empty():
			assert(got.is_empty(), "expected empty for: %s, got: %s" % [line, got])
		else:
			assert(got.findn(expected_sub) != -1,
				"line: %s\nexpected substring: %s\ngot: %s" % [line, expected_sub, got])
	print("✓ decode_error matches expected lines")


func _test_trim_to_budget() -> void:
	var N = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	var n = N.new()
	# Build a fake tagged list 3 blocks wide.
	var tagged: Array = [
		{"name": "a", "prio": 100, "text": "A".repeat(100)},
		{"name": "b", "prio": 50,  "text": "B".repeat(500)},
		{"name": "c", "prio": 10,  "text": "C".repeat(1000)},
	]
	var kept: Array = n._trim_to_budget(tagged, 700)
	# Total 1600 > 700 → drop lowest prio "c" (1000 chars) → 600 fits.
	assert(kept.size() == 2, "expected 2 kept, got %d" % kept.size())
	assert(kept[0].length() == 100)
	assert(kept[1].length() == 500)
	# When already under budget nothing is dropped.
	var kept2: Array = n._trim_to_budget(tagged, 10000)
	assert(kept2.size() == 3)
	print("✓ _trim_to_budget drops lowest priority first")


func _test_pinned_and_notes() -> void:
	var N = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	var n = N.new()
	# set_pinned_files stores PackedStringArray.
	var p := PackedStringArray()
	p.append("res://does/not/exist.vg")
	n.set_pinned_files(p)
	var block: String = n._pinned_files_block()
	# Missing files are mentioned but don't cause a crash.
	assert(block.find("missing") != -1, "expected 'missing' notice, got: %s" % block)
	print("✓ pinned-files block mentions missing files gracefully")

	# build_context_block returns a non-empty string even with no plugin.
	var ctx: String = n.build_context_block(null)
	assert(not ctx.is_empty())
	assert(ctx.find("Narcea response policy") != -1)
	print("✓ build_context_block produces output without plugin")
