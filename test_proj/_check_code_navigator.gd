@tool
extends SceneTree

## Headless test: verify Code Navigator _parse_procedures() correctly extracts
## Sub/Function/Property definitions from a real .vg file (infoview_companion.vg).

const PASS = "[PASS]"
const FAIL = "[FAIL]"

var _failures: int = 0

func _init():
	print("=== Code Navigator headless test ===")

	var nav_script = load("res://addons/visual_gasic/code_navigator.gd")
	if nav_script == null:
		printerr(FAIL + " Could not load code_navigator.gd")
		quit(1)
		return

	var nav = nav_script.new()

	# ------------------------------------------------------------------
	# 1. Read .vg text from disk
	# ------------------------------------------------------------------
	var vg_path := "/home/Commodore/Documents/VisualGasic/local_projects/infoview_companion/infoview_companion.vg"
	if not FileAccess.file_exists(vg_path):
		printerr(FAIL + " infoview_companion.vg not found at: " + vg_path)
		quit(1)
		return

	var text := FileAccess.get_file_as_string(vg_path)
	_assert("vg file non-empty", not text.is_empty())

	# ------------------------------------------------------------------
	# 2. Parse procedures
	# ------------------------------------------------------------------
	var procs: Array = nav._parse_procedures(text)
	print("  Procedures found: ", procs.size())
	for p in procs:
		print("    ", p["kind"].rpad(16), p["name"], "  line=", p["line"])

	_assert("at least 5 procedures found", procs.size() >= 5)

	# ------------------------------------------------------------------
	# 3. Verify specific known procedures exist
	# ------------------------------------------------------------------
	var names_found: Array = []
	for p in procs:
		names_found.append(p["name"].to_lower())

	_assert("_Ready found",    "_ready"    in names_found)
	_assert("cmdBack_Click found", "cmdback_click" in names_found)

	# ------------------------------------------------------------------
	# 4. All entries have required keys
	# ------------------------------------------------------------------
	for p in procs:
		_assert("proc has 'name' key",     p.has("name"))
		_assert("proc has 'kind' key",     p.has("kind"))
		_assert("proc has 'line' key",     p.has("line"))
		_assert("proc name non-empty",     not p["name"].is_empty())
		_assert("proc kind non-empty",     not p["kind"].is_empty())
		_assert("proc line >= 0",          p["line"] >= 0)

	# ------------------------------------------------------------------
	# 5. Kinds are valid
	# ------------------------------------------------------------------
	var valid_kinds := ["Sub", "Function", "Property Get", "Property Let", "Property Set"]
	for p in procs:
		_assert("kind is valid '" + p["kind"] + "'", p["kind"] in valid_kinds)

	# ------------------------------------------------------------------
	# 6. Sorted alphabetically by name
	# ------------------------------------------------------------------
	var sorted_ok := true
	for i in range(1, procs.size()):
		if procs[i - 1]["name"].to_lower() > procs[i]["name"].to_lower():
			sorted_ok = false
			break
	_assert("procedures are sorted alphabetically", sorted_ok)

	# ------------------------------------------------------------------
	# 7. Expected count matches grep count (23 expected)
	# ------------------------------------------------------------------
	_assert("procedure count matches grep (23)", procs.size() == 23)

	# ------------------------------------------------------------------
	# Summary
	# ------------------------------------------------------------------
	print("")
	if _failures == 0:
		print(PASS + " All tests passed.")
		quit(0)
	else:
		print(FAIL + " " + str(_failures) + " test(s) failed.")
		quit(1)


func _assert(label: String, condition: bool) -> void:
	if condition:
		print(PASS + " " + label)
	else:
		printerr(FAIL + " " + label)
		_failures += 1
