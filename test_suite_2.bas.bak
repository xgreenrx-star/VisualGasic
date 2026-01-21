Sub Main()
    Print "Testing Exception Handling and New Features"
    
    ' Test 1: Try Catch Generally
    Print "Test 1: General Try Catch"
    Try
        Dim x
        x = 1 / 0 ' Cause Error (if 1/0 throws, otherwise manually raise)
        ' Actually in VG, 1/0 might allow Inf or error. Let's Raise.
        Raise 101, "Test Error"
        Print "This should not print"
    Catch
        Print "Caught Error!"
    End Try

    ' Test 2: Finally
    Print "Test 2: Finally"
    Try
        Print "Inside Try"
        Raise 102
    Catch
        Print "Inside Catch"
    Finally
        Print "Inside Finally"
    End Try
    Print "After Try-Finally"

    ' Test 3: CType
    Dim s
    s = "123"
    Dim i
    i = CType(s, "Integer")
    Print "CType Result: " & (i + 1) ' Should be 124
    
    Dim d
    d = CDbl("12.5")
    Print "CDbl Result: " & d
    
    ' Test 4: String Functions
    Dim strVal
    strVal = "A,B,C"
    Dim parts
    parts = Split(strVal, ",")
    Print "Split Count: " & (UBound(parts) + 1)
    Print "Part 1: " & parts(1)
    
    Dim joined
    joined = Join(parts, "-")
    Print "Joined: " & joined
    
    Print "Replace: " & Replace("Hello World", "World", "Visual Gasic")

    ' Test 5: Me and New
    ' Requires class/struct context for real test, but New Dictionary works globally
    Dim dict
    ' Set dict = New Dictionary ' Parser needs "Set" for objects usually? Or just assignment.
    ' Let's try standard assignment if Value type, or Set if Ref.
    ' In VG, Dictionary is Variant, so = is fine.
    dict = New Dictionary
    dict("Key") = "Value"
    Print "Dictionary Key: " & dict("Key")
    
    ' Me is only valid inside a class/object script. 
    ' Since we are running Main in a script acting as class? 
    ' If we run this script attached to a Node, Me should work.
    ' But standalone test runner might not have owner?
    ' VisualGasicInstance wrapper usually sets owner.
    
    Print "Test Complete"
End Sub
