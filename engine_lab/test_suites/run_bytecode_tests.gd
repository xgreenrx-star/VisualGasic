extends SceneTree

func _initialize() -> void:
    var runner := VisualGasicTestRunner.new()
    var summary : Dictionary = runner.run_bytecode_tests()
    var details : Array = summary.get("details", [])
    for detail in details:
        var name : String = String(detail.get("name", "Unnamed Test"))
        var success : bool = detail.get("success", false)
        var status : String = "[FAIL]"
        if success:
            status = "[PASS]"
        print("%s %s" % [status, name])
        var message : String = String(detail.get("message", ""))
        if message.length() > 0:
            print("    %s" % message)
    var passed : int = int(summary.get("passed", 0))
    var total : int = int(summary.get("total", details.size()))
    print("\n%d/%d bytecode tests passed" % [passed, total])
    if passed == total:
        print("✅ Bytecode regression suite passed")
        quit(0)
    else:
        push_error("Bytecode regression suite failed")
        quit(1)
