Option Explicit

Dim X As Integer
Dim Y As Integer

Sub _Ready()
    X = 10
    Print "X is " & X

    Y = 20
    Print "Y is " & Y

    Try
        Print "Entering Try Block"
        Kill "NonExistentFile.txt" 
        Print "This should not print"
    Catch
        Print "Caught Error in Try Block!"
        Print "Error Number: " & Err.Number
        Print "Error Description: " & Err.Description
    End Try

    Print "Continuing execution..."
    
    ' Test Option Explicit
    Dim Z
    Z = 30
    Print "Z is " & Z
    
    ' Uncommenting the next line should cause a PARSE ERROR because W is not presumed
    ' W = 40
End Sub
