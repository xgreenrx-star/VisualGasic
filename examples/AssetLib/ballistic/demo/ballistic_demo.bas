' Ballistic demo (typed VisualGasic)
' Upstream: https://github.com/neclor/ballistic-solutions (MIT)
'
' Demonstrates usage of a `BallisticBridge` which exposes the ballistic utilities to VisualGasic.
'
Dim target_x As Float = 10.0
Dim target_y As Float = 0.0
Dim target_z As Float = 0.0
Dim shooter_speed As Float = 50.0

Sub Form_Load()
    If BallisticBridge Is Nothing Then
        Print "BallisticBridge not found. Add the bridge node to use ballistic helpers."
        Return
    End If

    ' Request a suggested firing velocity (bridge may fallback to simple approximation)
    Call BallisticBridge.RequestVelocity(target_x, target_y, target_z, shooter_speed)
End Sub
