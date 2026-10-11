extends SceneTree

const ChainScript := preload("res://addons/visual_gasic/vg_causal_chain.gd")

func _init() -> void:
	var chain: RefCounted = ChainScript.new()
	var passed := 0

	passed += _run_fixture(chain, "simple_msgbox", _fixture_simple_msgbox(), func(r: String) -> bool:
		return r.contains("User triggers btnOK.Click") and r.contains("MsgBox")
	)

	passed += _run_fixture(chain, "nested_call", _fixture_nested_call(), func(r: String) -> bool:
		return r.contains("Call ValidateForm()") and r.contains("Returns True")
	)

	passed += _run_fixture(chain, "raise_event", _fixture_raise_event(), func(r: String) -> bool:
		return r.contains("RaiseEvent FormSubmitted") and r.contains("Parent scene")
	)

	passed += _run_fixture(chain, "timer_tick", _fixture_timer_tick(), func(r: String) -> bool:
		return r.contains("User triggers tmrMain.Timer") and r.contains("Call UpdateClock()")
	)

	passed += _run_fixture(chain, "form_load", _fixture_form_load(), func(r: String) -> bool:
		return r.contains("Form.Load") and r.contains("Call InitControls()")
	)

	passed += _run_fixture(chain, "multi_handler", _fixture_multi_handler(), func(r: String) -> bool:
		return r.contains("btnSave.Click") and r.contains("btnCancel.Click")
	)

	passed += _run_fixture(chain, "recursive_call", _fixture_recursive_call(), func(r: String) -> bool:
		return r.contains("Call Walk(3)") and r.contains("Call Walk(level - 1)")
	)

	passed += _run_fixture(chain, "narcea_form", _fixture_narcea_form(), func(r: String) -> bool:
		return r.contains("btnSubmit.Click") and r.contains("MsgBox") and r.contains("Call ValidateEmail()")
	)

	var evidence_passed := 0
	var evidence_total := 0
	for engine in ["ast", "fallback"]:
		var engine_result: Dictionary = _run_evidence_suite(chain, engine)
		evidence_passed += int(engine_result["passed"])
		evidence_total += int(engine_result["total"])
		print("[INFO] evidence/%s %d/%d" % [engine, int(engine_result["passed"]), int(engine_result["total"])])

	if passed == 8 and evidence_passed == evidence_total:
		print("[PASS] test_vg_causal_chain.gd (8/8 legacy fixtures, %d/%d evidence checks)" % [evidence_passed, evidence_total])
		quit(0)
		return
	push_error("test_vg_causal_chain: legacy %d/8, evidence %d/%d" % [passed, evidence_passed, evidence_total])
	quit(1)


func _run_fixture(chain: RefCounted, name: String, source: String, check: Callable) -> int:
	var report: String = chain.generate(source)
	if report.is_empty():
		push_error("Fixture %s: empty report" % name)
		return 0
	if not check.call(report):
		push_error("Fixture %s failed:\n%s" % [name, report])
		return 0
	return 1


func _fixture_simple_msgbox() -> String:
	return """
Sub btnOK_Click()
    MsgBox "Hello"
End Sub
"""


func _fixture_nested_call() -> String:
	return """
Sub btnOK_Click()
    Call ValidateForm()
End Sub

Function ValidateForm() As Boolean
    If txtName.Text = "" Then
        MsgBox "Required"
        ValidateForm = False
        Return
    End If
    ValidateForm = True
End Function
"""


func _fixture_raise_event() -> String:
	return """
Sub btnSubmit_Click()
    RaiseEvent FormSubmitted(data)
End Sub
"""


func _fixture_timer_tick() -> String:
	return """
Sub tmrMain_Timer()
    Call UpdateClock()
End Sub

Sub UpdateClock()
    Print "tick"
End Sub
"""


func _fixture_form_load() -> String:
	return """
Sub Form_Load()
    Call InitControls()
End Sub

Sub InitControls()
    Print "ready"
End Sub
"""


func _fixture_multi_handler() -> String:
	return """
Sub btnSave_Click()
    Call SaveData()
End Sub

Sub btnCancel_Click()
    MsgBox "Cancelled"
End Sub

Sub SaveData()
    Print "saved"
End Sub
"""


func _fixture_recursive_call() -> String:
	return """
Sub btnRun_Click()
    Call Walk(3)
End Sub

Sub Walk(level As Long)
    If level <= 0 Then
        Return
    End If
    Call Walk(level - 1)
End Sub
"""


