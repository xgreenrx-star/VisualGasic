Sub Main()
    ' Test Input
    Print "Mouse Pos: " & GetMousePos()
    Print "Global Mouse Pos: " & GetGlobalMousePos()
End Sub

Sub OnDraw()
    ' Test Drawing only if in OnDraw
    DrawLine(Vector2(0,0), Vector2(100,100), Color(1,0,0,1))
    DrawCircle(Vector2(50,50), 20, Color(0,1,0,1))
    DrawRect(Rect2(10,10, 30,30), Color(0,0,1,1), True)
End Sub
