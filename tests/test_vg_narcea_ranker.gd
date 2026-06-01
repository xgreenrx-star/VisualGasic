extends SceneTree

## Smoke test for vg_ai_narcea._rank_examples_by_hint.

func _init() -> void:
	var N = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	assert(N != null, "narcea.gd failed to load")
	var n = N.new()
	var entries := [
		{"path":"tutorials/camera_tutorial.vg", "title":"Camera and viewport"},
		{"path":"tutorials/timer_tutorial.vg",  "title":"Timer events"},
		{"path":"corpus/01_basics/hello.vg",    "title":"Hello world"},
		{"path":"demos/Pong/pong.vg",           "title":"Pong paddle game"},
		{"path":"demos/Snake/snake.vg",         "title":"Snake game grid"},
	]
	var ranked: Array = n._rank_examples_by_hint(entries, "how do I move a paddle in pong game", 3)
	assert(ranked.size() >= 1, "expected at least 1 ranked entry")
	assert(ranked[0]["path"].find("pong") != -1, "pong should rank first, got: %s" % ranked[0]["path"])
	print("✓ pong ranked first for paddle/pong query")

	var camera: Array = n._rank_examples_by_hint(entries, "I need a camera that follows the player", 1)
	assert(camera[0]["path"].find("camera") != -1, "camera should win, got: %s" % camera[0]["path"])
	print("✓ camera ranked first for camera query")

	# No matches → falls back to slice
	var none: Array = n._rank_examples_by_hint(entries, "xyzzy frobnicate", 2)
	assert(none.size() == 2, "fallback must return first 2 entries")
	print("✓ fallback slice when no matches")

	# Token extraction skips words <3 chars
	var toks: Array = n._tokenise("a big cat in the box")
	assert("big" in toks and "cat" in toks and "the" in toks and "box" in toks)
	assert(not ("a" in toks) and not ("in" in toks))
	print("✓ _tokenise filters <3-char words")

	# set_query_hint stores value
	n.set_query_hint("hello world")
	assert(n._query_hint == "hello world")
	print("✓ set_query_hint")

	print("[PASS] test_vg_narcea_ranker.gd")
	quit(0)
