Attribute VB_Name = "BuiltinTest"

Sub Main()
    Print "BUILTINS_START"
    Dim tmp As String
    Print "LEN:" & Len("hello")
    Print "LEFT:" & Left("hello", 2)
    Print "RIGHT:" & Right("hello", 2)
    Print "MID:" & Mid("hello", 2, 2)
    Print "UCASE:" & UCase("abc")
    Print "LCASE:" & LCase("ABC")
    Print "ASC:" & Asc("A")
    Print "CHR:" & Chr(65)
    Print "SIN0:" & Sin(0)
    Print "ABS:" & Abs(-5)
    Print "INT:" & Int(3.7)
    Print "ROUND:" & Round(3.6)

    ' Vector helpers tests
    Print "VADD_X:" & VAdd(Vec3(1,2,3), Vec3(2,3,4)).x
    Print "VDOT:" & VDot(Vec3(1,2,3), Vec3(2,3,4))
    Print "VCROSS_X:" & VCross(Vec3(1,2,3), Vec3(2,3,4)).x
    Print "VCROSS_Y:" & VCross(Vec3(1,2,3), Vec3(2,3,4)).y
    Print "VCROSS_Z:" & VCross(Vec3(1,2,3), Vec3(2,3,4)).z
    Print "VLEN:" & VLen(Vec3(0,3,4))

    ' AddChild / SetProp smoke test
    Set n = CreateNode("Node2D")
    SetProp n, "position", Vector2(10,20)
    AddChild n
    Print "ADDCHILD_POS_X:" & n.position.x

    Print "BUILTINS_DONE"
End Sub
