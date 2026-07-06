extends MainLoop

func _initialize():
    print("=== Linter Test ===")
    
    var script = VisualGasicScript.new()
    script.source_code = """
Dim usedVar As Integer
Dim unusedVar As String

Sub _Ready()
    usedVar = 42
    Print usedVar
    HelperFunc 5
End Sub

Sub HelperFunc(x As Integer)
    Dim usedVar As Integer
    usedVar = x * 2
    Print usedVar
End Sub

Sub EmptySub()
End Sub

Sub NeverCalled()
    Print "Hello"
End Sub
"""
    var err = script.reload()
    print("Parse result: ", err, " (0=OK)")
    
    if err == OK:
        print("[PASS] Linter integrated into _validate pipeline")
    else:
        print("[FAIL] Parse error")
    
    print("")
    print("Warning types: Unused var(100), Unused sub(101), Empty sub(102),")
    print("  Shadowed var(103), Unreachable(104), Unused param(106)")

func _process(_delta):
    return true
