Sub Main()
    Print "Testing LoadData..."
    
    ' Basic variable based loading
    Dim f As String
    f = "res://test_io.txt"
    
    LoadData f
    
    Dim a As Integer
    Dim b As String
    
    Read a
    Read b
    
    Print "Dynamic Read: " & a & ", " & b
    
    If a <> 100 Then Print "Error: Dyn Read A failed"
    If b <> "File Data" Then Print "Error: Dyn Read B failed"
    
    ' Test appending
    LoadData f
    Dim c As Integer
    Read c
    Print "Appended Read: " & c 
    If c <> 100 Then Print "Error: Appended data read failed"
    
    Print "LoadData Tests OK"
End Sub
