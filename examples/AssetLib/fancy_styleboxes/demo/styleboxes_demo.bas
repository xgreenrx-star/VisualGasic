' Fancy StyleBoxes demo (typed VisualGasic)
' Upstream: https://github.com/xZpookyx/StyleBoxFancy (MIT)
'
' Demonstrates usage of fancy styleboxes applied to a panel node named 'PanelDemo'.
'
Dim border_thickness As Integer = 4
Dim corner_curve As Integer = 16

Sub Form_Load()
    If PanelDemo Is Nothing Then
        Print "PanelDemo not found. Add a Control node named 'PanelDemo' and attach StyleBox in editor."
        Return
    End If
    Print "StyleBoxes demo loaded. Adjust border_thickness and corner_curve in editor or demo code."
End Sub

Sub IncreaseCurve_Click()
    corner_curve = corner_curve + 4
    Print "corner_curve=" & corner_curve
End Sub
