Type Vector2D
    X As Integer
    Y As Integer
End Type

Type Player
    Name As String
    Pos As Vector2D
End Type

Sub Main
    Dim P As Player
    P.Name = "Hero"
    P.Pos.X = 10
    P.Pos.Y = 20
    
    Print "Player: " & P.Name
    Print "Pos: " & P.Pos.X & ", " & P.Pos.Y
    
    Dim V1 As Vector2D
    V1.X = 5
    V1.Y = 5
    
    Print "V1: " & V1.X & "," & V1.Y

    ' Test Array of UDTs
    Dim Party(1) As Player
    Party(0).Name = "A"
    Party(0).Pos.X = 1
    Party(1).Name = "B"
    Party(1).Pos.Y = 2
    
    Print "Party 0: " & Party(0).Name & " X=" & Party(0).Pos.X
    Print "Party 1: " & Party(1).Name & " Y=" & Party(1).Pos.Y

End Sub
