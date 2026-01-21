Attribute VB_Name = "FullTest"

Sub Main()
    Print "Testing All Features"
    
    Dim Name
    Name = "RenamedNode"
    ' Test Sub Call with argument
    Call set_name(Name) 
    
    Dim Result
    
    ' Test Call Expression (Return Value) using set_meta/get_meta
    ' First set a meta value using Call statement
    Call set_meta("TestKey", 42)
    
    ' Now retrieve it using Call Expression
    Result = get_meta("TestKey")
    
    Print "Meta Result (should be 42):"
    Print Result
    
    Dim Check
    ' Test boolean return
    Check = has_meta("TestKey")
    
    If Check Then
        Print "Meta Key Found!"
    Else
        Print "Meta Key Missing!"
    End If
    
    ' Check variable modification
    Dim Counter
    Counter = 0
    For i = 1 To 3
        Counter = Counter + i
    Next
    Print "Loop Counter (should be 6):"
    Print Counter
    
    Print "Done"
End Sub
