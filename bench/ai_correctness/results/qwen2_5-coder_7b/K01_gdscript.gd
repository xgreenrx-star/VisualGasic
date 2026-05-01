extends SceneTree

func _init():
    var point = Point.new(3, 4)
    print(point.toString())
    quit()

class Point:
    var x: int
    var y: int
    
    func new(x_val: int, y_val: int):
        self.x = x_val
        self.y = y_val
        
    func toString() -> String:
        return "({0}, {1})".format(self.x, self.y)