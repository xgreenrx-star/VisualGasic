' Test the End statement

Sub _ready()
    Print "Application starting..."
    Print "This will quit the application in 2 seconds"
    
    ' Wait a bit then quit
    call_deferred("quit_app")
End Sub

Sub quit_app()
    Print "Calling End to quit..."
    End
    Print "This should never print"
End Sub
