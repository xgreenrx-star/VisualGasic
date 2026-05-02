extends SceneTree

func _init():
    var file = FileAccess.open("output.txt", FileAccess.WRITE)
    file.store_line("Line 1")
    file.store_line("Line 2")
    file.store_line("Line 3")
    file.close()
    
    file = FileAccess.open("output.txt", FileAccess.READ)
    var line_number = 1
    while not file.eof_reached():
        var line = file.get_line()
        if line != "":
            print(str(line_number) + ": " + line)
            line_number += 1
    file.close()
    
    quit()