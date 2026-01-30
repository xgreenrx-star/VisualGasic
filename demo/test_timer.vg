Dim tick_count As Integer

Sub Main()
    Print "=== Timer Component Test ==="
    tick_count = 0
    
    ' Create a standard Godot Timer

    Set t = New Timer
    Print "Timer created: " & t
    
    ' Configure properties (using Godot API names)
    t.wait_time = 0.5
    t.one_shot = False
    
    ' Add to Scene Tree (Me is the current script instance node)
    Print "Adding child..."
    ' Me.add_child t ' This causes crash in headless? or general?
    ' The issue might be calling add_child inside _init or before entered tree?
    ' But we aren't in _init of VisualGasic node, we are in Main called by Runner.
    ' Runner calls Main. Node is added to root.
    
    ' Try using call "add_child" explicitly?
    Call Me.add_child(t)
    ' Print "Skipping add_child"

    Print "Child added."
    
    ' Connect Signal
    ' Connect(Source, "signal_name", "MethodName")
    Connect t, "timeout", "OnTick"
    
    ' Start
    t.start
    Print "Timer started..."
End Sub

Sub OnTick()
    tick_count = tick_count + 1
    Print "Tick " & tick_count
    
    if tick_count >= 5 then
         Print "Timer finished."
         Me.get_tree().quit()
    end if
End Sub
