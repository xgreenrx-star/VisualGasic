Sub Main()
    Print "--- Starting Feature Check ---"

    ' 1. Test Select Case
    Dim scVal
    scVal = 2
    Select Case scVal
        Case 1
            Print "Strict Fail: Select Case matched 1"
        Case 2
            Print "Pass: Select Case matched 2"
        Case 3
            Print "Strict Fail: Select Case matched 3"
        Case Else
            Print "Strict Fail: Select Case matched Else"
    End Select

    ' 2. Test ElseIf
    Dim eiVal
    eiVal = 20
    If eiVal = 10 Then
        Print "Strict Fail: If matched 10"
    ElseIf eiVal = 20 Then
        Print "Pass: ElseIf matched 20"
    Else
        Print "Strict Fail: Else matched"
    End If

    ' 3. Test Exit For
    Dim i
    Dim exitCheck
    exitCheck = 0
    For i = 1 To 10
        If i = 5 Then 
            exitCheck = 1
            Exit For
        End If
    Next
    
    If exitCheck = 1 Then
        If i = 5 Then Print "Pass: Exit For stopped at 5" Else Print "Strict Fail: Exit For index issue " & i
    Else
        Print "Strict Fail: Exit For did not trigger"
    End If

    ' 4. Test Split and Join
    Dim sRaw
    sRaw = "Apple,Banana,Cherry"
    Dim parts
    parts = Split(sRaw, ",")
    
    ' Check size - dependent on array implementation, usually UBound for VB, or just use index
    ' VisualGasic might not have UBound yet. Let's try direct access.
    
    If parts(0) = "Apple" Then Print "Pass: Split Index 0" Else Print "Strict Fail: Split Index 0"
    If parts(1) = "Banana" Then Print "Pass: Split Index 1" Else Print "Strict Fail: Split Index 1"

    Dim sJoined
    sJoined = Join(parts, "-")
    If sJoined = "Apple-Banana-Cherry" Then Print "Pass: Join" Else Print "Strict Fail: Join Result: " & sJoined

    Print "--- End Feature Check ---"
End Sub