func _fixture_narcea_form() -> String:
	return """
Sub btnSubmit_Click()
    If Call ValidateEmail() Then
        MsgBox "OK"
    End If
End Sub

Function ValidateEmail() As Boolean
    ValidateEmail = True
End Function
"""


func _run_evidence_suite(chain: RefCounted, engine: String) -> Dictionary:
	var passed := 0
	var total := 0
	var checks: Array[Dictionary] = [
		{"name": "becomes_root", "fn": _check_becomes_root},
		{"name": "multiple_roots", "fn": _check_multiple_roots},
		{"name": "guard_possible", "fn": _check_guard_possible},
		{"name": "playcue_resolution", "fn": _check_playcue_resolution},
		{"name": "missing_targets", "fn": _check_missing_targets},
		{"name": "comments_and_strings", "fn": _check_comments_and_strings},
		{"name": "indent_identity", "fn": _check_indent_identity},
		{"name": "hash_stability", "fn": _check_hash_stability},
		{"name": "depth_and_cycle", "fn": _check_depth_and_cycle},
		{"name": "existing_roots", "fn": _check_existing_roots},
		{"name": "rendered_report", "fn": _check_rendered_report},
		{"name": "case_fold", "fn": _check_case_fold},
		{"name": "multi_callback", "fn": _check_multi_callback},
		{"name": "branch_identity", "fn": _check_branch_identity},
		{"name": "section_root_heading", "fn": _check_section_root_heading},
	]
	for item in checks:
		total += 1
		var detail: String = item["fn"].call(chain, engine)
		if detail.is_empty():
			passed += 1
		else:
			push_error("evidence/%s/%s: %s" % [engine, item["name"], detail])
	return {"passed": passed, "total": total}


func _analyze(chain: RefCounted, source: String, engine: String, roots: Array = [], source_path: String = "") -> Dictionary:
	return chain.analyze(source, roots, source_path, engine)


func _fail_engine(ev: Dictionary, engine: String) -> String:
	if str(ev.get("engine", "")) == "unavailable":
		return "path unavailable: %s" % str(ev.get("limitations", []))
	if str(ev.get("engine", "")) != engine:
		return "engine %s != %s" % [str(ev.get("engine", "")), engine]
	if not bool(ev.get("ok", false)):
		return "analysis not ok: %s" % str(ev.get("errors", ev.get("limitations", "")))
	if int(ev.get("schema_version", 0)) != 1 or int(ev.get("line_base", 0)) != 1:
		return "schema/line_base mismatch"
	var source: Dictionary = ev.get("source", {})
	if str(source.get("kind", "")) != "memory" or str(source.get("identity", "")) != "":
		return "in-memory snippet claimed a path: %s" % str(source)
	if str(source.get("content_hash", "")).is_empty():
		return "missing content hash"
	var limits := PackedStringArray(ev.get("limitations", PackedStringArray()))
	var joined := "\n".join(limits)
	if engine == "fallback" and not joined.contains("not equivalent"):
		return "fallback did not disclose that it is not AST-complete"
	if engine == "ast" and joined.contains("not equivalent"):
		return "AST result described itself as the fallback"
	if not joined.contains("possible behavior"):
		return "missing possible-behavior limitation"
	return ""


func _line_of(source: String, needle: String) -> int:
	var lines := source.split("\n")
	for i in lines.size():
		if lines[i].contains(needle):
			return i + 1
	return -1


func _root_named(ev: Dictionary, section: String) -> Dictionary:
	for root in ev.get("roots", []):
		if str(root.get("kind", "")) == "whenever" and str(root.get("section", "")) == section:
			return root
	return {}


func _steps_for(ev: Dictionary, root_index: int) -> Array:
	var found: Array = []
	for step in ev.get("steps", []):
		if int(step.get("root_index", -1)) == root_index:
			found.append(step)
	return found


func _root_index(ev: Dictionary, section: String) -> int:
	var roots: Array = ev.get("roots", [])
	for i in roots.size():
		var root: Dictionary = roots[i]
		if str(root.get("kind", "")) == "whenever" and str(root.get("section", "")) == section:
			return i
	return -1


func _find_step(steps: Array, kind: String, text_part: String) -> Dictionary:
	for step in steps:
		if str(step.get("kind", "")) == kind and str(step.get("text", "")).contains(text_part):
			return step
	return {}


func _child_of(steps: Array, parent_id: String, kind: String) -> Dictionary:
	for step in steps:
		if str(step.get("parent_id", "")) == parent_id and str(step.get("kind", "")) == kind:
			return step
	return {}


