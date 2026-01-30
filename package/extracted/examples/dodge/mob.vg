' Mob Script for Dodge The Creeps

Sub _Ready()
    ' Select random animation type if we had animations
    ' For now, we are just a generic physics body
    
    ' Add visibility notifier to cleanup
    Dim f As Object
    AddChild(notif)
    ' Connect signal. Note: Standard signal is "screen_exited"
    ' We connect it to a local sub "OnScreenExited"
    Call Connect(notif, "screen_exited", "OnScreenExited")
End Sub

Sub OnScreenExited()
    QueueFree()
End Sub
