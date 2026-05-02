extends SceneTree

class Point:
    var x
    var y
    
    func _init(p_x, p_y):
        x = p_x
        y = p_y
    
    func _to_string():
        return "(" + str(x) + ", " + str(y) + ")"

func _init():
    var point = Point.new(3, 4)
    print(point)
    quit()