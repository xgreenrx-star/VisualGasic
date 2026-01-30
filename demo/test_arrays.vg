Attribute VB_Name = "ArrayTest"

Sub Main()
    Print "Testing Arrays"
    

    
    A(0) = 10
    A(1) = 20
    A(5) = 50
    
    Print "A(0) should be 10:"
    Print A(0)
    
    Print "A(1) should be 20:"
    Print A(1)
    
    Print "A(5) should be 50:"
    Print A(5)
    
    Print "Looping Array:"

    Sum = 0
    For i = 0 To 5
        ' Use > 0 to filter out nulls/empty
        If A(i) > 0 Then
            Sum = Sum + A(i)
        End If
    Next
    
    Print "Sum of Array (10+20+50=80):"
    Print Sum
    
    Print "Done"
End Sub
