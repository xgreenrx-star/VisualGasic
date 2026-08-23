@tool
extends SceneTree
## Headless tests for vg_open_path_resolver.gd

const Resolver := preload("res://addons/visual_gasic/vg_open_path_resolver.gd")

const FIXTURE := """Sub LoadScores()
    Open \"user://scores.txt\" For Input As #1
    Line Input #1, line
    Close #1
End Sub

Sub PlaySfx()
    Sound.Play \"res://sfx/jump.wav\"
End Sub
"""


func _initialize() -> void:
	print("=== open_path_resolver headless tests ===")
	var passed := 0
	var failed := 0
	if _test_open_line():
		passed += 1
	else:
		failed += 1
	if _test_sound_line():
		passed += 1
	else:
		failed += 1
	if _test_no_match():
		passed += 1
	else:
		failed += 1
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _test_open_line() -> bool:
	var ref := Resolver.resolve_at_caret(FIXTURE, 1, 12)
	if ref.is_empty():
		print("  [FAIL] open line resolves")
		return false
	if ref.get("path") != "user://scores.txt":
		print("  [FAIL] path")
		return false
	if ref.get("command") != "open":
		print("  [FAIL] command")
		return false
	if ref.get("mode") != "input":
		print("  [FAIL] mode")
		return false
	print("  [PASS] open line")
	return true


func _test_sound_line() -> bool:
	var ref := Resolver.resolve_at_caret(FIXTURE, 7, 24)
	if ref.is_empty() or ref.get("kind") != "audio":
		print("  [FAIL] sound.play audio kind")
		return false
	print("  [PASS] sound.play")
	return true


func _test_no_match() -> bool:
	var ref := Resolver.resolve_at_caret(FIXTURE, 2, 5)
	if not ref.is_empty():
		print("  [FAIL] non-string caret should be empty")
		return false
	print("  [PASS] no false positive")
	return true
