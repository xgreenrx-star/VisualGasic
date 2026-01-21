Sub Main()
    Dim f
    f = FreeFile
    Print "FreeFile: " & f
    
    Dim path
    path = "user://temp_test_kill.txt"
    
    Open path For Output As #f
    Print #f, "Content to kill"
    Close #f
    
    Print "File created. Killing it..."
    Kill path
    
    On Error Resume Next
    Open path For Input As #f
    If Err.Number <> 0 Then
        Print "File successfully deleted (Open failed)."
    Else
        Print "File still exists!"
        Close #f
    End If
End Sub
