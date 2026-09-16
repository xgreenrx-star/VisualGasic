Attribute VB_Name = "PongTest"

Public BallY As Single
Public Speed As Single

Sub Main()
    BallY = 100.0
    Speed = 50.0
    
    Print "Start BallY: " & Str(BallY)
    
    Dim i As Integer
    For i = 1 To 5
        UpdateBall 0.1
        Print "Frame " & Str(i) & " BallY: " & Str(BallY)
    Next
End Sub

Sub UpdateBall(dt)
    BallY = BallY + Speed * dt
End Sub
