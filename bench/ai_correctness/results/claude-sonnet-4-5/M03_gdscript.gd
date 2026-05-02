extends SceneTree

func _init():
    var x1 = 0
    var y1 = 0
    var x2 = 3
    var y2 = 4
    var distance = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2))
    print(distance)
    quit()