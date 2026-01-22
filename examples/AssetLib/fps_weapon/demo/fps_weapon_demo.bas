' FPS Weapon demo (typed VisualGasic)
' Upstream: https://github.com/Jeh3no/Godot-Simple-FPS-Weapon-System-Asset (MIT)
'
' This demo uses `FPSBridge` to request projectile spawns and simulate a simple hitscan.
'
Dim muzzle_velocity As Float = 100.0
Dim ammo As Integer = 10

Sub Form_Load()
    Print "FPS Weapon demo loaded. ammo=" & ammo
End Sub

Sub Fire_Click()
    If FPSBridge Is Nothing Then
        Print "FPSBridge not found. Add bridge node to scene to handle projectile spawn."
        Return
    End If
    If ammo <= 0 Then
        Print "Out of ammo"
        Return
    End If
    Call FPSBridge.SpawnProjectile(muzzle_velocity)
    ammo = ammo - 1
    Print "Fired projectile. ammo=" & ammo
End Sub
