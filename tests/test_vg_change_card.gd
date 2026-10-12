extends SceneTree

## Phase 5: the change card keeps claim, files, static chain, observed run,
## expectations, and rollback in separate sections.
var failures := 0
var checks := 0

const BEFORE := """Whenever Section Keep health Changes OnKeep
Sub OnKeep()
	healthBar = health
End Sub
Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlockExit
Sub OnUnlockExit()
	exitOpen = True
End Sub
Whenever Section Gone a Changes OnGone
Sub OnGone()
End Sub
"""

const AFTER := """Whenever Section Keep health Changes OnKeep
Sub OnKeep()
	healthBar = health
End Sub
Whenever Section UnlockExit crystals Becomes 5 OnOther
Sub OnOther()
	score = 1
End Sub
Whenever Section Added b Changes OnAdded
Sub OnAdded()
End Sub
"""


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + what)


func _sha(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


## Found in the windowed editor: after rollback the card re-read the restored file as "after",
## credited a pre-change run to the change, and took fires from an arbitrary section.
func _check_post_hash_and_fires(Card) -> void:
	var entry := {"op": "write", "path": "res://Caverns.vg", "existed": true, "binary": false,
		"pre_hash": _sha(BEFORE), "post_hash": _sha(AFTER)}
	var change_set := {"id": "card-2", "status": "rolled_back", "entries": [entry], "not_tracked": []}
	var events := [
		{"kind": "whenever_fired", "section": "UnlockExit"},
		{"kind": "watched_write", "variable": "crystals"},
		{"kind": "watched_write", "variable": "exitOpen"},
	]
	var old_run := {"run_id": "run-old", "scripts": [{"path": "res://Caverns.vg", "content_hash": _sha(BEFORE)}], "events": events}
	var rolled: Dictionary = Card.build_card(change_set, {
		"before": {"res://Caverns.vg": BEFORE},
		"after": {},
		"snapshot": old_run,
		"expectations": {"present": false},
		"rollback_state": {"status": "rolled_back", "conflicts": []},
	})
	var rolled_text: String = Card.to_text(rolled)
	check(rolled_text.find("not run since change") >= 0, "a pre-change run is not credited to the change")
	check(rolled_text.find("run-old") < 0, "pre-change run id is not shown as observed")
	check(rolled_text.find("file no longer matches this change") >= 0, "static says the file no longer matches")
	check(rolled_text.find("removed") < 0, "static does not report sections as removed after rollback")
	check(rolled_text.find("line delta") < 0, "no line delta when the file no longer matches")
	var new_run := {"run_id": "run-new", "scripts": [{"path": "res://Caverns.vg", "content_hash": _sha(AFTER)}], "events": events}
	var ran: Dictionary = Card.build_card(change_set, {
		"before": {"res://Caverns.vg": BEFORE},
		"after": {"res://Caverns.vg": AFTER},
		"snapshot": new_run,
		"expectations": {"present": false},
		"rollback_state": {"status": "available", "conflicts": []},
	})
	var ran_text: String = Card.to_text(ran)
	check(ran_text.find("run run-new: fires 1, writes 2, suppressions 0") >= 0, "fires counts whenever_fired events")


func _run() -> void:
	var Card = load("res://addons/visual_gasic/vg_change_card.gd")
	if Card == null:
		push_error("FAIL: vg_change_card.gd is not loaded")
		quit(1)
		return
	var reply := "A" + "b".repeat(598) + "C" + "D".repeat(40)
	var change_set := {
		"id": "card-1",
		"label": "Make code",
		"source": "make_code",
		"status": "frozen",
		"reply": reply,
		"ended_unix": 200,
		"entries": [{
			"op": "write",
			"path": "res://Caverns.vg",
			"existed": true,
			"binary": false,
			"pre_size": BEFORE.to_utf8_buffer().size(),
			"post_size": AFTER.to_utf8_buffer().size(),
		}],
		"not_tracked": [{"path": "res://Form.tscn", "reason": "form designer ResourceSaver"}],
	}
	var inputs := {
		"reply": reply,
		"before": {"res://Caverns.vg": BEFORE},
		"after": {"res://Caverns.vg": AFTER},
		"snapshot": {
			"run_id": "run-9",
			"scripts": [{"path": "res://Caverns.vg", "content_hash": "not-the-after-hash"}],
			"events": [],
		},
		"expectations": {
			"present": true,
			"rows": [
				{"name": "not_yet.gd", "status": "not run", "note": "waiting"},
				{"name": "ok.gd", "status": "pass", "note": "holds"},
				{"name": "bad.gd", "status": "fail", "note": "broke"},
				{"name": "hung.gd", "status": "incomplete", "note": "no result line"},
				{"name": "old.gd", "status": "stale", "note": "ran too early"},
			],
		},
		"rollback_state": {"status": "available", "conflicts": []},
	}
	var card: Dictionary = Card.build_card(change_set, inputs)
	var text: String = Card.to_text(card)
	var claim: Dictionary = card.get("claim", {})
	check(str(claim.get("label", "")) == "Narcea says (not verified)", "claim label")
	check(str(claim.get("source", "")) == "model", "claim source is model")
	check(str(claim.get("text", "")) == reply.substr(0, 600), "claim is the first 600 characters verbatim")
	check(not str(claim.get("text", "")).contains("D"), "claim stops at 600 characters")
	var static_text := text
	check(static_text.find("trigger changed") >= 0, "static reports trigger changed")
	check(static_text.find("GEM_TARGET") >= 0 and static_text.find("5") >= 0, "static shows GEM_TARGET and 5")
	check(static_text.find("callbacks changed") >= 0, "static reports callbacks changed")
	check(static_text.find("writes changed") >= 0, "static reports writes changed")
	check(static_text.find("added") >= 0 and static_text.find("Added") >= 0, "static reports an added section")
	check(static_text.find("removed") >= 0 and static_text.find("Gone") >= 0, "static reports a removed section")
	check(static_text.find("unchanged") >= 0 and static_text.find("Keep") >= 0, "static reports an unchanged section")
	check(static_text.find("not run since change") >= 0, "observed is not run since change")
	check(static_text.find("not run") >= 0, "expectation not run")
	check(static_text.find("pass") >= 0, "expectation pass")
	check(static_text.find("fail") >= 0, "expectation fail")
	check(static_text.find("incomplete") >= 0, "expectation incomplete and rollback incomplete")
	check(static_text.find("stale") >= 0, "expectation stale")
	check(static_text.find("Form.tscn") >= 0, "not tracked file is named")
	check(str(card.get("rollback", {}).get("status", "")) == "incomplete", "not tracked makes rollback incomplete")
	_check_post_hash_and_fires(Card)
	var empty: Dictionary = Card.build_card({"entries": [], "not_tracked": []}, {"expectations": {"present": false}})
	var empty_text: String = Card.to_text(empty)
	check(empty_text.find("No protected expectations in this project.") >= 0, "no-expectations sentence")
	var blob := JSON.stringify(card) + text + JSON.stringify(empty) + empty_text
	check(blob.find("safe") < 0, "card output has no safe substring")
	check(blob.find("success") < 0, "card output has no success substring")
	if failures == 0:
		print("[PASS] test_vg_change_card.gd (%d/%d)" % [checks, checks])
		quit(0)
	else:
		print("[FAIL] test_vg_change_card.gd (%d failures / %d checks)" % [failures, checks])
		quit(1)
