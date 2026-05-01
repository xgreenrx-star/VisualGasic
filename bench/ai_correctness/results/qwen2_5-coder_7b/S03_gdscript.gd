extends SceneTree

func _init():
    var count = 0
    for char in "mississippi":
        if char == 's':
            count += 1
    print(count)
    quit()