' Laser3D demo (typed VisualGasic)
' Upstream: https://github.com/Saulo-de-Souza/Laser-3D (MIT)
'
' Demonstrates toggling laser beams via `LaserBridge` and simulating a firing call.
'
Dim beam_length As Float = 50.0
Dim beam_color As Integer = 0xFFFFFF

Sub Form_Load()
    If LaserBridge Is Nothing Then
        Print "LaserBridge not found. Add bridge node to scene to use Laser features."
        Return
    End If
    Call LaserBridge.SetParam("beam_length", beam_length)
    Call LaserBridge.SetParam("beam_color", beam_color)
    Print "Laser demo configured: length=" & beam_length
End Sub

Sub FireLaser_Click()
    If LaserBridge Is Nothing Then Print "LaserBridge missing" : Return
    Call LaserBridge.Fire()
    Print "Laser fired"
End Sub
