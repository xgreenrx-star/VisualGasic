Sub Main()
    Print "=== Advanced Loops Demo ==="
    
    ' 1. For Each Array
    Print "Iterating Array:"
    Dim ers(3) As Array
    numbers(0) = 1
    numbers(1) = 2
    numbers(2) = 4
    numbers(3) = 8
    

    For Each n In numbers
        Print "Val: " & n
    Next
    
    ' 2. Dictionary and With
    Print "Dictionary With Block:"
    Dim d As Dictionary
    Set d = New Dictionary
    
    With d
        .Name = "VisualGasic"
        .Version = 1.0
        .Type = "Language"
        Print "Inside With: " & .Name
    End With
    
    Print "Outside With Check:"
    Print "Name: " & d("Name")
    Print "Version: " & d("Version")
    Print "Type: " & d("Type")
    
    Print "Demo Complete."
End Sub
