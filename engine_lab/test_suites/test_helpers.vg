Sub Main()
    Print "Waited 0ms (Testing Sleep)"
    Sleep 100
    Print "Waited 100ms"
    

    s = "Hello"
    Print "TypeName(s): " & TypeName(s)
    Print "IsNumeric(123): " & IsNumeric(123)
    Print "IsNumeric(ABC): " & IsNumeric("ABC")
    Print "IsArray(s): " & IsArray(s)
    

    d = 3.14159
    Print "Round(PI, 2): " & Round(d, 2)
    Print "Round(PI): " & Round(d)
    
    Print "RandRange(0, 10): " & RandRange(0, 10)
    
    Print "CInt(3.9): " & CInt(3.9) ' Should be 3 (trunc) or 4 (round)? Cast is usually trunc in C++.
    ' VB CInt rounds. C++ (int) truncates. 
    ' I implemented (int) cast so it truncates.
    ' Let's verify.
End Sub
