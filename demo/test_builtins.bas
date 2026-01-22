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

    ' Vector helpers tests (assign first to avoid nested call evaluation issues)
    Set a = Vector3(1,2,3)
    Set b = Vector3(2,3,4)
    Print "VADD_X:" & VAdd(a, b).x
    Print "VDOT:" & VDot(a, b)
    Set c = VCross(a, b)
    Print "VCROSS_X:" & c.x
    Print "VCROSS_Y:" & c.y
    Print "VCROSS_Z:" & c.z
    Set d = Vector3(0,3,4)
    Print "VLEN:" & VLen(d)

    ' AddChild / SetProp smoke test
    Set n = CreateNode("Node2D")
    SetProp n, "position", Vector2(10,20)
    AddChild n
    Print "ADDCHILD_POS_X:" & n.position.x

    ' Compositor smoke tests
    Set comp = CompositorCreate()
    Print "COMPOSITOR_CREATED"
    Set eff = CompositorEffectCreate()
    Print "EFFECT_CREATED"
    Call CompositorSetEffects(comp, Array(eff))
    Call CompositorEffectSetEnabled(eff, 1)
    Print "EFFECT_ENABLED"

    ' Free compositor resources to avoid RID leaks
    Call CompositorEffectFree(eff)
    Print "EFFECT_FREED"
    Call CompositorFree(comp)
    Print "COMPOSITOR_FREED"

    Print "BUILTINS_DONE"
End Sub