func _unlock_source() -> String:
	return """Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlockExit

Sub OnUnlockExit()
	If gameState <> "playing" Or exitOpen Then Exit Sub
	exitOpen = True
	Call PlayCue(SFX_UNLOCK)
End Sub

Sub PlayCue(cue As Integer)
	soundRenderer.PlayCue(cue)
End Sub
"""


func _check_becomes_root(chain: RefCounted, engine: String) -> String:
	var source := _unlock_source()
	var ev := _analyze(chain, source, engine)
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var root := _root_named(ev, "UnlockExit")
	if root.is_empty():
		return "missing UnlockExit root"
	if str(root.get("variable", "")) != "crystals":
		return "variable %s" % str(root.get("variable", ""))
	if str(root.get("condition", "")) != "Becomes GEM_TARGET":
		return "condition %s" % str(root.get("condition", ""))
	if str(root.get("handler", "")) != "OnUnlockExit":
		return "handler %s" % str(root.get("handler", ""))
	if int(root.get("line", 0)) != _line_of(source, "Whenever Section UnlockExit"):
		return "declaration line %s" % str(root.get("line", 0))
	if not bool(root.get("location_known", false)):
		return "declaration location unknown"
	var write := _find_step(_steps_for(ev, _root_index(ev, "UnlockExit")), "state_write", "exitOpen = True")
	if write.is_empty():
		return "missing exitOpen write"
	if int(write.get("line", 0)) != _line_of(source, "exitOpen = True"):
		return "write line %s" % str(write.get("line", 0))
	if not bool(write.get("location_known", false)):
		return "write location unknown"
	if not PackedStringArray(write.get("risks", PackedStringArray())).has("state write"):
		return "write missing state-write risk"
	return ""


func _check_multiple_roots(chain: RefCounted, engine: String) -> String:
	var source := """Whenever Section First crystals Changes OnFirst
Whenever Section Second health Below 11 OnSecond

Sub OnFirst()
	gemText = "one"
End Sub

Sub OnSecond()
	lowTime = True
End Sub
"""
	var ev := _analyze(chain, source, engine)
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var roots: Array = ev.get("roots", [])
	if roots.size() != 2:
		return "root count %d" % roots.size()
	if str(roots[0].get("section", "")) != "First" or str(roots[1].get("section", "")) != "Second":
		return "root order %s then %s" % [str(roots[0].get("section", "")), str(roots[1].get("section", ""))]
	var second_steps := _steps_for(ev, 1)
	for step in _steps_for(ev, 0):
		for other in second_steps:
			if str(step.get("id", "")) == str(other.get("parent_id", "")):
				return "second root nested under first"
	if str(roots[1].get("condition", "")) != "Below 11":
		return "second condition %s" % str(roots[1].get("condition", ""))
	return ""


func _check_guard_possible(chain: RefCounted, engine: String) -> String:
	var source := _unlock_source()
	var ev := _analyze(chain, source, engine)
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var steps := _steps_for(ev, _root_index(ev, "UnlockExit"))
	var guard := _find_step(steps, "guard", "exitOpen")
	if guard.is_empty():
		return "missing guard"
	if bool(guard.get("unconditional", true)) or not bool(guard.get("possible", false)):
		return "guard presented as unconditional"
	if not PackedStringArray(guard.get("risks", PackedStringArray())).has("early-return guard"):
		return "guard risk missing"
	var exit_step := _child_of(steps, str(guard.get("id", "")), "exit")
	if exit_step.is_empty():
		return "Exit Sub is not inside the guard"
	if bool(exit_step.get("unconditional", true)):
		return "Exit Sub presented as unconditional"
	var write := _find_step(steps, "state_write", "exitOpen = True")
	if write.is_empty():
		return "missing write"
	if str(write.get("parent_id", "")) == str(exit_step.get("id", "x")):
		return "write nested under Exit Sub"
	if bool(write.get("unconditional", true)):
		return "write presented as unconditional output"
	return ""


