extends SceneTree

func _init():
    # Check if ClassDB can find FileAccess enum constants
    var has_read = ClassDB.class_has_integer_constant("FileAccess", "READ")
    var has_write = ClassDB.class_has_integer_constant("FileAccess", "WRITE")
    var has_rw = ClassDB.class_has_integer_constant("FileAccess", "READ_WRITE")
    var has_wr = ClassDB.class_has_integer_constant("FileAccess", "WRITE_READ")
    
    print("FileAccess.READ: has=", has_read)
    print("FileAccess.WRITE: has=", has_write)
    print("FileAccess.READ_WRITE: has=", has_rw)
    print("FileAccess.WRITE_READ: has=", has_wr)
    
    if has_read:
        print("  READ value=", ClassDB.class_get_integer_constant("FileAccess", "READ"))
    if has_write:
        print("  WRITE value=", ClassDB.class_get_integer_constant("FileAccess", "WRITE"))
    if has_rw:
        print("  READ_WRITE value=", ClassDB.class_get_integer_constant("FileAccess", "READ_WRITE"))
    if has_wr:
        print("  WRITE_READ value=", ClassDB.class_get_integer_constant("FileAccess", "WRITE_READ"))
    quit(0)
