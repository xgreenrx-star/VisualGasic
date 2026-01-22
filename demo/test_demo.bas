' Starter Assets demo (typed VisualGasic)
' Upstream: https://github.com/NiwlGames/GodotStarterAssets (CC0)
'
' Demonstrates controller hook-up and a simple character input example.
'
Dim gravity As Float = 9.8
Dim jump_force As Float = 8.0

Sub Form_Load()
    Print "Starter Assets demo loaded. Adjust gravity and jump_force then press Run in host scene."
End Sub

Sub Jump_Click()
    If Player Is Nothing Then
        Print "Player node not wired. Add a Player node and name it 'Player'"
        Return
    End If
    If Player.HasMethod("apply_jump") Then
        Player.apply_jump(jump_force)
    Else
        Print "Player node has no apply_jump helper; implement a small GDScript bridge if needed."
    End If
End Sub
