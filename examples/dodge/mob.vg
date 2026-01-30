' Mob Script for Dodge The Creeps
Option Explicit

Sub _Ready()
	' Select random animation type if we had animations
	' For now, we are just a generic physics body
	
	' Add visibility notifier to cleanup
	Dim notif As Object
	Set notif = CreateNode("VisibleOnScreenNotifier2D")
	AddChild(notif)
	' Connect signal. Note: Standard signal is "screen_exited"
	' We connect it to a local sub "OnScreenExited"
	Call Connect(notif, "screen_exited", "OnScreenExited")
End Sub

Sub OnScreenExited()
	QueueFree()
End Sub
