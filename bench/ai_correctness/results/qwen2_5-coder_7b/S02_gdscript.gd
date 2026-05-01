extends SceneTree

func _init():
    var trimmed_string = "  Hello, World!  ".strip_edges()
    var uppercased_string = trimmed_string.uppercase()
    print(uppercased_string)
    quit()