extends SceneTree

func _init():
    var arr = [64, 25, 12, 22, 11]
    arr.sort()
    for i in range(arr.size()):
        print(arr[i])
    quit()