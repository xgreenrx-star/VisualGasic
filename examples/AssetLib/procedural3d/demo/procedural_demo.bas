' Procedural 3D demo (typed VisualGasic)
' Upstream: https://github.com/SirNeirda/godot_procedural_infinite_world (MIT)
'
' This demo shows how to toggle terrain-generation parameters exposed by a
' bridge node `ProceduralBridge` that wraps the upstream project's APIs.
'
Dim seed As Integer = 42
Dim density As Float = 0.5
Dim enable_weather As Integer = 1

Sub Form_Load()
    If ProceduralBridge Is Nothing Then
        Print "ProceduralBridge not found. Add bridge node or use upstream scene directly."
        Return
    End If

    Call ProceduralBridge.SetParam("seed", seed)
    Call ProceduralBridge.SetParam("density", density)
    Call ProceduralBridge.SetParam("enable_weather", enable_weather)
    Print "Procedural demo configured: seed=" & seed & " density=" & density
End Sub

Sub RandomizeSeed_Click()
    seed = (seed + 12345) Mod 100000
    Call ProceduralBridge.SetParam("seed", seed)
    Print "Seed randomized: " & seed
End Sub
