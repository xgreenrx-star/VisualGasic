extends SceneTree

func _init():
    var arr = [-5, 12, 8, -10, 22, 0, 17]
    var max_val = arr[0]
    var min_val = arr[0]
    
    for num in arr:
        if num > max_val:
            max_val = num
        elif num < min_val:
            min_val = num
    
    print("Max: ", max_val)
    print("Min: ", min_val)
    quit()