Sub Main()
    // removed malformed Dim lines introduced by autofix
    
    If a > b Then
        Print "FAILURE: " & a & " > " & b & " is True!"
    Else
        Print "SUCCESS: " & a & " > " & b & " is False."
    End If
End Sub
