Type Vector2D
    x As Single
    y As Single
    label As String
End Type

Type Player
    pos As Vector2D
    score As Integer
End Type

Sub Main()
    Print "Testing Structs..."
    
    Dim p As Player
    p.score = 100
    p.pos.x = 10.5
    p.pos.y = 20.5
    p.pos.label = "Start"
    
    Print "Player Score: " & Str(p.score)
    Print "Player Pos: " & Str(p.pos.x) & "," & Str(p.pos.y)
    Print "Player Label: " & p.pos.label
    
    If p.score = 100 Then
        Print "Struct Member Access: Pass"
    Else
        Print "Struct Member Access: FAIL"
    End If
    
    Print "Testing Select Case..."
    
    Dim val As Integer
    val = 2
    
    Select Case val
        Case 1
            Print "Case 1: FAIL"
        Case 2
            Print "Case 2: Pass"
        Case 3
            Print "Case 3: FAIL"
        Case Else
            Print "Case Else: FAIL"
    End Select
    
    val = 5
    Select Case val
        Case 1
             Print "Case 1: FAIL"
        Case 99
             Print "Case 99: FAIL"
        Case Else
             Print "Case Else: Pass"
    End Select
    
End Sub
