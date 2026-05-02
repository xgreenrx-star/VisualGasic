extends SceneTree

func _init():
    var text = "mississippi"
    var count = 0
    for c in text:
        if c == 's':
            count += 1
    print(count)
    quit()