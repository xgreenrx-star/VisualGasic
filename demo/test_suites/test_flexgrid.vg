Sub Main()
    Print "Testing FlexGrid..."


    ' Create 3x3 Grid
    Set grid = CreateFlexGrid(3, 3, 50, 50)
    
    ' Set Headers (Row 0)
    grid.SetTextMatrix(0, 0, "ID")
    grid.SetTextMatrix(0, 1, "Name")
    grid.SetTextMatrix(0, 2, "Status")
    
    ' Set Data (Row 1, 2)
    grid.SetTextMatrix(1, 0, "001")
    grid.SetTextMatrix(1, 1, "Alice")
    grid.SetTextMatrix(1, 2, "Active")
    
    grid.SetTextMatrix(2, 0, "002")
    grid.SetTextMatrix(2, 1, "Bob")
    grid.SetTextMatrix(2, 2, "Idle")
    
    Print "Grid Rows: " & grid.Rows
    Print "Grid Cols: " & grid.Cols
    
    ' Add Item method
    ' grid.AddItem "003" & vbTab & "Charlie" & vbTab & "Offline"
    grid.AddItem "Simple"
    Print "Grid Rows after Add: " & grid.Rows
    
    ' Resize Grid
    grid.Cols = 4
    grid.SetTextMatrix(0, 3, "New Col")
    Print "Resized Cols: " & grid.Cols
    
End Sub
