Attribute VB_Name = "Test_Math"

Sub Main()
    Dim ok As Boolean
    ok = True

    If Abs(-5) <> 5 Then ok = False
    If Int(3.7) <> 3 Then ok = False
    If Round(3.6) <> 4 Then ok = False
    If Sin(0) <> 0 Then ok = False

    If ok Then
        Print "TEST_OK:02_math"
    Else
        Print "TEST_FAIL:02_math"
    End If
End Sub
