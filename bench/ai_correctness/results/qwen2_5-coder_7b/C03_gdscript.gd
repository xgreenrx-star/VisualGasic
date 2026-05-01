extends SceneTree

func _init():
    var sum = 0
    for i in range(1, 101):
        sum += i
    print(sum)
    quit()