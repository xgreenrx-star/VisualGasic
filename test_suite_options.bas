Option Compare Text
Sub Main()
    Print "Testing Option Compare Text"
    
    Dim s1, s2
    s1 = "Hello"
    s2 = "HELLO"
    
    If s1 = s2 Then
        Print "s1 = s2 (Case Insensitive Match!)"
    Else
        Print "s1 <> s2 (Case Sensitive Match - Failed)"
    End If
    
    If s1 <> s2 Then
        Print "s1 <> s2 (Strange, should be equal in Text mode)"
    End If
    
    Dim s3
    s3 = "apple"
    Dim s4
    s4 = "Banana"
    ' "apple" < "Banana" might depend on casing in ASCII ("a" > "B" usually), but in Text mode "a" < "b".
    ' "apple" vs "Banana" -> "apple" < "banana" (True)
    
    If s3 < s4 Then
        Print "apple comes before Banana"
    End If
    
    Print "Test Complete"
End Sub
