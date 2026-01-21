Sub Main()
    Print "=== Date/Time Test ==="
    

    d = Now()
    Print "Now dictionary: "
    Print d
    
    Print "Year: " & Year(d) 
    Print "Month: " & Month(d)
    Print "Day: " & Day(d)
    Print "Time: " & Hour(d) & ":" & Minute(d) & ":" & Second(d)
    
    Print "Timer (s): " & Timer()
    

    t0 = Timer()
    ' Busy wait roughly

    For i = 1 To 10000
    Next
    Print "Delta: " & (Timer() - t0)
    
    Print "=== Date/Time Test Complete ==="
End Sub
