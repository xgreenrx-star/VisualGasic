extends SceneTree

func _init():
    var num_str = "42"
    var int_num = int(num_str)
    var str_num = str(99)
    
    print("Integer from string: ", int_num)
    print("String from number: ", str_num)
    
    quit()