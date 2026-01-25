' VisualGasic benchmark script

Function BenchArithmetic(ByVal iterations As Long, ByVal inner As Long) As Long
    Dim i As Long
    Dim j As Long
    Dim s As Long

    For i = 0 To iterations - 1 Step 1
        For j = 0 To inner - 1 Step 1
            s = s + (j * 3) - 7
        Next j
    Next i

    BenchArithmetic = s
End Function

Function BenchArraySum(ByVal iterations As Long, ByVal size As Long) As Long
    Dim i As Long
    Dim k As Long
    Dim s As Long
    Dim arr(0) As Long
    ReDim arr(size - 1)

    For i = 0 To size - 1 Step 1
        arr(i) = i
    Next i

    For k = 0 To iterations - 1 Step 1
        For i = 0 To size - 1 Step 1
            s = s + arr(i)
        Next i
    Next k

    BenchArraySum = s
End Function

Function BenchStringConcat(ByVal iterations As Long, ByVal inner As Long) As Long
    Dim i As Long
    Dim j As Long
    Dim s As String

    For i = 0 To iterations - 1 Step 1
        s = ""
        For j = 0 To inner - 1 Step 1
            s = s & "x"
        Next j
    Next i

    BenchStringConcat = Len(s)
End Function

Function BenchBranch(ByVal iterations As Long, ByVal inner As Long) As Long
    Dim i As Long
    Dim j As Long
    Dim s As Long
    Dim flag As Long

    For i = 0 To iterations - 1 Step 1
        flag = 0
        For j = 0 To inner - 1 Step 1
            If flag = 0 Then
                s = s + j
                flag = 1
            Else
                s = s - j
                flag = 0
            End If
        Next j
    Next i

    BenchBranch = s
End Function