func _check_playcue_resolution(chain: RefCounted, engine: String) -> String:
	var source := _unlock_source()
	var ev := _analyze(chain, source, engine)
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var steps := _steps_for(ev, _root_index(ev, "UnlockExit"))
	var local_call := _find_step(steps, "call", "PlayCue(SFX_UNLOCK)")
	if local_call.is_empty():
		return "missing local PlayCue call"
	if str(local_call.get("resolution", "")) != "resolved" or not bool(local_call.get("target_known", false)):
		return "local PlayCue not resolved"
	if int(local_call.get("line", 0)) != _line_of(source, "Call PlayCue"):
		return "PlayCue call-site line %s" % str(local_call.get("line", 0))
	if int(local_call.get("target_line", 0)) != _line_of(source, "Sub PlayCue"):
		return "PlayCue target line %s" % str(local_call.get("target_line", 0))
	var external := _child_of(steps, str(local_call.get("id", "")), "call")
	if external.is_empty() or not str(external.get("text", "")).contains("soundRenderer.PlayCue"):
		return "missing object call under PlayCue"
	if str(external.get("resolution", "")) != "unresolved" or bool(external.get("target_known", true)):
		return "object call was treated as resolved"
	if int(external.get("target_line", -1)) != 0:
		return "invented target location for object call"
	if int(external.get("line", 0)) != _line_of(source, "soundRenderer.PlayCue"):
		return "object call-site line %s" % str(external.get("line", 0))
	var risks := PackedStringArray(external.get("risks", PackedStringArray()))
	if not risks.has("unresolved target") or not risks.has("external effect"):
		return "object call risks %s" % str(risks)
	return ""


func _check_missing_targets(chain: RefCounted, engine: String) -> String:
	var source := """Whenever Section MissingHandler crystals Becomes GEM_TARGET OnMissing
Whenever Section MissingCall crystals Changes OnPresent

Sub OnPresent()
	Call NoSuch()
End Sub
"""
	var ev := _analyze(chain, source, engine)
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var root := _root_named(ev, "MissingHandler")
	if str(root.get("handler_resolution", "")) != "unresolved" or int(root.get("handler_line", -1)) != 0:
		return "missing handler was resolved"
	var handler_steps := _steps_for(ev, _root_index(ev, "MissingHandler"))
	var handler_step := _find_step(handler_steps, "call", "OnMissing")
	if handler_step.is_empty():
		return "missing handler has no call-site step"
	if int(handler_step.get("line", 0)) != _line_of(source, "Whenever Section MissingHandler"):
		return "handler call site line %s" % str(handler_step.get("line", 0))
	if bool(handler_step.get("target_known", true)) or str(handler_step.get("resolution", "")) != "unresolved":
		return "handler target was invented"
	var local_missing := _find_step(_steps_for(ev, _root_index(ev, "MissingCall")), "call", "NoSuch")
	if local_missing.is_empty():
		return "missing local call omitted"
	if int(local_missing.get("line", 0)) != _line_of(source, "Call NoSuch"):
		return "NoSuch call site line %s" % str(local_missing.get("line", 0))
	if bool(local_missing.get("target_known", true)) or str(local_missing.get("resolution", "")) != "unresolved":
		return "NoSuch target invented"
	return ""


func _check_comments_and_strings(chain: RefCounted, engine: String) -> String:
	var source := """' Whenever Section Fake crystals Becomes 1 OnFake
Sub Show()
	Print "Whenever Section Quoted crystals Becomes 2 OnQuoted"
End Sub
Whenever Section Real crystals Becomes GEM_TARGET OnReal

Sub OnReal()
	exitOpen = True
End Sub
"""
	var ev := _analyze(chain, source, engine)
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var whenever_roots := 0
	for root in ev.get("roots", []):
		if str(root.get("kind", "")) != "whenever":
			continue
		whenever_roots += 1
		if str(root.get("section", "")) != "Real":
			return "false root %s" % str(root.get("section", ""))
	if whenever_roots != 1:
		return "whenever root count %d" % whenever_roots
	return ""


func _relation(ev: Dictionary) -> Array:
	var rows: Array = []
	var roots: Array = ev.get("roots", [])
	for i in roots.size():
		var root: Dictionary = roots[i]
		if str(root.get("kind", "")) != "whenever":
			continue
		var calls: Array = []
		var writes: Array = []
		for step in _steps_for(ev, i):
			if str(step.get("kind", "")) == "state_write":
				writes.append(str(step.get("text", "")))
			elif str(step.get("kind", "")) == "call":
				calls.append("%s:%s" % [str(step.get("text", "")), str(step.get("resolution", ""))])
		rows.append({
			"section": str(root.get("section", "")),
			"variable": str(root.get("variable", "")),
			"condition": str(root.get("condition", "")),
			"handler": str(root.get("handler", "")),
			"writes": writes,
			"calls": calls,
		})
	return rows


