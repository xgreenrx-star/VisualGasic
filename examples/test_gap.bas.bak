Sub Main()
    Print "Lerp(0, 100, 0.5): " & Lerp(0, 100, 0.5)
    Print "Clamp(150, 0, 100): " & Clamp(150, 0, 100)
    
    Dim path
    path = "user://test_mkdir"
    
    On Error Resume Next
    RmDir path
    On Error Goto 0
    
    MkDir path
    Print "MkDir created."
    
    Dim f
    f = FreeFile
    Open path & "/test.txt" For Output As #f
    Print #f, "Hello"
    Close #f
    
    Print "FileLen: " & FileLen(path & "/test.txt")
    
    Print "Deleting file..."
    Kill path & "/test.txt"
    
    Print "Deleting dir..."
    RmDir path
    Print "Done."
    
    ' MsgBox "Test Alert", 0, "Title" 
    ' Uncommenting above will show blocking alert
    
End Sub
