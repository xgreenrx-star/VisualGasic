' Test Declare statement (DLL external functions)

' Declare external function (parsed as stub)
Declare Function MessageBox Lib "user32.dll" Alias "MessageBoxA" _
    (ByVal hwnd As Long, ByVal text As String, ByVal caption As String, ByVal flags As Long) As Long

Declare Sub Sleep Lib "kernel32.dll" (ByVal ms As Long)

Sub _ready()
    Print "Declare statements parse successfully"
    Print "Full FFI implementation pending"
    
    ' These would call external DLL functions in real VB6
    ' MessageBox 0, "Hello", "Title", 0
    ' Sleep 1000
End Sub
