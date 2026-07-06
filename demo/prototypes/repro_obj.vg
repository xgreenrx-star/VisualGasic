Global Ball
Global VelY

Sub _Ready()
    Set Ball = CreateNode("ColorRect")
    AddChild(Ball)
    Ball.Top = 590.0
    VelY = 500.0
    Print "INIT Top=" & Str(Ball.Top) & " Vy=" & Str(VelY)
End Sub

Sub _Process(delta)
    Print "Frame START: Top=" & Str(Ball.Top) & " Vy=" & Str(VelY)
    
    Ball.Top = Ball.Top + (VelY * delta)
    Print "  Moved to: " & Str(Ball.Top)
    
    If Ball.Top > 600.0 Then
        Ball.Top = 600.0
        If VelY > 0 Then VelY = -VelY
        Print "  Hit Bottom! Flipped Vy=" & Str(VelY)
    End If
    
    Print "Frame END: Top=" & Str(Ball.Top)
End Sub