func _check_indent_identity(chain: RefCounted, engine: String) -> String:
	var compact := "Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlockExit\nSub OnUnlockExit()\nexitOpen = True\nCall PlayCue(SFX_UNLOCK)\nEnd Sub\nSub PlayCue(cue As Integer)\nsoundRenderer.PlayCue(cue)\nEnd Sub\n"
	var indented := "Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlockExit\nSub OnUnlockExit()\n\texitOpen = True\n\tCall PlayCue(SFX_UNLOCK)\nEnd Sub\nSub PlayCue(cue As Integer)\n\tsoundRenderer.PlayCue(cue)\nEnd Sub\n"
	var left := _analyze(chain, compact, engine)
	var right := _analyze(chain, indented, engine)
	var bad := _fail_engine(left, engine)
	if bad.is_empty():
		bad = _fail_engine(right, engine)
	if not bad.is_empty():
		return bad
	if _relation(left) != _relation(right):
		return "indentation changed relationships"
	if str(left["source"]["content_hash"]) == str(right["source"]["content_hash"]):
		return "different indentation produced one hash"
	if int(_find_step(_steps_for(left, 0), "state_write", "exitOpen").get("line", 0)) != _line_of(compact, "exitOpen"):
		return "compact write line"
	if int(_find_step(_steps_for(right, 0), "state_write", "exitOpen").get("line", 0)) != _line_of(indented, "exitOpen"):
		return "indented write line"
	return ""


func _check_hash_stability(chain: RefCounted, engine: String) -> String:
	var source := _unlock_source()
	var first := _analyze(chain, source, engine, [], "res://examples/Unlock.vg")
	var second := _analyze(chain, source, engine, [], "res://examples/Unlock.vg")
	if str(first.get("engine", "")) != engine or not bool(first.get("ok", false)):
		return _fail_engine(first, engine) if str(first.get("source", {}).get("kind", "")) == "memory" else "path analysis failed"
	if str(first["source"]["kind"]) != "path" or str(first["source"]["identity"]) != "res://examples/Unlock.vg":
		return "path identity %s" % str(first.get("source", {}))
	if str(first["source"]["content_hash"]) != str(second["source"]["content_hash"]):
		return "hash changed without a source change"
	if _relation(first) != _relation(second):
		return "steps changed without a source change"
	var changed := source.replace("GEM_TARGET", "GEM_TARGET_NEXT")
	var third := _analyze(chain, changed, engine)
	if str(third["source"]["content_hash"]) == str(first["source"]["content_hash"]):
		return "edited source kept the old hash"
	if str(_root_named(third, "UnlockExit").get("condition", "")) == "Becomes GEM_TARGET":
		return "edited source kept the old condition"
	return ""


func _check_depth_and_cycle(chain: RefCounted, engine: String) -> String:
	var cycle := """Whenever Section CycleWatch crystals Changes OnCycle
Sub OnCycle()
	Call OnCycle()
End Sub
"""
	var cycle_ev := _analyze(chain, cycle, engine)
	var bad := _fail_engine(cycle_ev, engine)
	if not bad.is_empty():
		return bad
	if not bool(cycle_ev.get("truncated", false)):
		return "cycle did not report truncation"
	var cycle_limits := "\n".join(PackedStringArray(cycle_ev.get("limitations", PackedStringArray())))
	if not cycle_limits.contains("truncat"):
		return "cycle limitation missing"
	var chain_src := "Whenever Section Deep crystals Changes OnDeep\nSub OnDeep()\n\tCall S1()\nEnd Sub\n"
	for i in range(1, 25):
		chain_src += "Sub S%d()\n\tCall S%d()\nEnd Sub\n" % [i, i + 1]
	chain_src += "Sub S25()\n\texitOpen = True\nEnd Sub\n"
	var deep := _analyze(chain, chain_src, engine)
	bad = _fail_engine(deep, engine)
	if not bad.is_empty():
		return bad
	if not bool(deep.get("truncated", false)):
		return "depth chain did not report truncation"
	var saw_limit := false
	for step in deep.get("steps", []):
		if str(step.get("kind", "")) == "limit":
			saw_limit = true
			if bool(step.get("location_known", false)) or int(step.get("line", -1)) != 0:
				return "limit step invented a source location"
	if not saw_limit:
		return "depth chain has no limit step"
	if not str(cycle_ev.get("report", "")).contains("truncat"):
		return "analyze report missing cycle limit"
	if not str(deep.get("report", "")).contains("MAX_DEPTH"):
		return "analyze report missing depth limit"
	if not chain.generate(cycle).contains("truncat"):
		return "generate() missing cycle limit"
	if not chain.generate(chain_src).contains("MAX_DEPTH"):
		return "generate() missing depth limit"
	if engine == "ast" and str(deep.get("report", "")) != chain.generate(chain_src):
		return "generate() diverges from the AST report"
	return ""


