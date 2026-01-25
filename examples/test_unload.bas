' Test the Unload statement

Sub _ready()
    Print "Form loaded"
    Print "Click to unload this form"
End Sub

Sub _on_button_pressed()
    Print "Unloading form..."
    Unload Me
    Print "This should never print"
End Sub
