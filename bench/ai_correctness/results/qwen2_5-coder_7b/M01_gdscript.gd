extends SceneTree

func _init():
    var a = 0
    var b = 1
    for i in range(10):
        print(a)
        var temp = a + b
        a = b
        b = temp
    quit()