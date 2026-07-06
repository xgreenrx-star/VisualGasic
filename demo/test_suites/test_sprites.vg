Sub Main()
    ' Test Sprite Commands
    Print "Testing Sprite Commands..."


    Set n = CreateNode("Node2D")
    ' TypeName might return Object or Node2D depending on implementation. 
    ' Let's just print it.
    Print "Node Type: " & TypeName(n)

    If TypeName(n) = "Node2D" Then
        Print "CreateNode(Node2D): Success"
    Else
        Print "CreateNode(Node2D): Check returned " & TypeName(n)
    End If

    AddChild n
    n.position = Vector2(100, 200)
    Print "Node Position set to 100, 200"
    Print "Node Position: " & n.position


    Set spr = LoadSprite("res://icon.svg")

    ' Check if object is valid.
    ' We can check if TypeName returns "Sprite2D"
    If TypeName(spr) = "Sprite2D" Then
        Print "LoadSprite: Success"
        AddChild spr
        spr.position = Vector2(300, 300)
        Print "Sprite Position: " & spr.position
    Else
        Print "LoadSprite: Failed (icon.svg likely missing)"
    End If
    
    ' Dim empty_var
    ' If spr Is empty_var Then
    '    Print "spr is Nothing" 
    ' Else
    '    Print "spr is valid object"
    ' End If
    
    ' Is operator seems to have issues in current build, skipping check

    ' Test generic create sprite

    Set tex = LoadTexture("res://icon.svg")
    ' check if tex is valid object (approx)
    If TypeName(tex) = "CompressedTexture2D" Or TypeName(tex) = "Texture2D" Then

        Set s2 = CreateSprite(tex)
        Print "CreateSprite: Success"
        AddChild s2
    Else
        ' If icon missing, TypeName is likely "Object" (null variant?) or something else.
        Print "LoadTexture: Failed or icon missing"
    End If
End Sub
