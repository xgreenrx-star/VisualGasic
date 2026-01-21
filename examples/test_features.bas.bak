Sub Main()
    ' Test Input
    Print "Move mouse to test input..."
    
    Dim d
    d = CreateFileDialog()
    d.Title = "Hello VisualGasic"
    
    Print "Dialog Created"
    
    ' Test Tween
    Dim l
    Set l = CreateText("Tween Me!")
    l.Position = Vector2(100, 100)
    
    TweenProperty l, "position", Vector2(500, 100), 2.0
    Print "Tween Started"
    
    ' Test Trigger
    Dim t
    Set t = CreateTrigger("Zone1", 300, 300, 100, 100)
    Print "Trigger Created"
    
    ' Create Actor
    ' Use icon.svg if available
    Dim a
    Set a = CreateActor2D("icon.svg", 0, 0)
    
    ' Tween actor into the trigger area
    TweenProperty a, "position", Vector2(300, 300), 1.0
End Sub

Sub Zone1_Collision(Body)
    Print "Collision Detected!"
End Sub