func _check_existing_roots(chain: RefCounted, engine: String) -> String:
	var selected := _analyze(chain, _fixture_simple_msgbox(), engine, ["btnOK_Click"])
	var bad := _fail_engine(selected, engine)
	if not bad.is_empty():
		return bad
	var roots: Array = selected.get("roots", [])
	if roots.size() != 1 or str(roots[0].get("kind", "")) != "event" or str(roots[0].get("name", "")) != "btnOK_Click":
		return "selected roots %s" % str(roots)
	if not str(selected.get("report", "")).contains("User triggers btnOK.Click"):
		return "selected report lost the event text"
	var multi := _analyze(chain, _fixture_multi_handler(), engine)
	bad = _fail_engine(multi, engine)
	if not bad.is_empty():
		return bad
	var names: Array = []
	for root in multi.get("roots", []):
		if str(root.get("kind", "")) == "event":
			names.append(str(root.get("name", "")))
	if not names.has("btnSave_Click") or not names.has("btnCancel_Click"):
		return "event roots %s" % str(names)
	if not str(multi.get("report", "")).contains("btnSave.Click") or not str(multi.get("report", "")).contains("btnCancel.Click"):
		return "multi report changed"
	return ""


func _check_rendered_report(chain: RefCounted, engine: String) -> String:
	var source := _unlock_source()
	var ev := _analyze(chain, source, engine)
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var guard_line := _line_of(source, "Then Exit Sub")
	var write_line := _line_of(source, "exitOpen = True")
	var play_line := _line_of(source, "Sub PlayCue")
	var report := str(ev.get("report", ""))
	var public_report: String = chain.generate(source)
	if engine == "ast" and report != public_report:
		return "generate() diverges from analyze()"
	for text in [report, public_report]:
		if not text.contains("Whenever UnlockExit line %d:" % _line_of(source, "Whenever Section UnlockExit")):
			return "missing Whenever source line"
		if not text.contains("Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlockExit"):
			return "declaration spelling dropped"
		if not text.contains("L%d guard " % guard_line):
			return "guard location missing"
		if not text.contains("L%d state_write exitOpen = True" % write_line):
			return "write location missing"
		if not text.contains("Call PlayCue(SFX_UNLOCK) [resolved PlayCue line %d]" % play_line):
			return "resolved call missing"
		if not text.contains("soundRenderer.PlayCue(cue) [unresolved]"):
			return "unresolved call missing"
		if not text.contains("Limits:") or not text.contains("possible behavior"):
			return "limits missing from the Whenever report"
	return ""


func _check_case_fold(chain: RefCounted, engine: String) -> String:
	var source := """whenever section unlockexit crystals becomes GEM_TARGET onunlockexit
sub OnUnlockExit()
	call playcue(SFX_UNLOCK)
end sub
sub PlayCue(cue As Integer)
	soundRenderer.PlayCue(cue)
end sub
sub btnOK_Click()
	MsgBox "Hello"
end sub
"""
	var ev := _analyze(chain, source, engine, ["UNLOCKEXIT"])
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var root := _root_named(ev, "unlockexit")
	if root.is_empty():
		return "lowercase section was not selected"
	if str(root.get("section", "")) != "unlockexit":
		return "section spelling rewritten: %s" % str(root.get("section", ""))
	var declaration := str(root.get("declaration", ""))
	if not declaration.contains("whenever") or not declaration.contains("becomes") or not declaration.contains("onunlockexit"):
		return "declaration lost source spelling: %s" % declaration
	if str(root.get("condition", "")).to_lower() != "becomes gem_target":
		return "condition %s" % str(root.get("condition", ""))
	if str(root.get("condition", "")).to_lower().contains("onunlockexit"):
		return "callback contaminated the condition"
	var handlers: Array = root.get("handlers", [])
	if handlers.size() != 1 or str(handlers[0].get("name", "")) != "onunlockexit":
		return "handler spelling %s" % str(handlers)
	if str(handlers[0].get("target_name", "")) != "OnUnlockExit" or str(handlers[0].get("resolution", "")) != "resolved":
		return "procedure spelling %s" % str(handlers[0])
	var call := _find_step(_steps_for(ev, _root_index(ev, "unlockexit")), "call", "playcue")
	if call.is_empty() or str(call.get("target_name", "")) != "PlayCue" or not bool(call.get("target_known", false)):
		return "call resolution %s" % str(call)
	if not str(call.get("text", "")).contains("playcue"):
		return "call site spelling rewritten"
	var rendered := str(ev.get("whenever_text", ""))
	if not rendered.contains("unlockexit") or not rendered.contains("becomes") or not rendered.contains("OnUnlockExit") or not rendered.contains("PlayCue"):
		return "rendered report lost spellings: %s" % rendered
	var selected := _analyze(chain, source, engine, ["btnok_click"])
	bad = _fail_engine(selected, engine)
	if not bad.is_empty():
		return bad
	if str(selected.get("roots", [{}])[0].get("name", "")) != "btnOK_Click":
		return "event root spelling %s" % str(selected.get("roots", []))
	if not str(selected.get("report", "")).contains("User triggers btnOK.Click"):
		return "event report lost original spelling"
	if not chain.generate(source, ["btnok_click"]).contains("User triggers btnOK.Click"):
		return "generate() lost original spelling"
	if not chain.generate(source, ["unlockexit"]).contains("onunlockexit") or not chain.generate(source, ["unlockexit"]).contains("OnUnlockExit"):
		return "generate() lost Whenever spelling"
	return ""


