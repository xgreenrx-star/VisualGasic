' Button Test
Option Explicit

Sub _Ready()
	Print "Button Test Ready"
	
	Dim btn As Object
	Set btn = CreateNode("Button")
	btn.Name = "MyButton"
	btn.Text = "Click Me"
	btn.Position = Vector2(100, 100)
	btn.Size = Vector2(200, 50)
	AddChild(btn)
	
	Print "Button Created"
End Sub

Sub MyButton_Click()
	Print "VisualGasic: Button Clicked Successfully!"
End Sub
