Sub Main()
    Print "Testing Shaders..."
    
    ' Load generic icon

    Set spr = LoadSprite("res://icon.svg")
    
    ' Check if sprite loaded (headless environment issue?)
    If TypeName(spr) = "Sprite2D" Then
        AddChild spr
        spr.position = Vector2(300, 300)
        
        ' Load Shader

        Set sh = LoadShader("res://test_shader.gdshader")
        
        If Not sh Is Nothing Then
            Print "Shader Loaded Successfully"
            
            ' Apply Shader
            SetShader spr, sh
            Print "Shader Applied"
            
            ' Change Parameter
            ' Make it Red
            SetShaderParam spr, "my_color", Color(1, 0, 0, 1)
            Print "Shader Param Set (Red)"
        Else
            Print "Failed to load shader"
        End If
    Else
        Print "Skipping Shader apply, sprite not loaded"
    End If

End Sub