func _check_multi_callback(chain: RefCounted, engine: String) -> String:
	var source := """Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlock, OnAlso, OnMissing
Whenever Section Band crystals Between 1 And 9 OnLow, OnHigh
Whenever Section Watch crystals Changes OnFirst, OnSecond
Sub OnUnlock()
	exitOpen = True
End Sub
Sub OnAlso()
	exitOpen = False
End Sub
Sub OnLow()
End Sub
Sub OnHigh()
End Sub
Sub OnFirst()
End Sub
Sub OnSecond()
End Sub
"""
	var ev := _analyze(chain, source, engine)
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var unlock := _root_named(ev, "UnlockExit")
	if str(unlock.get("condition", "")) != "Becomes GEM_TARGET":
		return "Becomes condition %s" % str(unlock.get("condition", ""))
	var names := _handler_names(unlock)
	if names != ["OnUnlock", "OnAlso", "OnMissing"]:
		return "Becomes handlers %s" % str(names)
	var steps := _steps_for(ev, _root_index(ev, "UnlockExit"))
	if _find_step(steps, "state_write", "exitOpen = True").is_empty() or _find_step(steps, "state_write", "exitOpen = False").is_empty():
		return "a callback body was dropped"
	var missing := _find_step(steps, "call", "OnMissing")
	if missing.is_empty() or bool(missing.get("target_known", true)):
		return "unresolved callback dropped"
	var band := _root_named(ev, "Band")
	if str(band.get("condition", "")) != "Between 1 And 9":
		return "Between condition %s" % str(band.get("condition", ""))
	if _handler_names(band) != ["OnLow", "OnHigh"]:
		return "Between handlers %s" % str(_handler_names(band))
	var watch := _root_named(ev, "Watch")
	if str(watch.get("condition", "")) != "Changes":
		return "Changes condition %s" % str(watch.get("condition", ""))
	if _handler_names(watch) != ["OnFirst", "OnSecond"]:
		return "Changes handlers %s" % str(_handler_names(watch))
	for text in [str(ev.get("report", "")), chain.generate(source)]:
		if not text.contains("OnAlso [resolved") or not text.contains("OnMissing [unresolved]") or not text.contains("OnHigh [resolved") or not text.contains("OnSecond [resolved"):
			return "report dropped a callback"
	return ""


func _handler_names(root: Dictionary) -> Array:
	var names: Array = []
	for handler in root.get("handlers", []):
		names.append(str(handler.get("name", "")))
	return names


