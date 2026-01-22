' Dual Kawase Blur — VisualGasic demo
' Upstream: https://github.com/Ultipuk/godot-dual-kawase-blur (MIT)
'
' This demo assumes the Dual Kawase plugin is installed and a node
' named "DualKawase" (DualKawaseBlurCompositorEffect or similar) is
' present in the running scene (or available via an autoload).
'
' The script demonstrates typed variables, simple UI event handlers
' and how to set common parameters. Where direct compositor APIs are
' not available in VisualGasic, manual scene setup is required; see
' MISSING_KEYWORDS.md for details.
'
Dim blur_radius As Float = 4.0
Dim iterations As Integer = 2
Dim enabled As Integer = 1 ' 1 = true, 0 = false (no Boolean type in some examples)

Sub Form_Load()
    ' Form_Load is called when the form (scene) is ready. We expect
    ' the host scene to have a node named "DualKawase" (added in the
    ' editor or by the upstream plugin). The GasicForm auto-wires
    ' scene nodes into the script scope by name.

    If DualKawase Is Nothing Then
        Print "DualKawase node not found. Please add the Dual Kawase node named 'DualKawase'."
        Return
    End If

    ' Apply initial settings — property names below are illustrative;
    ' match them to the upstream plugin's API (check plugin docs).
    On Error Resume Next
    ' Prefer a bridge helper if present, otherwise set properties directly
    If Not DualKawaseBridge Is Nothing Then
        Call DualKawaseBridge.SetParam("blur_radius", blur_radius)
        Call DualKawaseBridge.SetParam("iterations", iterations)
        Call DualKawaseBridge.SetParam("enabled", enabled)
    Else
        DualKawase.blur_radius = blur_radius
        DualKawase.iterations = iterations
        DualKawase.enabled = enabled
    End If
    On Error GoTo 0

    Print "DualKawase demo loaded. radius=" & blur_radius & " iterations=" & iterations
End Sub

Sub IncreaseBlur_Click()
    Dim v As Float
    v = blur_radius + 1.0
    blur_radius = v
    If Not DualKawaseBridge Is Nothing Then
        Call DualKawaseBridge.SetParam("blur_radius", blur_radius)
    ElseIf Not DualKawase Is Nothing Then
        DualKawase.blur_radius = blur_radius
    End If
    Print "Increased blur to " & blur_radius
End Sub

Sub DecreaseBlur_Click()
    Dim v As Float
    v = blur_radius - 1.0
    If v < 0 Then v = 0
    blur_radius = v
    If Not DualKawaseBridge Is Nothing Then
        Call DualKawaseBridge.SetParam("blur_radius", blur_radius)
    ElseIf Not DualKawase Is Nothing Then
        DualKawase.blur_radius = blur_radius
    End If
    Print "Decreased blur to " & blur_radius
End Sub

Sub ToggleEnabled_Click()
    If enabled = 0 Then
        enabled = 1
    Else
        enabled = 0
    End If
    If Not DualKawase Is Nothing Then DualKawase.enabled = enabled
    Print "DualKawase enabled=" & enabled
End Sub
