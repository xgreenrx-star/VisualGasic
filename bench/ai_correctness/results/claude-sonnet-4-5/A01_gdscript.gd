extends SceneTree

func _init():
    var array = [3, 1, 4, 1, 5, 9, 2, 6]
    var sum = 0
    
    for num in array:
        sum += num
    
    var average = float(sum) / array.size()
    
    print("Sum: ", sum)
    print("Average: ", average)
    
    quit()