func _check_branch_identity(chain: RefCounted, engine: String) -> String:
	var source := """Whenever Section Branch crystals Becomes READY OnBranch
Sub OnBranch()
	If ready Then
		exitOpen = True
	Else
		exitOpen = False
	End If
	kept = 1
	For i = 1 To 3
		missed = 1
	Next
End Sub
"""
	var ev := _analyze(chain, source, engine)
	var bad := _fail_engine(ev, engine)
	if not bad.is_empty():
		return bad
	var steps := _steps_for(ev, _root_index(ev, "Branch"))
	var public_report: String = chain.generate(source)
	if engine == "ast":
		var guard := _find_step(steps, "guard", "ready")
		if guard.is_empty():
			return "missing guard"
		var opened := _child_of(steps, str(guard["id"]), "state_write")
		var then_write := {}
		var else_write := {}
		for step in steps:
			if str(step.get("parent_id", "")) != str(guard["id"]):
				continue
			if str(step.get("text", "")).contains("exitOpen = True"):
				then_write = step
			elif str(step.get("text", "")).contains("exitOpen = False"):
				else_write = step
		if then_write.is_empty() or str(then_write.get("branch", "")) != "then":
			return "Then branch %s" % str(then_write)
		if else_write.is_empty() or str(else_write.get("branch", "")) != "else":
			return "Else branch %s" % str(else_write)
		if _find_step(steps, "state_write", "kept = 1").is_empty():
			return "statement after End If was dropped"
		if not _find_step(steps, "state_write", "missed").is_empty():
			return "For body was presented as a chain write"
		if str(ev.get("report", "")) != public_report:
			return "generate() diverges from analyze()"
		if not public_report.contains("then state_write exitOpen = True") or not public_report.contains("else state_write exitOpen = False"):
			return "generate() lost branch identity"
		if not opened.is_empty() and str(opened.get("branch", "")).is_empty():
			return "branch child lost its identity"
	else:
		if _find_step(steps, "gap", "not expanded").is_empty():
			return "fallback did not report the control-flow gap"
		if not _find_step(steps, "state_write", "exitOpen").is_empty() or not _find_step(steps, "state_write", "missed").is_empty():
			return "fallback presented a detached write as the chain"
		if _find_step(steps, "state_write", "kept = 1").is_empty():
			return "fallback dropped the statement outside the block"
		var rendered := str(ev.get("whenever_text", ""))
		if not rendered.contains("not expanded") or rendered.contains("exitOpen = True") or rendered.contains("missed"):
			return "fallback Whenever report hid the gap: %s" % rendered
		if not str(ev.get("report", "")).contains("not expanded"):
			return "analyze report hid the gap"
		if not public_report.contains("then state_write exitOpen = True") or not public_report.contains("else state_write exitOpen = False"):
			return "generate() lost branch identity"
	return ""


func _check_section_root_heading(chain: RefCounted, engine: String) -> String:
	var source := """Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlockExit
Sub OnUnlockExit()
	exitOpen = True
End Sub
Sub btnOK_Click()
	MsgBox "Hello"
End Sub
"""
	var section := _analyze(chain, source, engine, ["unlockexit"])
	var bad := _fail_engine(section, engine)
	if not bad.is_empty():
		return bad
	var section_report := str(section.get("report", ""))
	var section_public: String = chain.generate(source, ["unlockexit"])
	if section_report.contains("Entry:"):
		return "section root invented an Entry heading: %s" % section_report
	if not section_report.contains("Whenever UnlockExit line "):
		return "section root lost the watcher report"
	var section_roots: Array = section.get("roots", [])
	if section_roots.size() != 1 or str(section_roots[0].get("kind", "")) != "whenever":
		return "section selection roots %s" % str(section_roots)
	if engine == "ast" and section_report != section_public:
		return "generate() diverges from the section report"
	if section_public.contains("Entry:"):
		return "generate() invented an Entry heading for a Whenever section"
	if not section_public.contains("Whenever UnlockExit line "):
		return "generate() lost the watcher report"
	var proc := _analyze(chain, source, engine, ["OnUnlockExit"])
	bad = _fail_engine(proc, engine)
	if not bad.is_empty():
		return bad
	if not str(proc.get("report", "")).contains("Entry: OnUnlockExit"):
		return "procedure heading lost: %s" % str(proc.get("report", ""))
	if not chain.generate(source, ["OnUnlockExit"]).contains("Entry: OnUnlockExit"):
		return "generate() lost the procedure heading"
	var event := _analyze(chain, source, engine, ["btnOK_Click"])
	bad = _fail_engine(event, engine)
	if not bad.is_empty():
		return bad
	if not str(event.get("report", "")).contains("User triggers btnOK.Click"):
		return "event heading lost"
	if str(event.get("report", "")).contains("Entry:"):
		return "event root gained a synthetic Entry heading"
	var mixed := _analyze(chain, source, engine, ["UnlockExit", "btnOK_Click"])
	bad = _fail_engine(mixed, engine)
	if not bad.is_empty():
		return bad
	var mixed_report := str(mixed.get("report", ""))
	if mixed_report.contains("Entry:"):
		return "mixed selection kept a synthetic Entry heading: %s" % mixed_report
	if not mixed_report.contains("User triggers btnOK.Click") or not mixed_report.contains("Whenever UnlockExit line "):
		return "mixed selection lost a real heading: %s" % mixed_report
	var mixed_public: String = chain.generate(source, ["UnlockExit", "btnOK_Click"])
	if mixed_public.contains("Entry:") or not mixed_public.contains("User triggers btnOK.Click"):
		return "generate() mixed headings: %s" % mixed_public
	return ""
