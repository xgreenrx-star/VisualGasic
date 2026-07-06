Attribute VB_Name = "TestExit"

Sub Main()
    Print "Testing Exit Sub"
    TestExitSub
    Print "Back in Main"

    Print "Testing Exit For"
    Dim i As Integer
    For i = 1 To 10
        Print i
        If i = 3 Then 
            Exit For
        End If
    Next
    Print "Exited For at " & Str(i)

    Print "Testing Exit Do"
    Dim j As Integer
    j = 0
    Do
        j = j + 1
        Print j
        If j = 3 Then 
            Exit Do
        End If
    Loop
    Print "Exited Do at " & Str(j)
End Sub

Sub TestExitSub()
    Print "Inside TestExitSub - Start"
    Exit Sub
    Print "Inside TestExitSub - This should not print"
End Sub
