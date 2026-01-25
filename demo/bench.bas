' VisualGasic benchmark script

Function Bench(ByVal iterations As Long, ByVal inner As Long) As Long
    Dim i As Long
    Dim j As Long
    Dim s As Long

    For i = 0 To iterations - 1
        For j = 0 To inner - 1
            s = s + j
        Next j
    Next i

    Bench = s
End Function
