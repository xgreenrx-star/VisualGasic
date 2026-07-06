extends SceneTree

func _init():
    var lang = VisualGasicLanguage.new()
    var code = FileAccess.get_file_as_string("res://test_full.vg")
    var result = lang._validate(code, "res://test_full.vg", false, true, false, false)
    print("Validate result:", result)
    if result.has("errors"):
        var errs = result["errors"]
        for e in errs:
            print("ERR:", e)
    quit()
