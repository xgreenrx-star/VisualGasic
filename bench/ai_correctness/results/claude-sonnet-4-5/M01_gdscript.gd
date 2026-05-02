extends SceneTree

func _init():
    var a = 0
    var b = 1
    print(a)
    print(b)
    for i in range(8):
        var next = a + b
        print(next)
        a = b
        b = next
    quit()