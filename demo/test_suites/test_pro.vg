Dim tatus As Variant
Dim ame As Variant

Sub Main()
    Print "Starting Form Test..."
    Set LblStatus = CreateLabel("Status: Waiting...", 10, 10)
    Set TxtName = CreateInput("Type name...", 10, 40, 200)
    Set btn = CreateButton("Say Hello", 10, 80, "OnHelloClick")
    Set btnQuit = CreateButton("Quit", 120, 80, "OnQuitClick")
    Print "Form Created"
End Sub

Sub OnHelloClick()
    Print "Hello Clicked!"
    LblStatus.Text = "Hello Clicked! (Input Read Skipped)"
End Sub

Sub OnQuitClick()
    Print "Quitting..."
End Sub
