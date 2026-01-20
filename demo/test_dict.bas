Sub _Process(delta)
    If Godot.Input.IsActionPressed("ui_accept") Then
        Print "Jump Detected!"
    End If
End Sub

Sub CheckDict()
    Dim d As Dictionary
    Set d = New Dictionary
    d("Test") = 123
    Print "Dict val: "
    Print d("Test")
End Sub
