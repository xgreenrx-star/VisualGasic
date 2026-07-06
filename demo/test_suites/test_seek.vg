Sub Main()
    Open "user://seektest.txt" For Output As #1
    Print #1, "Line1"
    Print #1, "Line2"
    Close #1
    
    Dim s As String
    Open "user://seektest.txt" For Input As #1
    
    ' Read first line
    Line Input #1, s
    Print "1: " & s
    
    ' Read second line
    Line Input #1, s
    Print "2: " & s
    
    ' Seek back to start (0)
    Seek #1, 0
    Line Input #1, s
    Print "3 (Should be Line1): " & s
    
    If s <> "Line1" Then
       Print "Error: Seek to 0 failed"
    End If
    
    ' Seek to specific byte? "Line1" + newline roughly 6 bytes? 
    ' Depends on OS (\n vs \r\n). Linux is \n. 
    ' Expect "Line1\n" -> 6 chars.
    
    Seek #1, 6
    Line Input #1, s
    Print "4 (Should be Line2): " & s
    
    Close #1
    Print "Seek Test OK"
End Sub
