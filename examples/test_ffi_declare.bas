' Test FFI/Declare functionality
' Tests: Declare statements, external DLL/SO functions, ByVal/ByRef, Cdecl

' Declare some common system functions (these won't execute but will parse)

' Windows API example - MessageBox
Declare Function MessageBox Lib "user32.dll" Alias "MessageBoxA" _
    (ByVal hwnd As Long, ByVal lpText As String, ByVal lpCaption As String, ByVal uType As Long) As Long

' Linux C library examples
Declare Function strlen Lib "libc.so.6" (ByVal str As String) As Long

Declare Function getpid Lib "libc.so.6" () As Long

Declare Sub sleep Lib "libc.so.6" (ByVal seconds As Long)

' Example with ByRef parameter
Declare Function GetComputerName Lib "kernel32.dll" Alias "GetComputerNameA" _
    (ByVal lpBuffer As String, ByRef nSize As Long) As Long

' Example with Cdecl calling convention  
Declare Function printf Lib "libc.so.6" Cdecl _
    (ByVal format As String) As Long

' Example Sub (no return value)
Declare Sub ExitProcess Lib "kernel32.dll" (ByVal uExitCode As Long)

Sub TestFFI()
    Print "=== Testing Declare/FFI Functionality ==="
    
    Print ""
    Print "Declared functions:"
    Print "  - MessageBox (stdcall, Alias, ByVal)"
    Print "  - strlen (libc)"
    Print "  - getpid (libc, no params)"
    Print "  - sleep (libc, ByVal)"
    Print "  - GetComputerName (ByRef param)"
    Print "  - printf (Cdecl calling convention)"
    Print "  - ExitProcess (Sub, no return)"
    
    Print ""
    Print "All Declare statements parsed successfully!"
    Print "FFI infrastructure is in place."
    Print "Note: Full type marshaling and function invocation"
    Print "      requires libffi or platform-specific assembly."
    
    ' These calls would work once FFI is fully implemented:
    ' Dim pid As Long
    ' pid = getpid()
    ' Print "Process ID:", pid
    
    ' Dim len As Long
    ' len = strlen("Hello World")
    ' Print "String length:", len
End Sub

' Execute test
TestFFI()
