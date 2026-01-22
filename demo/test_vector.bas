Sub Main()
    Print "Testing Vector Helpers..."

    Dim a As Vector3 = Vec3(1,2,3)
    Dim b As Vector3 = Vec3(2,3,4)

    Dim sum As Vector3 = VAdd(a,b)
    Dim diff As Vector3 = VSub(b,a)
    Dim dotv As Double = VDot(a,b)
    Dim crossv As Vector3 = VCross(a,b)
    Dim len As Double = VLen(a)
    Dim norm As Vector3 = VNormalize(a)

    Print "a=" & a & " b=" & b
    Print "sum=" & sum
    Print "diff=" & diff
    Print "dot=" & dotv
    Print "cross=" & crossv
    Print "len(a)=" & len
    Print "norm(a)=" & norm

    ' Basic SetProp demo
    Set n = CreateNode("Node2D")
    SetProp n, "position", Vector2(10,20)
    AddChild n
    Print "n.position=" & n.position
End Sub
