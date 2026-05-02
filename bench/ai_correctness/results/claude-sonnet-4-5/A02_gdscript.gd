extends SceneTree

func _init():
    var array = [-5, 12, 8, -10, 22, 0, 17]
    var maximum = array[0]
    var minimum = array[0]
    
    for value in array:
        if value > maximum:
            maximum = value
        if value < minimum:
            minimum = value
    
    print("Maximum: ", maximum)
    print("Minimum: ", minimum)
    
    quit()