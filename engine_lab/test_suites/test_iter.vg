Sub IterTest()
    Dim arr(2) As Integer
    arr(0) = 10
    arr(1) = 20
    arr(2) = 30
    

    Print "Iterating numbers:"
    For Each x In arr
        Print x
    Next

    Dim d As Dictionary
    Set d = New Dictionary
    d("A") = "Alice"
    d("B") = "Bob"
    
    Print "Dictionary check:"
    Print "d('A') = "
    Print d("A")
    
    Print "Iterating Dictionary Keys (Not fully supported yet but array-like?):"
    ' ...
End Sub

Sub WithTest()
    Print "Starting WithTest"
    Dim d As Dictionary
    Set d = New Dictionary
    
    With d
        .Name = "Gasic"
        .Type = "Language"
        Print "Inside With:"
        Print "  .Name = "
        Print .Name
        Print "  d('Name') = "
        Print d("Name")
    End With
    
    Print "After With:"
    Print "  d('Name') = "
    Print d("Name")
End Sub
