' Fight Engine demo (typed VisualGasic)
' Upstream: https://github.com/Fxll3n/FightEngine (MIT)
'
' Demonstrates invoking simple fight-engine helpers via auto-wired `FightEngine` node.
'
Dim combo_step As Integer = 0

Sub Form_Load()
    Print "Fight Engine demo loaded"
End Sub

Sub Punch_Click()
    If FightEngine Is Nothing Then
        Print "FightEngine node not found. Add it to the scene or use upstream demo."
        Return
    End If
    If FightEngine.HasMethod("do_punch") Then
        FightEngine.do_punch()
    Else
        Print "FightEngine missing do_punch helper; add a small bridge if needed."
    End If
End Sub
