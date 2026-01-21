Sub Main()
    Print "--- Starting Modifiers Test ---"
    
    ' Test 1: Optional Parameters
    Print "Test 1: Optional Parameters"
    TestOptional "Required"
    TestOptional "Required", "Provided"
    
    ' Test 2: Static Variables
    Print "Test 2: Static Variables"
    TestStatic
    TestStatic
    TestStatic
    
    ' Test 3: ParamArray
    Print "Test 3: ParamArray"
    TestParamArray "Run1", 10, 20, 30
    TestParamArray "Run2"
    
    Print "--- End Modifiers Test ---"
End Sub

Sub TestOptional(req, Optional opt = "Default")
    Print "Req: " & req & ", Opt: " & opt
End Sub

Sub TestStatic()
    Static counter As Integer
    Dim normal As Integer
    
    counter = counter + 1
    normal = normal + 1
    
    Print "Static Counter: " & counter & ", Normal: " & normal
End Sub

Sub TestParamArray(prefix, ParamArray args)
    Print "Prefix: " & prefix & ", Count: " & args.Size()

    For i = 0 To args.Size() - 1
        Print "Arg " & i & ": " & args(i)
    Next
End Sub
