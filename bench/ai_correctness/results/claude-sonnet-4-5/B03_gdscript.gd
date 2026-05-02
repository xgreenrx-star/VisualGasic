extends SceneTree

func _init():
    var int_from_string = int("42")
    var string_from_number = str(99)
    print("Integer from string: ", int_from_string)
    print("String from number: ", string_from_number)
    quit()