Sub Main
    Print "Starting Error Test"
    

    
    ' Test 1: Goto
    Print "Testing Goto..."
    Goto SkipMe
    Print "FAIL: This should be skipped"
SkipMe:
    Print "Pass: Goto worked"
    
    ' Test 2: On Error Resume Next
    Print "Testing Resume Next..."
    On Error Resume Next
    A(99) = 1 ' Out of bounds
    Print "Pass: Resumed after error"

    ' Test 3: Err Object
    Print "Testing Err Object..."
    Err.Clear
    Err.Raise 101, "Test", "Manually raised error"
    Print "Err.Number (expected 101): " & Str(Err.Number)
    Print "Err.Description: " & Err.Description
    Err.Clear
    Print "Err.Number after clear (expected 0): " & Str(Err.Number)
    
    ' Test 4: On Error Goto Label
    Print "Testing Error Handler..."
    On Error Goto MyHandler
    A(99) = 1 ' Error again
    Print "FAIL: Should have jumped to handler"
    Goto Done
    
MyHandler:
    Print "Pass: Error Handler Caught Error"
    
Done:
    Print "Finished."
End Sub
