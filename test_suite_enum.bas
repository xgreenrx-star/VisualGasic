Sub Main()
    Print "Testing Enum and Var"
    
    Enum GameState
        Menu = 0
        Playing = 1
        Paused = 2
        GameOver = 3
    End Enum
    
    Print "Enum Menu: " & Menu
    Print "Enum Playing: " & Playing
    
    Dim e As Variant
    State = Playing
    
    If State = Playing Then
        Print "State is Playing"
    End If
    
    Var x = 100
    Print "Var x: " & x
    
    Print "Test Complete"
End Sub
