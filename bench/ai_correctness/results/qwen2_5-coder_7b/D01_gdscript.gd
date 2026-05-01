extends SceneTree

func _init():
    var prices = {"apple": 0.5, "bread": 2.25, "cheese": 5.99}
    var total = 0.0
    
    for item in prices:
        print("%s: %f" % [item, prices[item]])
        total += prices[item]
    
    print("Total: %f" % total)
    quit()