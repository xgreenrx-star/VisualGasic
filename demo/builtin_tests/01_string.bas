Attribute VB_Name = "Test_String"

Sub Main()
    Dim ok As Boolean
    ok = True

    Dim s As String
    s = Left("hello", 2)
    If s <> "he" Then ok = False

    s = Right("hello", 2)
    If s <> "lo" Then ok = False

    If Len("abc") <> 3 Then ok = False

    If UCase("ab") <> "AB" Then ok = False
    If LCase("AB") <> "ab" Then ok = False

    If Asc("A") <> 65 Then ok = False
    If Chr(65) <> "A" Then ok = False

    If ok Then
        Print "TEST_OK:01_string"
    Else
        Print "TEST_FAIL:01_string"
    End If
End Sub
