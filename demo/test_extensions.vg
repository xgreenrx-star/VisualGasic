Sub Main()
    Print "Log(1): " & Log(1)
    Print "Exp(1): " & Exp(1)
    

    Set v = Vector2(10, 20)
    Print "Vector2: " & v 
    

    Set v3 = Vector3(1, 2, 3)
    Print "Vector3: " & v3
    
    Print "Hex(255): " & Hex(255)
    Print "Oct(8): " & Oct(8)
    

    s = "A,B,C"
    Dim s As Variant
    parts = Split(s, ",")
    
    Print "UBound(parts): " & UBound(parts)
    Print "Parts(0): " & parts(0)
    

    j = Join(parts, "-")
    Print "Joined: " & j
    
    ' Shell test (optional, output might be captured or not depending on runner)
    ' Shell "echo", ["Hello from Shell"] 
    ' Using literal array not supported yet in parser maybe? 
    ' Yes, parser supports [ ] ? No, checked parser, no array literal syntax yet.
    ' So let's skip Shell test with args for now or use variable.
    
    Dim l_args(0) As Array
    shell_args(0) = "Hello Shell"
    ' Shell "echo", shell_args -- Only if Shell support works.
    ' The Shell implementation assumes 2nd arg is Array.
    ' shell_args is a Variant(Array) ?
    ' My Dim creates Variant which can hold Array?
    ' Dim A(10) creates Array.
    ' Dim A. A = Array.
    ' Let's try simple Vector3 and Split first.
End Sub
