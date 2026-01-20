extends SceneTree

func _init():
    var script = VisualGasicScript.new()
    script.source_code = FileAccess.get_file_as_string("res://test_struct.bas")
    var instance = VisualGasicInstance.new(script, self)
    quit()
