Sub Main()
    Form_Load
End Sub

Dim MSComm1

Private Sub Form_Load()
    Print "Initializing MSComm1..."
    
    ' Create the component (VisualGasic specific step, as we don't have a designer yet)
    Set MSComm1 = CreateMSComm()
    Print "CreateMSComm returned: " & MSComm1

    ' Specify the COM port number (e.g., COM1)
    MSComm1.CommPort = 1 
    Print "CommPort set"
    
    ' Set the port parameters
    MSComm1.Settings = "9600,N,8,1" 
    Print "Settings set"
    
    ' Disable hardware handshaking
    MSComm1.Handshaking = comNone
    Print "Handshaking set"
    
    Print "Settings: " & MSComm1.Settings
    Print "Trying to open port..."
    
    ' Open the port
    MSComm1.PortOpen = 1
    
    If MSComm1.PortOpen Then
        Print "Port OK!"
    Else
        Print "Port Failed (Simulated mode might be active)"
    End If
End Sub
