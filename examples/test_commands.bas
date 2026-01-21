Sub Main()
    Print "Asc(A): " & Asc("A") 
    Print "Chr(65): " & Chr(65)
    Print "Space(5): '" & Space(5) & "'"
    Print "String(3, *): " & String(3, "*")

    Print "Sgn(-10): " & Sgn(-10)
    Print "Sgn(10): " & Sgn(10)
    Print "Sgn(0): " & Sgn(0)
    
    Dim ath As Variant
    Dim path2 As Variant
    f = FreeFile
    path = "user://test_rename_src.txt"
    path2 = "user://test_rename_dst.txt"
    
    On Error Resume Next
    Kill path
    Kill path2
    On Error Goto 0
    
    Open path For Output As #f
    Print #f, "Data"
    Close #f
    
    Name path As path2
    Print "Renamed to dst"
    
    Kill path2
    Print "Killed dst"
    

    Set res = Load("res://test_commands.bas")
    
    ' Comparison with Nothing using =
    If res = Nothing Then
        Print "Load failed"
    Else
        Print "Loaded Resource OK"
    End If
End Sub
