Attribute VB_Name = "BoolTest"

Sub Main()
    Print "Testing Boolean Logic"
    
    Dim A
    Dim B
    A = 10
    B = 20
    
    If A < B And B > 15 Then
        Print "A < B And B > 15 : TRUE"
    Else
        Print "A < B And B > 15 : FALSE"
    End If
    
    If A > B Or B > 15 Then
        Print "A > B Or B > 15 : TRUE"
    Else
        Print "A > B Or B > 15 : FALSE"
    End If
    
    If Not (A > B) Then
        Print "Not (A > B) : TRUE"
    Else
        Print "Not (A > B) : FALSE"
    End If
    
    Print "Done"
End Sub
