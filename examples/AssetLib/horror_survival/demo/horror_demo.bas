' Horror survival demo (typed VisualGasic)
' Upstream: https://github.com/BoQsc/Horror-Survival-Game-Project (CC0)
'
' This demo toggles a small marching-cubes sample via a bridge node `HorrorBridge`.
'
Dim chunk_size As Integer = 16
Dim iso_level As Float = 0.5

Sub Form_Load()
    If HorrorBridge Is Nothing Then
        Print "HorrorBridge not found. Add the bridge node or run upstream scene directly."
        Return
    End If

    Call HorrorBridge.SetParam("chunk_size", chunk_size)
    Call HorrorBridge.SetParam("iso_level", iso_level)
    Print "Horror demo configured: chunk_size=" & chunk_size & " iso_level=" & iso_level
End Sub

Sub Regenerate_Click()
    Call HorrorBridge.Regenerate()
    Print "Regeneration requested"
End Sub
