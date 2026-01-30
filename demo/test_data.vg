Sub Main()
    Print "Testing Data/Read..."
    
    Dim a As Integer
    Dim b As String
    Dim c As Integer
    
    Read a
    Read b
    Read c
    
    If a <> 10 Then 
        Print "Error: a should be 10, got " & a
    End If
    If b <> "Hello" Then 
        Print "Error: b should be Hello, got " & b
    End If
    If c <> 20 Then 
        Print "Error: c should be 20, got " & c
    End If
    
    Print "Values Read: " & a & ", " & b & ", " & c
    
    ' Test Restore
    Restore
    Read a
    If a <> 10 Then 
        Print "Error: Restore failed, expected 10 got " & a
    End If
    Print "Restore Main OK"
    
    ' Test Labeled Restore
    Restore OtherData
    Dim x As Integer
    Dim y As Integer
    
    Read x
    Read y
    
    If x <> 100 Then 
        Print "Error: Labeled Restore failed, expected 100 got " & x
    End If
    If y <> 200 Then 
        Print "Error: Labeled Restore failed, expected 200 got " & y
    End If
    
    Print "Labeled Restore OK"
    
    ' Test Complex Types
    Restore ComplexData
    Dim v As Vector2
    Read v
    Print "Read Vector: " & v 
    If v.x <> 1 Or v.y <> 2 Then
       Print "Error: Vector read failed"
    End If
    
    Print "All Data Tests Passed"
End Sub

Data 10, "Hello", 20

OtherData:
Data 100, 200

ComplexData:
Data Vector2(1, 2)
