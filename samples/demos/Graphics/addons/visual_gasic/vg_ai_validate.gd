@tool
extends RefCounted
class_name VGAiValidate
## Headless Godot editor boot — scrape stderr for parse / script errors.
## Same filters as scripts/ci_smoke.sh.


static func run_smoke_sync(project_path_abs: String) -> Dictionary:
	var godot := OS.get_executable_path()
	if godot.is_empty():
		return {"ok": false, "errors": PackedStringArray(["Godot executable path unknown"]), "summary": ""}

	# Cross-platform: invoke Godot directly (no bash/timeout — those break on Windows).
	var output: Array = []
	var args := PackedStringArray(["--headless", "--quit", "--editor", "--path", project_path_abs])
	OS.execute(godot, args, output, true, false)
	var text := "\n".join(output)
	var errors: PackedStringArray = PackedStringArray()
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty():
			continue
		if not ("Parse Error" in trimmed or "SCRIPT ERROR" in trimmed):
			continue
		if "Binding duplicate" in trimmed or "preset.0.options" in trimmed:
			continue
		errors.append(trimmed)

	var summary := "ok" if errors.is_empty() else "%d error(s)" % errors.size()
	return {"ok": errors.is_empty(), "errors": errors, "summary": summary}
