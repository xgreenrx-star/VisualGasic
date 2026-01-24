@tool
extends EditorScript

# Simple in-editor parser integration checks that exercise the VisualGasic loader
# Run this from the Editor: Project -> Run -> Run Custom Script and pick this file.

func _run():
    var tests = [
        "res://visualgasic/third_person_controller.bas",
        "res://visualgasic/first_person_controller.bas",
    ]

    for path in tests:
        print("Running parser test on: ", path)
        var res = ResourceLoader.load(path)
        if not res:
            print("FAILED: could not load resource: ", path)
        else:
            print("Loaded: ", path, " type=", typeof(res), " -> ", res)

    print('Parser integration tests finished.')
