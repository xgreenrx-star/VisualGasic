@tool
extends SceneTree

func _init():
    var bas_path = "res://test_modern.vg"
    print("Regression test: instantiate and free VisualGasicScript")

    if not ClassDB.class_exists("VisualGasicScript"):
        print("VisualGasicScript class MISSING.")
        quit()

    var script = ClassDB.instantiate("VisualGasicScript")
    script.resource_path = bas_path
    print("Created instance:", script)

    # If script exposes a reload method, call it to exercise parsing
    if script.has_method("reload"):
        print("Calling reload() on VisualGasicScript")
        script.reload()

    # Drop reference and quit so teardown runs during shutdown
    script = null
    print("Freed instance (reference dropped)")

    quit()
