extends SceneTree

## Minimal test: vg_ai_patch_spec parsing + edit application.
##
## Run:
##   ./Godot_v4.6.1-stable_linux.x86_64 --headless --script tests/test_vg_patch_spec.gd

func _init() -> void:
	var Patch = load("res://addons/visual_gasic/vg_ai_patch_spec.gd")
	assert(Patch != null, "vg_ai_patch_spec.gd failed to load")
	var ps = Patch.new()
	var resp := """Some prose.
```vg-patch-spec
{"edits":[
  {"path":"res://Form1.vg","op":"replace","find":"Hello","with":"Hi"},
  {"path":"res://Form1.vg","op":"insert_after","anchor":"Option Explicit","text":"' added by patch"},
  {"path":"res://Form1.vg","op":"insert_before","anchor":"End Sub","text":"    MsgBox \\"bye\\""},
  {"path":"res://Form1.vg","op":"append","text":"Sub New_Click()\\nEnd Sub"}
]}
```
"""
	var spec: Dictionary = ps.extract_spec(resp)
	assert(not spec.is_empty(), "extract_spec returned empty")
	print("✓ extract_spec found block (%d edits)" % spec["edits"].size())

	var src := "' Form1\nOption Explicit\n\nSub Form_Load()\n    Hello.Text = \"Hello\"\nEnd Sub\n"
	var got: Dictionary = ps._apply_edits_to_text(src, spec["edits"])
	var out: String = got["text"]
	var errs: Array = got["errors"]
	assert(errs.is_empty(), "unexpected errors: %s" % str(errs))
	# count defaults to 1 → only the first `Hello` becomes `Hi`.
	assert(out.find("Hi.Text = \"Hello\"") != -1, "replace did not run on first occurrence")
	assert(out.find("' added by patch") != -1, "insert_after missed")
	assert(out.find("    MsgBox \"bye\"") != -1, "insert_before missed")
	assert(out.find("Sub New_Click()") != -1, "append missed")
	print("✓ replace, insert_after, insert_before, append all applied")

	# describe
	assert(ps.describe(spec) == "4 edit(s)", "describe wrong: %s" % ps.describe(spec))
	print("✓ describe()")

	# missing anchor → recorded as error, other edits still apply
	var bad := [
		{"path":"res://X.vg","op":"insert_after","anchor":"NOT THERE","text":"x"},
		{"path":"res://X.vg","op":"append","text":"tail\n"},
	]
	var bres: Dictionary = ps._apply_edits_to_text("body\n", bad)
	assert(bres["errors"].size() == 1, "expected 1 anchor error")
	assert(str(bres["text"]).ends_with("tail\n"), "append did not run after error")
	print("✓ failure isolated, later edits still apply")

	print("[PASS] test_vg_patch_spec.gd")
	quit(0)
