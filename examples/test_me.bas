Sub Main()
    Print "Me functionality test"

    ' Expecting implicit Call/Assignment via MemberAccess
    ' Me is owner (VisualGasicNode)
    s = Me.get_name() 
    Print "Owner Name: " & s
    

    Print "Call Tree"
    Set tree = Me.get_tree()
    Print "Tree: " & tree

End Sub
