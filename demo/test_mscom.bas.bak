Sub Main()
    Print "Testing MSComctl-like features..."
    
    ' ProgressBar
    Dim pb
    Print "Creating ProgressBar"
    pb = CreateProgressBar(0, 100, 0, 100, 100)
    pb.Value = 50
    Print "ProgressBar Value: " & pb.Value
    
    ' Slider
    Dim sl
    Print "Creating Slider"
    sl = CreateSlider(0, 10, 5, 100, 150)
    sl.Value = 8
    Print "Slider Value: " & sl.Value
    
    ' ListView
    Dim lv
    Print "Creating ListView"
    lv = CreateListView(100, 200)
    lv.AddItem "Item A"
    lv.AddItem "Item B"
    lv.AddItem "Item C"
    Print "ListView Items Added"
    
    ' Animate
    Animate pb, "Value", 100, 1.0
    Print "Animating ProgressBar..."
    
End Sub
