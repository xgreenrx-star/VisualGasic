extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + what)

func _run() -> void:
	var nav_script = load("res://addons/visual_gasic/code_navigator.gd")
	var nav = nav_script.new()
	var text := "\n".repeat(70)
	text += "Whenever Section UnlockExit crystals Becomes 6 OnUnlockExit\nSub OnUnlockExit()\nEnd Sub\n"
	nav.set_evidence_recording_override(true)
	nav.set_evidence_source(text, 71, "res://inline.vg")
	nav.set_evidence_run({}, "none")
	check(nav.evidence_header_text().begins_with("UnlockExit"), "header names UnlockExit, got " + nav.evidence_header_text())
	check(nav.evidence_banner_text().contains("No run yet."), "no run yet")
	for status in nav.evidence_row_statuses():
		check(str(status) != "observed", "empty run row is not observed, got " + str(status))
	nav.set_evidence_recording_override(false)
	check(nav.evidence_banner_text().contains("Recording off. Enable vg/evidence/runtime_ring and run the game."), "recording off")
	nav.set_evidence_recording_override(true)
	var hash := _hash(text)
	var stale := {
		"schema": "behavior-run/1",
		"run_id": "run-stale",
		"recording": true,
		"dropped": 0,
		"capacity": 512,
		"scripts": [{"path": "res://inline.vg", "content_hash": "edited"}],
		"events": [],
		"watch": [],
	}
	nav.set_evidence_run(stale, "ended")
	check(nav.evidence_banner_text().contains("Source changed since this run (stale)."), "stale banner")
	check(nav.evidence_header_text().contains("stale"), "stale header")
	var dropped := {
		"schema": "behavior-run/1",
		"run_id": "run-dropped",
		"recording": true,
		"dropped": 4,
		"capacity": 64,
		"scripts": [{"path": "res://inline.vg", "content_hash": hash}],
		"events": [],
		"watch": [],
	}
	nav.set_evidence_run(dropped, "running")
	check(nav.evidence_banner_text().contains("Events dropped (4). Raise vg/evidence/runtime_ring_capacity."), "dropped banner, got " + nav.evidence_banner_text())
	nav.set_evidence_source(text, 1, "res://inline.vg")
	check(nav.evidence_prompt_text() == "Put the caret on a Whenever Section line.", "caret prompt")
	nav.free()
	if failures == 0:
		print("EVIDENCE PANEL: %d passed" % checks)
		quit(0)
	else:
		print("EVIDENCE PANEL: %d failed / %d" % [failures, checks])
		quit(1)

func _hash(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()
