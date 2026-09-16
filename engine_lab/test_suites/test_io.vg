Sub _Ready()
    Print "Testing File I/O..."
    
    Dim path As String
    path = "user://test_io.txt" 
    
    Print "Writing to file..."
    Open path For Output As #1
    Print #1, "Hello File"
    Print #1, "123.456"
    Close #1
    
    Print "Reading from file..."
    Dim s1 As String
    Dim f1 As Single
    
    Open path For Input As #1
    Input #1, s1
    Print "Read Line 1: " & s1
    
    Input #1, f1
    Print "Read Float: " & f1
    
    Close #1
    
    GetTree().Quit()
End Sub
