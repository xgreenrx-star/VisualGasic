Sub Main()
    Open "test_funcs.txt" For Output As #1
    Print #1, "1234567890"
    Close #1

    Open "test_funcs.txt" For Input As #1
    
    Print "File Length (LOF): " + Str(LOF(1))
    
    Print "Position before read (Loc): " + Str(Loc(1))
    
    Dim s As String
    s = Input(5, #1)
    Print "Read 5 chars: " + s
    
    Print "Position after read (Loc): " + Str(Loc(1))
    
    Seek #1, 0
    Print "Position after Seek 0 (Loc): " + Str(Loc(1))
    
    Close #1
End Sub
