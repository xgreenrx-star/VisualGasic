extends Node
# ===========================================================================
# Bug #2 regression — unhandled runtime errors must not corrupt app state.
#
# When an event Sub raises an unhandled error mid-execution, the VisualGasic
# signal dispatcher now fires a synthetic _OnError(subName, msg, num, line)
# callback so the form can reset state (the "WorkerBusy stuck" bug). The error
# is also logged to the Output panel via printerr().
#
# This drives a VG fixture through ScriptInstance::call() — the same dispatch
# path a real button click takes (call() Site: generic dispatch) — and verifies
# that _OnError fired and reset the stuck state with accurate error context.
#
# Staged + run by tests/run_gd_tests.sh (expects a "RESULTS: X/Y ..." line).
# ===========================================================================

var total := 0
var passed := 0
var failed := 0
var fail_details: Array = []

func _ready() -> void:
	print("============================================================")
	print("BUG #2 — UNHANDLED ERROR RECOVERY (_OnError dispatch)")
	print("============================================================")
	await run_all()
	print("\n============================================================")
	print("RESULTS: %d/%d passed, %d failed" % [passed, total, failed])
	if fail_details.size() > 0:
		print("\nFAILURES:")
		for d in fail_details:
			print("  x " + d)
	print("============================================================")
	get_tree().quit()

func check(cond: bool, label: String) -> void:
	total += 1
	if cond:
		passed += 1
		print("  ok  " + label)
	else:
		failed += 1
		fail_details.append(label)
		print("  X   " + label)

func run_all() -> void:
	var vg_script = load("res://_gd_fixtures/onerror_recovery.vg")
	check(vg_script != null, "fixture onerror_recovery.vg loaded")
	if vg_script == null:
		return

	var node := Node.new()
	node.name = "WorkerForm"
	node.set_script(vg_script)
	add_child(node)
	# Let _Ready run (initializes the flags).
	await get_tree().process_frame

	# Sanity: clean initial state.
	check(bool(node.call("GetWorkerBusy")) == false, "initial WorkerBusy is False")
	check(bool(node.call("GetRecovered")) == false, "initial Recovered is False")

	# Fire the event Sub through the dispatcher. StartWork sets WorkerBusy=True
	# then raises an unhandled error before reaching its own cleanup line.
	node.call("StartWork")

	# The Sub must have aborted before its cleanup line — this proves the error
	# was genuinely unhandled mid-execution (the bug scenario that would leave
	# WorkerBusy stuck True without a recovery hook).
	check(bool(node.call("GetCleanupRan")) == false, "StartWork aborted before cleanup line")

	# The fix: _OnError fired and reset the stuck state.
	check(bool(node.call("GetRecovered")) == true, "_OnError callback fired")
	check(bool(node.call("GetWorkerBusy")) == false, "WorkerBusy reset by _OnError (no stuck state)")

	# The dispatcher passed accurate error context to _OnError.
	check(String(node.call("GetLastErrSub")) == "StartWork", "_OnError received originating Sub name")
	check(int(node.call("GetLastErrNum")) == 51, "_OnError received error number 51")
	check(String(node.call("GetLastErrMsg")).findn("device") != -1, "_OnError received error message text")

	node.queue_free()
