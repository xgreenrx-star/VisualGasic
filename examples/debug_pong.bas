Dim y As Single
Dim vy As Single

Sub _Ready()
    y = 595.0
    vy = 500.0
    Print "INIT y=" & Str(y) & " vy=" & Str(vy)
End Sub

Sub _Process(delta)
    Print "Frame BEGIN: y=" & Str(y) & " vy=" & Str(vy)
    y = y + vy * delta
    Print "  Moved: y=" & Str(y)
    
    If y > 600.0 Then
        Print "  HIT BOTTOM CHECK TRUE (" & Str(y) & " > 600)"
        y = 600.0
        vy = -vy
        Print "  FLIPPED: vy=" & Str(vy)
    End If
    
    Print "Frame END: y=" & Str(y)
End Sub
