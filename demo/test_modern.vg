Sub Main()
    Print "Testing Modern VisualGasic Features"
    
    ' Test 1: String Interpolation
    Dim myname As String 
    myname = "Gasic"
    Dim ver As Integer
    ver = 2
    Print $"Welcome to {myname} v{ver}!"
    
    ' Test 2: IIf
    Dim x As Integer
    x = 10
    Dim res As String
    res = IIf(x > 5, "Greater", "Smaller")
    Print "IIf Result: " & res
    
    Dim res2 As String
    res2 = IIf(x > 20, True="Greater", False="Smaller")
    Print "IIf Named Args Result: " & res2
    
    Dim res3 As String
    res3 = "Inline Win" If x > 5 Else "Inline Lose"
    Print "Inline If Result: " & res3

    Dim res4 As Integer
    Dim pTest As Boolean
    pTest = True
    ' 10 + (20 If True Else 0) -> 30
    res4 = 10 + 20 If pTest Else 0
    Print "Precedence Test (10+20): " & res4

    ' Test 3: AndAlso / OrElse (Short Circuit)
    Print "Testing Short Circuit..."
    If True OrElse Crash() Then
        Print "OrElse Short Circuit Worked (Crash Avoided)"
    End If
    
    If False AndAlso Crash() Then
        Print "Failed"
    Else
        Print "AndAlso Short Circuit Worked (Crash Avoided)"
    End If
    
    ' Test 4: Return
    Print "Factorial(5) = " & Factorial(5)
    
    ' Test 5: Continue
    Print "Odd numbers <= 5:"
    Dim i As Integer
    For i = 1 To 5
        If Int(i / 2) * 2 = i Then Continue For
        Print i
    Next
End Sub

Function Factorial(n As Integer) As Integer
    If n <= 1 Then Return 1
    Return n * Factorial(n - 1)
End Function

Function Crash() As Boolean
    Print "CRASH CALLED (Should not happen)"
    Return False
End Function
