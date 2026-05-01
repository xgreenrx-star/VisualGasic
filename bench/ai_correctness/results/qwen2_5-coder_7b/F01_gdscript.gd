extends SceneTree

func _init():
    var file = File.new()
    if not file.file_exists("user://output.txt"):
        file.open("user://output.txt", File.WRITE)
        file.store_line("Line 1")
        file.store_line("Line 2")
        file.store_line("Line 3")
        file.close()

    file.open("user://output.txt", File.READ)
    var line_number = 1
    while not file.eof_reached():
        print("%d: %s" % [line_number, file.get_line()])
        line_number += 1
    file.close()
    quit()