' Test Constants
Const PI = 3.14159
Const APP_NAME = "VisualGasic Demo"

Sub Main()
    Print "=== Const Test ==="
    Print "App: " & APP_NAME
    Print "PI: "
    Print PI
    
    ' Local Const (Actually treated as code execution in current parser)
    ' The parser allows instructions in Sub. 
    ' But Const inside Sub is parsed as ConstStatement?
    ' The parse_statement calls parse_const -> returns STMT_CONST.
    ' instance executes STMT_CONST -> stores variable.
    Const LOCAL_VAL = 100
    Print "Local Const: " & LOCAL_VAL
    
    Print "=== Const Test Complete ==="
End Sub
