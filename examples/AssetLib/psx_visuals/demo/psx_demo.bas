' PSX Visuals — VisualGasic demo
' Upstream: https://github.com/scolastico/psx_visuals_gd4 (MIT)
'
' This demo demonstrates toggling a few PSX-style visual parameters such as
' pixelization (pixel_size), dithering, and saturation. The scene should
' include a node named "PSXVisuals" (from the upstream plugin) to be auto-wired
' into the script scope by the host form (see GasicForm auto-wiring behavior).
'
Dim pixel_size As Integer = 4
Dim dithering As Integer = 1 ' 1 = on, 0 = off
Dim saturation As Float = 1.0
Dim effect_mode As Integer = 0

Sub Form_Load()
    If PSXVisuals Is Nothing Then
        Print "PSXVisuals node not found. Please add the PSX Visuals plugin and name the node 'PSXVisuals'."
        Return
    End If

    On Error Resume Next
    PSXVisuals.pixel_size = pixel_size
    PSXVisuals.dithering = dithering
    PSXVisuals.saturation = saturation
    PSXVisuals.mode = effect_mode
    On Error GoTo 0

    Print "PSX Visuals demo loaded. pixel_size=" & pixel_size & " dithering=" & dithering & " saturation=" & saturation
End Sub

Sub IncreasePixel_Click()
    pixel_size = pixel_size + 1
    If Not PSXVisuals Is Nothing Then PSXVisuals.pixel_size = pixel_size
    Print "pixel_size=" & pixel_size
End Sub

Sub DecreasePixel_Click()
    pixel_size = pixel_size - 1
    If pixel_size < 1 Then pixel_size = 1
    If Not PSXVisuals Is Nothing Then PSXVisuals.pixel_size = pixel_size
    Print "pixel_size=" & pixel_size
End Sub

Sub ToggleDither_Click()
    If dithering = 0 Then dithering = 1 Else dithering = 0
    If Not PSXVisuals Is Nothing Then PSXVisuals.dithering = dithering
    Print "dithering=" & dithering
End Sub

Sub CycleMode_Click()
    effect_mode = (effect_mode + 1) Mod 3
    If Not PSXVisuals Is Nothing Then PSXVisuals.mode = effect_mode
    Print "mode=" & effect_mode
End Sub
