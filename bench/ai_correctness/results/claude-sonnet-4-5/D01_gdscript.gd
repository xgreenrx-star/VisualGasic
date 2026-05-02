extends SceneTree

func _init():
    var items = {"apple": 0.5, "bread": 2.25, "cheese": 5.99}
    
    for key in items:
        print(key, ": ", items[key])
    
    var total = 0.0
    for value in items.values():
        total += value
    
    print("Total: ", total)
    
    quit()