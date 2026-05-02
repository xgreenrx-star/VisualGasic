extends SceneTree

func _init():
    var text = "  Hello, World!  "
    var result = text.strip_edges().to_upper()
    print(result)
    quit()